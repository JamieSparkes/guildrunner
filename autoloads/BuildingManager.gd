extends Node
## Manages building construction, upgrades, and the construction queue.
## Applies building effects on completion via BuildingEffectProcessor.

var _building_db: Dictionary = {}  # { building_id: BuildingData }

func _ready() -> void:
	_building_db = DataLoader.load_buildings()
	EventBus.day_advanced.connect(_on_day_advanced)

# ── Public API ────────────────────────────────────────────────────────────────

## Attempt to begin construction/upgrade of a building.
## Returns false if: unknown building, already at max tier, already queued, or insufficient gold.
func begin_construction(building_id: String) -> bool:
	var building: BuildingData = _building_db.get(building_id, null)
	if building == null:
		push_warning("BuildingManager: unknown building '%s'" % building_id)
		return false

	var state := GuildManager.get_state()
	var current_tier: int = state.building_tiers.get(building_id, 0)
	var target_tier := current_tier + 1

	if target_tier > building.max_tier:
		push_warning("BuildingManager: '%s' is already at max tier" % building_id)
		return false

	for entry: Dictionary in state.buildings_under_construction:
		if entry["building_id"] == building_id:
			push_warning("BuildingManager: '%s' already under construction" % building_id)
			return false

	var cost: int = building.build_costs_gold[target_tier - 1]
	if not GuildManager.deduct_gold(cost):
		return false

	var completion_day: int = TimeManager.current_day + building.build_time_days[target_tier - 1]
	state.buildings_under_construction.append({
		"building_id": building_id,
		"target_tier": target_tier,
		"completion_day": completion_day,
	})
	EventBus.building_construction_started.emit(building_id, target_tier, completion_day)
	return true

## Return the BuildingData for a building, or null if unknown.
func get_building(building_id: String) -> BuildingData:
	return _building_db.get(building_id, null)

## Return all BuildingData instances.
func get_all_buildings() -> Dictionary:
	return _building_db

## Return the construction queue entry for a building, or null if not queued.
func get_construction_entry(building_id: String) -> Dictionary:
	for entry: Dictionary in GuildManager.get_state().buildings_under_construction:
		if entry["building_id"] == building_id:
			return entry
	return {}

## True if the building is currently under construction.
func is_under_construction(building_id: String) -> bool:
	return not get_construction_entry(building_id).is_empty()

## Current tier for a building (0 = ruins).
func get_tier(building_id: String) -> int:
	return GuildManager.get_state().building_tiers.get(building_id, 0)

# ── Day tick ──────────────────────────────────────────────────────────────────

func _on_day_advanced(day: int) -> void:
	var state := GuildManager.get_state()
	# Collect completed entries first to avoid mutation during iteration.
	var completed: Array = []
	for entry: Dictionary in state.buildings_under_construction:
		if day >= entry["completion_day"]:
			completed.append(entry)
	for entry: Dictionary in completed:
		state.buildings_under_construction.erase(entry)
		_complete_construction(entry["building_id"], entry["target_tier"])

func _complete_construction(building_id: String, tier: int) -> void:
	var state := GuildManager.get_state()
	state.building_tiers[building_id] = tier
	BuildingEffectProcessor.apply_effects(building_id, tier, _building_db)
	EventBus.upgrade_built.emit(building_id, tier)

# ── Test helpers ──────────────────────────────────────────────────────────────

func _reset_for_test() -> void:
	var state := GuildManager.get_state()
	for key: String in state.building_tiers.keys():
		state.building_tiers[key] = 0
	state.buildings_under_construction.clear()
	state.recovery_day_reduction = 0
	state.building_flags.clear()
