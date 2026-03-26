extends ScrollContainer
## A scrollable column of FeedEntry nodes for one mission (or all missions).
## M6: one column showing all feeds combined. M9 will use per-mission columns.
## Call setup() then refresh() after add_child().

const FEED_ENTRY_SCENE := preload("res://ui/components/FeedEntry.tscn")

var _mission_id_filter: String = ""
var _entries_box: VBoxContainer

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_entries_box = VBoxContainer.new()
	_entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_box.add_theme_constant_override("separation", 2)
	add_child(_entries_box)

	EventBus.feed_event.connect(_on_feed_event)

## Pass "" to show all missions, or a specific mission_id to filter.
func setup(mission_id_filter: String = "") -> void:
	_mission_id_filter = mission_id_filter

## Rebuild the column from current FeedManager state.
func refresh() -> void:
	for child: Node in _entries_box.get_children():
		child.queue_free()
	var events: Array = FeedManager.get_all_events() \
		if _mission_id_filter == "" \
		else FeedManager.get_feed(_mission_id_filter)
	for event: FeedEvent in events:
		_add_entry(event)

# ── Internal ──────────────────────────────────────────────────────────────────

func _add_entry(event: FeedEvent) -> void:
	var entry: Node = FEED_ENTRY_SCENE.instantiate()
	entry.setup(event)
	_entries_box.add_child(entry)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)

func _on_feed_event(mission_id: String, _event_key: String, _params: Dictionary) -> void:
	if _mission_id_filter != "" and mission_id != _mission_id_filter:
		return
	# FeedManager._on_feed_event runs first (autoload connected earlier),
	# so get_feed already contains the new event.
	var feed: Array = FeedManager.get_feed(mission_id)
	if not feed.is_empty():
		_add_entry(feed[-1])
		_scroll_to_bottom()
