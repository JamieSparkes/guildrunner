extends Node
## Manages the hero roster: lookup, status changes, injury, death, capture.
## Owns all HeroData instances at runtime.

# Recovery days by injury severity (mirrors InjuryResolver.RECOVERY_DAYS)
const RECOVERY_DAYS: Dictionary = {
	Enums.InjurySeverity.MINOR:    2,
	Enums.InjurySeverity.SERIOUS:  4,
	Enums.InjurySeverity.CRITICAL: 7,
}

# ── State ─────────────────────────────────────────────────────────────────────

var _heroes: Dictionary = {}  # { hero_id: HeroData }

func _ready() -> void:
	# Starting heroes loaded in M8 new-game flow; _heroes populated from JSON.
	EventBus.day_advanced.connect(_on_day_advanced)

# ── Lookup ────────────────────────────────────────────────────────────────────

func get_hero(hero_id: String) -> HeroData:
	return _heroes.get(hero_id, null)

func get_all_heroes() -> Array:
	return _heroes.values()

func get_available_heroes() -> Array:
	return _heroes.values().filter(
		func(h: HeroData) -> bool: return h.status == Enums.HeroStatus.AVAILABLE
	)

# ── Status mutations ──────────────────────────────────────────────────────────

func set_status(hero_id: String, new_status: Enums.HeroStatus) -> void:
	var hero := get_hero(hero_id)
	if hero == null:
		push_error("HeroManager: unknown hero '%s'" % hero_id)
		return
	hero.status = new_status

func set_current_mission(hero_id: String, mission_id: String) -> void:
	var hero := get_hero(hero_id)
	if hero == null:
		return
	hero.current_mission_id = mission_id

# ── Injury / death / capture ──────────────────────────────────────────────────

## Apply an injury to a hero: sets status, recovery days, and emits signals.
func apply_injury(hero_id: String, severity: Enums.InjurySeverity) -> void:
	var hero := get_hero(hero_id)
	if hero == null:
		return
	hero.times_wounded += 1
	var reduction: int = GuildManager.get_state().recovery_day_reduction
	hero.injury_recovery_days = max(1, RECOVERY_DAYS[severity] - reduction)
	hero.current_mission_id = ""

	if severity == Enums.InjurySeverity.MINOR:
		hero.status = Enums.HeroStatus.INJURED
	else:
		hero.status = Enums.HeroStatus.RECOVERING

	EventBus.hero_wounded.emit(hero_id, severity)

## Permanently kill a hero.
func kill_hero(hero_id: String, mission_id: String) -> void:
	var hero := get_hero(hero_id)
	if hero == null:
		return
	hero.status = Enums.HeroStatus.DEAD
	hero.current_mission_id = ""
	EventBus.hero_killed.emit(hero_id, mission_id)

## Mark a hero as captured (rescue contract generated in M12).
func capture_hero(hero_id: String, mission_id: String) -> void:
	var hero := get_hero(hero_id)
	if hero == null:
		return
	hero.status = Enums.HeroStatus.CAPTURED
	hero.current_mission_id = ""
	EventBus.hero_captured.emit(hero_id, mission_id)

# ── Daily tick — injury recovery ──────────────────────────────────────────────

func _on_day_advanced(_day: int) -> void:
	for hero: HeroData in _heroes.values():
		if hero.status != Enums.HeroStatus.INJURED \
				and hero.status != Enums.HeroStatus.RECOVERING:
			continue
		hero.injury_recovery_days -= 1
		if hero.injury_recovery_days <= 0:
			hero.injury_recovery_days = 0
			hero.status = Enums.HeroStatus.AVAILABLE

# ── Test helpers ──────────────────────────────────────────────────────────────

func _inject_hero_for_test(hero: HeroData) -> void:
	_heroes[hero.hero_id] = hero

func _clear_roster_for_test() -> void:
	_heroes.clear()
