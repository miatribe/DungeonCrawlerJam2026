@tool
extends Resource
class_name GraphTileset


@export var north_textures: Array[TileTexture] = []
@export var east_textures: Array[TileTexture] = []
@export var south_textures: Array[TileTexture] = []
@export var west_textures: Array[TileTexture] = []
@export var ceiling_textures: Array[TileTexture] = []
@export var floor_textures: Array[TileTexture] = []


func get_textures_for_surface(surface: Direction.Surface) -> Array[TileTexture]:
	match surface:
		Direction.Surface.NORTH: return north_textures
		Direction.Surface.EAST: return east_textures
		Direction.Surface.SOUTH: return south_textures
		Direction.Surface.WEST: return west_textures
		Direction.Surface.CEILING: return ceiling_textures
		_: return floor_textures


func get_texture_for_surface(surface: Direction.Surface, rng: RandomNumberGenerator = null) -> Texture2D:
	var weighted_textures := get_textures_for_surface(surface)
	return _pick_weighted_texture(weighted_textures, rng)


func _pick_weighted_texture(weighted_textures: Array[TileTexture], rng: RandomNumberGenerator = null) -> Texture2D:
	if weighted_textures.is_empty(): return null
	if weighted_textures.size() == 1: return weighted_textures[0].texture

	var total_weight := 0.0
	for weighted_texture in weighted_textures:
		total_weight += maxf(weighted_texture.chance_percent, 0.0)

	if total_weight <= 0.0: return weighted_textures[0].texture

	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	var roll := local_rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for weighted_texture in weighted_textures:
		cumulative += maxf(weighted_texture.chance_percent, 0.0)
		if roll <= cumulative: return weighted_texture.texture

	return weighted_textures[weighted_textures.size() - 1].texture
