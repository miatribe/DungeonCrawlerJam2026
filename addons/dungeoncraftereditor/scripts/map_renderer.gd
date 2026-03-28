@tool
extends Node2D
class_name MapRenderer


const CELL_SIZE := Vector2i(16, 16)
const EDGE_OFFSET := Vector2i(CELL_SIZE * 0.5)
const GRID_COLOR := Color(0.45, 0.45, 0.45, 0.55)

var drawGrid: bool = true
var vertex_type_tileset_colors: Dictionary = {}

var graph: Graph
var bsbNodeRoot: BspNode


func _draw() -> void:
	if drawGrid: _draw_grid()
	if graph == null: return
	if bsbNodeRoot: _print_bsp_nodes(bsbNodeRoot)
	draw_vertices()
	draw_edges()


func _draw_grid() -> void:
	if CELL_SIZE.x <= 0 or CELL_SIZE.y <= 0: return
	
	var tl := to_local(Vector2.ZERO)
	var br := to_local(get_viewport_rect().size)
	var min_x := minf(tl.x, br.x)
	var max_x := maxf(tl.x, br.x)
	var min_y := minf(tl.y, br.y)
	var max_y := maxf(tl.y, br.y)
	var start_x := floori(min_x / CELL_SIZE.x) * CELL_SIZE.x
	var end_x := ceili(max_x / CELL_SIZE.x) * CELL_SIZE.x
	var start_y := floori(min_y / CELL_SIZE.y) * CELL_SIZE.y
	var end_y := ceili(max_y / CELL_SIZE.y) * CELL_SIZE.y
	for x in range(start_x, end_x + CELL_SIZE.x, CELL_SIZE.x): draw_line(Vector2(x, min_y), Vector2(x, max_y), GRID_COLOR, 1.0)
	for y in range(start_y, end_y + CELL_SIZE.y, CELL_SIZE.y): draw_line(Vector2(min_x, y), Vector2(max_x, y), GRID_COLOR, 1.0)


func draw_vertices() -> void:
	for key in graph.vertices:
		var vertex = graph.vertices[key]
		var top_left = Vector2i(vertex.position) * CELL_SIZE
		var rect = Rect2(top_left, CELL_SIZE)
		var color = get_vertex_color_for_type_tileset(vertex.type, vertex.type_tileset_id)
		draw_rect(rect, color, true)
		draw_rect(rect, Color.BLACK, false, 2.0)


func draw_edges() -> void:
	for edge_id in graph.edges:
		var edge: Edge = graph.edges[edge_id]
		var start_vertex = graph.vertices[edge.vertex_a_id]
		var end_vertex = graph.vertices[edge.vertex_b_id]
		var color = get_edge_color_for_edge(edge)
		draw_line(start_vertex.position * CELL_SIZE + EDGE_OFFSET, end_vertex.position * CELL_SIZE + EDGE_OFFSET, color, 2.0)


func _print_bsp_nodes(node) -> void:
	if node == null: return
	draw_rect(Rect2(node.box.position * CELL_SIZE, node.box.size * CELL_SIZE), Color.DARK_GRAY, false, 2.0)
	_print_bsp_nodes(node.left)
	_print_bsp_nodes(node.right)


func get_edge_color_for_edge(edge: Edge) -> Color:
	if edge.type == Edge.EdgeType.CORRIDOR:
		return Color.GREEN
	if edge.type == Edge.EdgeType.DOOR:
		var door_state := int(edge.door_state)
		match door_state:
			Door.DoorState.OPEN:
				return Color.GRAY
			Door.DoorState.CLOSED:
				return Color.BLUE
	return Color.WHITE


func get_vertex_color_for_type_tileset(vertex_type: Vertex.VertexType, tileset_id: int) -> Color:
	var key = "%d:%d" % [int(vertex_type), tileset_id]
	if vertex_type_tileset_colors.has(key):
		return vertex_type_tileset_colors[key]

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(key.hash())
	var hue = rng.randf()
	var saturation = rng.randf_range(0.45, 0.85)
	var value = rng.randf_range(0.65, 0.95)

	if vertex_type == Vertex.VertexType.HALLWAY:
		value = rng.randf_range(0.45, 0.75)

	var color = Color.from_hsv(hue, saturation, value)
	vertex_type_tileset_colors[key] = color
	return color