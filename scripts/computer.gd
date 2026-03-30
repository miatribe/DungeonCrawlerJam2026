extends Control

@export var logic_scene_map: Dictionary[StringName, PackedScene] = {
	&"vertex_62_logic_1774834428": preload("res://scenes/MapOne.tscn")
}

@onready var _subviewport: SubViewport = $AspectRatioContainer/DesignRoot/SubViewportContainer/SubViewport

var _connected_graph: Graph


func _ready() -> void:
	_connect_to_current_graph()


func _connect_to_current_graph() -> void:
	_disconnect_from_current_graph()

	if _subviewport == null or _subviewport.get_child_count() == 0:
		push_warning("Computer: SubViewport has no scene to connect to.")
		return

	var scene_root := _subviewport.get_child(0)
	var graph_renderer := scene_root as GraphRenderer
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
	if not logic_scene_map.has(logic_id):
		return

	var target_scene: PackedScene = logic_scene_map.get(logic_id)
	if target_scene == null:
		push_warning("Computer: Logic '%s' is mapped, but scene is null." % String(logic_id))
		return

	_swap_subviewport_scene(target_scene)
	_connect_to_current_graph()


func _swap_subviewport_scene(scene: PackedScene) -> void:
	if scene == null or _subviewport == null:
		return

	for child in _subviewport.get_children():
		child.queue_free()

	var next_scene := scene.instantiate()
	if next_scene == null:
		push_warning("Computer: Failed to instantiate replacement scene.")
		return

	_subviewport.add_child(next_scene)
