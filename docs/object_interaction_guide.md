# Guildrunner Object Interaction Guide

This guide maps every major game object in the current codebase to:

- **How it is created/owned**
- **What inputs it receives**
- **What side effects it produces**
- **What other objects it talks to**

---

## 1) Core Interaction Pattern (How objects communicate)

Guildrunner follows an event-driven architecture:

1. UI object emits a `cmd_*` signal on `EventBus`.
2. `AppController` receives the command and delegates to a manager.
3. Domain managers mutate runtime state/resources.
4. Managers emit result/status signals via `EventBus`.
5. UI listens to those signals and refreshes views.

This keeps UI and gameplay logic decoupled.

---

## 2) Global Singleton Objects (Autoloads)

These are always alive and are the primary runtime objects.

### `EventBus`
- **Role:** Global signal hub.
- **Receives:** Signals emitted by all systems.
- **Emits:** Time, hero, contract, feed, faction, guild, state, and command/result signals.
- **Used by:** Essentially every manager and screen.

### `AppController`
- **Role:** Command executor.
- **Listens for:**
  - `cmd_start_new_game`
  - `cmd_transition_state`
  - `cmd_open_screen`
  - `cmd_close_top_screen`
  - `cmd_clear_screens`
  - `cmd_dispatch_contract`
  - `cmd_begin_construction`
  - `cmd_use_intervention`
- **Delegates to:** `GameManager`, `UIManager`, `MissionManager`, `ContractQueue`, `BuildingManager`, `GuildManager`.
- **Emits results:** mission dispatch/building/intervention result signals.

### `GameManager`
- **Role:** Finite state machine for game phases.
- **Key interaction:** `transition_to(new_state)` validates legal transitions and emits `state_changed`.
- **New game flow:** resets all manager runtime states, sets state to hub, then changes scene to guild hub.

### `UIManager`
- **Role:** Overlay screen stack manager.
- **Interaction API:** `push_screen`, `pop_screen`, `clear_screens`.
- **Screen IDs:** `contract_board`, `mission_briefing`, `feed`, `hero_roster`, `hero_detail`, `building`.

### `TimeManager`
- **Role:** Day/week clock object.
- **Key interactions:**
  - `advance_day()` emits `day_advanced`, morning delivery, weekly upkeep checks.
  - `trigger_night_phase()` emits `night_began`.

### `GuildManager`
- **Role:** Owns `GuildState` and guild economy/tokens.
- **Interactions:**
  - Gold add/deduct APIs (`gold_changed`).
  - Weekly upkeep calculation and morale penalties.
  - Daily intervention token reset.

### `HeroManager`
- **Role:** Owns all runtime `HeroData` objects.
- **Interactions:**
  - Lookup/availability queries for UI and mission dispatch.
  - Status transitions (`AVAILABLE`, `ON_MISSION`, `INJURED`, etc.).
  - Injury/death/capture methods that emit corresponding hero signals.
  - Day tick recovery updates.

### `MissionManager`
- **Role:** Mission lifecycle orchestrator.
- **Interactions:**
  - `dispatch_heroes` validates hero availability and creates active mission objects.
  - Emits feed events for mission narrative.
  - Resolves missions on completion day and applies rewards/outcomes.
  - Uses `MissionResolver` and `InjuryResolver` for outcome math.

### `ContractQueue`
- **Role:** Contract board object store.
- **Interactions:**
  - On each morning: expire old contracts, generate new contracts.
  - Emits `contract_available` and `contract_expired`.
  - Removes contract on acceptance.

### `BuildingManager`
- **Role:** Building upgrade and queue manager.
- **Interactions:**
  - `begin_construction(building_id)` validates state/cost and queues build.
  - On day advance, completes due entries and applies effects via `BuildingEffectProcessor`.
  - Emits `building_construction_started` and `upgrade_built`.

### `FeedManager`
- **Role:** Mission feed event object manager.
- **Interactions:**
  - Receives raw `feed_event` signal and converts it to runtime `FeedEvent` objects.
  - Applies template formatting, color routing, and intervention trigger checks.
  - Stores per-mission feeds + day buffer.

### `ItemManager` and `FactionManager`
- **Role (current milestone):** Placeholders with interface comments only.
- **Expected future interaction:** Inventory/equipment and dynamic reputation tiers.

---

## 3) Runtime Data Objects (models)

These are structured resource/value objects moved between managers and UI.

### `HeroData`
- Identity, personality, stats, morale, status, gear, relationship, and mission history object.
- Primary owner: `HeroManager`.

### `ContractData`
- Contract definition/runtime instance object (difficulty, duration, rewards, consequences).
- Primary owner: `ContractQueue`; consumed by `MissionManager` and briefing UI.

### `BuildingData`
- Static building definition object (costs, times, effects, hub metadata).
- Read by `BuildingManager` and building UI slots.

### `GuildState`
- Global mutable guild object (gold, tiers, construction queue, intervention tokens, upkeep, flags).
- Primary owner: `GuildManager`.

### `ItemData`
- Item instance/definition object (type, rarity, stats, durability, passive effects).
- Future owner: `ItemManager` systems.

### `FactionData`
- Faction definition object (thresholds, aid behavior, contract pool).
- Future owner: `FactionManager` runtime logic.

### `TraitData`
- Trait definition object with trigger + effects.
- Expected owner: trait progression/evaluator systems.

### `FeedEvent`
- Lightweight runtime feed entry object (text, key, mission/day, color).
- Owner: `FeedManager`; rendered by feed UI components.

---

## 4) Player-Facing Interactable Objects

These are the objects players directly click/use.

### Main menu object
- **UI object:** `MainMenuScreen`
- **Interactions:**
  - `New Game` → emits `cmd_start_new_game`
  - `Quit` → exits game tree

### Hub action objects (`GuildHubScene` buttons)
- **Contract Board** → `cmd_open_screen("contract_board", {})`
- **Hero Roster** → `cmd_open_screen("hero_roster", {})`
- **Mission Feed** → `cmd_open_screen("feed", {})`
- **Building buttons** → `cmd_open_screen("building", {})`
- **Advance Day** → `cmd_transition_state(MORNING_PHASE)`

### Contract board objects
- **UI object:** `ContractBoardScreen`
- **Child object:** `ContractCard`
- **Interaction:** selecting card opens mission briefing with selected `ContractData`.

### Mission briefing objects
- **UI object:** `MissionBriefingScreen`
- **Child object:** `HeroPortraitCard`
- **Interactions:**
  - Toggle heroes to build dispatch party.
  - Set commitment level.
  - Dispatch emits `cmd_dispatch_contract(contract, hero_ids, commitment)`.

### Mission feed objects
- **UI object:** `FeedScreen`
- **Child objects:** `FeedEntry`, `InterventionPrompt`
- **Interactions:**
  - Renders day buffer or full history.
  - If intervention trigger exists, embeds prompt objects inline.

### Building management objects
- **UI object:** `BuildingScreen`
- **Child object:** `BuildingSlot`
- **Interactions:**
  - Slot computes tier/status/cost/ETA from managers.
  - Build/Upgrade emits `build_requested(building_id)`.
  - Screen forwards to `cmd_begin_construction(building_id)`.

---

## 5) End-to-End Interaction Flows by Object Group

### Flow A: Start game
1. `MainMenuScreen` emits `cmd_start_new_game`.
2. `AppController` calls `GameManager.start_new_game()`.
3. Managers reset runtime state.
4. Scene changes to `GuildHubScene`.
5. Hub emits morning signal to seed contract board.

### Flow B: Dispatch contract
1. Player opens Contract Board and selects a `ContractCard`.
2. Mission briefing opens with `ContractData`.
3. Player picks hero objects + commitment.
4. Dispatch command reaches `AppController`.
5. `MissionManager` creates active mission object and marks heroes `ON_MISSION`.
6. `ContractQueue` removes accepted contract.

### Flow C: Advance day and resolve
1. Player clicks `Advance Day`.
2. Game enters morning phase and calls `TimeManager.advance_day()`.
3. Day listeners tick:
   - `ContractQueue` expires/refills contracts.
   - `MissionManager` resolves missions whose completion day has arrived.
   - `BuildingManager` completes upgrades due that day.
   - `HeroManager` heals injury days.
4. `FeedManager` buffers generated feed events.
5. If day feed exists, hub auto-opens feed report screen.

### Flow D: Build/upgrade
1. Player opens Building screen and clicks slot build/upgrade.
2. Command reaches `BuildingManager.begin_construction`.
3. Gold deducted via `GuildManager` if affordable.
4. Queue entry added with `completion_day`.
5. On future day advance, completion applies effects + emits upgrade event.

---

## 6) Quick Object-to-Object Dependency Matrix

- **UI screens** → emit commands to **EventBus**.
- **AppController** → translates command signals into manager API calls.
- **Managers** → read/write runtime model objects and emit domain signals.
- **FeedManager/UIManager** → convert domain output into visible UI history.
- **GuildState/HeroData/ContractData/etc.** → shared data objects that move through the manager layer.

If you add a new object, plug it into this pattern:
`UI intent -> EventBus cmd -> AppController/Manager API -> EventBus domain signal -> UI refresh`.
