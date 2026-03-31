extends RefCounted
class_name MapStateStore

## Persists per-map graph mutations and a shared DungeonRunState across map swaps.
## Owned by Computer — not an autoload.

var run_state: DungeonRunState = DungeonRunState.new()

# Key: graph resource_path (String). Value: Dictionary with "edges" and "vertices".
var _map_states: Dictionary[String, Dictionary] = {}


func save_map_state(graph: Graph) -> void:
	if graph == null or graph.resource_path.is_empty():
		return

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

	_map_states[graph.resource_path] = {
		"edges": edge_snapshots,
		"vertices": vertex_snapshots,
	}


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
