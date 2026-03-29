extends Node
## Generates and manages available contracts on the board.
## Handles morning delivery, expiry, and board size scaling per TDD §4.3.2.

var active_contracts: Array[ContractData] = []

var _templates: Dictionary = {}  # { template_id: ContractData }
var _counter: int = 0

func _ready() -> void:
	_templates = DataLoader.load_contract_templates()
	EventBus.morning_phase_started.connect(on_morning_phase)

## Called by TimeManager each morning. Expires old contracts and refills the board.
func on_morning_phase(day: int) -> void:
	_expire_contracts(day)
	_fill_board(day)

## Return all contracts currently posted on the board.
func get_available_contracts() -> Array[ContractData]:
	return active_contracts

## Remove a contract from the board when accepted for dispatch.
func remove_contract(contract_id: String) -> void:
	for i: int in active_contracts.size():
		if active_contracts[i].contract_id == contract_id:
			active_contracts.remove_at(i)
			return

# ── Internal ──────────────────────────────────────────────────────────────────

func _expire_contracts(day: int) -> void:
	# Iterate backwards so remove_at doesn't shift unvisited indices.
	for i: int in range(active_contracts.size() - 1, -1, -1):
		var contract: ContractData = active_contracts[i]
		if contract.expiry_day < day:
			active_contracts.remove_at(i)
			EventBus.contract_expired.emit(contract.contract_id, contract.is_consequential)

func _fill_board(day: int) -> void:
	var target := _board_target_size(day)
	var attempts := 0
	while active_contracts.size() < target and attempts < 20:
		attempts += 1
		var contract := _generate_contract(day)
		if contract != null:
			active_contracts.append(contract)
			EventBus.contract_available.emit(contract.contract_id)

func _board_target_size(day: int) -> int:
	if day <= 20:
		return randi_range(2, 3)
	elif day <= 60:
		return randi_range(4, 6)
	elif day <= 80:
		return randi_range(5, 7)
	else:
		return randi_range(3, 5)

func _generate_contract(day: int) -> ContractData:
	# Collect template IDs already on the board to prevent duplicates
	var on_board: Array[String] = []
	for c: ContractData in active_contracts:
		on_board.append(c.get_meta("template_id", c.contract_id))

	# Collect templates eligible for this day
	var eligible: Array[String] = []
	for template_id: String in _templates.keys():
		var tpl: ContractData = _templates[template_id]
		if tpl.available_from_day <= day and not on_board.has(template_id):
			eligible.append(template_id)

	if eligible.is_empty():
		return null

	var chosen_id: String = eligible[randi() % eligible.size()]
	var tpl: ContractData = _templates[chosen_id]
	var contract: ContractData = tpl.duplicate()
	# Resource.duplicate() only copies @export vars; copy non-exported fields.
	contract.stages = tpl.stages
	_counter += 1
	contract.contract_id = "contract_%d_%s" % [_counter, chosen_id]
	contract.expiry_day = day + randi_range(2, 3)
	contract.set_meta("template_id", chosen_id)
	return contract

# ── Test helpers ──────────────────────────────────────────────────────────────

func reset_runtime_state() -> void:
	active_contracts.clear()
	_counter = 0

func _reset_for_test() -> void:
	reset_runtime_state()

func _inject_templates_for_test(templates: Dictionary) -> void:
	_templates = templates
