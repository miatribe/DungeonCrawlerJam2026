extends Node3D
class_name Player

const TEXT_LOG_GROUP := "text_log"

@export var graph_renderer: GraphRenderer
@export var turn_manager: TurnManager
@export var enemy_manager: EnemyManager
@export var start_vertex_id: int = -1
@export var start_facing_direction: Direction.Cardinal = Direction.Cardinal.NORTH
@export var attack: int = 4
@export var defense: int = 1
@export var hit: int = 5
@export var dodge: int = 3
@export var max_health: int = 20

var _navigator: GraphNavigator = GraphNavigator.new()
var _run_state: DungeonRunState = DungeonRunState.new()
var _logic_resolver: VertexLogicResolver = VertexLogicResolver.new()
var _cell_size: float = 2.0
var current_health: int = 20
var combat_stats: CombatStats = CombatStats.new()
var _text_log: TextLog


func _ready() -> void:
	if graph_renderer == null || not (graph_renderer is GraphRenderer):
		push_warning("GraphRenderer not assigned to Player.")
		return
	if start_vertex_id == -1:
		push_warning("Start vertex ID not set for Player.")
		return
	_text_log = _find_text_log()
	_log_message("Combat log connected.")
	combat_stats.set_values(attack, defense, hit, dodge)
	current_health = maxi(1, max_health)
	_set_facing_direction(start_facing_direction)
	_navigator.set_graph(graph_renderer.graph)
	_cell_size = graph_renderer.cell_size
	_navigator.vertex_entered.connect(_on_vertex_entered)
	_navigator.movement_blocked.connect(_on_movement_blocked)
	if !_navigator.set_current_vertex(start_vertex_id, true): push_warning("Player did not find a valid start vertex.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo: return

	# Rotating is always allowed and does not consume a turn.
	if key_event.keycode == KEY_E:
		rotate_y(deg_to_rad(-90))
		rotation_degrees.y = roundf(rotation_degrees.y)
		return
	if key_event.keycode == KEY_Q:
		rotate_y(deg_to_rad(90))
		rotation_degrees.y = roundf(rotation_degrees.y)
		return

	if not _can_take_turn_action():
		return

	var forward := _get_forward_direction()
	var move_direction := _get_move_direction(key_event.keycode, forward)
	if move_direction != Direction.Cardinal.NONE:
		if _try_move(move_direction):
			_consume_player_turn()
		return

	if key_event.keycode == KEY_R:
		if _interact_current_vertex():
			_consume_player_turn()


func _on_vertex_entered(vertex_id: int, _previous_vertex_id: int, _via_direction: Direction.Cardinal) -> void:
	if _navigator.graph == null:
		return
	var vertex: Vertex = _navigator.graph.vertices.get(vertex_id)
	if vertex == null:
		return
	global_position = Vector3(vertex.position.x * _cell_size, global_position.y, vertex.position.y * _cell_size)
	_logic_resolver.apply_on_enter(_navigator.graph, _run_state, vertex_id)


func _on_movement_blocked(_from_vertex_id: int, _direction: Direction.Cardinal, reason: StringName) -> void:
	push_warning("Movement blocked: %s" % String(reason))


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


func _get_move_direction(keycode: int, forward: Direction.Cardinal) -> Direction.Cardinal:
	match keycode:
		KEY_W: return forward
		KEY_S: return Direction.get_opposite(forward)
		KEY_D: return Direction.get_rotated_direction(forward, 90)
		KEY_A: return Direction.get_rotated_direction(forward, -90)
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


func _can_take_turn_action() -> bool:
	if turn_manager == null: return true
	return turn_manager.is_player_turn


func _consume_player_turn() -> void:
	if turn_manager == null: return
	if turn_manager.is_player_turn: turn_manager.player_took_turn()


func _try_move(direction: Direction.Cardinal) -> bool:
	var target_vertex_id := _peek_target_vertex_id(direction)
	if target_vertex_id != -1 and enemy_manager != null:
		if enemy_manager.is_vertex_occupied_by_enemy(target_vertex_id):
			return _attack_enemy_at_vertex(target_vertex_id)
		if enemy_manager.is_vertex_blocked_for_player(target_vertex_id):
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


func _attack_enemy_at_vertex(vertex_id: int) -> bool:
	if enemy_manager == null:
		return false
	var enemy := enemy_manager.get_enemy_at_vertex(vertex_id)
	if enemy == null:
		return false
	var result := CombatResolver.resolve_attack(combat_stats, enemy.combat_stats)
	if not result.hit:
		var miss_message := "Player misses enemy on vertex %d" % vertex_id
		print(miss_message)
		_log_message(miss_message)
		return true
	enemy.apply_damage(result.damage)
	var crit_text := " (CRIT)" if result.crit else ""
	var hit_message := "Player hits enemy for %d%s on vertex %d" % [result.damage, crit_text, vertex_id]
	print(hit_message)
	_log_message(hit_message)
	return true


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	_log_message("Player takes %d damage. HP: %d/%d" % [amount, current_health, max_health])
	if current_health == 0:
		print("Player has been defeated.")
		_log_message("Player has been defeated.")


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
