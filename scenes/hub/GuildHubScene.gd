extends Control
## Main hub scene — entry point for the in-game loop.
## Shows building hotspots (placeholders) and a HUD bar.
## The player opens the Contract Board here, then advances the day.

const HUD_BAR_SCENE := preload("res://ui/HUDBar.tscn")

func _ready() -> void:
	_build_scene()
	# Seed the board on game start (day 1 morning)
	EventBus.morning_phase_started.emit(TimeManager.current_day)

func _build_scene() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.10, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer layout
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	# HUD bar
	var hud_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		hud_margin.add_theme_constant_override("margin_" + side, 8)
	outer.add_child(hud_margin)

	var hud := HUD_BAR_SCENE.instantiate()
	hud_margin.add_child(hud)

	outer.add_child(HSeparator.new())

	# Centre panel with building hotspots
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(centre)

	var hub_panel := VBoxContainer.new()
	hub_panel.custom_minimum_size = Vector2(360, 0)
	hub_panel.add_theme_constant_override("separation", 12)
	centre.add_child(hub_panel)

	var title := Label.new()
	title.text = "Guild Hub"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_panel.add_child(title)

	hub_panel.add_child(HSeparator.new())

	# Contract Board hotspot
	var board_btn := Button.new()
	board_btn.text = "Contract Board"
	board_btn.pressed.connect(_on_contract_board_pressed)
	hub_panel.add_child(board_btn)

	# Hero Roster
	var roster_btn := Button.new()
	roster_btn.text = "Hero Roster"
	roster_btn.pressed.connect(_on_hero_roster_pressed)
	hub_panel.add_child(roster_btn)

	# Mission Feed (shows once heroes have been dispatched)
	var feed_btn := Button.new()
	feed_btn.text = "Mission Feed"
	feed_btn.pressed.connect(_on_mission_feed_pressed)
	hub_panel.add_child(feed_btn)

	# Building buttons
	var building_labels: Dictionary = {
		"barracks":         "Barracks",
		"forge":            "Forge",
		"infirmary":        "Infirmary",
		"training_grounds": "Training Grounds",
		"tavern":           "Tavern",
		"gatehouse":        "Gatehouse",
	}
	for building_id: String in building_labels.keys():
		var btn := Button.new()
		btn.text = building_labels[building_id]
		btn.pressed.connect(func() -> void: EventBus.cmd_open_screen.emit("building", {"building_id": building_id}))
		hub_panel.add_child(btn)

	hub_panel.add_child(HSeparator.new())

	# Advance Day
	var advance_btn := Button.new()
	advance_btn.text = "Advance Day"
	advance_btn.pressed.connect(_on_advance_day_pressed)
	hub_panel.add_child(advance_btn)

func _on_contract_board_pressed() -> void:
	EventBus.cmd_open_screen.emit("contract_board", {})

func _on_hero_roster_pressed() -> void:
	EventBus.cmd_open_screen.emit("hero_roster", {})

func _on_mission_feed_pressed() -> void:
	EventBus.cmd_open_screen.emit("feed", {})

func _on_advance_day_pressed() -> void:
	EventBus.cmd_transition_state.emit(Enums.GameState.MORNING_PHASE)
