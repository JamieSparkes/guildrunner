extends GutTest
## Tests for M9: Multi-Column Feed + Interventions.
## Covers: token deduction/reset, commitment update, can_trigger_intervention flag,
## stream resume on intervention_used/dismissed, 6 independent feeds.

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
func _push_trigger(mission_id: String, event_key: String) -> FeedEvent:
	FeedManager.push_event(mission_id, event_key, {
		"personality": "STOIC",
		"name": "Test Hero",
		"target": "Somewhere",
	})
	var feed: Array = FeedManager.get_feed(mission_id)
	return feed[feed.size() - 1]

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

# ── can_trigger_intervention flag ─────────────────────────────────────────────

func test_trigger_key_sets_can_trigger_intervention_flag() -> void:
	var event := _push_trigger("m1", "hero_wounded_minor")
	assert_true(event.can_trigger_intervention,
		"hero_wounded_minor should set can_trigger_intervention")

func test_encounter_obstacle_sets_flag() -> void:
	var event := _push_trigger("m1", "encounter_obstacle")
	assert_true(event.can_trigger_intervention,
		"encounter_obstacle should set can_trigger_intervention")

func test_hero_wounded_serious_sets_flag() -> void:
	var event := _push_trigger("m1", "hero_wounded_serious")
	assert_true(event.can_trigger_intervention,
		"hero_wounded_serious should set can_trigger_intervention")

func test_non_trigger_key_does_not_set_flag() -> void:
	var event := _push_trigger("m1", "travel_uneventful")
	assert_false(event.can_trigger_intervention,
		"travel_uneventful should not set can_trigger_intervention")

func test_arrival_does_not_set_flag() -> void:
	var event := _push_trigger("m1", "arrival")
	assert_false(event.can_trigger_intervention,
		"arrival should not set can_trigger_intervention")

# ── Stream resume on intervention resolved ────────────────────────────────────

func test_intervention_used_emits_feed_stream_resume() -> void:
	EventBus.intervention_used.emit("m1", Enums.CommitmentLevel.COME_HOME_SAFE)
	assert_signal_emitted(EventBus, "feed_stream_resume",
		"feed_stream_resume should fire after intervention_used")

func test_intervention_dismissed_emits_feed_stream_resume() -> void:
	EventBus.intervention_dismissed.emit("m1")
	assert_signal_emitted(EventBus, "feed_stream_resume",
		"feed_stream_resume should fire after intervention_dismissed")

func test_intervention_used_clears_stream_paused_state() -> void:
	FeedManager.begin_stream()
	FeedManager.set_stream_paused(true)
	EventBus.intervention_used.emit("m1", Enums.CommitmentLevel.COME_HOME_SAFE)
	assert_false(FeedManager.is_stream_paused(), "Stream should not be paused after intervention_used")

func test_intervention_dismissed_clears_stream_paused_state() -> void:
	FeedManager.begin_stream()
	FeedManager.set_stream_paused(true)
	EventBus.intervention_dismissed.emit("m1")
	assert_false(FeedManager.is_stream_paused(), "Stream should not be paused after dismissal")

# ── Stream queue ──────────────────────────────────────────────────────────────

func test_begin_stream_enables_queue() -> void:
	FeedManager.begin_stream()
	_push_trigger("m1", "travel_uneventful")
	assert_true(FeedManager.has_stream_events(), "Stream queue should have events after begin_stream")

func test_events_not_queued_before_begin_stream() -> void:
	# _streaming_active is false by default after reset.
	_push_trigger("m1", "travel_uneventful")
	assert_false(FeedManager.has_stream_events(), "Events should not queue before begin_stream")

func test_pop_stream_event_returns_in_order() -> void:
	FeedManager.begin_stream()
	_push_trigger("m1", "travel_uneventful")
	_push_trigger("m1", "arrival")
	var first: FeedEvent = FeedManager.pop_stream_event()
	assert_eq(first.event_key, "travel_uneventful", "First event should be travel_uneventful")
	var second: FeedEvent = FeedManager.pop_stream_event()
	assert_eq(second.event_key, "arrival", "Second event should be arrival")
	assert_false(FeedManager.has_stream_events(), "Queue empty after both events popped")

func test_feed_stream_event_queued_signal_emitted() -> void:
	FeedManager.begin_stream()
	_push_trigger("m1", "travel_uneventful")
	assert_signal_emitted(EventBus, "feed_stream_event_queued",
		"feed_stream_event_queued should fire when event pushed during stream")

# ── Independent feeds ─────────────────────────────────────────────────────────

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
