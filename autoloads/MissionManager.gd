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
	FeedManager.assign_mission_color(mission_id)
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
		# Emit departure feed event immediately so the player sees something.
		var hero := HeroManager.get_hero(id)
		if hero != null:
			EventBus.feed_event.emit(mission_id, "hero_departed", {
				"hero_id":     id,
				"name":        hero.display_name,
				"personality": _personality_key(hero),
				"target":      contract.title,
			})

	EventBus.contract_accepted.emit(contract.contract_id)
	return mission_id

## Change commitment mid-mission (intervention system, M9).
func update_commitment(mission_id: String, new_commitment: Enums.CommitmentLevel) -> void:
	if _active.has(mission_id):
		_active[mission_id].commitment = new_commitment

## Return all active missions.
func get_active_missions() -> Array:
	return _active.values()

## Return the contract title for a mission, or the mission_id as fallback.
func get_mission_title(mission_id: String) -> String:
	var mission: ActiveMission = _active.get(mission_id, null)
	if mission == null:
		return mission_id
	return mission.contract.title

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

	# Pre-compute per-hero outcomes so we can emit narrative before applying state.
	var outcomes: Array = []
	for hero: HeroData in squad:
		outcomes.append(InjuryResolver.resolve_hero_outcome(
			hero, result, mission.commitment, contract.difficulty
		))

	# Emit full narrative feed sequence.
	_emit_mission_narrative(mission, squad, result, outcomes)

	# Apply gold reward.
	match result:
		Enums.MissionResult.FULL_SUCCESS, Enums.MissionResult.SUCCESS:
			GuildManager.add_gold(contract.reward_gold)
		Enums.MissionResult.PARTIAL:
			GuildManager.add_gold(contract.reward_gold_partial)

	_apply_rep(contract, result)

	# Apply per-hero outcomes and update history.
	for i: int in squad.size():
		_apply_hero_outcome(squad[i], outcomes[i], result, contract, mission.mission_id)

	EventBus.contract_completed.emit(
		contract.contract_id, result != Enums.MissionResult.FAILURE
	)
	_active.erase(mission.mission_id)

func _emit_mission_narrative(
	mission: ActiveMission,
	squad: Array[HeroData],
	result: Enums.MissionResult,
	outcomes: Array
) -> void:
	var mid := mission.mission_id
	var target := mission.contract.title
	# Use the lead hero's personality for shared events.
	var lead: HeroData = squad[0]
	var base_params := {
		"name":        lead.display_name,
		"personality": _personality_key(lead),
		"target":      target,
	}

	EventBus.feed_event.emit(mid, "travel_uneventful", base_params)
	EventBus.feed_event.emit(mid, "arrival", base_params)

	var encounter_pool: Array[String] = [
		"encounter_skirmish", "encounter_ambush",
		"encounter_obstacle", "encounter_discovery",
	]
	for _i: int in randi_range(2, 4):
		EventBus.feed_event.emit(
			mid,
			encounter_pool[randi() % encounter_pool.size()],
			base_params
		)

	var outcome_key := ""
	match result:
		Enums.MissionResult.FULL_SUCCESS: outcome_key = "outcome_full_success"
		Enums.MissionResult.SUCCESS:      outcome_key = "outcome_success"
		Enums.MissionResult.PARTIAL:      outcome_key = "outcome_partial"
		_:                                outcome_key = "outcome_failure"
	EventBus.feed_event.emit(mid, outcome_key, base_params)

	# Per-hero epilogue.
	for i: int in squad.size():
		var hero: HeroData = squad[i]
		var hparams := {
			"hero_id":     hero.hero_id,
			"name":        hero.display_name,
			"personality": _personality_key(hero),
			"target":      target,
		}
		var outcome: Dictionary = outcomes[i]
		if outcome["died"]:
			EventBus.feed_event.emit(mid, "hero_died", hparams)
		elif outcome["captured"]:
			EventBus.feed_event.emit(mid, "hero_captured", hparams)
		elif outcome["injured"]:
			var sev: int = outcome["severity"]
			var wkey := "hero_wounded_minor" \
				if sev == Enums.InjurySeverity.MINOR else "hero_wounded_serious"
			EventBus.feed_event.emit(mid, wkey, hparams)
		else:
			EventBus.feed_event.emit(mid, "hero_returned", hparams)

func _apply_hero_outcome(
	hero: HeroData,
	outcome: Dictionary,
	result: Enums.MissionResult,
	contract: ContractData,
	mission_id: String
) -> void:
	_update_history(hero, contract, result, outcome)

	if outcome["died"]:
		HeroManager.kill_hero(hero.hero_id, mission_id)
		return
	if outcome["captured"]:
		HeroManager.capture_hero(hero.hero_id, mission_id)
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

## Convert a hero's personality_type int to the JSON key string (e.g. "STOIC").
func _personality_key(hero: HeroData) -> String:
	return Enums.PersonalityType.keys()[hero.personality_type]

# ── Test helpers ──────────────────────────────────────────────────────────────

func reset_runtime_state() -> void:
	_active.clear()
	_counter = 0
	_item_db = DataLoader.load_item_definitions()

func _reset_for_test() -> void:
	_active.clear()
	_counter = 0
	_item_db = {}
