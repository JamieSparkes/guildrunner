extends PanelContainer
## Data-driven intervention prompt. Rendered inline in the live feed when an
## intervention trigger fires. Call setup() with an InterventionData before add_child().
## Supports COMMITMENT_CHANGE today; BINARY_CHOICE and HERO_RECALL are stubbed for later.

const COMMITMENT_LABELS: Dictionary = {
	Enums.CommitmentLevel.AT_ANY_COST:    "At Any Cost",
	Enums.CommitmentLevel.USE_JUDGEMENT:  "Use Judgement",
	Enums.CommitmentLevel.COME_HOME_SAFE: "Come Home Safe",
}

var _data: InterventionData

## Store data before add_child() so _ready() can apply it.
func setup(data: InterventionData) -> void:
	_data = data

func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header_lbl := Label.new()
	header_lbl.text = "Intervention Available"
	vbox.add_child(header_lbl)

	var ctx_lbl := Label.new()
	ctx_lbl.text = _data.context_text
	ctx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ctx_lbl)

	var tokens: int = GuildManager.get_state().intervention_tokens
	var tokens_lbl := Label.new()
	tokens_lbl.text = "Tokens remaining: %d" % tokens
	vbox.add_child(tokens_lbl)

	vbox.add_child(HSeparator.new())

	match _data.intervention_type:
		InterventionData.Type.COMMITMENT_CHANGE:
			_build_commitment_buttons(vbox)
		InterventionData.Type.BINARY_CHOICE:
			_build_binary_choice_buttons(vbox)
		InterventionData.Type.HERO_RECALL:
			_build_hero_recall_buttons(vbox)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.pressed.connect(func() -> void:
		EventBus.intervention_dismissed.emit(_data.mission_id)
		queue_free()
	)
	vbox.add_child(dismiss_btn)

func _build_commitment_buttons(vbox: VBoxContainer) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	for i: int in _data.options.size():
		var level: int = _data.options[i]
		var btn := Button.new()
		btn.text = COMMITMENT_LABELS.get(level, str(level))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = (i == _data.current_option_index)
		var captured := level
		btn.pressed.connect(func() -> void: _on_commitment_chosen(captured))
		btn_row.add_child(btn)

func _build_binary_choice_buttons(_vbox: VBoxContainer) -> void:
	pass  # Stubbed — implement when BINARY_CHOICE intervention type is added.

func _build_hero_recall_buttons(_vbox: VBoxContainer) -> void:
	pass  # Stubbed — implement when HERO_RECALL intervention type is added.

func _on_commitment_chosen(level: int) -> void:
	EventBus.cmd_use_intervention.emit(_data.mission_id, level)
	queue_free()
