## A single event entry in the auto-resolve feed.
## Lightweight; created frequently at runtime. Not persisted directly (embedded in mission log).
class_name FeedEvent extends RefCounted

## ID of the mission this event belongs to.
var mission_id: String = ""
## Formatted text displayed in the feed column.
var text: String = ""
## If true, an illustrated panel should render above this entry.
var is_illustrated: bool = false
## Day number when this event occurred.
var day: int = 0
## Raw event key (e.g. "hero_wounded"), kept for log filtering.
var event_key: String = ""
## Display color for this entry (mission color or reserved override).
var color: Color = Color.WHITE

func _init(
	p_mission_id: String = "",
	p_text: String = "",
	p_event_key: String = "",
	p_is_illustrated: bool = false,
	p_day: int = 0,
	p_color: Color = Color.WHITE
) -> void:
	mission_id = p_mission_id
	text = p_text
	event_key = p_event_key
	is_illustrated = p_is_illustrated
	day = p_day
	color = p_color
