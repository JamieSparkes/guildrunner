# Guildrunner

A single-player guild management game built in Godot 4.x with GDScript. The player manages a guild of heroes-for-hire from a fixed castle hub — assigning them to contracts, equipping them, setting commitment levels, and watching missions play out through a real-time narrative feed. The tone is low-fantasy medieval, mostly serious with dry humour.

*"You are not the hero. You are the one who sends the heroes."*

See `Guildrunner_GDD.md` for full game design and `Guildrunner_TDD.md` for the technical spec.

## Architecture

Manager/Autoload pattern. Each autoload singleton owns a slice of state and exposes a public API. Cross-system communication flows through **EventBus** signals. Direct manager-to-manager references are avoided.

### Communication Rules

1. **UI never mutates game state directly.** All player intents emit `EventBus.cmd_*` signals.
2. **AppController mediates.** It connects to `cmd_*` signals, calls the appropriate manager API, then emits result signals back for the UI to consume.
3. **Managers broadcast state changes** via EventBus (e.g. `gold_changed`, `hero_wounded`). Other managers or UI listen — never call each other directly.
4. **Resolvers are pure static classes** with no state, no `_ready()`, no autoload. Managers call them for deterministic math (outcome rolls, injury resolution, success chance). This keeps them testable in isolation.

```
UI Action
  → EventBus.cmd_* signal
    → AppController handler
      → Manager API call
        → Resolver (pure math)
      → EventBus result signal
  → UI updates
```

### Autoloads (registration order matters)

| # | Autoload | Owns |
|---|----------|------|
| 1 | EventBus | All signals — no state |
| 2 | GameManager | FSM (MAIN_MENU, GUILD_HUB, MORNING_PHASE, NIGHT_PHASE, etc.) |
| 3 | TimeManager | current_day, day/night cycle |
| 4 | GuildManager | Gold, upkeep, intervention tokens, building tiers (GuildState resource) |
| 5 | HeroManager | Hero roster, status mutations, injury/death/capture |
| 6 | MissionManager | Mission dispatch, daily stage progression, finalization |
| 7 | ItemManager | Guild inventory, hero equipment (stub) |
| 8 | FactionManager | Reputation per faction (stub) |
| 9 | BuildingManager | Construction queue, tier upgrades, effect application |
| 10 | FeedManager | Narrative event streaming, color assignment, intervention triggers |
| 11 | ContractQueue | Daily contract generation/expiry from templates |
| 12 | UIManager | Screen stack (push/pop), CanvasLayer at layer 10 |
| 13 | AppController | Command→manager mediation (last, connects to everything) |

### Static Resolvers (`systems/`)

| Resolver | Purpose |
|----------|---------|
| MissionResolver | Outcome roll for flat (non-staged) contracts |
| StageResolver | Stage-by-stage resolution, exact success chance calculation |
| InjuryResolver | Injury, severity, death, capture rolls |
| BuildingEffectProcessor | Apply building tier effects to GuildState |
| RelationshipModifier | Bond/tension performance and morale effects |

## Data Flow

### JSON → Runtime Objects

```
data/contracts/contract_templates.json
  → DataLoader.load_contract_templates()
    → Dictionary { template_id: ContractData }
      → ContractQueue._templates (cached at _ready)
        → ContractQueue._generate_contract(day)
          → tpl.duplicate() + manual copy of non-@export vars
            → active_contracts array (the board)
```

All JSON loading goes through `utils/DataLoader.gd` which has static methods for each data type. `DataLoader.str_to_enum()` converts string keys to Godot enum values — enum keys must match exactly (see `models/enums.gd` for valid values).

**Important:** `Resource.duplicate()` only copies `@export` vars. Non-exported fields like `ContractData.stages` must be copied manually after duplicating.

### Data files

| File | Contains |
|------|----------|
| `data/contracts/contract_templates.json` | Contract definitions (flat and staged) |
| `data/heroes/starting_heroes.json` | Starting hero roster |
| `data/heroes/portrait_atlas.json` | Sprite sheet column mapping for portraits |
| `data/buildings/buildings.json` | Building definitions and effects |
| `data/world/factions.json` | Faction definitions and thresholds |
| `data/items/items.json` | Item definitions |
| `data/feed/feed_events.json` | Personality-keyed narrative text templates |

## Contract System

### Flat Contracts (legacy)
Single difficulty/skill-weight roll at completion. Duration = `base_duration_days + distance_days`. Uses `MissionResolver` for outcome.

### Staged Contracts
Ordered stages that progress day-by-day. Each stage has events (combat, reward, discovery, objective, narrative) and an advance mechanic. Uses `StageResolver` for outcome.

**Advance types:**
- `auto` — always advances, chains to next stage same day
- `chance` — probability roll with optional `cumulative_increase` and `stat_bonus`; blocks until next day on failure
- `stat_check` — best hero stat vs threshold; optional `fail_advance: true`

**Flags:** Events/stages set flags (`objective_complete`, `detected`, `found_weakness`) that later stages read via `difficulty_modifier_if_flag`. The reserved flag `objective_complete` determines success at mission end.

**Outcome logic (`StageResolver.determine_outcome`):**
- `objective_complete` + all stages done → SUCCESS or FULL_SUCCESS
- `objective_complete` + timed out → PARTIAL
- stages_completed / total ≥ 50% → PARTIAL
- Otherwise → FAILURE

**Success chance:** Exact probability calculation (deterministic, not Monte Carlo). Day-by-day state propagation through advance probabilities multiplied by objective event probability.

### Capture

Capture only happens when `ContractData.can_capture = true` (set per contract in JSON). Without this flag, `InjuryResolver.roll_capture()` is never called. Only contracts where an enemy faction is narratively present to take prisoners should set this.

## UI

### Screen Stack

Screens are pushed/popped via `UIManager`. Each screen is a `Control` node loaded from a `.tscn` and receives data through a `setup(data: Dictionary)` method called after instantiation.

```gdscript
# Opening a screen
EventBus.cmd_open_screen.emit("mission_briefing", {"contract": contract})

# Closing
EventBus.cmd_close_top_screen.emit()
```

All screens are built programmatically in `_build_ui()` — no scene editor layout. Each screen has a matching minimal `.tscn` that just attaches the script.

### Registered screens

contract_board, mission_briefing, feed, hero_roster, hero_detail, building, contract_editor

### Dev Tools

- **F9** — Opens/closes Contract Editor (create flat or staged contracts, clone templates, delete from board)

## Feed & Narrative Streaming

Mission events flow through `FeedManager`:

1. `MissionManager` emits `EventBus.feed_event(mission_id, event_key, params)`
2. `FeedManager.push_event()` formats text from `feed_events.json` templates using personality variants and `{placeholder}` substitution
3. Events queue in `_stream_queue` during active streaming
4. `FeedScreen` pops events on a timer (0.8s), pauses for intervention prompts

**Personality variants:** Each feed event key maps to a dictionary of personality → text arrays in `feed_events.json`. Uses `DEFAULT` as fallback. Personalities: STOIC, RECKLESS, LOYAL, CYNICAL, CHEERFUL, GRIM, CAUTIOUS, PROUD.

**Color coding:** Mission-level color from palette, per-hero colors for departure/return events, reserved red for wounds, green for success, near-black for death/capture.

### Mission Timeline

`MissionTimeline` component (`ui/components/MissionTimeline.gd`) draws a horizontal pip-and-track timeline for each active staged mission. Displayed at the top of FeedScreen.

- Each stage is a pip connected by a track line
- Hero portraits sit above the current pip and lerp to the next when the stage advances
- Pips turn green as stages complete, yellow for the current stage, red on failure/timeout
- FeedScreen matches streamed event keys against `stage_narrative_keys` to advance the timeline in sync with the narrative
- `mission_stage_advanced` and `mission_stage_completed` signals on EventBus for other systems to react to stage progress

## Enums

All enums in `models/enums.gd`, accessed as `Enums.EnumName.VALUE`:

- **HeroArchetype:** FIGHTER, ROGUE, RANGER, SUPPORT
- **PersonalityType:** STOIC, RECKLESS, LOYAL, CYNICAL, CHEERFUL, GRIM, CAUTIOUS, PROUD
- **HeroStatus:** AVAILABLE, ON_MISSION, INJURED, RECOVERING, CAPTURED, DEAD
- **MissionType:** ELIMINATE, RETRIEVE, ESCORT, EXPLORE, DEFEND
- **MissionResult:** FAILURE, PARTIAL, SUCCESS, FULL_SUCCESS
- **CommitmentLevel:** AT_ANY_COST, USE_JUDGEMENT, COME_HOME_SAFE
- **InjurySeverity:** MINOR, SERIOUS, CRITICAL
- **GameState:** MAIN_MENU, GUILD_HUB, MORNING_PHASE, NIGHT_PHASE, MISSION_BRIEFING, MISSION_AUTO, SIEGE, MISSION_DIRECT, CUTSCENE, PAUSED

## Testing

Uses GUT (Godot Unit Test) framework. Tests are in `tests/test_*.gd`.

**Conventions:**
- Each test file extends `GutTest`
- `before_each()` / `after_each()` for setup/teardown — call `_reset_for_test()` on managers
- Test helpers on managers: `_inject_hero_for_test()`, `_inject_templates_for_test()`, `_clear_roster_for_test()`
- Assertions: `assert_eq()`, `assert_true()`, `assert_almost_eq()`, etc.

## Conventions

- GDScript throughout. No C# unless performance-critical.
- Screens build their UI in code (`_build_ui()`), not in the scene editor.
- Models in `models/` extend `Resource` (persistent, `@export` vars) or `RefCounted` (ephemeral).
- Static data loaded once at `_ready()` from JSON via `DataLoader`, cached in manager dictionaries.
- No direct manager-to-manager calls. Use EventBus signals.
- Resolvers are stateless static classes — no autoload registration.
- Feed event keys in `feed_events.json` must have at least a `DEFAULT` personality variant.
- Contract template IDs in JSON must be unique. Runtime IDs are generated as `"contract_{counter}_{template_id}"`.
