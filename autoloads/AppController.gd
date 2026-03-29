extends Node
## Application service layer for UI-driven commands.
## Mediates UI intents into manager calls and emits result events.

func _ready() -> void:
	EventBus.cmd_start_new_game.connect(_on_cmd_start_new_game)
	EventBus.cmd_transition_state.connect(_on_cmd_transition_state)
	EventBus.cmd_open_screen.connect(_on_cmd_open_screen)
	EventBus.cmd_close_top_screen.connect(_on_cmd_close_top_screen)
	EventBus.cmd_clear_screens.connect(_on_cmd_clear_screens)
	EventBus.cmd_dispatch_contract.connect(_on_cmd_dispatch_contract)
	EventBus.cmd_begin_construction.connect(_on_cmd_begin_construction)
	EventBus.cmd_use_intervention.connect(_on_cmd_use_intervention)
	EventBus.cmd_finalize_mission.connect(_on_cmd_finalize_mission)

func _on_cmd_start_new_game() -> void:
	GameManager.start_new_game()

func _on_cmd_transition_state(new_state: int) -> void:
	GameManager.transition_to(new_state)

func _on_cmd_open_screen(screen_id: String, data: Dictionary) -> void:
	UIManager.push_screen(screen_id, data)

func _on_cmd_close_top_screen() -> void:
	UIManager.pop_screen()

func _on_cmd_clear_screens() -> void:
	UIManager.clear_screens()

func _on_cmd_dispatch_contract(contract: ContractData, hero_ids: Array[String], commitment: int) -> void:
	var mission_id := MissionManager.dispatch_heroes(contract, hero_ids, commitment)
	if mission_id.is_empty():
		EventBus.mission_dispatch_result.emit(false, "", "Dispatch failed. Check hero availability.")
		return
	ContractQueue.remove_contract(contract.contract_id)
	EventBus.mission_dispatch_result.emit(true, mission_id, "")
	EventBus.cmd_clear_screens.emit()

func _on_cmd_begin_construction(building_id: String) -> void:
	var success := BuildingManager.begin_construction(building_id)
	if success:
		EventBus.building_construction_result.emit(building_id, true, "")
	else:
		EventBus.building_construction_result.emit(building_id, false, "Construction failed.")


func _on_cmd_use_intervention(mission_id: String, new_commitment: int) -> void:
	if not GuildManager.spend_intervention_token():
		EventBus.intervention_command_result.emit(false, "No intervention tokens remaining.")
		return
	MissionManager.update_commitment(mission_id, new_commitment)
	EventBus.intervention_used.emit(mission_id, new_commitment)
	EventBus.intervention_command_result.emit(true, "")
	# Stream resume is handled by FeedManager._on_intervention_used().

func _on_cmd_finalize_mission(mission_id: String) -> void:
	MissionManager.finalize_mission(mission_id)
