extends Control
## Developer tool for manually adding and removing contracts on the board.
## Open with F9 at any time. Not wired into normal game flow.

# ── Shared form fields ────────────────────────────────────────────────────────
var _title_edit: LineEdit
var _desc_edit: LineEdit
var _difficulty_spin: SpinBox
var _min_heroes_spin: SpinBox
var _gold_spin: SpinBox
var _gold_partial_spin: SpinBox
var _capture_check: CheckBox

# ── Mode toggle ───────────────────────────────────────────────────────────────
var _flat_btn: Button
var _staged_btn: Button
var _flat_section: Control
var _staged_section: Control

# ── Flat-specific ─────────────────────────────────────────────────────────────
var _duration_spin: SpinBox

# ── Staged-specific ───────────────────────────────────────────────────────────
var _max_duration_spin: SpinBox
var _stages_vbox: VBoxContainer

# ── Bottom UI ─────────────────────────────────────────────────────────────────
var _template_option: OptionButton
var _board_list: VBoxContainer
var _status_lbl: Label

var _counter: int = 0
var _stage_counter: int = 0

func _ready() -> void:
	_build_ui()
	_refresh_board_list()
	_refresh_template_list()
	_set_mode(false)  # start in flat mode

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := CenterContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940, 640)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)
	var hdr_lbl := Label.new()
	hdr_lbl.text = "Contract Editor  [DEV]"
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hdr_lbl)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: EventBus.cmd_close_top_screen.emit())
	header.add_child(close_btn)

	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_left_panel())
	body.add_child(VSeparator.new())
	body.add_child(_build_board_panel())

func _build_left_panel() -> Control:
	var outer_vbox := VBoxContainer.new()
	outer_vbox.custom_minimum_size = Vector2(430, 0)
	outer_vbox.add_theme_constant_override("separation", 6)

	# ── Shared fields ─────────────────────────────────────────────────────────
	_title_edit = _make_line_edit("e.g. Retrieve the Shipment")
	outer_vbox.add_child(_row("Title", _title_edit))

	_desc_edit = _make_line_edit("Short flavour text")
	outer_vbox.add_child(_row("Description", _desc_edit))

	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(nums)
	_difficulty_spin = _make_spin(1, 5, 2)
	nums.add_child(_row("Difficulty", _difficulty_spin))
	_min_heroes_spin = _make_spin(1, 6, 1)
	nums.add_child(_row("Min Heroes", _min_heroes_spin))

	var golds := HBoxContainer.new()
	golds.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(golds)
	_gold_spin = _make_spin(0, 9999, 50)
	golds.add_child(_row("Reward Gold", _gold_spin))
	_gold_partial_spin = _make_spin(0, 9999, 0)
	golds.add_child(_row("Partial Gold", _gold_partial_spin))

	_capture_check = CheckBox.new()
	_capture_check.text = "Can Capture on failure"
	outer_vbox.add_child(_capture_check)

	outer_vbox.add_child(HSeparator.new())

	# ── Mode toggle ───────────────────────────────────────────────────────────
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 0)
	outer_vbox.add_child(mode_row)

	_flat_btn = Button.new()
	_flat_btn.text = "Flat Contract"
	_flat_btn.toggle_mode = true
	_flat_btn.button_pressed = true
	_flat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flat_btn.pressed.connect(func() -> void: _set_mode(false))
	mode_row.add_child(_flat_btn)

	_staged_btn = Button.new()
	_staged_btn.text = "Staged Contract"
	_staged_btn.toggle_mode = true
	_staged_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staged_btn.pressed.connect(func() -> void: _set_mode(true))
	mode_row.add_child(_staged_btn)

	# ── Flat section ──────────────────────────────────────────────────────────
	_flat_section = VBoxContainer.new()
	(_flat_section as VBoxContainer).add_theme_constant_override("separation", 6)
	outer_vbox.add_child(_flat_section)

	_duration_spin = _make_spin(1, 14, 3)
	_flat_section.add_child(_row("Duration Days", _duration_spin))

	var flat_add := Button.new()
	flat_add.text = "Add Flat Contract to Board"
	flat_add.pressed.connect(_on_add_flat_pressed)
	_flat_section.add_child(flat_add)

	# ── Staged section ────────────────────────────────────────────────────────
	_staged_section = VBoxContainer.new()
	(_staged_section as VBoxContainer).add_theme_constant_override("separation", 6)
	outer_vbox.add_child(_staged_section)

	_max_duration_spin = _make_spin(1, 14, 4)
	_staged_section.add_child(_row("Max Duration Days", _max_duration_spin))

	var stages_hdr := HBoxContainer.new()
	_staged_section.add_child(stages_hdr)
	var stages_lbl := Label.new()
	stages_lbl.text = "Stages"
	stages_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages_hdr.add_child(stages_lbl)
	var add_stage_btn := Button.new()
	add_stage_btn.text = "+ Stage"
	add_stage_btn.pressed.connect(_add_stage)
	stages_hdr.add_child(add_stage_btn)

	var stages_scroll := ScrollContainer.new()
	stages_scroll.custom_minimum_size = Vector2(0, 200)
	stages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staged_section.add_child(stages_scroll)

	_stages_vbox = VBoxContainer.new()
	_stages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages_vbox.add_theme_constant_override("separation", 4)
	stages_scroll.add_child(_stages_vbox)

	var staged_add := Button.new()
	staged_add.text = "Add Staged Contract to Board"
	staged_add.pressed.connect(_on_add_staged_pressed)
	_staged_section.add_child(staged_add)

	outer_vbox.add_child(HSeparator.new())

	# ── From Template ─────────────────────────────────────────────────────────
	outer_vbox.add_child(_make_label("Add from Template"))
	var tpl_row := HBoxContainer.new()
	tpl_row.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(tpl_row)
	_template_option = OptionButton.new()
	_template_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tpl_row.add_child(_template_option)
	var tpl_btn := Button.new()
	tpl_btn.text = "Add"
	tpl_btn.pressed.connect(_on_add_template_pressed)
	tpl_row.add_child(tpl_btn)

	# ── Status ────────────────────────────────────────────────────────────────
	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	outer_vbox.add_child(_status_lbl)

	return outer_vbox

func _build_board_panel() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_make_label("On the Board"))
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_board_list = VBoxContainer.new()
	_board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_board_list)
	return vbox

# ── Stage builder ─────────────────────────────────────────────────────────────

func _add_stage() -> void:
	_stage_counter += 1
	var idx := _stage_counter

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages_vbox.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# Header row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vb.add_child(hdr)
	var stage_num_lbl := Label.new()
	stage_num_lbl.text = "Stage %d:" % idx
	hdr.add_child(stage_num_lbl)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "stage_id"
	id_edit.text = "stage_%d" % idx
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(id_edit)
	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.pressed.connect(func() -> void: panel.queue_free())
	hdr.add_child(remove_btn)

	# Narrative + sets_flag
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	vb.add_child(detail)
	detail.add_child(_make_label("Narrative:"))
	var narr_edit := LineEdit.new()
	narr_edit.placeholder_text = "feed event key"
	narr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(narr_edit)
	detail.add_child(_make_label("Sets Flag:"))
	var flag_edit := LineEdit.new()
	flag_edit.placeholder_text = "objective_complete"
	flag_edit.custom_minimum_size = Vector2(130, 0)
	detail.add_child(flag_edit)

	# Advance type row
	var adv_row := HBoxContainer.new()
	adv_row.add_theme_constant_override("separation", 6)
	vb.add_child(adv_row)
	adv_row.add_child(_make_label("Advance:"))
	var adv_opt := OptionButton.new()
	for opt: String in ["auto", "chance", "stat_check"]:
		adv_opt.add_item(opt)
	adv_row.add_child(adv_opt)

	# Chance params
	var chance_row := HBoxContainer.new()
	chance_row.add_theme_constant_override("separation", 6)
	vb.add_child(chance_row)
	chance_row.add_child(_make_label("Base %:"))
	var base_spin := _make_spin_float(0.0, 1.0, 0.40)
	base_spin.step = 0.05
	chance_row.add_child(base_spin)
	chance_row.add_child(_make_label("Cumulative %:"))
	var cum_spin := _make_spin_float(0.0, 0.5, 0.0)
	cum_spin.step = 0.05
	chance_row.add_child(cum_spin)

	# Stat check params
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 6)
	vb.add_child(stat_row)
	stat_row.add_child(_make_label("Stat:"))
	var stat_opt := OptionButton.new()
	for s: String in ["strength", "agility", "stealth", "resilience", "leadership"]:
		stat_opt.add_item(s)
	stat_row.add_child(stat_opt)
	stat_row.add_child(_make_label("≥"))
	var threshold_spin := _make_spin(0, 100, 50)
	stat_row.add_child(threshold_spin)
	var fail_adv_check := CheckBox.new()
	fail_adv_check.text = "Fail Advance"
	stat_row.add_child(fail_adv_check)

	# Show/hide advance param rows based on type
	chance_row.visible = false
	stat_row.visible = false
	adv_opt.item_selected.connect(func(i: int) -> void:
		chance_row.visible = (i == 1)
		stat_row.visible = (i == 2)
	)

	# Events section
	var events_hdr := HBoxContainer.new()
	vb.add_child(events_hdr)
	var ev_lbl := Label.new()
	ev_lbl.text = "Events:"
	ev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_hdr.add_child(ev_lbl)
	var add_ev_btn := Button.new()
	add_ev_btn.text = "+ Event"
	events_hdr.add_child(add_ev_btn)

	var events_vbox := VBoxContainer.new()
	events_vbox.add_theme_constant_override("separation", 2)
	vb.add_child(events_vbox)
	add_ev_btn.pressed.connect(func() -> void: _add_event(events_vbox))

	# Store refs in metadata
	panel.set_meta("id_edit", id_edit)
	panel.set_meta("narr_edit", narr_edit)
	panel.set_meta("flag_edit", flag_edit)
	panel.set_meta("adv_opt", adv_opt)
	panel.set_meta("base_spin", base_spin)
	panel.set_meta("cum_spin", cum_spin)
	panel.set_meta("stat_opt", stat_opt)
	panel.set_meta("threshold_spin", threshold_spin)
	panel.set_meta("fail_adv_check", fail_adv_check)
	panel.set_meta("events_vbox", events_vbox)

func _add_event(events_vbox: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_vbox.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	# Row 1: type, chance, difficulty, remove
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)

	var type_opt := OptionButton.new()
	for t: String in ["combat", "reward", "discovery", "objective", "narrative"]:
		type_opt.add_item(t)
	row1.add_child(type_opt)

	row1.add_child(_make_label("Chance:"))
	var chance_spin := _make_spin_float(0.0, 1.0, 1.0)
	chance_spin.step = 0.05
	row1.add_child(chance_spin)

	row1.add_child(_make_label("Diff:"))
	var diff_spin := _make_spin(1, 5, 2)
	diff_spin.custom_minimum_size = Vector2(60, 0)
	row1.add_child(diff_spin)

	var rm_btn := Button.new()
	rm_btn.text = "✕"
	rm_btn.pressed.connect(func() -> void: panel.queue_free())
	row1.add_child(rm_btn)

	# Row 2: narrative key, on_success_flag, intervention checkbox
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vb.add_child(row2)

	row2.add_child(_make_label("Key:"))
	var narr_edit := LineEdit.new()
	narr_edit.placeholder_text = "feed event key"
	narr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(narr_edit)

	row2.add_child(_make_label("Flag:"))
	var flag_edit := LineEdit.new()
	flag_edit.placeholder_text = "on_success_flag"
	flag_edit.custom_minimum_size = Vector2(120, 0)
	row2.add_child(flag_edit)

	var interv_check := CheckBox.new()
	interv_check.text = "Intervene"
	row2.add_child(interv_check)

	# Row 3: reward gold (shown for reward type)
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	vb.add_child(row3)
	row3.add_child(_make_label("Gold:"))
	var gold_spin := _make_spin(0, 9999, 10)
	gold_spin.step = 5
	row3.add_child(gold_spin)
	row3.visible = false

	type_opt.item_selected.connect(func(i: int) -> void:
		row3.visible = (i == 1)  # "reward"
		diff_spin.editable = (i == 0)  # only combat uses difficulty
	)

	panel.set_meta("type_opt", type_opt)
	panel.set_meta("chance_spin", chance_spin)
	panel.set_meta("diff_spin", diff_spin)
	panel.set_meta("narr_edit", narr_edit)
	panel.set_meta("flag_edit", flag_edit)
	panel.set_meta("interv_check", interv_check)
	panel.set_meta("gold_spin", gold_spin)

# ── Mode switching ────────────────────────────────────────────────────────────

func _set_mode(staged: bool) -> void:
	_flat_section.visible = not staged
	_staged_section.visible = staged
	_flat_btn.button_pressed = not staged
	_staged_btn.button_pressed = staged

# ── Add to board ──────────────────────────────────────────────────────────────

func _on_add_flat_pressed() -> void:
	var t := _title_edit.text.strip_edges()
	if t.is_empty():
		_set_status("Title is required.", false)
		return
	_counter += 1
	var c := ContractData.new()
	c.contract_id        = "dev_%d" % _counter
	c.title              = t
	c.description        = _desc_edit.text.strip_edges()
	c.difficulty         = int(_difficulty_spin.value)
	c.min_heroes         = int(_min_heroes_spin.value)
	c.reward_gold        = int(_gold_spin.value)
	c.reward_gold_partial = int(_gold_partial_spin.value)
	c.base_duration_days = int(_duration_spin.value)
	c.can_capture        = _capture_check.button_pressed
	c.expiry_day         = 9999
	c.available_from_day = 1
	_push_to_board(c)

func _on_add_staged_pressed() -> void:
	var t := _title_edit.text.strip_edges()
	if t.is_empty():
		_set_status("Title is required.", false)
		return
	if _stages_vbox.get_child_count() == 0:
		_set_status("Add at least one stage.", false)
		return
	_counter += 1
	var c := ContractData.new()
	c.contract_id         = "dev_%d" % _counter
	c.title               = t
	c.description         = _desc_edit.text.strip_edges()
	c.difficulty          = int(_difficulty_spin.value)
	c.min_heroes          = int(_min_heroes_spin.value)
	c.reward_gold         = int(_gold_spin.value)
	c.reward_gold_partial = int(_gold_partial_spin.value)
	c.max_duration_days   = int(_max_duration_spin.value)
	c.can_capture         = _capture_check.button_pressed
	c.expiry_day          = 9999
	c.available_from_day  = 1

	for stage_panel: Node in _stages_vbox.get_children():
		c.stages.append(_read_stage(stage_panel))

	_push_to_board(c)

func _read_stage(panel: Node) -> StageData:
	var sd := StageData.new()
	sd.stage_id      = (panel.get_meta("id_edit") as LineEdit).text.strip_edges()
	sd.narrative_key = (panel.get_meta("narr_edit") as LineEdit).text.strip_edges()
	sd.sets_flag     = (panel.get_meta("flag_edit") as LineEdit).text.strip_edges()

	var adv_idx: int = (panel.get_meta("adv_opt") as OptionButton).selected
	match adv_idx:
		0:  # auto
			sd.advance = { "type": "auto" }
		1:  # chance
			sd.advance = {
				"type": "chance",
				"base_chance": (panel.get_meta("base_spin") as SpinBox).value,
				"cumulative_increase": (panel.get_meta("cum_spin") as SpinBox).value,
			}
		2:  # stat_check
			var stat_name: String = (panel.get_meta("stat_opt") as OptionButton).get_item_text(
				(panel.get_meta("stat_opt") as OptionButton).selected)
			sd.advance = {
				"type": "stat_check",
				"stat": stat_name,
				"threshold": (panel.get_meta("threshold_spin") as SpinBox).value,
				"fail_advance": (panel.get_meta("fail_adv_check") as CheckBox).button_pressed,
			}

	var events_vbox: Node = panel.get_meta("events_vbox")
	for ev_panel: Node in events_vbox.get_children():
		sd.events.append(_read_event(ev_panel))

	return sd

func _read_event(panel: Node) -> StageEventData:
	var ev := StageEventData.new()
	var type_opt := panel.get_meta("type_opt") as OptionButton
	ev.type = type_opt.get_item_text(type_opt.selected)
	ev.chance = (panel.get_meta("chance_spin") as SpinBox).value
	ev.difficulty = int((panel.get_meta("diff_spin") as SpinBox).value)
	ev.narrative_key = (panel.get_meta("narr_edit") as LineEdit).text.strip_edges()
	ev.on_success_flag = (panel.get_meta("flag_edit") as LineEdit).text.strip_edges()
	ev.can_trigger_intervention = (panel.get_meta("interv_check") as CheckBox).button_pressed
	if ev.type == "reward":
		ev.reward = { "gold": int((panel.get_meta("gold_spin") as SpinBox).value) }
	return ev

func _on_add_template_pressed() -> void:
	var idx := _template_option.selected
	if idx < 0:
		_set_status("No template selected.", false)
		return
	var tid: String = _template_option.get_item_metadata(idx)
	if not ContractQueue._templates.has(tid):
		_set_status("Template not found.", false)
		return
	_counter += 1
	var tpl: ContractData = ContractQueue._templates[tid]
	var c: ContractData = tpl.duplicate()
	c.stages = tpl.stages
	c.contract_id = "dev_%d_%s" % [_counter, tid]
	c.expiry_day = 9999
	_push_to_board(c)

func _on_delete_pressed(contract_id: String) -> void:
	ContractQueue.remove_contract(contract_id)
	_set_status("Contract removed.", true)
	_refresh_board_list()

func _push_to_board(c: ContractData) -> void:
	ContractQueue.active_contracts.append(c)
	EventBus.contract_available.emit(c.contract_id)
	_set_status("Added \"%s\" to the board." % c.title, true)
	_refresh_board_list()

# ── Refresh helpers ───────────────────────────────────────────────────────────

func _refresh_board_list() -> void:
	for child in _board_list.get_children():
		child.queue_free()
	var contracts := ContractQueue.get_available_contracts()
	if contracts.is_empty():
		var lbl := Label.new()
		lbl.text = "(board is empty)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_board_list.add_child(lbl)
		return
	for c: ContractData in contracts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_board_list.add_child(row)
		var info := Label.new()
		var tag := " [staged]" if not c.stages.is_empty() else ""
		info.text = "[D%d]%s %s" % [c.difficulty, tag, c.title]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		row.add_child(info)
		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.pressed.connect(_on_delete_pressed.bind(c.contract_id))
		row.add_child(del_btn)

func _refresh_template_list() -> void:
	_template_option.clear()
	var ids: Array = ContractQueue._templates.keys()
	ids.sort()
	for id: String in ids:
		var tpl: ContractData = ContractQueue._templates[id]
		var tag := " [staged]" if not tpl.stages.is_empty() else ""
		_template_option.add_item("%s%s" % [tpl.title, tag])
		_template_option.set_item_metadata(_template_option.item_count - 1, id)

# ── Widget helpers ────────────────────────────────────────────────────────────

func _row(label_text: String, widget: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	h.add_child(lbl)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(widget)
	return h

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _make_line_edit(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	return le

func _make_spin(min_v: float, max_v: float, default_v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = default_v
	s.step = 1
	s.custom_minimum_size = Vector2(70, 0)
	return s

func _make_spin_float(min_v: float, max_v: float, default_v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = default_v
	s.step = 0.05
	s.custom_minimum_size = Vector2(70, 0)
	return s

func _set_status(msg: String, ok: bool) -> void:
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.5) if ok else Color(1.0, 0.4, 0.4))
