## Data for a single item instance in the guild inventory or equipped by a hero.
class_name ItemData extends Resource

@export var item_id: String = ""
## Unique instance ID (generated at runtime; item_id is the definition reference).
@export var instance_id: String = ""
@export var display_name: String = ""
@export var item_type: Enums.ItemType = Enums.ItemType.WEAPON
@export var rarity: Enums.ItemRarity = Enums.ItemRarity.COMMON
## Artefacts only — carries an unexplained magical property.
@export var is_magical: bool = false

# ── Stat Modifiers (additive) ─────────────────────────────────────────────────
@export var mod_strength: float = 0.0
@export var mod_agility: float = 0.0
@export var mod_stealth: float = 0.0
@export var mod_resilience: float = 0.0

# ── Durability ────────────────────────────────────────────────────────────────
## Reduced on use. 0 = broken; needs Forge repair.
@export var max_durability: int = 10
@export var current_durability: int = 10

# ── Special ───────────────────────────────────────────────────────────────────
## ID of passive effect definition. Empty unless is_magical.
@export var passive_effect_id: String = ""
## Unique items cannot appear more than once in the world.
@export var is_unique: bool = false
@export var lore_text: String = ""
