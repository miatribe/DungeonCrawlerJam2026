extends RefCounted
class_name CombatStats

var attack: int = 0
var defense: int = 0
var hit: int = 0
var dodge: int = 0


func set_values(new_attack: int, new_defense: int, new_hit: int, new_dodge: int) -> void:
	attack = maxi(0, new_attack)
	defense = maxi(0, new_defense)
	hit = maxi(0, new_hit)
	dodge = maxi(0, new_dodge)
