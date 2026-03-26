## Applies building effects from buildings.json to game state on construction completion.
## All methods are static — no autoload needed.
class_name BuildingEffectProcessor

## Apply all effects for the given building at the given tier.
static func apply_effects(building_id: String, tier: int, building_db: Dictionary) -> void:
	var building: BuildingData = building_db.get(building_id, null)
	if building == null:
		push_warning("BuildingEffectProcessor: unknown building '%s'" % building_id)
		return
	var effects: Array = building.tier1_effects if tier == 1 else building.tier2_effects
	for effect: Dictionary in effects:
		_apply_effect(effect)

static func _apply_effect(effect: Dictionary) -> void:
	var type: String = effect.get("type", "")
	var value = effect.get("value")
	var state := GuildManager.get_state()
	match type:
		"max_roster_size":
			state.max_roster_size = int(value)
		"intervention_tokens":
			GuildManager.set_max_intervention_tokens(int(value))
		"recovery_day_reduction":
			state.recovery_day_reduction = int(value)
		_:
			# Store future effects (enable_*, multipliers, siege bonuses) as flags.
			state.building_flags[type] = value
