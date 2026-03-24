extends Node
## Generates and manages available contracts on the board.
## Handles morning delivery, expiry, and board size scaling.
## Fully implemented in M5; stub methods exist so TimeManager can call safely.

var active_contracts: Array = []

## Called by TimeManager each morning. Expires old contracts and generates new ones.
## Full implementation in M5.
func on_morning_phase(_day: int) -> void:
	pass
