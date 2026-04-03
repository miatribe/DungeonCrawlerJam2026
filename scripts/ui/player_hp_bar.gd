extends ProgressBar
class_name PlayerHpBar

@export var player_path: NodePath
@export var auto_find_player: bool = true
@export_range(0.1, 5.0, 0.1) var auto_find_interval_seconds: float = 0.5

var _player: Player
var _find_timer: float = 0.0
var _last_current_hp: int = -1
var _last_max_hp: int = -1


func _ready() -> void:
	show_percentage = false
	min_value = 0.0
	max_value = 1.0
	value = 1.0
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
	_refresh_from_player()


func set_player(player: Player) -> void:
	_player = player
	_refresh_from_player()


func set_health(current_hp: int, max_hp: int) -> void:
	var safe_max := maxi(1, max_hp)
	var safe_current := clampi(current_hp, 0, safe_max)
	_last_current_hp = safe_current
	_last_max_hp = safe_max
	min_value = 0.0
	max_value = float(safe_max)
	value = float(safe_current)


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
