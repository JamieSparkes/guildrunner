## Static definition for a faction. Runtime reputation is owned by FactionManager.
class_name FactionData extends Resource

@export var faction_id: String = ""
@export var display_name: String = ""
@export var faction_type: Enums.FactionType = Enums.FactionType.CROWN

# ── Reputation Thresholds (score is -100 to +100) ─────────────────────────────
## score < threshold_enemy   → ENEMY
## score < threshold_unknown → UNKNOWN
## score < threshold_neutral → NEUTRAL
## score < threshold_trusted → TRUSTED
## score >= threshold_trusted → HONOURED
@export var threshold_enemy: int = -40
@export var threshold_unknown: int = -15
@export var threshold_neutral: int = 10
@export var threshold_trusted: int = 50

# ── Siege ─────────────────────────────────────────────────────────────────────
## Minimum tier required for the faction to provide siege aid.
@export var siege_aid_at_tier: Enums.RepTier = Enums.RepTier.TRUSTED
## Strength contribution to siege defence when aiding.
@export var siege_force_strength: int = 0

# ── Contracts ─────────────────────────────────────────────────────────────────
## Template IDs this faction can offer on the contract board.
@export var contract_pool: Array[String] = []

# ── Flavour ───────────────────────────────────────────────────────────────────
@export var description: String = ""
@export var hostile_action_description: String = ""
