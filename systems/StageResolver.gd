## Stage-by-stage resolution logic for staged contracts. All static, no state.
class_name StageResolver

# ── Event resolution ─────────────────────────────────────────────────────────

## Roll whether a stage event triggers, accounting for stat modifiers.
static func roll_event(
	event: StageEventData,
	squad: Array[HeroData],
	flags: Dictionary
) -> bool:
	var chance := event.chance
	if not event.stat_modifier.is_empty():
		var stat_name: String = event.stat_modifier.get("stat", "")
		var weight: float = event.stat_modifier.get("weight", 0.0)
		chance += _average_stat(squad, stat_name) * weight
	chance = clampf(chance, 0.0, 1.0)
	return randf() < chance

## Resolve a combat event. Returns an Array of per-hero injury outcome dicts
## (same shape as InjuryResolver.resolve_hero_outcome).
static func resolve_combat(
	event: StageEventData,
	squad: Array[HeroData],
	commitment: Enums.CommitmentLevel,
	flags: Dictionary,
	can_capture: bool = false
) -> Array:
	var effective_difficulty := event.difficulty
	for flag_name: String in event.difficulty_modifier_if_flag:
		if flags.get(flag_name, false):
			effective_difficulty += int(event.difficulty_modifier_if_flag[flag_name])
	effective_difficulty = clampi(effective_difficulty, 1, 5)

	var combat_result := _resolve_combat_result(squad, commitment, effective_difficulty)

	var outcomes: Array = []
	for hero: HeroData in squad:
		outcomes.append(InjuryResolver.resolve_hero_outcome(
			hero, combat_result, commitment, effective_difficulty, can_capture
		))
	return outcomes

# ── Stage advancement ────────────────────────────────────────────────────────

## Attempt chance-based advancement. Returns true if the stage advances.
static func roll_advance(
	advance: Dictionary,
	squad: Array[HeroData],
	attempts: int
) -> bool:
	var chance: float = advance.get("base_chance", 0.5)
	chance += advance.get("cumulative_increase", 0.0) * float(attempts)
	var stat_bonus: Dictionary = advance.get("stat_bonus", {})
	if not stat_bonus.is_empty():
		var avg := _average_stat(squad, stat_bonus.get("stat", ""))
		chance += avg * stat_bonus.get("weight", 0.0)
	chance = clampf(chance, 0.0, 1.0)
	return randf() < chance

## Stat-check advancement. Returns true if the squad passes the threshold.
static func check_stat(advance: Dictionary, squad: Array[HeroData]) -> bool:
	var stat_name: String = advance.get("stat", "strength")
	var threshold: float = advance.get("threshold", 50.0)
	return _best_stat(squad, stat_name) >= threshold

# ── Overall outcome ──────────────────────────────────────────────────────────

## Determine the mission result from flags and stage progress.
static func determine_outcome(
	stages_completed: int,
	total_stages: int,
	flags: Dictionary,
	timed_out: bool
) -> Enums.MissionResult:
	var objective_done: bool = flags.get("objective_complete", false)
	if objective_done and not timed_out:
		if randf() < 0.3:
			return Enums.MissionResult.FULL_SUCCESS
		return Enums.MissionResult.SUCCESS
	if objective_done and timed_out:
		return Enums.MissionResult.PARTIAL
	if float(stages_completed) / float(maxi(total_stages, 1)) >= 0.5:
		return Enums.MissionResult.PARTIAL
	return Enums.MissionResult.FAILURE

# ── Success chance estimation ────────────────────────────────────────────────

## Exact probability (0.0–1.0) of a staged contract ending in SUCCESS or better.
## Uses day-by-day state propagation — result is deterministic for a given squad.
static func calculate_success_chance(
	contract: ContractData,
	squad: Array[HeroData],
) -> float:
	if squad.is_empty() or contract.stages.is_empty():
		return 0.0
	var p_complete := _calc_completion_prob(contract, squad)
	var p_obj := _calc_objective_prob(contract, squad)
	return clampf(p_complete * p_obj, 0.0, 1.0)

## P(all stages advance before max_duration_days expires).
## Tracks state as [stage_index, attempts_at_current_stage] → probability.
static func _calc_completion_prob(contract: ContractData, squad: Array[HeroData]) -> float:
	var states: Dictionary = { [0, 0]: 1.0 }
	var p_done: float = 0.0
	for _day: int in contract.max_duration_days:
		var blocked: Dictionary = {}
		for key in states.keys():
			p_done += _advance_chain(contract.stages, squad, key[0], key[1], states[key], blocked)
		states = blocked
	return p_done

## Advance through stages for one day starting at (si, att) with probability mass p.
## Returns probability that completed all stages. Deposits blocked probability into out_blocked.
static func _advance_chain(
	stages: Array,
	squad: Array[HeroData],
	si: int,
	att: int,
	p: float,
	out_blocked: Dictionary
) -> float:
	# Consume all leading auto-advance stages (they chain instantly).
	while si < stages.size() and (stages[si] as StageData).advance.get("type", "auto") == "auto":
		si += 1
	if si >= stages.size():
		return p  # All stages complete.

	var stage := stages[si] as StageData
	match stage.advance.get("type", "auto"):
		"chance":
			var q: float = stage.advance.get("base_chance", 0.5)
			q += stage.advance.get("cumulative_increase", 0.0) * float(att)
			var sb: Dictionary = stage.advance.get("stat_bonus", {})
			if not sb.is_empty():
				q += _average_stat(squad, sb.get("stat", "")) * sb.get("weight", 0.0)
			q = clampf(q, 0.0, 1.0)
			# Fail branch: blocked until next day.
			var bk := [si, att + 1]
			out_blocked[bk] = out_blocked.get(bk, 0.0) + p * (1.0 - q)
			# Success branch: continue chain this same day.
			return _advance_chain(stages, squad, si + 1, 0, p * q, out_blocked)
		"stat_check":
			var passes: bool = _best_stat(squad, stage.advance.get("stat", "strength")) \
				>= stage.advance.get("threshold", 50.0)
			if passes or stage.advance.get("fail_advance", false):
				return _advance_chain(stages, squad, si + 1, 0, p, out_blocked)
			# Stat check will always fail — this probability can never succeed.
			return 0.0
	return 0.0

## P(objective_complete is achieved, given all stages complete).
## For stages that guarantee it via sets_flag, returns 1.0 immediately.
## For objective events, combines them as independent chances.
static func _calc_objective_prob(contract: ContractData, squad: Array[HeroData]) -> float:
	for stage: StageData in contract.stages:
		if stage.sets_flag == "objective_complete":
			return 1.0
	var p_no_obj := 1.0
	for stage: StageData in contract.stages:
		for ev in stage.events:
			var event := ev as StageEventData
			if event.type == "objective" and event.on_success_flag == "objective_complete":
				var p_ev: float = event.chance
				if not event.stat_modifier.is_empty():
					p_ev += _average_stat(squad, event.stat_modifier.get("stat", "")) \
						* event.stat_modifier.get("weight", 0.0)
				p_ev = clampf(p_ev, 0.0, 1.0)
				p_no_obj *= (1.0 - p_ev)
	return 1.0 - p_no_obj

# ── Internal helpers ─────────────────────────────────────────────────────────

static func _average_stat(squad: Array[HeroData], stat_name: String) -> float:
	if squad.is_empty() or stat_name == "":
		return 0.0
	var total := 0.0
	for hero: HeroData in squad:
		total += hero.get(stat_name) as float
	return total / float(squad.size())

static func _best_stat(squad: Array[HeroData], stat_name: String) -> float:
	var best := 0.0
	for hero: HeroData in squad:
		best = maxf(best, hero.get(stat_name) as float)
	return best

static func _resolve_combat_result(
	squad: Array[HeroData],
	commitment: Enums.CommitmentLevel,
	difficulty: int
) -> Enums.MissionResult:
	var score := 0.0
	for hero: HeroData in squad:
		score += (hero.strength * 0.4 + hero.agility * 0.3 + hero.resilience * 0.3)
	score /= float(squad.size())
	score *= MissionResolver.COMMITMENT_MULTIPLIER[commitment]
	var roll := score + randf_range(-25.0, 25.0)
	var threshold := 40.0 + float(difficulty - 1) * 10.0
	if roll >= threshold + 20.0:
		return Enums.MissionResult.FULL_SUCCESS
	if roll >= threshold:
		return Enums.MissionResult.SUCCESS
	if roll >= threshold - 15.0:
		return Enums.MissionResult.PARTIAL
	return Enums.MissionResult.FAILURE
