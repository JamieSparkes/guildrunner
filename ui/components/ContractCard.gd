extends PanelContainer
## Displays one contract on the board. Emits contract_pressed when the Select button is clicked.

signal contract_pressed(contract: ContractData)

var _contract: ContractData
var _title_lbl: Label
var _diff_lbl: Label
var _desc_lbl: Label
var _faction_lbl: Label
var _reward_lbl: Label
var _duration_lbl: Label

func setup(contract: ContractData) -> void:
	_contract = contract
	if is_inside_tree():
		_update_display()

func _ready() -> void:
	_build_ui()
	if _contract != null:
		_update_display()

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 100)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_lbl)

	_diff_lbl = Label.new()
	title_row.add_child(_diff_lbl)

	# Description
	_desc_lbl = Label.new()
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_desc_lbl)

	# Footer row
	var footer := HBoxContainer.new()
	vbox.add_child(footer)

	_faction_lbl = Label.new()
	_faction_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_faction_lbl)

	_duration_lbl = Label.new()
	footer.add_child(_duration_lbl)

	_reward_lbl = Label.new()
	footer.add_child(_reward_lbl)

	var btn := Button.new()
	btn.text = "Select"
	btn.pressed.connect(_on_select_pressed)
	footer.add_child(btn)

func _update_display() -> void:
	_title_lbl.text = _contract.title
	_diff_lbl.text = " [%s] Diff %d" % [
		Enums.MissionType.keys()[_contract.mission_type],
		_contract.difficulty
	]
	_desc_lbl.text = _contract.description
	_faction_lbl.text = _contract.client_faction_id.capitalize()
	var total_days := _contract.base_duration_days + _contract.distance_days
	_duration_lbl.text = "  %d day(s)  " % total_days
	_reward_lbl.text = "%d g  " % _contract.reward_gold

func _on_select_pressed() -> void:
	if _contract != null:
		contract_pressed.emit(_contract)
