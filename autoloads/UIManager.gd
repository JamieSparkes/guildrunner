extends Node
## Manages overlay screens on top of the hub scene.
## Screens push onto a stack; popping returns to the previous state.
## §6.3: screens receive data via setup(), emit signals upward, never mutate state directly.

const SCREEN_PATHS: Dictionary = {
	"contract_board":   "res://ui/screens/ContractBoardScreen.tscn",
	"mission_briefing": "res://ui/screens/MissionBriefingScreen.tscn",
	"feed":             "res://ui/screens/FeedScreen.tscn",
	"hero_roster":      "res://ui/screens/HeroRosterScreen.tscn",
	"hero_detail":      "res://ui/screens/HeroDetailScreen.tscn",
	"building":         "res://ui/screens/BuildingScreen.tscn",
}

var _stack: Array[Node] = []
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.name = "UILayer"
	add_child(_layer)

## Push a named screen onto the stack. Pass data for setup() as a Dictionary.
func push_screen(screen_id: String, data: Dictionary = {}) -> void:
	if not SCREEN_PATHS.has(screen_id):
		push_error("UIManager: unknown screen '%s'" % screen_id)
		return
	var packed: PackedScene = load(SCREEN_PATHS[screen_id])
	if packed == null:
		push_error("UIManager: could not load scene for '%s'" % screen_id)
		return
	var instance: Node = packed.instantiate()
	if instance.has_method("setup"):
		instance.setup(data)
	_layer.add_child(instance)
	_stack.append(instance)

## Pop and free the top screen.
func pop_screen() -> void:
	if _stack.is_empty():
		return
	var top: Node = _stack.pop_back()
	top.queue_free()

## Pop and free all screens (return to bare hub).
func clear_screens() -> void:
	for screen: Node in _stack:
		screen.queue_free()
	_stack.clear()
