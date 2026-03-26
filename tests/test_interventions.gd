extends GutTest
## Tests for M9: Multi-Column Feed + Interventions.
## Covers: token deduction/reset, commitment update, intervention signal triggers,
## no-trigger-without-tokens, no double-trigger, 6 independent feeds.

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_hero(id: String) -> HeroData:
	var h := HeroData.new()
	h.hero_id          = id
	h.display_name     = "Hero %s" % id
	h.archetype        = Enums.HeroArchetype.FIGHTER
	h.personality_type = Enums.PersonalityType.STOIC
	h.strength         = 80.0
	h.agility          = 60.0
	h.stealth          = 50.0
	h.resilience       = 70.0
	h.leadership       = 40.0
	h.morale           = 80.0
	h.morale_floor     = 20.0
	h.status           = Enums.HeroStatus.AVAILABLE
	return h

func _make_contract(id: String, duration: int = 3) -> ContractData:
	var c := ContractData.new()
	c.contract_id        = id
	c.title              = "Mission %s" % id
	c.difficulty         = 2
	c.base_duration_days = duration
	c.distance_days      = 0
	c.reward_gold        = 100
	c.reward_gold_partial = 40
	c.available_from_day = 1
	c.expiry_day         = 999
	c.weight_strength    = 1.0
	c.min_heroes         = 1
	c.recommended_heroes = 1
	return c

## Push a trigger event directly through FeedManager.
func _push_trigger(mission_id: String, event_key: String) -> void:
	FeedManager.push_event(mission_id, event_key, {
		"personality": "STOIC",
		"name": "Test Hero",
		"target": "Somewhere",
	})

func before_each() -> void:
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()
	GuildManager._reset_for_test()
	TimeManager._reset_for_test()
	FeedManager._reset_for_test()
	watch_signals(EventBus)

func after_each() -> void:
	HeroManager._clear_roster_for_test()
	MissionManager._reset_for_test()
	GuildManager._reset_for_test()
	FeedManager._reset_for_test()

# ── Token API ─────────────────────────────────────────────────────────────────

func test_spend_token_deducts_by_one() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	GuildManager.spend_intervention_token()
	assert_eq(GuildManager.get_state().intervention_tokens, 1, "One token spent")

func test_spend_token_returns_true_when_available() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	assert_true(GuildManager.spend_intervention_token(), "Returns true when token available")

func test_spend_token_returns_false_when_empty() -> void:
	GuildManager.set_max_intervention_tokens(0)
	GuildManager.reset_intervention_tokens()
	assert_false(GuildManager.spend_intervention_token(), "Returns false when no tokens")

func test_spend_token_does_not_go_negative() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	GuildManager.spend_intervention_token()
	GuildManager.spend_intervention_token()  # Second call on empty
	assert_eq(GuildManager.get_state().intervention_tokens, 0, "Tokens do not go below 0")

func test_reset_tokens_restores_to_max() -> void:
	GuildManager.set_max_intervention_tokens(3)
	GuildManager.reset_intervention_tokens()
	GuildManager.spend_intervention_token()
	GuildManager.spend_intervention_token()
	GuildManager.reset_intervention_tokens()
	assert_eq(GuildManager.get_state().intervention_tokens, 3, "Tokens restored to max on reset")

func test_reset_tokens_on_day_advanced() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	GuildManager.spend_intervention_token()
	assert_eq(GuildManager.get_state().intervention_tokens, 1, "One token spent before day advance")
	# TimeManager.advance_day() fires day_advanced; GuildManager connects to reset tokens.
	TimeManager.advance_day()
	assert_eq(GuildManager.get_state().intervention_tokens, 2, "Tokens reset on new morning")

# ── Commitment update ─────────────────────────────────────────────────────────

func test_update_commitment_changes_active_mission() -> void:
	var hero := _make_hero("h1")
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1")
	var mid := MissionManager.dispatch_heroes(
		contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	assert_ne(mid, "", "Mission dispatched")
	MissionManager.update_commitment(mid, Enums.CommitmentLevel.COME_HOME_SAFE)
	var missions: Array = MissionManager.get_active_missions()
	assert_eq(missions.size(), 1, "One active mission")
	assert_eq(
		missions[0].commitment,
		Enums.CommitmentLevel.COME_HOME_SAFE,
		"Commitment changed to COME_HOME_SAFE"
	)

func test_update_commitment_noop_for_unknown_mission() -> void:
	# Should not crash.
	MissionManager.update_commitment("nonexistent_id", Enums.CommitmentLevel.AT_ANY_COST)
	pass_test("No crash on unknown mission_id")

# ── Intervention signal triggers ──────────────────────────────────────────────

func test_trigger_key_emits_intervention_signal_when_tokens_available() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_minor")
	assert_signal_emitted_with_parameters(
		EventBus, "feed_intervention_available", ["m1"]
	)

func test_encounter_obstacle_triggers_intervention() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "encounter_obstacle")
	assert_signal_emitted_with_parameters(
		EventBus, "feed_intervention_available", ["m1"]
	)

func test_hero_wounded_serious_triggers_intervention() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_serious")
	assert_signal_emitted_with_parameters(
		EventBus, "feed_intervention_available", ["m1"]
	)

func test_non_trigger_key_does_not_emit_signal() -> void:
	GuildManager.set_max_intervention_tokens(1)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "travel_uneventful")
	assert_signal_not_emitted(EventBus, "feed_intervention_available")

func test_no_trigger_when_tokens_zero() -> void:
	GuildManager.set_max_intervention_tokens(0)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_minor")
	assert_signal_not_emitted(EventBus, "feed_intervention_available")

# ── No double-trigger ─────────────────────────────────────────────────────────

func test_second_trigger_key_does_not_emit_again_for_same_mission() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_minor")
	_push_trigger("m1", "encounter_obstacle")
	# Signal should have fired exactly once for m1.
	assert_signal_emit_count(EventBus, "feed_intervention_available", 1)

func test_intervention_used_clears_pending_and_allows_next_trigger() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	# First trigger.
	_push_trigger("m1", "hero_wounded_minor")
	assert_signal_emit_count(EventBus, "feed_intervention_available", 1)
	# Simulate the player using the intervention — clears the pending flag.
	EventBus.intervention_used.emit("m1", Enums.CommitmentLevel.COME_HOME_SAFE)
	# Spend a token manually to match real flow.
	GuildManager.spend_intervention_token()
	# Second trigger on same mission should now fire again.
	_push_trigger("m1", "encounter_obstacle")
	assert_signal_emit_count(EventBus, "feed_intervention_available", 2)

func test_pending_flag_cleared_by_clear_feed() -> void:
	GuildManager.set_max_intervention_tokens(2)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_minor")
	FeedManager.clear_feed("m1")
	# After clear, re-triggering should work (pending flag gone).
	_push_trigger("m1", "hero_wounded_serious")
	assert_signal_emit_count(EventBus, "feed_intervention_available", 2)

# ── Independent feeds ─────────────────────────────────────────────────────────

func test_trigger_on_mission_a_does_not_affect_mission_b() -> void:
	GuildManager.set_max_intervention_tokens(3)
	GuildManager.reset_intervention_tokens()
	_push_trigger("m1", "hero_wounded_minor")
	# m2 should still be able to trigger independently.
	_push_trigger("m2", "hero_wounded_minor")
	assert_signal_emit_count(EventBus, "feed_intervention_available", 2)

func test_six_independent_feeds_all_accumulate_events() -> void:
	# Simulate 6 concurrent missions, each receiving 3 events.
	for i: int in range(1, 7):
		var mid := "m%d" % i
		_push_trigger(mid, "travel_uneventful")
		_push_trigger(mid, "arrival")
		_push_trigger(mid, "encounter_skirmish")

	for i: int in range(1, 7):
		var mid := "m%d" % i
		var feed: Array = FeedManager.get_feed(mid)
		assert_eq(feed.size(), 3, "%s has 3 events" % mid)

func test_six_independent_feeds_trigger_independently() -> void:
	GuildManager.set_max_intervention_tokens(6)
	GuildManager.reset_intervention_tokens()
	for i: int in range(1, 7):
		_push_trigger("m%d" % i, "hero_wounded_minor")
	assert_signal_emit_count(EventBus, "feed_intervention_available", 6)

func test_get_all_events_returns_events_across_all_missions() -> void:
	for i: int in range(1, 4):
		var mid := "m%d" % i
		_push_trigger(mid, "arrival")
		_push_trigger(mid, "encounter_skirmish")
	var all_events: Array = FeedManager.get_all_events()
	assert_eq(all_events.size(), 6, "6 total events across 3 missions")

# ── get_mission_title ─────────────────────────────────────────────────────────

func test_get_mission_title_returns_contract_title() -> void:
	var hero := _make_hero("h1")
	HeroManager._inject_hero_for_test(hero)
	var contract := _make_contract("c1")
	var mid := MissionManager.dispatch_heroes(
		contract, ["h1"], Enums.CommitmentLevel.USE_JUDGEMENT
	)
	assert_eq(MissionManager.get_mission_title(mid), "Mission c1", "Title matches contract")

func test_get_mission_title_fallback_for_unknown_id() -> void:
	var result: String = MissionManager.get_mission_title("nonexistent")
	assert_eq(result, "nonexistent", "Falls back to mission_id when not found")
