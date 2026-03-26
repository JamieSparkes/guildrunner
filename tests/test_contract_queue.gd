extends GutTest
## Tests for ContractQueue: board generation, expiry, scaling, and signal emission.

# ── Helpers ───────────────────────────────────────────────────────────────────

## Build a dictionary of N ContractData templates, all available from `from_day`.
## Template 0 is marked consequential so expiry signals can be tested.
func _make_templates(from_day: int = 1, count: int = 8) -> Dictionary:
	var result: Dictionary = {}
	for i: int in count:
		var cd := ContractData.new()
		cd.contract_id = "tpl_%d" % i
		cd.title = "Template %d" % i
		cd.available_from_day = from_day
		cd.expiry_day = 999
		cd.is_consequential = (i == 0)
		result[cd.contract_id] = cd
	return result

func before_each() -> void:
	ContractQueue._reset_for_test()
	ContractQueue._inject_templates_for_test(_make_templates())
	TimeManager._reset_for_test()

func after_each() -> void:
	ContractQueue._reset_for_test()

# ── Board size ────────────────────────────────────────────────────────────────

func test_board_size_early_game() -> void:
	# Day 1–20 → 2–3 contracts
	ContractQueue.on_morning_phase(10)
	assert_between(ContractQueue.active_contracts.size(), 2, 3,
			"Early game board (day 10) should have 2–3 contracts")

func test_board_size_mid_game() -> void:
	# Day 21–60 → 4–6 contracts
	ContractQueue.on_morning_phase(35)
	assert_between(ContractQueue.active_contracts.size(), 4, 6,
			"Mid game board (day 35) should have 4–6 contracts")

func test_board_size_pre_siege() -> void:
	# Day 61–80 → 5–7 contracts (need ≥ 7 templates)
	ContractQueue.on_morning_phase(70)
	assert_between(ContractQueue.active_contracts.size(), 5, 7,
			"Pre-siege board (day 70) should have 5–7 contracts")

func test_board_size_post_siege() -> void:
	# Day 81+ → 3–5 contracts
	ContractQueue.on_morning_phase(90)
	assert_between(ContractQueue.active_contracts.size(), 3, 5,
			"Post-siege board (day 90) should have 3–5 contracts")

# ── Availability gate ─────────────────────────────────────────────────────────

func test_late_templates_not_used_before_available_day() -> void:
	# Mix: 5 early templates + 1 late (from day 20)
	var templates := _make_templates(1, 5)
	var late := ContractData.new()
	late.contract_id = "late_tpl"
	late.available_from_day = 20
	late.expiry_day = 999
	templates["late_tpl"] = late
	ContractQueue._inject_templates_for_test(templates)

	ContractQueue.on_morning_phase(5)

	for contract: ContractData in ContractQueue.active_contracts:
		var tid: String = contract.get_meta("template_id", contract.contract_id)
		assert_ne(tid, "late_tpl",
				"Late template should not appear on day 5")

func test_late_templates_appear_after_available_day() -> void:
	# Only one template, available from day 10
	var templates: Dictionary = {}
	var tpl := ContractData.new()
	tpl.contract_id = "late_only"
	tpl.available_from_day = 10
	tpl.expiry_day = 999
	templates["late_only"] = tpl
	ContractQueue._inject_templates_for_test(templates)

	ContractQueue.on_morning_phase(10)
	assert_eq(ContractQueue.active_contracts.size(), 1,
			"Late template should appear once its available_from_day is reached")

# ── Duplicate prevention ──────────────────────────────────────────────────────

func test_no_duplicate_templates_on_board() -> void:
	ContractQueue.on_morning_phase(35)
	var seen_templates: Array[String] = []
	for contract: ContractData in ContractQueue.active_contracts:
		var tid: String = contract.get_meta("template_id", contract.contract_id)
		assert_false(seen_templates.has(tid),
				"Template '%s' appears more than once on the board" % tid)
		seen_templates.append(tid)

# ── Expiry ────────────────────────────────────────────────────────────────────

func test_expired_contracts_are_removed() -> void:
	ContractQueue.on_morning_phase(5)
	# Force-expire everything
	for contract: ContractData in ContractQueue.active_contracts:
		contract.expiry_day = 5

	ContractQueue.on_morning_phase(6)

	# All remaining contracts should have expiry_day >= 6
	for contract: ContractData in ContractQueue.active_contracts:
		assert_gte(contract.expiry_day, 6,
				"Expired contracts (expiry_day < 6) should have been removed")

func test_contract_expired_signal_consequential() -> void:
	watch_signals(EventBus)
	var cd := ContractData.new()
	cd.contract_id = "cons_test"
	cd.expiry_day = 4
	cd.is_consequential = true
	ContractQueue.active_contracts.append(cd)

	ContractQueue.on_morning_phase(5)

	assert_signal_emitted_with_parameters(EventBus, "contract_expired",
			["cons_test", true])

func test_contract_expired_signal_non_consequential() -> void:
	watch_signals(EventBus)
	var cd := ContractData.new()
	cd.contract_id = "noncons_test"
	cd.expiry_day = 4
	cd.is_consequential = false
	ContractQueue.active_contracts.append(cd)

	ContractQueue.on_morning_phase(5)

	assert_signal_emitted_with_parameters(EventBus, "contract_expired",
			["noncons_test", false])

func test_non_expired_contracts_stay() -> void:
	ContractQueue.on_morning_phase(5)
	var count_before := ContractQueue.active_contracts.size()
	# Force only one contract to expire
	ContractQueue.active_contracts[0].expiry_day = 5

	ContractQueue.on_morning_phase(6)

	# Board refills, so final size >= count_before - 1
	assert_gte(ContractQueue.active_contracts.size(), count_before - 1,
			"Non-expired contracts should survive the morning phase")

# ── remove_contract ───────────────────────────────────────────────────────────

func test_remove_contract_decrements_board() -> void:
	ContractQueue.on_morning_phase(5)
	var before := ContractQueue.active_contracts.size()
	var target_id: String = ContractQueue.active_contracts[0].contract_id

	ContractQueue.remove_contract(target_id)

	assert_eq(ContractQueue.active_contracts.size(), before - 1,
			"Board should shrink by one after remove_contract")

func test_remove_contract_removes_correct_entry() -> void:
	ContractQueue.on_morning_phase(5)
	var target_id: String = ContractQueue.active_contracts[0].contract_id

	ContractQueue.remove_contract(target_id)

	for c: ContractData in ContractQueue.active_contracts:
		assert_ne(c.contract_id, target_id,
				"Removed contract should not remain on board")

func test_remove_nonexistent_is_noop() -> void:
	ContractQueue.on_morning_phase(5)
	var before := ContractQueue.active_contracts.size()

	ContractQueue.remove_contract("ghost_id")

	assert_eq(ContractQueue.active_contracts.size(), before,
			"Removing a non-existent ID should not change the board")

# ── contract_available signal ─────────────────────────────────────────────────

func test_contract_available_signal_emitted_on_fill() -> void:
	watch_signals(EventBus)
	ContractQueue.on_morning_phase(5)
	assert_signal_emitted(EventBus, "contract_available",
			"contract_available should be emitted when new contracts are added")

# ── Expiry date range ─────────────────────────────────────────────────────────

func test_generated_contract_expiry_is_2_or_3_days_ahead() -> void:
	# Fresh board on day 5: all contracts generated this morning
	ContractQueue.on_morning_phase(5)
	for contract: ContractData in ContractQueue.active_contracts:
		assert_between(contract.expiry_day, 7, 8,
				"Contract generated on day 5 should expire on day 7 or 8")

# ── Runtime contract IDs are unique ──────────────────────────────────────────

func test_runtime_contract_ids_are_unique() -> void:
	ContractQueue.on_morning_phase(35)
	var ids: Array[String] = []
	for contract: ContractData in ContractQueue.active_contracts:
		assert_false(ids.has(contract.contract_id),
				"Each contract on the board should have a unique runtime ID")
		ids.append(contract.contract_id)
