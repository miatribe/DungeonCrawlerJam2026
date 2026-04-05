extends RefCounted
class_name MapStateStore

## Persists per-map graph mutations and a shared DungeonRunState across map swaps.
## Owned by Computer — not an autoload.

var run_state: DungeonRunState = DungeonRunState.new()

# Key: graph resource_path (String). Value: Dictionary with "edges" and "vertices".
var _map_states: Dictionary[String, Dictionary] = {}


func set_edge_state_for_map(map_path: String, edge_id: int, edge_type: int = -1, door_state: int = -1) -> void:
	if map_path.is_empty() or edge_id < 0:
		return
	_ensure_map_state_for_path(map_path)
	if not _map_states.has(map_path):
		return

	var state: Dictionary = _map_states.get(map_path, {})
	var edge_snapshots: Dictionary = state.get("edges", {})
	if not edge_snapshots.has(edge_id):
		return

	var snap: Dictionary = edge_snapshots.get(edge_id, {})
	if edge_type >= 0:
		snap["type"] = edge_type
	if door_state >= 0:
		snap["door_state"] = door_state
	edge_snapshots[edge_id] = snap
	state["edges"] = edge_snapshots
	_map_states[map_path] = state


func save_map_state(graph: Graph) -> void:
	if graph == null or graph.resource_path.is_empty():
		return
	_map_states[graph.resource_path] = _build_state_from_graph(graph)


func restore_map_state(graph: Graph) -> void:
	if graph == null or graph.resource_path.is_empty():
		return
	if not _map_states.has(graph.resource_path):
		return

	var state: Dictionary = _map_states[graph.resource_path]

	var edge_snapshots: Dictionary = state.get("edges", {})
	for edge_id: int in edge_snapshots:
		var edge: Edge = graph.edges.get(edge_id)
		if edge == null:
			continue
		var snap: Dictionary = edge_snapshots[edge_id]
		edge.type = int(snap["type"]) as Edge.EdgeType
		edge.door_id = int(snap["door_id"])
		edge.door_state = int(snap["door_state"])

	var vertex_snapshots: Dictionary = state.get("vertices", {})
	for vertex_id: int in vertex_snapshots:
		var vertex: Vertex = graph.vertices.get(vertex_id)
		if vertex == null:
			continue
		var snap: Dictionary = vertex_snapshots[vertex_id]
		vertex.surface_texture_overrides = snap["surface_texture_overrides"].duplicate()


func _ensure_map_state_for_path(map_path: String) -> void:
	if _map_states.has(map_path):
		return
	var loaded := ResourceLoader.load(map_path)
	if not (loaded is Graph):
		return
	var graph := loaded as Graph
	_map_states[map_path] = _build_state_from_graph(graph)


func _build_state_from_graph(graph: Graph) -> Dictionary:
	var edge_snapshots: Dictionary[int, Dictionary] = {}
	for edge_id: int in graph.edges:
		var edge: Edge = graph.edges[edge_id]
		edge_snapshots[edge_id] = {
			"type": int(edge.type),
			"door_id": edge.door_id,
			"door_state": int(edge.door_state),
		}

	var vertex_snapshots: Dictionary[int, Dictionary] = {}
	for vertex_id: int in graph.vertices:
		var vertex: Vertex = graph.vertices[vertex_id]
		if vertex.surface_texture_overrides.size() > 0:
			vertex_snapshots[vertex_id] = {
				"surface_texture_overrides": vertex.surface_texture_overrides.duplicate(),
			}

	return {
		"edges": edge_snapshots,
		"vertices": vertex_snapshots,
	}
