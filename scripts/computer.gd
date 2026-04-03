extends Control

const STAT_BONUS_FLAG_PREFIX := &"stat_bonus_applied_"
const UPGRADE_INDICATOR_FLAG_PREFIX := &"upgrade_indicator_applied_"

@export var logic_scene_map: Dictionary[StringName, PackedScene] = {
	&"vertex_62_logic_1774834428": preload("res://scenes/MapOne.tscn")
}
@export var logic_message_map: Dictionary[StringName, String] = {}
@export var logic_stat_bonus_map: Dictionary[StringName, Dictionary] = {}
@export var logic_upgrade_indicator_map: Dictionary[StringName, NodePath] = {}
@export var minimap_unlock_logic_ids: Array[StringName] = []
@export var minimap_unlocked_by_default: bool = true
@export_range(0.0, 10.0, 0.1) var loading_screen_hold_seconds: float = 2.0

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport
@onready var _temp_loading_screen: Control = %LoadingScreen
@onready var _player_input: PlayerInput = $PlayerInput
@onready var _text_log: TextLog = %TextLog
@onready var _mini_map: MiniMap = %MiniMap

var _connected_graph: Graph
var _is_swapping_scene := false
var _map_state_store: MapStateStore = MapStateStore.new()


func _ready() -> void:
	if _temp_loading_screen != null: _temp_loading_screen.visible = false
	_inject_run_state_into_player()
	_connect_to_current_graph()
	_setup_mini_map()
	_apply_all_persistent_upgrade_indicators()


func _process(_delta: float) -> void:
	_sync_mini_map_context()


func _connect_to_current_graph() -> void:
	_disconnect_from_current_graph()
	if _subviewport == null or _subviewport.get_child_count() == 0:
		push_warning("Computer: SubViewport has no scene to connect to.")
		return
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		push_warning("Computer: SubViewport scene root is not a GraphRenderer.")
		return
	if graph_renderer.graph == null:
		push_warning("Computer: GraphRenderer has no Graph assigned.")
		return
	_connected_graph = graph_renderer.graph
	if not _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.connect(_on_vertex_logic_triggered)


func _disconnect_from_current_graph() -> void:
	if _connected_graph == null: return
	if _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.disconnect(_on_vertex_logic_triggered)
	_connected_graph = null


func _on_vertex_logic_triggered(_vertex_id: int, logic_id: StringName) -> void:
	if _is_swapping_scene: return
	if logic_message_map.has(logic_id) and _text_log != null:
		_text_log.add_message(logic_message_map[logic_id])
	_apply_logic_stat_bonus_once(logic_id)
	_apply_logic_upgrade_indicator_once(logic_id)
	if minimap_unlock_logic_ids.has(logic_id) and _mini_map != null:
		_mini_map.set_unlocked(true)
	if not logic_scene_map.has(logic_id): return
	var target_scene: PackedScene = logic_scene_map.get(logic_id)
	if target_scene == null:
		push_warning("Computer: Logic '%s' is mapped, but scene is null." % String(logic_id))
		return
	_swap_subviewport_scene_with_loading(target_scene)


func _swap_subviewport_scene_with_loading(scene: PackedScene) -> void:
	if scene == null: return
	_is_swapping_scene = true
	_set_player_movement_enabled(false)
	_set_loading_screen_visible(true)
	await get_tree().process_frame
	_save_current_map_state()
	_swap_subviewport_scene(scene)
	_restore_current_map_state()
	_inject_run_state_into_player()
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer != null: graph_renderer.render_graph()
	await get_tree().process_frame
	await get_tree().create_timer(maxf(0.0, loading_screen_hold_seconds)).timeout
	_set_loading_screen_visible(false)
	_set_player_movement_enabled(true)
	_connect_to_current_graph()
	_sync_mini_map_context()
	_is_swapping_scene = false


func _swap_subviewport_scene(scene: PackedScene) -> void:
	if scene == null or _subviewport == null: return
	for child in _subviewport.get_children():
		_subviewport.remove_child(child)
		child.queue_free()
	var next_scene := scene.instantiate()
	if next_scene == null:
		push_warning("Computer: Failed to instantiate replacement scene.")
		_set_loading_screen_visible(false)
		_set_player_movement_enabled(true)
		_is_swapping_scene = false
		return
	_subviewport.add_child(next_scene)


func _set_loading_screen_visible(new_is_visible: bool) -> void:
	if _temp_loading_screen != null:
		_temp_loading_screen.visible = new_is_visible


func _get_current_graph_renderer() -> GraphRenderer:
	if _subviewport == null or _subviewport.get_child_count() == 0: return null
	return _subviewport.get_child(0) as GraphRenderer


func _set_player_movement_enabled(is_enabled: bool) -> void:
	if _player_input == null: return
	_player_input.set_input_locked(not is_enabled)


func _save_current_map_state() -> void:
	if _connected_graph != null:
		_map_state_store.save_map_state(_connected_graph)


func _restore_current_map_state() -> void:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null or graph_renderer.graph == null:
		return
	_map_state_store.restore_map_state(graph_renderer.graph)


func _inject_run_state_into_player() -> void:
	var player := _get_current_player()
	if player != null:
		player.set_run_state(_map_state_store.run_state)
		_apply_all_persistent_logic_stat_bonuses(player)


func _apply_logic_stat_bonus_once(logic_id: StringName) -> void:
	if not logic_stat_bonus_map.has(logic_id):
		return
	var bonus_config: Dictionary = logic_stat_bonus_map.get(logic_id, {})
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	var flag_id := _get_stat_bonus_flag_id(logic_id)
	if run_state.has_flag(flag_id):
		return
	run_state.set_flag(flag_id, true)
	var player := _get_current_player()
	_log_stat_bonus_gain(player, bonus_config)
	if player != null:
		_apply_all_persistent_logic_stat_bonuses(player)


func _apply_all_persistent_logic_stat_bonuses(player: Player) -> void:
	if player == null:
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		player.set_persistent_stat_bonuses(0, 0, 0, 0, 0)
		return
	var attack_bonus := 0
	var defense_bonus := 0
	var hit_bonus := 0
	var dodge_bonus := 0
	var max_health_bonus := 0
	for key in logic_stat_bonus_map.keys():
		var logic_id := key as StringName
		if not run_state.has_flag(_get_stat_bonus_flag_id(logic_id)):
			continue
		var bonus_config: Dictionary = logic_stat_bonus_map.get(logic_id, {})
		attack_bonus += int(bonus_config.get(&"attack", 0))
		defense_bonus += int(bonus_config.get(&"defense", 0))
		hit_bonus += int(bonus_config.get(&"hit", 0))
		dodge_bonus += int(bonus_config.get(&"dodge", 0))
		max_health_bonus += int(bonus_config.get(&"max_health", 0))
	player.set_persistent_stat_bonuses(attack_bonus, defense_bonus, hit_bonus, dodge_bonus, max_health_bonus)


func _get_stat_bonus_flag_id(logic_id: StringName) -> StringName:
	return StringName(String(STAT_BONUS_FLAG_PREFIX) + String(logic_id))


func _apply_logic_upgrade_indicator_once(logic_id: StringName) -> void:
	if not logic_upgrade_indicator_map.has(logic_id):
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	var flag_id := _get_upgrade_indicator_flag_id(logic_id)
	if run_state.has_flag(flag_id):
		return
	run_state.set_flag(flag_id, true)
	_apply_indicator_upgrade(logic_id)


func _apply_all_persistent_upgrade_indicators() -> void:
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	for key in logic_upgrade_indicator_map.keys():
		var logic_id := key as StringName
		if run_state.has_flag(_get_upgrade_indicator_flag_id(logic_id)):
			_apply_indicator_upgrade(logic_id)


func _apply_indicator_upgrade(logic_id: StringName) -> void:
	if not logic_upgrade_indicator_map.has(logic_id):
		return
	var node_path: NodePath = logic_upgrade_indicator_map.get(logic_id)
	if node_path == NodePath(""):
		return
	var node := get_node_or_null(node_path)
	if node == null:
		push_warning("Computer: UpgradeIndicator path not found for logic '%s': %s" % [String(logic_id), String(node_path)])
		return
	if not (node is UpgradeIndicator):
		push_warning("Computer: Node at path '%s' for logic '%s' is not an UpgradeIndicator." % [String(node_path), String(logic_id)])
		return
	(node as UpgradeIndicator).set_upgraded(true)


func _get_upgrade_indicator_flag_id(logic_id: StringName) -> StringName:
	return StringName(String(UPGRADE_INDICATOR_FLAG_PREFIX) + String(logic_id))


func _log_stat_bonus_gain(player: Player, bonus_config: Dictionary) -> void:
	if _text_log == null:
		return
	var parts: Array[String] = []

	var attack_gain := int(bonus_config.get(&"attack", 0))
	if attack_gain != 0:
		var base_attack := player.attack if player != null else 0
		parts.append("Attack %d + %d" % [base_attack, attack_gain])

	var defense_gain := int(bonus_config.get(&"defense", 0))
	if defense_gain != 0:
		var base_defense := player.defense if player != null else 0
		parts.append("Defense %d + %d" % [base_defense, defense_gain])

	var hit_gain := int(bonus_config.get(&"hit", 0))
	if hit_gain != 0:
		var base_hit := player.hit if player != null else 0
		parts.append("Hit %d + %d" % [base_hit, hit_gain])

	var dodge_gain := int(bonus_config.get(&"dodge", 0))
	if dodge_gain != 0:
		var base_dodge := player.dodge if player != null else 0
		parts.append("Dodge %d + %d" % [base_dodge, dodge_gain])

	var max_health_gain := int(bonus_config.get(&"max_health", 0))
	if max_health_gain != 0:
		var base_max_health := player.max_health if player != null else 0
		parts.append("Max HP %d + %d" % [base_max_health, max_health_gain])

	if parts.is_empty():
		return
	_text_log.add_message("Stat gain: %s" % ", ".join(parts))


func _setup_mini_map() -> void:
	if _mini_map == null:
		return
	_mini_map.set_unlocked(minimap_unlocked_by_default)
	_sync_mini_map_context()


func _sync_mini_map_context() -> void:
	if _mini_map == null:
		return
	var graph_renderer := _get_current_graph_renderer()
	var player := _get_current_player()
	if graph_renderer == null:
		_mini_map.set_context(null, player)
		return
	_mini_map.set_context(graph_renderer.graph, player)


func _get_current_player() -> Player:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		return null
	for child in graph_renderer.get_children():
		if child is Player:
			return child as Player
	return null
