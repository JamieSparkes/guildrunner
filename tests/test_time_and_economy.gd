## M3 GUT tests — TimeManager day/week cycle + GuildManager economy
extends GutTest

# ── Setup ─────────────────────────────────────────────────────────────────────

func before_each() -> void:
	TimeManager._reset_for_test()
	GuildManager._reset_for_test()

func after_each() -> void:
	TimeManager._reset_for_test()
	GuildManager._reset_for_test()

# ── TimeManager: initial state ────────────────────────────────────────────────

func test_time_manager_starts_on_day_1() -> void:
	assert_eq(TimeManager.current_day, 1)

func test_time_manager_starts_in_morning_phase() -> void:
	assert_eq(TimeManager.phase, Enums.DayPhase.MORNING)

func test_week_number_day_1_is_week_1() -> void:
	assert_eq(TimeManager.week_number, 1)

func test_week_number_day_7_is_week_1() -> void:
	for _i in range(6):
		TimeManager.advance_day()
	assert_eq(TimeManager.current_day, 7)
	assert_eq(TimeManager.week_number, 1)

func test_week_number_day_8_is_week_2() -> void:
	for _i in range(7):
		TimeManager.advance_day()
	assert_eq(TimeManager.current_day, 8)
	assert_eq(TimeManager.week_number, 2)

# ── TimeManager: advance_day ──────────────────────────────────────────────────

func test_advance_day_increments_current_day() -> void:
	TimeManager.advance_day()
	assert_eq(TimeManager.current_day, 2)

func test_advance_day_sets_phase_to_morning() -> void:
	TimeManager.trigger_night_phase()
	TimeManager.advance_day()
	assert_eq(TimeManager.phase, Enums.DayPhase.MORNING)

func test_advance_day_emits_day_advanced_signal() -> void:
	watch_signals(EventBus)
	TimeManager.advance_day()
	assert_signal_emitted(EventBus, "day_advanced")

func test_advance_day_signal_carries_new_day_number() -> void:
	watch_signals(EventBus)
	TimeManager.advance_day()
	assert_signal_emitted_with_parameters(EventBus, "day_advanced", [2])

func test_advance_day_multiple_times() -> void:
	for _i in range(5):
		TimeManager.advance_day()
	assert_eq(TimeManager.current_day, 6)

# ── TimeManager: trigger_night_phase ─────────────────────────────────────────

func test_trigger_night_phase_sets_phase() -> void:
	TimeManager.trigger_night_phase()
	assert_eq(TimeManager.phase, Enums.DayPhase.NIGHT)

func test_trigger_night_phase_emits_night_began() -> void:
	watch_signals(EventBus)
	TimeManager.trigger_night_phase()
	assert_signal_emitted(EventBus, "night_began")

func test_trigger_night_phase_signal_carries_day() -> void:
	watch_signals(EventBus)
	TimeManager.trigger_night_phase()
	assert_signal_emitted_with_parameters(EventBus, "night_began", [1])

# ── TimeManager: weekly boundary ─────────────────────────────────────────────

func test_week_advanced_signal_fires_on_day_7() -> void:
	watch_signals(EventBus)
	for _i in range(6):
		TimeManager.advance_day()
	assert_signal_emitted(EventBus, "week_advanced")

func test_week_advanced_signal_does_not_fire_on_day_6() -> void:
	watch_signals(EventBus)
	for _i in range(5):
		TimeManager.advance_day()
	assert_signal_not_emitted(EventBus, "week_advanced")

# ── GuildManager: initial state ───────────────────────────────────────────────

func test_guild_manager_starts_with_200_gold() -> void:
	assert_eq(GuildManager.get_state().gold, 200)

func test_guild_manager_starts_with_zero_tokens() -> void:
	assert_eq(GuildManager.get_state().intervention_tokens, 0)

# ── GuildManager: gold operations ────────────────────────────────────────────

func test_add_gold_increases_gold() -> void:
	GuildManager.add_gold(50)
	assert_eq(GuildManager.get_state().gold, 250)

func test_deduct_gold_decreases_gold() -> void:
	GuildManager.deduct_gold(50)
	assert_eq(GuildManager.get_state().gold, 150)

func test_deduct_gold_returns_true_when_sufficient() -> void:
	assert_true(GuildManager.deduct_gold(100))

func test_deduct_gold_returns_false_when_insufficient() -> void:
	assert_false(GuildManager.deduct_gold(999))

func test_deduct_gold_does_not_modify_on_failure() -> void:
	GuildManager.deduct_gold(999)
	assert_eq(GuildManager.get_state().gold, 200)

func test_add_gold_emits_gold_changed() -> void:
	watch_signals(EventBus)
	GuildManager.add_gold(10)
	assert_signal_emitted(EventBus, "gold_changed")

func test_deduct_gold_emits_gold_changed_on_success() -> void:
	watch_signals(EventBus)
	GuildManager.deduct_gold(10)
	assert_signal_emitted(EventBus, "gold_changed")

func test_deduct_gold_does_not_emit_on_failure() -> void:
	watch_signals(EventBus)
	GuildManager.deduct_gold(999)
	assert_signal_not_emitted(EventBus, "gold_changed")

# ── GuildManager: upkeep calculation ─────────────────────────────────────────

func test_upkeep_zero_with_empty_roster() -> void:
	# HeroManager has no heroes after reset
	assert_eq(GuildManager.calculate_upkeep(), 0)

func test_upkeep_fighter_costs_8_gold() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_fighter"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.AVAILABLE
	HeroManager._inject_hero_for_test(hero)
	assert_eq(GuildManager.calculate_upkeep(), 8)
	HeroManager._clear_roster_for_test()

func test_upkeep_rogue_costs_7_gold() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_rogue"
	hero.archetype = Enums.HeroArchetype.ROGUE
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.AVAILABLE
	HeroManager._inject_hero_for_test(hero)
	assert_eq(GuildManager.calculate_upkeep(), 7)
	HeroManager._clear_roster_for_test()

func test_upkeep_legendary_adds_3_surcharge() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_legend"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = true
	hero.status = Enums.HeroStatus.AVAILABLE
	HeroManager._inject_hero_for_test(hero)
	assert_eq(GuildManager.calculate_upkeep(), 11)  # 8 + 3
	HeroManager._clear_roster_for_test()

func test_upkeep_excludes_dead_heroes() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_dead"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.DEAD
	HeroManager._inject_hero_for_test(hero)
	assert_eq(GuildManager.calculate_upkeep(), 0)
	HeroManager._clear_roster_for_test()

# ── GuildManager: upkeep application ─────────────────────────────────────────

func test_apply_weekly_upkeep_deducts_gold() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_upkeep"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.AVAILABLE
	HeroManager._inject_hero_for_test(hero)
	GuildManager.apply_weekly_upkeep()
	assert_eq(GuildManager.get_state().gold, 192)  # 200 - 8
	HeroManager._clear_roster_for_test()

func test_apply_weekly_upkeep_records_last_upkeep_day() -> void:
	GuildManager.apply_weekly_upkeep()
	assert_eq(GuildManager.get_state().last_upkeep_day, TimeManager.current_day)

# ── GuildManager: debt + morale penalty ──────────────────────────────────────

func test_debt_upkeep_drains_gold_to_zero_or_below() -> void:
	GuildManager.get_state().gold = 5  # Less than 8 gold upkeep
	var hero := HeroData.new()
	hero.hero_id = "test_debt"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.AVAILABLE
	hero.morale = 80.0
	hero.morale_floor = 20.0
	HeroManager._inject_hero_for_test(hero)
	GuildManager.apply_weekly_upkeep()
	assert_lt(GuildManager.get_state().gold, 5, "Gold should have decreased")
	HeroManager._clear_roster_for_test()

func test_debt_upkeep_adds_consequence_to_pending() -> void:
	GuildManager.get_state().gold = 0
	var hero := HeroData.new()
	hero.hero_id = "test_debt2"
	hero.archetype = Enums.HeroArchetype.FIGHTER
	hero.is_legendary = false
	hero.status = Enums.HeroStatus.AVAILABLE
	hero.morale = 80.0
	hero.morale_floor = 20.0
	HeroManager._inject_hero_for_test(hero)
	GuildManager.apply_weekly_upkeep()
	var has_debt := false
	for c in GuildManager.get_state().pending_consequences:
		if c.get("type") == "upkeep_debt":
			has_debt = true
	assert_true(has_debt, "Debt consequence should be recorded")
	HeroManager._clear_roster_for_test()

# ── GuildManager: intervention tokens ────────────────────────────────────────

func test_reset_tokens_fills_to_max() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	assert_eq(GuildManager.get_state().intervention_tokens, 2)

func test_spend_token_decrements() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	GuildManager.spend_intervention_token()
	assert_eq(GuildManager.get_state().intervention_tokens, 0)

func test_spend_token_returns_false_when_empty() -> void:
	assert_false(GuildManager.spend_intervention_token())
