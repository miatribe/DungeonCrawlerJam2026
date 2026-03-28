@tool
extends Control

@onready var seed_spin: SpinBox = %SeedSpin
@onready var width_spin: SpinBox = %WidthSpin
@onready var height_spin: SpinBox = %HeightSpin
@onready var max_depth_spin: SpinBox = %MaxDepthSpin
@onready var min_room_spin: SpinBox = %MinRoomSpin
@onready var max_room_spin: SpinBox = %MaxRoomSpin
@onready var padding_spin: SpinBox = %PaddingSpin
@onready var max_room_tile_sets_spin: SpinBox = %MaxRoomTileSetsSpin
@onready var max_hallway_tile_sets_spin: SpinBox = %MaxHallwayTileSetsSpin
@onready var save_button: Button = %SaveButton
@onready var file_dialog: FileDialog = $MarginContainer/Controls/FileDialog

@onready var map_viewport_container: MapRendererSubViewport = $Map


func _ready() -> void:
    seed_spin.value_changed.connect(_on_generation_parameter_changed)
    width_spin.value_changed.connect(_on_generation_parameter_changed)
    height_spin.value_changed.connect(_on_generation_parameter_changed)
    max_depth_spin.value_changed.connect(_on_generation_parameter_changed)
    min_room_spin.value_changed.connect(_on_generation_parameter_changed)
    max_room_spin.value_changed.connect(_on_generation_parameter_changed)
    padding_spin.value_changed.connect(_on_generation_parameter_changed)
    max_room_tile_sets_spin.value_changed.connect(_on_generation_parameter_changed)
    max_hallway_tile_sets_spin.value_changed.connect(_on_generation_parameter_changed)
    save_button.pressed.connect(_on_save_button_pressed)
    file_dialog.file_selected.connect(on_file_dialog_file_selected)


func _on_generation_parameter_changed(value) -> void:
    update_generation_parameters(seed_spin.value, width_spin.value, height_spin.value, max_depth_spin.value, min_room_spin.value, max_room_spin.value, padding_spin.value, max_room_tile_sets_spin.value, max_hallway_tile_sets_spin.value)


func _on_save_button_pressed() -> void:
    file_dialog.show()


func update_generation_parameters(seed_value: float, width: float, height: float, max_depth: float, min_room_size: float, max_room_size: float, padding: float, max_room_tile_sets: float, max_hallway_tile_sets: float) -> void:
    var generator = BspDungeonGenerator.new()
    var generated = generator.generate(Vector2i(width, height), seed_value, max_depth, min_room_size, max_room_size, padding, max_room_tile_sets, max_hallway_tile_sets)
    map_viewport_container.map.graph = generated.graph
    map_viewport_container.map.bsbNodeRoot = generated.root
    map_viewport_container.map.queue_redraw()


func on_file_dialog_file_selected(path: String) -> void:
    if map_viewport_container.map && map_viewport_container.map.graph:
        print("Saving graph...")
        return ResourceSaver.save(map_viewport_container.map.graph, path)
