extends Control

const STAT_BONUS_FLAG_PREFIX := &"stat_bonus_applied_"
const UPGRADE_INDICATOR_FLAG_PREFIX := &"upgrade_indicator_applied_"
const LASER_PANEL_FLAG_PREFIX := &"laser_panel_applied_"
const BATTERY_PICKUP_FLAG_PREFIX := &"battery_pickup_collected_"
const LASER_PANEL_MAX_STEP := 5

@export var logic_scene_map: Dictionary[StringName, PackedScene] = {
	&"vertex_62_logic_1774834428": preload("res://scenes/MapOne.tscn")
}
@export var logic_message_map: Dictionary[StringName, String] = {}
@export var logic_stat_bonus_map: Dictionary[StringName, Dictionary] = {}
@export var logic_upgrade_indicator_map: Dictionary[StringName, NodePath] = {}
@export var laser_upgrade_logic_id: StringName = &""
@export_range(0, 5, 1) var laser_upgrade_step: int = 0
@export var minimap_unlock_logic_ids: Array[StringName] = []
@export var minimap_unlocked_by_default: bool = true
@export_range(0.0, 10.0, 0.1) var loading_screen_hold_seconds: float = 2.0
@export var battery_pickup_map: Dictionary[String, Dictionary] = {
	"res://assets/graphs/Maze.tres": {
		&"vertex_id": 6,
		&"texture": preload("res://assets/images/Battery_pack.png"),
	},
		"res://assets/graphs/TestGraph.tres": {
		&"vertex_id": 131,
		&"texture": preload("res://assets/images/laser_gun.png"),
	}
}


@export var default_battery_pickup_texture: Texture2D = preload("res://assets/images/Battery_pack.png")
@export_range(0.0, 10.0, 0.1) var default_battery_pickup_height: float = 0.6
@export_range(0.0001, 0.05, 0.0001) var default_battery_pickup_pixel_size: float = 0.002

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport
@onready var _temp_loading_screen: Control = %LoadingScreen
@onready var _player_input: PlayerInput = $PlayerInput
@onready var _text_log: TextLog = %TextLog
@onready var _mini_map: MiniMap = %MiniMap
@onready var _btn_move_forward: Button = $AspectRatioContainer/DesignRoot/MoveFoward
@onready var _btn_move_backward: Button = $AspectRatioContainer/DesignRoot/MoveBackwards
@onready var _btn_move_left: Button = $AspectRatioContainer/DesignRoot/MoveLeft
@onready var _btn_move_right: Button = $AspectRatioContainer/DesignRoot/MoveRight
@onready var _btn_rotate_left: Button = $AspectRatioContainer/DesignRoot/RotLeft
@onready var _btn_rotate_right: Button = $AspectRatioContainer/DesignRoot/RotRight
@onready var _btn_attack: Button = $AspectRatioContainer/DesignRoot/Attack
@onready var _btn_interact: Button = $AspectRatioContainer/DesignRoot/Interact
@onready var _laser_gun_upgrade_panel: LaserGunUpgradePanel = $AspectRatioContainer/DesignRoot/LaserGunUpgradePanel

var _connected_graph: Graph
var _connected_turn_manager: TurnManager
var _is_swapping_scene := false
var _map_state_store: MapStateStore = MapStateStore.new()
var _battery_pickup_sprite: Sprite3D


func _ready() -> void:
	if _temp_loading_screen != null: _temp_loading_screen.visible = false
	_wire_button_actions()
	_inject_run_state_into_player()
	_connect_to_current_graph()
	_refresh_battery_pickup_visual()
	_setup_mini_map()
	_apply_all_persistent_upgrade_indicators()
	_apply_all_persistent_laser_panel_upgrades()


func _wire_button_actions() -> void:
	if _btn_move_forward != null and not _btn_move_forward.pressed.is_connected(_on_move_forward_pressed):
		_btn_move_forward.pressed.connect(_on_move_forward_pressed)
	if _btn_move_backward != null and not _btn_move_backward.pressed.is_connected(_on_move_backward_pressed):
		_btn_move_backward.pressed.connect(_on_move_backward_pressed)
	if _btn_move_left != null and not _btn_move_left.pressed.is_connected(_on_move_left_pressed):
		_btn_move_left.pressed.connect(_on_move_left_pressed)
	if _btn_move_right != null and not _btn_move_right.pressed.is_connected(_on_move_right_pressed):
		_btn_move_right.pressed.connect(_on_move_right_pressed)
	if _btn_rotate_left != null and not _btn_rotate_left.pressed.is_connected(_on_rotate_left_pressed):
		_btn_rotate_left.pressed.connect(_on_rotate_left_pressed)
	if _btn_rotate_right != null and not _btn_rotate_right.pressed.is_connected(_on_rotate_right_pressed):
		_btn_rotate_right.pressed.connect(_on_rotate_right_pressed)
	if _btn_attack != null and not _btn_attack.pressed.is_connected(_on_attack_pressed):
		_btn_attack.pressed.connect(_on_attack_pressed)
	if _btn_interact != null and not _btn_interact.pressed.is_connected(_on_interact_pressed):
		_btn_interact.pressed.connect(_on_interact_pressed)


func _on_move_forward_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_move_forward()


func _on_move_backward_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_move_backward()


func _on_move_left_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_move_left()


func _on_move_right_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_move_right()


func _on_rotate_left_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_rotate_left()


func _on_rotate_right_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_rotate_right()


func _on_attack_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_attack()


func _on_interact_pressed() -> void:
	if _player_input == null:
		return
	_player_input.command_interact()


func _process(_delta: float) -> void:
	_sync_mini_map_context()
	_update_battery_pickup_collection()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F:
		return
	_try_fire_laser()


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
	_connect_to_current_turn_manager()
	_refresh_battery_pickup_visual()


func _disconnect_from_current_graph() -> void:
	if _connected_graph == null: return
	if _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.disconnect(_on_vertex_logic_triggered)
	_connected_graph = null
	_disconnect_from_current_turn_manager()
	_clear_battery_pickup_sprite()


func _on_vertex_logic_triggered(_vertex_id: int, logic_id: StringName) -> void:
	if _is_swapping_scene: return
	if logic_message_map.has(logic_id) and _text_log != null:
		_text_log.add_message(logic_message_map[logic_id])
	_apply_logic_stat_bonus_once(logic_id)
	_apply_logic_upgrade_indicator_once(logic_id)
	_apply_logic_laser_panel_upgrade_once(logic_id)
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
	_refresh_battery_pickup_visual()
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


func _get_current_turn_manager() -> TurnManager:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		return null
	for child in graph_renderer.get_children():
		if child is TurnManager:
			return child as TurnManager
	return null


func _connect_to_current_turn_manager() -> void:
	_disconnect_from_current_turn_manager()
	var turn_manager := _get_current_turn_manager()
	if turn_manager == null:
		return
	_connected_turn_manager = turn_manager
	if not _connected_turn_manager.PlayerTurnOver.is_connected(_on_player_turn_over):
		_connected_turn_manager.PlayerTurnOver.connect(_on_player_turn_over)


func _disconnect_from_current_turn_manager() -> void:
	if _connected_turn_manager == null:
		return
	if _connected_turn_manager.PlayerTurnOver.is_connected(_on_player_turn_over):
		_connected_turn_manager.PlayerTurnOver.disconnect(_on_player_turn_over)
	_connected_turn_manager = null


func _on_player_turn_over() -> void:
	_advance_laser_upgrade_step()


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
	_log_stat_bonus_gain(player, bonus_config, logic_id)
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


func _apply_logic_laser_panel_upgrade_once(logic_id: StringName) -> void:
	if laser_upgrade_logic_id == &"":
		return
	if logic_id != laser_upgrade_logic_id:
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	var flag_id := _get_laser_panel_flag_id()
	if run_state.has_flag(flag_id):
		return
	run_state.set_flag(flag_id, true)
	_apply_laser_panel_upgrade()


func _apply_all_persistent_laser_panel_upgrades() -> void:
	if laser_upgrade_logic_id == &"":
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	if run_state.has_flag(_get_laser_panel_flag_id()):
		_apply_laser_panel_upgrade()


func _apply_laser_panel_upgrade() -> void:
	if _laser_gun_upgrade_panel == null:
		push_warning("Computer: LaserGunUpgradePanel not found at expected path.")
		return
	_laser_gun_upgrade_panel.set_upgraded(true)
	_laser_gun_upgrade_panel.set_current_step(laser_upgrade_step)


func _advance_laser_upgrade_step() -> void:
	if laser_upgrade_logic_id == &"":
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	if not run_state.has_flag(_get_laser_panel_flag_id()):
		return
	if laser_upgrade_step >= LASER_PANEL_MAX_STEP:
		return
	laser_upgrade_step = mini(laser_upgrade_step + 1, LASER_PANEL_MAX_STEP)
	_apply_laser_panel_upgrade()


func _try_fire_laser() -> void:
	if _is_swapping_scene:
		return
	if laser_upgrade_step < LASER_PANEL_MAX_STEP:
		return
	var run_state := _map_state_store.run_state
	if run_state == null or not run_state.has_flag(_get_laser_panel_flag_id()):
		return
	var player := _get_current_player()
	if player == null:
		return
	if not _can_player_take_turn_action(player):
		return
	_fire_laser_forward(player)
	laser_upgrade_step = 0
	_apply_laser_panel_upgrade()
	_consume_player_turn(player)


func _fire_laser_forward(player: Player) -> void:
	if player == null:
		return
	var graph := player.get_navigation_graph()
	if graph == null:
		return
	var direction := player.get_forward_direction()
	if direction == Direction.Cardinal.NONE:
		return
	var current_vertex_id := player.get_current_vertex_id()
	if current_vertex_id < 0:
		return

	while true:
		var current_vertex: Vertex = graph.vertices.get(current_vertex_id)
		if current_vertex == null:
			return
		if not current_vertex.edges.has(direction):
			return
		var edge: Edge = current_vertex.edges.get(direction)
		if edge == null or not edge.is_passable():
			return

		var next_vertex_id := -1
		if edge.vertex_a_id == current_vertex_id:
			next_vertex_id = edge.vertex_b_id
		elif edge.vertex_b_id == current_vertex_id:
			next_vertex_id = edge.vertex_a_id
		if next_vertex_id < 0:
			return

		if player.attack_enemy_at_vertex(next_vertex_id):
			return

		current_vertex_id = next_vertex_id


func _can_player_take_turn_action(player: Player) -> bool:
	if player == null:
		return false
	if player.turn_manager == null:
		return true
	return player.turn_manager.is_player_turn


func _consume_player_turn(player: Player) -> void:
	if player == null or player.turn_manager == null:
		return
	if player.turn_manager.is_player_turn:
		player.turn_manager.player_took_turn()


func _get_laser_panel_flag_id() -> StringName:
	if laser_upgrade_logic_id == &"":
		return &""
	return StringName(String(LASER_PANEL_FLAG_PREFIX) + String(laser_upgrade_logic_id))


func _log_stat_bonus_gain(player: Player, bonus_config: Dictionary, logic_id: StringName) -> void:
	if _text_log == null:
		return
	var parts: Array[String] = []
	var upgrade_name := String(bonus_config.get(&"name", bonus_config.get(&"upgrade_name", ""))).strip_edges()
	if upgrade_name.is_empty():
		upgrade_name = String(logic_id)

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

	if parts.is_empty() and upgrade_name.is_empty():
		return
	if parts.is_empty():
		_text_log.add_message("You got %s." % upgrade_name)
		return
	_text_log.add_message("You got %s - %s" % [upgrade_name, ", ".join(parts)])


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


func _refresh_battery_pickup_visual() -> void:
	_clear_battery_pickup_sprite()
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null or graph_renderer.graph == null:
		return
	var pickup_config := _get_battery_pickup_config_for_graph(graph_renderer.graph)
	if pickup_config.is_empty():
		return
	var vertex_id := int(pickup_config.get(&"vertex_id", -1))
	if vertex_id < 0:
		return
	var texture := pickup_config.get(&"texture", default_battery_pickup_texture) as Texture2D
	if texture == null:
		return
	var pickup_height := float(pickup_config.get(&"height", default_battery_pickup_height))
	var pickup_pixel_size := float(pickup_config.get(&"pixel_size", default_battery_pickup_pixel_size))
	if not graph_renderer.graph.vertices.has(vertex_id):
		return
	if _is_battery_pickup_collected(graph_renderer.graph, vertex_id):
		return

	var vertex: Vertex = graph_renderer.graph.vertices.get(vertex_id)
	if vertex == null:
		return

	var sprite := Sprite3D.new()
	sprite.name = "BatteryPickup"
	sprite.texture = texture
	sprite.billboard = 1
	sprite.pixel_size = pickup_pixel_size
	sprite.double_sided = false
	sprite.position = Vector3(vertex.position.x * graph_renderer.cell_size, pickup_height, vertex.position.y * graph_renderer.cell_size)
	graph_renderer.add_child(sprite)
	_battery_pickup_sprite = sprite


func _update_battery_pickup_collection() -> void:
	if _is_swapping_scene:
		return
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null or graph_renderer.graph == null:
		return
	var pickup_config := _get_battery_pickup_config_for_graph(graph_renderer.graph)
	if pickup_config.is_empty():
		return
	var vertex_id := int(pickup_config.get(&"vertex_id", -1))
	if vertex_id < 0:
		return
	if _is_battery_pickup_collected(graph_renderer.graph, vertex_id):
		return
	var player := _get_current_player()
	if player == null:
		return
	if player.get_current_vertex_id() != vertex_id:
		return
	_set_battery_pickup_collected(graph_renderer.graph, vertex_id, true)
	_clear_battery_pickup_sprite()


func _is_battery_pickup_collected(graph: Graph, vertex_id: int) -> bool:
	if graph == null:
		return false
	var run_state := _map_state_store.run_state
	if run_state == null:
		return false
	return run_state.has_flag(_get_battery_pickup_flag_id(graph, vertex_id))


func _set_battery_pickup_collected(graph: Graph, vertex_id: int, value: bool) -> void:
	if graph == null:
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	run_state.set_flag(_get_battery_pickup_flag_id(graph, vertex_id), value)


func _get_battery_pickup_flag_id(graph: Graph, vertex_id: int) -> StringName:
	if graph == null:
		return &""
	var map_key := graph.resource_path
	if map_key.is_empty():
		map_key = "runtime_%d" % graph.get_instance_id()
	return StringName("%s%s_%d" % [String(BATTERY_PICKUP_FLAG_PREFIX), map_key, vertex_id])


func _get_battery_pickup_config_for_graph(graph: Graph) -> Dictionary:
	if graph == null:
		return {}
	var graph_key := graph.resource_path
	if graph_key.is_empty():
		return {}
	if not battery_pickup_map.has(graph_key):
		return {}
	var config: Variant = battery_pickup_map.get(graph_key, {})
	if config is Dictionary:
		return config as Dictionary
	return {}


func _clear_battery_pickup_sprite() -> void:
	if _battery_pickup_sprite != null and is_instance_valid(_battery_pickup_sprite):
		_battery_pickup_sprite.queue_free()
	_battery_pickup_sprite = null
