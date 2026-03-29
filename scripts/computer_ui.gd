extends Control

@export var design_size := Vector2(1920.0, 1080.0)
@export var viewport_region_position := Vector2(21.0, 23.0)
@export var viewport_region_size := Vector2(1356.0, 747.0)

@onready var background: TextureRect = $TextureRect
@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var subviewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()


func _apply_layout() -> void:
	if design_size.x <= 0.0 or design_size.y <= 0.0:
		return

	var window_size := get_viewport_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var scale_factor := min(window_size.x / design_size.x, window_size.y / design_size.y)
	var scaled_size := design_size * scale_factor
	var origin := (window_size - scaled_size) * 0.5

	background.position = origin
	background.size = scaled_size

	viewport_container.position = origin + (viewport_region_position * scale_factor)
	viewport_container.size = viewport_region_size * scale_factor

	var scaled_subviewport_size := viewport_region_size * scale_factor
	subviewport.size = Vector2i(
		maxi(1, int(round(scaled_subviewport_size.x))),
		maxi(1, int(round(scaled_subviewport_size.y)))
	)
