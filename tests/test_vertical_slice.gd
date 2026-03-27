extends GutTest
## Integration test for the core gameplay loop (M8 vertical slice).
## Runs entirely headless: no UI, no scene changes.
## Verifies: dispatch → day advancement → mission resolution → gold + hero status.

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hero(id: String, strength: float = 80.0) -> HeroData:
	var h := HeroData.new()
	h.hero_id        = id
	h.display_name   = "Hero %s" % id
	h.archetype      = Enums.HeroArchetype.FIGHTER
	h.personality_type = Enums.PersonalityType.STOIC
	h.strength       = strength
	h.agility        = 60.0
	h.stealth        = 50.0
	h.resilience     = 70.0
	h.leadership     = 40.0
	h.morale         = 80.0
	h.morale_floor   = 20.0
	h.status         = Enums.HeroStatus.AVAILABLE
	return h

func _make_contract(id: String, difficulty: int = 1, duration: int = 2) -> ContractData:
	var c := ContractData.new()
	c.contract_id       = id
	c.title             = "Test: %s" % id
	c.difficulty        = difficulty
	c.base_duration_days = duration
	c.distance_days     = 0
	c.reward_gold       = 100
	c.reward_gold_partial = 40
	c.available_from_day = 1
	c.expiry_day        = 999
	c.weight_strength   = 1.0
	c.min_heroes        = 1
	c.recommended_heroes = 1
	return c

func before_each() -> void:
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()
	GuildManager._reset_for_test()
	TimeManager._reset_for_test()
	FeedManager._reset_for_test()
	ContractQueue._reset_for_test()

func after_each() -> void:
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()
	FeedManager._reset_for_test()

# ── Dispatch ──────────────────────────────────────────────────────────────────

func test_dispatch_sets_hero_on_mission() -> void:
	var hero := _make_hero("h1")
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1")

	var mission_id := MissionManager.dispatch_heroes(
		contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)

	assert_ne(mission_id, "", "dispatch_heroes should return a non-empty mission_id")
	assert_eq(HeroManager.get_hero("h1").status, Enums.HeroStatus.ON_MISSION,
			"Hero should be ON_MISSION after dispatch")

func test_dispatch_unavailable_hero_fails() -> void:
	var hero := _make_hero("h1")
	hero.status = Enums.HeroStatus.INJURED
	HeroManager._inject_hero_for_test(hero)

	var mission_id := MissionManager.dispatch_heroes(
		_make_contract("c1"), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)

	assert_eq(mission_id, "", "Dispatching an injured hero should fail")

func test_dispatch_emits_hero_dispatched_signal() -> void:
	watch_signals(EventBus)
	HeroManager._inject_hero_for_test(_make_hero("h1"))

	MissionManager.dispatch_heroes(
		_make_contract("c1"), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)

	assert_signal_emitted(EventBus, "hero_dispatched")

func test_dispatch_emits_departure_feed_event() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	FeedManager._inject_templates_for_test({
		"hero_departed": {"DEFAULT": ["{name} leaves."]}
	})

	var mission_id := MissionManager.dispatch_heroes(
		_make_contract("c1"), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)

	assert_false(FeedManager.get_feed(mission_id).is_empty(),
			"Feed should contain departure event after dispatch")

# ── Resolution ────────────────────────────────────────────────────────────────

func test_mission_not_resolved_before_completion_day() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	MissionManager.dispatch_heroes(
		_make_contract("c1", 1, 3), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	# Start day=1, completion_day = 1 + 3 = 4. Day 3 should not resolve.
	MissionManager._on_day_advanced(3)

	assert_eq(HeroManager.get_hero("h1").status, Enums.HeroStatus.ON_MISSION,
			"Hero should still be ON_MISSION before completion day")
	assert_eq(MissionManager.get_active_missions().size(), 1,
			"Mission should still be active before completion day")

func test_mission_resolves_on_completion_day() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	# duration=2, start_day=1 → completion_day=3
	var mid := MissionManager.dispatch_heroes(
		_make_contract("c1", 1, 2), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)

	MissionManager._on_day_advanced(3)
	MissionManager.finalize_mission(mid)

	assert_eq(MissionManager.get_active_missions().size(), 0,
			"No active missions after completion day")
	var status := HeroManager.get_hero("h1").status
	assert_ne(status, Enums.HeroStatus.ON_MISSION,
			"Hero should not be ON_MISSION after resolution")

func test_gold_changes_after_resolution() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1", 100.0))
	var contract := _make_contract("c1", 1, 2)
	contract.reward_gold = 100
	contract.reward_gold_partial = 40
	var gold_before: int = GuildManager.get_state().gold

	var mid := MissionManager.dispatch_heroes(contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT)
	MissionManager._on_day_advanced(3)
	MissionManager.finalize_mission(mid)

	var gold_after: int = GuildManager.get_state().gold
	# On any non-failure result, gold increases. On failure it stays the same.
	assert_true(gold_after >= gold_before,
			"Gold should be >= initial after resolution (no negative reward)")

func test_resolution_clears_mission_from_active() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	var mid := MissionManager.dispatch_heroes(
		_make_contract("c1", 1, 1), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	assert_eq(MissionManager.get_active_missions().size(), 1)

	MissionManager._on_day_advanced(2)
	MissionManager.finalize_mission(mid)

	assert_eq(MissionManager.get_active_missions().size(), 0,
			"Mission removed from active after resolution")

# ── Multiple simultaneous missions ────────────────────────────────────────────

func test_two_missions_resolve_independently() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	HeroManager._inject_hero_for_test(_make_hero("h2"))

	# h1: completes on day 3; h2: completes on day 5
	var mid1 := MissionManager.dispatch_heroes(
		_make_contract("c1", 1, 2), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	MissionManager.dispatch_heroes(
		_make_contract("c2", 1, 4), ["h2"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	assert_eq(MissionManager.get_active_missions().size(), 2)

	MissionManager._on_day_advanced(3)
	MissionManager.finalize_mission(mid1)
	assert_eq(MissionManager.get_active_missions().size(), 1,
			"Only h1 mission resolves on day 3")
	assert_ne(HeroManager.get_hero("h1").status, Enums.HeroStatus.ON_MISSION,
			"h1 resolved")
	assert_eq(HeroManager.get_hero("h2").status, Enums.HeroStatus.ON_MISSION,
			"h2 still on mission")

	var mid2_arr := MissionManager.get_active_missions()
	var mid2: String = mid2_arr[0].mission_id
	MissionManager._on_day_advanced(5)
	MissionManager.finalize_mission(mid2)
	assert_eq(MissionManager.get_active_missions().size(), 0,
			"Both missions resolved")

# ── Feed integration ──────────────────────────────────────────────────────────

func test_resolution_populates_feed() -> void:
	HeroManager._inject_hero_for_test(_make_hero("h1"))
	# Inject minimal templates so FeedManager doesn't error on unknown keys.
	var tpls: Dictionary = {}
	for key: String in FeedManager.REQUIRED_EVENT_KEYS:
		tpls[key] = {"DEFAULT": [key + " happened."]}
	FeedManager._inject_templates_for_test(tpls)

	var mission_id := MissionManager.dispatch_heroes(
		_make_contract("c1", 1, 1), ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	MissionManager._on_day_advanced(2)

	assert_true(FeedManager.get_feed(mission_id).size() > 1,
			"Feed should contain multiple events after resolution (departure + narrative)")

# ── Contract queue integration ────────────────────────────────────────────────

func test_morning_phase_refills_board_after_advance() -> void:
	var tpls := _make_early_templates()
	ContractQueue._inject_templates_for_test(tpls)

	ContractQueue.on_morning_phase(1)
	var day1_count: int = ContractQueue.active_contracts.size()
	assert_between(day1_count, 2, 3, "Day 1 board should have 2-3 contracts")

	# Expire all, advance to day 2
	for c: ContractData in ContractQueue.active_contracts:
		c.expiry_day = 1
	ContractQueue.on_morning_phase(2)
	assert_between(ContractQueue.active_contracts.size(), 2, 3,
			"Board refilled after advancing day")

func _make_early_templates() -> Dictionary:
	var result: Dictionary = {}
	for i: int in 8:
		var cd := ContractData.new()
		cd.contract_id = "tpl_%d" % i
		cd.available_from_day = 1
		cd.expiry_day = 999
		result[cd.contract_id] = cd
	return result
