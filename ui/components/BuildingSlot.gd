extends PanelContainer
## Displays a single building's status and provides a build/upgrade button.
## Call setup(building_id) to initialise.

signal build_requested(building_id: String)

const TIER_LABELS: Array[String] = ["Ruins", "Tier 1", "Tier 2"]

var _building_id: String = ""
var _name_lbl: Label
var _tier_lbl: Label
var _status_lbl: Label
var _effects_lbl: Label
var _build_btn: Button

func setup(building_id: String) -> void:
	_building_id = building_id
	if _name_lbl == null:
		return
	_refresh()

func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_name_lbl)

	_tier_lbl = Label.new()
	vbox.add_child(_tier_lbl)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_lbl)

	vbox.add_child(HSeparator.new())

	_effects_lbl = Label.new()
	_effects_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effects_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_effects_lbl)

	_build_btn = Button.new()
	_build_btn.pressed.connect(_on_build_pressed)
	vbox.add_child(_build_btn)

	if _building_id != "":
		_refresh()

	EventBus.upgrade_built.connect(func(_id: String, _t: int) -> void: _refresh())
	EventBus.building_construction_started.connect(
		func(_id: String, _t: int, _d: int) -> void: _refresh()
	)
	EventBus.gold_changed.connect(func(_d: int, _n: int) -> void: _refresh())
	EventBus.day_advanced.connect(func(_d: int) -> void: _refresh())

func _refresh() -> void:
	if _building_id == "":
		return
	var building: BuildingData = BuildingManager.get_building(_building_id)
	if building == null:
		return

	var state := GuildManager.get_state()
	var current_tier: int = state.building_tiers.get(_building_id, 0)
	var is_constructing: bool = BuildingManager.is_under_construction(_building_id)
	var at_max: bool = current_tier >= building.max_tier

	_name_lbl.text = building.display_name
	_tier_lbl.text = TIER_LABELS[current_tier] if current_tier < TIER_LABELS.size() else "Max"

	if is_constructing:
		var entry: Dictionary = BuildingManager.get_construction_entry(_building_id)
		var days_left: int = entry["completion_day"] - TimeManager.current_day
		_status_lbl.text = "Under construction — %d day%s remaining" % [
			days_left, "s" if days_left != 1 else ""
		]
		_build_btn.disabled = true
		_build_btn.text = "Building..."
	elif at_max:
		_status_lbl.text = "Fully upgraded"
		_build_btn.disabled = true
		_build_btn.text = "Max Tier"
	else:
		var target_tier := current_tier + 1
		var cost: int = building.build_costs_gold[target_tier - 1]
		var days: int = building.build_time_days[target_tier - 1]
		var can_afford: bool = state.gold >= cost
		_status_lbl.text = "%d gold · %d day%s" % [cost, days, "s" if days != 1 else ""]
		_build_btn.disabled = not can_afford
		_build_btn.text = "Build" if current_tier == 0 else "Upgrade"

	_effects_lbl.text = _effects_summary(building, current_tier)

func _effects_summary(building: BuildingData, current_tier: int) -> String:
	var effects: Array = building.tier1_effects if current_tier < 1 \
		else (building.tier2_effects if current_tier < 2 else building.tier2_effects)
	if current_tier == 0 and not building.tier1_effects.is_empty():
		effects = building.tier1_effects
	elif current_tier == 1 and not building.tier2_effects.is_empty():
		effects = building.tier2_effects
	else:
		return ""
	var lines: Array[String] = []
	for effect: Dictionary in effects:
		lines.append(_format_effect(effect))
	return "\n".join(lines)

func _format_effect(effect: Dictionary) -> String:
	var type: String = effect.get("type", "")
	var value = effect.get("value")
	match type:
		"max_roster_size":       return "Roster cap: %d" % value
		"intervention_tokens":   return "Intervention tokens: %d/day" % value
		"recovery_day_reduction": return "Recovery -%d day%s" % [value, "s" if value != 1 else ""]
		"morale_recovery_multiplier": return "Morale recovery ×%.1f" % value
		"siege_defense_bonus":   return "Siege defense +%d" % value
		"siege_casualty_reduction": return "Siege casualties −%d%%" % int(float(value) * 100)
		_:
			if type.begins_with("enable_"):
				return type.trim_prefix("enable_").replace("_", " ").capitalize()
			return "%s: %s" % [type.replace("_", " "), str(value)]

func _on_build_pressed() -> void:
	build_requested.emit(_building_id)
