extends Node
## Manages the auto-resolve feed for all active missions.
## Per TDD §4.2.1: active_feeds, push_event, _format_event with personality variant selection.

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

## Active feed entries per mission. { mission_id: Array } — each array holds FeedEvent.
var active_feeds: Dictionary = {}
var _templates: Dictionary = {}  # { event_key: { personality_key: [String] } }

func _ready() -> void:
	_templates = DataLoader.load_feed_event_templates()
	EventBus.feed_event.connect(_on_feed_event)

# ── Public API ────────────────────────────────────────────────────────────────

## Create and store a FeedEvent for the given mission.
## params keys:
##   "personality" — String matching Enums.PersonalityType name (e.g. "STOIC").
##                   Falls back to "DEFAULT" then the first available personality.
##   Any {placeholder} tokens used in the template variant (e.g. "name", "target").
func push_event(mission_id: String, event_key: String, params: Dictionary) -> void:
	if not active_feeds.has(mission_id):
		active_feeds[mission_id] = []
	var personality: String = params.get("personality", "STOIC")
	var text := _format_event(event_key, params, personality)
	var event := FeedEvent.new(mission_id, text, event_key, false, TimeManager.current_day)
	(active_feeds[mission_id] as Array).append(event)

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

func _inject_templates_for_test(templates: Dictionary) -> void:
	_templates = templates
