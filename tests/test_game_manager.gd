## M2 GUT tests — EventBus signals + GameManager FSM
extends GutTest

# ── Setup ─────────────────────────────────────────────────────────────────────
# GameManager is an autoload singleton — use it directly and reset between tests.

func before_each() -> void:
	GameManager._reset_for_test()

func after_each() -> void:
	GameManager._reset_for_test()

# ── EventBus: signal existence ────────────────────────────────────────────────

func test_event_bus_has_time_signals() -> void:
	assert_true(EventBus.has_signal("day_advanced"),   "day_advanced signal missing")
	assert_true(EventBus.has_signal("night_began"),    "night_began signal missing")
	assert_true(EventBus.has_signal("week_advanced"),  "week_advanced signal missing")

func test_event_bus_has_hero_signals() -> void:
	assert_true(EventBus.has_signal("hero_dispatched"),      "hero_dispatched missing")
	assert_true(EventBus.has_signal("hero_returned"),        "hero_returned missing")
	assert_true(EventBus.has_signal("hero_wounded"),         "hero_wounded missing")
	assert_true(EventBus.has_signal("hero_killed"),          "hero_killed missing")
	assert_true(EventBus.has_signal("hero_captured"),        "hero_captured missing")
	assert_true(EventBus.has_signal("hero_trait_acquired"),  "hero_trait_acquired missing")
	assert_true(EventBus.has_signal("hero_morale_changed"),  "hero_morale_changed missing")

func test_event_bus_has_contract_signals() -> void:
	assert_true(EventBus.has_signal("contract_available"),  "contract_available missing")
	assert_true(EventBus.has_signal("contract_accepted"),   "contract_accepted missing")
	assert_true(EventBus.has_signal("contract_completed"),  "contract_completed missing")
	assert_true(EventBus.has_signal("contract_expired"),    "contract_expired missing")
	assert_true(EventBus.has_signal("messenger_arrived"),   "messenger_arrived missing")

func test_event_bus_has_feed_signals() -> void:
	assert_true(EventBus.has_signal("feed_event"),                    "feed_event missing")
	assert_true(EventBus.has_signal("intervention_data_ready"),   "intervention_data_ready missing")
	assert_true(EventBus.has_signal("intervention_used"),             "intervention_used missing")

func test_event_bus_has_faction_signals() -> void:
	assert_true(EventBus.has_signal("reputation_changed"),   "reputation_changed missing")
	assert_true(EventBus.has_signal("faction_became_enemy"), "faction_became_enemy missing")
	assert_true(EventBus.has_signal("faction_became_ally"),  "faction_became_ally missing")

func test_event_bus_has_guild_signals() -> void:
	assert_true(EventBus.has_signal("upgrade_built"),   "upgrade_built missing")
	assert_true(EventBus.has_signal("guild_attacked"),  "guild_attacked missing")
	assert_true(EventBus.has_signal("gold_changed"),    "gold_changed missing")

func test_event_bus_has_state_changed_signal() -> void:
	assert_true(EventBus.has_signal("state_changed"), "state_changed signal missing")

# ── GameManager: initial state ────────────────────────────────────────────────

func test_game_manager_starts_in_main_menu() -> void:
	assert_eq(GameManager.current_state, Enums.GameState.MAIN_MENU, "Should start in MAIN_MENU")

# ── GameManager: valid transitions ───────────────────────────────────────────

func test_transition_main_menu_to_guild_hub() -> void:
	var ok := GameManager.transition_to(Enums.GameState.GUILD_HUB)
	assert_true(ok, "MAIN_MENU → GUILD_HUB should succeed")
	assert_eq(GameManager.current_state, Enums.GameState.GUILD_HUB)

func test_transition_guild_hub_to_morning_phase() -> void:
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	var ok := GameManager.transition_to(Enums.GameState.MORNING_PHASE)
	assert_true(ok, "GUILD_HUB → MORNING_PHASE should succeed")

func test_transition_guild_hub_to_mission_briefing() -> void:
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	var ok := GameManager.transition_to(Enums.GameState.MISSION_BRIEFING)
	assert_true(ok, "GUILD_HUB → MISSION_BRIEFING should succeed")

func test_transition_mission_briefing_to_mission_auto() -> void:
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	GameManager.transition_to(Enums.GameState.MISSION_BRIEFING)
	var ok := GameManager.transition_to(Enums.GameState.MISSION_AUTO)
	assert_true(ok, "MISSION_BRIEFING → MISSION_AUTO should succeed")

func test_transition_to_same_state_is_noop() -> void:
	var ok := GameManager.transition_to(Enums.GameState.MAIN_MENU)
	assert_true(ok, "Transitioning to current state should return true (no-op)")
	assert_eq(GameManager.current_state, Enums.GameState.MAIN_MENU)

# ── GameManager: invalid transitions ─────────────────────────────────────────

func test_invalid_transition_main_menu_to_mission_auto() -> void:
	var ok := GameManager.transition_to(Enums.GameState.MISSION_AUTO)
	assert_false(ok, "MAIN_MENU → MISSION_AUTO should be rejected")
	assert_eq(GameManager.current_state, Enums.GameState.MAIN_MENU, "State unchanged after rejection")

func test_invalid_transition_main_menu_to_siege() -> void:
	var ok := GameManager.transition_to(Enums.GameState.SIEGE)
	assert_false(ok, "MAIN_MENU → SIEGE should be rejected")

func test_invalid_transition_morning_phase_to_mission_briefing() -> void:
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	GameManager.transition_to(Enums.GameState.MORNING_PHASE)
	var ok := GameManager.transition_to(Enums.GameState.MISSION_BRIEFING)
	assert_false(ok, "MORNING_PHASE → MISSION_BRIEFING should be rejected")

# ── GameManager: can_transition_to ───────────────────────────────────────────

func test_can_transition_to_valid() -> void:
	assert_true(GameManager.can_transition_to(Enums.GameState.GUILD_HUB))

func test_can_transition_to_invalid() -> void:
	assert_false(GameManager.can_transition_to(Enums.GameState.MISSION_AUTO))

# ── GameManager: state_changed signal emission ───────────────────────────────

func test_state_changed_signal_emitted_on_valid_transition() -> void:
	watch_signals(EventBus)
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	assert_signal_emitted(EventBus, "state_changed")

func test_state_changed_signal_not_emitted_on_invalid_transition() -> void:
	watch_signals(EventBus)
	GameManager.transition_to(Enums.GameState.SIEGE)  # Invalid from MAIN_MENU
	assert_signal_not_emitted(EventBus, "state_changed")

func test_state_changed_carries_correct_from_and_to() -> void:
	watch_signals(EventBus)
	GameManager.transition_to(Enums.GameState.GUILD_HUB)
	assert_signal_emitted_with_parameters(
		EventBus, "state_changed",
		[Enums.GameState.MAIN_MENU, Enums.GameState.GUILD_HUB]
	)
