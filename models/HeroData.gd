## Runtime data for a single hero. Persisted to the heroes SQLite table.
class_name HeroData extends Resource

# ── Identity ──────────────────────────────────────────────────────────────────
@export var hero_id: String = ""
@export var display_name: String = ""
@export var archetype: Enums.HeroArchetype = Enums.HeroArchetype.FIGHTER
@export var is_legendary: bool = false
## References a key in the portrait sprite sheet atlas.
@export var portrait_id: String = ""
@export var bio: String = ""

# ── Personality ───────────────────────────────────────────────────────────────
@export var personality_type: Enums.PersonalityType = Enums.PersonalityType.STOIC
## 1–2 sentence description shown on the stats screen.
@export var personality_blurb: String = ""

# ── Attributes (0.0 – 100.0) ─────────────────────────────────────────────────
@export var strength: float = 0.0
@export var agility: float = 0.0
@export var stealth: float = 0.0
@export var resilience: float = 0.0
@export var leadership: float = 0.0

# ── Derived / Runtime ─────────────────────────────────────────────────────────
## Current morale 0.0–100.0.
@export var morale: float = 80.0
## Minimum morale; raised by certain traits.
@export var morale_floor: float = 20.0

# ── Status ────────────────────────────────────────────────────────────────────
@export var status: Enums.HeroStatus = Enums.HeroStatus.AVAILABLE
## Days remaining until recovery is complete (INJURED / RECOVERING).
@export var injury_recovery_days: int = 0
## Empty string if not on a mission.
@export var current_mission_id: String = ""

# ── Gear ──────────────────────────────────────────────────────────────────────
## item_id of equipped weapon, or "" if none.
@export var equipped_weapon: String = ""
@export var equipped_armour: String = ""
@export var equipped_accessory: String = ""
## item_ids of items the hero has become attached to.
@export var bonded_item_ids: Array[String] = []

# ── Relationships ─────────────────────────────────────────────────────────────
@export var bonds: Array[HeroRelationship] = []
@export var tensions: Array[HeroRelationship] = []

# ── History ───────────────────────────────────────────────────────────────────
@export var missions_completed: int = 0
## Maps MissionType (int) -> count.
@export var missions_by_type: Dictionary = {}
## Missions completed with stealth primary, no injury.
@export var stealth_missions_clean: int = 0
@export var times_wounded: int = 0
@export var kills: int = 0
## List of acquired trait_ids.
@export var acquired_traits: Array[String] = []

# ── Dialogue ──────────────────────────────────────────────────────────────────
## References an entry key in hero_dialogue_banks.json.
@export var dialogue_pool_id: String = ""
