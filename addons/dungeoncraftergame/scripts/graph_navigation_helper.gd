extends RefCounted
class_name GraphNavigationHelper


func get_neighbor_vertex_ids(graph: Graph, vertex_id: int, passable_only: bool = true) -> Array[int]:
	if graph == null:
		return []
	var vertex: Vertex = graph.vertices.get(vertex_id)
	if vertex == null:
		return []

	var neighbors: Array[int] = []
	for edge in vertex.edges.values():
		if edge == null:
			continue
		if passable_only and not edge.is_passable():
			continue
		var neighbor_id := _get_other_vertex_id(edge, vertex_id)
		if neighbor_id != -1 and graph.vertices.has(neighbor_id):
			neighbors.append(neighbor_id)
	return neighbors


func bfs_path_vertex_ids(graph: Graph, start_vertex_id: int, target_vertex_id: int, passable_only: bool = true) -> Array[int]:
	if graph == null:
		return []
	if not graph.vertices.has(start_vertex_id) or not graph.vertices.has(target_vertex_id):
		return []
	if start_vertex_id == target_vertex_id:
		return [start_vertex_id]

	var queue: Array[int] = [start_vertex_id]
	var visited: Dictionary[int, bool] = {start_vertex_id: true}
	var parent_by_vertex: Dictionary[int, int] = {}

	while not queue.is_empty():
		var current_vertex_id: int = queue.pop_front()
		for neighbor_id in get_neighbor_vertex_ids(graph, current_vertex_id, passable_only):
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			parent_by_vertex[neighbor_id] = current_vertex_id
			if neighbor_id == target_vertex_id:
				return _build_path_from_parents(parent_by_vertex, start_vertex_id, target_vertex_id)
			queue.append(neighbor_id)

	return []


func _build_path_from_parents(parent_by_vertex: Dictionary[int, int], start_vertex_id: int, target_vertex_id: int) -> Array[int]:
	var path: Array[int] = [target_vertex_id]
	var cursor := target_vertex_id
	while cursor != start_vertex_id:
		if not parent_by_vertex.has(cursor):
			return []
		cursor = parent_by_vertex[cursor]
		path.push_front(cursor)
	return path


func _get_other_vertex_id(edge: Edge, vertex_id: int) -> int:
	if edge.vertex_a_id == vertex_id:
		return edge.vertex_b_id
	if edge.vertex_b_id == vertex_id:
		return edge.vertex_a_id
	return -1
