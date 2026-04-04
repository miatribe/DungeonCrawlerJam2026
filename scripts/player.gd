extends Node3D
class_name Player

signal defeated

const TEXT_LOG_GROUP := "text_log"
const ENEMY_MANAGER_GROUP := "enemy_manager"

@export var graph_renderer: GraphRenderer
@export var turn_manager: TurnManager
@export var start_vertex_id: int = -1
@export var start_facing_direction: Direction.Cardinal = Direction.Cardinal.NORTH
@export var attack: int = 4
@export var defense: int = 1
@export var hit: int = 5
@export var dodge: int = 3
@export var max_health: int = 20

var _navigator: GraphNavigator = GraphNavigator.new()
var _run_state: DungeonRunState
var _logic_resolver: VertexLogicResolver = VertexLogicResolver.new()
var _cell_size: float = 2.0
var current_health: int = 20
var combat_stats: CombatStats = CombatStats.new()
var _text_log: TextLog
var _attack_bonus: int = 0
var _defense_bonus: int = 0
var _hit_bonus: int = 0
var _dodge_bonus: int = 0
var _max_health_bonus: int = 0
var _is_defeated := false

@onready var _move_sfx_player: RandomSfxPlayer = get_node_or_null("MoveSfx") as RandomSfxPlayer


func set_run_state(state: DungeonRunState) -> void:
	_run_state = state


func _ready() -> void:
	if _run_state == null:
		_run_state = DungeonRunState.new()
	if graph_renderer == null || not (graph_renderer is GraphRenderer):
		push_warning("GraphRenderer not assigned to Player.")
		return
	if start_vertex_id == -1:
		push_warning("Start vertex ID not set for Player.")
		return
	_text_log = _find_text_log()
	_log_message("Combat log connected.")
	combat_stats.set_values(attack + _attack_bonus, defense + _defense_bonus, hit + _hit_bonus, dodge + _dodge_bonus)
	current_health = maxi(1, max_health + _max_health_bonus)
	_is_defeated = false
	_set_facing_direction(start_facing_direction)
	_navigator.set_graph(graph_renderer.graph)
	_cell_size = graph_renderer.cell_size
	_navigator.vertex_entered.connect(_on_vertex_entered)
	if !_navigator.set_current_vertex(start_vertex_id, true): push_warning("Player did not find a valid start vertex.")


func rotate_view(clockwise: bool) -> bool:
	var rotation_delta := -90.0 if clockwise else 90.0
	rotate_y(deg_to_rad(rotation_delta))
	rotation_degrees.y = roundf(rotation_degrees.y)
	return true


func try_move_relative(relative_degrees: int) -> bool:
	if not _can_take_turn_action():
		return false
	var previous_vertex_id := _navigator.current_vertex_id

	var forward := _get_forward_direction()
	var move_direction := Direction.Cardinal.NONE
	match relative_degrees:
		0: move_direction = forward
		180: move_direction = Direction.get_opposite(forward)
		90: move_direction = Direction.get_rotated_direction(forward, 90)
		-90: move_direction = Direction.get_rotated_direction(forward, -90)
		_: return false

	if move_direction == Direction.Cardinal.NONE:
		return false

	if _try_move(move_direction):
		if _navigator.current_vertex_id != previous_vertex_id and _move_sfx_player != null:
			_move_sfx_player.play_random()
		_consume_player_turn()
		return true

	return false


func try_interact() -> bool:
	if not _can_take_turn_action():
		return false
	if _interact_current_vertex():
		_consume_player_turn()
		return true
	return false


func _on_vertex_entered(vertex_id: int, _previous_vertex_id: int, _via_direction: Direction.Cardinal) -> void:
	if _navigator.graph == null:
		return
	var vertex: Vertex = _navigator.graph.vertices.get(vertex_id)
	if vertex == null:
		return
	global_position = Vector3(vertex.position.x * _cell_size, global_position.y, vertex.position.y * _cell_size)
	_logic_resolver.apply_on_enter(_navigator.graph, _run_state, vertex_id)


func _interact_current_vertex() -> bool:
	if _navigator.graph == null:
		return false
	if _navigator.current_vertex_id < 0:
		return false
	_logic_resolver.apply_on_interact(_navigator.graph, _run_state, _navigator.current_vertex_id, _get_forward_direction())
	return true


func _get_forward_direction() -> Direction.Cardinal:
	var snapped_rotation := int(wrapi(roundi(rotation_degrees.y), 0, 360))
	match snapped_rotation:
		0: return Direction.Cardinal.NORTH
		90: return Direction.Cardinal.WEST
		180: return Direction.Cardinal.SOUTH
		270: return Direction.Cardinal.EAST
		_: return Direction.Cardinal.NONE


func _set_facing_direction(direction: Direction.Cardinal) -> void:
	match direction:
		Direction.Cardinal.NORTH: rotation_degrees.y = 0.0
		Direction.Cardinal.EAST: rotation_degrees.y = 270.0
		Direction.Cardinal.SOUTH: rotation_degrees.y = 180.0
		Direction.Cardinal.WEST: rotation_degrees.y = 90.0
		_: rotation_degrees.y = 0.0


func get_current_vertex_id() -> int:
	return _navigator.current_vertex_id


func get_navigation_graph() -> Graph:
	return _navigator.graph


func get_forward_direction() -> Direction.Cardinal:
	return _get_forward_direction()


func attack_enemy_at_vertex(vertex_id: int) -> bool:
	for manager in _get_enemy_managers():
		if manager.is_vertex_occupied_by_enemy(vertex_id):
			return _attack_enemy_at_vertex(vertex_id, manager)
	return false


func _can_take_turn_action() -> bool:
	if turn_manager == null: return true
	return turn_manager.is_player_turn


func _consume_player_turn() -> void:
	if turn_manager == null: return
	if turn_manager.is_player_turn: turn_manager.player_took_turn()


func _try_move(direction: Direction.Cardinal) -> bool:
	var target_vertex_id := _peek_target_vertex_id(direction)
	if target_vertex_id != -1:
		for manager in _get_enemy_managers():
			if manager.is_vertex_occupied_by_enemy(target_vertex_id):
				return _attack_enemy_at_vertex(target_vertex_id, manager)
		for manager in _get_enemy_managers():
			if manager.is_vertex_blocked_for_player(target_vertex_id):
				return false
	return _navigator.move(direction)


func _peek_target_vertex_id(direction: Direction.Cardinal) -> int:
	if _navigator.graph == null:
		return -1
	var current_vertex: Vertex = _navigator.graph.vertices.get(_navigator.current_vertex_id)
	if current_vertex == null:
		return -1
	if not current_vertex.edges.has(direction):
		return -1
	var edge: Edge = current_vertex.edges[direction]
	if edge == null:
		return -1
	if not edge.is_passable():
		return -1
	if edge.vertex_a_id == _navigator.current_vertex_id:
		return edge.vertex_b_id
	if edge.vertex_b_id == _navigator.current_vertex_id:
		return edge.vertex_a_id
	return -1


func _attack_enemy_at_vertex(vertex_id: int, manager: EnemyManager) -> bool:
	if manager == null:
		return false
	var enemy := manager.get_enemy_at_vertex(vertex_id)
	if enemy == null:
		return false
	var enemy_name := "Enemy"
	if enemy.enemy_resource != null:
		enemy_name = enemy.enemy_resource.name
	var result := CombatResolver.resolve_attack(combat_stats, enemy.combat_stats)
	if not result.hit:
		var miss_message := "You miss %s." % enemy_name
		print(miss_message)
		_log_message(miss_message)
		return true
	enemy.apply_damage(result.damage)
	var crit_text := " (CRIT)" if result.crit else ""
	var hit_message := "You hit %s for %d damage%s." % [enemy_name, result.damage, crit_text]
	print(hit_message)
	_log_message(hit_message)
	return true


func _get_enemy_managers() -> Array[EnemyManager]:
	var managers: Array[EnemyManager] = []
	if get_tree() == null:
		return managers
	for node in get_tree().get_nodes_in_group(ENEMY_MANAGER_GROUP):
		if not (node is EnemyManager):
			continue
		var manager := node as EnemyManager
		if not is_instance_valid(manager):
			continue
		if not managers.has(manager):
			managers.append(manager)
	return managers


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	if _is_defeated:
		return
	current_health = maxi(0, current_health - amount)
	_log_message("You take %d damage. HP: %d/%d" % [amount, current_health, get_effective_max_health()])
	if current_health == 0:
		_is_defeated = true
		print("You have been defeated.")
		_log_message("You have been defeated.")
		defeated.emit()


func respawn_to_start_full_health() -> void:
	current_health = get_effective_max_health()
	_is_defeated = false
	_set_facing_direction(start_facing_direction)
	if _navigator.graph == null:
		return
	if start_vertex_id == -1:
		return
	if not _navigator.set_current_vertex(start_vertex_id, true):
		push_warning("Player respawn failed: start vertex is invalid.")


func set_persistent_stat_bonuses(
		attack_bonus: int,
		defense_bonus: int,
		hit_bonus: int,
		dodge_bonus: int,
		max_health_bonus: int
	) -> void:
	var old_effective_max_health := get_effective_max_health()
	_attack_bonus = attack_bonus
	_defense_bonus = defense_bonus
	_hit_bonus = hit_bonus
	_dodge_bonus = dodge_bonus
	_max_health_bonus = max_health_bonus
	combat_stats.set_values(attack + _attack_bonus, defense + _defense_bonus, hit + _hit_bonus, dodge + _dodge_bonus)
	var new_effective_max_health := get_effective_max_health()
	if current_health <= 0:
		return
	if old_effective_max_health <= 0:
		current_health = new_effective_max_health
		return
	var health_ratio := float(current_health) / float(old_effective_max_health)
	current_health = clampi(int(round(health_ratio * float(new_effective_max_health))), 1, new_effective_max_health)


func get_effective_max_health() -> int:
	return maxi(1, max_health + _max_health_bonus)


func _log_message(message: String) -> void:
	if _text_log == null:
		_text_log = _find_text_log()
	if _text_log == null:
		return
	_text_log.add_message(message)


func _find_text_log() -> TextLog:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(TEXT_LOG_GROUP) as TextLog