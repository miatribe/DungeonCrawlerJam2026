extends Control

@export var logic_scene_map: Dictionary[StringName, PackedScene] = {
	&"vertex_62_logic_1774834428": preload("res://scenes/MapOne.tscn")
}
@export_range(0.0, 10.0, 0.1) var loading_screen_hold_seconds: float = 2.0
var player_group_name: StringName = "player"

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport
@onready var _temp_loading_screen: Control = %TempLoadingScreen

var _connected_graph: Graph
var _is_swapping_scene := false


func _ready() -> void:
	if _temp_loading_screen != null:
		_temp_loading_screen.visible = false
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
	if _connected_graph == null:
		return

	if _connected_graph.vertex_logic_triggered.is_connected(_on_vertex_logic_triggered):
		_connected_graph.vertex_logic_triggered.disconnect(_on_vertex_logic_triggered)

	_connected_graph = null


func _on_vertex_logic_triggered(_vertex_id: int, logic_id: StringName) -> void:
	if _is_swapping_scene:
		return
	if not logic_scene_map.has(logic_id):
		return

	var target_scene: PackedScene = logic_scene_map.get(logic_id)
	if target_scene == null:
		push_warning("Computer: Logic '%s' is mapped, but scene is null." % String(logic_id))
		return

	_swap_subviewport_scene_with_loading(target_scene)


func _swap_subviewport_scene_with_loading(scene: PackedScene) -> void:
	if scene == null:
		return
	_is_swapping_scene = true
	# Lock players in the currently active scene immediately.
	_set_player_movement_enabled(false)

	_set_loading_screen_visible(true)
	await get_tree().process_frame

	_swap_subviewport_scene(scene)
	# Lock players again so the newly instantiated scene's Player is also locked.
	_set_player_movement_enabled(false)

	var graph_renderer := _get_current_graph_renderer()
	if graph_renderer != null:
		graph_renderer.render_graph()

	await get_tree().process_frame
	await get_tree().create_timer(maxf(0.0, loading_screen_hold_seconds)).timeout
	_set_loading_screen_visible(false)
	_set_player_movement_enabled(true)
	_connect_to_current_graph()
	_is_swapping_scene = false


func _swap_subviewport_scene(scene: PackedScene) -> void:
	if scene == null or _subviewport == null:
		return

	for child in _subviewport.get_children():
		child.queue_free()

	var next_scene := scene.instantiate()
	if next_scene == null:
		push_warning("Computer: Failed to instantiate replacement scene.")
		_set_loading_screen_visible(false)
		_set_player_movement_enabled(true)
		_is_swapping_scene = false
		return

	_subviewport.add_child(next_scene)


func _set_loading_screen_visible(is_visible: bool) -> void:
	if _temp_loading_screen != null:
		_temp_loading_screen.visible = is_visible


func _get_current_graph_renderer() -> GraphRenderer:
	if _subviewport == null or _subviewport.get_child_count() == 0:
		return null
	return _subviewport.get_child(0) as GraphRenderer


func _set_player_movement_enabled(is_enabled: bool) -> void:
	if get_tree() == null: return
	for node in get_tree().get_nodes_in_group(player_group_name):
		var player := node as Player
		if player == null: continue
		if not is_ancestor_of(player): continue
		player.set_input_locked(not is_enabled)
