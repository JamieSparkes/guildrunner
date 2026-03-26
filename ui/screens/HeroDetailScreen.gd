extends Control
## Full hero stats, gear, relationships, history, and traits.
## Receives {"hero": HeroData} from UIManager.push_screen("hero_detail", ...).

var _hero: HeroData = null

func setup(data: Dictionary) -> void:
	_hero = data.get("hero", null)
	# UIManager calls add_child() then setup(), so _ready() has already run.
	# Build UI here once hero data is available.
	_build_ui()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_ui() -> void:
	if _hero == null:
		return

	# Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 600)
	centre.add_child(panel)

	var root_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		root_margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(root_margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = _hero.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func() -> void: EventBus.cmd_close_top_screen.emit())
	header.add_child(back_btn)

	vbox.add_child(HSeparator.new())

	# ── Identity row ──────────────────────────────────────────────────────────
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
	vbox.add_child(identity)

	# Portrait placeholder
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.color = Color(0.25, 0.20, 0.15)
	identity.add_child(portrait)

	var id_info := VBoxContainer.new()
	id_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(id_info)

	_add_row(id_info, "Archetype", Enums.HeroArchetype.keys()[_hero.archetype])
	_add_row(id_info, "Personality",
			Enums.PersonalityType.keys()[_hero.personality_type])
	var status_text: String = Enums.HeroStatus.keys()[_hero.status]
	if _hero.injury_recovery_days > 0:
		status_text += " (%d days)" % _hero.injury_recovery_days
	_add_row(id_info, "Status", status_text)
	if _hero.is_legendary:
		_add_row(id_info, "", "★ Legendary")

	if _hero.bio != "":
		var bio_lbl := Label.new()
		bio_lbl.text = _hero.bio
		bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bio_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(bio_lbl)

	if _hero.personality_blurb != "":
		var blurb := Label.new()
		blurb.text = '"' + _hero.personality_blurb + '"'
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(blurb)

	vbox.add_child(HSeparator.new())

	# ── Attributes ────────────────────────────────────────────────────────────
	var attr_title := Label.new()
	attr_title.text = "Attributes"
	vbox.add_child(attr_title)

	var attr_grid := GridContainer.new()
	attr_grid.columns = 2
	attr_grid.add_theme_constant_override("h_separation", 12)
	attr_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(attr_grid)

	_add_stat_bar(attr_grid, "Strength",    _hero.strength)
	_add_stat_bar(attr_grid, "Agility",     _hero.agility)
	_add_stat_bar(attr_grid, "Stealth",     _hero.stealth)
	_add_stat_bar(attr_grid, "Resilience",  _hero.resilience)
	_add_stat_bar(attr_grid, "Leadership",  _hero.leadership)
	_add_stat_bar(attr_grid, "Morale",      _hero.morale)

	vbox.add_child(HSeparator.new())

	# ── Gear ──────────────────────────────────────────────────────────────────
	var gear_title := Label.new()
	gear_title.text = "Equipment"
	vbox.add_child(gear_title)

	var gear_grid := GridContainer.new()
	gear_grid.columns = 2
	gear_grid.add_theme_constant_override("h_separation", 12)
	gear_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(gear_grid)

	_add_row(gear_grid, "Weapon",    _hero.equipped_weapon   if _hero.equipped_weapon   != "" else "—")
	_add_row(gear_grid, "Armour",    _hero.equipped_armour   if _hero.equipped_armour   != "" else "—")
	_add_row(gear_grid, "Accessory", _hero.equipped_accessory if _hero.equipped_accessory != "" else "—")

	vbox.add_child(HSeparator.new())

	# ── Bonds & Tensions ──────────────────────────────────────────────────────
	if not _hero.bonds.is_empty() or not _hero.tensions.is_empty():
		var rel_title := Label.new()
		rel_title.text = "Relationships"
		vbox.add_child(rel_title)

		for bond: HeroRelationship in _hero.bonds:
			var other := HeroManager.get_hero(bond.other_hero_id)
			var other_name := other.display_name if other != null else bond.other_hero_id
			_add_row(vbox, "Bond", "%s — %s" % [other_name, bond.flavour_text])

		for tension: HeroRelationship in _hero.tensions:
			var other := HeroManager.get_hero(tension.other_hero_id)
			var other_name := other.display_name if other != null else tension.other_hero_id
			_add_row(vbox, "Tension", "%s — %s" % [other_name, tension.flavour_text])

		vbox.add_child(HSeparator.new())

	# ── History ───────────────────────────────────────────────────────────────
	var hist_title := Label.new()
	hist_title.text = "History"
	vbox.add_child(hist_title)

	var hist_grid := GridContainer.new()
	hist_grid.columns = 2
	hist_grid.add_theme_constant_override("h_separation", 12)
	hist_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(hist_grid)

	_add_row(hist_grid, "Missions", str(_hero.missions_completed))
	_add_row(hist_grid, "Times Wounded", str(_hero.times_wounded))
	_add_row(hist_grid, "Kills", str(_hero.kills))
	_add_row(hist_grid, "Clean Stealth", str(_hero.stealth_missions_clean))

	# ── Traits ────────────────────────────────────────────────────────────────
	if not _hero.acquired_traits.is_empty():
		vbox.add_child(HSeparator.new())
		var trait_title := Label.new()
		trait_title.text = "Traits"
		vbox.add_child(trait_title)
		var trait_lbl := Label.new()
		trait_lbl.text = ", ".join(_hero.acquired_traits)
		trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(trait_lbl)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_row(parent: Node, key: String, value: String) -> void:
	var key_lbl := Label.new()
	key_lbl.text = key
	parent.add_child(key_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(val_lbl)

func _add_stat_bar(parent: GridContainer, label: String, value: float) -> void:
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(90, 0)
	parent.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Inline value label via HBoxContainer
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % int(value)
	val_lbl.custom_minimum_size = Vector2(32, 0)
	hbox.add_child(val_lbl)

	parent.add_child(hbox)
