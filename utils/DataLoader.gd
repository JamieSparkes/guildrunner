## Static utility for loading JSON data files into typed Resource instances.
## Called by autoloads on _ready() to populate their in-memory databases.
class_name DataLoader

# ── JSON I/O ──────────────────────────────────────────────────────────────────

## Returns parsed JSON data (Array or Dictionary) from a res:// path, or null on error.
static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open '%s' — error %d" % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("DataLoader: JSON parse error in '%s'" % path)
		return null
	return result

# ── Enum Helpers ──────────────────────────────────────────────────────────────

## Converts a string enum key to its integer value using the provided enum dict.
## Returns default_val if the key is not found.
static func str_to_enum(enum_dict: Dictionary, key: String, default_val: int = 0) -> int:
	if enum_dict.has(key):
		return enum_dict[key]
	push_warning("DataLoader: unknown enum key '%s'" % key)
	return default_val

# ── Faction Loader ────────────────────────────────────────────────────────────

## Loads all FactionData from res://data/world/factions.json.
## Returns a Dictionary keyed by faction_id.
static func load_factions() -> Dictionary:
	var raw: Variant = load_json("res://data/world/factions.json")
	if raw == null or not raw is Array:
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in raw:
		var fd := FactionData.new()
		fd.faction_id                = entry.get("faction_id", "")
		fd.display_name              = entry.get("display_name", "")
		fd.faction_type              = str_to_enum(Enums.FactionType, entry.get("faction_type", "CROWN"))
		fd.threshold_enemy           = entry.get("threshold_enemy", -40)
		fd.threshold_unknown         = entry.get("threshold_unknown", -15)
		fd.threshold_neutral         = entry.get("threshold_neutral", 10)
		fd.threshold_trusted         = entry.get("threshold_trusted", 50)
		fd.siege_aid_at_tier         = str_to_enum(Enums.RepTier, entry.get("siege_aid_at_tier", "TRUSTED"))
		fd.siege_force_strength      = entry.get("siege_force_strength", 0)
		fd.contract_pool.assign(entry.get("contract_pool", []))
		fd.description               = entry.get("description", "")
		fd.hostile_action_description = entry.get("hostile_action_description", "")
		result[fd.faction_id] = fd
	return result

# ── Building Loader ───────────────────────────────────────────────────────────

## Loads all BuildingData from res://data/buildings/buildings.json.
## Returns a Dictionary keyed by building_id.
static func load_buildings() -> Dictionary:
	var raw: Variant = load_json("res://data/buildings/buildings.json")
	if raw == null or not raw is Array:
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in raw:
		var bd := BuildingData.new()
		bd.building_id     = entry.get("building_id", "")
		bd.display_name    = entry.get("display_name", "")
		bd.current_tier    = entry.get("current_tier", 0)
		bd.max_tier        = entry.get("max_tier", 2)
		bd.build_costs_gold.assign(entry.get("build_costs_gold", []))
		bd.build_time_days.assign(entry.get("build_time_days", []))
		bd.sprite_ids.assign(entry.get("sprite_ids", []))
		var pos: Array = entry.get("hub_position", [0, 0])
		bd.hub_position     = Vector2(pos[0], pos[1])
		bd.tier1_effects.assign(entry.get("tier1_effects", []))
		bd.tier2_effects.assign(entry.get("tier2_effects", []))
		result[bd.building_id] = bd
	return result

# ── Contract Template Loader ──────────────────────────────────────────────────

## Loads contract templates from res://data/contracts/contract_templates.json.
## Returns a Dictionary keyed by contract_id (template id).
static func load_contract_templates() -> Dictionary:
	var raw: Variant = load_json("res://data/contracts/contract_templates.json")
	if raw == null or not raw is Array:
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in raw:
		var cd := _contract_from_dict(entry)
		result[cd.contract_id] = cd
	return result

static func _contract_from_dict(entry: Dictionary) -> ContractData:
	var cd := ContractData.new()
	cd.contract_id          = entry.get("contract_id", "")
	cd.title                = entry.get("title", "")
	cd.description          = entry.get("description", "")
	cd.client_faction_id    = entry.get("client_faction_id", "")
	cd.client_name          = entry.get("client_name", "")
	cd.is_consequential     = entry.get("is_consequential", false)
	cd.is_quest_chain       = entry.get("is_quest_chain", false)
	cd.quest_chain_id       = entry.get("quest_chain_id", "")
	cd.chain_step           = entry.get("chain_step", 0)
	cd.delivery_type        = str_to_enum(Enums.DeliveryType, entry.get("delivery_type", "NOTICEBOARD"))
	cd.mission_type         = str_to_enum(Enums.MissionType, entry.get("mission_type", "ELIMINATE"))
	cd.difficulty           = entry.get("difficulty", 1)
	cd.min_heroes           = entry.get("min_heroes", 1)
	cd.recommended_heroes   = entry.get("recommended_heroes", 1)
	cd.weight_strength      = entry.get("weight_strength", 0.0)
	cd.weight_agility       = entry.get("weight_agility", 0.0)
	cd.weight_stealth       = entry.get("weight_stealth", 0.0)
	cd.weight_resilience    = entry.get("weight_resilience", 0.0)
	cd.weight_leadership    = entry.get("weight_leadership", 0.0)
	cd.base_duration_days   = entry.get("base_duration_days", 1)
	cd.distance_days        = entry.get("distance_days", 0)
	cd.reward_gold          = entry.get("reward_gold", 0)
	cd.reward_gold_partial  = entry.get("reward_gold_partial", 0)
	cd.reward_item_ids.assign(entry.get("reward_item_ids", []))
	cd.rep_on_success       = entry.get("rep_on_success", {})
	cd.rep_on_failure       = entry.get("rep_on_failure", {})
	cd.rep_on_expiry        = entry.get("rep_on_expiry", {})
	cd.consequence_on_failure = entry.get("consequence_on_failure", "")
	cd.available_from_day   = entry.get("available_from_day", 1)
	cd.expiry_day           = entry.get("expiry_day", 999)
	return cd

# ── Item Loader ───────────────────────────────────────────────────────────────

## Loads item definitions from res://data/items/items.json.
## Returns a Dictionary keyed by item_id. These are definition templates;
## instances get unique instance_ids at runtime.
static func load_item_definitions() -> Dictionary:
	var raw: Variant = load_json("res://data/items/items.json")
	if raw == null or not raw is Array:
		return {}
	var result: Dictionary = {}
	for entry: Dictionary in raw:
		var id := ItemData.new()
		id.item_id          = entry.get("item_id", "")
		id.display_name     = entry.get("display_name", "")
		id.item_type        = str_to_enum(Enums.ItemType, entry.get("item_type", "WEAPON"))
		id.rarity           = str_to_enum(Enums.ItemRarity, entry.get("rarity", "COMMON"))
		id.is_magical       = entry.get("is_magical", false)
		id.mod_strength     = entry.get("mod_strength", 0.0)
		id.mod_agility      = entry.get("mod_agility", 0.0)
		id.mod_stealth      = entry.get("mod_stealth", 0.0)
		id.mod_resilience   = entry.get("mod_resilience", 0.0)
		id.max_durability   = entry.get("max_durability", 10)
		id.current_durability = entry.get("current_durability", id.max_durability)
		id.passive_effect_id = entry.get("passive_effect_id", "")
		id.is_unique        = entry.get("is_unique", false)
		id.lore_text        = entry.get("lore_text", "")
		result[id.item_id] = id
	return result

# ── Hero Loaders ──────────────────────────────────────────────────────────────

## Loads the three hand-authored starting heroes.
## Returns an Array[HeroData].
static func load_starting_heroes() -> Array[HeroData]:
	var raw: Variant = load_json("res://data/heroes/starting_heroes.json")
	if raw == null or not raw is Array:
		return []
	var result: Array[HeroData] = []
	for entry: Dictionary in raw:
		result.append(_hero_from_dict(entry))
	return result

static func _hero_from_dict(entry: Dictionary) -> HeroData:
	var hd := HeroData.new()
	hd.hero_id           = entry.get("hero_id", "")
	hd.display_name      = entry.get("display_name", "")
	hd.archetype         = str_to_enum(Enums.HeroArchetype, entry.get("archetype", "FIGHTER"))
	hd.is_legendary      = entry.get("is_legendary", false)
	hd.portrait_id       = entry.get("portrait_id", "")
	hd.bio               = entry.get("bio", "")
	hd.personality_type  = str_to_enum(Enums.PersonalityType, entry.get("personality_type", "STOIC"))
	hd.personality_blurb = entry.get("personality_blurb", "")
	hd.strength          = entry.get("strength", 50.0)
	hd.agility           = entry.get("agility", 50.0)
	hd.stealth           = entry.get("stealth", 50.0)
	hd.resilience        = entry.get("resilience", 50.0)
	hd.leadership        = entry.get("leadership", 50.0)
	hd.morale            = entry.get("morale", 80.0)
	hd.morale_floor      = entry.get("morale_floor", 20.0)
	hd.status            = str_to_enum(Enums.HeroStatus, entry.get("status", "AVAILABLE"))
	hd.equipped_weapon   = entry.get("equipped_weapon", "")
	hd.equipped_armour   = entry.get("equipped_armour", "")
	hd.equipped_accessory = entry.get("equipped_accessory", "")
	hd.dialogue_pool_id  = entry.get("dialogue_pool_id", "")
	# Relationships
	for bond_dict: Dictionary in entry.get("bonds", []):
		var rel := HeroRelationship.new()
		rel.other_hero_id       = bond_dict.get("other_hero_id", "")
		rel.relationship_type   = Enums.RelationshipType.BOND
		rel.flavour_text        = bond_dict.get("flavour_text", "")
		rel.morale_modifier     = bond_dict.get("morale_modifier", 5.0)
		rel.performance_modifier = bond_dict.get("performance_modifier", 2.0)
		hd.bonds.append(rel)
	for tension_dict: Dictionary in entry.get("tensions", []):
		var rel := HeroRelationship.new()
		rel.other_hero_id       = tension_dict.get("other_hero_id", "")
		rel.relationship_type   = Enums.RelationshipType.TENSION
		rel.flavour_text        = tension_dict.get("flavour_text", "")
		rel.morale_modifier     = tension_dict.get("morale_modifier", -5.0)
		rel.performance_modifier = tension_dict.get("performance_modifier", -2.0)
		hd.tensions.append(rel)
	return hd

## Loads archetype attribute ranges from hero_archetypes.json.
## Returns a Dictionary keyed by archetype name string.
static func load_hero_archetypes() -> Dictionary:
	var raw: Variant = load_json("res://data/heroes/hero_archetypes.json")
	if raw == null or not raw is Dictionary:
		return {}
	return raw
