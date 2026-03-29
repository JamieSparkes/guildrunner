## Static utility for loading hero portrait textures from a sprite sheet atlas.
class_name PortraitHelper

const ATLAS_PATH := "res://data/heroes/portrait_atlas.json"

static var _config: Dictionary = {}
static var _sheet: Texture2D = null
static var _cache: Dictionary = {}

static func _ensure_loaded() -> void:
	if not _config.is_empty():
		return
	_config = DataLoader.load_json(ATLAS_PATH)
	if _config == null:
		push_error("PortraitHelper: failed to load atlas config")
		_config = {}
		return
	_sheet = load(_config.get("sprite_sheet", ""))
	if _sheet == null:
		push_error("PortraitHelper: failed to load sprite sheet")

## Returns an AtlasTexture for the given portrait_id, or null if not found.
static func get_portrait_texture(portrait_id: String) -> AtlasTexture:
	if portrait_id == "":
		return null
	_ensure_loaded()
	if _cache.has(portrait_id):
		return _cache[portrait_id]
	var portraits: Dictionary = _config.get("portraits", {})
	if not portraits.has(portrait_id):
		push_warning("PortraitHelper: unknown portrait_id '%s'" % portrait_id)
		return null
	var col: int = portraits[portrait_id]
	var size: int = _config.get("sprite_size", 24)
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	atlas.region = Rect2(col * size, 0, size, size)
	_cache[portrait_id] = atlas
	return atlas

## Returns a TextureRect node displaying the portrait at the given pixel size,
## with nearest-neighbor filtering for crisp pixel art.
## Returns a placeholder ColorRect wrapper if portrait_id is not found.
static func create_portrait_rect(portrait_id: String, display_size: float = 96.0) -> Control:
	var tex := get_portrait_texture(portrait_id)
	if tex == null:
		var placeholder := ColorRect.new()
		placeholder.custom_minimum_size = Vector2(display_size, display_size)
		placeholder.color = Color(0.25, 0.20, 0.15)
		return placeholder
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(display_size, display_size)
	return rect
