## Injury, death, and capture resolution. All static — no state.
## Implements TDD §4.1.2 exactly.
class_name InjuryResolver

# ── Base injury chance per difficulty (index 0 = difficulty 1) ───────────────
const BASE_INJURY_CHANCE: Array = [0.05, 0.10, 0.18, 0.28, 0.40]

# Severity distribution weights: [MINOR, SERIOUS, CRITICAL]
const SEVERITY_WEIGHTS: Array = [0.60, 0.30, 0.10]

# Recovery days per severity (used by HeroManager.apply_injury)
const RECOVERY_DAYS: Dictionary = {
	Enums.InjurySeverity.MINOR:    2,
	Enums.InjurySeverity.SERIOUS:  4,   # 3–5; use 4 as base
	Enums.InjurySeverity.CRITICAL: 7,   # Extended; Infirmary reduces this
}

# Commitment multipliers
const COMMITMENT_INJURY_MULT: Dictionary = {
	Enums.CommitmentLevel.COME_HOME_SAFE: 0.5,
	Enums.CommitmentLevel.USE_JUDGEMENT:  1.0,
	Enums.CommitmentLevel.AT_ANY_COST:    2.0,
}

# ── Public API ────────────────────────────────────────────────────────────────

## Returns true if this hero suffers an injury.
## result: the MissionResult (PARTIAL/FAILURE adds +20% flat).
static func roll_injury(
	hero: HeroData,
	result: Enums.MissionResult,
	commitment: Enums.CommitmentLevel,
	difficulty: int
) -> bool:
	var chance: float = BASE_INJURY_CHANCE[clampi(difficulty - 1, 0, 4)]
	chance *= COMMITMENT_INJURY_MULT[commitment]
	if result == Enums.MissionResult.PARTIAL or result == Enums.MissionResult.FAILURE:
		chance += 0.20
	# Resilience reduces chance: -0.2% per point above 50
	chance -= maxf(hero.resilience - 50.0, 0.0) * 0.002
	chance = clampf(chance, 0.0, 1.0)
	return randf() < chance

## Returns the injury severity given that an injury has already occurred.
static func roll_severity() -> Enums.InjurySeverity:
	var r := randf()
	if r < SEVERITY_WEIGHTS[0]:
		return Enums.InjurySeverity.MINOR
	if r < SEVERITY_WEIGHTS[0] + SEVERITY_WEIGHTS[1]:
		return Enums.InjurySeverity.SERIOUS
	return Enums.InjurySeverity.CRITICAL

## Returns true if a CRITICAL-injured hero dies.
static func roll_death(hero: HeroData, commitment: Enums.CommitmentLevel) -> bool:
	var chance := 0.15
	if commitment == Enums.CommitmentLevel.AT_ANY_COST:
		chance *= 2.0
	# Resilience reduces: -0.3% per point above 50
	chance -= maxf(hero.resilience - 50.0, 0.0) * 0.003
	chance = clampf(chance, 0.0, 1.0)
	return randf() < chance

## Returns true if a hero is captured (only on FAILURE; not on death).
## would_have_died: true if hero survived a death roll — capture chance raised to 40%.
static func roll_capture(result: Enums.MissionResult, would_have_died: bool) -> bool:
	if result != Enums.MissionResult.FAILURE:
		return false
	var chance := 0.40 if would_have_died else 0.20
	return randf() < chance

## Full resolution pipeline for one hero on a completed mission.
## Returns a Dictionary with keys: injured (bool), severity (InjurySeverity),
## died (bool), captured (bool), recovery_days (int).
static func resolve_hero_outcome(
	hero: HeroData,
	result: Enums.MissionResult,
	commitment: Enums.CommitmentLevel,
	difficulty: int
) -> Dictionary:
	var outcome := {
		"injured": false,
		"severity": Enums.InjurySeverity.MINOR,
		"died": false,
		"captured": false,
		"recovery_days": 0,
	}

	if not roll_injury(hero, result, commitment, difficulty):
		return outcome

	outcome["injured"] = true
	var severity := roll_severity()
	outcome["severity"] = severity
	outcome["recovery_days"] = RECOVERY_DAYS[severity]

	if severity == Enums.InjurySeverity.CRITICAL:
		if roll_death(hero, commitment):
			outcome["died"] = true
			return outcome
		# Survived a would-be death — raise capture chance
		if roll_capture(result, true):
			outcome["captured"] = true
			return outcome
	elif result == Enums.MissionResult.FAILURE:
		if roll_capture(result, false):
			outcome["captured"] = true

	return outcome
