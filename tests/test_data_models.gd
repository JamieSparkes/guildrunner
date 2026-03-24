## GUT tests for M1: Core Data Models and DataLoader.
## Requires the GUT plugin (install via Godot AssetLib or GitHub).
## Run with: godot --headless -s addons/gut/gut_cmdln.gd -d res://tests/
extends GutTest

# ── Enum Tests ────────────────────────────────────────────────────────────────

func test_hero_archetype_enum_values_are_distinct() -> void:
	var values := [
		Enums.HeroArchetype.FIGHTER,
		Enums.HeroArchetype.ROGUE,
		Enums.HeroArchetype.RANGER,
		Enums.HeroArchetype.SUPPORT,
	]
	# All values should be unique integers
	var seen := {}
	for v in values:
		assert_false(seen.has(v), "Duplicate enum value: %d" % v)
		seen[v] = true

func test_game_state_enum_has_all_states() -> void:
	# Verify all FSM states defined in TDD §2.1 exist
	assert_true(Enums.GameState.has("MAIN_MENU"))
	assert_true(Enums.GameState.has("GUILD_HUB"))
	assert_true(Enums.GameState.has("MORNING_PHASE"))
	assert_true(Enums.GameState.has("NIGHT_PHASE"))
	assert_true(Enums.GameState.has("MISSION_BRIEFING"))
	assert_true(Enums.GameState.has("MISSION_AUTO"))
	assert_true(Enums.GameState.has("SIEGE"))
	assert_true(Enums.GameState.has("MISSION_DIRECT"))
	assert_true(Enums.GameState.has("CUTSCENE"))
	assert_true(Enums.GameState.has("PAUSED"))

func test_rep_tier_labels_cover_all_tiers() -> void:
	for tier in Enums.RepTier.values():
		assert_true(Enums.REP_TIER_LABELS.has(tier),
			"REP_TIER_LABELS missing tier %d" % tier)

# ── HeroData Tests ────────────────────────────────────────────────────────────

func test_hero_data_instantiation_has_correct_defaults() -> void:
	var hero := HeroData.new()
	assert_eq(hero.status, Enums.HeroStatus.AVAILABLE)
	assert_eq(hero.morale, 80.0)
	assert_eq(hero.morale_floor, 20.0)
	assert_eq(hero.missions_completed, 0)
	assert_eq(hero.bonds.size(), 0)
	assert_eq(hero.tensions.size(), 0)
	assert_eq(hero.acquired_traits.size(), 0)

func test_hero_relationship_instantiation() -> void:
	var rel := HeroRelationship.new()
	rel.other_hero_id = "test_hero"
	rel.relationship_type = Enums.RelationshipType.BOND
	rel.morale_modifier = 5.0
	assert_eq(rel.other_hero_id, "test_hero")
	assert_eq(rel.relationship_type, Enums.RelationshipType.BOND)
	assert_eq(rel.morale_modifier, 5.0)

# ── ContractData Tests ────────────────────────────────────────────────────────

func test_contract_data_defaults() -> void:
	var contract := ContractData.new()
	assert_eq(contract.min_heroes, 1)
	assert_eq(contract.difficulty, 1)
	assert_false(contract.is_consequential)
	assert_eq(contract.rep_on_success, {})

func test_contract_skill_weights_can_be_set() -> void:
	var contract := ContractData.new()
	contract.weight_strength = 0.7
	contract.weight_stealth = 0.8
	assert_eq(contract.weight_strength, 0.7)
	assert_eq(contract.weight_stealth, 0.8)

# ── ItemData Tests ────────────────────────────────────────────────────────────

func test_item_data_defaults() -> void:
	var item := ItemData.new()
	assert_eq(item.rarity, Enums.ItemRarity.COMMON)
	assert_false(item.is_magical)
	assert_false(item.is_unique)
	assert_eq(item.max_durability, 10)
	assert_eq(item.current_durability, 10)

# ── FactionData Tests ─────────────────────────────────────────────────────────

func test_faction_data_thresholds_are_ordered() -> void:
	var fd := FactionData.new()
	fd.threshold_enemy   = -40
	fd.threshold_unknown = -15
	fd.threshold_neutral = 10
	fd.threshold_trusted = 50
	assert_lt(fd.threshold_enemy, fd.threshold_unknown)
	assert_lt(fd.threshold_unknown, fd.threshold_neutral)
	assert_lt(fd.threshold_neutral, fd.threshold_trusted)

# ── BuildingData Tests ────────────────────────────────────────────────────────

func test_building_data_has_two_tiers() -> void:
	var bd := BuildingData.new()
	bd.build_costs_gold = [150, 350]
	bd.build_time_days  = [3, 5]
	assert_eq(bd.build_costs_gold.size(), 2)
	assert_eq(bd.build_time_days.size(), 2)
	assert_gt(bd.build_costs_gold[1], bd.build_costs_gold[0],
		"Tier 2 should cost more than Tier 1")

# ── GuildState Tests ──────────────────────────────────────────────────────────

func test_guild_state_default_gold() -> void:
	var gs := GuildState.new()
	assert_eq(gs.gold, 200)
	assert_eq(gs.current_day, 1)
	assert_eq(gs.max_roster_size, 6)

# ── FeedEvent Tests ───────────────────────────────────────────────────────────

func test_feed_event_init() -> void:
	var ev := FeedEvent.new("mission_001", "Aldric advances.", "departure", false, 1)
	assert_eq(ev.mission_id, "mission_001")
	assert_eq(ev.text, "Aldric advances.")
	assert_eq(ev.event_key, "departure")
	assert_false(ev.is_illustrated)
	assert_eq(ev.day, 1)

# ── TraitData Tests ───────────────────────────────────────────────────────────

func test_trait_data_defaults() -> void:
	var td := TraitData.new()
	assert_eq(td.trigger, "")
	assert_eq(td.effects.size(), 0)

# ── DataLoader Tests ──────────────────────────────────────────────────────────

func test_data_loader_str_to_enum_valid_key() -> void:
	var val := DataLoader.str_to_enum(Enums.HeroArchetype, "FIGHTER")
	assert_eq(val, Enums.HeroArchetype.FIGHTER)

func test_data_loader_str_to_enum_invalid_key_returns_default() -> void:
	var val := DataLoader.str_to_enum(Enums.HeroArchetype, "INVALID_KEY", 99)
	assert_eq(val, 99)

func test_data_loader_loads_factions() -> void:
	var factions := DataLoader.load_factions()
	assert_eq(factions.size(), 5, "Expected 5 factions")
	assert_true(factions.has("crown"))
	assert_true(factions.has("church"))
	assert_true(factions.has("merchants"))
	assert_true(factions.has("underworld"))
	assert_true(factions.has("common_folk"))

func test_data_loader_faction_thresholds_are_valid() -> void:
	var factions := DataLoader.load_factions()
	for faction_id: String in factions:
		var fd: FactionData = factions[faction_id]
		assert_lt(fd.threshold_enemy, fd.threshold_unknown,
			"%s: enemy threshold must be below unknown" % faction_id)
		assert_lt(fd.threshold_unknown, fd.threshold_neutral,
			"%s: unknown threshold must be below neutral" % faction_id)
		assert_lt(fd.threshold_neutral, fd.threshold_trusted,
			"%s: neutral threshold must be below trusted" % faction_id)

func test_data_loader_loads_buildings() -> void:
	var buildings := DataLoader.load_buildings()
	assert_eq(buildings.size(), 6, "Expected 6 buildings")
	for id: String in ["barracks", "forge", "infirmary", "training_grounds", "tavern", "gatehouse"]:
		assert_true(buildings.has(id), "Missing building: " + id)

func test_data_loader_building_costs_are_non_zero() -> void:
	var buildings := DataLoader.load_buildings()
	for building_id: String in buildings:
		var bd: BuildingData = buildings[building_id]
		assert_eq(bd.build_costs_gold.size(), 2)
		assert_gt(bd.build_costs_gold[0], 0,
			"%s Tier 1 cost should be > 0" % building_id)

func test_data_loader_loads_contract_templates() -> void:
	var templates := DataLoader.load_contract_templates()
	assert_gte(templates.size(), 15, "Expected at least 15 contract templates")

func test_data_loader_contract_templates_cover_all_factions() -> void:
	var templates := DataLoader.load_contract_templates()
	var faction_ids_found := {}
	for contract_id: String in templates:
		var cd: ContractData = templates[contract_id]
		faction_ids_found[cd.client_faction_id] = true
	for faction_id: String in ["crown", "church", "merchants", "underworld", "common_folk"]:
		assert_true(faction_ids_found.has(faction_id),
			"No contracts for faction: " + faction_id)

func test_data_loader_loads_item_definitions() -> void:
	var items := DataLoader.load_item_definitions()
	assert_gte(items.size(), 10, "Expected at least 10 item definitions")

func test_data_loader_item_definitions_have_valid_types() -> void:
	var items := DataLoader.load_item_definitions()
	for item_id: String in items:
		var item: ItemData = items[item_id]
		assert_true(
			item.item_type in [Enums.ItemType.WEAPON, Enums.ItemType.ARMOUR, Enums.ItemType.ACCESSORY],
			"Item %s has invalid item_type" % item_id
		)

func test_data_loader_loads_starting_heroes() -> void:
	var heroes := DataLoader.load_starting_heroes()
	assert_eq(heroes.size(), 3, "Expected exactly 3 starting heroes")

func test_data_loader_starting_hero_ids_are_unique() -> void:
	var heroes := DataLoader.load_starting_heroes()
	var ids := {}
	for hero: HeroData in heroes:
		assert_false(ids.has(hero.hero_id), "Duplicate hero_id: " + hero.hero_id)
		ids[hero.hero_id] = true

func test_data_loader_starting_heroes_have_valid_archetypes() -> void:
	var heroes := DataLoader.load_starting_heroes()
	var archetypes_found := {}
	for hero: HeroData in heroes:
		archetypes_found[hero.archetype] = true
	# The three starters should have three different archetypes
	assert_eq(archetypes_found.size(), 3, "Starting heroes should have 3 different archetypes")

func test_data_loader_starting_heroes_attributes_in_range() -> void:
	var heroes := DataLoader.load_starting_heroes()
	for hero: HeroData in heroes:
		for attr: float in [hero.strength, hero.agility, hero.stealth, hero.resilience, hero.leadership]:
			assert_gte(attr, 0.0, "%s attribute below 0" % hero.display_name)
			assert_lte(attr, 100.0, "%s attribute above 100" % hero.display_name)

func test_data_loader_starting_heroes_relationships_reference_valid_ids() -> void:
	var heroes := DataLoader.load_starting_heroes()
	var all_ids := {}
	for hero: HeroData in heroes:
		all_ids[hero.hero_id] = true
	for hero: HeroData in heroes:
		for bond: HeroRelationship in hero.bonds:
			assert_true(all_ids.has(bond.other_hero_id),
				"%s bond references unknown hero: %s" % [hero.hero_id, bond.other_hero_id])
		for tension: HeroRelationship in hero.tensions:
			assert_true(all_ids.has(tension.other_hero_id),
				"%s tension references unknown hero: %s" % [hero.hero_id, tension.other_hero_id])

func test_data_loader_loads_hero_archetypes() -> void:
	var archetypes := DataLoader.load_hero_archetypes()
	assert_true(archetypes.has("FIGHTER"))
	assert_true(archetypes.has("ROGUE"))
	assert_true(archetypes.has("RANGER"))
	assert_true(archetypes.has("SUPPORT"))

func test_data_loader_hero_archetype_ranges_are_valid() -> void:
	var archetypes := DataLoader.load_hero_archetypes()
	for archetype_name: String in archetypes:
		var arch: Dictionary = archetypes[archetype_name]
		for stat: String in ["strength", "agility", "stealth", "resilience", "leadership"]:
			assert_true(arch.has(stat), "%s missing stat: %s" % [archetype_name, stat])
			var stat_range: Dictionary = arch[stat]
			assert_lt(stat_range["min"], stat_range["max"],
				"%s.%s: min must be < max" % [archetype_name, stat])
			assert_gte(stat_range["min"], 0)
			assert_lte(stat_range["max"], 100)
