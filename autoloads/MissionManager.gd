extends Node
## Orchestrates mission dispatch, ticking, and resolution.
## Delegates outcome math to MissionResolver and InjuryResolver.

# ── Active mission record ─────────────────────────────────────────────────────

class ActiveMission:
	var mission_id: String = ""
	var contract: ContractData = null
	var hero_ids: Array[String] = []
	var commitment: Enums.CommitmentLevel = Enums.CommitmentLevel.USE_JUDGEMENT
	var start_day: int = 0
	var completion_day: int = 0

# ── State ─────────────────────────────────────────────────────────────────────

var _active: Dictionary = {}    # { mission_id: ActiveMission }
var _counter: int = 0
var _item_db: Dictionary = {}   # Populated on _ready

func _ready() -> void:
	_item_db = DataLoader.load_item_definitions()
	EventBus.day_advanced.connect(_on_day_advanced)

# ── Public API ────────────────────────────────────────────────────────────────

## Dispatch heroes on a contract. Returns the new mission_id or "" on error.
func dispatch_heroes(
	contract: ContractData,
	hero_ids: Array[String],
	commitment: Enums.CommitmentLevel
) -> String:
	for id: String in hero_ids:
		var hero := HeroManager.get_hero(id)
		if hero == null or hero.status != Enums.HeroStatus.AVAILABLE:
			push_warning("MissionManager: hero '%s' is not available for dispatch" % id)
			return ""

	var mission_id := _new_id(contract.contract_id)
	var mission := ActiveMission.new()
	mission.mission_id     = mission_id
	mission.contract       = contract
	mission.hero_ids.assign(hero_ids)
	mission.commitment     = commitment
	mission.start_day      = TimeManager.current_day
	mission.completion_day = TimeManager.current_day \
		+ contract.base_duration_days + contract.distance_days
	_active[mission_id] = mission

	for id: String in hero_ids:
		HeroManager.set_status(id, Enums.HeroStatus.ON_MISSION)
		HeroManager.set_current_mission(id, mission_id)
		EventBus.hero_dispatched.emit(id, mission_id)

	EventBus.contract_accepted.emit(contract.contract_id)
	return mission_id

## Change commitment mid-mission (intervention system, M9).
func update_commitment(mission_id: String, new_commitment: Enums.CommitmentLevel) -> void:
	if _active.has(mission_id):
		_active[mission_id].commitment = new_commitment

## Return all active missions.
func get_active_missions() -> Array:
	return _active.values()

# ── Day tick ──────────────────────────────────────────────────────────────────

func _on_day_advanced(day: int) -> void:
	for mission: ActiveMission in _active.values().duplicate():
		if day >= mission.completion_day:
			_resolve_mission(mission)

# ── Resolution ────────────────────────────────────────────────────────────────

func _resolve_mission(mission: ActiveMission) -> void:
	var contract := mission.contract
	var squad: Array[HeroData] = []
	for id: String in mission.hero_ids:
		var hero := HeroManager.get_hero(id)
		if hero != null:
			squad.append(hero)

	if squad.is_empty():
		_active.erase(mission.mission_id)
		return

	var result := MissionResolver.resolve_mission(contract, squad, mission.commitment, _item_db)

	match result:
		Enums.MissionResult.FULL_SUCCESS, Enums.MissionResult.SUCCESS:
			GuildManager.add_gold(contract.reward_gold)
		Enums.MissionResult.PARTIAL:
			GuildManager.add_gold(contract.reward_gold_partial)

	# Rep application wired in M11
	_apply_rep(contract, result)

	for hero: HeroData in squad:
		_resolve_hero(hero, result, mission.commitment, contract)

	EventBus.contract_completed.emit(
		contract.contract_id, result != Enums.MissionResult.FAILURE
	)
	_active.erase(mission.mission_id)

func _resolve_hero(
	hero: HeroData,
	result: Enums.MissionResult,
	commitment: Enums.CommitmentLevel,
	contract: ContractData
) -> void:
	var outcome := InjuryResolver.resolve_hero_outcome(
		hero, result, commitment, contract.difficulty
	)

	_update_history(hero, contract, result, outcome)

	if outcome["died"]:
		HeroManager.kill_hero(hero.hero_id, "")
		return
	if outcome["captured"]:
		HeroManager.capture_hero(hero.hero_id, "")
		return
	if outcome["injured"]:
		HeroManager.apply_injury(hero.hero_id, outcome["severity"])
		return

	HeroManager.set_status(hero.hero_id, Enums.HeroStatus.AVAILABLE)
	HeroManager.set_current_mission(hero.hero_id, "")
	EventBus.hero_returned.emit(hero.hero_id, result)

func _update_history(
	hero: HeroData,
	contract: ContractData,
	result: Enums.MissionResult,
	outcome: Dictionary
) -> void:
	if hero.status == Enums.HeroStatus.DEAD:
		return
	hero.missions_completed += 1
	var mk: int = contract.mission_type
	hero.missions_by_type[mk] = hero.missions_by_type.get(mk, 0) + 1
	if outcome.get("injured", false):
		hero.times_wounded += 1
	if contract.weight_stealth >= 0.5 \
			and result != Enums.MissionResult.FAILURE \
			and not outcome.get("injured", false):
		hero.stealth_missions_clean += 1

func _apply_rep(_contract: ContractData, _result: Enums.MissionResult) -> void:
	pass  # Wired in M11

func _new_id(contract_id: String) -> String:
	_counter += 1
	return "mission_%d_%s" % [_counter, contract_id]

# ── Test helpers ──────────────────────────────────────────────────────────────

func _reset_for_test() -> void:
	_active.clear()
	_counter = 0
	_item_db = {}
