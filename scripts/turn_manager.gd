extends Node
class_name TurnManager

const ENEMY_MANAGER_GROUP := "enemy_manager"


signal PlayerTurnOver()
signal AITurnOver(int)

var is_player_turn: bool = true
var turn_count: int = 0
var _has_completed_initial_ai_turn: bool = false


func player_took_turn() -> void:
	is_player_turn = false
	PlayerTurnOver.emit()
	_run_ai_turns()
	ai_took_turn()


func run_initial_ai_turn() -> void:
	if _has_completed_initial_ai_turn:
		return
	is_player_turn = false
	_run_ai_turns()
	ai_took_turn()
	_has_completed_initial_ai_turn = true


func ai_took_turn() -> void:
	is_player_turn = true
	turn_count += 1
	AITurnOver.emit(turn_count)


func _run_ai_turns() -> void:
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group(ENEMY_MANAGER_GROUP):
		if node is EnemyManager and is_instance_valid(node):
			(node as EnemyManager).take_turn()