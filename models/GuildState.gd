## The guild's runtime state. Single instance owned by GuildManager.
## Autosaved to guild_state and building_state SQLite tables.
class_name GuildState extends Resource

# ── Economy ───────────────────────────────────────────────────────────────────
@export var gold: int = 200
@export var current_day: int = 1
## Composite reputation used for content gating (not shown directly to player).
@export var overall_reputation: int = 0

# ── Buildings ─────────────────────────────────────────────────────────────────
## { building_id: current_tier }
@export var building_tiers: Dictionary = {}
## [{ "building_id": String, "target_tier": int, "completion_day": int }]
@export var buildings_under_construction: Array[Dictionary] = []

# ── Roster ────────────────────────────────────────────────────────────────────
@export var hero_ids: Array[String] = []
## Set by Barracks tier. Tier 1 = 6, Tier 2 = 12. Default = 6.
@export var max_roster_size: int = 6

# ── Economy ───────────────────────────────────────────────────────────────────
## Recalculated whenever roster changes. Deducted weekly.
@export var weekly_upkeep_total: int = 0
@export var last_upkeep_day: int = 0

# ── Interventions ─────────────────────────────────────────────────────────────
## Remaining tokens today. Reset each morning.
@export var intervention_tokens: int = 0
## 0 = no Tavern; 1 = Tavern T1; 2 = Tavern T2.
@export var max_intervention_tokens: int = 0

# ── Building effects ──────────────────────────────────────────────────────────
## Days subtracted from injury recovery time. Set by Infirmary.
@export var recovery_day_reduction: int = 0
## Catch-all for future building effects (enable_*, multipliers, siege bonuses).
@export var building_flags: Dictionary = {}

# ── Contracts ─────────────────────────────────────────────────────────────────
@export var active_contract_ids: Array[String] = []
## Pending faction consequences awaiting resolution.
@export var pending_consequences: Array[Dictionary] = []

# ── Save Metadata ─────────────────────────────────────────────────────────────
## "STANDARD" or "IRONMAN"
@export var game_mode: String = "STANDARD"
