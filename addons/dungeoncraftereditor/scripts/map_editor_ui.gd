@tool
extends VBoxContainer
class_name MapEditorUI


enum EditMode {
	ADD_VERTEX,
	ADD_EDGE,
	SELECT_VERTEX,
	SELECT_EDGE,
}

signal open_file_selected(path: String)
signal save_file_selected(path: String)
signal add_vertex_type_changed(vertex_type: Vertex.VertexType)
signal add_vertex_tileset_id_changed(tileset_id: int)
signal auto_connect_edges_changed(enabled: bool)
signal add_edge_type_changed(edge_type: Edge.EdgeType, door_state: int)
signal add_edge_door_id_changed(door_id: int)
signal selected_vertex_tileset_id_changed(tileset_id: int)
signal selected_vertex_type_changed(vertex_type: Vertex.VertexType)
signal selected_vertex_surface_override_toggled(surface: Direction.Surface, enabled: bool)
signal selected_vertex_surface_texture_override_changed(surface: Direction.Surface, texture_id: int)
signal selected_edge_type_changed(edge_type: Edge.EdgeType, door_state: int)
signal selected_edge_door_id_changed(door_id: int)
signal add_selected_vertex_logic_requested()
signal remove_selected_vertex_logic_requested()
signal selected_vertex_logic_entry_selected(index: int)
signal selected_vertex_logic_id_changed(value: String)
signal selected_vertex_logic_trigger_changed(trigger_type: VertexLogic.TriggerType)
signal selected_vertex_logic_required_direction_changed(direction: Direction.Cardinal)
signal selected_vertex_logic_one_shot_changed(value: bool)
signal selected_vertex_logic_required_flags_changed(value: String)
signal selected_vertex_logic_action_type_changed(action_type: String)
signal selected_vertex_logic_edge_id_changed(edge_id: int)
signal selected_vertex_logic_edge_type_changed(edge_type: Edge.EdgeType, door_state: int)
signal selected_vertex_logic_surface_override_target_vertex_id_changed(vertex_id: int)
signal selected_vertex_logic_surface_override_surface_changed(surface: Direction.Surface)
signal selected_vertex_logic_surface_override_texture_id_changed(texture_id: int)
signal selected_vertex_logic_flag_id_changed(flag_id: String)
signal selected_vertex_logic_flag_value_changed(value: bool)
signal edit_mode_changed(previous_mode: EditMode, current_mode: EditMode)

const EDGE_OPTION_CORRIDOR := 0
const EDGE_OPTION_DOOR := 1
const LOGIC_DOOR_STATE_TOGGLE_OPTION_ID := 100
const LOGIC_DOOR_STATE_TOGGLE_VALUE := -1

@onready var save_button: Button = $SaveButton
@onready var load_button: Button = $LoadButton
@onready var file_dialog_open: FileDialog = $FileDialogOpen
@onready var file_dialog_save: FileDialog = $FileDialogSave
@onready var edit_mode_option: OptionButton = $EditModeOption
@onready var mode_settings_container: VBoxContainer = $ModeSettingsContainer
@onready var add_vertex_settings: VBoxContainer = $ModeSettingsContainer/AddVertexSettings
@onready var add_vertex_type_option: OptionButton = $ModeSettingsContainer/AddVertexSettings/AddVertexTypeOption
@onready var tileset_id_spin: SpinBox = $ModeSettingsContainer/AddVertexSettings/TileSetIdSpin
@onready var auto_connect_edges_checkbox: CheckBox = $ModeSettingsContainer/AddVertexSettings/AutoConnectEdgesCheckBox
@onready var add_edge_settings: VBoxContainer = $ModeSettingsContainer/AddEdgeSettings
@onready var add_edge_type_option: OptionButton = $ModeSettingsContainer/AddEdgeSettings/AddEdgeTypeOption
@onready var add_edge_door_state_label: Label = $ModeSettingsContainer/AddEdgeSettings/AddEdgeDoorStateLabel
@onready var add_edge_door_state_option: OptionButton = $ModeSettingsContainer/AddEdgeSettings/AddEdgeDoorStateOption
@onready var add_edge_door_id_spin: SpinBox = $ModeSettingsContainer/AddEdgeSettings/AddEdgeDoorIdSpin
@onready var selected_details_container: VBoxContainer = get_node("../../RightMarginContainer/SelectedDetailsContainer")
@onready var no_selection_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/NoSelectionLabel")
@onready var select_vertex_settings: VBoxContainer = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings")
@onready var selected_vertex_id_value_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexIdValueLabel")
@onready var selected_vertex_type_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexTypeOption")
@onready var selected_vertex_tileset_id_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexTileSetIdSpin")
@onready var selected_vertex_surface_overrides_container: VBoxContainer = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexSurfaceOverridesContainer")
@onready var add_vertex_logic_button: Button = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/AddVertexLogicButton")
@onready var remove_vertex_logic_button: Button = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/RemoveVertexLogicButton")
@onready var selected_vertex_logic_entry_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicEntryOption")
@onready var selected_vertex_logic_id_edit: LineEdit = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicIdEdit")
@onready var selected_vertex_logic_trigger_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicTriggerOption")
@onready var selected_vertex_logic_one_shot_checkbox: CheckBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicOneShotCheckBox")
@onready var selected_vertex_logic_action_type_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicActionTypeOption")
@onready var selected_vertex_logic_edge_id_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicEdgeIdLabel")
@onready var selected_vertex_logic_edge_id_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicEdgeIdSpin")
@onready var selected_vertex_logic_edge_type_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicEdgeTypeLabel")
@onready var selected_vertex_logic_edge_type_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicEdgeTypeOption")
@onready var selected_vertex_logic_door_state_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicDoorStateLabel")
@onready var selected_vertex_logic_door_state_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicDoorStateOption")
@onready var selected_vertex_logic_flag_id_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicFlagIdLabel")
@onready var selected_vertex_logic_flag_id_edit: LineEdit = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicFlagIdEdit")
@onready var selected_vertex_logic_flag_value_checkbox: CheckBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectVertexSettings/SelectedVertexLogicFlagValueCheckBox")
@onready var select_edge_settings: VBoxContainer = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings")
@onready var selected_edge_id_value_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeIdValueLabel")
@onready var selected_edge_type_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeTypeOption")
@onready var selected_edge_door_state_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeDoorStateLabel")
@onready var selected_edge_door_state_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeDoorStateOption")
@onready var selected_edge_door_id_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeBaseTextureIdLabel")
@onready var selected_edge_door_id_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeBaseTextureIdSpin")
@onready var selected_edge_closed_texture_id_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeClosedTextureIdLabel")
@onready var selected_edge_closed_texture_id_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeClosedTextureIdSpin")
@onready var selected_edge_animation_type_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationTypeLabel")
@onready var selected_edge_animation_type_option: OptionButton = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationTypeOption")
@onready var selected_edge_animation_duration_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationDurationLabel")
@onready var selected_edge_animation_duration_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationDurationSpin")
@onready var selected_edge_animation_travel_label: Label = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationTravelLabel")
@onready var selected_edge_animation_travel_spin: SpinBox = get_node("../../RightMarginContainer/SelectedDetailsContainer/SelectEdgeSettings/SelectedEdgeAnimationTravelSpin")

var current_edit_mode: EditMode = EditMode.ADD_VERTEX
var has_selected_vertex: bool = false
var has_selected_edge: bool = false
var is_updating_ui: bool = false
var selected_vertex_surface_override_checkboxes: Dictionary[Direction.Surface, CheckBox] = {}
var selected_vertex_surface_override_spins: Dictionary[Direction.Surface, SpinBox] = {}
var selected_vertex_logic_required_flags_label: Label
var selected_vertex_logic_required_flags_edit: LineEdit
var selected_vertex_logic_required_direction_label: Label
var selected_vertex_logic_required_direction_option: OptionButton
var selected_vertex_logic_surface_override_target_vertex_id_label: Label
var selected_vertex_logic_surface_override_target_vertex_id_spin: SpinBox
var selected_vertex_logic_surface_override_surface_label: Label
var selected_vertex_logic_surface_override_surface_option: OptionButton
var selected_vertex_logic_surface_override_texture_id_label: Label
var selected_vertex_logic_surface_override_texture_id_spin: SpinBox


func _ready() -> void:
	_ensure_selected_vertex_logic_flag_fields()

	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	file_dialog_open.file_selected.connect(_on_file_dialog_open_file_selected)
	file_dialog_save.file_selected.connect(_on_file_dialog_save_file_selected)
	edit_mode_option.item_selected.connect(_on_edit_mode_selected)
	add_vertex_type_option.item_selected.connect(_on_add_vertex_type_selected)
	tileset_id_spin.value_changed.connect(_on_tileset_id_value_changed)
	auto_connect_edges_checkbox.toggled.connect(_on_auto_connect_edges_toggled)
	add_edge_type_option.item_selected.connect(_on_add_edge_type_selected)
	add_edge_door_state_option.item_selected.connect(_on_add_edge_door_state_selected)
	add_edge_door_id_spin.value_changed.connect(_on_add_edge_door_id_value_changed)
	selected_vertex_type_option.item_selected.connect(_on_selected_vertex_type_selected)
	selected_vertex_tileset_id_spin.value_changed.connect(_on_selected_vertex_tileset_id_value_changed)
	add_vertex_logic_button.pressed.connect(_on_add_vertex_logic_button_pressed)
	remove_vertex_logic_button.pressed.connect(_on_remove_vertex_logic_button_pressed)
	selected_vertex_logic_entry_option.item_selected.connect(_on_selected_vertex_logic_entry_selected)
	selected_vertex_logic_id_edit.text_changed.connect(_on_selected_vertex_logic_id_text_changed)
	selected_vertex_logic_trigger_option.item_selected.connect(_on_selected_vertex_logic_trigger_selected)
	selected_vertex_logic_required_direction_option.item_selected.connect(_on_selected_vertex_logic_required_direction_selected)
	selected_vertex_logic_one_shot_checkbox.toggled.connect(_on_selected_vertex_logic_one_shot_toggled)
	selected_vertex_logic_required_flags_edit.text_changed.connect(_on_selected_vertex_logic_required_flags_text_changed)
	selected_vertex_logic_action_type_option.item_selected.connect(_on_selected_vertex_logic_action_type_selected)
	selected_vertex_logic_edge_id_spin.value_changed.connect(_on_selected_vertex_logic_edge_id_value_changed)
	selected_vertex_logic_edge_type_option.item_selected.connect(_on_selected_vertex_logic_edge_type_selected)
	selected_vertex_logic_door_state_option.item_selected.connect(_on_selected_vertex_logic_door_state_selected)
	selected_vertex_logic_surface_override_target_vertex_id_spin.value_changed.connect(_on_selected_vertex_logic_surface_override_target_vertex_id_value_changed)
	selected_vertex_logic_surface_override_surface_option.item_selected.connect(_on_selected_vertex_logic_surface_override_surface_selected)
	selected_vertex_logic_surface_override_texture_id_spin.value_changed.connect(_on_selected_vertex_logic_surface_override_texture_id_value_changed)
	selected_vertex_logic_flag_id_edit.text_changed.connect(_on_selected_vertex_logic_flag_id_text_changed)
	selected_vertex_logic_flag_value_checkbox.toggled.connect(_on_selected_vertex_logic_flag_value_toggled)
	selected_edge_type_option.item_selected.connect(_on_selected_edge_type_selected)
	selected_edge_door_state_option.item_selected.connect(_on_selected_edge_door_state_selected)
	selected_edge_door_id_spin.value_changed.connect(_on_selected_edge_door_id_value_changed)

	_initialize_edit_mode_options()
	_initialize_vertex_type_options()
	_initialize_selected_vertex_type_options()
	_initialize_selected_vertex_surface_overrides()
	_initialize_selected_vertex_logic_options()
	_initialize_edge_type_options()
	_initialize_add_edge_door_state_options()
	_initialize_selected_edge_type_options()
	_initialize_selected_edge_door_state_options()
	_update_mode_settings_visibility()


func _ensure_selected_vertex_logic_flag_fields() -> void:
	selected_vertex_logic_required_flags_label = Label.new()
	selected_vertex_logic_required_flags_label.text = "Required Flags (comma-separated)"
	selected_vertex_logic_required_flags_edit = LineEdit.new()
	selected_vertex_logic_required_flags_edit.placeholder_text = "HasKey123, BossDefeated"
	selected_vertex_logic_required_direction_label = Label.new()
	selected_vertex_logic_required_direction_label.text = "Required Direction"
	selected_vertex_logic_required_direction_option = OptionButton.new()
	selected_vertex_logic_surface_override_target_vertex_id_label = Label.new()
	selected_vertex_logic_surface_override_target_vertex_id_label.text = "Target Vertex Id (-1 = Current)"
	selected_vertex_logic_surface_override_target_vertex_id_spin = SpinBox.new()
	selected_vertex_logic_surface_override_target_vertex_id_spin.min_value = -1
	selected_vertex_logic_surface_override_target_vertex_id_spin.max_value = 999999
	selected_vertex_logic_surface_override_target_vertex_id_spin.step = 1
	selected_vertex_logic_surface_override_target_vertex_id_spin.rounded = true
	selected_vertex_logic_surface_override_surface_label = Label.new()
	selected_vertex_logic_surface_override_surface_label.text = "Override Surface"
	selected_vertex_logic_surface_override_surface_option = OptionButton.new()
	selected_vertex_logic_surface_override_texture_id_label = Label.new()
	selected_vertex_logic_surface_override_texture_id_label.text = "Override Texture Id"
	selected_vertex_logic_surface_override_texture_id_spin = SpinBox.new()
	selected_vertex_logic_surface_override_texture_id_spin.min_value = 0
	selected_vertex_logic_surface_override_texture_id_spin.max_value = 999999
	selected_vertex_logic_surface_override_texture_id_spin.step = 1
	selected_vertex_logic_surface_override_texture_id_spin.rounded = true

	var insertion_index := selected_vertex_logic_one_shot_checkbox.get_index() + 1
	select_vertex_settings.add_child(selected_vertex_logic_required_flags_label)
	select_vertex_settings.move_child(selected_vertex_logic_required_flags_label, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_required_flags_edit)
	select_vertex_settings.move_child(selected_vertex_logic_required_flags_edit, insertion_index)

	insertion_index = selected_vertex_logic_trigger_option.get_index() + 1
	select_vertex_settings.add_child(selected_vertex_logic_required_direction_label)
	select_vertex_settings.move_child(selected_vertex_logic_required_direction_label, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_required_direction_option)
	select_vertex_settings.move_child(selected_vertex_logic_required_direction_option, insertion_index)

	insertion_index = selected_vertex_logic_action_type_option.get_index() + 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_surface_label)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_surface_label, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_target_vertex_id_label)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_target_vertex_id_label, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_target_vertex_id_spin)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_target_vertex_id_spin, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_surface_option)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_surface_option, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_texture_id_label)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_texture_id_label, insertion_index)
	insertion_index += 1
	select_vertex_settings.add_child(selected_vertex_logic_surface_override_texture_id_spin)
	select_vertex_settings.move_child(selected_vertex_logic_surface_override_texture_id_spin, insertion_index)


func _on_save_button_pressed() -> void:
	file_dialog_save.show()


func _on_load_button_pressed() -> void:
	file_dialog_open.show()


func _on_file_dialog_open_file_selected(path: String) -> void:
	open_file_selected.emit(path)


func _on_file_dialog_save_file_selected(path: String) -> void:
	save_file_selected.emit(path)


func _initialize_edit_mode_options() -> void:
	edit_mode_option.clear()
	edit_mode_option.add_item("Add Vertex", EditMode.ADD_VERTEX)
	edit_mode_option.add_item("Add Edge", EditMode.ADD_EDGE)
	edit_mode_option.add_item("Select Vertex", EditMode.SELECT_VERTEX)
	edit_mode_option.add_item("Select Edge", EditMode.SELECT_EDGE)


func _initialize_vertex_type_options() -> void:
	add_vertex_type_option.clear()
	for vertex_type_name in Vertex.VertexType.keys():
		var vertex_type_value: int = Vertex.VertexType[vertex_type_name]
		add_vertex_type_option.add_item(vertex_type_name.capitalize(), vertex_type_value)


func _initialize_selected_vertex_type_options() -> void:
	selected_vertex_type_option.clear()
	for vertex_type_name in Vertex.VertexType.keys():
		var vertex_type_value: int = Vertex.VertexType[vertex_type_name]
		selected_vertex_type_option.add_item(vertex_type_name.capitalize(), vertex_type_value)


func _initialize_selected_vertex_surface_overrides() -> void:
	for child in selected_vertex_surface_overrides_container.get_children():
		child.queue_free()
	selected_vertex_surface_override_checkboxes.clear()
	selected_vertex_surface_override_spins.clear()

	for surface_name in Direction.Surface.keys():
		var surface_value: int = Direction.Surface[surface_name]
		var surface := surface_value as Direction.Surface
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var checkbox := CheckBox.new()
		checkbox.text = "Override %s" % surface_name.capitalize()
		checkbox.toggled.connect(_on_selected_vertex_surface_override_toggled.bind(surface))

		var spinner := SpinBox.new()
		spinner.rounded = true
		spinner.visible = false
		spinner.value_changed.connect(_on_selected_vertex_surface_override_id_value_changed.bind(surface))

		row.add_child(checkbox)
		row.add_child(spinner)
		selected_vertex_surface_overrides_container.add_child(row)

		selected_vertex_surface_override_checkboxes[surface] = checkbox
		selected_vertex_surface_override_spins[surface] = spinner


func _initialize_selected_vertex_logic_options() -> void:
	selected_vertex_logic_trigger_option.clear()
	for trigger_name in VertexLogic.TriggerType.keys():
		var trigger_value: int = VertexLogic.TriggerType[trigger_name]
		selected_vertex_logic_trigger_option.add_item(trigger_name.capitalize(), trigger_value)
	_initialize_selected_vertex_logic_required_direction_options()

	selected_vertex_logic_action_type_option.clear()
	selected_vertex_logic_action_type_option.add_item("None", 0)
	selected_vertex_logic_action_type_option.add_item("Set Edge Type", 1)
	selected_vertex_logic_action_type_option.add_item("Set Flag", 2)
	selected_vertex_logic_action_type_option.add_item("Set Surface Override", 3)

	_initialize_selected_vertex_logic_surface_override_options()

	_initialize_edge_option_button(selected_vertex_logic_edge_type_option)
	_initialize_logic_door_state_option_button(selected_vertex_logic_door_state_option)

	selected_vertex_logic_edge_id_spin.min_value = 0
	selected_vertex_logic_edge_id_spin.max_value = 999999
	selected_vertex_logic_edge_id_spin.step = 1


func _initialize_selected_vertex_logic_surface_override_options() -> void:
	selected_vertex_logic_surface_override_surface_option.clear()
	for surface_name in Direction.Surface.keys():
		var surface_value: int = Direction.Surface[surface_name]
		selected_vertex_logic_surface_override_surface_option.add_item(surface_name.capitalize(), surface_value)


func _initialize_selected_vertex_logic_required_direction_options() -> void:
	selected_vertex_logic_required_direction_option.clear()
	selected_vertex_logic_required_direction_option.add_item("Any", int(Direction.Cardinal.NONE))
	selected_vertex_logic_required_direction_option.add_item("North", int(Direction.Cardinal.NORTH))
	selected_vertex_logic_required_direction_option.add_item("East", int(Direction.Cardinal.EAST))
	selected_vertex_logic_required_direction_option.add_item("South", int(Direction.Cardinal.SOUTH))
	selected_vertex_logic_required_direction_option.add_item("West", int(Direction.Cardinal.WEST))


func _on_edit_mode_selected(index: int) -> void:
	if is_updating_ui and index == int(current_edit_mode): return
	var previous_mode := current_edit_mode
	current_edit_mode = index as EditMode
	_update_mode_settings_visibility()
	edit_mode_changed.emit(previous_mode, current_edit_mode)


func _on_add_vertex_type_selected(index: int) -> void:
	if is_updating_ui: return
	add_vertex_type_changed.emit(add_vertex_type_option.get_item_id(index) as Vertex.VertexType)


func _on_tileset_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	add_vertex_tileset_id_changed.emit(int(value))


func _on_auto_connect_edges_toggled(is_enabled: bool) -> void:
	if is_updating_ui: return
	auto_connect_edges_changed.emit(is_enabled)


func _initialize_edge_type_options() -> void:
	_initialize_edge_option_button(add_edge_type_option)


func _initialize_selected_edge_type_options() -> void:
	_initialize_edge_option_button(selected_edge_type_option)


func _initialize_edge_option_button(option_button: OptionButton) -> void:
	option_button.clear()
	option_button.add_item("Corridor", EDGE_OPTION_CORRIDOR)
	option_button.add_item("Door", EDGE_OPTION_DOOR)


func _initialize_door_state_option_button(option_button: OptionButton) -> void:
	option_button.clear()
	option_button.add_item("Open", int(Door.DoorState.OPEN))
	option_button.add_item("Closed", int(Door.DoorState.CLOSED))


func _initialize_logic_door_state_option_button(option_button: OptionButton) -> void:
	_initialize_door_state_option_button(option_button)
	option_button.add_item("Toggle", LOGIC_DOOR_STATE_TOGGLE_OPTION_ID)


func _initialize_add_edge_door_state_options() -> void:
	_initialize_door_state_option_button(add_edge_door_state_option)


func _initialize_selected_edge_door_state_options() -> void:
	_initialize_door_state_option_button(selected_edge_door_state_option)


func _edge_option_id_for(edge_type: Edge.EdgeType, door_state: int = 1) -> int:
	if edge_type == Edge.EdgeType.DOOR:
		return EDGE_OPTION_DOOR
	return EDGE_OPTION_CORRIDOR


func _edge_option_to_values(option_id: int, door_state_option_button: OptionButton) -> Dictionary:
	match option_id:
		EDGE_OPTION_DOOR:
			return {
				"edge_type": Edge.EdgeType.DOOR,
				"door_state": _door_state_from_option(door_state_option_button),
			}
		_:
			return {
				"edge_type": Edge.EdgeType.CORRIDOR,
				"door_state": Door.DoorState.CLOSED,
			}


func _door_state_from_option(option_button: OptionButton) -> int:
	if option_button.selected < 0:
		return int(Door.DoorState.CLOSED)
	var selected_state := option_button.get_item_id(option_button.selected)
	if option_button == selected_vertex_logic_door_state_option and selected_state == LOGIC_DOOR_STATE_TOGGLE_OPTION_ID:
		return LOGIC_DOOR_STATE_TOGGLE_VALUE
	if selected_state < 0 or selected_state >= Door.DoorState.size():
		return int(Door.DoorState.CLOSED)
	return selected_state


func _on_add_edge_type_selected(index: int) -> void:
	if is_updating_ui: return
	var edge_values := _edge_option_to_values(add_edge_type_option.get_item_id(index), add_edge_door_state_option)
	_set_add_edge_door_state_visibility(edge_values["edge_type"] as Edge.EdgeType)
	add_edge_type_changed.emit(edge_values["edge_type"] as Edge.EdgeType, int(edge_values["door_state"]))


func _on_add_edge_door_state_selected(index: int) -> void:
	if is_updating_ui: return
	var edge_values := _edge_option_to_values(add_edge_type_option.get_item_id(add_edge_type_option.selected), add_edge_door_state_option)
	if edge_values["edge_type"] as Edge.EdgeType != Edge.EdgeType.DOOR:
		return
	add_edge_type_changed.emit(edge_values["edge_type"] as Edge.EdgeType, int(_door_state_from_option(add_edge_door_state_option)))


func _on_add_edge_door_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	add_edge_door_id_changed.emit(int(value))


func set_edit_mode(edit_mode: EditMode) -> void:
	current_edit_mode = edit_mode
	is_updating_ui = true
	var edit_mode_index := int(edit_mode)
	if edit_mode_index >= 0 and edit_mode_index < edit_mode_option.item_count:
		edit_mode_option.select(edit_mode_index)
	is_updating_ui = false
	_update_mode_settings_visibility()


func set_add_vertex_type(vertex_type: Vertex.VertexType) -> void:
	is_updating_ui = true
	var vertex_type_index := add_vertex_type_option.get_item_index(vertex_type)
	if vertex_type_index != -1: add_vertex_type_option.select(vertex_type_index)
	is_updating_ui = false


func set_add_vertex_tileset_id(tileset_id: int) -> void:
	is_updating_ui = true
	tileset_id_spin.value = tileset_id
	is_updating_ui = false


func set_auto_connect_edges_enabled(is_enabled: bool) -> void:
	is_updating_ui = true
	auto_connect_edges_checkbox.button_pressed = is_enabled
	is_updating_ui = false


func set_add_edge_type(edge_type: Edge.EdgeType, door_state: int = 1) -> void:
	is_updating_ui = true
	var edge_type_index := add_edge_type_option.get_item_index(_edge_option_id_for(edge_type, door_state))
	if edge_type_index != -1: add_edge_type_option.select(edge_type_index)
	_set_door_state_option(add_edge_door_state_option, door_state)
	_set_add_edge_door_state_visibility(edge_type)
	is_updating_ui = false


func set_add_edge_door_id(door_id: int) -> void:
	is_updating_ui = true
	add_edge_door_id_spin.value = max(door_id, 0)
	is_updating_ui = false


func set_selected_vertex_data(is_selected: bool, vertex_id: int = -1, vertex_type: Vertex.VertexType = Vertex.VertexType.ROOM, tileset_id: int = 0) -> void:
	has_selected_vertex = is_selected
	is_updating_ui = true
	if has_selected_vertex:
		selected_vertex_id_value_label.text = str(vertex_id)
		var vertex_type_index := selected_vertex_type_option.get_item_index(vertex_type)
		if vertex_type_index != -1: selected_vertex_type_option.select(vertex_type_index)
		selected_vertex_tileset_id_spin.value = tileset_id
	else:
		selected_vertex_id_value_label.text = "-"
		set_selected_vertex_logic_entries([], -1)
		for surface in selected_vertex_surface_override_checkboxes:
			selected_vertex_surface_override_checkboxes[surface].button_pressed = false
			selected_vertex_surface_override_spins[surface].visible = false
			selected_vertex_surface_override_spins[surface].value = 0
	is_updating_ui = false
	_update_mode_settings_visibility()


func set_selected_edge_data(is_selected: bool, edge_id: int = -1, edge_type: Edge.EdgeType = Edge.EdgeType.CORRIDOR, door_state: int = Door.DoorState.CLOSED, door_id: int = -1) -> void:
	has_selected_edge = is_selected
	is_updating_ui = true
	if has_selected_edge:
		selected_edge_id_value_label.text = str(edge_id)
		var edge_type_index := selected_edge_type_option.get_item_index(_edge_option_id_for(edge_type, door_state))
		if edge_type_index != -1: selected_edge_type_option.select(edge_type_index)
		_set_door_state_option(selected_edge_door_state_option, door_state)
		_set_selected_edge_door_fields(edge_type, door_id)
	else:
		selected_edge_id_value_label.text = "-"
		_set_door_state_option(selected_edge_door_state_option, int(Door.DoorState.CLOSED))
		_set_selected_edge_door_fields(Edge.EdgeType.CORRIDOR, -1)
	is_updating_ui = false
	_update_mode_settings_visibility()


func _set_selected_edge_door_fields(edge_type: Edge.EdgeType, door_id: int) -> void:
	var has_door := edge_type == Edge.EdgeType.DOOR
	selected_edge_door_state_label.visible = has_door
	selected_edge_door_state_option.visible = has_door
	selected_edge_door_state_option.disabled = not has_door
	selected_edge_door_id_label.visible = has_door
	selected_edge_door_id_spin.visible = has_door
	selected_edge_door_id_spin.editable = has_door
	selected_edge_door_id_spin.value = max(door_id, 0)

	selected_edge_closed_texture_id_label.visible = false
	selected_edge_closed_texture_id_spin.visible = false
	selected_edge_animation_type_label.visible = false
	selected_edge_animation_type_option.visible = false
	selected_edge_animation_duration_label.visible = false
	selected_edge_animation_duration_spin.visible = false
	selected_edge_animation_travel_label.visible = false
	selected_edge_animation_travel_spin.visible = false


func _set_add_edge_door_state_visibility(edge_type: Edge.EdgeType) -> void:
	var has_door := edge_type == Edge.EdgeType.DOOR
	add_edge_door_state_label.visible = has_door
	add_edge_door_state_option.visible = has_door
	add_edge_door_state_option.disabled = not has_door


func _set_door_state_option(option_button: OptionButton, door_state: int) -> void:
	if option_button == selected_vertex_logic_door_state_option and door_state == LOGIC_DOOR_STATE_TOGGLE_VALUE:
		var toggle_index := option_button.get_item_index(LOGIC_DOOR_STATE_TOGGLE_OPTION_ID)
		if toggle_index != -1:
			option_button.select(toggle_index)
		return
	var normalized_state := clampi(door_state, 0, Door.DoorState.size() - 1)
	var state_index := option_button.get_item_index(normalized_state)
	if state_index != -1:
		option_button.select(state_index)


func set_selected_vertex_logic_entries(entries: Array[VertexLogic], selected_index: int = -1) -> void:
	is_updating_ui = true
	selected_vertex_logic_entry_option.clear()
	for index in range(entries.size()):
		var logic := entries[index]
		var label := "Logic %d" % index
		if logic != null and logic.logic_id != &"":
			label = String(logic.logic_id)
		selected_vertex_logic_entry_option.add_item(label, index)

	var has_entries := entries.size() > 0
	if has_entries:
		var clamped_index := clampi(selected_index, 0, entries.size() - 1)
		selected_vertex_logic_entry_option.select(clamped_index)
		_set_selected_vertex_logic_values(entries[clamped_index])
	else:
		_set_selected_vertex_logic_values(null)
	is_updating_ui = false


func _set_selected_vertex_logic_values(logic: VertexLogic) -> void:
	var has_logic := logic != null
	selected_vertex_logic_entry_option.visible = has_logic
	remove_vertex_logic_button.disabled = not has_logic
	selected_vertex_logic_id_edit.editable = has_logic
	selected_vertex_logic_trigger_option.disabled = not has_logic
	selected_vertex_logic_required_direction_option.disabled = not has_logic
	selected_vertex_logic_one_shot_checkbox.disabled = not has_logic
	selected_vertex_logic_required_flags_edit.editable = has_logic
	selected_vertex_logic_action_type_option.disabled = not has_logic
	selected_vertex_logic_edge_id_spin.editable = has_logic
	selected_vertex_logic_edge_type_option.disabled = not has_logic
	selected_vertex_logic_door_state_option.disabled = not has_logic
	selected_vertex_logic_surface_override_target_vertex_id_spin.editable = has_logic
	selected_vertex_logic_surface_override_surface_option.disabled = not has_logic
	selected_vertex_logic_surface_override_texture_id_spin.editable = has_logic
	selected_vertex_logic_flag_id_edit.editable = has_logic
	selected_vertex_logic_flag_value_checkbox.disabled = not has_logic

	if not has_logic:
		selected_vertex_logic_id_edit.text = ""
		selected_vertex_logic_one_shot_checkbox.button_pressed = true
		selected_vertex_logic_required_flags_edit.text = ""
		selected_vertex_logic_flag_id_edit.text = ""
		selected_vertex_logic_flag_value_checkbox.button_pressed = true
		var any_direction_index := selected_vertex_logic_required_direction_option.get_item_index(int(Direction.Cardinal.NONE))
		if any_direction_index != -1:
			selected_vertex_logic_required_direction_option.select(any_direction_index)
		selected_vertex_logic_edge_id_spin.value = 0
		selected_vertex_logic_surface_override_target_vertex_id_spin.value = -1
		selected_vertex_logic_surface_override_texture_id_spin.value = 0
		var default_surface_index := selected_vertex_logic_surface_override_surface_option.get_item_index(int(Direction.Surface.NORTH))
		if default_surface_index != -1:
			selected_vertex_logic_surface_override_surface_option.select(default_surface_index)
		_set_door_state_option(selected_vertex_logic_door_state_option, int(Door.DoorState.CLOSED))
		_update_logic_trigger_visibility(VertexLogic.TriggerType.ON_ENTER)
		_update_logic_action_visibility("none")
		return

	selected_vertex_logic_id_edit.text = String(logic.logic_id)
	selected_vertex_logic_one_shot_checkbox.button_pressed = logic.one_shot
	selected_vertex_logic_required_flags_edit.text = _join_logic_flags(logic.required_flags)
	var trigger_index := selected_vertex_logic_trigger_option.get_item_index(int(logic.trigger_type))
	if trigger_index != -1:
		selected_vertex_logic_trigger_option.select(trigger_index)
	var required_direction_value := int(logic.required_direction)
	if required_direction_value == int(Direction.Cardinal.NONE):
		required_direction_value = int(logic.payload.get("required_direction", required_direction_value))
	var required_direction_index := selected_vertex_logic_required_direction_option.get_item_index(required_direction_value)
	if required_direction_index == -1:
		required_direction_index = selected_vertex_logic_required_direction_option.get_item_index(int(Direction.Cardinal.NONE))
	if required_direction_index != -1:
		selected_vertex_logic_required_direction_option.select(required_direction_index)

	var action_type := String(logic.payload.get("type", "none"))
	var action_index := _get_logic_action_index(action_type)
	selected_vertex_logic_action_type_option.select(action_index)

	selected_vertex_logic_edge_id_spin.value = int(logic.payload.get("edge_id", 0))
	var edge_type_int := int(logic.payload.get("edge_type", int(Edge.EdgeType.CORRIDOR)))
	if edge_type_int < 0 or edge_type_int >= Edge.EdgeType.size():
		edge_type_int = int(Edge.EdgeType.CORRIDOR)
	var edge_type_value := edge_type_int as Edge.EdgeType
	var door_state_mode := String(logic.payload.get("door_state_mode", ""))
	if door_state_mode == "" and not logic.one_shot and edge_type_value == Edge.EdgeType.DOOR:
		door_state_mode = "toggle"
	var door_state_int := int(logic.payload.get("door_state", int(Door.DoorState.CLOSED)))
	if door_state_int == LOGIC_DOOR_STATE_TOGGLE_VALUE:
		door_state_mode = "toggle"
	if door_state_int < 0 or door_state_int >= Door.DoorState.size():
		door_state_int = int(Door.DoorState.CLOSED)
	var door_state_value := LOGIC_DOOR_STATE_TOGGLE_VALUE if door_state_mode == "toggle" else door_state_int
	var edge_type_index := selected_vertex_logic_edge_type_option.get_item_index(_edge_option_id_for(edge_type_value, door_state_value))
	if edge_type_index != -1:
		selected_vertex_logic_edge_type_option.select(edge_type_index)
	_set_door_state_option(selected_vertex_logic_door_state_option, door_state_value)

	var surface_int := int(logic.payload.get("surface", int(Direction.Surface.NORTH)))
	if surface_int < 0 or surface_int >= Direction.Surface.size():
		surface_int = int(Direction.Surface.NORTH)
	selected_vertex_logic_surface_override_target_vertex_id_spin.value = int(logic.payload.get("target_vertex_id", -1))
	var surface_index := selected_vertex_logic_surface_override_surface_option.get_item_index(surface_int)
	if surface_index != -1:
		selected_vertex_logic_surface_override_surface_option.select(surface_index)
	selected_vertex_logic_surface_override_texture_id_spin.value = int(logic.payload.get("texture_id", 0))

	selected_vertex_logic_flag_id_edit.text = String(logic.payload.get("flag_id", ""))
	selected_vertex_logic_flag_value_checkbox.button_pressed = bool(logic.payload.get("value", true))
	_update_logic_trigger_visibility(logic.trigger_type)
	_update_logic_action_visibility(action_type)


func _join_logic_flags(flags: Array[StringName]) -> String:
	var values := PackedStringArray()
	for flag in flags:
		var value := String(flag).strip_edges()
		if value.is_empty():
			continue
		values.append(value)
	return ", ".join(values)


func _get_logic_action_index(action_type: String) -> int:
	match action_type:
		"set_edge_type":
			return 1
		"set_flag":
			return 2
		"set_surface_override":
			return 3
		_:
			return 0


func _get_logic_action_type_from_index(index: int) -> String:
	match index:
		1:
			return "set_edge_type"
		2:
			return "set_flag"
		3:
			return "set_surface_override"
		_:
			return "none"


func _update_logic_action_visibility(action_type: String) -> void:
	var is_edge := action_type == "set_edge_type"
	var edge_values := _edge_option_to_values(selected_vertex_logic_edge_type_option.get_item_id(selected_vertex_logic_edge_type_option.selected), selected_vertex_logic_door_state_option)
	var is_edge_door := is_edge and (edge_values["edge_type"] as Edge.EdgeType) == Edge.EdgeType.DOOR
	var is_flag := action_type == "set_flag"
	var is_surface_override := action_type == "set_surface_override"
	selected_vertex_logic_edge_id_label.visible = is_edge
	selected_vertex_logic_edge_id_spin.visible = is_edge
	selected_vertex_logic_edge_type_label.visible = is_edge
	selected_vertex_logic_edge_type_option.visible = is_edge
	selected_vertex_logic_door_state_label.visible = is_edge_door
	selected_vertex_logic_door_state_option.visible = is_edge_door
	selected_vertex_logic_door_state_option.disabled = not is_edge_door
	selected_vertex_logic_surface_override_target_vertex_id_label.visible = is_surface_override
	selected_vertex_logic_surface_override_target_vertex_id_spin.visible = is_surface_override
	selected_vertex_logic_surface_override_surface_label.visible = is_surface_override
	selected_vertex_logic_surface_override_surface_option.visible = is_surface_override
	selected_vertex_logic_surface_override_texture_id_label.visible = is_surface_override
	selected_vertex_logic_surface_override_texture_id_spin.visible = is_surface_override
	selected_vertex_logic_flag_id_label.visible = is_flag
	selected_vertex_logic_flag_id_edit.visible = is_flag
	selected_vertex_logic_flag_value_checkbox.visible = is_flag


func _update_logic_trigger_visibility(trigger_type: VertexLogic.TriggerType) -> void:
	var is_interact := trigger_type == VertexLogic.TriggerType.ON_INTERACT
	selected_vertex_logic_required_direction_label.visible = is_interact
	selected_vertex_logic_required_direction_option.visible = is_interact
	selected_vertex_logic_required_direction_option.disabled = not is_interact


func set_selected_vertex_surface_texture_override_enabled(surface: Direction.Surface, enabled: bool) -> void:
	is_updating_ui = true
	var checkbox: CheckBox = selected_vertex_surface_override_checkboxes.get(surface)
	var spinner: SpinBox = selected_vertex_surface_override_spins.get(surface)
	if checkbox != null: checkbox.button_pressed = enabled
	if spinner != null: spinner.visible = enabled
	is_updating_ui = false


func set_selected_vertex_surface_texture_override(surface: Direction.Surface, texture_id: int) -> void:
	is_updating_ui = true
	var spinner: SpinBox = selected_vertex_surface_override_spins.get(surface)
	if spinner != null: spinner.value = texture_id
	is_updating_ui = false


func set_selected_vertex_surface_overrides(surface_texture_overrides: Dictionary[Direction.Surface, int]) -> void:
	is_updating_ui = true
	for surface in selected_vertex_surface_override_checkboxes:
		var has_override := surface_texture_overrides.has(surface)
		var checkbox: CheckBox = selected_vertex_surface_override_checkboxes[surface]
		var spinner: SpinBox = selected_vertex_surface_override_spins[surface]
		checkbox.button_pressed = has_override
		spinner.visible = has_override
		spinner.value = int(surface_texture_overrides.get(surface, 0))
	is_updating_ui = false


func _on_selected_vertex_type_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_type_changed.emit(selected_vertex_type_option.get_item_id(index) as Vertex.VertexType)


func _on_selected_vertex_tileset_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_tileset_id_changed.emit(int(value))


func _on_selected_vertex_surface_override_toggled(is_enabled: bool, surface: Direction.Surface) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	set_selected_vertex_surface_texture_override_enabled(surface, is_enabled)
	selected_vertex_surface_override_toggled.emit(surface, is_enabled)


func _on_selected_vertex_surface_override_id_value_changed(value: float, surface: Direction.Surface) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_surface_texture_override_changed.emit(surface, int(value))


func _on_selected_edge_type_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_edge: return
	var edge_type := _edge_option_to_values(selected_edge_type_option.get_item_id(index), selected_edge_door_state_option)["edge_type"] as Edge.EdgeType
	_set_selected_edge_door_fields(edge_type, int(selected_edge_door_id_spin.value))
	var door_state := _door_state_from_option(selected_edge_door_state_option)
	if edge_type != Edge.EdgeType.DOOR:
		door_state = int(Door.DoorState.CLOSED)
	var edge_values := {
		"edge_type": edge_type,
		"door_state": door_state,
	}
	selected_edge_type_changed.emit(edge_values["edge_type"] as Edge.EdgeType, int(edge_values["door_state"]))


func _on_selected_edge_door_state_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_edge: return
	var edge_type := _edge_option_to_values(selected_edge_type_option.get_item_id(selected_edge_type_option.selected), selected_edge_door_state_option)["edge_type"] as Edge.EdgeType
	if edge_type != Edge.EdgeType.DOOR:
		return
	selected_edge_type_changed.emit(edge_type, _door_state_from_option(selected_edge_door_state_option))


func _on_selected_edge_door_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	if not has_selected_edge: return
	selected_edge_door_id_changed.emit(int(value))


func _on_add_vertex_logic_button_pressed() -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	add_selected_vertex_logic_requested.emit()


func _on_remove_vertex_logic_button_pressed() -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	remove_selected_vertex_logic_requested.emit()


func set_selected_vertex_logic_entry_label(index: int, label: String) -> void:
	if index < 0 or index >= selected_vertex_logic_entry_option.item_count:
		return
	var final_label := label
	if final_label.strip_edges().is_empty():
		final_label = "Logic %d" % index
	is_updating_ui = true
	selected_vertex_logic_entry_option.set_item_text(index, final_label)
	is_updating_ui = false


func _on_selected_vertex_logic_entry_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_entry_selected.emit(int(selected_vertex_logic_entry_option.get_item_id(index)))


func _on_selected_vertex_logic_id_text_changed(value: String) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_id_changed.emit(value)


func _on_selected_vertex_logic_trigger_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	var trigger := selected_vertex_logic_trigger_option.get_item_id(index) as VertexLogic.TriggerType
	_update_logic_trigger_visibility(trigger)
	selected_vertex_logic_trigger_changed.emit(trigger)


func _on_selected_vertex_logic_required_direction_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_required_direction_changed.emit(selected_vertex_logic_required_direction_option.get_item_id(index) as Direction.Cardinal)


func _on_selected_vertex_logic_one_shot_toggled(value: bool) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	var action_type := _get_logic_action_type_from_index(selected_vertex_logic_action_type_option.selected)
	_update_logic_action_visibility(action_type)
	selected_vertex_logic_one_shot_changed.emit(value)


func _on_selected_vertex_logic_required_flags_text_changed(value: String) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_required_flags_changed.emit(value)


func _on_selected_vertex_logic_action_type_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	var action_type := _get_logic_action_type_from_index(index)
	_update_logic_action_visibility(action_type)
	selected_vertex_logic_action_type_changed.emit(action_type)


func _on_selected_vertex_logic_edge_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_edge_id_changed.emit(int(value))


func _on_selected_vertex_logic_edge_type_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	var edge_values := _edge_option_to_values(selected_vertex_logic_edge_type_option.get_item_id(index), selected_vertex_logic_door_state_option)
	_update_logic_action_visibility("set_edge_type")
	selected_vertex_logic_edge_type_changed.emit(edge_values["edge_type"] as Edge.EdgeType, int(edge_values["door_state"]))


func _on_selected_vertex_logic_door_state_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	var edge_values := _edge_option_to_values(selected_vertex_logic_edge_type_option.get_item_id(selected_vertex_logic_edge_type_option.selected), selected_vertex_logic_door_state_option)
	if edge_values["edge_type"] as Edge.EdgeType != Edge.EdgeType.DOOR:
		return
	selected_vertex_logic_edge_type_changed.emit(Edge.EdgeType.DOOR, _door_state_from_option(selected_vertex_logic_door_state_option))


func _on_selected_vertex_logic_surface_override_target_vertex_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_surface_override_target_vertex_id_changed.emit(int(value))


func _on_selected_vertex_logic_surface_override_surface_selected(index: int) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_surface_override_surface_changed.emit(selected_vertex_logic_surface_override_surface_option.get_item_id(index) as Direction.Surface)


func _on_selected_vertex_logic_surface_override_texture_id_value_changed(value: float) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_surface_override_texture_id_changed.emit(int(value))


func _on_selected_vertex_logic_flag_id_text_changed(value: String) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_flag_id_changed.emit(value)


func _on_selected_vertex_logic_flag_value_toggled(value: bool) -> void:
	if is_updating_ui: return
	if not has_selected_vertex: return
	selected_vertex_logic_flag_value_changed.emit(value)


func _update_mode_settings_visibility() -> void:
	mode_settings_container.visible = current_edit_mode == EditMode.ADD_VERTEX or current_edit_mode == EditMode.ADD_EDGE
	add_vertex_settings.visible = current_edit_mode == EditMode.ADD_VERTEX
	add_edge_settings.visible = current_edit_mode == EditMode.ADD_EDGE
	selected_details_container.visible = true
	no_selection_label.visible = not ((current_edit_mode == EditMode.SELECT_VERTEX and has_selected_vertex) or (current_edit_mode == EditMode.SELECT_EDGE and has_selected_edge))
	select_vertex_settings.visible = current_edit_mode == EditMode.SELECT_VERTEX and has_selected_vertex
	select_edge_settings.visible = current_edit_mode == EditMode.SELECT_EDGE and has_selected_edge
