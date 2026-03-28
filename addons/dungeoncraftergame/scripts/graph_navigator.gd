extends RefCounted
class_name GraphNavigator


signal vertex_entered(vertex_id: int, previous_vertex_id: int, via_direction: Direction.Cardinal)
signal moved(from_vertex_id: int, to_vertex_id: int, direction: Direction.Cardinal, edge_id: int)
signal movement_blocked(from_vertex_id: int, direction: Direction.Cardinal, reason: StringName)

var graph: Graph
var current_vertex_id: int = -1


func set_graph(value: Graph) -> void:
	graph = value
	if graph == null or not graph.vertices.has(current_vertex_id):
		current_vertex_id = -1


func set_current_vertex(vertex_id: int, emit_entered_signal: bool = false) -> bool:
	if graph == null:
		return false
	if not graph.vertices.has(vertex_id):
		return false
	var previous_vertex_id := current_vertex_id
	current_vertex_id = vertex_id
	if emit_entered_signal:
		vertex_entered.emit(current_vertex_id, previous_vertex_id, Direction.Cardinal.NONE)
	return true


func move(direction: Direction.Cardinal) -> bool:
	if graph == null:
		movement_blocked.emit(current_vertex_id, direction, &"no_graph")
		return false

	var current_vertex: Vertex = graph.vertices.get(current_vertex_id)
	if current_vertex == null:
		movement_blocked.emit(current_vertex_id, direction, &"invalid_current_vertex")
		return false

	if not current_vertex.edges.has(direction):
		movement_blocked.emit(current_vertex_id, direction, &"no_edge")
		return false

	var edge: Edge = current_vertex.edges[direction]
	if edge == null:
		movement_blocked.emit(current_vertex_id, direction, &"missing_edge")
		return false

	if not _is_edge_passable(edge):
		movement_blocked.emit(current_vertex_id, direction, &"edge_blocked")
		return false

	var next_vertex_id := _get_other_vertex_id(edge, current_vertex_id)
	if next_vertex_id == -1 or not graph.vertices.has(next_vertex_id):
		movement_blocked.emit(current_vertex_id, direction, &"invalid_destination")
		return false

	var previous_vertex_id := current_vertex_id
	current_vertex_id = next_vertex_id
	moved.emit(previous_vertex_id, current_vertex_id, direction, edge.id)
	vertex_entered.emit(current_vertex_id, previous_vertex_id, direction)
	return true


func _is_edge_passable(edge: Edge) -> bool:
	if edge.type == Edge.EdgeType.CORRIDOR:
		return true
	if edge.type != Edge.EdgeType.DOOR:
		return false
	return int(edge.door_state) == int(Door.DoorState.OPEN)


func _get_other_vertex_id(edge: Edge, vertex_id: int) -> int:
	if edge.vertex_a_id == vertex_id:
		return edge.vertex_b_id
	if edge.vertex_b_id == vertex_id:
		return edge.vertex_a_id
	return -1
