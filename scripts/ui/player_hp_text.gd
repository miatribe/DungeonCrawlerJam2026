extends PanelContainer
class_name PlayerHpText

@export var player_path: NodePath
@export var auto_find_player: bool = true
@export_range(0.1, 5.0, 0.1) var auto_find_interval_seconds: float = 0.5
@export var auto_scale_font: bool = true
@export_range(8, 128, 1) var min_font_size: int = 12
@export_range(8, 256, 1) var max_font_size: int = 64
@export_range(0.1, 1.0, 0.05) var font_height_ratio: float = 0.62

var _player: Player
var _find_timer: float = 0.0
var _last_current_hp: int = -1
var _last_max_hp: int = -1
var _last_font_size: int = -1
@onready var _label: Label = %HealthLabel


func _ready() -> void:
	if _label != null:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.2, 1.0))
	set_health(0, 1)
	_resolve_player_reference()
	_refresh_from_player()
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = null
		_find_timer += delta
		if _find_timer >= auto_find_interval_seconds:
			_find_timer = 0.0
			_resolve_player_reference()
	_update_font_size()
	_refresh_from_player()


func set_player(player: Player) -> void:
	_player = player
	_refresh_from_player()


func set_health(current_hp: int, max_hp: int) -> void:
	var safe_max := maxi(1, max_hp)
	var safe_current := clampi(current_hp, 0, safe_max)
	_last_current_hp = safe_current
	_last_max_hp = safe_max
	if _label != null:
		_label.text = "%d/%d" % [safe_current, safe_max]


func _refresh_from_player() -> void:
	if _player == null:
		return
	var current_hp := _player.current_health
	var max_hp := _player.get_effective_max_health()
	if current_hp == _last_current_hp and max_hp == _last_max_hp:
		return
	set_health(current_hp, max_hp)


func _resolve_player_reference() -> void:
	if player_path != NodePath(""):
		var node := get_node_or_null(player_path)
		if node is Player:
			_player = node as Player
			return
	if not auto_find_player or get_tree() == null:
		return
	_player = _find_player_recursive(get_tree().root)


func _find_player_recursive(node: Node) -> Player:
	if node == null:
		return null
	if node is Player:
		return node as Player
	for child in node.get_children():
		var found := _find_player_recursive(child)
		if found != null:
			return found
	return null


func _update_font_size() -> void:
	if not auto_scale_font or _label == null:
		return
	var target_size := int(round(size.y * font_height_ratio))
	target_size = clampi(target_size, min_font_size, max_font_size)
	if target_size == _last_font_size:
		return
	_last_font_size = target_size
	_label.add_theme_font_size_override("font_size", target_size)
