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

func _ready() -> void:
	_templates = DataLoader.load_feed_event_templates()
	EventBus.feed_event.connect(_on_feed_event)
	EventBus.intervention_used.connect(_on_intervention_used)

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
	(active_feeds[mission_id] as Array).append(event)
	_day_buffer.append(event)
	# Check whether this event should trigger an intervention prompt.
	if _should_trigger_intervention(mission_id, event_key):
		EventBus.feed_intervention_available.emit(mission_id)

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

func _should_trigger_intervention(mission_id: String, event_key: String) -> bool:
	if _pending_interventions.get(mission_id, false):
		return false  # Already pending for this mission
	if GuildManager.get_state().intervention_tokens <= 0:
		return false  # No tokens available
	if event_key in INTERVENTION_TRIGGER_KEYS:
		_pending_interventions[mission_id] = true
		return true
	return false

func _on_intervention_used(mission_id: String, _commitment: int) -> void:
	_pending_interventions.erase(mission_id)

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

# ── Test helpers ──────────────────────────────────────────────────────────────

func _reset_for_test() -> void:
	active_feeds.clear()
	_pending_interventions.clear()
	_mission_colors.clear()
	_hero_colors.clear()
	_color_index = 0
	_day_buffer.clear()

func _inject_templates_for_test(templates: Dictionary) -> void:
	_templates = templates
