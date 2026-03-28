extends Resource
class_name DungeonRunState


@export var triggered_logic: Dictionary[StringName, bool] = {}
@export var world_flags: Dictionary[StringName, bool] = {}


func has_triggered(logic_id: StringName) -> bool:
	if logic_id == &"":
		return false
	return bool(triggered_logic.get(logic_id, false))


func mark_triggered(logic_id: StringName) -> void:
	if logic_id == &"":
		return
	triggered_logic[logic_id] = true


func has_flag(flag_id: StringName) -> bool:
	if flag_id == &"":
		return false
	return bool(world_flags.get(flag_id, false))


func set_flag(flag_id: StringName, value: bool = true) -> void:
	if flag_id == &"":
		return
	world_flags[flag_id] = value
