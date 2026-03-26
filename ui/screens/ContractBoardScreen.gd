extends Control
## Lists available contracts from ContractQueue.
## Pushed onto the UIManager stack when the player clicks the Contract Board hotspot.

const CONTRACT_CARD_SCENE := preload("res://ui/components/ContractCard.tscn")

var _contract_list: VBoxContainer

func _ready() -> void:
	_build_ui()
	_populate_contracts()
	EventBus.contract_available.connect(_on_contracts_changed)
	EventBus.contract_accepted.connect(_on_contracts_changed)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel
	var outer := CenterContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Contract Board"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(UIManager.pop_screen)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Scrollable contract list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_contract_list = VBoxContainer.new()
	_contract_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_contract_list)

func _populate_contracts() -> void:
	for child in _contract_list.get_children():
		child.queue_free()

	var contracts := ContractQueue.get_available_contracts()
	if contracts.is_empty():
		var lbl := Label.new()
		lbl.text = "No contracts available. Advance the day to receive new work."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_contract_list.add_child(lbl)
		return

	for contract: ContractData in contracts:
		var card := CONTRACT_CARD_SCENE.instantiate() as PanelContainer
		card.setup(contract)
		card.contract_pressed.connect(_on_contract_selected)
		_contract_list.add_child(card)

func _on_contracts_changed(_id: String = "") -> void:
	_populate_contracts()

func _on_contract_selected(contract: ContractData) -> void:
	UIManager.push_screen("mission_briefing", {"contract": contract})
