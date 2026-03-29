extends GutTest

func _make_hero(id: String, str_v: float, lead: float) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.strength = str_v
	h.leadership = lead
	return h

func _make_contract(difficulty: int, ws: float, wl: float) -> ContractData:
	var c := ContractData.new()
	c.difficulty = difficulty
	c.weight_strength = ws
	c.weight_leadership = wl
	# Set others to 0 to make math simple
	c.weight_agility = 0.0
	c.weight_stealth = 0.0
	c.weight_resilience = 0.0
	return c

func test_success_chance_basic() -> void:
	# Difficulty 1 threshold = 40.0
	var hero := _make_hero("h1", 40.0, 0.0)
	var contract := _make_contract(1, 1.0, 0.0)
	
	# score = 40.0 * 1.0 = 40.0
	# diff = 40.0 - 40.0 = 0
	# chance = (25.0 - 0) / 50.0 = 0.5
	var chance := MissionResolver.calculate_success_chance(contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_almost_eq(chance, 0.5, 0.01, "40 score vs 40 threshold should be 50%")

func test_success_chance_high_score() -> void:
	# Difficulty 1 threshold = 40.0
	var hero := _make_hero("h1", 65.0, 0.0)
	var contract := _make_contract(1, 1.0, 0.0)
	
	# score = 65.0
	# diff = 40.0 - 65.0 = -25.0
	# chance = (25.0 - (-25.0)) / 50.0 = 50.0 / 50.0 = 1.0
	var chance := MissionResolver.calculate_success_chance(contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_almost_eq(chance, 1.0, 0.01, "65 score vs 40 threshold should be 100%")

func test_success_chance_low_score() -> void:
	# Difficulty 1 threshold = 40.0
	var hero := _make_hero("h1", 15.0, 0.0)
	var contract := _make_contract(1, 1.0, 0.0)
	
	# score = 15.0
	# diff = 40.0 - 15.0 = 25.0
	# chance = (25.0 - 25.0) / 50.0 = 0.0
	var chance := MissionResolver.calculate_success_chance(contract, [hero], Enums.CommitmentLevel.USE_JUDGEMENT)
	assert_almost_eq(chance, 0.0, 0.01, "15 score vs 40 threshold should be 0%")

func test_success_chance_commitment_at_any_cost() -> void:
	# Difficulty 1 threshold = 40.0
	var hero := _make_hero("h1", 32.0, 0.0)
	var contract := _make_contract(1, 1.0, 0.0)
	
	# score = 32.0 * 1.25 = 40.0
	# diff = 40.0 - 40.0 = 0
	# chance = 0.5
	var chance := MissionResolver.calculate_success_chance(contract, [hero], Enums.CommitmentLevel.AT_ANY_COST)
	assert_almost_eq(chance, 0.5, 0.01, "32 score with 1.25 multiplier vs 40 threshold should be 50%")
