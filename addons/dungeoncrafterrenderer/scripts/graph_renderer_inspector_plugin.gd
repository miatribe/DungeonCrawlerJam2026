@tool
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is GraphRenderer


func _parse_begin(object: Object) -> void:
	var renderer := object as GraphRenderer
	if renderer == null:
		return

	var button := Button.new()
	button.text = "Render Graph"
	button.pressed.connect(_on_render_pressed.bind(renderer))
	add_custom_control(button)


func _on_render_pressed(renderer: GraphRenderer) -> void:
	if is_instance_valid(renderer):
		renderer.render_graph()
