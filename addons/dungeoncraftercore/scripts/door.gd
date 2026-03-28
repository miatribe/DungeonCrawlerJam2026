extends Resource
class_name Door


enum DoorState {OPEN, CLOSED}
enum OpenAnimation {NONE, INSTANT_SWAP, SLIDE_VERTICAL}

@export var state: DoorState = DoorState.CLOSED
@export var base_texture: Texture2D
@export var closed_texture: Texture2D
@export var open_animation: OpenAnimation = OpenAnimation.NONE
@export_range(0.01, 30.0, 0.01) var open_animation_duration: float = 0.35
@export var open_animation_travel: float = 1.0


func is_passable() -> bool:
	return state == DoorState.OPEN


func get_closed_texture() -> Texture2D:
	if closed_texture != null:
		return closed_texture
	return base_texture


func get_texture_for_state(target_state: DoorState = state) -> Texture2D:
	if target_state == DoorState.OPEN:
		return base_texture
	return get_closed_texture()


func can_start_opening() -> bool:
	return state == DoorState.CLOSED


func open() -> bool:
	state = DoorState.OPEN
	return true


func close() -> void:
	state = DoorState.CLOSED


func sample_open_travel(open_progress: float) -> float:
	if open_animation != OpenAnimation.SLIDE_VERTICAL:
		return 0.0
	return lerpf(0.0, open_animation_travel, clampf(open_progress, 0.0, 1.0))
