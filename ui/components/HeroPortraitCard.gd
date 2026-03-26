extends PanelContainer
## Selectable hero card used in MissionBriefingScreen and HeroRosterScreen.
## hero_toggled — selection toggle used by MissionBriefingScreen.
## hero_pressed — fired by the "View" button; used by HeroRosterScreen to open detail.

signal hero_toggled(hero: HeroData, selected: bool)
signal hero_pressed(hero: HeroData)

var _hero: HeroData
var _name_lbl: Label
var _archetype_lbl: Label
var _status_lbl: Label
var _toggle_btn: Button

func setup(hero: HeroData) -> void:
	_hero = hero
	if is_inside_tree():
		_update_display()

func _ready() -> void:
	_build_ui()
	if _hero != null:
		_update_display()

func _build_ui() -> void:
	custom_minimum_size = Vector2(140, 140)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	_name_lbl = Label.new()
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_name_lbl)

	_archetype_lbl = Label.new()
	_archetype_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_archetype_lbl)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_lbl)

	_toggle_btn = Button.new()
	_toggle_btn.text = "Select"
	_toggle_btn.toggle_mode = true
	_toggle_btn.toggled.connect(_on_toggled)
	vbox.add_child(_toggle_btn)

	var view_btn := Button.new()
	view_btn.text = "View"
	view_btn.pressed.connect(func() -> void: hero_pressed.emit(_hero))
	vbox.add_child(view_btn)

func _update_display() -> void:
	_name_lbl.text = _hero.display_name
	_archetype_lbl.text = Enums.HeroArchetype.keys()[_hero.archetype]
	_status_lbl.text = Enums.HeroStatus.keys()[_hero.status]
	var available := (_hero.status == Enums.HeroStatus.AVAILABLE)
	_toggle_btn.disabled = not available
	if not available:
		_toggle_btn.button_pressed = false

func is_selected() -> bool:
	return _toggle_btn != null \
		and _toggle_btn.button_pressed \
		and _hero != null \
		and _hero.status == Enums.HeroStatus.AVAILABLE

func _on_toggled(pressed: bool) -> void:
	hero_toggled.emit(_hero, pressed)
