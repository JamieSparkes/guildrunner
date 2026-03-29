## A single stage within a staged contract.
class_name StageData extends RefCounted

## Unique identifier within the contract (e.g. "travel", "search_chamber").
var stage_id: String = ""
## Feed event template key for the stage's narrative text.
var narrative_key: String = ""
## Advancement config: { "type": "auto"|"chance"|"stat_check", ... }
var advance: Dictionary = {}
## Events that can occur during this stage.
var events: Array[StageEventData] = []
## Flag to set when this stage completes (empty = none).
var sets_flag: String = ""
