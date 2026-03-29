extends Resource
class_name Direction

enum Cardinal {NORTH, SOUTH, EAST, WEST, NONE = -1} # TODO fix this in the future so we do not need _CLOCKWISE
enum Surface {NORTH, EAST, SOUTH, WEST, CEILING, FLOOR}

const DIRECTION_TO_OFFSET = {
	Cardinal.NORTH: Vector2i(0, -1),
	Cardinal.SOUTH: Vector2i(0, 1),
	Cardinal.WEST: Vector2i(-1, 0),
	Cardinal.EAST: Vector2i(1, 0)
}
const OFFSET_TO_DIRECTION := {
	Vector2i(0, -1): Cardinal.NORTH,
	Vector2i(0, 1): Cardinal.SOUTH,
	Vector2i(-1, 0): Cardinal.WEST,
	Vector2i(1, 0): Cardinal.EAST
}

# Cardinal values in clockwise order for rotation math (enum order is non-clockwise).
const _CLOCKWISE := [Cardinal.NORTH, Cardinal.EAST, Cardinal.SOUTH, Cardinal.WEST]

## Rotates [param dir] clockwise by [param rot] degrees (must be a multiple of 90).
static func get_rotated_direction(dir: Cardinal, rot: int) -> Cardinal:
	var idx := _CLOCKWISE.find(dir)
	if idx == -1: return Cardinal.NONE
	return _CLOCKWISE[wrapi(idx + rot / 90, 0, 4)]


static func get_opposite(dir: Cardinal) -> Cardinal:
	match dir:
		Cardinal.NORTH: return Cardinal.SOUTH
		Cardinal.SOUTH: return Cardinal.NORTH
		Cardinal.EAST: return Cardinal.WEST
		Cardinal.WEST: return Cardinal.EAST
		_: return Cardinal.NONE


static func direction_from_delta(delta: Vector2i) -> Cardinal:
	return Direction.OFFSET_TO_DIRECTION.get(delta, Cardinal.NONE)
