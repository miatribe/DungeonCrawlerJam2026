extends Node
class_name PlayerInput

@export var player_group_name: StringName = "player"

var _player: Player
var _input_locked := false


func _ready() -> void:
	_player = _resolve_player()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo: return

	match key_event.keycode:
		KEY_E: command_rotate_right()
		KEY_Q: command_rotate_left()
		KEY_W: command_move_forward()
		KEY_S: command_move_backward()
		KEY_D: command_move_right()
		KEY_A: command_move_left()
		KEY_R: command_interact()


func command_rotate_right() -> void:
	var player := _get_player()
	if player == null:
		return
	player.rotate_view(true)


func command_rotate_left() -> void:
	var player := _get_player()
	if player == null:
		return
	player.rotate_view(false)


func command_move_forward() -> void:
	if _input_locked:
		return
	var player := _get_player()
	if player == null:
		return
	player.try_move_relative(0)


func command_move_backward() -> void:
	if _input_locked:
		return
	var player := _get_player()
	if player == null:
		return
	player.try_move_relative(180)


func command_move_right() -> void:
	if _input_locked:
		return
	var player := _get_player()
	if player == null:
		return
	player.try_move_relative(90)


func command_move_left() -> void:
	if _input_locked:
		return
	var player := _get_player()
	if player == null:
		return
	player.try_move_relative(-90)


func command_attack() -> void:
	# In this ruleset, attack resolves by attempting to move into an occupied forward tile.
	command_move_forward()


func command_interact() -> void:
	if _input_locked:
		return
	var player := _get_player()
	if player == null:
		return
	player.try_interact()


func _get_player() -> Player:
	if is_instance_valid(_player): return _player
	_player = _resolve_player()
	return _player


func _resolve_player() -> Player:
	if get_tree() == null: return null
	var scope := get_parent()
	for node in get_tree().get_nodes_in_group(player_group_name):
		var player := node as Player
		if player == null: continue
		if scope != null and not scope.is_ancestor_of(player): continue
		return player
	return null


func set_input_locked(is_locked: bool) -> void:
	_input_locked = is_locked
