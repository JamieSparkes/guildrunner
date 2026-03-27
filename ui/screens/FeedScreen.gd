extends Control
## Single-column mission feed. Events are revealed one-by-one via a timer.
## Pauses on intervention triggers; resumes after the player resolves the prompt.
## Auto-opened after "Advance Day". Manual open shows full history (non-streaming).

const FEED_ENTRY_SCENE := preload("res://ui/components/FeedEntry.tscn")
const INTERVENTION_PROMPT_SCENE := preload("res://ui/components/InterventionPrompt.tscn")

const REVEAL_DELAY_SEC: float = 0.8

var _scroll: ScrollContainer
var _entries_box: VBoxContainer
var _empty_lbl: Label
var _close_btn: Button
var _auto_opened: bool = false

# ── Stream state ──────────────────────────────────────────────────────────────

var _timer: Timer
## Mission IDs whose pre-outcome events have been revealed; awaiting finalization.
var _missions_awaiting_finalization: Array[String] = []
var _paused_for_intervention: bool = false

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(data: Dictionary) -> void:
	_auto_opened = data.get("auto_opened", false)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	if _auto_opened:
		# Populate finalization queue from missions that already started their narrative
		# during advance_day() — that happens before this screen opens, so the signal
		# mission_narrative_started was emitted before we connected to it.
		_missions_awaiting_finalization.assign(MissionManager.get_pending_resolution_ids())
		# Still connect for any future narrative starts (e.g. second advance while feed is open).
		EventBus.mission_narrative_started.connect(_on_mission_narrative_started)
		EventBus.intervention_data_ready.connect(_on_intervention_data_ready)
		EventBus.feed_stream_resume.connect(_on_stream_resumed)
		EventBus.feed_stream_event_queued.connect(_schedule_tick)
		_empty_lbl.hide()
		_scroll.show()
		_close_btn.disabled = true
		_schedule_tick()
	else:
		# Manual open: show full history all at once (non-streaming).
		_populate_history()

func _exit_tree() -> void:
	if EventBus.mission_narrative_started.is_connected(_on_mission_narrative_started):
		EventBus.mission_narrative_started.disconnect(_on_mission_narrative_started)
	if EventBus.intervention_data_ready.is_connected(_on_intervention_data_ready):
		EventBus.intervention_data_ready.disconnect(_on_intervention_data_ready)
	if EventBus.feed_stream_resume.is_connected(_on_stream_resumed):
		EventBus.feed_stream_resume.disconnect(_on_stream_resumed)
	if EventBus.feed_stream_event_queued.is_connected(_schedule_tick):
		EventBus.feed_stream_event_queued.disconnect(_schedule_tick)
	FeedManager.end_stream()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

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

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func() -> void: EventBus.cmd_close_top_screen.emit())
	header.add_child(_close_btn)

	outer.add_child(HSeparator.new())

	_empty_lbl = Label.new()
	_empty_lbl.text = "No mission events.\nDispatch heroes from the Contract Board."
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_empty_lbl)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_entries_box = VBoxContainer.new()
	_entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_entries_box)

	# Create the timer used for streaming.
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)

# ── Streaming loop ────────────────────────────────────────────────────────────

func _schedule_tick() -> void:
	if _paused_for_intervention or _timer.time_left > 0:
		return
	_timer.start(REVEAL_DELAY_SEC)

func _on_timer_tick() -> void:
	if _paused_for_intervention:
		return
	if not FeedManager.has_stream_events():
		_try_finalize_next()
		return
	var event: FeedEvent = FeedManager.pop_stream_event()
	_reveal_event(event)
	# Check for intervention trigger at reveal time — not at push time.
	if event.can_trigger_intervention \
			and GuildManager.get_state().intervention_tokens > 0 \
			and not _paused_for_intervention:
		_paused_for_intervention = true
		FeedManager.set_stream_paused(true)
		EventBus.cmd_request_intervention.emit(event.mission_id, event.event_key)
		return  # Wait for intervention_data_ready, then feed_stream_resume.
	_schedule_tick()

func _reveal_event(event: FeedEvent) -> void:
	_empty_lbl.hide()
	_scroll.show()
	var entry: Node = FEED_ENTRY_SCENE.instantiate()
	entry.setup(event)
	_entries_box.add_child(entry)
	# Scroll to bottom after layout is updated.
	(func() -> void:
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value
	).call_deferred()

func _try_finalize_next() -> void:
	if _missions_awaiting_finalization.is_empty():
		_on_all_done()
		return
	var mission_id: String = _missions_awaiting_finalization.pop_front()
	# Finalization pushes outcome + epilogue events into the stream queue,
	# which triggers feed_stream_event_queued → _schedule_tick().
	EventBus.cmd_finalize_mission.emit(mission_id)

func _on_all_done() -> void:
	_close_btn.disabled = false

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_mission_narrative_started(mission_id: String) -> void:
	_missions_awaiting_finalization.append(mission_id)

func _on_intervention_data_ready(data: InterventionData) -> void:
	var prompt: Node = INTERVENTION_PROMPT_SCENE.instantiate()
	prompt.setup(data)
	_entries_box.add_child(prompt)

func _on_stream_resumed() -> void:
	_paused_for_intervention = false
	_schedule_tick()

# ── Non-streaming history display ─────────────────────────────────────────────

func _populate_history() -> void:
	var events: Array = FeedManager.get_all_events()
	if events.is_empty():
		_empty_lbl.show()
		_scroll.hide()
		return
	_empty_lbl.hide()
	_scroll.show()
	for event: FeedEvent in events:
		var entry: Node = FEED_ENTRY_SCENE.instantiate()
		entry.setup(event)
		_entries_box.add_child(entry)
