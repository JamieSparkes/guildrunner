extends Control
## Game entry point. New Game bootstraps all systems and transitions to the hub.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.add_theme_constant_override("separation", 16)
	centre.add_child(vbox)

	var title := Label.new()
	title.text = "Guildrunner"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A guild management story"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var new_game_btn := Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

func _on_new_game_pressed() -> void:
	EventBus.cmd_start_new_game.emit()
