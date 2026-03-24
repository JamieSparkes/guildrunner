## Static definition for a guild building. Runtime tier is tracked in GuildState.
class_name BuildingData extends Resource

@export var building_id: String = ""
## BARRACKS | FORGE | INFIRMARY | TRAINING_GROUNDS | TAVERN | GATEHOUSE
@export var display_name: String = ""
## Current built tier. 0 = ruins (unbuilt). Stored in GuildState at runtime.
@export var current_tier: int = 0
@export var max_tier: int = 2

# ── Costs ─────────────────────────────────────────────────────────────────────
## Index 0 = cost to build Tier 1 from ruins; index 1 = cost to upgrade to Tier 2.
@export var build_costs_gold: Array[int] = []
@export var build_time_days: Array[int] = []

# ── Visuals ───────────────────────────────────────────────────────────────────
## Sprite names: [ruins, tier1, tier2]. Maps to res://scenes/hub/sprites/{id}.png
@export var sprite_ids: Array[String] = []
## Position of the building hotspot in the hub scene (pixels from top-left).
@export var hub_position: Vector2 = Vector2.ZERO

# ── Effects ───────────────────────────────────────────────────────────────────
## Array of effect Dictionaries applied when Tier 1 is completed.
## Each entry: { "type": String, "value": Variant }
@export var tier1_effects: Array[Dictionary] = []
@export var tier2_effects: Array[Dictionary] = []
