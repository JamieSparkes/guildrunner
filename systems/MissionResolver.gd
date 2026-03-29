## Pure mission outcome resolution logic. No state, no Node — all static functions.
## Implements TDD §4.1.1 exactly.
class_name MissionResolver

# ── Commitment score multipliers ──────────────────────────────────────────────

const COMMITMENT_MULTIPLIER: Dictionary = {
	Enums.CommitmentLevel.AT_ANY_COST:    1.25,
	Enums.CommitmentLevel.USE_JUDGEMENT:  1.0,
	Enums.CommitmentLevel.COME_HOME_SAFE: 0.75,
}

# ── Public API ────────────────────────────────────────────────────────────────

## Resolve a mission and return the outcome.
## item_db: Dictionary[item_id: String → ItemData] — pass DataLoader.load_item_definitions()
##          or an empty dict to skip item bonuses (tests without item data).
static func resolve_mission(
	contract: ContractData,
	squad: Array[HeroData],
	commitment: Enums.CommitmentLevel,
	item_db: Dictionary = {}
) -> Enums.MissionResult:
	assert(squad.size() > 0, "MissionResolver: squad must not be empty")

	var score := 0.0
	for hero: HeroData in squad:
		score += _hero_score(hero, contract, item_db)

	# Leadership bonus for multi-hero squads
	if squad.size() > 1:
		var leader := _highest_leadership(squad)
		score += leader.leadership * contract.weight_leadership * 0.5

	# Bond/tension modifiers
	score += RelationshipModifier.get_score_modifier(squad)

	# Average across squad
	score /= float(squad.size())

	# Commitment modifier
	score *= COMMITMENT_MULTIPLIER[commitment]

	# Noise roll
	var roll := score + randf_range(-25.0, 25.0)

	# Threshold based on difficulty (1→40, 2→50, 3→60, 4→70, 5→80)
	var threshold := 40.0 + float(contract.difficulty - 1) * 10.0

	if roll >= threshold + 20.0:
		return Enums.MissionResult.FULL_SUCCESS
	if roll >= threshold:
		return Enums.MissionResult.SUCCESS
	if roll >= threshold - 15.0:
		return Enums.MissionResult.PARTIAL
	return Enums.MissionResult.FAILURE

## Deterministic version for testing — caller provides an explicit roll value instead of RNG.
static func resolve_mission_with_roll(
	contract: ContractData,
	squad: Array[HeroData],
	commitment: Enums.CommitmentLevel,
	explicit_roll_offset: float,
	item_db: Dictionary = {}
) -> Enums.MissionResult:
	assert(squad.size() > 0)

	var score := 0.0
	for hero: HeroData in squad:
		score += _hero_score(hero, contract, item_db)

	if squad.size() > 1:
		var leader := _highest_leadership(squad)
		score += leader.leadership * contract.weight_leadership * 0.5

	score += RelationshipModifier.get_score_modifier(squad)
	score /= float(squad.size())
	score *= COMMITMENT_MULTIPLIER[commitment]

	var roll := score + explicit_roll_offset
	var threshold := 40.0 + float(contract.difficulty - 1) * 10.0

	if roll >= threshold + 20.0:
		return Enums.MissionResult.FULL_SUCCESS
	if roll >= threshold:
		return Enums.MissionResult.SUCCESS
	if roll >= threshold - 15.0:
		return Enums.MissionResult.PARTIAL
	return Enums.MissionResult.FAILURE

## Compute a hero's raw weighted score for a contract (before squad averaging).
## Exposed for tests and UI score previews.
static func hero_score(hero: HeroData, contract: ContractData, item_db: Dictionary = {}) -> float:
	return _hero_score(hero, contract, item_db)

## Calculate the mathematical probability (0.0 to 1.0) of getting a SUCCESS or better.
## Useful for UI previews before dispatching.
static func calculate_success_chance(
	contract: ContractData,
	squad: Array[HeroData],
	commitment: Enums.CommitmentLevel,
	item_db: Dictionary = {}
) -> float:
	if squad.is_empty():
		return 0.0

	var score := 0.0
	for hero: HeroData in squad:
		score += _hero_score(hero, contract, item_db)

	if squad.size() > 1:
		var leader := _highest_leadership(squad)
		score += leader.leadership * contract.weight_leadership * 0.5

	score += RelationshipModifier.get_score_modifier(squad)
	score /= float(squad.size())
	score *= COMMITMENT_MULTIPLIER[commitment]

	var threshold := 40.0 + float(contract.difficulty - 1) * 10.0
	
	# roll = score + randf_range(-25.0, 25.0)
	# We want P(roll >= threshold) = P(score + rand >= threshold)
	# rand is uniform on [-25, 25].
	var diff := threshold - score
	return clamp((25.0 - diff) / 50.0, 0.0, 1.0)

# ── Internal ──────────────────────────────────────────────────────────────────

static func _hero_score(hero: HeroData, contract: ContractData, item_db: Dictionary) -> float:
	var s := 0.0
	s += hero.strength   * contract.weight_strength
	s += hero.agility    * contract.weight_agility
	s += hero.stealth    * contract.weight_stealth
	s += hero.resilience * contract.weight_resilience
	s += _item_bonus(hero, contract, item_db)
	# Trait bonus deferred to M14
	return s

static func _item_bonus(hero: HeroData, contract: ContractData, item_db: Dictionary) -> float:
	if item_db.is_empty():
		return 0.0
	var bonus := 0.0
	for item_id: String in [hero.equipped_weapon, hero.equipped_armour, hero.equipped_accessory]:
		if item_id.is_empty() or not item_db.has(item_id):
			continue
		var item: ItemData = item_db[item_id]
		bonus += item.mod_strength   * contract.weight_strength
		bonus += item.mod_agility    * contract.weight_agility
		bonus += item.mod_stealth    * contract.weight_stealth
		bonus += item.mod_resilience * contract.weight_resilience
	return bonus

static func _highest_leadership(squad: Array[HeroData]) -> HeroData:
	var best: HeroData = squad[0]
	for hero: HeroData in squad:
		if hero.leadership > best.leadership:
			best = hero
	return best
