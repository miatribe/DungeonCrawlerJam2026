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
