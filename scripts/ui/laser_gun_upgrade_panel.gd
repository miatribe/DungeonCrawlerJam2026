@tool
extends TextureRect
class_name LaserGunUpgradePanel

@export var not_upgraded_texture: Texture2D = preload("res://assets/images/Laser_gun_panel__offline.png")
@export var upgraded_step_textures: Array[Texture2D] = [
	preload("res://assets/images/Laser_gun_panel_0.png"),
	preload("res://assets/images/Laser_gun_panel_1.png"),
	preload("res://assets/images/Laser_gun_panel_2.png"),
	preload("res://assets/images/Laser_gun_panel_3.png"),
	preload("res://assets/images/Laser_gun_panel_4.png"),
	preload("res://assets/images/Laser_gun_panel_5.png")
]
@export var starts_upgraded: bool = false:
	set(value):
		starts_upgraded = value
		if is_inside_tree():
			set_upgraded(starts_upgraded)
@export_range(0, 5, 1) var current_step: int = 0:
	set(value):
		current_step = clampi(value, 0, 5)
		if is_inside_tree():
			_update_texture()

var _is_upgraded: bool = false


func _enter_tree() -> void:
	_ensure_visible_defaults()
	set_upgraded(starts_upgraded)


func _ready() -> void:
	_ensure_visible_defaults()
	set_upgraded(starts_upgraded)


func set_upgraded(value: bool) -> void:
	_is_upgraded = value
	_update_texture()


func toggle_upgrade(value = null) -> void:
	# Supports both Button.pressed() and BaseButton.toggled(bool) connections.
	if value is bool:
		set_upgraded(value)
		return
	set_upgraded(not _is_upgraded)


func is_upgraded() -> bool:
	return _is_upgraded


func set_current_step(step: int) -> void:
	current_step = clampi(step, 0, 5)
	_update_texture()


func get_current_step() -> int:
	return current_step


func _update_texture() -> void:
	if not _is_upgraded:
		texture = not_upgraded_texture
		return
	if upgraded_step_textures.is_empty():
		texture = null
		return
	var safe_index := clampi(current_step, 0, upgraded_step_textures.size() - 1)
	texture = upgraded_step_textures[safe_index]


func _ensure_visible_defaults() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(256, 256)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	if texture == null:
		texture = not_upgraded_texture
