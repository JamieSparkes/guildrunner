extends Control
## Single-column mission feed. Events are revealed one-by-one via a timer.
## Pauses on intervention triggers; resumes after the player resolves the prompt.
## Auto-opened after "Advance Day". Manual open shows full history (non-streaming).

const FEED_ENTRY_SCENE := preload("res://ui/components/FeedEntry.tscn")
const INTERVENTION_PROMPT_SCENE := preload("res://ui/components/InterventionPrompt.tscn")
const TIMELINE_SCENE := preload("res://ui/components/MissionTimeline.tscn")

const REVEAL_DELAY_SEC: float = 0.8

var _scroll: ScrollContainer
var _entries_box: VBoxContainer
var _empty_lbl: Label
var _close_btn: Button
var _auto_opened: bool = false
var _stream_finished: bool = false

# ── Timeline state ────────────────────────────────────────────────────────────

var _timelines_box: VBoxContainer
var _timelines: Dictionary = {}  # { mission_id: MissionTimeline node }
## Maps mission_id → array of stage narrative_keys (in order) so we can detect
## which stage a revealed feed event corresponds to.
var _stage_narrative_keys: Dictionary = {}  # { mission_id: Array[String] }
## Tracks the highest stage index we've revealed per mission during streaming.
var _revealed_stage: Dictionary = {}  # { mission_id: int }

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
		_build_timelines()
		_empty_lbl.hide()
		_scroll.show()
		_close_btn.text = "Skip ▶▶"
		_close_btn.disabled = false
		_schedule_tick()
	else:
		# Manual open: show full history all at once (non-streaming).
		_build_timelines_for_history()
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
	if EventBus.mission_stage_completed.is_connected(_on_mission_stage_completed):
		EventBus.mission_stage_completed.disconnect(_on_mission_stage_completed)
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

	# Spacer so the button sits in the centre of the header
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 0)
	_close_btn.pressed.connect(_on_close_btn_pressed)
	header.add_child(_close_btn)

	outer.add_child(HSeparator.new())

	# ── Feed area (fills available space above the timeline panel) ────────────
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

	# ── Timeline panel (fixed height, lower quarter) ──────────────────────────
	outer.add_child(HSeparator.new())

	var tl_panel := PanelContainer.new()
	tl_panel.custom_minimum_size = Vector2(0, 260)
	tl_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	outer.add_child(tl_panel)

	var tl_scroll := ScrollContainer.new()
	tl_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tl_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tl_panel.add_child(tl_scroll)

	var tl_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		tl_margin.add_theme_constant_override("margin_" + side, 10)
	tl_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_scroll.add_child(tl_margin)

	_timelines_box = VBoxContainer.new()
	_timelines_box.add_theme_constant_override("separation", 8)
	_timelines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_margin.add_child(_timelines_box)

	# Create the timer used for streaming.
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)

# ── Streaming loop ────────────────────────────────────────────────────────────

func _schedule_tick() -> void:
	if _stream_finished or _paused_for_intervention or _timer.time_left > 0:
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
	# Advance timeline if this event is a stage narrative key.
	_try_advance_timeline(event)
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
	_stream_finished = true
	_close_btn.text = "Close"

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

func _on_close_btn_pressed() -> void:
	if _stream_finished:
		EventBus.cmd_close_top_screen.emit()
	else:
		_fast_forward()

## Drain the entire stream synchronously — no timer delays, no intervention pauses.
func _fast_forward() -> void:
	_timer.stop()
	_paused_for_intervention = false
	FeedManager.set_stream_paused(false)

	# Safety limit to avoid an infinite loop if something misbehaves.
	var safety := 2000
	while safety > 0:
		safety -= 1
		if FeedManager.has_stream_events():
			_reveal_event(FeedManager.pop_stream_event())
		elif not _missions_awaiting_finalization.is_empty():
			# Finalization emits more events synchronously via feed_event signal,
			# which lands in the stream queue immediately if streaming is active.
			EventBus.cmd_finalize_mission.emit(_missions_awaiting_finalization.pop_front())
		else:
			break

	_on_all_done()

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

# ── Timeline management ──────────────────────────────────────────────────────

## Create timelines for all active staged missions (streaming mode).
func _build_timelines() -> void:
	EventBus.mission_stage_completed.connect(_on_mission_stage_completed)
	for mission in MissionManager.get_active_missions():
		_create_timeline_for_mission(mission.mission_id)
	# Also create for missions already pending resolution (events queued but not finalized).
	for mid: String in _missions_awaiting_finalization:
		if not _timelines.has(mid):
			_create_timeline_for_mission(mid)

## Create timelines showing current state for history view.
func _build_timelines_for_history() -> void:
	for mission in MissionManager.get_active_missions():
		var mid: String = mission.mission_id
		var tl := _create_timeline_for_mission(mid)
		if tl != null:
			var progress: Variant = MissionManager.get_mission_progress(mid)
			if progress != null:
				tl.advance_to(progress["current_stage_index"])
				if progress["completed"]:
					var obj_done: bool = mission.flags.get("objective_complete", false)
					tl.mark_completed(obj_done)

func _create_timeline_for_mission(mission_id: String) -> Node:
	if _timelines.has(mission_id):
		return _timelines[mission_id]
	var progress: Variant = MissionManager.get_mission_progress(mission_id)
	if progress == null or progress["total_stages"] == 0:
		return null
	var tl: Node = TIMELINE_SCENE.instantiate()
	tl.setup_timeline(mission_id, progress)
	_timelines_box.add_child(tl)
	_timelines[mission_id] = tl
	_stage_narrative_keys[mission_id] = progress["stage_narrative_keys"]
	_revealed_stage[mission_id] = 0
	return tl

func _try_advance_timeline(event: FeedEvent) -> void:
	var mid := event.mission_id
	if not _timelines.has(mid):
		return
	if not _stage_narrative_keys.has(mid):
		return
	var keys: Array = _stage_narrative_keys[mid]
	var current_revealed: int = _revealed_stage.get(mid, 0)
	# Check if this event's key matches any stage narrative key ahead of where we are.
	for i: int in range(current_revealed, keys.size()):
		if event.event_key == keys[i]:
			_revealed_stage[mid] = i
			(_timelines[mid] as PanelContainer).advance_to(i)
			break
	# Detect stage_timed_out or outcome events as mission completion in the stream.
	if event.event_key == "stage_timed_out":
		(_timelines[mid] as PanelContainer).mark_completed(false)
	elif event.event_key in ["outcome_success", "outcome_full_success"]:
		(_timelines[mid] as PanelContainer).mark_completed(true)
	elif event.event_key in ["outcome_failure", "outcome_partial"]:
		(_timelines[mid] as PanelContainer).mark_completed(false)

func _on_mission_stage_completed(mission_id: String, success: bool) -> void:
	if _timelines.has(mission_id):
		(_timelines[mission_id] as PanelContainer).mark_completed(success)
