extends Control
## Displays the mission auto-resolve feed.
## M6: single column showing all active feeds combined.
## M9 will expand to multiple per-mission columns (HBoxContainer of FeedColumns).

const FEED_COLUMN_SCENE := preload("res://ui/components/FeedColumn.tscn")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# Semi-transparent backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 560)
	centre.add_child(panel)

	var outer := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	outer.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Mission Feed"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(UIManager.pop_screen)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Feed column — shows all missions combined
	var column: Node = FEED_COLUMN_SCENE.instantiate()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(column)
	column.setup("")
	column.refresh()
