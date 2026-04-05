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
@export var logic_heal_map: Dictionary[StringName, int] = {
	&"vertex_28_Use_HP": 20
}
@export var per_map_surface_reset_logic_ids: Array[StringName] = [
	&"vertex_28_Use_HP"
]
@export var logic_stat_bonus_map: Dictionary[StringName, Dictionary] = {}
@export var logic_upgrade_indicator_map: Dictionary[StringName, NodePath] = {}
@export var laser_upgrade_logic_id: StringName = &""
@export var boss_music_logic_ids: Array[StringName] = [
	&"vertex_7_logic_1775353017"
]
@export var final_boss_scene_path: String = "res://scenes/FinalBoos.tscn"
@export var final_boss_graph_path: String = "res://assets/graphs/Boooos.tres"
@export var homebase_graph_path: String = "res://assets/graphs/HomeBaseMap.tres"
@export var homebase_unlock_edge_id: int = 79
@export_range(0, 5, 1) var laser_upgrade_step: int = 0
@export var minimap_unlock_logic_ids: Array[StringName] = []
@export var minimap_unlocked_by_default: bool = true
@export var god_mode_enabled: bool = false
@export_range(0.0, 10.0, 0.1) var loading_screen_hold_seconds: float = 2.0
@export var menu_screen_texture: Texture2D = preload("res://assets/images/Drone_Menu_screen.png")
@export_range(0.0, 10.0, 0.1) var death_screen_hold_seconds: float = 2.0
@export var death_screen_texture: Texture2D = preload("res://assets/images/Drone_deathscreen.png")
@export var win_screen_texture: Texture2D = preload("res://assets/images/WIN_screen.png")
@export var respawn_home_scene: PackedScene = preload("res://scenes/HomeBase.tscn")
@export var death_sting_sfx: AudioStream = preload("res://assets/audio/sfx/you_died_sting.wav")
@export var sfx_bus: StringName = &"SFX"
@export var battery_pickup_map: Dictionary[String, Dictionary] = {
	"res://assets/graphs/Maze.tres": {
		&"vertex_id": 6,
		&"texture": preload("res://assets/images/Battery_pack.png"),
	},
		"res://assets/graphs/TestGraph.tres": {
		&"vertex_id": 131,
		&"texture": preload("res://assets/images/laser_gun.png"),
	},
		"res://assets/graphs/Gaunt.tres": {
		&"vertex_id": 74,
		&"texture": preload("res://assets/images/Battery_pack.png"),
	}
}


@export var default_battery_pickup_texture: Texture2D = preload("res://assets/images/Battery_pack.png")
@export_range(0.0, 10.0, 0.1) var default_battery_pickup_height: float = 0.6
@export_range(0.0001, 0.05, 0.0001) var default_battery_pickup_pixel_size: float = 0.002

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport
@onready var _temp_loading_screen: TextureRect = %LoadingScreen
@onready var _player_input: PlayerInput = $PlayerInput
@onready var _music_system: MusicSystem = %MusicSystem
@onready var _logic_interact_sfx: RandomSfxPlayer = %LogicInteractSfx
@onready var _door_open_sfx: RandomSfxPlayer = %DoorOpenSfx
@onready var _door_close_sfx: RandomSfxPlayer = %DoorCloseSfx
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
@onready var _btn_menu: Button = get_node_or_null("AspectRatioContainer/DesignRoot/Menu") as Button
@onready var _btn_restart: Button = get_node_or_null("AspectRatioContainer/DesignRoot/RestartGame") as Button
@onready var _laser_gun_upgrade_panel: LaserGunUpgradePanel = $AspectRatioContainer/DesignRoot/LaserGunUpgradePanel
@onready var _gun_not_ready: CanvasItem = get_node_or_null("AspectRatioContainer/DesignRoot/GunNotReady") as CanvasItem

var _connected_graph: Graph
var _connected_turn_manager: TurnManager
var _is_swapping_scene := false
var _is_menu_open := false
var _map_state_store: MapStateStore = MapStateStore.new()
var _battery_pickup_sprite: Sprite3D
var _default_loading_screen_texture: Texture2D
var _loading_screen_texture_override: Texture2D
var _connected_player: Player
var _connected_enemy_manager: EnemyManager
var _base_surface_overrides_by_graph: Dictionary[String, Dictionary] = {}
var _ui_sfx_player: AudioStreamPlayer
var _is_win_screen_active := false
var _has_seen_final_boss_enemy_alive := false
var _has_triggered_final_victory := false


func _ready() -> void:
	if _temp_loading_screen != null:
		_default_loading_screen_texture = _temp_loading_screen.texture
		_temp_loading_screen.visible = false
	_create_ui_sfx_player_if_missing()
	_wire_button_actions()
	_inject_run_state_into_player()
	_connect_to_current_graph()
	_connect_to_current_player()
	_refresh_battery_pickup_visual()
	_setup_mini_map()
	_apply_all_persistent_upgrade_indicators()
	_apply_all_persistent_laser_panel_upgrades()
	_update_gun_not_ready_visibility()
	_update_attack_button_enabled_state()
	if _btn_restart != null:
		_btn_restart.visible = false
		_btn_restart.disabled = true
	call_deferred("_run_initial_ai_turn_after_load")


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
	if _btn_menu != null and not _btn_menu.pressed.is_connected(_on_menu_pressed):
		_btn_menu.pressed.connect(_on_menu_pressed)
	if _btn_restart != null and not _btn_restart.pressed.is_connected(_on_restart_pressed):
		_btn_restart.pressed.connect(_on_restart_pressed)


func _on_move_forward_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_move_forward()


func _on_move_backward_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_move_backward()


func _on_move_left_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_move_left()


func _on_move_right_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_move_right()


func _on_rotate_left_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_rotate_left()


func _on_rotate_right_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_rotate_right()


func _on_attack_pressed() -> void:
	if not _can_accept_player_commands():
		return
	_try_fire_laser()


func _on_interact_pressed() -> void:
	if not _can_accept_player_commands():
		return
	if _player_input == null:
		return
	_player_input.command_interact()


func _process(_delta: float) -> void:
	_ensure_turn_manager_wiring()
	_ensure_player_defeat_wiring()
	_ensure_enemy_manager_wiring()
	_sync_mini_map_context()
	_update_battery_pickup_collection()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_toggle_menu_overlay()
		get_viewport().set_input_as_handled()
		return
	if _is_menu_open:
		return
	if key_event.keycode != KEY_F and key_event.keycode != KEY_KP_9:
		return
	_try_fire_laser()


func _on_menu_pressed() -> void:
	_toggle_menu_overlay()


func _on_restart_pressed() -> void:
	if get_tree() == null:
		return
	get_tree().reload_current_scene()


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
	_update_homebase_unlock_state()
	_capture_graph_base_surface_overrides_if_missing()
	_reset_per_map_heal_logic_triggers()
	var did_reset_surface_overrides := _reset_per_map_surface_overrides_for_logic_ids()
	if did_reset_surface_overrides:
		graph_renderer.render_graph()
	if not _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.connect(_on_vertex_logic_triggered)
	_connect_to_current_turn_manager()
	_refresh_battery_pickup_visual()


func _disconnect_from_current_graph() -> void:
	if _connected_graph == null: return
	if _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.disconnect(_on_vertex_logic_triggered)
	_connected_graph = null
	_disconnect_from_current_enemy_manager()
	_disconnect_from_current_turn_manager()
	_disconnect_from_current_player()
	_clear_battery_pickup_sprite()


func _on_vertex_logic_triggered(vertex_id: int, logic_id: StringName) -> void:
	if _is_swapping_scene: return
	_play_interact_logic_sfx_if_needed(vertex_id, logic_id)
	_play_door_logic_sfx_if_needed(vertex_id, logic_id)
	_apply_logic_music_changes(logic_id)
	if logic_message_map.has(logic_id) and _text_log != null:
		_text_log.add_message(logic_message_map[logic_id])
	_apply_logic_heal(logic_id)
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


func _apply_logic_music_changes(logic_id: StringName) -> void:
	if boss_music_logic_ids.has(logic_id):
		play_boss_music()


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
	_connect_to_current_player()
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer != null: graph_renderer.render_graph()
	await get_tree().process_frame
	_run_initial_ai_turn_for_current_scene()
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
		if not _is_menu_open or _is_win_screen_active:
			if _loading_screen_texture_override != null:
				_temp_loading_screen.texture = _loading_screen_texture_override
			elif _default_loading_screen_texture != null:
				_temp_loading_screen.texture = _default_loading_screen_texture
		_temp_loading_screen.visible = new_is_visible


func _toggle_menu_overlay() -> void:
	if _is_swapping_scene:
		return
	if _is_win_screen_active:
		return
	_set_menu_overlay_open(not _is_menu_open)


func _set_menu_overlay_open(is_open: bool) -> void:
	if _is_win_screen_active and is_open:
		return
	if _is_menu_open == is_open:
		return
	_is_menu_open = is_open
	if _temp_loading_screen != null:
		if is_open:
			if menu_screen_texture != null:
				_temp_loading_screen.texture = menu_screen_texture
			_temp_loading_screen.visible = true
		else:
			if _default_loading_screen_texture != null:
				_temp_loading_screen.texture = _default_loading_screen_texture
			_temp_loading_screen.visible = false
	_set_player_movement_enabled(not is_open)


func _can_accept_player_commands() -> bool:
	if _is_menu_open:
		return false
	if _is_swapping_scene:
		return false
	if _is_win_screen_active:
		return false
	return true


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


func _get_current_enemy_manager() -> EnemyManager:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		return null
	for child in graph_renderer.get_children():
		if child is EnemyManager:
			return child as EnemyManager
	return null


func _connect_to_current_turn_manager() -> void:
	_disconnect_from_current_turn_manager()
	var turn_manager := _get_current_turn_manager()
	if turn_manager == null:
		return
	_connected_turn_manager = turn_manager
	if not _connected_turn_manager.PlayerTurnOver.is_connected(_on_player_turn_over):
		_connected_turn_manager.PlayerTurnOver.connect(_on_player_turn_over)


func _ensure_turn_manager_wiring() -> void:
	if _is_swapping_scene:
		return
	var turn_manager := _get_current_turn_manager()
	if turn_manager == null:
		_disconnect_from_current_turn_manager()
		return
	if _connected_turn_manager != turn_manager:
		_connect_to_current_turn_manager()
		return
	if not _connected_turn_manager.PlayerTurnOver.is_connected(_on_player_turn_over):
		_connected_turn_manager.PlayerTurnOver.connect(_on_player_turn_over)


func _disconnect_from_current_turn_manager() -> void:
	if _connected_turn_manager == null:
		return
	if _connected_turn_manager.PlayerTurnOver.is_connected(_on_player_turn_over):
		_connected_turn_manager.PlayerTurnOver.disconnect(_on_player_turn_over)
	_connected_turn_manager = null


func _connect_to_current_enemy_manager() -> void:
	_disconnect_from_current_enemy_manager()
	var enemy_manager := _get_current_enemy_manager()
	if enemy_manager == null:
		return
	_connected_enemy_manager = enemy_manager
	if not _connected_enemy_manager.child_entered_tree.is_connected(_on_enemy_manager_child_entered_tree):
		_connected_enemy_manager.child_entered_tree.connect(_on_enemy_manager_child_entered_tree)
	if not _connected_enemy_manager.child_exiting_tree.is_connected(_on_enemy_manager_child_exiting_tree):
		_connected_enemy_manager.child_exiting_tree.connect(_on_enemy_manager_child_exiting_tree)
	for child in _connected_enemy_manager.get_children():
		_wire_enemy_death_signal(child)
	_check_final_boss_victory_condition()


func _ensure_enemy_manager_wiring() -> void:
	if _is_swapping_scene:
		return
	var enemy_manager := _get_current_enemy_manager()
	if enemy_manager == null:
		_disconnect_from_current_enemy_manager()
		return
	if _connected_enemy_manager != enemy_manager:
		_connect_to_current_enemy_manager()
		return
	if not _connected_enemy_manager.child_entered_tree.is_connected(_on_enemy_manager_child_entered_tree):
		_connected_enemy_manager.child_entered_tree.connect(_on_enemy_manager_child_entered_tree)
	if not _connected_enemy_manager.child_exiting_tree.is_connected(_on_enemy_manager_child_exiting_tree):
		_connected_enemy_manager.child_exiting_tree.connect(_on_enemy_manager_child_exiting_tree)


func _disconnect_from_current_enemy_manager() -> void:
	if _connected_enemy_manager == null:
		return
	if _connected_enemy_manager.child_entered_tree.is_connected(_on_enemy_manager_child_entered_tree):
		_connected_enemy_manager.child_entered_tree.disconnect(_on_enemy_manager_child_entered_tree)
	if _connected_enemy_manager.child_exiting_tree.is_connected(_on_enemy_manager_child_exiting_tree):
		_connected_enemy_manager.child_exiting_tree.disconnect(_on_enemy_manager_child_exiting_tree)
	for child in _connected_enemy_manager.get_children():
		_unwire_enemy_death_signal(child)
	_connected_enemy_manager = null
	_has_seen_final_boss_enemy_alive = false


func _on_enemy_manager_child_entered_tree(node: Node) -> void:
	_wire_enemy_death_signal(node)
	_check_final_boss_victory_condition()


func _on_enemy_manager_child_exiting_tree(node: Node) -> void:
	if node is Enemy:
		call_deferred("_check_final_boss_victory_condition")


func _wire_enemy_death_signal(node: Node) -> void:
	if not (node is Enemy):
		return
	var enemy := node as Enemy
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)


func _unwire_enemy_death_signal(node: Node) -> void:
	if not (node is Enemy):
		return
	var enemy := node as Enemy
	if enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.disconnect(_on_enemy_died)


func _on_enemy_died() -> void:
	call_deferred("_check_final_boss_victory_condition")


func _check_final_boss_victory_condition() -> void:
	if _has_triggered_final_victory:
		return
	if not _is_current_map_final_boss():
		return
	var enemy_manager := _get_current_enemy_manager()
	if enemy_manager == null:
		return
	var alive_count := 0
	for child in enemy_manager.get_children():
		if child is Enemy and is_instance_valid(child):
			alive_count += 1
	if alive_count > 0:
		_has_seen_final_boss_enemy_alive = true
		return
	if not _has_seen_final_boss_enemy_alive:
		return
	_trigger_final_victory()


func _is_current_map_final_boss() -> bool:
	if final_boss_scene_path.is_empty() and final_boss_graph_path.is_empty():
		return false
	if _connected_graph != null and not final_boss_graph_path.is_empty():
		if _connected_graph.resource_path == final_boss_graph_path:
			return true
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		return false
	if not final_boss_scene_path.is_empty() and graph_renderer.scene_file_path == final_boss_scene_path:
		return true
	# Fallback for cases where scene_file_path is empty at runtime.
	if not final_boss_scene_path.is_empty() and graph_renderer.name == "FinalBoos":
		return true
	return false


func _trigger_final_victory() -> void:
	_has_triggered_final_victory = true
	_is_win_screen_active = true
	_set_player_movement_enabled(false)
	_set_menu_overlay_open(false)
	if _btn_menu != null:
		_btn_menu.disabled = true
	if _btn_restart != null:
		_btn_restart.visible = true
		_btn_restart.disabled = false
	_loading_screen_texture_override = win_screen_texture
	_set_loading_screen_visible(true)
	play_victory_music()
	if _text_log != null:
		_text_log.add_message("Mission complete. Press Restart to play again.")


func _on_player_turn_over() -> void:
	_advance_laser_upgrade_step()


func _set_player_movement_enabled(is_enabled: bool) -> void:
	if _player_input == null: return
	_player_input.set_input_locked(not is_enabled)


func _play_interact_logic_sfx_if_needed(vertex_id: int, logic_id: StringName) -> void:
	if _logic_interact_sfx == null:
		return
	if _connected_graph == null:
		return
	var entries := _connected_graph.get_vertex_logic(vertex_id)
	for logic in entries:
		if logic == null:
			continue
		if logic.logic_id != logic_id:
			continue
		if logic.trigger_type != VertexLogic.TriggerType.ON_INTERACT:
			continue
		_logic_interact_sfx.play_random()
		return


func _play_door_logic_sfx_if_needed(vertex_id: int, logic_id: StringName) -> void:
	if _connected_graph == null:
		return
	var entries := _connected_graph.get_vertex_logic(vertex_id)
	for logic in entries:
		if logic == null:
			continue
		if logic.logic_id != logic_id:
			continue
		var payload: Dictionary = logic.payload
		if String(payload.get("type", "")) != "set_edge_type":
			continue
		var edge_id := int(payload.get("edge_id", -1))
		if edge_id < 0:
			continue
		var edge: Edge = _connected_graph.edges.get(edge_id)
		if edge == null:
			continue
		if edge.type == Edge.EdgeType.DOOR and int(edge.door_state) == int(Door.DoorState.OPEN):
			if _door_open_sfx != null:
				_door_open_sfx.play_random()
		else:
			if _door_close_sfx != null:
				_door_close_sfx.play_random()
		return


func _connect_to_current_player() -> void:
	_disconnect_from_current_player()
	var player := _get_current_player()
	if player == null:
		return
	_connected_player = player
	_connected_player.set_god_mode(god_mode_enabled)
	if not _connected_player.defeated.is_connected(_on_player_defeated):
		_connected_player.defeated.connect(_on_player_defeated)
	if not _connected_player.turn_consumed.is_connected(_on_player_turn_consumed):
		_connected_player.turn_consumed.connect(_on_player_turn_consumed)


func _ensure_player_defeat_wiring() -> void:
	if _is_swapping_scene:
		return
	var player := _get_current_player()
	if player == null:
		_disconnect_from_current_player()
		return
	if _connected_player != player:
		_connect_to_current_player()
		return
	if not _connected_player.defeated.is_connected(_on_player_defeated):
		_connected_player.defeated.connect(_on_player_defeated)
	# Fallback in case death happened before the signal was connected this frame.
	if player.current_health <= 0:
		_on_player_defeated()


func _disconnect_from_current_player() -> void:
	if _connected_player == null:
		return
	if _connected_player.defeated.is_connected(_on_player_defeated):
		_connected_player.defeated.disconnect(_on_player_defeated)
	if _connected_player.turn_consumed.is_connected(_on_player_turn_consumed):
		_connected_player.turn_consumed.disconnect(_on_player_turn_consumed)
	_connected_player = null


func _on_player_turn_consumed() -> void:
	# TurnManager already drives charge via PlayerTurnOver when present.
	if _connected_player != null and _connected_player.turn_manager != null:
		return
	_advance_laser_upgrade_step()


func _on_player_defeated() -> void:
	if _is_swapping_scene:
		return
	await _respawn_player_to_home()


func _respawn_player_to_home() -> void:
	if respawn_home_scene == null:
		push_warning("Computer: Home respawn scene is not assigned.")
		return
	_is_swapping_scene = true
	_set_player_movement_enabled(false)
	_play_death_sting_sfx()
	play_gameplay_music()
	_loading_screen_texture_override = death_screen_texture
	_set_loading_screen_visible(true)
	if _text_log != null:
		_text_log.add_message("System failure detected. Respawning at Home Base...")
	await get_tree().create_timer(maxf(0.0, death_screen_hold_seconds)).timeout
	_save_current_map_state()
	_swap_subviewport_scene(respawn_home_scene)
	_restore_current_map_state()
	_inject_run_state_into_player()
	_connect_to_current_player()
	var player := _get_current_player()
	if player != null:
		player.respawn_to_start_full_health()
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer != null:
		graph_renderer.render_graph()
	_connect_to_current_graph()
	await get_tree().process_frame
	_run_initial_ai_turn_for_current_scene()
	_refresh_battery_pickup_visual()
	_sync_mini_map_context()
	_loading_screen_texture_override = null
	_set_loading_screen_visible(false)
	_set_player_movement_enabled(true)
	_is_swapping_scene = false
	if _btn_menu != null:
		_btn_menu.disabled = false


func _run_initial_ai_turn_after_load() -> void:
	if get_tree() == null:
		return
	await get_tree().process_frame
	_run_initial_ai_turn_for_current_scene()


func _run_initial_ai_turn_for_current_scene() -> void:
	var turn_manager := _get_current_turn_manager()
	if turn_manager == null:
		return
	turn_manager.run_initial_ai_turn()
	_check_final_boss_victory_condition()


func _save_current_map_state() -> void:
	if _connected_graph != null:
		_map_state_store.save_map_state(_connected_graph)


func _reset_per_map_heal_logic_triggers() -> void:
	if _connected_graph == null:
		return
	if logic_heal_map.is_empty():
		return
	var run_state := _map_state_store.run_state
	if run_state == null:
		return
	for key in logic_heal_map.keys():
		var logic_id := key as StringName
		run_state.triggered_logic.erase(logic_id)


func _apply_logic_heal(logic_id: StringName) -> void:
	if not logic_heal_map.has(logic_id):
		return
	var heal_amount := int(logic_heal_map.get(logic_id, 0))
	if heal_amount == 0:
		return
	var player := _get_current_player()
	if player == null:
		return
	var old_hp := player.current_health
	var max_hp := player.get_effective_max_health()
	player.current_health = clampi(player.current_health + heal_amount, 0, max_hp)
	if _text_log != null and player.current_health != old_hp:
		var delta := player.current_health - old_hp
		if delta > 0:
			_text_log.add_message("You heal %d HP. HP: %d/%d" % [delta, player.current_health, max_hp])


func _reset_per_map_surface_overrides_for_logic_ids() -> bool:
	if _connected_graph == null:
		return false
	if per_map_surface_reset_logic_ids.is_empty():
		return false
	var graph_state_key := _get_connected_graph_state_key()
	var baseline_by_vertex: Dictionary = {}
	if not graph_state_key.is_empty() and _base_surface_overrides_by_graph.has(graph_state_key):
		baseline_by_vertex = _base_surface_overrides_by_graph.get(graph_state_key, {})

	var did_change := false
	for vertex_id in _connected_graph.vertex_logic.keys():
		var entries := _connected_graph.get_vertex_logic(int(vertex_id))
		for logic in entries:
			if logic == null:
				continue
			if not per_map_surface_reset_logic_ids.has(logic.logic_id):
				continue
			var payload: Dictionary = logic.payload
			if String(payload.get("type", "")) != "set_surface_override":
				continue

			var target_vertex_id := int(payload.get("target_vertex_id", -1))
			if target_vertex_id < 0:
				target_vertex_id = int(vertex_id)
			var target_vertex: Vertex = _connected_graph.vertices.get(target_vertex_id)
			if target_vertex == null:
				continue

			var surface_int := int(payload.get("surface", int(Direction.Surface.NORTH)))
			var writable_overrides := target_vertex.surface_texture_overrides.duplicate(true)
			var baseline_overrides: Dictionary = baseline_by_vertex.get(target_vertex_id, {})
			if baseline_overrides.has(surface_int):
				var baseline_value: int = int(baseline_overrides.get(surface_int, 0))
				if not writable_overrides.has(surface_int) or int(writable_overrides.get(surface_int, -1)) != baseline_value:
					writable_overrides[surface_int] = baseline_value
					target_vertex.surface_texture_overrides = writable_overrides
					did_change = true
			elif writable_overrides.has(surface_int):
				writable_overrides.erase(surface_int)
				target_vertex.surface_texture_overrides = writable_overrides
				did_change = true

	return did_change


func _capture_graph_base_surface_overrides_if_missing() -> void:
	if _connected_graph == null:
		return
	var graph_state_key := _get_connected_graph_state_key()
	if graph_state_key.is_empty():
		return
	if _base_surface_overrides_by_graph.has(graph_state_key):
		return

	var baseline_by_vertex: Dictionary[int, Dictionary] = {}
	for vertex_id in _connected_graph.vertices:
		var vertex: Vertex = _connected_graph.vertices.get(vertex_id)
		if vertex == null:
			continue
		if vertex.surface_texture_overrides.size() > 0:
			baseline_by_vertex[vertex_id] = vertex.surface_texture_overrides.duplicate(true)
	_base_surface_overrides_by_graph[graph_state_key] = baseline_by_vertex


func _get_connected_graph_state_key() -> String:
	if _connected_graph == null:
		return ""
	var map_key := _connected_graph.resource_path
	if map_key.is_empty():
		map_key = "runtime_%d" % _connected_graph.get_instance_id()
	return map_key


func _restore_current_map_state() -> void:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null or graph_renderer.graph == null:
		return
	_map_state_store.restore_map_state(graph_renderer.graph)


func _inject_run_state_into_player() -> void:
	var player := _get_current_player()
	if player != null:
		player.set_run_state(_map_state_store.run_state)
		player.set_god_mode(god_mode_enabled)
		_apply_all_persistent_logic_stat_bonuses(player)
	_update_homebase_unlock_state()
	_apply_all_persistent_laser_panel_upgrades()


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
	_update_homebase_unlock_state()
	var player := _get_current_player()
	_log_stat_bonus_gain(player, bonus_config, logic_id)
	if player != null:
		_apply_all_persistent_logic_stat_bonuses(player)


func _has_all_stat_bonuses_unlocked() -> bool:
	var run_state := _map_state_store.run_state
	if run_state == null:
		return false
	if logic_stat_bonus_map.is_empty():
		return false
	for key in logic_stat_bonus_map.keys():
		var logic_id := key as StringName
		if not run_state.has_flag(_get_stat_bonus_flag_id(logic_id)):
			return false
	return true


func _update_homebase_unlock_state() -> void:
	if not _has_all_stat_bonuses_unlocked():
		return
	if homebase_graph_path.is_empty() or homebase_unlock_edge_id < 0:
		return
	_map_state_store.set_edge_state_for_map(
		homebase_graph_path,
		homebase_unlock_edge_id,
		int(Edge.EdgeType.DOOR),
		int(Door.DoorState.OPEN)
	)
	if _connected_graph == null:
		return
	if _connected_graph.resource_path != homebase_graph_path:
		return
	var edge: Edge = _connected_graph.edges.get(homebase_unlock_edge_id)
	if edge == null:
		return
	edge.type = Edge.EdgeType.DOOR
	edge.door_state = Door.DoorState.OPEN
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer != null:
		graph_renderer.render_graph()


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
	_update_gun_not_ready_visibility()
	if _laser_gun_upgrade_panel == null:
		push_warning("Computer: LaserGunUpgradePanel not found at expected path.")
		return
	_laser_gun_upgrade_panel.set_upgraded(true)
	_laser_gun_upgrade_panel.set_current_step(laser_upgrade_step)


func _update_gun_not_ready_visibility() -> void:
	if _gun_not_ready == null:
		return
	_gun_not_ready.visible = laser_upgrade_step < LASER_PANEL_MAX_STEP
	_update_attack_button_enabled_state()


func _update_attack_button_enabled_state() -> void:
	if _btn_attack == null:
		return
	_btn_attack.disabled = laser_upgrade_step < LASER_PANEL_MAX_STEP


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
	player.play_attack_sfx_random()
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

		if player.attack_enemy_at_vertex(next_vertex_id, false):
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


func play_gameplay_music() -> void:
	if _music_system == null:
		return
	_music_system.play_gameplay_track(false)


func play_boss_music() -> void:
	if _music_system == null:
		return
	_music_system.play_boss_track(false)


func play_victory_music() -> void:
	if _music_system == null:
		return
	_music_system.play_victory_track(false)


func _create_ui_sfx_player_if_missing() -> void:
	if _ui_sfx_player != null:
		return
	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.name = "UiSfxPlayer"
	add_child(_ui_sfx_player)
	_ui_sfx_player.bus = sfx_bus


func _play_death_sting_sfx() -> void:
	if death_sting_sfx == null:
		return
	_create_ui_sfx_player_if_missing()
	if _ui_sfx_player == null:
		return
	_ui_sfx_player.stream = death_sting_sfx
	_ui_sfx_player.play()


func set_god_mode_enabled(is_enabled: bool) -> void:
	god_mode_enabled = is_enabled
	if _connected_player != null:
		_connected_player.set_god_mode(god_mode_enabled)
