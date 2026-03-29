extends Node3D
class_name Enemy


signal enemy_died()

@export var enemy_resource: EnemyResource
@export var start_vertex_id: int = -1


var enemy_manager: EnemyManager
var current_vertex_id: int = -1
var spawn_vertex_id: int = -1
var current_health: int = 1
var distance_to_target := -1
var is_aggressed: bool = false
var tween: Tween
var move_tween_time: float = 0.25

@onready var sprite_3d: Sprite3D = $Sprite3D

func _ready() -> void:
	if enemy_resource == null:
		push_warning("Enemy resource is not assigned.")
		return
	current_health = maxi(1, enemy_resource.health)
	sprite_3d.texture = enemy_resource.sprite
	enemy_manager = get_parent() as EnemyManager
	if enemy_manager == null:
		push_warning("Enemy parent must be EnemyManager.")
		return
	if not enemy_manager.has_required_references():
		push_warning("EnemyManager is missing graph/player references.")
		return
	if start_vertex_id == -1:
		push_warning("Start vertex ID not set for Enemy.")
		return
	if not enemy_manager.graph.vertices.has(start_vertex_id):
		push_warning("Enemy start vertex ID is invalid.")
		return
	current_vertex_id = start_vertex_id
	spawn_vertex_id = start_vertex_id
	global_position = enemy_manager.get_vertex_world_position(current_vertex_id, global_position.y)


func take_turn() -> void:
	if enemy_manager == null or not enemy_manager.has_required_references():
		return
	var player_vertex_id := enemy_manager.get_player_vertex_id()
	if current_vertex_id == -1 or player_vertex_id == -1:
		return

	var bfs_path: Array[int] = enemy_manager.get_bfs_path(current_vertex_id, player_vertex_id)
	distance_to_target = maxi(bfs_path.size() - 1, 0)

	if not is_aggressed and not bfs_path.is_empty() and distance_to_target <= enemy_resource.aggro_range:
		is_aggressed = true

	if distance_to_target == 1:
		attack()
		return

	if is_aggressed and bfs_path.size() >= 2:
		move_to_vertex(bfs_path[1])
		return

	move_to_vertex(get_random_connected_vertex_id())


func move_to_vertex(new_vertex_id: int) -> void:
	if new_vertex_id == -1:
		return
	if enemy_manager == null or enemy_manager.graph == null:
		return
	if not enemy_manager.graph.vertices.has(new_vertex_id):
		return
	if enemy_manager.is_vertex_occupied_by_player(new_vertex_id):
		attack()
		return
	if enemy_manager.is_vertex_blocked_for_enemy(new_vertex_id, self ):
		return
	if tween != null && tween.is_running(): tween.custom_step(move_tween_time)
	tween = create_tween()
	tween.tween_property(self , "global_position", enemy_manager.get_vertex_world_position(new_vertex_id, global_position.y), move_tween_time).set_ease(Tween.EASE_IN)
	current_vertex_id = new_vertex_id


func get_random_connected_vertex_id() -> int:
	if enemy_manager == null or current_vertex_id == -1:
		return -1
	var possible_vertex_ids: Array[int] = [current_vertex_id]
	for neighbor_id in enemy_manager.get_neighbor_vertex_ids(current_vertex_id):
		if not enemy_manager.is_vertex_blocked_for_enemy(neighbor_id, self ):
			possible_vertex_ids.append(neighbor_id)
	return possible_vertex_ids.pick_random()


func attack() -> void:
	if enemy_manager == null or enemy_manager.player == null:
		return
	var result := CombatResolver.resolve_attack(self , enemy_manager.player)
	if not result.hit:
		print("Enemy misses player from vertex %d" % current_vertex_id)
		return
	enemy_manager.player.apply_damage(result.damage)
	var crit_text := " (CRIT)" if result.crit else ""
	print("Enemy hits player for %d%s" % [result.damage, crit_text])


func get_attack() -> int:
	if enemy_resource == null:
		return 0
	return enemy_resource.attack


func get_defense() -> int:
	if enemy_resource == null:
		return 0
	return enemy_resource.defense


func get_hit() -> int:
	if enemy_resource == null:
		return 0
	return enemy_resource.hit


func get_dodge() -> int:
	if enemy_resource == null:
		return 0
	return enemy_resource.dodge


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	if current_health == 0:
		die()


func die() -> void:
	enemy_died.emit()
	queue_free()


func reset_agression() -> void:
	distance_to_target = -1
	is_aggressed = false
	if spawn_vertex_id != -1:
		move_to_vertex(spawn_vertex_id)
