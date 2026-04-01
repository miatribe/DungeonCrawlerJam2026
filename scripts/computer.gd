extends Control

@export var logic_scene_map: Dictionary[StringName, PackedScene] = {
	&"vertex_62_logic_1774834428": preload("res://scenes/MapOne.tscn")
}
@export_range(0.0, 10.0, 0.1) var loading_screen_hold_seconds: float = 2.0

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport
@onready var _temp_loading_screen: Control = %TempLoadingScreen
@onready var _player_input: PlayerInput = $PlayerInput

var _connected_graph: Graph
var _is_swapping_scene := false
var _map_state_store: MapStateStore = MapStateStore.new()


func _ready() -> void:
	if _temp_loading_screen != null: _temp_loading_screen.visible = false
	_inject_run_state_into_player()
	_connect_to_current_graph()


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


func _get_current_player() -> Player:
	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer == null:
		return null
	for child in graph_renderer.get_children():
		if child is Player:
			return child as Player
	return null
