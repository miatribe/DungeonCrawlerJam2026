extends Node3D
class_name EnemyManager

const ENEMY_MANAGER_GROUP := "enemy_manager"

@export var graph_renderer: GraphRenderer
@export var player: Player
@export var turn_manager: TurnManager
@export var enemy_scene: PackedScene
@export var enemy_resources: Array[EnemyResource] = []
@export_range(0, 512, 1) var max_enemies: int = 4
@export_range(0, 512, 1) var min_spawn_distance_from_player: int = 3
@export var target_spawn_vertex_id: int = -1
@export var one_time_spawner: bool = false

var graph: Graph
var cell_size: float = 2.0
var navigation_helper: GraphNavigationHelper = GraphNavigationHelper.new()
var enemies: Array[Enemy] = []
var _has_spawned_wave: bool = false


func _ready() -> void:
	add_to_group(ENEMY_MANAGER_GROUP)
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


func has_required_references() -> bool: return graph != null and player != null


func get_player_vertex_id() -> int:
	if player == null: return -1
	return player.get_current_vertex_id()


func get_bfs_path(start_vertex_id: int, target_vertex_id: int) -> Array[int]:
	return navigation_helper.bfs_path_vertex_ids(graph, start_vertex_id, target_vertex_id, true)


func get_neighbor_vertex_ids(vertex_id: int) -> Array[int]:
	return navigation_helper.get_neighbor_vertex_ids(graph, vertex_id, true)


func get_vertex_world_position(vertex_id: int, current_y: float) -> Vector3:
	if graph == null: return Vector3.ZERO
	var vertex: Vertex = graph.vertices.get(vertex_id)
	if vertex == null: return Vector3.ZERO
	return Vector3(vertex.position.x * cell_size, current_y, vertex.position.y * cell_size)


func is_vertex_occupied_by_player(vertex_id: int) -> bool:
	var player_vertex_id := get_player_vertex_id()
	return player_vertex_id != -1 and player_vertex_id == vertex_id


func is_vertex_occupied_by_enemy(vertex_id: int, ignored_enemy: Enemy = null) -> bool:
	return _is_vertex_occupied_by_enemy(vertex_id, ignored_enemy)


func get_enemy_at_vertex(vertex_id: int, ignored_enemy: Enemy = null) -> Enemy:
	for manager in _get_all_enemy_managers():
		var enemy := manager._get_enemy_at_vertex_local(vertex_id, ignored_enemy)
		if enemy != null:
			return enemy
	return null


func is_vertex_blocked_for_player(vertex_id: int) -> bool: return is_vertex_occupied_by_enemy(vertex_id)


func is_vertex_blocked_for_enemy(vertex_id: int, ignored_enemy: Enemy = null) -> bool:
	if is_vertex_occupied_by_player(vertex_id): return true
	return is_vertex_occupied_by_enemy(vertex_id, ignored_enemy)


func run_all_enemy_turns() -> void:
	# Keep turn order stable based on this node's child order.
	_refresh_enemy_list()
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.take_turn()


func try_spawn_enemy() -> Enemy:
	if not has_required_references(): return null
	if enemy_scene == null:
		push_warning("Enemy scene is not assigned on EnemyManager.")
		return null
	_refresh_enemy_list()
	if enemies.size() >= max_enemies: return null
	var spawn_vertex_id := _find_spawn_vertex_id()
	if spawn_vertex_id == -1: return null
	var spawned := enemy_scene.instantiate()
	if not (spawned is Enemy):
		push_warning("Enemy scene root must use Enemy script.")
		if spawned != null: spawned.queue_free()
		return null
	var enemy := spawned as Enemy
	enemy.start_vertex_id = spawn_vertex_id
	var chosen_resource := _pick_random_enemy_resource()
	if chosen_resource != null: enemy.enemy_resource = chosen_resource
	else:
		push_warning("EnemyManager enemy_resources is empty. Add at least one EnemyResource to spawn enemies.")
		spawned.queue_free()
		return null
	add_child(enemy)
	_refresh_enemy_list()
	return enemy


func spawn_enemies_up_to_max() -> int:
	if one_time_spawner and _has_spawned_wave: return 0
	var spawned_count := 0
	while true:
		_refresh_enemy_list()
		if enemies.size() >= max_enemies: break
		var spawned := try_spawn_enemy()
		if spawned == null: break
		spawned_count += 1
	if one_time_spawner: _has_spawned_wave = true
	return spawned_count


func take_turn() -> void:
	spawn_enemies_up_to_max()
	run_all_enemy_turns()


func reset_spawn_cycle() -> void: _has_spawned_wave = false


func _refresh_enemy_list() -> void:
	enemies.clear()
	for child in get_children():
		if child is Enemy: enemies.append(child as Enemy)


func _find_spawn_vertex_id() -> int:
	if graph == null: return -1
	if target_spawn_vertex_id == -1: return -1
	if not graph.vertices.has(target_spawn_vertex_id): return -1
	var candidates: Array[int] = [target_spawn_vertex_id]
	for neighbor_id in get_neighbor_vertex_ids(target_spawn_vertex_id):
		if not candidates.has(neighbor_id): candidates.append(neighbor_id)
	for candidate_vertex_id in candidates:
		if _can_spawn_at_vertex(candidate_vertex_id): return candidate_vertex_id
	return -1


func _can_spawn_at_vertex(vertex_id: int) -> bool:
	if graph == null: return false
	if not graph.vertices.has(vertex_id): return false
	if _is_vertex_occupied_by_enemy(vertex_id): return false

	var player_vertex_id := get_player_vertex_id()
	if player_vertex_id != -1 and vertex_id == player_vertex_id: return false
	if min_spawn_distance_from_player <= 0: return true
	if player_vertex_id == -1: return true

	var path_to_player: Array[int] = get_bfs_path(vertex_id, player_vertex_id)
	# If unreachable, treat as sufficiently far for spawning.
	if path_to_player.is_empty(): return true

	var distance_to_player := maxi(path_to_player.size() - 1, 0)
	return distance_to_player >= min_spawn_distance_from_player


func _is_vertex_occupied_by_enemy(vertex_id: int, ignored_enemy: Enemy = null) -> bool:
	for manager in _get_all_enemy_managers():
		if manager._is_vertex_occupied_by_enemy_local(vertex_id, ignored_enemy):
			return true
	return false


func _is_vertex_occupied_by_enemy_local(vertex_id: int, ignored_enemy: Enemy = null) -> bool:
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if ignored_enemy != null and enemy == ignored_enemy: continue
		if enemy.current_vertex_id == vertex_id: return true
	return false


func _get_enemy_at_vertex_local(vertex_id: int, ignored_enemy: Enemy = null) -> Enemy:
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if ignored_enemy != null and enemy == ignored_enemy: continue
		if enemy.current_vertex_id == vertex_id: return enemy
	return null


func _get_all_enemy_managers() -> Array[EnemyManager]:
	var managers: Array[EnemyManager] = []
	if get_tree() != null:
		for node in get_tree().get_nodes_in_group(ENEMY_MANAGER_GROUP):
			if node is EnemyManager and is_instance_valid(node):
				managers.append(node as EnemyManager)
	if not managers.has(self ):
		managers.append(self )
	return managers


func _pick_random_enemy_resource() -> EnemyResource:
	var valid_resources: Array[EnemyResource] = []
	for resource in enemy_resources:
		if resource != null: valid_resources.append(resource)
	if valid_resources.is_empty(): return null
	return valid_resources.pick_random()


func _on_child_entered_tree(_node: Node) -> void: _refresh_enemy_list()


func _on_child_exiting_tree(_node: Node) -> void: _refresh_enemy_list()
