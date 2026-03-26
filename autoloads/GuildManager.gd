extends Node
## Owns the GuildState resource: gold, roster, buildings, intervention tokens.
## Provides economy API (gold operations, upkeep).

# Base weekly cost per archetype (index matches Enums.HeroArchetype value order)
# FIGHTER=0  ROGUE=1  RANGER=2  SUPPORT=3
const BASE_UPKEEP_BY_ARCHETYPE: Array = [8, 7, 7, 6]
const LEGENDARY_SURCHARGE: int = 3

# ── State ─────────────────────────────────────────────────────────────────────

var _state: GuildState = null

func _ready() -> void:
	_init_state()
	EventBus.day_advanced.connect(_on_day_advanced)

func _init_state() -> void:
	_state = GuildState.new()
	_state.gold = 200
	_state.current_day = 1
	_state.max_roster_size = 4
	_state.intervention_tokens = 0
	_state.max_intervention_tokens = 0
	_state.building_tiers = {
		"barracks": 0, "forge": 0, "infirmary": 0,
		"training_grounds": 0, "tavern": 0, "gatehouse": 0,
	}

func _on_day_advanced(_day: int) -> void:
	reset_intervention_tokens()

## Returns the current GuildState.
func get_state() -> GuildState:
	return _state

# ── Gold API ──────────────────────────────────────────────────────────────────

func add_gold(amount: int) -> void:
	_state.gold += amount
	EventBus.gold_changed.emit(amount, _state.gold)

## Returns false and does NOT deduct if funds are insufficient.
func deduct_gold(amount: int) -> bool:
	if _state.gold < amount:
		return false
	_state.gold -= amount
	EventBus.gold_changed.emit(-amount, _state.gold)
	return true

## Force-deduct even into negative (upkeep debt).
func force_deduct_gold(amount: int) -> void:
	_state.gold -= amount
	EventBus.gold_changed.emit(-amount, _state.gold)

# ── Upkeep ────────────────────────────────────────────────────────────────────

## Calculate total weekly upkeep for the current live roster.
func calculate_upkeep() -> int:
	var total := 0
	for hero in HeroManager.get_all_heroes():
		if hero.status == Enums.HeroStatus.DEAD:
			continue
		var base: int = BASE_UPKEEP_BY_ARCHETYPE[hero.archetype]
		var surcharge: int = LEGENDARY_SURCHARGE if hero.is_legendary else 0
		total += base + surcharge
	return total

## Deduct weekly upkeep. If gold is insufficient, apply morale penalty.
func apply_weekly_upkeep() -> void:
	var cost := calculate_upkeep()
	_state.weekly_upkeep_total = cost
	_state.last_upkeep_day = TimeManager.current_day

	if _state.gold >= cost:
		_state.gold -= cost
		EventBus.gold_changed.emit(-cost, _state.gold)
		_clear_debt_consequences()
	else:
		var shortfall := cost - _state.gold
		force_deduct_gold(_state.gold)
		_apply_debt_morale_penalty()
		var debt_entry: Dictionary = {
			"type": "upkeep_debt",
			"shortfall": shortfall,
			"week": TimeManager.week_number,
		}
		_state.pending_consequences.append(debt_entry)

func _clear_debt_consequences() -> void:
	var keep: Array[Dictionary] = []
	for entry: Dictionary in _state.pending_consequences:
		if entry.get("type") != "upkeep_debt":
			keep.append(entry)
	_state.pending_consequences = keep

func _apply_debt_morale_penalty() -> void:
	for hero in HeroManager.get_all_heroes():
		if hero.status == Enums.HeroStatus.DEAD:
			continue
		var new_morale: float = maxf(hero.morale - 5.0, hero.morale_floor)
		var delta: float = new_morale - hero.morale
		hero.morale = new_morale
		if delta != 0.0:
			EventBus.hero_morale_changed.emit(hero.hero_id, delta)

# ── Intervention tokens ───────────────────────────────────────────────────────

func set_max_intervention_tokens(new_max: int) -> void:
	_state.max_intervention_tokens = new_max

func reset_intervention_tokens() -> void:
	_state.intervention_tokens = _state.max_intervention_tokens

func spend_intervention_token() -> bool:
	if _state.intervention_tokens <= 0:
		return false
	_state.intervention_tokens -= 1
	return true

# ── Test helpers ──────────────────────────────────────────────────────────────

func reset_runtime_state() -> void:
	_init_state()

func _reset_for_test() -> void:
	reset_runtime_state()
