extends PanelContainer
## Horizontal stage timeline for a single staged mission.
## Shows stage pips connected by a track line, with hero portraits at their
## current position. Portraits lerp to the next pip when advance_to() is called.

const PIP_SIZE := 20.0
const PIP_SPACING := 110.0
const PORTRAIT_SIZE := 40.0
const TRACK_Y := 30.0
const PORTRAIT_Y := 4.0
const LABEL_Y := 56.0
const TWEEN_DURATION := 0.45
const TRACK_COLOR := Color(0.35, 0.35, 0.35)
const PIP_DONE_COLOR := Color(0.5, 0.8, 0.4)
const PIP_CURRENT_COLOR := Color(1.0, 0.85, 0.3)
const PIP_FUTURE_COLOR := Color(0.3, 0.3, 0.3)
const PIP_FAIL_COLOR := Color(0.7, 0.25, 0.25)

var _mission_id: String = ""
var _stage_names: Array[String] = []
var _total_stages: int = 0
var _current_index: int = 0
var _completed: bool = false
var _success: bool = false
var _progress: Dictionary = {}  # Stored for deferred build in _ready

var _canvas: Control  # Custom draw area for track + pips
var _portrait_nodes: Array[Control] = []
var _title_lbl: Label

func setup_timeline(mission_id: String, progress: Dictionary) -> void:
	_mission_id = mission_id
	_stage_names.assign(progress.get("stage_names", []))
	_total_stages = progress.get("total_stages", 0)
	_current_index = 0  # start at 0, FeedScreen advances as events stream
	_completed = false
	_success = false
	_progress = progress

	if is_inside_tree():
		_build_content(progress)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 96)
	if not _progress.is_empty():
		_build_content(_progress)

func _build_content(progress: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_portrait_nodes.clear()

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# Title row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.text = progress.get("title", _mission_id)
	var mission_color := FeedManager.get_mission_color(_mission_id)
	_title_lbl.add_theme_color_override("font_color", mission_color)
	header.add_child(_title_lbl)

	# Canvas for pips, track line, portraits
	_canvas = Control.new()
	var needed_width := PIP_SPACING * float(maxi(_total_stages - 1, 0)) + PIP_SIZE
	_canvas.custom_minimum_size = Vector2(maxf(needed_width + PORTRAIT_SIZE, 200.0), 80.0)
	vbox.add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)

	# Create hero portrait nodes
	var hero_ids: Array = progress.get("hero_ids", [])
	for i: int in hero_ids.size():
		var hid: String = hero_ids[i]
		var hero: HeroData = HeroManager.get_hero(hid)
		var portrait: Control
		if hero != null:
			portrait = PortraitHelper.create_portrait_rect(hero.portrait_id, PORTRAIT_SIZE)
		else:
			portrait = ColorRect.new()
			portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait.position = _portrait_pos_for_stage(0, i, hero_ids.size())
		_canvas.add_child(portrait)
		_portrait_nodes.append(portrait)

	# Stage name labels
	for s: int in _total_stages:
		var lbl := Label.new()
		lbl.text = _stage_names[s] if s < _stage_names.size() else str(s)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lbl_x := _pip_x(s) - 30.0
		lbl.position = Vector2(lbl_x, LABEL_Y)
		lbl.custom_minimum_size = Vector2(60, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_canvas.add_child(lbl)

func advance_to(stage_index: int) -> void:
	if stage_index <= _current_index and not (stage_index == _current_index and _current_index == 0):
		return
	_current_index = stage_index
	_animate_portraits()
	_canvas.queue_redraw()

func mark_completed(success: bool) -> void:
	_completed = true
	_success = success
	# Move portraits past last pip
	_current_index = _total_stages
	_animate_portraits()
	_canvas.queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _on_canvas_draw() -> void:
	if _total_stages == 0:
		return

	var y := TRACK_Y + PIP_SIZE * 0.5

	# Track line (only if 2+ stages)
	var x_start := _pip_x(0)
	if _total_stages >= 2:
		var x_end := _pip_x(_total_stages - 1)
		_canvas.draw_line(Vector2(x_start, y), Vector2(x_end, y), TRACK_COLOR, 2.0)

	# Progress line (filled portion)
	var fill_index := mini(_current_index, _total_stages - 1)
	if fill_index > 0:
		var fill_color := PIP_FAIL_COLOR if (_completed and not _success) else PIP_DONE_COLOR
		_canvas.draw_line(
			Vector2(x_start, y),
			Vector2(_pip_x(fill_index), y),
			fill_color, 2.0
		)

	# Pips
	for i: int in _total_stages:
		var pip_center := Vector2(_pip_x(i), y)
		var color: Color
		if _completed and not _success:
			color = PIP_DONE_COLOR if i < _current_index else PIP_FAIL_COLOR
		elif i < _current_index:
			color = PIP_DONE_COLOR
		elif i == _current_index and _current_index < _total_stages:
			color = PIP_CURRENT_COLOR
		else:
			color = PIP_FUTURE_COLOR
		_canvas.draw_circle(pip_center, PIP_SIZE * 0.5, color)

# ── Animation ─────────────────────────────────────────────────────────────────

func _animate_portraits() -> void:
	var hero_count := _portrait_nodes.size()
	for i: int in hero_count:
		var target := _portrait_pos_for_stage(_current_index, i, hero_count)
		var tween := create_tween()
		tween.tween_property(_portrait_nodes[i], "position", target, TWEEN_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ── Layout helpers ────────────────────────────────────────────────────────────

func _pip_x(stage_index: int) -> float:
	return PIP_SIZE * 0.5 + float(stage_index) * PIP_SPACING

func _portrait_pos_for_stage(stage_index: int, hero_offset: int, hero_count: int) -> Vector2:
	var clamped := mini(stage_index, maxi(_total_stages - 1, 0))
	var base_x := _pip_x(clamped) - PORTRAIT_SIZE * 0.5
	# Fan out multiple heroes slightly
	var fan := float(hero_offset - (hero_count - 1) * 0.5) * (PORTRAIT_SIZE + 4.0)
	return Vector2(base_x + fan, PORTRAIT_Y)
