extends GutTest
## Tests for M10: Building System.
## Covers: construction flow, completion timing, gold cost, each building's effects,
## Infirmary recovery reduction, max tier enforcement, double-queue guard.

func before_each() -> void:
	BuildingManager._reset_for_test()
	GuildManager._reset_for_test()
	TimeManager._reset_for_test()
	watch_signals(EventBus)

func after_each() -> void:
	BuildingManager._reset_for_test()
	GuildManager._reset_for_test()

# ── Construction flow ─────────────────────────────────────────────────────────

func test_begin_construction_returns_true_on_success() -> void:
	GuildManager.get_state().gold = 9999
	assert_true(BuildingManager.begin_construction("barracks"), "begin_construction returns true")

func test_begin_construction_deducts_gold() -> void:
	var building: BuildingData = BuildingManager.get_building("barracks")
	var cost: int = building.build_costs_gold[0]
	GuildManager.get_state().gold = cost + 50
	BuildingManager.begin_construction("barracks")
	assert_eq(GuildManager.get_state().gold, 50, "Gold deducted correctly")

func test_begin_construction_fails_when_insufficient_gold() -> void:
	GuildManager.get_state().gold = 1
	assert_false(BuildingManager.begin_construction("barracks"), "Fails when can't afford")

func test_begin_construction_adds_to_queue() -> void:
	GuildManager.get_state().gold = 9999
	BuildingManager.begin_construction("barracks")
	assert_true(BuildingManager.is_under_construction("barracks"), "Building queued")

func test_begin_construction_emits_signal() -> void:
	GuildManager.get_state().gold = 9999
	BuildingManager.begin_construction("barracks")
	assert_signal_emitted(EventBus, "building_construction_started")

func test_begin_construction_prevents_double_queue() -> void:
	GuildManager.get_state().gold = 9999
	BuildingManager.begin_construction("barracks")
	assert_false(BuildingManager.begin_construction("barracks"),
			"Second queuing of same building fails")

func test_begin_construction_fails_at_max_tier() -> void:
	GuildManager.get_state().gold = 9999
	GuildManager.get_state().building_tiers["barracks"] = 2
	assert_false(BuildingManager.begin_construction("barracks"), "Fails at max tier")

# ── Completion timing ─────────────────────────────────────────────────────────

func test_construction_completes_on_correct_day() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("barracks")
	var duration: int = building.build_time_days[0]
	BuildingManager.begin_construction("barracks")
	for _i: int in duration - 1:
		TimeManager.advance_day()
	assert_true(BuildingManager.is_under_construction("barracks"),
			"Still constructing one day before completion")
	TimeManager.advance_day()
	assert_false(BuildingManager.is_under_construction("barracks"),
			"No longer under construction after completion day")

func test_construction_emits_upgrade_built_on_completion() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("barracks")
	var duration: int = building.build_time_days[0]
	BuildingManager.begin_construction("barracks")
	for _i: int in duration:
		TimeManager.advance_day()
	assert_signal_emitted(EventBus, "upgrade_built")

func test_construction_updates_tier_on_completion() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("barracks")
	var duration: int = building.build_time_days[0]
	BuildingManager.begin_construction("barracks")
	for _i: int in duration:
		TimeManager.advance_day()
	assert_eq(BuildingManager.get_tier("barracks"), 1, "Tier updated to 1 after completion")

# ── Building effects ──────────────────────────────────────────────────────────

func test_barracks_t1_sets_max_roster_size_6() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("barracks")
	BuildingManager.begin_construction("barracks")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().max_roster_size, 6, "Barracks T1 sets roster cap to 6")

func test_barracks_t2_sets_max_roster_size_12() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("barracks")
	BuildingManager.begin_construction("barracks")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	assert_eq(BuildingManager.get_tier("barracks"), 1)
	BuildingManager.begin_construction("barracks")
	for _i: int in building.build_time_days[1]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().max_roster_size, 12, "Barracks T2 sets roster cap to 12")

func test_tavern_t1_sets_intervention_tokens_1() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("tavern")
	BuildingManager.begin_construction("tavern")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().max_intervention_tokens, 1,
			"Tavern T1 sets max_intervention_tokens to 1")

func test_tavern_t2_sets_intervention_tokens_2() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("tavern")
	BuildingManager.begin_construction("tavern")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	BuildingManager.begin_construction("tavern")
	for _i: int in building.build_time_days[1]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().max_intervention_tokens, 2,
			"Tavern T2 sets max_intervention_tokens to 2")

func test_infirmary_t1_sets_recovery_day_reduction_1() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("infirmary")
	BuildingManager.begin_construction("infirmary")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().recovery_day_reduction, 1,
			"Infirmary T1 sets recovery_day_reduction to 1")

func test_infirmary_t2_sets_recovery_day_reduction_2() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("infirmary")
	BuildingManager.begin_construction("infirmary")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	BuildingManager.begin_construction("infirmary")
	for _i: int in building.build_time_days[1]:
		TimeManager.advance_day()
	assert_eq(GuildManager.get_state().recovery_day_reduction, 2,
			"Infirmary T2 sets recovery_day_reduction to 2")

func test_unknown_effects_stored_in_building_flags() -> void:
	GuildManager.get_state().gold = 9999
	var building: BuildingData = BuildingManager.get_building("forge")
	BuildingManager.begin_construction("forge")
	for _i: int in building.build_time_days[0]:
		TimeManager.advance_day()
	assert_true(GuildManager.get_state().building_flags.size() > 0,
			"Forge T1 flags stored in building_flags")

# ── Infirmary — HeroManager interaction ───────────────────────────────────────

func test_infirmary_reduces_hero_recovery_days() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_hero"
	hero.status = Enums.HeroStatus.AVAILABLE
	hero.morale_floor = 20.0
	HeroManager._inject_hero_for_test(hero)
	GuildManager.get_state().recovery_day_reduction = 1
	HeroManager.apply_injury("test_hero", Enums.InjurySeverity.MINOR)
	# MINOR = 2 days; reduction = 1 → should be 1 day
	assert_eq(hero.injury_recovery_days, 1, "Infirmary reduces recovery by 1 day")
	HeroManager._clear_roster_for_test()

func test_hero_recovery_never_drops_below_1() -> void:
	var hero := HeroData.new()
	hero.hero_id = "test_hero2"
	hero.status = Enums.HeroStatus.AVAILABLE
	hero.morale_floor = 20.0
	HeroManager._inject_hero_for_test(hero)
	GuildManager.get_state().recovery_day_reduction = 99
	HeroManager.apply_injury("test_hero2", Enums.InjurySeverity.MINOR)
	assert_eq(hero.injury_recovery_days, 1, "Recovery days floored at 1")
	HeroManager._clear_roster_for_test()

# ── buildings.json integration ────────────────────────────────────────────────

func test_all_six_buildings_loaded() -> void:
	var buildings: Dictionary = BuildingManager.get_all_buildings()
	assert_eq(buildings.size(), 6, "All 6 buildings loaded from JSON")

func test_each_building_has_two_tiers_worth_of_data() -> void:
	for id: String in BuildingManager.get_all_buildings().keys():
		var b: BuildingData = BuildingManager.get_building(id)
		assert_eq(b.build_costs_gold.size(), 2, "%s has 2 build costs" % id)
		assert_eq(b.build_time_days.size(), 2, "%s has 2 build times" % id)
