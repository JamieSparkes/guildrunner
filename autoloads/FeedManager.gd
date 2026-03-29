extends Node
## Manages the auto-resolve feed for all active missions.
## Per TDD §4.2.1: active_feeds, push_event, _format_event with personality variant selection.
## Per TDD §4.2.2: intervention trigger detection on wound and decision-point events.
## M9b: single-column feed with color-coded missions and batched day display.

## All event keys that must be present in feed_events.json.
const REQUIRED_EVENT_KEYS: Array[String] = [
	"hero_departed",
	"travel_uneventful",
	"arrival",
	"encounter_skirmish",
	"encounter_ambush",
	"encounter_obstacle",
	"encounter_discovery",
	"outcome_success",
	"outcome_failure",
	"outcome_partial",
	"outcome_full_success",
	"hero_wounded_minor",
	"hero_wounded_serious",
	"hero_died",
	"hero_captured",
	"hero_returned",
	"stage_advance_fail",
	"stage_combat_victory",
	"stage_combat_struggle",
	"stage_timed_out",
]

## Event keys that can trigger an intervention prompt (if tokens are available).
const INTERVENTION_TRIGGER_KEYS: Array[String] = [
	"hero_wounded_minor",
	"hero_wounded_serious",
	"encounter_obstacle",
]

## Shared palette for both mission and hero colors — avoids red, green, and near-black (reserved).
const MISSION_COLOR_PALETTE: Array[Color] = [
	Color(0.40, 0.60, 1.00),   # Blue
	Color(1.00, 0.60, 0.20),   # Orange
	Color(0.70, 0.40, 0.90),   # Purple
	Color(0.20, 0.80, 0.80),   # Teal
	Color(0.95, 0.85, 0.20),   # Yellow
	Color(1.00, 0.50, 0.70),   # Pink
	Color(0.40, 0.85, 0.95),   # Cyan
	Color(0.75, 0.55, 0.35),   # Brown
]

## Per-hero event keys: colored by the individual hero, not the mission.
## Reserved colors still override these if the key is in RESERVED_EVENT_COLORS.
const PER_HERO_EVENT_KEYS: Array[String] = [
	"hero_departed",
	"hero_returned",
]

## Event keys that override mission color with a reserved color.
const RESERVED_EVENT_COLORS: Dictionary = {
	"hero_wounded_minor":  Color(0.90, 0.20, 0.20),   # Red
	"hero_wounded_serious": Color(0.90, 0.20, 0.20),   # Red
	"hero_died":           Color(0.15, 0.15, 0.15),    # Black (near-black for visibility)
	"hero_captured":       Color(0.15, 0.15, 0.15),    # Black
	"outcome_full_success": Color(0.20, 0.80, 0.20),   # Green
	"outcome_success":     Color(0.20, 0.80, 0.20),    # Green
}

## When true, every push_event() call prints a rich debug block to the Godot console.
## Toggle with F10 at runtime.
var debug_feed: bool = false

## Active feed entries per mission. { mission_id: Array } — each array holds FeedEvent.
var active_feeds: Dictionary = {}
var _templates: Dictionary = {}  # { event_key: { personality_key: [String] } }
## Tracks missions with a pending intervention so we don't double-fire.
var _pending_interventions: Dictionary = {}  # { mission_id: bool }

# ── Color assignment ──────────────────────────────────────────────────────────

var _mission_colors: Dictionary = {}   # { mission_id: Color }
var _hero_colors: Dictionary = {}      # { hero_id: Color }
var _color_index: int = 0              # Cycles through palette (shared by mission + hero)

# ── Day buffer (batched display) ──────────────────────────────────────────────

var _day_buffer: Array = []   # FeedEvents generated during the current day advance

# ── Stream queue (live feed) ──────────────────────────────────────────────────

var _stream_queue: Array = []     # FeedEvents waiting to be revealed by FeedScreen
var _streaming_active: bool = false
var _stream_paused: bool = false

func _ready() -> void:
	_templates = DataLoader.load_feed_event_templates()
	EventBus.feed_event.connect(_on_feed_event)
	EventBus.intervention_used.connect(_on_intervention_used)
	EventBus.intervention_dismissed.connect(_on_intervention_dismissed)

# ── Public API ────────────────────────────────────────────────────────────────

## Create and store a FeedEvent for the given mission.
## params keys:
##   "personality" — String matching Enums.PersonalityType name (e.g. "STOIC").
##   Any {placeholder} tokens used in the template variant (e.g. "name", "target").
func push_event(mission_id: String, event_key: String, params: Dictionary) -> void:
	if not active_feeds.has(mission_id):
		active_feeds[mission_id] = []
	var personality: String = params.get("personality", "STOIC")
	var text := _format_event(event_key, params, personality)
	var event_color := _resolve_event_color(mission_id, event_key, params)
	var event := FeedEvent.new(mission_id, text, event_key, false, TimeManager.current_day, event_color)
	# Flag events that can trigger interventions; checked by FeedScreen at reveal time.
	event.can_trigger_intervention = event_key in INTERVENTION_TRIGGER_KEYS
	(active_feeds[mission_id] as Array).append(event)
	_day_buffer.append(event)
	if _streaming_active:
		_stream_queue.append(event)
		EventBus.feed_stream_event_queued.emit()
	if debug_feed:
		_debug_print_event(mission_id, event_key, params, text, event_color)

## All events for a mission, oldest first. Returns [] if mission not known.
func get_feed(mission_id: String) -> Array:
	return active_feeds.get(mission_id, [])

## All events across every mission, in insertion order per mission.
func get_all_events() -> Array:
	var result: Array = []
	for arr in active_feeds.values():
		result.append_array(arr)
	return result

## Remove all feed entries for a mission (e.g. after it is archived).
func clear_feed(mission_id: String) -> void:
	active_feeds.erase(mission_id)
	_pending_interventions.erase(mission_id)
	_mission_colors.erase(mission_id)

# ── Color assignment API ─────────────────────────────────────────────────────

## Assign a palette color to a mission. Call once on dispatch.
func assign_mission_color(mission_id: String) -> Color:
	if _mission_colors.has(mission_id):
		return _mission_colors[mission_id]
	var c: Color = MISSION_COLOR_PALETTE[_color_index % MISSION_COLOR_PALETTE.size()]
	_color_index += 1
	_mission_colors[mission_id] = c
	return c

## Get the color assigned to a mission (white fallback).
func get_mission_color(mission_id: String) -> Color:
	return _mission_colors.get(mission_id, Color.WHITE)

## Get the persistent color for a hero, assigning one lazily if not yet seen.
func get_hero_color(hero_id: String) -> Color:
	if not _hero_colors.has(hero_id):
		_hero_colors[hero_id] = MISSION_COLOR_PALETTE[_color_index % MISSION_COLOR_PALETTE.size()]
		_color_index += 1
	return _hero_colors[hero_id]

# ── Stream queue API ─────────────────────────────────────────────────────────

## Open the stream queue for the upcoming day advance. Call before advance_day().
func begin_stream() -> void:
	_stream_queue.clear()
	_streaming_active = true
	_stream_paused = false

## Close the stream. Called when FeedScreen is done.
func end_stream() -> void:
	_streaming_active = false

func has_stream_events() -> bool:
	return not _stream_queue.is_empty()

func pop_stream_event() -> FeedEvent:
	if _stream_queue.is_empty():
		return null
	return _stream_queue.pop_front()

func is_stream_paused() -> bool:
	return _stream_paused

func set_stream_paused(paused: bool) -> void:
	_stream_paused = paused

# ── Day buffer API ───────────────────────────────────────────────────────────

## Events generated during the current day advance, in emit order.
func get_day_buffer() -> Array:
	return _day_buffer

## Clear the day buffer (call at the start of each day advance).
func clear_day_buffer() -> void:
	_day_buffer.clear()

## True if any events were generated during the current day advance.
func has_day_events() -> bool:
	return not _day_buffer.is_empty()

# ── Intervention logic ────────────────────────────────────────────────────────

func _on_intervention_used(mission_id: String, _commitment: int) -> void:
	_pending_interventions.erase(mission_id)
	set_stream_paused(false)
	EventBus.feed_stream_resume.emit()

func _on_intervention_dismissed(mission_id: String) -> void:
	_pending_interventions.erase(mission_id)
	set_stream_paused(false)
	EventBus.feed_stream_resume.emit()

# ── Color resolution ─────────────────────────────────────────────────────────

func _resolve_event_color(mission_id: String, event_key: String, params: Dictionary) -> Color:
	if RESERVED_EVENT_COLORS.has(event_key):
		return RESERVED_EVENT_COLORS[event_key]
	var hero_id: String = params.get("hero_id", "")
	if hero_id != "" and event_key in PER_HERO_EVENT_KEYS:
		return get_hero_color(hero_id)
	return get_mission_color(mission_id)

# ── Formatting ────────────────────────────────────────────────────────────────

func _format_event(event_key: String, params: Dictionary, personality: String) -> String:
	if not _templates.has(event_key):
		return "[%s]" % event_key
	var by_personality: Dictionary = _templates[event_key]
	var variants: Array
	if by_personality.has(personality):
		variants = by_personality[personality]
	elif by_personality.has("DEFAULT"):
		variants = by_personality["DEFAULT"]
	else:
		variants = by_personality.values()[0]
	var template: String = variants[randi() % variants.size()]
	return _substitute(template, params)

func _substitute(template: String, params: Dictionary) -> String:
	var result := template
	for key in params.keys():
		result = result.replace("{%s}" % key, str(params[key]))
	return result

# ── Signal handler ────────────────────────────────────────────────────────────

func _on_feed_event(mission_id: String, event_key: String, params: Dictionary) -> void:
	push_event(mission_id, event_key, params)

# ── Debug ─────────────────────────────────────────────────────────────────────

func _debug_print_event(
	mission_id: String,
	event_key: String,
	params: Dictionary,
	formatted_text: String,
	event_color: Color
) -> void:
	var lines: Array[String] = []
	lines.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	lines.append("[FEED] Day %d  |  %s  |  %s" % [TimeManager.current_day, mission_id, event_key])
	lines.append("  Text     : %s" % formatted_text)

	# Params
	if not params.is_empty():
		var param_parts: Array[String] = []
		for k: String in params.keys():
			param_parts.append("%s=%s" % [k, str(params[k])])
		lines.append("  Params   : { %s }" % ", ".join(param_parts))

	# Color + flags
	var color_hex := event_color.to_html(false)
	var can_intervene := event_key in INTERVENTION_TRIGGER_KEYS
	lines.append("  Color    : #%s  |  can_intervene=%s  |  streaming=%s" % [
		color_hex, str(can_intervene), str(_streaming_active)
	])

	# Mission progress from MissionManager
	var progress: Variant = MissionManager.get_mission_progress(mission_id)
	if progress != null:
		var stage_idx: int = progress["current_stage_index"]
		var total: int = progress["total_stages"]
		var stage_names: Array = progress["stage_names"]
		var cur_name: String = stage_names[stage_idx] if stage_idx < stage_names.size() else "—"
		lines.append("  Stage    : %d/%d  current=%s  completed=%s" % [
			stage_idx, total, cur_name, str(progress["completed"])
		])
		# Flags
		var flags: Dictionary = {}
		for mission in MissionManager.get_active_missions():
			if mission.mission_id == mission_id:
				flags = mission.flags
				break
		if not flags.is_empty():
			var flag_parts: Array[String] = []
			for fk: String in flags.keys():
				flag_parts.append("%s=%s" % [fk, str(flags[fk])])
			lines.append("  Flags    : { %s }" % ", ".join(flag_parts))
		else:
			lines.append("  Flags    : (none)")
		# Heroes
		var hero_ids: Array = progress["hero_ids"]
		for hid: String in hero_ids:
			var hero: HeroData = HeroManager.get_hero(hid)
			if hero == null:
				lines.append("  Hero     : %s (not found)" % hid)
				continue
			var status_name: String = Enums.HeroStatus.keys()[hero.status]
			var injury_str := ""
			if hero.status in [Enums.HeroStatus.INJURED, Enums.HeroStatus.RECOVERING]:
				injury_str = "  recovery_days=%d" % hero.injury_recovery_days
			lines.append("  Hero     : %s [%s]  str=%.0f  agi=%.0f  ste=%.0f  res=%.0f  lea=%.0f  morale=%.0f%s" % [
				hero.display_name, status_name,
				hero.strength, hero.agility, hero.stealth,
				hero.resilience, hero.leadership, hero.morale,
				injury_str
			])
		# Accumulated combat outcomes
		var combat_outcomes: Dictionary = progress["combat_outcomes"]
		if not combat_outcomes.is_empty():
			for hid: String in combat_outcomes.keys():
				var oc: Dictionary = combat_outcomes[hid]
				lines.append("  Outcome  : %s — injured=%s sev=%s died=%s captured=%s recovery=%d" % [
					hid,
					str(oc.get("injured", false)),
					Enums.InjurySeverity.keys()[oc.get("severity", 0)],
					str(oc.get("died", false)),
					str(oc.get("captured", false)),
					oc.get("recovery_days", 0),
				])
	else:
		lines.append("  Mission  : not found in MissionManager (may be finalized)")

	# Stream queue depth
	lines.append("  Queue    : %d events pending  |  buffer=%d" % [
		_stream_queue.size(), _day_buffer.size()
	])

	print("\n".join(lines))

# ── Test helpers ──────────────────────────────────────────────────────────────

func reset_runtime_state() -> void:
	active_feeds.clear()
	_pending_interventions.clear()
	_mission_colors.clear()
	_hero_colors.clear()
	_color_index = 0
	_day_buffer.clear()
	_stream_queue.clear()
	_streaming_active = false
	_stream_paused = false

func _reset_for_test() -> void:
	reset_runtime_state()

func _inject_templates_for_test(templates: Dictionary) -> void:
	_templates = templates
