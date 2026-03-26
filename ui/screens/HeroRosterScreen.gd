extends Control
## Displays all heroes with a status filter bar.
## Clicking "View" on any card opens HeroDetailScreen.

const PORTRAIT_CARD_SCENE := preload("res://ui/components/HeroPortraitCard.tscn")

# Filter: "" = show all; otherwise matches HeroStatus key string.
var _active_filter: String = ""
var _grid: GridContainer
var _filter_btns: Dictionary = {}  # { status_key: Button }

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_populate_grid()

func _build_ui() -> void:
	# Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	# Header
	var header_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		header_margin.add_theme_constant_override("margin_" + side, 10)
	outer.add_child(header_margin)

	var header := HBoxContainer.new()
	header_margin.add_child(header)

	var title := Label.new()
	title.text = "Hero Roster"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(UIManager.pop_screen)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# Status filter bar
	var filter_margin := MarginContainer.new()
	filter_margin.add_theme_constant_override("margin_left", 10)
	filter_margin.add_theme_constant_override("margin_right", 10)
	filter_margin.add_theme_constant_override("margin_top", 6)
	filter_margin.add_theme_constant_override("margin_bottom", 6)
	outer.add_child(filter_margin)

	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 6)
	filter_margin.add_child(filter_bar)

	_add_filter_btn(filter_bar, "All", "")
	for status_key: String in Enums.HeroStatus.keys():
		_add_filter_btn(filter_bar, _status_label(status_key), status_key)

	outer.add_child(HSeparator.new())

	# Scrollable grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var grid_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(grid_margin)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	grid_margin.add_child(_grid)

func _add_filter_btn(parent: HBoxContainer, label: String, status_key: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_pressed = (status_key == _active_filter)
	btn.pressed.connect(func() -> void: _on_filter_changed(status_key))
	parent.add_child(btn)
	_filter_btns[status_key] = btn

func _on_filter_changed(status_key: String) -> void:
	_active_filter = status_key
	# Update button visuals
	for key: String in _filter_btns:
		_filter_btns[key].button_pressed = (key == status_key)
	_populate_grid()

func _populate_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()

	var heroes: Array = HeroManager.get_all_heroes()
	for hero: HeroData in heroes:
		if _active_filter != "":
			var status_name: String = Enums.HeroStatus.keys()[hero.status]
			if status_name != _active_filter:
				continue
		var card: Node = PORTRAIT_CARD_SCENE.instantiate()
		card.setup(hero)
		card.hero_pressed.connect(_on_hero_pressed)
		_grid.add_child(card)

func _on_hero_pressed(hero: HeroData) -> void:
	UIManager.push_screen("hero_detail", {"hero": hero})

# Shorten status labels for the filter bar
func _status_label(status_key: String) -> String:
	match status_key:
		"AVAILABLE":  return "Available"
		"ON_MISSION": return "On Mission"
		"INJURED":    return "Injured"
		"RECOVERING": return "Recovering"
		"CAPTURED":   return "Captured"
		"DEAD":       return "Dead"
	return status_key
