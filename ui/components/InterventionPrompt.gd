extends PanelContainer
## Mid-mission commitment change prompt. Appears inline in the feed when an
## intervention trigger fires and the guild has tokens remaining.
## Call setup() before add_child().

const COMMITMENT_LABELS: Dictionary = {
	Enums.CommitmentLevel.AT_ANY_COST:    "At Any Cost",
	Enums.CommitmentLevel.USE_JUDGEMENT:  "Use Judgement",
	Enums.CommitmentLevel.COME_HOME_SAFE: "Come Home Safe",
}

var _mission_id: String = ""
var _context_text: String = ""

## Store data before add_child() so _ready() can apply it.
func setup(mission_id: String, context_text: String) -> void:
	_mission_id = mission_id
	_context_text = context_text

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
	ctx_lbl.text = _context_text
	ctx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ctx_lbl)

	var tokens: int = GuildManager.get_state().intervention_tokens
	var tokens_lbl := Label.new()
	tokens_lbl.text = "Tokens remaining: %d" % tokens
	vbox.add_child(tokens_lbl)

	vbox.add_child(HSeparator.new())

	# Commitment buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	var current_commitment := Enums.CommitmentLevel.USE_JUDGEMENT
	var mission := MissionManager.get_active_missions().filter(
		func(m) -> bool: return m.mission_id == _mission_id
	)
	if not mission.is_empty():
		current_commitment = mission[0].commitment

	for level: int in [
		Enums.CommitmentLevel.AT_ANY_COST,
		Enums.CommitmentLevel.USE_JUDGEMENT,
		Enums.CommitmentLevel.COME_HOME_SAFE,
	]:
		var btn := Button.new()
		btn.text = COMMITMENT_LABELS[level]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = (level == current_commitment)
		var captured := level
		btn.pressed.connect(func() -> void: _on_commitment_chosen(captured))
		btn_row.add_child(btn)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.pressed.connect(queue_free)
	vbox.add_child(dismiss_btn)

func _on_commitment_chosen(level: int) -> void:
	EventBus.cmd_use_intervention.emit(_mission_id, level)
	queue_free()
