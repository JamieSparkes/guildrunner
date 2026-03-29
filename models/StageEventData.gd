## A single event that can occur during a contract stage.
class_name StageEventData extends RefCounted

## Unique identifier within the stage (e.g. "cave_fight", "find_gold").
var event_id: String = ""
## Event type: "combat", "reward", "discovery", "objective", "narrative".
var type: String = ""
## Base probability (0.0–1.0) of this event firing.
var chance: float = 1.0
## Optional stat modifier: { "stat": "strength", "weight": 0.004 }.
## Adjusts effective chance by hero_stat * weight.
var stat_modifier: Dictionary = {}
## For combat events: difficulty level (1–5).
var difficulty: int = 0
## Difficulty adjustments based on flags: { "detected": 1, "found_weakness": -1 }.
var difficulty_modifier_if_flag: Dictionary = {}
## For reward events: { "gold": int } or { "item_id": String }.
var reward: Dictionary = {}
## Feed event template key for this event's narrative text.
var narrative_key: String = ""
## Whether this event can trigger an intervention prompt.
var can_trigger_intervention: bool = false
## Flag to set on success (empty = none).
var on_success_flag: String = ""
## Feed event template key for failure text (objective events).
var on_failure_narrative_key: String = ""
