@tool
extends Resource
class_name Graph


signal vertex_logic_triggered(vertex_id: int, logic_id: StringName)


@export var _next_vertex_id: int = 0
@export var _next_edge_id: int = 0
@export var vertices: Dictionary[int, Vertex] = {} # id -> Vertex
@export var edges: Dictionary[int, Edge] = {} # id -> Edge
@export var vertex_logic: Dictionary[int, VertexLogicList] = {} # vertex id -> logic list wrapper

@export var tilesets: Array[GraphTileset] = []
@export var doors: Array[Door] = []
@export var override_textures: Array[TileTexture] = []

func add_vertex(pos: Vector2i, vertex_type: Vertex.VertexType) -> Vertex:
	var v := Vertex.new(_next_vertex_id, pos)
	v.type = vertex_type
	vertices[_next_vertex_id] = v
	_next_vertex_id += 1
	return v


func connect_vertices(vertex_a_id: int, vertex_b_id: int, direction_from_a: Direction.Cardinal, edge_type: Edge.EdgeType, door_state: int = Door.DoorState.CLOSED, door_id: int = -1) -> Edge:
	var vertex_a: Vertex = vertices.get(vertex_a_id)
	var vertex_b: Vertex = vertices.get(vertex_b_id)
	if vertex_a == null or vertex_b == null:
		push_warning("Graph: connect_vertices called with invalid vertex ID(s): %d, %d" % [vertex_a_id, vertex_b_id])
		return null
	var edge := Edge.new(_next_edge_id, vertex_a_id, vertex_b_id, direction_from_a)
	_next_edge_id += 1
	edges[edge.id] = edge
	_assign_edge(vertex_a, direction_from_a, edge)
	_assign_edge(vertex_b, Direction.get_opposite(direction_from_a), edge)
	edge.type = edge_type
	if edge_type == Edge.EdgeType.DOOR:
		edge.door_state = clampi(door_state, 0, Door.DoorState.size() - 1)
		edge.door_id = door_id
	else:
		edge.door_state = Door.DoorState.CLOSED
		edge.door_id = -1
	return edge

func _assign_edge(vertex: Vertex, direction: Direction.Cardinal, edge: Edge) -> void: vertex.edges[direction] = edge


func set_vertex_logic(vertex_id: int, entries: Array[VertexLogic]) -> bool:
	if not vertices.has(vertex_id): return false
	var logic_list := _get_or_create_logic_list(vertex_id)
	logic_list.entries = entries.duplicate(true)
	return true


func get_vertex_logic(vertex_id: int) -> Array[VertexLogic]:
	if not vertex_logic.has(vertex_id): return []
	var stored := vertex_logic.get(vertex_id)
	if stored is VertexLogicList:
		return (stored as VertexLogicList).entries
	return []


func get_door_definition(door_id: int) -> Door:
	if door_id < 0 or door_id >= doors.size():
		return null
	return doors[door_id]


func _get_or_create_logic_list(vertex_id: int) -> VertexLogicList:
	var stored := vertex_logic.get(vertex_id)
	if stored is VertexLogicList:
		var logic_list := stored as VertexLogicList
		if logic_list.entries.is_read_only():
			logic_list.entries = logic_list.entries.duplicate(true)
		return logic_list

	var logic_list := VertexLogicList.new()
	vertex_logic[vertex_id] = logic_list
	return logic_list