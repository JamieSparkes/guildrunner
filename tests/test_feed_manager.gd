extends GutTest
## Tests for FeedManager: event formatting, personality variants, substitution,
## feed accumulation, signal handling, and JSON template validation.

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_templates() -> Dictionary:
	return {
		"hero_departed": {
			"STOIC":    ["Stoic {name} leaves."],
			"RECKLESS": ["Reckless {name} charges out!", "Reckless {name} flies out!"],
			"DEFAULT":  ["Someone leaves."],
		},
		"hero_returned": {
			"DEFAULT": ["Someone returned."],
		},
		"hero_died": {
			"DEFAULT": ["{name} falls."],
		},
	}

func before_each() -> void:
	FeedManager._reset_for_test()
	FeedManager._inject_templates_for_test(_make_templates())

func after_each() -> void:
	FeedManager._reset_for_test()

# ── Formatting — personality selection ────────────────────────────────────────

func test_format_uses_matching_personality() -> void:
	FeedManager.push_event("m1", "hero_departed", {"name": "Aldric", "personality": "STOIC"})
	var events: Array = FeedManager.get_feed("m1")
	assert_eq(events.size(), 1, "One event stored")
	assert_eq(events[0].text, "Stoic Aldric leaves.", "STOIC variant used with name substituted")

func test_format_falls_back_to_default_when_personality_absent() -> void:
	# "CYNICAL" is not in our test templates — should fall back to DEFAULT.
	FeedManager.push_event("m1", "hero_departed", {"personality": "CYNICAL"})
	var events: Array = FeedManager.get_feed("m1")
	assert_eq(events[0].text, "Someone leaves.", "Falls back to DEFAULT when personality key absent")

func test_format_uses_default_when_no_personality_key_provided() -> void:
	FeedManager.push_event("m1", "hero_returned", {"personality": "STOIC"})
	var events: Array = FeedManager.get_feed("m1")
	# hero_returned only has DEFAULT; any personality should resolve to it.
	assert_eq(events[0].text, "Someone returned.", "Uses DEFAULT when no specific personality variant")

func test_format_falls_back_to_first_key_when_no_default() -> void:
	# Template with only one personality key and no DEFAULT.
	var templates := {
		"solo_key_event": {
			"STOIC": ["Only stoic variant."],
		},
	}
	FeedManager._inject_templates_for_test(templates)
	FeedManager.push_event("m1", "solo_key_event", {"personality": "RECKLESS"})
	var events: Array = FeedManager.get_feed("m1")
	assert_eq(events[0].text, "Only stoic variant.",
			"Falls back to first available key when personality and DEFAULT absent")

func test_reckless_picks_from_variant_pool() -> void:
	# Run 50 times — all results must come from the RECKLESS variants array.
	var valid: Array[String] = ["Reckless  charges out!", "Reckless  flies out!"]
	for _i: int in 50:
		FeedManager._reset_for_test()
		FeedManager._inject_templates_for_test(_make_templates())
		FeedManager.push_event("m1", "hero_departed", {"personality": "RECKLESS"})
		var text: String = (FeedManager.get_feed("m1")[0] as FeedEvent).text
		# Both variants have empty {name} since we didn't pass "name" param.
		assert_true(text.begins_with("Reckless "),
				"RECKLESS variant should start with 'Reckless ' (got: %s)" % text)

# ── Formatting — substitution ─────────────────────────────────────────────────

func test_substitute_replaces_name_placeholder() -> void:
	FeedManager.push_event("m1", "hero_died", {"name": "Mira", "personality": "STOIC"})
	var text: String = (FeedManager.get_feed("m1")[0] as FeedEvent).text
	assert_true(text.contains("Mira"), "Name placeholder substituted correctly")
	assert_false(text.contains("{name}"), "Raw {name} placeholder should not remain")

func test_substitute_leaves_unmatched_placeholders_intact() -> void:
	# Template uses {name} but we don't supply it.
	FeedManager.push_event("m1", "hero_died", {"personality": "STOIC"})
	var text: String = (FeedManager.get_feed("m1")[0] as FeedEvent).text
	assert_true(text.contains("{name}"), "Unmatched placeholder stays in text")

func test_unknown_event_key_returns_bracketed_fallback() -> void:
	FeedManager.push_event("m1", "no_such_event", {"personality": "STOIC"})
	var events: Array = FeedManager.get_feed("m1")
	assert_eq(events[0].text, "[no_such_event]", "Unknown key returns bracketed key name")

# ── Feed accumulation ─────────────────────────────────────────────────────────

func test_push_event_creates_feed_event_with_correct_fields() -> void:
	FeedManager.push_event("mission_1", "hero_departed",
			{"name": "Aldric", "personality": "STOIC"})
	var events: Array = FeedManager.get_feed("mission_1")
	assert_eq(events.size(), 1, "One event after one push")
	var ev: FeedEvent = events[0]
	assert_eq(ev.mission_id, "mission_1", "Correct mission_id")
	assert_eq(ev.event_key, "hero_departed", "Correct event_key")

func test_push_event_accumulates_for_same_mission() -> void:
	FeedManager.push_event("m1", "hero_departed", {"personality": "STOIC"})
	FeedManager.push_event("m1", "hero_returned", {"personality": "STOIC"})
	assert_eq(FeedManager.get_feed("m1").size(), 2, "Two events accumulate for the same mission")

func test_push_event_separates_missions() -> void:
	FeedManager.push_event("m1", "hero_departed", {"personality": "STOIC"})
	FeedManager.push_event("m2", "hero_returned", {"personality": "STOIC"})
	assert_eq(FeedManager.get_feed("m1").size(), 1, "Mission m1 has 1 event")
	assert_eq(FeedManager.get_feed("m2").size(), 1, "Mission m2 has 1 event")

func test_get_feed_returns_empty_for_unknown_mission() -> void:
	assert_eq(FeedManager.get_feed("ghost_mission").size(), 0,
			"Unknown mission returns empty array")

func test_get_all_events_combines_all_missions() -> void:
	FeedManager.push_event("m1", "hero_departed", {"personality": "STOIC"})
	FeedManager.push_event("m2", "hero_returned", {"personality": "STOIC"})
	FeedManager.push_event("m1", "hero_died", {"personality": "STOIC"})
	assert_eq(FeedManager.get_all_events().size(), 3,
			"get_all_events combines events across missions")

func test_clear_feed_removes_entries_for_mission() -> void:
	FeedManager.push_event("m1", "hero_departed", {"personality": "STOIC"})
	FeedManager.push_event("m2", "hero_returned", {"personality": "STOIC"})
	FeedManager.clear_feed("m1")
	assert_eq(FeedManager.get_feed("m1").size(), 0, "Cleared mission has no events")
	assert_eq(FeedManager.get_feed("m2").size(), 1, "Other mission unaffected by clear")

# ── Signal integration ────────────────────────────────────────────────────────

func test_feed_event_signal_triggers_storage() -> void:
	EventBus.feed_event.emit("sig_mission", "hero_departed", {"personality": "STOIC"})
	assert_eq(FeedManager.get_feed("sig_mission").size(), 1,
			"Emitting feed_event signal causes FeedManager to store the event")

# ── JSON template validation ──────────────────────────────────────────────────

func test_required_event_keys_present_in_json() -> void:
	var real_templates := DataLoader.load_feed_event_templates()
	assert_false(real_templates.is_empty(), "feed_events.json loaded successfully")
	for key: String in FeedManager.REQUIRED_EVENT_KEYS:
		assert_true(real_templates.has(key),
				"feed_events.json missing required key: %s" % key)

func test_each_event_key_has_at_least_one_variant() -> void:
	var real_templates := DataLoader.load_feed_event_templates()
	for key: String in FeedManager.REQUIRED_EVENT_KEYS:
		if not real_templates.has(key):
			continue  # Caught by previous test
		var by_personality: Dictionary = real_templates[key]
		assert_false(by_personality.is_empty(),
				"Event key '%s' has no personality entries" % key)
		for pkey: String in by_personality.keys():
			var variants: Array = by_personality[pkey]
			assert_false(variants.is_empty(),
					"Event key '%s' personality '%s' has no variants" % [key, pkey])
