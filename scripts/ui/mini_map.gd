extends Control
class_name MiniMap

@export var reveal_radius: int = 4
@export_range(4.0, 40.0, 1.0) var cell_size: float = 12.0
@export var visited_tile_color: Color = Color(0.34, 0.82, 0.58, 1.0)
@export var unvisited_tile_color: Color = Color(0.18, 0.23, 0.29, 1.0)
@export var player_color: Color = Color(0.95, 0.95, 0.95, 1.0)
@export var border_color: Color = Color(0.8, 0.82, 0.9, 0.8)
@export var background_color: Color = Color(0.02, 0.03, 0.05, 0.75)
@export var door_closed_color: Color = Color(0.88, 0.38, 0.22, 1.0)
@export var door_open_color: Color = Color(0.34, 0.75, 0.38, 1.0)

var _graph: Graph
var _player: Player
var _visited_by_map: Dictionary[String, Dictionary] = {}
var _current_map_key: String = ""
var _last_player_vertex_id: int = -1
var _last_player_rotation_y: int = -9999
var _last_door_signature: int = -1
var _is_unlocked: bool = false


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _is_unlocked
	queue_redraw()


func set_unlocked(is_unlocked: bool) -> void:
	_is_unlocked = is_unlocked
	visible = is_unlocked
	queue_redraw()


func is_unlocked() -> bool:
	return _is_unlocked


func set_context(graph: Graph, player: Player) -> void:
	if _graph == graph and _player == player:
		return
	_graph = graph
	_player = player
	_last_player_vertex_id = -1
	_last_player_rotation_y = -9999
	_last_door_signature = -1
	_current_map_key = _resolve_map_key(graph)
	if not _visited_by_map.has(_current_map_key):
		_visited_by_map[_current_map_key] = {}
	queue_redraw()


func _process(_delta: float) -> void:
	if _graph == null or _player == null:
		return
	var player_vertex_id := _player.get_current_vertex_id()
	if player_vertex_id < 0:
		return
	_mark_visited(player_vertex_id)
	if _last_player_vertex_id != player_vertex_id:
		_last_player_vertex_id = player_vertex_id
		queue_redraw()
	var snapped_rotation_y := int(wrapi(roundi(_player.rotation_degrees.y), 0, 360))
	if _last_player_rotation_y != snapped_rotation_y:
		_last_player_rotation_y = snapped_rotation_y
		queue_redraw()
	var door_signature := _compute_door_signature()
	if _last_door_signature != door_signature:
		_last_door_signature = door_signature
		queue_redraw()


func _draw() -> void:
	if not _is_unlocked:
		return
	if _graph == null or _player == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)

	var player_vertex_id := _player.get_current_vertex_id()
	if player_vertex_id < 0:
		return
	var player_vertex: Vertex = _graph.vertices.get(player_vertex_id)
	if player_vertex == null:
		return

	var player_cell := player_vertex.position
	var half := cell_size * 0.5
	for vertex_id: int in _graph.vertices:
		var vertex: Vertex = _graph.vertices[vertex_id]
		if vertex == null:
			continue
		if not _is_within_reveal(vertex.position, player_cell):
			continue

		var cell_center := _world_to_map(vertex.position, player_cell)
		var tile_rect := Rect2(cell_center - Vector2(half, half), Vector2(cell_size, cell_size))
		var tile_color := visited_tile_color if _is_visited(vertex_id) else unvisited_tile_color
		draw_rect(tile_rect, tile_color, true)
		draw_rect(tile_rect, border_color, false, 1.0)

	_draw_doors(player_cell)
	_draw_player_arrow()


func _draw_player_arrow() -> void:
	var center := size * 0.5
	var forward := _player_forward_vector()
	var right := Vector2(-forward.y, forward.x)
	var head := center + forward * (cell_size * 0.49)
	var left := center - forward * (cell_size * 0.24) + right * (cell_size * 0.27)
	var right_point := center - forward * (cell_size * 0.24) - right * (cell_size * 0.27)
	draw_colored_polygon(PackedVector2Array([head, left, right_point]), player_color)


func _draw_doors(player_cell: Vector2i) -> void:
	if _graph == null:
		return
	for edge_id: int in _graph.edges:
		var edge: Edge = _graph.edges[edge_id]
		if edge == null or int(edge.type) != int(Edge.EdgeType.DOOR):
			continue
		var vertex_a: Vertex = _graph.vertices.get(edge.vertex_a_id)
		var vertex_b: Vertex = _graph.vertices.get(edge.vertex_b_id)
		if vertex_a == null or vertex_b == null:
			continue
		var in_range_a := _is_within_reveal(vertex_a.position, player_cell)
		var in_range_b := _is_within_reveal(vertex_b.position, player_cell)
		if not in_range_a and not in_range_b:
			continue
		var midpoint := (vertex_a.position + vertex_b.position) / 2.0
		var map_point := size * 0.5 + (midpoint - Vector2(player_cell)) * cell_size
		var marker_size := maxf(3.0, cell_size * 0.3)
		var marker_rect := Rect2(map_point - Vector2(marker_size * 0.5, marker_size * 0.5), Vector2(marker_size, marker_size))
		var is_open := int(edge.door_state) == int(Door.DoorState.OPEN)
		draw_rect(marker_rect, door_open_color if is_open else door_closed_color, true)
		draw_rect(marker_rect, border_color, false, 1.0)


func _world_to_map(cell: Vector2i, player_cell: Vector2i) -> Vector2:
	var delta := cell - player_cell
	return size * 0.5 + Vector2(delta.x, delta.y) * cell_size


func _is_within_reveal(cell: Vector2i, player_cell: Vector2i) -> bool:
	var dx := absi(cell.x - player_cell.x)
	var dy := absi(cell.y - player_cell.y)
	return dx <= reveal_radius and dy <= reveal_radius


func _resolve_map_key(graph: Graph) -> String:
	if graph == null:
		return ""
	if not graph.resource_path.is_empty():
		return graph.resource_path
	return "runtime_%d" % graph.get_instance_id()


func _mark_visited(vertex_id: int) -> void:
	if _current_map_key.is_empty():
		return
	if not _visited_by_map.has(_current_map_key):
		_visited_by_map[_current_map_key] = {}
	var visited: Dictionary = _visited_by_map[_current_map_key]
	if visited.has(vertex_id):
		return
	visited[vertex_id] = true
	queue_redraw()


func _is_visited(vertex_id: int) -> bool:
	if _current_map_key.is_empty() or not _visited_by_map.has(_current_map_key):
		return false
	return (_visited_by_map[_current_map_key] as Dictionary).has(vertex_id)


func _player_forward_vector() -> Vector2:
	if _player == null:
		return Vector2.UP
	var snapped_rotation := int(wrapi(roundi(_player.rotation_degrees.y), 0, 360))
	match snapped_rotation:
		0:
			return Vector2(0, -1)
		90:
			return Vector2(-1, 0)
		180:
			return Vector2(0, 1)
		270:
			return Vector2(1, 0)
		_:
			return Vector2(0, -1)


func _compute_door_signature() -> int:
	if _graph == null:
		return 0
	var signature := 17
	for edge_id: int in _graph.edges:
		var edge: Edge = _graph.edges[edge_id]
		if edge == null or int(edge.type) != int(Edge.EdgeType.DOOR):
			continue
		signature = signature * 31 + edge_id
		signature = signature * 31 + int(edge.type)
		signature = signature * 31 + int(edge.door_state)
		signature = signature * 31 + int(edge.door_id)
	return signature
