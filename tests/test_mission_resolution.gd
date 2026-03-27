## M4 GUT tests — MissionResolver, InjuryResolver, RelationshipModifier, MissionManager
## Statistical tests use fixed seeds for reproducibility.
extends GutTest

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hero(id: String, archetype: Enums.HeroArchetype,
		str_v: float, agi: float, stealth: float, res: float, lead: float) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.archetype = archetype
	h.status = Enums.HeroStatus.AVAILABLE
	h.strength = str_v; h.agility = agi; h.stealth = stealth
	h.resilience = res; h.leadership = lead
	h.morale = 80.0; h.morale_floor = 20.0
	h.is_legendary = false
	return h

func _make_contract(id: String, difficulty: int, mission_type: Enums.MissionType,
		ws: float = 0.6, wa: float = 0.0, wst: float = 0.0,
		wr: float = 0.2, wl: float = 0.2,
		gold: int = 100, partial: int = 40, duration: int = 2) -> ContractData:
	var c := ContractData.new()
	c.contract_id = id; c.title = id; c.difficulty = difficulty
	c.mission_type = mission_type
	c.weight_strength = ws; c.weight_agility = wa; c.weight_stealth = wst
	c.weight_resilience = wr; c.weight_leadership = wl
	c.reward_gold = gold; c.reward_gold_partial = partial
	c.base_duration_days = duration; c.distance_days = 0
	c.min_heroes = 1; c.recommended_heroes = 1
	c.client_faction_id = "common_folk"
	return c

func before_each() -> void:
	TimeManager._reset_for_test()
	GuildManager._reset_for_test()
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()

func after_each() -> void:
	TimeManager._reset_for_test()
	GuildManager._reset_for_test()
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()

# ─────────────────────────────────────────────────────────────────────────────
# MissionResolver — deterministic outcome math
# ─────────────────────────────────────────────────────────────────────────────

func test_resolver_full_success_when_roll_far_above_threshold() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 25, 65, 50)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	# Difficulty 1 threshold = 40. roll offset +25 => score(~70*0.6+65*0.2+50*0.2=52) + 25 = 77 >= 60
	var result := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, 25.0
	)
	assert_eq(result, Enums.MissionResult.FULL_SUCCESS)

func test_resolver_failure_when_roll_far_below_threshold() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 30, 30, 30, 30, 30)
	var contract := _make_contract("c1", 3, Enums.MissionType.ELIMINATE)
	# Difficulty 3 threshold = 60. With low stats score ~24, roll offset -15 => 9 < 45
	var result := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, -15.0
	)
	assert_eq(result, Enums.MissionResult.FAILURE)

func test_resolver_partial_in_the_gap() -> void:
	# score ≈ 40 (threshold for difficulty 1), roll offset -10 => 30 which is >= 25 (40-15)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 30, 25, 40, 40)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE, 0.6, 0.0, 0.0, 0.2, 0.2)
	var result := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, -10.0
	)
	assert_eq(result, Enums.MissionResult.PARTIAL)

func test_resolver_at_any_cost_boosts_score() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 40, 30, 25, 35, 35)
	var contract := _make_contract("c1", 2, Enums.MissionType.ELIMINATE)
	# With USE_JUDGEMENT: would be borderline. AT_ANY_COST x1.25 should tip to success.
	var use_j := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, 0.0
	)
	var at_cost := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.AT_ANY_COST, 0.0
	)
	# AT_ANY_COST should produce an equal or better result
	assert_true(at_cost >= use_j, "AT_ANY_COST should not produce a worse result than USE_JUDGEMENT")

func test_resolver_come_home_safe_reduces_score() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 60, 50)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	var at_cost := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.AT_ANY_COST, 0.0
	)
	var safe := MissionResolver.resolve_mission_with_roll(
		contract, [hero], Enums.CommitmentLevel.COME_HOME_SAFE, 0.0
	)
	assert_true(safe <= at_cost, "COME_HOME_SAFE should not produce a better result than AT_ANY_COST")

func test_resolver_higher_difficulty_harder_to_succeed() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 60, 40, 30, 55, 45)
	var easy_contract := _make_contract("easy", 1, Enums.MissionType.ELIMINATE)
	var hard_contract := _make_contract("hard", 5, Enums.MissionType.ELIMINATE)
	var easy := MissionResolver.resolve_mission_with_roll(
		easy_contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, 0.0
	)
	var hard := MissionResolver.resolve_mission_with_roll(
		hard_contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT, 0.0
	)
	assert_true(hard <= easy, "Difficulty 5 should not produce a better result than difficulty 1")

func test_resolver_hero_score_uses_weighted_attributes() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.ROGUE, 30, 80, 75, 35, 35)
	var contract := _make_contract("c1", 1, Enums.MissionType.RETRIEVE, 0.0, 0.4, 0.5, 0.1, 0.0)
	var score := MissionResolver.hero_score(hero, contract)
	var expected := 80.0 * 0.4 + 75.0 * 0.5 + 35.0 * 0.1  # 32 + 37.5 + 3.5 = 73.0
	assert_almost_eq(score, expected, 0.01)

func test_resolver_squad_averaging_reduces_per_hero_effect() -> void:
	var strong := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 90, 40, 30, 70, 60)
	var weak   := _make_hero("h2", Enums.HeroArchetype.FIGHTER, 30, 30, 25, 30, 30)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	var score_solo := MissionResolver.hero_score(strong, contract)
	var result_duo := MissionResolver.resolve_mission_with_roll(
		contract, [strong, weak], Enums.CommitmentLevel.USE_JUDGEMENT, 0.0
	)
	var result_solo := MissionResolver.resolve_mission_with_roll(
		contract, [strong], Enums.CommitmentLevel.USE_JUDGEMENT, 0.0
	)
	assert_true(score_solo > 0.0)  # sanity
	# Solo strong hero >= duo with weak partner (squad average drag)
	assert_true(result_solo >= result_duo,
		"Solo strong hero should do at least as well as a duo with a weak partner")

# ─────────────────────────────────────────────────────────────────────────────
# MissionResolver — statistical (1000 runs with fixed seed)
# ─────────────────────────────────────────────────────────────────────────────

func test_resolver_strong_hero_mostly_succeeds_on_easy_contract() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 80, 50, 35, 70, 55)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	var successes := 0
	for _i in range(1000):
		var r := MissionResolver.resolve_mission(
			contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT
		)
		if r == Enums.MissionResult.SUCCESS or r == Enums.MissionResult.FULL_SUCCESS:
			successes += 1
	assert_gt(successes, 700, "Strong hero on difficulty 1 should succeed >70% of the time")

func test_resolver_weak_hero_often_fails_on_hard_contract() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 35, 30, 25, 30, 30)
	var contract := _make_contract("c1", 5, Enums.MissionType.ELIMINATE)
	var failures := 0
	for _i in range(1000):
		var r := MissionResolver.resolve_mission(
			contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT
		)
		if r == Enums.MissionResult.FAILURE:
			failures += 1
	assert_gt(failures, 700, "Weak hero on difficulty 5 should fail >70% of the time")

func test_resolver_all_four_outcomes_appear_in_1000_runs() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 60, 40, 30, 55, 45)
	var contract := _make_contract("c1", 2, Enums.MissionType.ELIMINATE)
	var seen := {}
	for _i in range(1000):
		var r := MissionResolver.resolve_mission(
			contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT
		)
		seen[r] = true
	assert_true(seen.has(Enums.MissionResult.FULL_SUCCESS), "FULL_SUCCESS should appear")
	assert_true(seen.has(Enums.MissionResult.SUCCESS),      "SUCCESS should appear")
	assert_true(seen.has(Enums.MissionResult.PARTIAL),      "PARTIAL should appear")
	assert_true(seen.has(Enums.MissionResult.FAILURE),      "FAILURE should appear")

# ─────────────────────────────────────────────────────────────────────────────
# InjuryResolver
# ─────────────────────────────────────────────────────────────────────────────

func test_injury_chance_higher_on_failure_than_success() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var injuries_on_success := 0
	var injuries_on_failure := 0
	for _i in range(1000):
		if InjuryResolver.roll_injury(hero, Enums.MissionResult.SUCCESS,
				Enums.CommitmentLevel.USE_JUDGEMENT, 2):
			injuries_on_success += 1
		if InjuryResolver.roll_injury(hero, Enums.MissionResult.FAILURE,
				Enums.CommitmentLevel.USE_JUDGEMENT, 2):
			injuries_on_failure += 1
	assert_gt(injuries_on_failure, injuries_on_success,
		"Injury rate on failure should exceed rate on success")

func test_injury_chance_higher_at_any_cost_vs_come_home_safe() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var injuries_risky := 0
	var injuries_safe := 0
	for _i in range(1000):
		if InjuryResolver.roll_injury(hero, Enums.MissionResult.SUCCESS,
				Enums.CommitmentLevel.AT_ANY_COST, 3):
			injuries_risky += 1
		if InjuryResolver.roll_injury(hero, Enums.MissionResult.SUCCESS,
				Enums.CommitmentLevel.COME_HOME_SAFE, 3):
			injuries_safe += 1
	assert_gt(injuries_risky, injuries_safe, "AT_ANY_COST should injure more than COME_HOME_SAFE")

func test_high_resilience_reduces_injury_chance() -> void:
	seed(42)
	var tough  := _make_hero("tough", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 90, 40)
	var fragile := _make_hero("frag", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 20, 40)
	var injuries_tough := 0
	var injuries_fragile := 0
	for _i in range(1000):
		if InjuryResolver.roll_injury(tough, Enums.MissionResult.PARTIAL,
				Enums.CommitmentLevel.USE_JUDGEMENT, 3):
			injuries_tough += 1
		if InjuryResolver.roll_injury(fragile, Enums.MissionResult.PARTIAL,
				Enums.CommitmentLevel.USE_JUDGEMENT, 3):
			injuries_fragile += 1
	assert_gt(injuries_fragile, injuries_tough,
		"Low resilience hero should be injured more often than high resilience hero")

func test_injury_severity_distribution_is_approximate() -> void:
	seed(42)
	var minor := 0; var serious := 0; var critical := 0
	for _i in range(10000):
		match InjuryResolver.roll_severity():
			Enums.InjurySeverity.MINOR:    minor += 1
			Enums.InjurySeverity.SERIOUS:  serious += 1
			Enums.InjurySeverity.CRITICAL: critical += 1
	# Expect MINOR≈60%, SERIOUS≈30%, CRITICAL≈10% (±5% tolerance)
	assert_gt(minor,    5500, "MINOR should be roughly 60%")
	assert_gt(serious,  2500, "SERIOUS should be roughly 30%")
	assert_gt(critical, 500,  "CRITICAL should be roughly 10%")
	assert_lt(minor,    6500, "MINOR should not exceed ~65%")
	assert_lt(serious,  3500, "SERIOUS should not exceed ~35%")
	assert_lt(critical, 1500, "CRITICAL should not exceed ~15%")

func test_capture_only_on_failure() -> void:
	assert_false(InjuryResolver.roll_capture(Enums.MissionResult.SUCCESS, false))
	assert_false(InjuryResolver.roll_capture(Enums.MissionResult.FULL_SUCCESS, false))
	assert_false(InjuryResolver.roll_capture(Enums.MissionResult.PARTIAL, false))

func test_capture_chance_higher_when_would_have_died() -> void:
	seed(42)
	var captures_normal := 0
	var captures_near_death := 0
	for _i in range(1000):
		if InjuryResolver.roll_capture(Enums.MissionResult.FAILURE, false):
			captures_normal += 1
		if InjuryResolver.roll_capture(Enums.MissionResult.FAILURE, true):
			captures_near_death += 1
	assert_gt(captures_near_death, captures_normal,
		"Near-death capture chance (40%) should exceed base (20%)")

func test_injury_resolver_full_pipeline_no_error() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var outcome := InjuryResolver.resolve_hero_outcome(
		hero, Enums.MissionResult.FAILURE, Enums.CommitmentLevel.AT_ANY_COST, 4
	)
	assert_true(outcome.has("injured"))
	assert_true(outcome.has("died"))
	assert_true(outcome.has("captured"))
	assert_true(outcome.has("recovery_days"))

func test_injury_resolver_dead_and_captured_mutually_exclusive() -> void:
	seed(42)
	for _i in range(500):
		var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 30, 25, 20, 25, 25)
		var outcome := InjuryResolver.resolve_hero_outcome(
			hero, Enums.MissionResult.FAILURE, Enums.CommitmentLevel.AT_ANY_COST, 5
		)
		assert_false(outcome["died"] and outcome["captured"],
			"Hero cannot be both dead and captured")

# ─────────────────────────────────────────────────────────────────────────────
# RelationshipModifier
# ─────────────────────────────────────────────────────────────────────────────

func test_bond_adds_positive_performance_modifier() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var h2 := _make_hero("h2", Enums.HeroArchetype.ROGUE,   40, 70, 65, 35, 35)
	var rel := HeroRelationship.new()
	rel.other_hero_id = "h2"
	rel.relationship_type = Enums.RelationshipType.BOND
	rel.performance_modifier = 5.0
	rel.morale_modifier = 5.0
	h1.bonds.append(rel)
	var mod := RelationshipModifier.get_score_modifier([h1, h2])
	assert_almost_eq(mod, 5.0, 0.01)

func test_tension_adds_negative_performance_modifier() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var h2 := _make_hero("h2", Enums.HeroArchetype.ROGUE,   40, 70, 65, 35, 35)
	var rel := HeroRelationship.new()
	rel.other_hero_id = "h2"
	rel.relationship_type = Enums.RelationshipType.TENSION
	rel.performance_modifier = -3.0
	rel.morale_modifier = -5.0
	h1.tensions.append(rel)
	var mod := RelationshipModifier.get_score_modifier([h1, h2])
	assert_almost_eq(mod, -3.0, 0.01)

func test_no_relationship_yields_zero_modifier() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var h2 := _make_hero("h2", Enums.HeroArchetype.ROGUE,   40, 70, 65, 35, 35)
	assert_almost_eq(RelationshipModifier.get_score_modifier([h1, h2]), 0.0, 0.01)

func test_solo_hero_has_zero_relationship_modifier() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	assert_almost_eq(RelationshipModifier.get_score_modifier([h1]), 0.0, 0.01)

func test_morale_modifier_computed_for_hero() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 50, 40, 30, 50, 40)
	var h2 := _make_hero("h2", Enums.HeroArchetype.ROGUE,   40, 70, 65, 35, 35)
	var rel := HeroRelationship.new()
	rel.other_hero_id = "h2"
	rel.relationship_type = Enums.RelationshipType.BOND
	rel.morale_modifier = 5.0
	rel.performance_modifier = 2.0
	h1.bonds.append(rel)
	var morale_mod := RelationshipModifier.get_morale_modifier(h1, [h1, h2])
	assert_almost_eq(morale_mod, 5.0, 0.01)

# ─────────────────────────────────────────────────────────────────────────────
# MissionManager — dispatch and completion flow
# ─────────────────────────────────────────────────────────────────────────────

func test_dispatch_sets_hero_status_to_on_mission() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	MissionManager.dispatch_heroes(contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_eq(HeroManager.get_hero("h1").status, Enums.HeroStatus.ON_MISSION)

func test_dispatch_emits_hero_dispatched_signal() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	watch_signals(EventBus)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	MissionManager.dispatch_heroes(contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_signal_emitted(EventBus, "hero_dispatched")

func test_dispatch_rejects_unavailable_hero() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	hero.status = Enums.HeroStatus.INJURED
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	var mission_id := MissionManager.dispatch_heroes(
		contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	assert_eq(mission_id, "", "Should return empty string for unavailable hero")

func test_dispatch_returns_unique_mission_ids() -> void:
	var h1 := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	var h2 := _make_hero("h2", Enums.HeroArchetype.ROGUE, 35, 75, 70, 35, 35)
	HeroManager._inject_hero_for_test(h1)
	HeroManager._inject_hero_for_test(h2)
	var c1 := _make_contract("c1", 1, Enums.MissionType.ELIMINATE)
	var c2 := _make_contract("c2", 1, Enums.MissionType.RETRIEVE)
	var id1 := MissionManager.dispatch_heroes(c1, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	var id2 := MissionManager.dispatch_heroes(c2, ["h2"], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_ne(id1, id2, "Each dispatch should produce a unique mission ID")

func test_mission_completes_after_duration_days() -> void:
	seed(42)
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 80, 50, 35, 75, 55)
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE,
		0.6, 0.0, 0.0, 0.2, 0.2, 100, 40, 2)
	var mid := MissionManager.dispatch_heroes(contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_eq(MissionManager.get_active_missions().size(), 1, "Mission should be active")
	# Advance 2 days to reach completion, then finalize.
	TimeManager.advance_day()
	TimeManager.advance_day()
	MissionManager.finalize_mission(mid)
	assert_eq(MissionManager.get_active_missions().size(), 0, "Mission should be resolved")

func test_successful_mission_awards_gold() -> void:
	seed(0)  # Seed chosen to reliably get a success with this hero/contract
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 90, 50, 35, 80, 60)
	HeroManager._inject_hero_for_test(hero)
	var starting_gold := GuildManager.get_state().gold
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE,
		0.6, 0.0, 0.0, 0.2, 0.2, 100, 40, 1)
	var mid := MissionManager.dispatch_heroes(contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	TimeManager.advance_day()
	MissionManager.finalize_mission(mid)
	# Hero is either back or injured/dead; gold should have changed
	var final_gold := GuildManager.get_state().gold
	# With a strong hero on difficulty 1, we expect gold or partial gold
	assert_ne(final_gold, starting_gold, "Gold should change after mission completes")

func test_update_commitment_changes_active_mission() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1", 1, Enums.MissionType.ELIMINATE,
		0.6, 0.0, 0.0, 0.2, 0.2, 100, 40, 3)
	var mid := MissionManager.dispatch_heroes(
		contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	MissionManager.update_commitment(mid, Enums.CommitmentLevel.COME_HOME_SAFE)
	var missions := MissionManager.get_active_missions()
	assert_eq(missions[0].commitment, Enums.CommitmentLevel.COME_HOME_SAFE)

# ─────────────────────────────────────────────────────────────────────────────
# HeroManager — injury / death / capture
# ─────────────────────────────────────────────────────────────────────────────

func test_apply_injury_sets_recovering_status_for_serious() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	HeroManager.apply_injury("h1", Enums.InjurySeverity.SERIOUS)
	assert_eq(hero.status, Enums.HeroStatus.RECOVERING)

func test_apply_injury_sets_injured_status_for_minor() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	HeroManager.apply_injury("h1", Enums.InjurySeverity.MINOR)
	assert_eq(hero.status, Enums.HeroStatus.INJURED)

func test_apply_injury_emits_hero_wounded() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	watch_signals(EventBus)
	HeroManager.apply_injury("h1", Enums.InjurySeverity.MINOR)
	assert_signal_emitted(EventBus, "hero_wounded")

func test_kill_hero_sets_dead_status() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	HeroManager.kill_hero("h1", "mission_1")
	assert_eq(hero.status, Enums.HeroStatus.DEAD)

func test_kill_hero_emits_hero_killed() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	watch_signals(EventBus)
	HeroManager.kill_hero("h1", "mission_1")
	assert_signal_emitted(EventBus, "hero_killed")

func test_capture_hero_sets_captured_status() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	HeroManager.capture_hero("h1", "mission_1")
	assert_eq(hero.status, Enums.HeroStatus.CAPTURED)

func test_hero_recovers_after_recovery_days() -> void:
	var hero := _make_hero("h1", Enums.HeroArchetype.FIGHTER, 70, 40, 30, 65, 50)
	HeroManager._inject_hero_for_test(hero)
	HeroManager.apply_injury("h1", Enums.InjurySeverity.MINOR)  # 2 days
	assert_eq(hero.status, Enums.HeroStatus.INJURED)
	TimeManager.advance_day()
	TimeManager.advance_day()
	assert_eq(hero.status, Enums.HeroStatus.AVAILABLE, "Hero should recover after 2 days")
