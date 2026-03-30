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

	var player := _get_player()
	if player == null: return

	# Rotation is available on any turn.
	if key_event.keycode == KEY_E: player.rotate_view(true)
	if key_event.keycode == KEY_Q: player.rotate_view(false)

	if _input_locked: return

	match key_event.keycode:
		KEY_W: player.try_move_relative(0)
		KEY_S: player.try_move_relative(180)
		KEY_D: player.try_move_relative(90)
		KEY_A: player.try_move_relative(-90)
		KEY_R: player.try_interact()


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
