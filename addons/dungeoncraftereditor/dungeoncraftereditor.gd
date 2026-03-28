@tool
extends EditorPlugin

var panel: Control

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	panel = preload("res://addons/dungeoncraftereditor/scenes/editor_panel.tscn").instantiate()
	panel.name = "DungeonCrafter"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	EditorInterface.get_editor_main_screen().add_child(panel)


func _exit_tree() -> void:
	if panel != null:
		panel.queue_free()
		panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if panel != null:
		if visible:
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = visible


func _get_plugin_name() -> String:
	return "DungeonCrafter"


func _get_plugin_icon() -> Texture2D:
	var base := get_editor_interface().get_base_control()
	if base.has_theme_icon("TileSet", "EditorIcons"):
		return base.get_theme_icon("TileSet", "EditorIcons")
	if base.has_theme_icon("TileMap", "EditorIcons"):
		return base.get_theme_icon("TileMap", "EditorIcons")
	if base.has_theme_icon("TileMapLayer", "EditorIcons"):
		return base.get_theme_icon("TileMapLayer", "EditorIcons")
	if base.has_theme_icon("TileSetAtlasSource", "EditorIcons"):
		return base.get_theme_icon("TileSetAtlasSource", "EditorIcons")
	return base.get_theme_icon("Node", "EditorIcons")
