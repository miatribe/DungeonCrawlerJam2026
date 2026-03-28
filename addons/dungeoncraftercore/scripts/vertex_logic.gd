extends Resource
class_name VertexLogic


enum TriggerType {ON_ENTER, ON_INTERACT}

@export var logic_id: StringName = &""
@export var trigger_type: TriggerType = TriggerType.ON_ENTER
@export var required_direction: Direction.Cardinal = Direction.Cardinal.NONE
@export var one_shot: bool = true
@export var required_flags: Array[StringName] = []
@export var payload: Dictionary = {}


func can_run(active_flags: Dictionary[StringName, bool]) -> bool:
	for flag in required_flags:
		if not bool(active_flags.get(flag, false)):
			return false
	return true
