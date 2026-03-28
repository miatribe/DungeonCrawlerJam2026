extends Resource
class_name Edge


enum EdgeType {CORRIDOR, DOOR}

@export var id: int
@export var vertex_a_id: int
@export var vertex_b_id: int
@export var direction_from_a: Direction.Cardinal = Direction.Cardinal.NONE
@export var direction_from_b: Direction.Cardinal = Direction.Cardinal.NONE
@export var type: EdgeType = EdgeType.CORRIDOR
@export var door_id: int = -1
@export var door_state: int = Door.DoorState.CLOSED


func _init(_id: int = 0, a: int = 0, b: int = 0, dir: Direction.Cardinal = Direction.Cardinal.NONE):
	id = _id
	vertex_a_id = a
	vertex_b_id = b
	direction_from_a = dir
	direction_from_b = Direction.get_opposite(direction_from_a)
	type = EdgeType.CORRIDOR
	door_id = -1
	door_state = Door.DoorState.CLOSED


func is_passable() -> bool:
	if type == EdgeType.CORRIDOR:
		return true
	if type == EdgeType.DOOR:
		return int(door_state) == int(Door.DoorState.OPEN)
	return false
