## Computes bond/tension effects on mission scores and hero morale.
## All static — no state.
class_name RelationshipModifier

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the total performance_modifier delta to apply to the squad's
## aggregate score, based on all bond/tension pairs present in the squad.
static func get_score_modifier(squad: Array[HeroData]) -> float:
	var total := 0.0
	for i: int in range(squad.size()):
		for j: int in range(i + 1, squad.size()):
			total += _pair_performance_modifier(squad[i], squad[j])
	return total

## Returns the morale modifier a specific hero experiences from the rest of
## the squad (sum of morale_modifier on matching bonds/tensions).
static func get_morale_modifier(hero: HeroData, squad: Array[HeroData]) -> float:
	var total := 0.0
	for other: HeroData in squad:
		if other.hero_id == hero.hero_id:
			continue
		total += _hero_morale_modifier(hero, other.hero_id)
	return total

# ── Internal ──────────────────────────────────────────────────────────────────

## Sum performance_modifier for the bond/tension between hero_a and hero_b.
## Checks hero_a's relationships for references to hero_b (one-directional lookup).
static func _pair_performance_modifier(hero_a: HeroData, hero_b: HeroData) -> float:
	var total := 0.0
	for rel: HeroRelationship in hero_a.bonds:
		if rel.other_hero_id == hero_b.hero_id:
			total += rel.performance_modifier
	for rel: HeroRelationship in hero_a.tensions:
		if rel.other_hero_id == hero_b.hero_id:
			total += rel.performance_modifier
	return total

static func _hero_morale_modifier(hero: HeroData, other_id: String) -> float:
	var total := 0.0
	for rel: HeroRelationship in hero.bonds:
		if rel.other_hero_id == other_id:
			total += rel.morale_modifier
	for rel: HeroRelationship in hero.tensions:
		if rel.other_hero_id == other_id:
			total += rel.morale_modifier
	return total
