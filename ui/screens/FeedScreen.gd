extends Control
## Single-column mission feed (M9b). Color-coded by mission; batched on day advance.
## Auto-opened after "Advance Day" if events were generated. Manual open shows full history.

const FEED_ENTRY_SCENE := preload("res://ui/components/FeedEntry.tscn")
const INTERVENTION_PROMPT_SCENE := preload("res://ui/components/InterventionPrompt.tscn")

var _scroll: ScrollContainer
var _entries_box: VBoxContainer
var _empty_lbl: Label
var _auto_opened: bool = false

func setup(data: Dictionary) -> void:
	_auto_opened = data.get("auto_opened", false)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_populate_feed()
	EventBus.feed_intervention_available.connect(_on_intervention_available)

func _build_ui() -> void:
	# Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	# Header
	var header_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		header_margin.add_theme_constant_override("margin_" + side, 10)
	outer.add_child(header_margin)

	var header := HBoxContainer.new()
	header_margin.add_child(header)

	var title := Label.new()
	if _auto_opened:
		title.text = "Day %d Report" % TimeManager.current_day
	else:
		title.text = "Mission Feed"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(UIManager.pop_screen)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# Empty state label
	_empty_lbl = Label.new()
	_empty_lbl.text = "No mission events.\nDispatch heroes from the Contract Board."
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_empty_lbl)

	# Scrollable entries
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_entries_box = VBoxContainer.new()
	_entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_entries_box)

func _populate_feed() -> void:
	var events: Array
	if _auto_opened:
		events = FeedManager.get_day_buffer()
	else:
		events = FeedManager.get_all_events()

	if events.is_empty():
		_empty_lbl.show()
		_scroll.hide()
		return

	_empty_lbl.hide()
	_scroll.show()

	# Track last entry index per mission for intervention placement.
	var last_entry_index: Dictionary = {}  # { mission_id: int }

	for event: FeedEvent in events:
		var entry: Node = FEED_ENTRY_SCENE.instantiate()
		entry.setup(event)
		_entries_box.add_child(entry)
		last_entry_index[event.mission_id] = _entries_box.get_child_count() - 1

	# Insert inline intervention prompts after the triggering event.
	# Process in reverse index order so insertions don't shift earlier indices.
	var interventions: Array = _collect_pending_interventions(events)
	interventions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["index"] > b["index"]
	)
	for info: Dictionary in interventions:
		var prompt: Node = INTERVENTION_PROMPT_SCENE.instantiate()
		prompt.setup(info["mission_id"], info["context"])
		_entries_box.add_child(prompt)
		_entries_box.move_child(prompt, info["index"] + 1)

## Build list of {mission_id, index, context} for pending interventions.
func _collect_pending_interventions(events: Array) -> Array:
	var result: Array = []
	var seen_missions: Dictionary = {}
	for i: int in events.size():
		var event: FeedEvent = events[i]
		if event.event_key in FeedManager.INTERVENTION_TRIGGER_KEYS \
				and not seen_missions.has(event.mission_id) \
				and FeedManager._pending_interventions.get(event.mission_id, false):
			seen_missions[event.mission_id] = true
			var context := _intervention_context(event.event_key)
			result.append({"mission_id": event.mission_id, "index": i, "context": context})
	return result

func _intervention_context(event_key: String) -> String:
	if event_key in ["hero_wounded_minor", "hero_wounded_serious"]:
		return "A hero has been wounded. Change commitment?"
	if event_key == "encounter_obstacle":
		return "A decision point reached. Change commitment?"
	return "Intervention available. Change commitment?"

func _on_intervention_available(mission_id: String) -> void:
	# Live trigger (unlikely with batching, but defensive).
	var context := "Intervention available. Change commitment?"
	var prompt: Node = INTERVENTION_PROMPT_SCENE.instantiate()
	prompt.setup(mission_id, context)
	_entries_box.add_child(prompt)
