@tool
extends Control


@onready var editor_ui = $MarginContainer/Controls

@onready var map_viewport_container: MapRendererSubViewport = $Map

var pending_edge_start_vertex_id: int = -1
var selected_vertex_id: int = -1
var selected_edge_id: int = -1
var selected_vertex_logic_index: int = -1
var current_edit_mode: MapEditorUI.EditMode = MapEditorUI.EditMode.ADD_VERTEX
var current_vertex_type: Vertex.VertexType = Vertex.VertexType.ROOM
var current_tileset_id: int = 0
var current_edge_type: Edge.EdgeType = Edge.EdgeType.CORRIDOR
var current_door_state: int = Door.DoorState.CLOSED
var current_door_id: int = 0
var auto_connect_edges_enabled: bool = true
const LOGIC_DOOR_STATE_TOGGLE := -1

func _ready() -> void:
    editor_ui.open_file_selected.connect(on_file_dialog_open_file_selected)
    editor_ui.save_file_selected.connect(on_file_dialog_save_file_selected)
    editor_ui.add_vertex_type_changed.connect(_on_add_vertex_type_changed)
    editor_ui.add_vertex_tileset_id_changed.connect(_on_add_vertex_tileset_id_changed)
    editor_ui.auto_connect_edges_changed.connect(_on_auto_connect_edges_changed)
    editor_ui.add_edge_type_changed.connect(_on_add_edge_type_changed)
    editor_ui.add_edge_door_id_changed.connect(_on_add_edge_door_id_changed)
    editor_ui.selected_vertex_tileset_id_changed.connect(_on_selected_vertex_tileset_id_changed)
    editor_ui.selected_vertex_type_changed.connect(_on_selected_vertex_type_changed)
    editor_ui.selected_vertex_surface_override_toggled.connect(_on_selected_vertex_surface_override_toggled)
    editor_ui.selected_vertex_surface_texture_override_changed.connect(_on_selected_vertex_surface_texture_override_changed)
    editor_ui.selected_vertex_logic_entry_selected.connect(_on_selected_vertex_logic_entry_selected)
    editor_ui.selected_vertex_logic_id_changed.connect(_on_selected_vertex_logic_id_changed)
    editor_ui.selected_vertex_logic_trigger_changed.connect(_on_selected_vertex_logic_trigger_changed)
    editor_ui.selected_vertex_logic_required_direction_changed.connect(_on_selected_vertex_logic_required_direction_changed)
    editor_ui.selected_vertex_logic_one_shot_changed.connect(_on_selected_vertex_logic_one_shot_changed)
    editor_ui.selected_vertex_logic_required_flags_changed.connect(_on_selected_vertex_logic_required_flags_changed)
    editor_ui.selected_vertex_logic_action_type_changed.connect(_on_selected_vertex_logic_action_type_changed)
    editor_ui.selected_vertex_logic_edge_id_changed.connect(_on_selected_vertex_logic_edge_id_changed)
    editor_ui.selected_vertex_logic_edge_type_changed.connect(_on_selected_vertex_logic_edge_type_changed)
    editor_ui.selected_vertex_logic_surface_override_target_vertex_id_changed.connect(_on_selected_vertex_logic_surface_override_target_vertex_id_changed)
    editor_ui.selected_vertex_logic_surface_override_surface_changed.connect(_on_selected_vertex_logic_surface_override_surface_changed)
    editor_ui.selected_vertex_logic_surface_override_texture_id_changed.connect(_on_selected_vertex_logic_surface_override_texture_id_changed)
    editor_ui.selected_vertex_logic_flag_id_changed.connect(_on_selected_vertex_logic_flag_id_changed)
    editor_ui.selected_vertex_logic_flag_value_changed.connect(_on_selected_vertex_logic_flag_value_changed)
    editor_ui.add_selected_vertex_logic_requested.connect(_on_add_selected_vertex_logic_requested)
    editor_ui.remove_selected_vertex_logic_requested.connect(_on_remove_selected_vertex_logic_requested)
    editor_ui.selected_edge_type_changed.connect(_on_selected_edge_type_changed)
    editor_ui.selected_edge_door_id_changed.connect(_on_selected_edge_door_id_changed)
    editor_ui.edit_mode_changed.connect(_on_edit_mode_changed)
    map_viewport_container.gui_input.connect(_on_map_gui_input)
    map_viewport_container.map.drawGrid = true
    _sync_ui_from_state()


func _on_map_gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton): return
    var mouse_button_event := event as InputEventMouseButton
    if current_edit_mode != MapEditorUI.EditMode.ADD_EDGE: pending_edge_start_vertex_id = -1
    if mouse_button_event.pressed:
        if current_edit_mode == MapEditorUI.EditMode.ADD_VERTEX:
            if mouse_button_event.button_index == MOUSE_BUTTON_LEFT: _try_add_vertex_from_click(mouse_button_event)
            elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT: _try_remove_vertex_from_click(mouse_button_event)
        elif current_edit_mode == MapEditorUI.EditMode.ADD_EDGE:
            if mouse_button_event.button_index == MOUSE_BUTTON_LEFT: _try_modify_edge_from_click(mouse_button_event, true)
            elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT: _try_modify_edge_from_click(mouse_button_event, false)
        elif current_edit_mode == MapEditorUI.EditMode.SELECT_VERTEX:
            if mouse_button_event.button_index == MOUSE_BUTTON_LEFT: _try_select_vertex_from_click(mouse_button_event)
        elif current_edit_mode == MapEditorUI.EditMode.SELECT_EDGE:
            if mouse_button_event.button_index == MOUSE_BUTTON_LEFT: _try_select_edge_from_click(mouse_button_event)
    map_viewport_container.get_viewport().set_input_as_handled()


func _get_grid_position_from_click(map: MapRenderer, mouse_button_event: InputEventMouseButton) -> Vector2i:
    var local_position := mouse_button_event.position - map.position
    return Vector2i(floori(local_position.x / map.CELL_SIZE.x), floori(local_position.y / map.CELL_SIZE.y))


func _try_add_vertex_from_click(mouse_button_event: InputEventMouseButton) -> void:
    var map := map_viewport_container.map
    if map.graph == null: map.graph = Graph.new()
    var grid_position := _get_grid_position_from_click(map, mouse_button_event)
    if _get_vertex_at_position(grid_position) != null: return
    var new_vertex := map.graph.add_vertex(grid_position, current_vertex_type)
    new_vertex.type_tileset_id = current_tileset_id
    if auto_connect_edges_enabled: _auto_connect_edges(new_vertex)
    map.queue_redraw()


func _try_remove_vertex_from_click(mouse_button_event: InputEventMouseButton) -> void:
    var map := map_viewport_container.map
    if map.graph == null: return
    var grid_position := _get_grid_position_from_click(map, mouse_button_event)
    var vertex := _get_vertex_at_position(grid_position)
    if vertex == null: return
    _remove_vertex_and_connections(map.graph, vertex)
    map.queue_redraw()


func _try_select_vertex_from_click(mouse_button_event: InputEventMouseButton) -> void:
    var map := map_viewport_container.map
    if map.graph == null:
        _set_selected_vertex(null)
        return
    var grid_position := _get_grid_position_from_click(map, mouse_button_event)
    var vertex := _get_vertex_at_position(grid_position)
    _set_selected_vertex(vertex)


func _try_select_edge_from_click(mouse_button_event: InputEventMouseButton) -> void:
    var map := map_viewport_container.map
    if map.graph == null:
        _set_selected_edge(null)
        return
    var local_position := mouse_button_event.position - map.position
    var edge := _get_edge_at_local_position(local_position)
    _set_selected_edge(edge)


func _try_modify_edge_from_click(mouse_button_event: InputEventMouseButton, should_add: bool) -> void:
    var map := map_viewport_container.map
    if map.graph == null: return
    var grid_position := _get_grid_position_from_click(map, mouse_button_event)
    var clicked_vertex := _get_vertex_at_position(grid_position)
    if clicked_vertex == null: return
    if pending_edge_start_vertex_id == -1:
        pending_edge_start_vertex_id = clicked_vertex.id
        return
    var start_vertex: Vertex = map.graph.vertices.get(pending_edge_start_vertex_id)
    pending_edge_start_vertex_id = -1
    if start_vertex == null: return
    if start_vertex.id == clicked_vertex.id: return
    var delta: Vector2i = clicked_vertex.position - start_vertex.position
    var normalized_delta := Vector2i(signi(delta.x), signi(delta.y))
    var direction = Direction.direction_from_delta(normalized_delta)
    if direction == Direction.Cardinal.NONE: return
    if start_vertex.edges.has(direction):
        var existing_edge: Edge = start_vertex.edges[direction]
        if existing_edge != null: _remove_edge_by_id(map.graph, existing_edge.id)
    #In most cases the above should fix this, but the below can occur when skipping a cell in the given direction
    var opposite_direction := Direction.get_opposite(direction)
    if clicked_vertex.edges.has(opposite_direction):
        var existing_edge: Edge = clicked_vertex.edges[opposite_direction]
        if existing_edge != null: _remove_edge_by_id(map.graph, existing_edge.id)
    if should_add: map.graph.connect_vertices(start_vertex.id, clicked_vertex.id, direction, current_edge_type, current_door_state, current_door_id)
    map.queue_redraw()


func _auto_connect_edges(new_vertex: Vertex) -> void:
    var graph := map_viewport_container.map.graph
    for direction in Direction.DIRECTION_TO_OFFSET:
        var offset: Vector2i = Direction.DIRECTION_TO_OFFSET[direction]
        var neighbor_position := new_vertex.position + offset
        var neighbor_vertex := _get_vertex_at_position(neighbor_position)
        if neighbor_vertex == null: continue
        if new_vertex.edges.has(direction): continue
        graph.connect_vertices(new_vertex.id, neighbor_vertex.id, direction, Edge.EdgeType.CORRIDOR)


func _remove_vertex_and_connections(graph: Graph, vertex: Vertex) -> void:
    while not vertex.edges.is_empty():
        var direction: Direction.Cardinal = vertex.edges.keys()[0]
        var edge: Edge = vertex.edges[direction]
        if edge == null:
            vertex.edges.erase(direction)
            continue
        _remove_edge_by_id(graph, edge.id)
    graph.vertices.erase(vertex.id)


func _remove_edge_by_id(graph: Graph, edge_id: int) -> void:
    var edge: Edge = graph.edges.get(edge_id)
    if edge == null: return
    var vertex_a: Vertex = graph.vertices.get(edge.vertex_a_id)
    if vertex_a != null: vertex_a.edges.erase(edge.direction_from_a)
    var vertex_b: Vertex = graph.vertices.get(edge.vertex_b_id)
    if vertex_b != null: vertex_b.edges.erase(edge.direction_from_b)
    graph.edges.erase(edge_id)


func _get_vertex_at_position(position: Vector2i) -> Vertex:
    if map_viewport_container.map.graph == null: return null
    for vertex_id in map_viewport_container.map.graph.vertices:
        var vertex = map_viewport_container.map.graph.vertices[vertex_id]
        if vertex != null and vertex.position == position: return vertex
    return null


func _set_selected_vertex(vertex: Vertex) -> void:
    selected_vertex_id = -1 if vertex == null else vertex.id
    if vertex == null:
        selected_vertex_logic_index = -1
        editor_ui.set_selected_vertex_data(false)
        editor_ui.set_selected_vertex_logic_entries(_empty_vertex_logic_entries(), -1)
        map_viewport_container.request_resize_sync()
        return
    editor_ui.set_selected_vertex_data(true, vertex.id, vertex.type, vertex.type_tileset_id)
    editor_ui.set_selected_vertex_surface_overrides(vertex.surface_texture_overrides)
    var entries: Array[VertexLogic] = map_viewport_container.map.graph.get_vertex_logic(vertex.id)
    selected_vertex_logic_index = 0 if entries.size() > 0 else -1
    editor_ui.set_selected_vertex_logic_entries(entries, selected_vertex_logic_index)
    map_viewport_container.request_resize_sync()


func _set_selected_edge(edge: Edge) -> void:
    selected_edge_id = -1 if edge == null else edge.id
    if edge == null:
        editor_ui.set_selected_edge_data(false)
        map_viewport_container.request_resize_sync()
        return
    editor_ui.set_selected_edge_data(true, edge.id, edge.type, edge.door_state, edge.door_id)
    map_viewport_container.request_resize_sync()


func _get_selected_vertex() -> Vertex:
    if selected_vertex_id == -1: return null
    var graph := map_viewport_container.map.graph
    if graph == null: return null
    return graph.vertices.get(selected_vertex_id)


func _get_selected_edge() -> Edge:
    if selected_edge_id == -1: return null
    var graph := map_viewport_container.map.graph
    if graph == null: return null
    return graph.edges.get(selected_edge_id)


func _get_selected_vertex_logic() -> VertexLogic:
    var selected_vertex := _get_selected_vertex()
    var graph := map_viewport_container.map.graph
    if selected_vertex == null or graph == null:
        return null
    var entries: Array[VertexLogic] = graph.get_vertex_logic(selected_vertex.id)
    if selected_vertex_logic_index < 0 or selected_vertex_logic_index >= entries.size():
        return null
    return entries[selected_vertex_logic_index]


func _refresh_selected_vertex_logic_ui() -> void:
    var selected_vertex := _get_selected_vertex()
    var graph := map_viewport_container.map.graph
    if selected_vertex == null or graph == null:
        selected_vertex_logic_index = -1
        editor_ui.set_selected_vertex_logic_entries(_empty_vertex_logic_entries(), -1)
        return
    var entries: Array[VertexLogic] = graph.get_vertex_logic(selected_vertex.id)
    if entries.is_empty():
        selected_vertex_logic_index = -1
        editor_ui.set_selected_vertex_logic_entries(_empty_vertex_logic_entries(), -1)
        return
    selected_vertex_logic_index = clampi(selected_vertex_logic_index, 0, entries.size() - 1)
    editor_ui.set_selected_vertex_logic_entries(entries, selected_vertex_logic_index)


func _empty_vertex_logic_entries() -> Array[VertexLogic]:
    var entries: Array[VertexLogic] = []
    return entries


func _get_edge_at_local_position(local_position: Vector2) -> Edge:
    var map := map_viewport_container.map
    var graph := map.graph
    if graph == null:
        return null

    var best_edge: Edge = null
    var best_distance := 8.0
    for edge in graph.edges.values():
        if edge == null:
            continue
        var start_vertex: Vertex = graph.vertices.get(edge.vertex_a_id)
        var end_vertex: Vertex = graph.vertices.get(edge.vertex_b_id)
        if start_vertex == null or end_vertex == null:
            continue
        var start_point := Vector2(start_vertex.position * map.CELL_SIZE + map.EDGE_OFFSET)
        var end_point := Vector2(end_vertex.position * map.CELL_SIZE + map.EDGE_OFFSET)
        var distance := Geometry2D.get_closest_point_to_segment(local_position, start_point, end_point).distance_to(local_position)
        if distance < best_distance:
            best_distance = distance
            best_edge = edge

    return best_edge


func _sync_ui_from_state() -> void:
    editor_ui.set_edit_mode(current_edit_mode)
    editor_ui.set_add_vertex_type(current_vertex_type)
    editor_ui.set_add_vertex_tileset_id(current_tileset_id)
    editor_ui.set_auto_connect_edges_enabled(auto_connect_edges_enabled)
    editor_ui.set_add_edge_type(current_edge_type, current_door_state)
    editor_ui.set_add_edge_door_id(current_door_id)
    editor_ui.set_selected_vertex_data(false)


func _on_add_vertex_type_changed(vertex_type: Vertex.VertexType) -> void:
    current_vertex_type = vertex_type


func _on_add_vertex_tileset_id_changed(tileset_id: int) -> void:
    current_tileset_id = tileset_id


func _on_auto_connect_edges_changed(is_enabled: bool) -> void:
    auto_connect_edges_enabled = is_enabled


func _on_add_edge_type_changed(edge_type: Edge.EdgeType, door_state: int) -> void:
    current_edge_type = edge_type
    current_door_state = door_state


func _on_add_edge_door_id_changed(door_id: int) -> void:
    current_door_id = max(door_id, 0)


func _on_selected_vertex_tileset_id_changed(tileset_id: int) -> void:
    var selected_vertex := _get_selected_vertex()
    if selected_vertex == null: return
    if selected_vertex.type_tileset_id == tileset_id: return
    selected_vertex.type_tileset_id = tileset_id
    map_viewport_container.map.queue_redraw()


func _on_selected_vertex_type_changed(vertex_type: Vertex.VertexType) -> void:
    var selected_vertex := _get_selected_vertex()
    if selected_vertex == null: return
    if selected_vertex.type == vertex_type: return
    selected_vertex.type = vertex_type
    map_viewport_container.map.queue_redraw()


func _on_selected_vertex_surface_override_toggled(surface: Direction.Surface, is_enabled: bool) -> void:
    var selected_vertex := _get_selected_vertex()
    if selected_vertex == null: return
    var writable_overrides := selected_vertex.surface_texture_overrides.duplicate(true)
    if is_enabled:
        writable_overrides[surface] = int(writable_overrides.get(surface, 0))
    else:
        writable_overrides.erase(surface)
    selected_vertex.surface_texture_overrides = writable_overrides
    map_viewport_container.map.queue_redraw()


func _on_selected_vertex_surface_texture_override_changed(surface: Direction.Surface, texture_id: int) -> void:
    var selected_vertex := _get_selected_vertex()
    if selected_vertex == null: return
    var writable_overrides := selected_vertex.surface_texture_overrides.duplicate(true)
    if not writable_overrides.has(surface): return
    if int(writable_overrides.get(surface, 0)) == texture_id: return
    writable_overrides[surface] = texture_id
    selected_vertex.surface_texture_overrides = writable_overrides
    map_viewport_container.map.queue_redraw()


func _on_selected_edge_type_changed(edge_type: Edge.EdgeType, door_state: int) -> void:
    var selected_edge := _get_selected_edge()
    if selected_edge == null: return
    var selected_door_state := int(selected_edge.door_state)
    if selected_edge.type == edge_type and selected_door_state == door_state: return
    selected_edge.type = edge_type
    if edge_type == Edge.EdgeType.DOOR:
        selected_edge.door_state = clampi(door_state, 0, Door.DoorState.size() - 1)
        if selected_edge.door_id < 0:
            selected_edge.door_id = max(current_door_id, 0)
    else:
        selected_edge.door_state = Door.DoorState.CLOSED
        selected_edge.door_id = -1
    editor_ui.set_selected_edge_data(true, selected_edge.id, selected_edge.type, selected_edge.door_state, selected_edge.door_id)
    map_viewport_container.map.queue_redraw()


func _on_selected_edge_door_id_changed(door_id: int) -> void:
    var selected_edge := _get_selected_edge()
    if selected_edge == null or selected_edge.type != Edge.EdgeType.DOOR: return
    var clamped_door_id := max(door_id, 0)
    if selected_edge.door_id == clamped_door_id: return
    selected_edge.door_id = clamped_door_id
    editor_ui.set_selected_edge_data(true, selected_edge.id, selected_edge.type, selected_edge.door_state, selected_edge.door_id)
    map_viewport_container.map.queue_redraw()


func _on_add_selected_vertex_logic_requested() -> void:
    var graph := map_viewport_container.map.graph
    var selected_vertex := _get_selected_vertex()
    if graph == null or selected_vertex == null:
        return

    var new_logic := VertexLogic.new()
    new_logic.logic_id = StringName("vertex_%d_logic_%d" % [selected_vertex.id, Time.get_unix_time_from_system()])
    new_logic.trigger_type = VertexLogic.TriggerType.ON_ENTER
    new_logic.one_shot = true
    var entries := graph.get_vertex_logic(selected_vertex.id).duplicate(true)
    entries.append(new_logic)
    if graph.set_vertex_logic(selected_vertex.id, entries):
        var refreshed_entries := graph.get_vertex_logic(selected_vertex.id)
        selected_vertex_logic_index = refreshed_entries.size() - 1
        _refresh_selected_vertex_logic_ui()
        print("Added VertexLogic to vertex %d" % selected_vertex.id)


func _on_selected_vertex_logic_entry_selected(index: int) -> void:
    selected_vertex_logic_index = index
    _refresh_selected_vertex_logic_ui()


func _on_selected_vertex_logic_id_changed(value: String) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.logic_id = StringName(value)
    editor_ui.set_selected_vertex_logic_entry_label(selected_vertex_logic_index, value)


func _on_remove_selected_vertex_logic_requested() -> void:
    var graph := map_viewport_container.map.graph
    var selected_vertex := _get_selected_vertex()
    if graph == null or selected_vertex == null:
        return

    var entries := graph.get_vertex_logic(selected_vertex.id)
    if selected_vertex_logic_index < 0 or selected_vertex_logic_index >= entries.size():
        return

    var writable_entries := entries.duplicate(true)
    writable_entries.remove_at(selected_vertex_logic_index)
    if graph.set_vertex_logic(selected_vertex.id, writable_entries):
        if writable_entries.is_empty():
            selected_vertex_logic_index = -1
        else:
            selected_vertex_logic_index = mini(selected_vertex_logic_index, writable_entries.size() - 1)
        _refresh_selected_vertex_logic_ui()


func _on_selected_vertex_logic_trigger_changed(trigger_type: VertexLogic.TriggerType) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.trigger_type = trigger_type
    if trigger_type == VertexLogic.TriggerType.ON_INTERACT:
        logic.payload["required_direction"] = int(logic.required_direction)
    else:
        logic.payload.erase("required_direction")
    _refresh_selected_vertex_logic_ui()


func _on_selected_vertex_logic_required_direction_changed(direction: Direction.Cardinal) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.required_direction = direction
    logic.payload["required_direction"] = int(direction)


func _on_selected_vertex_logic_one_shot_changed(value: bool) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.one_shot = value
    var edge_type_int := int(logic.payload.get("edge_type", int(Edge.EdgeType.CORRIDOR)))
    var edge_type := Edge.EdgeType.CORRIDOR
    if edge_type_int >= 0 and edge_type_int < Edge.EdgeType.size():
        edge_type = edge_type_int as Edge.EdgeType
    var door_state_mode := String(logic.payload.get("door_state_mode", ""))
    var stored_door_state := int(logic.payload.get("door_state", int(Door.DoorState.CLOSED)))
    var door_state := LOGIC_DOOR_STATE_TOGGLE if door_state_mode == "toggle" or stored_door_state == LOGIC_DOOR_STATE_TOGGLE else stored_door_state
    _sync_selected_vertex_logic_door_payload(logic, edge_type, door_state)
    _refresh_selected_vertex_logic_ui()


func _on_selected_vertex_logic_required_flags_changed(raw_flags: String) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.required_flags = _parse_logic_flags(raw_flags)


func _parse_logic_flags(raw_flags: String) -> Array[StringName]:
    var parsed: Array[StringName] = []
    var seen: Dictionary[StringName, bool] = {}
    for raw_entry in raw_flags.split(",", false):
        var clean_entry := raw_entry.strip_edges()
        if clean_entry.is_empty():
            continue
        var flag_id := StringName(clean_entry)
        if seen.has(flag_id):
            continue
        seen[flag_id] = true
        parsed.append(flag_id)
    return parsed


func _on_selected_vertex_logic_action_type_changed(action_type: String) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    if action_type == "none":
        logic.payload.erase("type")
    else:
        logic.payload["type"] = action_type

    if action_type == "set_edge_type":
        var edge_type_int := int(logic.payload.get("edge_type", int(Edge.EdgeType.CORRIDOR)))
        var edge_type := Edge.EdgeType.CORRIDOR
        if edge_type_int >= 0 and edge_type_int < Edge.EdgeType.size():
            edge_type = edge_type_int as Edge.EdgeType
        var door_state_mode := String(logic.payload.get("door_state_mode", ""))
        var stored_door_state := int(logic.payload.get("door_state", int(Door.DoorState.CLOSED)))
        var door_state := LOGIC_DOOR_STATE_TOGGLE if door_state_mode == "toggle" or stored_door_state == LOGIC_DOOR_STATE_TOGGLE else stored_door_state
        _sync_selected_vertex_logic_door_payload(logic, edge_type, door_state)
    elif action_type == "set_surface_override":
        var surface := int(logic.payload.get("surface", int(Direction.Surface.NORTH)))
        if surface < 0 or surface >= Direction.Surface.size():
            surface = int(Direction.Surface.NORTH)
        logic.payload["surface"] = surface
        logic.payload["target_vertex_id"] = int(logic.payload.get("target_vertex_id", -1))
        logic.payload["texture_id"] = max(0, int(logic.payload.get("texture_id", 0)))
    _refresh_selected_vertex_logic_ui()


func _on_selected_vertex_logic_edge_id_changed(edge_id: int) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["edge_id"] = edge_id


func _on_selected_vertex_logic_edge_type_changed(edge_type: Edge.EdgeType, door_state: int) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["edge_type"] = int(edge_type)
    _sync_selected_vertex_logic_door_payload(logic, edge_type, door_state)


func _on_selected_vertex_logic_surface_override_surface_changed(surface: Direction.Surface) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["surface"] = int(surface)


func _on_selected_vertex_logic_surface_override_target_vertex_id_changed(vertex_id: int) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["target_vertex_id"] = vertex_id


func _on_selected_vertex_logic_surface_override_texture_id_changed(texture_id: int) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["texture_id"] = max(texture_id, 0)


func _sync_selected_vertex_logic_door_payload(logic: VertexLogic, edge_type: Edge.EdgeType, door_state: int) -> void:
    if edge_type != Edge.EdgeType.DOOR:
        logic.payload.erase("door_state")
        logic.payload.erase("door_state_mode")
        return

    if door_state == LOGIC_DOOR_STATE_TOGGLE:
        logic.payload["door_state_mode"] = "toggle"
        logic.payload["door_state"] = LOGIC_DOOR_STATE_TOGGLE
    else:
        logic.payload["door_state_mode"] = "fixed"
        logic.payload["door_state"] = clampi(int(door_state), 0, Door.DoorState.size() - 1)


func _on_selected_vertex_logic_flag_id_changed(flag_id: String) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    if flag_id.strip_edges().is_empty():
        logic.payload.erase("flag_id")
    else:
        logic.payload["flag_id"] = StringName(flag_id)


func _on_selected_vertex_logic_flag_value_changed(value: bool) -> void:
    var logic := _get_selected_vertex_logic()
    if logic == null: return
    logic.payload["value"] = value


func _on_edit_mode_changed(previous_mode: MapEditorUI.EditMode, current_mode: MapEditorUI.EditMode) -> void:
    current_edit_mode = current_mode
    if previous_mode == MapEditorUI.EditMode.SELECT_VERTEX and current_mode != MapEditorUI.EditMode.SELECT_VERTEX:
        _set_selected_vertex(null)
    if previous_mode == MapEditorUI.EditMode.SELECT_EDGE and current_mode != MapEditorUI.EditMode.SELECT_EDGE:
        _set_selected_edge(null)
    map_viewport_container.request_resize_sync()


func on_file_dialog_open_file_selected(path: String) -> void:
    var loaded_graph = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    if loaded_graph:
        map_viewport_container.map.graph = loaded_graph.duplicate(true)
        _set_selected_vertex(null)
        map_viewport_container.map.queue_redraw()


func on_file_dialog_save_file_selected(path: String) -> void:
    if map_viewport_container.map && map_viewport_container.map.graph:
        return ResourceSaver.save(map_viewport_container.map.graph, path)