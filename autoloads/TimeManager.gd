extends Node
## Owns the day/night cycle: current day, phase, week tracking.
## Fires day_advanced and night_began signals via EventBus.

# ── State ─────────────────────────────────────────────────────────────────────

var current_day: int = 1
var phase: Enums.DayPhase = Enums.DayPhase.MORNING

var week_number: int:
	get:
		return int(ceil(current_day / 7.0))

# ── Public API ────────────────────────────────────────────────────────────────

## Advance to the next day. Resolves pending night events, increments the day
## counter, runs morning delivery, and checks weekly upkeep.
func advance_day() -> void:
	_resolve_night_events()
	current_day += 1
	phase = Enums.DayPhase.MORNING
	EventBus.day_advanced.emit(current_day)
	_deliver_morning_contracts()
	_check_weekly_upkeep()

## Transition to the night phase for the current day.
func trigger_night_phase() -> void:
	phase = Enums.DayPhase.NIGHT
	EventBus.night_began.emit(current_day)

## Reset to day 1 / morning. For use in GUT tests and new-game setup.
func _reset_for_test() -> void:
	current_day = 1
	phase = Enums.DayPhase.MORNING

# ── Internal ──────────────────────────────────────────────────────────────────

func _resolve_night_events() -> void:
	pass  # Wired by NightEventManager in M16

func _deliver_morning_contracts() -> void:
	ContractQueue.on_morning_phase(current_day)  # Wired in M5

func _check_weekly_upkeep() -> void:
	if current_day % 7 == 0:
		EventBus.week_advanced.emit(week_number)
		GuildManager.apply_weekly_upkeep()
