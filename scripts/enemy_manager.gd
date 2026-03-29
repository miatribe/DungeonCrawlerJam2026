extends Node3D
class_name EnemyManager


@export var graph_renderer: GraphRenderer
@export var player: Player

var graph: Graph
var cell_size: float = 2.0
var navigation_helper: GraphNavigationHelper = GraphNavigationHelper.new()
var enemies: Array[Enemy] = []


func _ready() -> void:
	if graph_renderer == null or not (graph_renderer is GraphRenderer):
		push_warning("GraphRenderer not assigned to EnemyManager.")
		return
	graph = graph_renderer.graph
	cell_size = graph_renderer.cell_size
	if graph == null:
		push_warning("EnemyManager did not find a Graph on GraphRenderer.")
	_refresh_enemy_list()
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)


func has_required_references() -> bool:
	return graph != null and player != null


func get_player_vertex_id() -> int:
	if player == null:
		return -1
	return player.get_current_vertex_id()


func get_bfs_path(start_vertex_id: int, target_vertex_id: int) -> Array[int]:
	return navigation_helper.bfs_path_vertex_ids(graph, start_vertex_id, target_vertex_id, true)


func get_neighbor_vertex_ids(vertex_id: int) -> Array[int]:
	return navigation_helper.get_neighbor_vertex_ids(graph, vertex_id, true)


func get_vertex_world_position(vertex_id: int, current_y: float) -> Vector3:
	if graph == null:
		return Vector3.ZERO
	var vertex: Vertex = graph.vertices.get(vertex_id)
	if vertex == null:
		return Vector3.ZERO
	return Vector3(vertex.position.x * cell_size, current_y, vertex.position.y * cell_size)


func run_all_enemy_turns() -> void:
	# Keep turn order stable based on this node's child order.
	_refresh_enemy_list()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.take_turn()


func take_enemy_turns() -> void:
	run_all_enemy_turns()


func _refresh_enemy_list() -> void:
	enemies.clear()
	for child in get_children():
		if child is Enemy:
			enemies.append(child as Enemy)


func _on_child_entered_tree(_node: Node) -> void:
	_refresh_enemy_list()


func _on_child_exiting_tree(_node: Node) -> void:
	_refresh_enemy_list()
