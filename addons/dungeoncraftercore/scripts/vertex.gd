extends Resource
class_name Vertex


enum VertexType {ROOM, HALLWAY}

@export var id: int = 0
@export var position: Vector2i = Vector2i.ZERO
@export var type: VertexType
@export var type_tileset_id: int
@export var edges: Dictionary[Direction.Cardinal, Edge] = {}

@export var surface_texture_overrides: Dictionary[Direction.Surface, int] = {}

func _init(_id: int = 0, _pos: Vector2i = Vector2i.ZERO):
	id = _id
	position = _pos