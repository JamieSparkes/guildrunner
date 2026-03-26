extends PanelContainer
## A single text line in the mission feed.
## Call setup() with a FeedEvent before adding to the scene tree.

var _event: FeedEvent = null

func _ready() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(label)

	if _event != null:
		label.text = _event.text

func setup(event: FeedEvent) -> void:
	_event = event
