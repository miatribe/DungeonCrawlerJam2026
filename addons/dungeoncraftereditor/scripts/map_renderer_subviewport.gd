@tool
extends SubViewportContainer
class_name MapRendererSubViewport

@onready var sub_viewport: SubViewport = $SubViewport
@onready var map: MapRenderer = $SubViewport/Map


var _pan_remainder: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not gui_input.is_connected(_on_host_gui_input):
		gui_input.connect(_on_host_gui_input)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_sync_subviewport_size()


func _on_resized() -> void:
	_sync_subviewport_size()


func _sync_subviewport_size() -> void:
	if sub_viewport == null:
		return
	if stretch:
		map.queue_redraw()
		return
	var target_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if sub_viewport.size != target_size:
		sub_viewport.size = target_size
		map.queue_redraw()


func request_resize_sync() -> void:
	call_deferred("_sync_subviewport_size")


func _on_host_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_pan_remainder += event.relative
		var move_cells := Vector2i(int(_pan_remainder.x / map.CELL_SIZE.x), int(_pan_remainder.y / map.CELL_SIZE.y))
		if move_cells != Vector2i.ZERO:
			var move := Vector2(move_cells) * Vector2(map.CELL_SIZE)
			map.position += move
			_pan_remainder -= move
			map.queue_redraw()
		get_viewport().set_input_as_handled()
