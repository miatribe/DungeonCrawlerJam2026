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


func connect_vertices(vertex_a_id: int, vertex_b_id: int, direction_from_a: Direction.Cardinal, edge_type: Edge.EdgeType, door_state: int = 1, door_id: int = -1) -> Edge:
	var vertex_a := vertices.get(vertex_a_id)
	var vertex_b := vertices.get(vertex_b_id)
	var edge := Edge.new(_next_edge_id, vertex_a_id, vertex_b_id, direction_from_a)
	_next_edge_id += 1
	edges[edge.id] = edge
	assign_edge(vertex_a, direction_from_a, edge)
	assign_edge(vertex_b, Direction.get_opposite(direction_from_a), edge)
	edge.type = edge_type
	if edge_type == Edge.EdgeType.DOOR:
		edge.door_state = clampi(door_state, 0, Door.DoorState.size() - 1)
		edge.door_id = door_id
	else:
		edge.door_state = Door.DoorState.CLOSED
		edge.door_id = -1
	return edge

func assign_edge(vertex: Vertex, direction: Direction.Cardinal, edge: Edge) -> void: vertex.edges[direction] = edge


func add_logic_to_vertex(vertex_id: int, logic: VertexLogic) -> bool:
	if logic == null: return false
	if not vertices.has(vertex_id): return false
	var logic_list := _get_or_create_logic_list(vertex_id)
	var writable_entries: Array[VertexLogic] = logic_list.entries.duplicate(true)
	writable_entries.append(logic)
	logic_list.entries = writable_entries
	return true


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

	# Backward compatibility for old resources that serialized Array values.
	if stored is Array:
		var typed_entries: Array[VertexLogic] = []
		for entry in stored:
			if entry is VertexLogic: typed_entries.append(entry)
		var migrated := VertexLogicList.new()
		migrated.entries = typed_entries
		vertex_logic[vertex_id] = migrated
		return typed_entries

	return []


func clear_vertex_logic(vertex_id: int) -> void:
	vertex_logic.erase(vertex_id)


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
	if stored is Array:
		var stored_entries: Array = stored
		if stored_entries.is_read_only():
			stored_entries = stored_entries.duplicate(true)
		var writable_entries: Array[VertexLogic] = []
		for entry in stored_entries:
			if entry is VertexLogic:
				writable_entries.append(entry)
		logic_list.entries = writable_entries
	vertex_logic[vertex_id] = logic_list
	return logic_list