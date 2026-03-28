extends Resource
class_name BspDungeonGenerator


var padding: int
var min_room_size: int
var max_room_size: int
var min_side: int
var max_depth: int
var max_room_tile_sets: int
var max_hallway_tile_sets: int
var random: RandomNumberGenerator


func generate(_size: Vector2i, _seed: int, _max_depth: int = 16, _min_room_size: int = 3, _max_room_size: int = 8, _padding: int = 1, _max_room_tile_sets: int = 1, _max_hallway_tile_sets: int = 1) -> Result:
	random = RandomNumberGenerator.new()
	random.seed = _seed
	max_depth = _max_depth
	min_room_size = _min_room_size
	max_room_size = _max_room_size
	max_room_tile_sets = _max_room_tile_sets
	max_hallway_tile_sets = _max_hallway_tile_sets
	padding = _padding
	min_side = min_room_size + padding * 2
	var graph = Graph.new()
	var vertex_lookup = {}
	var root = build_bsp_tree(BspNode.new(Rect2i(Vector2i.ZERO, _size)), 0)
	place_rooms_in_leaves(root, graph, vertex_lookup)
	connect_sibling_leaves(root, graph, vertex_lookup)
	return Result.new(graph, root)


func build_bsp_tree(node: BspNode, depth: int) -> BspNode:
	if depth >= max_depth || !can_split(node): return node
	var split = split_node(node)
	if split.left != null && split.right != null:
		node.left = split.left if !can_split(split.left) else build_bsp_tree(split.left, depth + 1)
		node.right = split.right if !can_split(split.right) else build_bsp_tree(split.right, depth + 1)
	return node


func split_node(node: BspNode) -> SplitResult:
	var split_vertical = can_split_vertical(node) && (!can_split_horizontal(node) || random.randf() < 0.5)
	var split_percent = random.randf_range(0.3, 0.7)
	if split_vertical:
		var min_x = node.box.position.x + min_side
		var max_x = node.box.position.x + node.box.size.x - min_side
		var split_pos = clamp(node.box.position.x + int(node.box.size.x * split_percent), min_x, max_x)
		var left_box = Rect2i(node.box.position, Vector2i(split_pos - node.box.position.x, node.box.size.y))
		var right_box = Rect2i(Vector2i(split_pos, node.box.position.y), Vector2i(node.box.size.x - (split_pos - node.box.position.x), node.box.size.y))
		return SplitResult.new(BspNode.new(left_box), BspNode.new(right_box))
	else:
		var min_y = node.box.position.y + min_side
		var max_y = node.box.position.y + node.box.size.y - min_side
		var split_pos = clamp(node.box.position.y + int(node.box.size.y * split_percent), min_y, max_y)
		var top_box = Rect2i(node.box.position, Vector2i(node.box.size.x, split_pos - node.box.position.y))
		var bottom_box = Rect2i(Vector2i(node.box.position.x, split_pos), Vector2i(node.box.size.x, node.box.size.y - (split_pos - node.box.position.y)))
		return SplitResult.new(BspNode.new(top_box), BspNode.new(bottom_box))


func can_split(node: BspNode) -> bool:
	return can_split_vertical(node) || can_split_horizontal(node)


func can_split_vertical(node: BspNode) -> bool:
	return node.box.size.x >= min_side * 2


func can_split_horizontal(node: BspNode) -> bool:
	return node.box.size.y >= min_side * 2


func place_rooms_in_leaves(node: BspNode, graph: Graph, vertex_lookup: Dictionary) -> void:
	if node.left == null && node.right == null:
		var room = create_room(node)
		node.vertex = add_room_to_graph(graph, vertex_lookup, room)
		return
	if node.left != null: place_rooms_in_leaves(node.left, graph, vertex_lookup)
	if node.right != null: place_rooms_in_leaves(node.right, graph, vertex_lookup)


func create_room(node: BspNode) -> Rect2i:
	# Calculate available space (accounting for padding on both sides)
	var available_width = node.box.size.x - padding * 2
	var available_height = node.box.size.y - padding * 2

	# Clamp to max room size
	var max_width = min(max_room_size, available_width)
	var max_height = min(max_room_size, available_height)

	# Generate room dimensions
	var room_width = random.randi_range(min_room_size, max_width)
	var room_height = random.randi_range(min_room_size, max_height)

	# Position room within the available space (with padding)
	var room_x = random.randi_range(node.box.position.x + padding, node.box.position.x + available_width - room_width + padding)
	var room_y = random.randi_range(node.box.position.y + padding, node.box.position.y + available_height - room_height + padding)

	return Rect2i(Vector2i(room_x, room_y), Vector2i(room_width, room_height))


func add_room_to_graph(graph: Graph, vertex_lookup: Dictionary, room: Rect2i) -> Vertex:
	var room_root_vertex: Vertex
	var room_tileset_id = random.randi_range(0, max_room_tile_sets - 1)
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			var pos = Vector2i(x, y)
			var vertex = graph.add_vertex(pos, Vertex.VertexType.ROOM)
			vertex.type_tileset_id = room_tileset_id
			vertex_lookup[pos] = vertex
			if room_root_vertex == null: room_root_vertex = vertex
	connect_room_vertices(graph, vertex_lookup, room)
	return room_root_vertex


func connect_room_vertices(graph: Graph, vertex_lookup: Dictionary, room: Rect2i) -> void:
	#this only works for rooms that are rectangular, because we flood fill
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			var current = vertex_lookup.get(Vector2i(x, y))
			if x + 1 < room.position.x + room.size.x:
				var neighbor = vertex_lookup.get(Vector2i(x + 1, y))
				_connect_vertices_if_missing(graph, current, neighbor, Direction.Cardinal.EAST, Edge.EdgeType.CORRIDOR)
			if y + 1 < room.position.y + room.size.y:
				var neighbor = vertex_lookup.get(Vector2i(x, y + 1))
				_connect_vertices_if_missing(graph, current, neighbor, Direction.Cardinal.SOUTH, Edge.EdgeType.CORRIDOR)


func connect_sibling_leaves(node: BspNode, graph: Graph, vertex_lookup: Dictionary) -> void:
	if node.left == null && node.right == null: return
	connect_sibling_leaves(node.left, graph, vertex_lookup)
	connect_sibling_leaves(node.right, graph, vertex_lookup)
	if node.left.vertex != null && node.right.vertex != null:
		var path = find_path_between_rooms(node.left.vertex, node.right.vertex, vertex_lookup)
		node.vertex = carve_hallway(graph, vertex_lookup, path)


func find_path_between_rooms(start: Vertex, end: Vertex, vertex_lookup: Dictionary) -> Array:
	var open_set = [start.position]
	var came_from = {}
	var g_score = {start.position: 0}
	var f_score = {start.position: start.position.distance_to(end.position)}
	while open_set.size() > 0:
		var current_pos = open_set[0]
		var current_idx = 0
		for i in range(open_set.size()):
			if f_score[open_set[i]] < f_score[current_pos]:
				current_pos = open_set[i]
				current_idx = i
		if current_pos == end.position:
			var path = [current_pos]
			while came_from.has(current_pos):
				current_pos = came_from[current_pos]
				path.insert(0, current_pos)
			return path
		open_set.remove_at(current_idx)
		for neighbor_pos in [current_pos + Vector2i.RIGHT, current_pos + Vector2i.LEFT, current_pos + Vector2i.UP, current_pos + Vector2i.DOWN]:
			var cost = 2
			#TODO I want to increase the cost of room corners
			#TODO I want to increase the cost of hallways connecting to room on a vertex that already has a hallway
			if vertex_lookup.has(neighbor_pos):
				var neighbor_vertex = vertex_lookup[neighbor_pos]
				if neighbor_vertex.type == Vertex.VertexType.HALLWAY: cost = 1
				if neighbor_vertex.type != Vertex.VertexType.HALLWAY:
					cost = 0
			var tentative_g = g_score[current_pos] + cost
			if !g_score.has(neighbor_pos) || tentative_g < g_score[neighbor_pos]:
				came_from[neighbor_pos] = current_pos
				g_score[neighbor_pos] = tentative_g
				f_score[neighbor_pos] = g_score[neighbor_pos] + neighbor_pos.distance_to(end.position)
				if neighbor_pos not in open_set:
					open_set.append(neighbor_pos)
	return [] # No path found


func carve_hallway(graph: Graph, vertex_lookup: Dictionary, path: Array) -> Vertex:
	var last_vertex: Vertex
	var hallway_tileset_id = random.randi_range(0, max_hallway_tile_sets - 1) # If we need this latter
	for i in range(path.size()):
		var current_vertex = get_or_create_vertex(graph, vertex_lookup, path[i], hallway_tileset_id)
		if i + 1 < path.size():
			var next_vertex = get_or_create_vertex(graph, vertex_lookup, path[i + 1], hallway_tileset_id)
			var direction = Direction.direction_from_delta(next_vertex.position - current_vertex.position)
			_connect_vertices_if_missing(graph, current_vertex, next_vertex, direction, Edge.EdgeType.CORRIDOR)
		last_vertex = current_vertex
	return last_vertex


func get_or_create_vertex(graph: Graph, vertex_lookup: Dictionary, pos: Vector2i, tileset_id: int) -> Vertex:
	var vertex = vertex_lookup.get(pos)
	if vertex == null:
		vertex = graph.add_vertex(pos, Vertex.VertexType.HALLWAY)
		vertex.type_tileset_id = tileset_id
		vertex_lookup[pos] = vertex
	return vertex


func _connect_vertices_if_missing(graph: Graph, vertex_a: Vertex, vertex_b: Vertex, direction_from_a: Direction.Cardinal, edge_type: Edge.EdgeType) -> void:
	var existing_edge: Edge = vertex_a.edges.get(direction_from_a)
	if existing_edge != null and _edge_connects_vertices(existing_edge, vertex_a.id, vertex_b.id): return
	graph.connect_vertices(vertex_a.id, vertex_b.id, direction_from_a, edge_type)


func _edge_connects_vertices(edge: Edge, a_id: int, b_id: int) -> bool: return (edge.vertex_a_id == a_id and edge.vertex_b_id == b_id) or (edge.vertex_a_id == b_id and edge.vertex_b_id == a_id)