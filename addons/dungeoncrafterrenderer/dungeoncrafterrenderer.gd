@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	var graph_renderer_script := preload("res://addons/dungeoncrafterrenderer/scripts/graph_renderer.gd")
	add_custom_type("GraphRenderer", "Node3D", graph_renderer_script, null)

	var inspector_plugin_script := preload("res://addons/dungeoncrafterrenderer/scripts/graph_renderer_inspector_plugin.gd")
	_inspector_plugin = inspector_plugin_script.new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	remove_custom_type("GraphRenderer")
