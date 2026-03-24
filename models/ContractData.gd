## Data for a single available or active contract.
## Static definition loaded from contract_templates.json; runtime fields set by ContractQueue.
class_name ContractData extends Resource

# ── Identity ──────────────────────────────────────────────────────────────────
@export var contract_id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var client_faction_id: String = ""
@export var client_name: String = ""
## Consequential contracts cause a reputation hit on expiry/failure.
@export var is_consequential: bool = false
@export var is_quest_chain: bool = false
@export var quest_chain_id: String = ""
@export var chain_step: int = 0
@export var delivery_type: Enums.DeliveryType = Enums.DeliveryType.NOTICEBOARD

# ── Classification ────────────────────────────────────────────────────────────
@export var mission_type: Enums.MissionType = Enums.MissionType.ELIMINATE
## 1 (trivial) – 5 (extremely dangerous).
@export var difficulty: int = 1
@export var min_heroes: int = 1
@export var recommended_heroes: int = 1

# ── Skill Weights (0.0 – 1.0) ────────────────────────────────────────────────
## Used in outcome roll. Sum need not equal 1.0.
@export var weight_strength: float = 0.0
@export var weight_agility: float = 0.0
@export var weight_stealth: float = 0.0
@export var weight_resilience: float = 0.0
## Applied as a bonus when squad size > 1.
@export var weight_leadership: float = 0.0

# ── Duration ──────────────────────────────────────────────────────────────────
## Base days the mission takes (1–5).
@export var base_duration_days: int = 1
## Additional travel days (0–2). "Two days ride to the north."
@export var distance_days: int = 0

# ── Rewards ───────────────────────────────────────────────────────────────────
@export var reward_gold: int = 0
## Gold paid on PARTIAL result.
@export var reward_gold_partial: int = 0
@export var reward_item_ids: Array[String] = []

# ── Consequences ──────────────────────────────────────────────────────────────
## { faction_id: int delta } applied on success.
@export var rep_on_success: Dictionary = {}
## { faction_id: int delta } applied on failure.
@export var rep_on_failure: Dictionary = {}
## { faction_id: int delta } applied on expiry (consequential only).
@export var rep_on_expiry: Dictionary = {}
## ID of a ConsequenceTemplate to trigger on failure. Empty = none.
@export var consequence_on_failure: String = ""

# ── Timing ────────────────────────────────────────────────────────────────────
@export var available_from_day: int = 1
@export var expiry_day: int = 999
