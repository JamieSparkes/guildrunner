extends Node
## Global event bus for cross-system communication.
## All managers emit and connect signals here. No direct manager-to-manager references.

# ── Time ─────────────────────────────────────────────────────────────────────

signal day_advanced(day: int)
signal morning_phase_started(day: int)
signal night_began(day: int)
signal week_advanced(week: int)

# ── Heroes ────────────────────────────────────────────────────────────────────

signal hero_dispatched(hero_id: String, mission_id: String)
signal hero_returned(hero_id: String, result: int)          # Enums.MissionResult
signal hero_wounded(hero_id: String, severity: int)         # Enums.InjurySeverity
signal hero_killed(hero_id: String, mission_id: String)
signal hero_captured(hero_id: String, mission_id: String)
signal hero_trait_acquired(hero_id: String, trait_id: String)
signal hero_morale_changed(hero_id: String, delta: float)

# ── Contracts ─────────────────────────────────────────────────────────────────

signal contract_available(contract_id: String)
signal contract_accepted(contract_id: String)
signal contract_completed(contract_id: String, success: bool)
signal contract_expired(contract_id: String, was_consequential: bool)
signal messenger_arrived(contract_id: String)

# ── Feed ──────────────────────────────────────────────────────────────────────

signal feed_event(mission_id: String, event_key: String, params: Dictionary)
signal feed_intervention_available(mission_id: String)
signal intervention_used(mission_id: String, new_commitment: int)  # Enums.CommitmentLevel

# ── Factions ─────────────────────────────────────────────────────────────────

signal reputation_changed(faction_id: String, delta: int, new_tier: int)  # Enums.RepTier
signal faction_became_enemy(faction_id: String)
signal faction_became_ally(faction_id: String)

# ── Guild ─────────────────────────────────────────────────────────────────────

signal building_construction_started(building_id: String, target_tier: int, completion_day: int)
signal upgrade_built(building_id: String, tier: int)
signal guild_attacked(source: String, strength: int)
signal gold_changed(delta: int, new_total: int)

# ── Game state ────────────────────────────────────────────────────────────────

signal state_changed(from_state: int, to_state: int)  # Enums.GameState

# ── Application Commands / Results ───────────────────────────────────────────

## UI emits commands; AppController executes them.
signal cmd_start_new_game()
signal cmd_transition_state(new_state: int)
signal cmd_open_screen(screen_id: String, data: Dictionary)
signal cmd_close_top_screen()
signal cmd_clear_screens()
signal cmd_dispatch_contract(contract: ContractData, hero_ids: Array[String], commitment: int)
signal cmd_begin_construction(building_id: String)
signal cmd_use_intervention(mission_id: String, new_commitment: int)

## Command results for UI feedback.
signal mission_dispatch_result(success: bool, mission_id: String, error: String)
signal building_construction_result(building_id: String, success: bool, error: String)
signal intervention_command_result(success: bool, error: String)
