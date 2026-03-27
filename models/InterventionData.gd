## Describes an intervention opportunity presented to the player during the live feed.
## UI widgets use the type discriminator to render the correct options.
## AppController dispatches the resolved option to the appropriate manager.
class_name InterventionData extends RefCounted

enum Type {
	COMMITMENT_CHANGE,  ## Choose a new CommitmentLevel for the mission.
	BINARY_CHOICE,      ## (Future) Choose between two named narrative paths.
	HERO_RECALL,        ## (Future) Remove a specific hero from the mission.
}

## Mission this intervention applies to.
var mission_id: String = ""

## Discriminator; controls which UI widget is rendered.
var intervention_type: Type = Type.COMMITMENT_CHANGE

## Human-readable prompt shown above the option buttons.
var context_text: String = ""

## The event key that triggered this intervention (e.g. "encounter_obstacle").
var trigger_event_key: String = ""

## Options the player can choose from. Schema varies by type:
##   COMMITMENT_CHANGE: Array[int] — CommitmentLevel values
##   BINARY_CHOICE:     Array[{ "label": String, "path_key": String }]
##   HERO_RECALL:       Array[{ "hero_id": String, "name": String }]
var options: Array = []

## Index into options of the currently-active value (disabled in UI).
## -1 means no option is pre-disabled.
var current_option_index: int = -1
