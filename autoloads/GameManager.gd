extends Node
## Owns the top-level game state machine.
## Call transition_to() to move between states; invalid transitions are rejected.

# ── Valid transition table ────────────────────────────────────────────────────
# Populated in _ready() because GDScript const blocks can't reference external
# enum values (Enums.GameState.*) at parse time.
var _transitions: Dictionary = {}

func _ready() -> void:
	_transitions = {
		Enums.GameState.MAIN_MENU:        [Enums.GameState.GUILD_HUB, Enums.GameState.CUTSCENE],
		Enums.GameState.GUILD_HUB:        [Enums.GameState.MORNING_PHASE, Enums.GameState.MISSION_BRIEFING,
										   Enums.GameState.PAUSED, Enums.GameState.MAIN_MENU,
										   Enums.GameState.CUTSCENE],
		Enums.GameState.MORNING_PHASE:    [Enums.GameState.GUILD_HUB, Enums.GameState.CUTSCENE],
		Enums.GameState.NIGHT_PHASE:      [Enums.GameState.GUILD_HUB, Enums.GameState.SIEGE,
										   Enums.GameState.CUTSCENE],
		Enums.GameState.MISSION_BRIEFING: [Enums.GameState.GUILD_HUB, Enums.GameState.MISSION_AUTO],
		Enums.GameState.MISSION_AUTO:     [Enums.GameState.GUILD_HUB, Enums.GameState.PAUSED,
										   Enums.GameState.CUTSCENE],
		Enums.GameState.SIEGE:            [Enums.GameState.GUILD_HUB, Enums.GameState.CUTSCENE],
		Enums.GameState.MISSION_DIRECT:   [Enums.GameState.GUILD_HUB],  # Reserved; post-launch
		Enums.GameState.CUTSCENE:         [Enums.GameState.GUILD_HUB, Enums.GameState.MAIN_MENU],
		Enums.GameState.PAUSED:           [Enums.GameState.GUILD_HUB, Enums.GameState.MISSION_AUTO,
										   Enums.GameState.MISSION_BRIEFING],
	}

# ── State ─────────────────────────────────────────────────────────────────────

var current_state: Enums.GameState = Enums.GameState.MAIN_MENU

# ── Public API ────────────────────────────────────────────────────────────────

## Attempts to move to new_state. Returns true on success, false if the
## transition is invalid. Emits EventBus.state_changed on success.
func transition_to(new_state: Enums.GameState) -> bool:
	if new_state == current_state:
		return true  # Already there; no-op
	var allowed: Array = _transitions.get(current_state, [])
	if new_state not in allowed:
		push_warning(
			"GameManager: invalid transition %s → %s" % [
				Enums.GameState.keys()[current_state],
				Enums.GameState.keys()[new_state]
			]
		)
		return false
	var prev := current_state
	_on_exit_state(prev)
	current_state = new_state
	_on_enter_state(new_state)
	EventBus.state_changed.emit(prev, new_state)
	return true

## Returns true if transitioning to new_state from the current state is allowed.
func can_transition_to(new_state: Enums.GameState) -> bool:
	if new_state == current_state:
		return true
	return new_state in _transitions.get(current_state, [])

## Bootstrap a new game: reset all systems, load starting heroes, switch to hub.
## M13 will replace the _reset_for_test helpers with proper save-compatible init.
func start_new_game() -> void:
	TimeManager._reset_for_test()
	GuildManager._reset_for_test()
	MissionManager._reset_for_test()
	ContractQueue._reset_for_test()
	FeedManager._reset_for_test()
	HeroManager._clear_roster_for_test()
	for hero: HeroData in DataLoader.load_starting_heroes():
		HeroManager._inject_hero_for_test(hero)
	# Bypass the normal transition table — game is bootstrapping from scratch.
	current_state = Enums.GameState.GUILD_HUB
	EventBus.state_changed.emit(Enums.GameState.MAIN_MENU, Enums.GameState.GUILD_HUB)
	get_tree().change_scene_to_file("res://scenes/hub/GuildHubScene.tscn")

## Resets the FSM to MAIN_MENU. For use in GUT tests only.
func _reset_for_test() -> void:
	current_state = Enums.GameState.MAIN_MENU

# ── Entry / exit hooks ────────────────────────────────────────────────────────

func _on_exit_state(_state: Enums.GameState) -> void:
	pass

func _on_enter_state(state: Enums.GameState) -> void:
	match state:
		Enums.GameState.MORNING_PHASE:
			TimeManager.advance_day()
			# Morning processing is synchronous; return to hub on the next frame
			# so all day_advanced listeners finish before the state changes again.
			call_deferred("transition_to", Enums.GameState.GUILD_HUB)
		Enums.GameState.NIGHT_PHASE:
			TimeManager.trigger_night_phase()
