extends HBoxContainer
## HUD bar displayed at the top of the hub: gold, day, hero availability.
## Subscribes to EventBus signals to stay current without polling.

var _gold_label: Label
var _day_label: Label
var _hero_label: Label

func _ready() -> void:
	_build_ui()
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.hero_dispatched.connect(func(_a: String, _b: String) -> void: _refresh_heroes())
	EventBus.hero_returned.connect(func(_a: String, _b: int) -> void: _refresh_heroes())
	_refresh_all()

func _build_ui() -> void:
	add_theme_constant_override("separation", 20)

	_gold_label = Label.new()
	add_child(_gold_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	_day_label = Label.new()
	add_child(_day_label)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer2)

	_hero_label = Label.new()
	add_child(_hero_label)

func _refresh_all() -> void:
	var state := GuildManager.get_state()
	_gold_label.text = "Gold: %d" % state.gold
	_day_label.text = "Day %d" % TimeManager.current_day
	_refresh_heroes()

func _on_gold_changed(_delta: int, new_total: int) -> void:
	_gold_label.text = "Gold: %d" % new_total

func _on_day_advanced(day: int) -> void:
	_day_label.text = "Day %d" % day

func _refresh_heroes() -> void:
	var available := HeroManager.get_available_heroes().size()
	var total := HeroManager.get_all_heroes().size()
	_hero_label.text = "Heroes: %d / %d" % [available, total]
