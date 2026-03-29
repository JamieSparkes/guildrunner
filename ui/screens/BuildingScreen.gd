extends Control
## Building management overview (M10). Shows all 6 buildings with tier, status, and upgrade buttons.

const BUILDING_SLOT_SCENE := preload("res://ui/components/BuildingSlot.tscn")

const BUILDING_ORDER: Array[String] = [
	"barracks", "forge", "infirmary",
	"training_grounds", "tavern", "gatehouse",
]

var _gold_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.building_construction_result.connect(_on_building_construction_result)
	EventBus.gold_changed.connect(_on_gold_changed)
	_build_ui()

func _exit_tree() -> void:
	if EventBus.building_construction_result.is_connected(_on_building_construction_result):
		EventBus.building_construction_result.disconnect(_on_building_construction_result)
	if EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.disconnect(_on_gold_changed)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
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
	title.text = "Buildings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_gold_lbl = Label.new()
	_gold_lbl.text = "Gold: %d" % GuildManager.get_state().gold
	header.add_child(_gold_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: EventBus.cmd_close_top_screen.emit())
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# Scrollable grid of building slots
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	# Margin around the grid
	var grid_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(grid_margin)

	var inner_grid := GridContainer.new()
	inner_grid.columns = 3
	inner_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_grid.add_theme_constant_override("h_separation", 8)
	inner_grid.add_theme_constant_override("v_separation", 8)
	grid_margin.add_child(inner_grid)

	for building_id: String in BUILDING_ORDER:
		var slot: Node = BUILDING_SLOT_SCENE.instantiate()
		inner_grid.add_child(slot)
		slot.setup(building_id)
		slot.build_requested.connect(_on_build_requested)

func _on_build_requested(building_id: String) -> void:
	EventBus.cmd_begin_construction.emit(building_id)

func _on_building_construction_result(building_id: String, success: bool, error: String) -> void:
	if success:
		return
	push_warning("BuildingScreen: construction failed for '%s' (%s)" % [building_id, error])

func _on_gold_changed(_delta: int, new_total: int) -> void:
	if _gold_lbl != null and is_instance_valid(_gold_lbl):
		_gold_lbl.text = "Gold: %d" % new_total
