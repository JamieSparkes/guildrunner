## Definition of a hero trait. Loaded from trait_definitions.json.
## Traits are awarded when a hero meets the trigger condition.
class_name TraitData extends Resource

@export var trait_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Condition string evaluated by TraitEvaluator.
## Examples: "stealth_missions_clean >= 5", "times_wounded >= 3", "missions_completed >= 10"
@export var trigger: String = ""

## Effects applied when the trait is awarded.
## Each entry: { "type": "attribute" | "morale_floor", "attribute": String, "modifier": float }
@export var effects: Array[Dictionary] = []
