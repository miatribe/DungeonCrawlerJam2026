extends Node
class_name TurnManager


signal PlayerTurnOver()
signal AITurnOver(int)

var is_player_turn: bool = true
var turn_count: int = 0


func player_took_turn() -> void:
	is_player_turn = false
	PlayerTurnOver.emit()


func ai_took_turn() -> void:
	is_player_turn = true
	turn_count += 1
	AITurnOver.emit(turn_count)