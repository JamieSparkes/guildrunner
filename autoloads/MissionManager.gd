extends Node
## Orchestrates mission dispatch, daily stage progression, and resolution.
## Delegates combat math to StageResolver and injury rolls to InjuryResolver.

# ── Active mission record ─────────────────────────────────────────────────────

class ActiveMission:
	var mission_id: String = ""
	var contract: ContractData = null
	var hero_ids: Array[String] = []
	var commitment: Enums.CommitmentLevel = Enums.CommitmentLevel.USE_JUDGEMENT
	var start_day: int = 0
	## Flat contracts only: day when mission resolves.
	var completion_day: int = 0
	## Stage tracking (staged contracts only).
	var current_stage_index: int = 0
	## Per-stage attempts: { stage_id: int }
	var stage_state: Dictionary = {}
	## Flags set by events and stages: { flag_name: bool }
	var flags: Dictionary = {}
	## Worst combat outcome per hero accumulated during stages: { hero_id: Dictionary }
	var combat_outcomes: Dictionary = {}
	## True once all stages complete or timed out.
	var completed: bool = false

## Holds the squad reference for a mission between narrative generation and outcome
## finalization. Created when mission completes, consumed in finalize_mission().
class PendingResolution:
	var mission: ActiveMission = null
	var squad: Array = []   # Array[HeroData]

# ── State ─────────────────────────────────────────────────────────────────────

var _active: Dictionary = {}                # { mission_id: ActiveMission }
var _pending_resolutions: Dictionary = {}   # { mission_id: PendingResolution }
var _counter: int = 0
var _item_db: Dictionary = {}   # Populated on _ready

func _ready() -> void:
	_item_db = DataLoader.load_item_definitions()
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.cmd_request_intervention.connect(_on_cmd_request_intervention)

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
	# Flat contracts: compute completion_day from duration fields.
	if contract.stages.is_empty():
		mission.completion_day = TimeManager.current_day \
			+ contract.base_duration_days + contract.distance_days
	_active[mission_id] = mission

	for id: String in hero_ids:
		HeroManager.set_status(id, Enums.HeroStatus.ON_MISSION)
		HeroManager.set_current_mission(id, mission_id)
		EventBus.hero_dispatched.emit(id, mission_id)
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

## Change commitment mid-mission (intervention system).
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

## Stage progress snapshot for a mission. Returns null if not found.
## Keys: mission_id, title, hero_ids, stage_names, stage_narrative_keys,
##        current_stage_index, total_stages, completed, combat_outcomes.
func get_mission_progress(mission_id: String) -> Variant:
	var mission: ActiveMission = _active.get(mission_id, null)
	if mission == null:
		var pending: PendingResolution = _pending_resolutions.get(mission_id, null)
		if pending != null:
			mission = pending.mission
	if mission == null:
		return null
	var stage_names: Array[String] = []
	var stage_narrative_keys: Array[String] = []
	for s: StageData in mission.contract.stages:
		stage_names.append(s.stage_id)
		stage_narrative_keys.append(s.narrative_key)
	return {
		"mission_id": mission.mission_id,
		"title": mission.contract.title,
		"hero_ids": mission.hero_ids,
		"stage_names": stage_names,
		"stage_narrative_keys": stage_narrative_keys,
		"current_stage_index": mission.current_stage_index,
		"total_stages": mission.contract.stages.size(),
		"completed": mission.completed,
		"combat_outcomes": mission.combat_outcomes,
	}

## Number of missions with pre-outcome events queued but not yet finalized.
func get_pending_resolution_count() -> int:
	return _pending_resolutions.size()

## IDs of missions that have generated pre-outcome events but not yet been finalized.
## FeedScreen calls this at open-time to populate its finalization queue.
func get_pending_resolution_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_pending_resolutions.keys())
	return ids

# ── Day tick ──────────────────────────────────────────────────────────────────

func _on_day_advanced(day: int) -> void:
	for mission: ActiveMission in _active.values().duplicate():
		if mission.completed or _pending_resolutions.has(mission.mission_id):
			continue
		if mission.contract.stages.is_empty():
			# Flat contract: resolve on completion_day (legacy path).
			if day >= mission.completion_day:
				_begin_flat_mission_narrative(mission)
		else:
			_process_mission_day(mission, day)

# ── Staged daily processing ──────────────────────────────────────────────────

func _process_mission_day(mission: ActiveMission, day: int) -> void:
	var contract := mission.contract
	var squad := _get_squad(mission)
	if squad.is_empty():
		_active.erase(mission.mission_id)
		return

	# Check timeout.
	var days_elapsed := day - mission.start_day
	if days_elapsed >= contract.max_duration_days:
		_emit_stage_event(mission, squad, "stage_timed_out", {})
		EventBus.mission_stage_completed.emit(mission.mission_id, false)
		_begin_finalization(mission, squad, true)
		return

	# Process stages in a loop (auto-advance stages chain within a single day).
	while mission.current_stage_index < contract.stages.size():
		var stage: StageData = contract.stages[mission.current_stage_index]
		var advanced := _process_stage(mission, stage, squad)
		if not advanced:
			break
		mission.current_stage_index += 1
		EventBus.mission_stage_advanced.emit(
			mission.mission_id,
			mission.current_stage_index,
			contract.stages.size()
		)

	# Check if all stages are done.
	if mission.current_stage_index >= contract.stages.size():
		mission.completed = true
		EventBus.mission_stage_completed.emit(mission.mission_id, true)
		_begin_finalization(mission, squad, false)

func _process_stage(
	mission: ActiveMission,
	stage: StageData,
	squad: Array[HeroData]
) -> bool:
	var mid := mission.mission_id
	var lead: HeroData = squad[0]
	var base_params := {
		"name":        lead.display_name,
		"personality": _personality_key(lead),
		"target":      mission.contract.title,
	}

	# 1. Emit stage narrative.
	_emit_stage_event(mission, squad, stage.narrative_key, base_params)

	# 2. Process each event in this stage.
	for event: StageEventData in stage.events:
		_process_event(mission, event, squad, base_params)

	# 3. Set stage flag if defined.
	if stage.sets_flag != "":
		mission.flags[stage.sets_flag] = true

	# 4. Attempt advancement.
	var advance: Dictionary = stage.advance
	var advance_type: String = advance.get("type", "auto")

	match advance_type:
		"auto":
			return true
		"chance":
			var stage_id := stage.stage_id
			var attempts: int = mission.stage_state.get(stage_id, 0)
			if StageResolver.roll_advance(advance, squad, attempts):
				return true
			else:
				mission.stage_state[stage_id] = attempts + 1
				_emit_stage_event(mission, squad, "stage_advance_fail", base_params)
				return false
		"stat_check":
			if StageResolver.check_stat(advance, squad):
				return true
			else:
				var fail_advance: bool = advance.get("fail_advance", false)
				var fail_flag: String = advance.get("fail_sets_flag", "")
				if fail_flag != "":
					mission.flags[fail_flag] = true
				if fail_advance:
					return true
				_emit_stage_event(mission, squad, "stage_advance_fail", base_params)
				return false

	return true  # fallback

func _process_event(
	mission: ActiveMission,
	event: StageEventData,
	squad: Array[HeroData],
	base_params: Dictionary
) -> void:
	# Roll to see if this event fires.
	if not StageResolver.roll_event(event, squad, mission.flags):
		return

	var mid := mission.mission_id
	var params := base_params.duplicate()

	match event.type:
		"combat":
			_emit_stage_event(mission, squad, event.narrative_key, params)
			var outcomes := StageResolver.resolve_combat(
				event, squad, mission.commitment, mission.flags, mission.contract.can_capture
			)
			for i: int in squad.size():
				var outcome: Dictionary = outcomes[i]
				if outcome["injured"]:
					var hero: HeroData = squad[i]
					# Keep the worst outcome per hero across all stage combats.
					_accumulate_combat_outcome(mission, hero.hero_id, outcome)
					var hparams := {
						"hero_id":     hero.hero_id,
						"name":        hero.display_name,
						"personality": _personality_key(hero),
						"target":      mission.contract.title,
					}
					var sev: int = outcome["severity"]
					var wkey := "hero_wounded_minor" \
						if sev == Enums.InjurySeverity.MINOR else "hero_wounded_serious"
					EventBus.feed_event.emit(mid, wkey, hparams)

		"reward":
			var gold: int = event.reward.get("gold", 0)
			if gold > 0:
				GuildManager.add_gold(gold)
				params["gold"] = str(gold)
			_emit_stage_event(mission, squad, event.narrative_key, params)

		"discovery":
			_emit_stage_event(mission, squad, event.narrative_key, params)
			if event.on_success_flag != "":
				mission.flags[event.on_success_flag] = true

		"objective":
			if event.on_success_flag != "":
				mission.flags[event.on_success_flag] = true
			_emit_stage_event(mission, squad, event.narrative_key, params)

		"narrative":
			_emit_stage_event(mission, squad, event.narrative_key, params)

func _emit_stage_event(
	mission: ActiveMission,
	squad: Array[HeroData],
	event_key: String,
	params: Dictionary
) -> void:
	if event_key == "":
		return
	var p := params.duplicate()
	if not p.has("personality") and not squad.is_empty():
		p["personality"] = _personality_key(squad[0])
	if not p.has("name") and not squad.is_empty():
		p["name"] = squad[0].display_name
	if not p.has("target"):
		p["target"] = mission.contract.title
	EventBus.feed_event.emit(mission.mission_id, event_key, p)

## Keep the worst injury outcome per hero across all stage combats.
func _accumulate_combat_outcome(mission: ActiveMission, hero_id: String, outcome: Dictionary) -> void:
	if not mission.combat_outcomes.has(hero_id):
		mission.combat_outcomes[hero_id] = outcome
		return
	var existing: Dictionary = mission.combat_outcomes[hero_id]
	# Worse = died > captured > higher severity injury > any injury.
	if outcome.get("died", false) and not existing.get("died", false):
		mission.combat_outcomes[hero_id] = outcome
	elif outcome.get("captured", false) and not existing.get("captured", false) and not existing.get("died", false):
		mission.combat_outcomes[hero_id] = outcome
	elif outcome.get("severity", 0) > existing.get("severity", 0) and not existing.get("died", false):
		mission.combat_outcomes[hero_id] = outcome

# ── Flat contract legacy path ────────────────────────────────────────────────

func _begin_flat_mission_narrative(mission: ActiveMission) -> void:
	var squad := _get_squad(mission)
	if squad.is_empty():
		_active.erase(mission.mission_id)
		return

	var pending := PendingResolution.new()
	pending.mission = mission
	pending.squad = squad
	_pending_resolutions[mission.mission_id] = pending

	_emit_flat_pre_outcome_events(mission, squad)
	EventBus.mission_narrative_started.emit(mission.mission_id)

func _emit_flat_pre_outcome_events(mission: ActiveMission, squad: Array[HeroData]) -> void:
	var mid := mission.mission_id
	var target := mission.contract.title
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

# ── Finalization ─────────────────────────────────────────────────────────────

func _begin_finalization(
	mission: ActiveMission,
	squad: Array[HeroData],
	timed_out: bool
) -> void:
	var pending := PendingResolution.new()
	pending.mission = mission
	pending.squad = squad
	# Store timed_out in mission flags for finalize_mission to read.
	mission.flags["_timed_out"] = timed_out
	_pending_resolutions[mission.mission_id] = pending
	EventBus.mission_narrative_started.emit(mission.mission_id)

## Phase 2: Compute outcome, emit outcome + epilogue events, apply state changes.
## Called by AppController via cmd_finalize_mission.
func finalize_mission(mission_id: String) -> void:
	var pending: PendingResolution = _pending_resolutions.get(mission_id, null)
	if pending == null:
		return
	_pending_resolutions.erase(mission_id)

	var mission := pending.mission
	var squad: Array[HeroData] = []
	for h in pending.squad:
		squad.append(h as HeroData)
	var contract := mission.contract

	var result: Enums.MissionResult
	if contract.stages.is_empty():
		# Flat contract: use original MissionResolver.
		result = MissionResolver.resolve_mission(contract, squad, mission.commitment, _item_db)
	else:
		# Staged contract: determine outcome from flags and stage progress.
		var timed_out: bool = mission.flags.get("_timed_out", false)
		result = StageResolver.determine_outcome(
			mission.current_stage_index,
			contract.stages.size(),
			mission.flags,
			timed_out
		)

	var outcomes: Array = []
	if contract.stages.is_empty():
		# Flat contract: roll injuries at finalization as before.
		for hero: HeroData in squad:
			outcomes.append(InjuryResolver.resolve_hero_outcome(
				hero, result, mission.commitment, contract.difficulty, contract.can_capture
			))
	else:
		# Staged contract: use injuries accumulated during stage combats.
		for hero: HeroData in squad:
			if mission.combat_outcomes.has(hero.hero_id):
				outcomes.append(mission.combat_outcomes[hero.hero_id])
			else:
				outcomes.append({
					"injured": false,
					"severity": Enums.InjurySeverity.MINOR,
					"died": false,
					"captured": false,
					"recovery_days": 0,
				})

	_emit_outcome_events(mission, squad, result, outcomes)

	match result:
		Enums.MissionResult.FULL_SUCCESS, Enums.MissionResult.SUCCESS:
			GuildManager.add_gold(contract.reward_gold)
		Enums.MissionResult.PARTIAL:
			GuildManager.add_gold(contract.reward_gold_partial)

	_apply_rep(contract, result)

	for i: int in squad.size():
		_apply_hero_outcome(squad[i], outcomes[i], result, contract, mission_id)

	EventBus.contract_completed.emit(
		contract.contract_id, result != Enums.MissionResult.FAILURE
	)
	_active.erase(mission_id)

func _emit_outcome_events(
	mission: ActiveMission,
	squad: Array[HeroData],
	result: Enums.MissionResult,
	outcomes: Array
) -> void:
	var mid := mission.mission_id
	var target := mission.contract.title
	var lead: HeroData = squad[0]
	var base_params := {
		"name":        lead.display_name,
		"personality": _personality_key(lead),
		"target":      target,
	}

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

# ── Intervention handling ─────────────────────────────────────────────────────

func _on_cmd_request_intervention(mission_id: String, event_key: String) -> void:
	var mission: ActiveMission = _active.get(mission_id, null)
	if mission == null:
		return
	var data := InterventionData.new()
	data.mission_id = mission_id
	data.intervention_type = InterventionData.Type.COMMITMENT_CHANGE
	data.context_text = _intervention_context_for_key(event_key)
	data.trigger_event_key = event_key
	data.options = [
		Enums.CommitmentLevel.AT_ANY_COST,
		Enums.CommitmentLevel.USE_JUDGEMENT,
		Enums.CommitmentLevel.COME_HOME_SAFE,
	]
	data.current_option_index = mission.commitment
	EventBus.intervention_data_ready.emit(data)

func _intervention_context_for_key(event_key: String) -> String:
	match event_key:
		"hero_wounded_minor", "hero_wounded_serious":
			return "A hero has been wounded. Adjust commitment?"
		"encounter_obstacle":
			return "The squad faces a decision point. Change commitment?"
	return "Intervention available. Change commitment?"

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

func _apply_rep(_contract: ContractData, _result: Enums.MissionResult) -> void:
	pass  # Wired in M11

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_squad(mission: ActiveMission) -> Array[HeroData]:
	var squad: Array[HeroData] = []
	for id: String in mission.hero_ids:
		var hero := HeroManager.get_hero(id)
		if hero != null:
			squad.append(hero)
	return squad

func _new_id(contract_id: String) -> String:
	_counter += 1
	return "mission_%d_%s" % [_counter, contract_id]

func _personality_key(hero: HeroData) -> String:
	return Enums.PersonalityType.keys()[hero.personality_type]

# ── Test helpers ──────────────────────────────────────────────────────────────

func reset_runtime_state() -> void:
	_active.clear()
	_pending_resolutions.clear()
	_counter = 0
	_item_db = DataLoader.load_item_definitions()

func _reset_for_test() -> void:
	_active.clear()
	_pending_resolutions.clear()
	_counter = 0
	_item_db = {}
