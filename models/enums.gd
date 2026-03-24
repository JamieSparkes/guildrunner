## Global enum definitions for Guildrunner.
## All enums are accessed as Enums.EnumName.VALUE from other scripts.
class_name Enums

# ── Hero ─────────────────────────────────────────────────────────────────────

enum HeroArchetype {
	FIGHTER,
	ROGUE,
	RANGER,
	SUPPORT,
}

enum PersonalityType {
	STOIC,
	RECKLESS,
	LOYAL,
	CYNICAL,
	CHEERFUL,
	GRIM,
	CAUTIOUS,
	PROUD,
}

enum HeroStatus {
	AVAILABLE,
	ON_MISSION,
	INJURED,
	RECOVERING,
	CAPTURED,
	DEAD,
}

# ── Mission ──────────────────────────────────────────────────────────────────

enum MissionType {
	ELIMINATE,
	RETRIEVE,
	ESCORT,
	EXPLORE,
	DEFEND,
}

enum MissionResult {
	FAILURE,
	PARTIAL,
	SUCCESS,
	FULL_SUCCESS,
}

enum CommitmentLevel {
	AT_ANY_COST,
	USE_JUDGEMENT,
	COME_HOME_SAFE,
}

# ── Items ────────────────────────────────────────────────────────────────────

enum ItemType {
	WEAPON,
	ARMOUR,
	ACCESSORY,
}

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	ARTEFACT,
}

# ── Factions ─────────────────────────────────────────────────────────────────

enum FactionType {
	CROWN,
	CHURCH,
	MERCHANTS,
	UNDERWORLD,
	COMMON_FOLK,
}

enum RepTier {
	ENEMY,
	UNKNOWN,
	NEUTRAL,
	TRUSTED,
	HONOURED,
}

const REP_TIER_LABELS: Dictionary = {
	RepTier.ENEMY:    "Enemy",
	RepTier.UNKNOWN:  "Unknown",
	RepTier.NEUTRAL:  "Neutral",
	RepTier.TRUSTED:  "Trusted",
	RepTier.HONOURED: "Honoured",
}

# ── Time / World ──────────────────────────────────────────────────────────────

enum DayPhase {
	MORNING,
	NIGHT,
}

enum DeliveryType {
	NOTICEBOARD,
	MESSENGER,
}

enum InjurySeverity {
	MINOR,
	SERIOUS,
	CRITICAL,
}

enum RelationshipType {
	BOND,
	TENSION,
}

# ── Game State Machine ────────────────────────────────────────────────────────

enum GameState {
	MAIN_MENU,
	GUILD_HUB,
	MORNING_PHASE,
	NIGHT_PHASE,
	MISSION_BRIEFING,
	MISSION_AUTO,
	SIEGE,
	MISSION_DIRECT,  # Reserved; post-launch
	CUTSCENE,
	PAUSED,
}
