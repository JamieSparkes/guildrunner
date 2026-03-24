## Describes a bond or tension between two heroes.
## Applied when both heroes are on the same mission.
class_name HeroRelationship extends Resource

@export var other_hero_id: String = ""
@export var relationship_type: Enums.RelationshipType = Enums.RelationshipType.BOND
@export var flavour_text: String = ""

## Applied to outcome score when both heroes are on the same mission.
## +5.0 for bond, -5.0 for tension.
@export var morale_modifier: float = 0.0

## Small delta added to the outcome roll.
@export var performance_modifier: float = 0.0
