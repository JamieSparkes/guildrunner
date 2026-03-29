extends Control
## Hero assignment and commitment selection before dispatching.
## setup({"contract": ContractData}) is called by UIManager after instantiation.

const HERO_CARD_SCENE := preload("res://ui/components/HeroPortraitCard.tscn")

var _contract: ContractData
var _commitment: Enums.CommitmentLevel = Enums.CommitmentLevel.USE_JUDGEMENT
var _hero_cards: Array[Node] = []

# UI references set during _build_ui()
var _contract_title_lbl: Label
var _contract_desc_lbl: Label
var _hero_row: HBoxContainer
var _success_chance_lbl: Label
var _status_lbl: Label
var _dispatch_btn: Button
var _commit_row: HBoxContainer

func setup(data: Dictionary) -> void:
	_contract = data.get("contract", null)
	if is_inside_tree() and _contract != null:
		_populate_contract()
		_populate_heroes()

func _ready() -> void:
	_build_ui()
	EventBus.mission_dispatch_result.connect(_on_mission_dispatch_result)
	if _contract != null:
		_populate_contract()
		_populate_heroes()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := CenterContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 580)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Contract info
	_contract_title_lbl = Label.new()
	vbox.add_child(_contract_title_lbl)

	_contract_desc_lbl = Label.new()
	_contract_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_contract_desc_lbl)

	vbox.add_child(HSeparator.new())

	# Hero selection
	var hero_hdr := Label.new()
	hero_hdr.text = "Assign Heroes:"
	vbox.add_child(hero_hdr)

	var hero_scroll := ScrollContainer.new()
	hero_scroll.custom_minimum_size = Vector2(0, 170)
	hero_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(hero_scroll)

	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 8)
	hero_scroll.add_child(_hero_row)

	vbox.add_child(HSeparator.new())

	# Commitment
	var commit_hdr := Label.new()
	commit_hdr.text = "Commitment Level:"
	vbox.add_child(commit_hdr)

	_commit_row = HBoxContainer.new()
	_commit_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_commit_row)

	var commit_options: Array = [
		[Enums.CommitmentLevel.AT_ANY_COST,    "At Any Cost"],
		[Enums.CommitmentLevel.USE_JUDGEMENT,  "Use Judgement"],
		[Enums.CommitmentLevel.COME_HOME_SAFE, "Come Home Safe"],
	]
	for pair in commit_options:
		var level: int = pair[0]
		var label: String = pair[1]
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.button_pressed = (level == Enums.CommitmentLevel.USE_JUDGEMENT)
		btn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_commitment = level as Enums.CommitmentLevel
				_deselect_other_commit_buttons(btn)
				_update_success_chance()
			elif _commitment == level:
				btn.button_pressed = true  # Prevent deselecting active option
		)
		_commit_row.add_child(btn)

	vbox.add_child(HSeparator.new())

	# Success Chance Label
	_success_chance_lbl = Label.new()
	_success_chance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success_chance_lbl.text = "Chance of Success: 0%"
	vbox.add_child(_success_chance_lbl)

	# Status / error label
	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(_status_lbl)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: EventBus.cmd_close_top_screen.emit())
	btn_row.add_child(back_btn)

	_dispatch_btn = Button.new()
	_dispatch_btn.text = "Dispatch"
	_dispatch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dispatch_btn.pressed.connect(_on_dispatch_pressed)
	btn_row.add_child(_dispatch_btn)

func _populate_contract() -> void:
	_contract_title_lbl.text = "%s  [Difficulty %d]" % [_contract.title, _contract.difficulty]
	_contract_desc_lbl.text = _contract.description

func _populate_heroes() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	_hero_cards.clear()

	var available := HeroManager.get_available_heroes()
	if available.is_empty():
		var lbl := Label.new()
		lbl.text = "No heroes available for dispatch."
		_hero_row.add_child(lbl)
		return

	for hero: HeroData in available:
		var card := HERO_CARD_SCENE.instantiate()
		card.setup(hero)
		card.hero_toggled.connect(func(_h: HeroData, _p: bool) -> void:
			_status_lbl.text = ""
			_update_success_chance()
		)
		_hero_row.add_child(card)
		_hero_cards.append(card)

	_update_success_chance()

func _deselect_other_commit_buttons(active: Button) -> void:
	for child in _commit_row.get_children():
		if child is Button and child != active:
			(child as Button).button_pressed = false

func _update_success_chance() -> void:
	if not is_instance_valid(_success_chance_lbl):
		return
	var selected_squad: Array[HeroData] = []
	for card in _hero_cards:
		if card.is_selected():
			selected_squad.append(card._hero)
	
	if selected_squad.is_empty():
		_success_chance_lbl.text = "Chance of Success: —"
		return

	var chance: float
	if not _contract.stages.is_empty():
		chance = StageResolver.calculate_success_chance(_contract, selected_squad)
	else:
		chance = MissionResolver.calculate_success_chance(_contract, selected_squad, _commitment)
	_success_chance_lbl.text = "Chance of Success: %d%%" % roundi(chance * 100)

func _on_dispatch_pressed() -> void:
	var selected_ids: Array[String] = []
	for card in _hero_cards:
		if card.is_selected():
			selected_ids.append(card._hero.hero_id)

	if selected_ids.is_empty():
		_status_lbl.text = "Select at least one hero."
		return

	if selected_ids.size() < _contract.min_heroes:
		_status_lbl.text = "This contract requires at least %d hero(es)." % _contract.min_heroes
		return

	EventBus.cmd_dispatch_contract.emit(_contract, selected_ids, _commitment)

func _on_mission_dispatch_result(success: bool, _mission_id: String, error: String) -> void:
	if success:
		_status_lbl.text = ""
		return
	_status_lbl.text = error
