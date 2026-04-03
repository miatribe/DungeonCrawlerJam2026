@tool
extends TextureRect
class_name UpgradeIndicator

@export var not_upgraded_texture: Texture2D = preload("res://assets/images/Battery_panel_Off.png")
@export var upgraded_texture: Texture2D = preload("res://assets/images/Battery_panel_ON.png")
@export var starts_upgraded: bool = false:
	set(value):
		starts_upgraded = value
		if is_inside_tree():
			set_upgraded(starts_upgraded)

var _is_upgraded: bool = false


func _enter_tree() -> void:
	_ensure_visible_defaults()
	set_upgraded(starts_upgraded)


func _ready() -> void:
	_ensure_visible_defaults()
	set_upgraded(starts_upgraded)


func set_upgraded(value: bool) -> void:
	_is_upgraded = value
	texture = upgraded_texture if _is_upgraded else not_upgraded_texture


func toggle_upgrade(value = null) -> void:
	# Supports both Button.pressed() and BaseButton.toggled(bool) connections.
	if value is bool:
		set_upgraded(value)
		return
	set_upgraded(not _is_upgraded)


func is_upgraded() -> bool:
	return _is_upgraded


func _ensure_visible_defaults() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(256, 256)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	if texture == null:
		texture = not_upgraded_texture
