**GUILDRUNNER**

*Technical Design Document*

Version 0.2  ·  Post Design Review — Architecture & Systems Reference

*This document reflects design decisions made during the structured design review session. It supersedes v0.1. All data models, system designs, and architecture decisions have been updated to match confirmed game design.*

# **1\. Technology Stack**

## **1.1 Engine & Language**

Godot 4.x remains the target engine. GDScript is used for all gameplay logic; C\# is reserved for performance-critical systems only (e.g. save serialisation, batch outcome simulation). The 2D art direction decision removes all 3D rendering requirements — Godot's 2D pipeline is mature and well-suited to the hub scene and feed UI.

| Component | Choice | Notes |
| :---- | :---- | :---- |
| Engine | Godot 4.x | 2D pipeline only; no 3D scenes required at launch |
| Language | GDScript / C\# | GDScript for game logic; C\# for save and simulation systems |
| Persistence | SQLite | One .db file per save slot; JSON for static config data |
| UI Framework | Godot Control | Native Control tree; hub scene uses 2D Sprite nodes \+ Buttons |
| Art Pipeline | Aseprite / PNG | Sprite sheets for hero portraits; illustrated panels as static images |
| Source Control | Git | .gitignore configured for Godot 4 project structure |

## **1.2 Platform Targets**

* **PC (Windows / macOS / Linux)** — primary target for launch

* **Steam Deck** — supported via Linux build; controller nav required for all UI

* **Console** — post-launch stretch; not in v1 scope

# **2\. High-Level Architecture**

The game uses a Manager/Autoload architecture. Each Manager owns a slice of game state and exposes a public API. Cross-system communication flows through a global EventBus using named signals. Direct Manager-to-Manager references are avoided except where performance demands it.

| ┌──────────────────────────────────────────────────────────────┐ │                        GameManager                          │ │   FSM: MAIN\_MENU | GUILD\_HUB | MISSION\_BRIEFING |           │ │         MISSION\_AUTO | SIEGE | CUTSCENE | PAUSED            │ │                                                              │ │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │ │  │ GuildManager│  │MissionManager│  │  WorldManager    │   │ │  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │ │         │                │                    │             │ │  ┌──────▼──────┐  ┌──────▼───────┐  ┌────────▼─────────┐   │ │  │ HeroManager │  │ContractQueue │  │ FactionManager   │   │ │  └─────────────┘  └──────────────┘  └──────────────────┘   │ │         │                                                    │ │  ┌──────▼──────┐  ┌──────────────┐  ┌──────────────────┐   │ │  │  ItemManager│  │  TimeManager │  │  FeedManager     │   │ │  └─────────────┘  └──────────────┘  └──────────────────┘   │ │                                                              │ │              ┌──────────────────────┐                       │ │              │       EventBus        │                       │ │              └──────────────────────┘                       │ └──────────────────────────────────────────────────────────────┘ |
| :---- |

**NOTE**  *MISSION\_DIRECT is reserved in the FSM for future direct-play missions (post-launch). The architecture supports it without restructuring.*

## **2.1 Game State Machine**

| States:   MAIN\_MENU        — Title, save selection, settings   GUILD\_HUB        — Primary hub scene; all managers active   MORNING\_PHASE    — Day advance; contract delivery; building results   NIGHT\_PHASE      — Night event resolution (attacks, distress signals)   MISSION\_BRIEFING — Pre-dispatch: squad select, commitment, loadout   MISSION\_AUTO     — Feed active; one or more heroes dispatched   SIEGE            — Guild defence event; special feed rules apply   MISSION\_DIRECT   — (Reserved) Direct-play mode; post-launch   CUTSCENE         — Narrative sequence; input suppressed   PAUSED           — Overlay; time frozen |
| :---- |

## **2.2 TimeManager**

A new TimeManager autoload is introduced to own the day/night cycle. It tracks the current day number, the current phase (MORNING or NIGHT), and fires the appropriate events when the player advances time.

| \# TimeManager.gd (Autoload) var current\_day: int \= 1 var phase: DayPhase \= DayPhase.MORNING  \# MORNING | NIGHT var week\_number: int:     get: return ceil(current\_day / 7.0) func advance\_day():     \_resolve\_night\_events()         \# Process any pending night events     current\_day \+= 1     phase \= DayPhase.MORNING     EventBus.day\_advanced.emit(current\_day)     \_deliver\_morning\_contracts()    \# Trigger ContractQueue to generate     \_check\_weekly\_upkeep()          \# Deduct upkeep on week boundary func trigger\_night\_phase():     phase \= DayPhase.NIGHT     EventBus.night\_began.emit(current\_day)     \# Night events resolved by NightEventManager |
| :---- |

## **2.3 EventBus**

| \# EventBus.gd (Autoload) — confirmed signals \# Time signal day\_advanced(day: int) signal night\_began(day: int) signal week\_advanced(week: int) \# Heroes signal hero\_dispatched(hero\_id: String, mission\_id: String) signal hero\_returned(hero\_id: String, result: MissionResult) signal hero\_wounded(hero\_id: String, severity: InjurySeverity) signal hero\_killed(hero\_id: String, mission\_id: String) signal hero\_captured(hero\_id: String, mission\_id: String) signal hero\_trait\_acquired(hero\_id: String, trait\_id: String) signal hero\_morale\_changed(hero\_id: String, delta: float) \# Contracts signal contract\_available(contract\_id: String) signal contract\_accepted(contract\_id: String) signal contract\_completed(contract\_id: String, success: bool) signal contract\_expired(contract\_id: String, was\_consequential: bool) \# Feed signal feed\_event(mission\_id: String, event\_key: String, params: Dictionary) signal feed\_intervention\_available(mission\_id: String) signal intervention\_used(mission\_id: String, new\_commitment: CommitmentLevel) \# Faction signal reputation\_changed(faction\_id: String, delta: int, new\_tier: RepTier) signal faction\_became\_enemy(faction\_id: String) signal faction\_became\_ally(faction\_id: String) \# Guild signal upgrade\_built(upgrade\_id: String, tier: int) signal guild\_attacked(source: String, strength: int) signal gold\_changed(delta: int, new\_total: int) |
| :---- |

# **3\. Core Data Models**

All game entities are typed Resource classes. Static data (definitions, templates) is loaded from JSON at startup. Runtime state is serialised to SQLite on save. Changes from v0.1: HeroData now includes personality, bonds, and morale floor; FactionData uses tier-based reputation; BuildingData is a new model; FeedManager is new.

## **3.1 HeroData**

| class\_name HeroData extends Resource \# Identity @export var hero\_id: String @export var display\_name: String @export var archetype: HeroArchetype     \# FIGHTER | ROGUE | RANGER | SUPPORT @export var is\_legendary: bool           \# Hand-authored if true @export var portrait\_id: String          \# References portrait sprite sheet @export var bio: String                  \# Flavour; shown on stats screen \# Personality @export var personality\_type: PersonalityType \# STOIC | RECKLESS | LOYAL | CYNICAL | CHEERFUL | GRIM | CAUTIOUS | PROUD @export var personality\_blurb: String    \# 1-2 sentence description \# Attributes (0.0–100.0) @export var strength: float @export var agility: float @export var stealth: float @export var resilience: float @export var leadership: float \# Derived / runtime @export var morale: float                \# 0.0–100.0 @export var morale\_floor: float          \# Min morale (raised by traits) \# Status @export var status: HeroStatus \# AVAILABLE | ON\_MISSION | INJURED | RECOVERING | CAPTURED | DEAD @export var injury\_recovery\_days: int @export var current\_mission\_id: String \# Gear @export var equipped\_weapon: String      \# item\_id or empty @export var equipped\_armour: String @export var equipped\_accessory: String @export var bonded\_item\_ids: Array\[String\]  \# Items hero is attached to \# Relationships @export var bonds: Array\[HeroRelationship\]   \# Positive relationships @export var tensions: Array\[HeroRelationship\] \# Negative relationships \# History @export var missions\_completed: int @export var missions\_by\_type: Dictionary    \# MissionType \-\> count @export var stealth\_missions\_clean: int     \# No injury, stealth-primary @export var times\_wounded: int @export var kills: int @export var acquired\_traits: Array\[String\]  \# trait\_ids \# Dialogue @export var dialogue\_pool\_id: String    \# References dialogue bank entry |
| :---- |

## **3.2 HeroRelationship**

| class\_name HeroRelationship extends Resource @export var other\_hero\_id: String @export var relationship\_type: RelationshipType  \# BOND | TENSION @export var flavour\_text: String  \# e.g. 'Served together under the old king' \# Mechanical effects (applied when both heroes on same mission) @export var morale\_modifier: float   \# \+5.0 for bond, \-5.0 for tension @export var performance\_modifier: float  \# Small delta to outcome roll |
| :---- |

## **3.3 ContractData**

| class\_name ContractData extends Resource \# Identity @export var contract\_id: String @export var title: String @export var description: String @export var client\_faction\_id: String @export var client\_name: String @export var is\_consequential: bool     \# True \= rep hit on expiry/failure @export var is\_quest\_chain: bool @export var quest\_chain\_id: String @export var chain\_step: int @export var delivery\_type: DeliveryType  \# NOTICEBOARD | MESSENGER \# Classification @export var mission\_type: MissionType \# ELIMINATE | RETRIEVE | ESCORT | EXPLORE | DEFEND @export var difficulty: int            \# 1–5 @export var min\_heroes: int @export var recommended\_heroes: int \# Skill weights (0.0–1.0; used in outcome rolls) @export var weight\_strength: float @export var weight\_agility: float @export var weight\_stealth: float @export var weight\_resilience: float @export var weight\_leadership: float   \# Bonus when squad \> 1 \# Duration @export var base\_duration\_days: int    \# 1–5 @export var distance\_days: int         \# 0–2 added to base \# Rewards @export var reward\_gold: int @export var reward\_gold\_partial: int   \# Paid on PARTIAL result @export var reward\_item\_ids: Array\[String\] \# Consequences @export var rep\_on\_success: Dictionary     \# { faction\_id: delta } @export var rep\_on\_failure: Dictionary @export var rep\_on\_expiry: Dictionary      \# For consequential contracts @export var consequence\_on\_failure: String \# ConsequenceTemplate ID \# Timing @export var available\_from\_day: int @export var expiry\_day: int |
| :---- |

## **3.4 ItemData**

| class\_name ItemData extends Resource @export var item\_id: String @export var display\_name: String @export var item\_type: ItemType        \# WEAPON | ARMOUR | ACCESSORY @export var rarity: ItemRarity         \# COMMON | UNCOMMON | RARE | ARTEFACT @export var is\_magical: bool           \# Artefacts only; has passive\_effect\_id \# Stat modifiers (additive) @export var mod\_strength: float @export var mod\_agility: float @export var mod\_stealth: float @export var mod\_resilience: float \# Durability @export var max\_durability: int        \# Reduced by use; 0 \= broken @export var current\_durability: int \# Special @export var passive\_effect\_id: String  \# Empty unless is\_magical @export var is\_unique: bool @export var lore\_text: String |
| :---- |

## **3.5 FactionData & Reputation**

| class\_name FactionData extends Resource @export var faction\_id: String @export var display\_name: String @export var faction\_type: FactionType \# CROWN | CHURCH | MERCHANTS | UNDERWORLD | COMMON\_FOLK \# Reputation thresholds (numeric, internal only) @export var threshold\_enemy: int       \# Below this \= ENEMY tier @export var threshold\_unknown: int     \# Below this \= UNKNOWN tier @export var threshold\_neutral: int     \# Below this \= NEUTRAL tier @export var threshold\_trusted: int     \# Below this \= TRUSTED tier \# Above threshold\_trusted \= HONOURED \# Siege @export var siege\_aid\_at\_tier: RepTier \# TRUSTED or HONOURED to give aid @export var siege\_force\_strength: int  \# How strong their hostile force is \# Contract pool @export var contract\_pool: Array\[String\]  \# Template IDs \# ── Runtime (stored in FactionManager, not FactionData) ────── \# reputation\_score: int  (-100 to \+100) \# current\_tier: RepTier  (derived from score at runtime) |
| :---- |

| enum RepTier { ENEMY, UNKNOWN, NEUTRAL, TRUSTED, HONOURED } \# Tier display strings (localisation key \-\> display) const TIER\_LABELS \= {     RepTier.ENEMY:    "Enemy",     RepTier.UNKNOWN:  "Unknown",     RepTier.NEUTRAL:  "Neutral",     RepTier.TRUSTED:  "Trusted",     RepTier.HONOURED: "Honoured" } |
| :---- |

## **3.6 BuildingData**

| class\_name BuildingData extends Resource @export var building\_id: String \# BARRACKS | FORGE | INFIRMARY | TRAINING\_GROUNDS | TAVERN | GATEHOUSE @export var display\_name: String @export var current\_tier: int          \# 0 \= ruins, 1 \= basic, 2 \= improved @export var max\_tier: int              \# Always 2 at launch \# Costs per tier (index 0 \= build from ruins, index 1 \= upgrade to T2) @export var build\_costs\_gold: Array\[int\]   \# \[tier1\_cost, tier2\_cost\] @export var build\_time\_days: Array\[int\]    \# Days to construct each tier \# Visual @export var sprite\_ids: Array\[String\]  \# \[ruins, tier1, tier2\] sprite names @export var hub\_position: Vector2      \# Position in hub scene \# Effects applied on completion (processed by BuildingEffectProcessor) @export var tier1\_effects: Array\[Dictionary\] @export var tier2\_effects: Array\[Dictionary\] |
| :---- |

## **3.7 GuildState**

| class\_name GuildState extends Resource @export var gold: int @export var current\_day: int @export var overall\_reputation: int    \# Composite; used for content gating \# Buildings @export var building\_tiers: Dictionary  \# { building\_id: current\_tier } @export var buildings\_under\_construction: Array\[Dictionary\] \# { building\_id, target\_tier, completion\_day } \# Roster @export var hero\_ids: Array\[String\] @export var max\_roster\_size: int       \# Derived from Barracks tier \# Economy @export var weekly\_upkeep\_total: int   \# Recalculated on roster change @export var last\_upkeep\_day: int \# Intervention tokens @export var intervention\_tokens: int       \# Reset each morning @export var max\_intervention\_tokens: int   \# 0 if no Tavern; 1 T1; 2 T2 \# Active contracts @export var active\_contract\_ids: Array\[String\] @export var pending\_consequences: Array\[Dictionary\] |
| :---- |

# **4\. Core Systems**

## **4.1 Mission Resolution**

### **4.1.1 Outcome Roll**

The mission resolution pipeline is unchanged from v0.1 in structure, but updated to include the leadership weight for squad missions and resilience weighting for Defend/Escort types.

| func resolve\_mission(contract: ContractData, squad: Array\[HeroData\],                      commitment: CommitmentLevel) \-\> MissionResult:     var score := 0.0     for hero in squad:         var hs := 0.0         hs \+= hero.strength   \* contract.weight\_strength         hs \+= hero.agility    \* contract.weight\_agility         hs \+= hero.stealth    \* contract.weight\_stealth         hs \+= hero.resilience \* contract.weight\_resilience         hs \+= get\_item\_bonus(hero)         hs \+= get\_trait\_bonus(hero, contract.mission\_type)         score \+= hs     \# Leadership bonus for squads     if squad.size() \> 1:         var leader := get\_highest\_leadership(squad)         score \+= leader.leadership \* contract.weight\_leadership \* 0.5     \# Bond/tension modifiers     score \+= get\_relationship\_modifier(squad)     \# Average across squad     score /= squad.size()     \# Commitment modifier     var cm := { CommitmentLevel.AT\_ANY\_COST: 1.25,                 CommitmentLevel.USE\_JUDGEMENT: 1.0,                 CommitmentLevel.COME\_HOME\_SAFE: 0.75 }     score \*= cm\[commitment\]     \# Normalise against difficulty     var threshold := 40.0 \+ (contract.difficulty \- 1\) \* 10.0     \# Roll with noise     var roll := score \+ randf\_range(-15.0, 15.0)     if roll \>= threshold \+ 20: return MissionResult.FULL\_SUCCESS     if roll \>= threshold:      return MissionResult.SUCCESS     if roll \>= threshold \- 15: return MissionResult.PARTIAL     return MissionResult.FAILURE |
| :---- |

### **4.1.2 Injury, Death & Capture**

| \# Base injury chance by difficulty:  \[5%, 10%, 18%, 28%, 40%\] \# Commitment multiplier: COME\_HOME=0.5, USE\_JUDGEMENT=1.0, AT\_ANY\_COST=2.0 \# PARTIAL or FAILURE result: \+20% flat \# Resilience reduction: \-0.2% per point above 50 \# \# If injury check passes: \#   Severity roll: MINOR (60%) | SERIOUS (30%) | CRITICAL (10%) \#   SERIOUS injury \= extended recovery (3–5 days) \#   CRITICAL injury \= near-death; chance of permanent attribute loss \# \# Death only rolls on CRITICAL injury: \#   Base death chance: 15% \#   AT\_ANY\_COST modifier: x2.0 \#   Resilience modifier: \-0.3% per point above 50 \# \# Capture rolls on FAILURE result (not death): \#   Base capture chance: 20% on FAILURE \#   Raised to 40% if hero would have died but death roll fails \#   Hero status set to CAPTURED; rescue contract generated |
| :---- |

### **4.1.3 Hero Death Presentation**

| \# When hero\_killed signal fires: \# 1\. FeedManager pauses the active feed \# 2\. DeathCardScreen pushed to UI stack \# 3\. Card displays: \#    \- Hero portrait (large) \#    \- Hero name \+ archetype \#    \- Missions completed \#    \- Generated epitaph (from personality \+ death context template) \#    \- Cause of death \# 4\. Player must dismiss before feed resumes \# 5\. Hero status set to DEAD in HeroManager \# 6\. Death logged permanently to mission\_log table |
| :---- |

## **4.2 The Auto-Resolve Feed**

### **4.2.1 FeedManager**

FeedManager is a new autoload that owns the feed state for all active missions. It receives feed\_event signals from MissionManager, sequences them with appropriate timing, and pushes display data to the FeedScreen UI.

| \# FeedManager.gd (Autoload) var active\_feeds: Dictionary  \# { mission\_id: FeedState } class FeedState:     var mission\_id: String     var hero\_id: String     var colour\_index: int      \# Assigned on dispatch; 0–5     var events: Array\[FeedEvent\]     var is\_paused: bool        \# True during death card or intervention     var intervention\_available: bool func on\_hero\_dispatched(hero\_id: String, mission\_id: String):     var state := FeedState.new()     state.mission\_id \= mission\_id     state.hero\_id \= hero\_id     state.colour\_index \= \_next\_colour\_index()     active\_feeds\[mission\_id\] \= state func push\_event(mission\_id: String, event\_key: String, params: Dictionary):     var text := \_format\_event(event\_key, params)     var entry := FeedEvent.new(mission\_id, text, params.get('is\_illustrated', false))     active\_feeds\[mission\_id\].events.append(entry)     EventBus.feed\_event.emit(mission\_id, event\_key, params) |
| :---- |

### **4.2.2 Intervention System**

| \# Interventions are gated by GuildState.intervention\_tokens \# Tokens reset each morning (MORNING\_PHASE) \# Token count \= Tavern tier (0 if no Tavern, 1 at T1, 2 at T2) \# \# Intervention prompt fires when: \#   \- Hero is wounded mid-mission \#   \- Hero reaches a decision point (defined in contract template) \#   \- Hero's outcome is trending toward failure on mid-mission roll \# func attempt\_intervention(mission\_id: String,                           new\_commitment: CommitmentLevel) \-\> bool:     var guild := GuildManager.get\_state()     if guild.intervention\_tokens \<= 0:         return false     guild.intervention\_tokens \-= 1     MissionManager.update\_commitment(mission\_id, new\_commitment)     EventBus.intervention\_used.emit(mission\_id, new\_commitment)     return true |
| :---- |

### **4.2.3 Feed Event Templates**

Event text is generated from templates in feed\_events.json, with personality-variant entries for key event types. The personality\_type of the hero selects the appropriate variant pool.

| \# feed\_events.json (excerpt showing personality variants) {   "hero\_wounded": {     "default":  "{hero} takes a wound — pressing on regardless.",     "RECKLESS": "{hero} takes a wound and grins. Pushes harder.",     "CAUTIOUS": "{hero} is wounded. Hesitates, but holds the line.",     "STOIC":    "{hero} is wounded. No visible change in pace."   },   "hero\_killed": {     "default":  "{hero} has been killed in action."   },   "combat\_kill": {     "default":  "{hero} cuts down the {enemy\_type}.",     "LOYAL":    "{hero} drives through. The {enemy\_type} falls."   },   "bond\_event": {     "default":  "{hero} and {other} cover each other. Neither takes a hit."   },   "tension\_event": {     "default":  "{hero} hesitates — {other} is close. A moment of friction."   },   "objective\_complete": {     "default":  "Objective complete. {hero} is heading back.",     "CYNICAL":  "Done. {hero} doesn't hang around."   } } |
| :---- |

## **4.3 Contract Board System**

### **4.3.1 Contract Generation**

ContractQueue generates contracts each morning. Standard contracts are procedural; quest chain contracts are injected by QuestManager at scripted day thresholds. Messenger-delivered contracts are flagged in their template and trigger the messenger event in the hub scene.

| func on\_morning\_phase(day: int):     expire\_old\_contracts(day)     \_inject\_quest\_chain\_contracts(day)   \# QuestManager provides these     var target := get\_target\_board\_size(day)  \# Phase-based scaling     var deficit := target \- active\_contracts.size()     for i in range(max(deficit, 0)):         var contract := \_generate\_contract(day)         active\_contracts.append(contract)         if contract.delivery\_type \== DeliveryType.MESSENGER:             EventBus.messenger\_arrived.emit(contract.contract\_id)         else:             EventBus.contract\_available.emit(contract.contract\_id) |
| :---- |

### **4.3.2 Board Size by Phase**

| Phase | Days | Board Size | Notes |
| :---- | :---- | :---- | :---- |
| Early | 1–20 | 2–3 | Slow pace; first buildings go up |
| Mid | 21–60 | 4–6 | Juggling begins; first raid occurs |
| Pre-Siege | 61–80 | 5–7 | Pressure peaks; preparation critical |
| Post-Siege | 80+ | 3–5 | Returns to sustainable pace |

## **4.4 Economy System**

### **4.4.1 Weekly Upkeep**

| \# Upkeep deducted every 7 days in advance\_day() \# Base cost per hero by archetype: \#   Fighter:  8 gold/week \#   Rogue:    7 gold/week \#   Ranger:   7 gold/week \#   Support:  6 gold/week \#   Legendary hero: \+3 gold/week flat bonus \# \# If gold \< upkeep\_total: \#   Debt accumulates \#   Hero morale decreases (-5 per week unpaid) \#   Heroes may leave if morale hits floor while unpaid (2+ weeks) |
| :---- |

### **4.4.2 Gold Sinks**

| \# Healing (Infirmary) \#   Minor injury:   free (2-day natural recovery) \#   Serious injury: 15–25 gold (Infirmary required for fast track) \#   Critical injury: 40–60 gold \# \# Training (Training Grounds required) \#   1 training session: 20 gold; takes 1 day; hero unavailable \#   Grants \+2–5 to a single attribute within archetype range \# \# Construction \#   Tier 1 build: 150–300 gold (varies by building) \#   Tier 2 upgrade: 300–600 gold \# \# Hero recruitment \#   Common hero:   30–60 gold \#   Rare hero:     80–150 gold \#   Legendary:     not purchasable; unlocked via quests \# \# Mercenary siege support \#   Light force:   200 gold \#   Heavy force:   500 gold |
| :---- |

## **4.5 Faction & Reputation System**

| \# FactionManager.gd (Autoload) var \_scores: Dictionary  \# { faction\_id: int }  range: \-100 to \+100 var \_tiers: Dictionary   \# { faction\_id: RepTier }  derived func apply\_delta(faction\_id: String, delta: int):     var prev\_score := \_scores\[faction\_id\]     var prev\_tier  := \_tiers\[faction\_id\]     \_scores\[faction\_id\] \= clamp(prev\_score \+ delta, \-100, 100\)     \_tiers\[faction\_id\]  \= \_score\_to\_tier(faction\_id, \_scores\[faction\_id\])     EventBus.reputation\_changed.emit(faction\_id, delta, \_tiers\[faction\_id\])     \# Check tier crossings     if prev\_tier \!= RepTier.ENEMY and \_tiers\[faction\_id\] \== RepTier.ENEMY:         \_schedule\_hostile\_consequence(faction\_id)         EventBus.faction\_became\_enemy.emit(faction\_id)     elif prev\_tier \< RepTier.HONOURED and \_tiers\[faction\_id\] \== RepTier.HONOURED:         EventBus.faction\_became\_ally.emit(faction\_id) func \_score\_to\_tier(faction\_id: String, score: int) \-\> RepTier:     var f := FactionDB.get(faction\_id)     if score \< f.threshold\_enemy:   return RepTier.ENEMY     if score \< f.threshold\_unknown: return RepTier.UNKNOWN     if score \< f.threshold\_neutral: return RepTier.NEUTRAL     if score \< f.threshold\_trusted: return RepTier.TRUSTED     return RepTier.HONOURED |
| :---- |

## **4.6 Building System**

| \# BuildingManager.gd (Autoload) func begin\_construction(building\_id: String, target\_tier: int) \-\> bool:     var building := \_buildings\[building\_id\]     var cost := building.build\_costs\_gold\[target\_tier \- 1\]     if GuildManager.get\_state().gold \< cost:         return false     GuildManager.deduct\_gold(cost)     var completion\_day := TimeManager.current\_day \+ building.build\_time\_days\[target\_tier \- 1\]     \_construction\_queue.append({         "building\_id": building\_id,         "target\_tier": target\_tier,         "completion\_day": completion\_day     })     return true func on\_day\_advanced(day: int):     for job in \_construction\_queue.duplicate():         if day \>= job.completion\_day:             \_complete\_construction(job.building\_id, job.target\_tier)             \_construction\_queue.erase(job) func \_complete\_construction(building\_id: String, tier: int):     \_buildings\[building\_id\].current\_tier \= tier     BuildingEffectProcessor.apply\_effects(building\_id, tier)     \_update\_hub\_scene\_visual(building\_id, tier)  \# Swap sprite     EventBus.upgrade\_built.emit(building\_id, tier) |
| :---- |

## **4.7 Hero Trait System**

| \# Trait evaluation runs each time a hero returns from a mission \# and on day advance for time-based conditions func evaluate\_traits(hero: HeroData):     for trait\_def in TraitDB.get\_all():         if hero.acquired\_traits.has(trait\_def.id):             continue  \# Already acquired         if \_evaluate\_condition(hero, trait\_def.trigger):             \_award\_trait(hero, trait\_def) func \_award\_trait(hero: HeroData, trait\_def: TraitData):     hero.acquired\_traits.append(trait\_def.id)     for effect in trait\_def.effects:         \_apply\_trait\_effect(hero, effect)     EventBus.hero\_trait\_acquired.emit(hero.hero\_id, trait\_def.id) \# trait\_definitions.json (excerpt) \# { \#   'id': 'shadow\_step', \#   'trigger': 'stealth\_missions\_clean \>= 5', \#   'effects': \[{ 'attribute': 'stealth', 'modifier': 12.0 }\] \# } |
| :---- |

# **5\. Save & Persistence**

## **5.1 Schema**

| \# SQLite tables (v0.2) heroes          (hero\_id TEXT PK, archetype TEXT, status TEXT,                  attributes\_json TEXT, personality\_json TEXT,                  gear\_json TEXT, bonds\_json TEXT, traits\_json TEXT,                  history\_json TEXT, current\_mission\_id TEXT) items           (item\_id TEXT PK, definition\_id TEXT, owner\_hero\_id TEXT,                  current\_durability INT, is\_bonded INT) contracts       (contract\_id TEXT PK, definition\_id TEXT, state TEXT,                  assigned\_hero\_ids\_json TEXT, day\_accepted INT) guild\_state     (key TEXT PK, value TEXT) \# Keys: gold, current\_day, overall\_rep, intervention\_tokens, \#        max\_roster\_size, last\_upkeep\_day, game\_mode building\_state  (building\_id TEXT PK, current\_tier INT,                  under\_construction INT, completion\_day INT) faction\_rep     (faction\_id TEXT PK, score INT, tier TEXT) world\_events    (event\_id TEXT PK, day\_triggered INT,                  resolved INT, event\_type TEXT, data\_json TEXT) mission\_log     (entry\_id TEXT PK, day INT, hero\_id TEXT,                  contract\_id TEXT, result TEXT, feed\_json TEXT) schema\_version  (version INT) |
| :---- |

## **5.2 Save Strategy**

* **Autosave** — triggered on every day advance and after each mission result

* **Manual save** — available at any time from the Guild Hub in Standard mode only

* **Three save slots** — each an independent .db file

* **Ironman mode** — single autosave slot; manual save disabled; game\_mode field \= 'IRONMAN'

# **6\. UI Architecture**

## **6.1 Hub Scene Structure**

The guild hub is a Godot scene (GuildHubScene.tscn) containing a large illustrated background sprite and interactive hotspot nodes (Button or Area2D) for each building and the contract noticeboard. Clicking a hotspot opens the relevant screen. As buildings are upgraded, the hub background is swapped or composited to show the new state.

| res://scenes/   hub/     GuildHubScene.tscn          \# Main interactive scene     HubBackground.png           \# Base (all ruins)     sprites/       barracks\_t0.png           \# Ruins state       barracks\_t1.png           \# Tier 1 built       barracks\_t2.png           \# Tier 2 improved       forge\_t0.png ... t2.png       infirmary\_t0.png ... t2.png       training\_t0.png ... t2.png       tavern\_t0.png ... t2.png       gatehouse\_t0.png ... t2.png res://ui/screens/   ContractBoardScreen.tscn   HeroRosterScreen.tscn   HeroDetailScreen.tscn         \# Stats, traits, gear, relationships   MissionBriefingScreen.tscn   FeedScreen.tscn               \# Multi-column auto-resolve feed   DeathCardScreen.tscn          \# Hero death memorial   BuildingScreen.tscn           \# Build/upgrade menu   FactionScreen.tscn            \# Reputation panel   LogScreen.tscn                \# Event history   InventoryScreen.tscn res://ui/components/   HeroPortraitCard.tscn   FeedColumn.tscn               \# Single mission feed column   FeedEntry.tscn                \# Individual event line   ContractCard.tscn   ReputationTierBadge.tscn   BuildingSlot.tscn   InterventionPrompt.tscn |
| :---- |

## **6.2 Feed Screen Layout**

FeedScreen displays up to six simultaneous mission feeds in colour-coded columns. Each column shows the mission name, the assigned hero portrait, and a scrolling list of FeedEntry nodes. Illustrated event panels appear inline within the column at full column width when triggered. The intervention prompt appears as an overlay on the relevant column when available.

| FeedScreen ├── HBoxContainer (columns) │   ├── FeedColumn \[BLUE\]   — Mission: The Bandit Road │   │   ├── HeroPortraitCard (Aldric) │   │   ├── ScrollContainer │   │   │   └── VBoxContainer │   │   │       ├── FeedEntry (text) │   │   │       ├── IllustratedPanel (on key events) │   │   │       └── FeedEntry (text) │   │   └── InterventionPrompt (shown when available) │   ├── FeedColumn \[GREEN\]  — Mission: The Missing Merchant │   └── FeedColumn \[AMBER\]  — Mission: The Old Mill └── HUDBar (gold counter, day, token count, pause button) |
| :---- |

## **6.3 Data Binding**

Screens receive view-model objects on open and emit signals upward to UIManager, which translates them to Manager calls. Screens never directly mutate game state.

# **7\. Content & Data Pipeline**

| res://data/   contracts/     contract\_templates.json     quest\_chains.json   heroes/     starting\_heroes.json        \# 3 hand-authored starters     legendary\_heroes.json       \# All hand-authored legendaries     hero\_archetypes.json        \# Procedural generation templates     name\_pools.json     personality\_types.json     trait\_definitions.json     relationship\_presets.json   \# Preset bond/tension pairs   world/     factions.json     consequence\_templates.json     night\_event\_templates.json   items/     items.json     artefacts.json              \# Magical items; separate pool     loot\_tables.json   buildings/     buildings.json     building\_effects.json   feed/     feed\_events.json     siege\_feed\_events.json      \# Extended dramatic pool for siege   dialogue/     hero\_dialogue\_banks.json    \# Keyed by personality\_type     messenger\_scripts.json   localisation/     en.json |
| :---- |

# **8\. Testing & Quality**

## **8.1 Unit Tests (GUT)**

* **MissionResolutionTest** — outcome, injury, death, capture across all difficulty/commitment combinations

* **RelationshipModifierTest** — bond/tension effects on outcome and morale

* **FactionReputationTest** — delta, tier transitions, hostile/ally events

* **ContractQueueTest** — board scaling, expiry, consequential contract handling

* **BuildingEffectTest** — effect application, intervention token recalculation

* **EconomyTest** — upkeep deduction, debt morale effects, gold sinks

* **SaveMigrationTest** — round-trip serialise/deserialise, migration correctness

## **8.2 Balance Simulation**

| \# Headless simulation — 500 runs, output metrics CSV godot \--headless \--script tools/sim\_runner.gd \-- \--runs 500 \--seed 42 \# Key output metrics: \# \- Hero death rate per run \# \- Gold per day average \# \- Contract success rate by type and difficulty \# \- Faction tier distribution at siege \# \- Day of first/second raid and final siege \# \- Intervention token usage rate \# \- Most common cause of hero death |
| :---- |

# **9\. Open Technical Questions**

* Siege leader identity: Coalition model is leading candidate. ConsequenceSystem needs to track cumulative faction hostility to determine coalition composition. Implementation deferred pending narrative sign-off.

* Night event frequency and types: Template list and trigger conditions need full authoring. Rough target: 1 night event per 5–7 days in mid-game, scaling with hostility level.

* Illustrated feed panels: Art spec needed. Target is 3–5 reusable scene illustrations (cave entrance, battle, discovery, retreat, death) with hero portrait composited in. Scope to be confirmed with art pipeline.

* Messenger animation: Does the messenger arrival trigger a brief animation in the hub scene, or just a notification? Animation adds polish but increases art scope.

* Post-siege content expansion: DLC architecture via additive JSON packs. Confirm that no schema changes are needed before locking the save schema.

* Direct-play missions (post-launch): Reserved as MISSION\_DIRECT in FSM. EnemyData model, ActionSystem, and MissionScene architecture deferred. Will require a separate TDD addendum when scoped.

*— End of Document —*