extends RefCounted
class_name VertexLogicResolver


func apply_on_enter(graph: Graph, run_state: DungeonRunState, vertex_id: int) -> void:
	if graph == null or run_state == null:
		return

	var entries := graph.get_vertex_logic(vertex_id)
	for logic in entries:
		if logic == null:
			continue
		if logic.trigger_type != VertexLogic.TriggerType.ON_ENTER:
			continue
		if logic.one_shot and run_state.has_triggered(logic.logic_id):
			continue
		if not logic.can_run(run_state.world_flags):
			continue

		_apply_payload(graph, run_state, vertex_id, logic.payload)
		graph.emit_signal(&"vertex_logic_triggered", vertex_id, logic.logic_id)
		if logic.one_shot:
			run_state.mark_triggered(logic.logic_id)


func apply_on_interact(graph: Graph, run_state: DungeonRunState, vertex_id: int, facing_direction: Direction.Cardinal) -> void:
	if graph == null or run_state == null:
		return

	var entries := graph.get_vertex_logic(vertex_id)
	for logic in entries:
		if logic == null:
			continue
		if logic.trigger_type != VertexLogic.TriggerType.ON_INTERACT:
			continue
		if logic.one_shot and run_state.has_triggered(logic.logic_id):
			continue
		if not logic.can_run(run_state.world_flags):
			continue
		var required_direction := _resolve_required_direction(logic)
		if required_direction != Direction.Cardinal.NONE and required_direction != facing_direction:
			continue

		_apply_payload(graph, run_state, vertex_id, logic.payload)
		graph.emit_signal(&"vertex_logic_triggered", vertex_id, logic.logic_id)
		if logic.one_shot:
			run_state.mark_triggered(logic.logic_id)


func _resolve_required_direction(logic: VertexLogic) -> Direction.Cardinal:
	var required_direction := logic.required_direction
	if required_direction == Direction.Cardinal.NONE:
		var payload_direction := int(logic.payload.get("required_direction", int(Direction.Cardinal.NONE)))
		if payload_direction >= int(Direction.Cardinal.NONE) and payload_direction < Direction.Cardinal.size():
			required_direction = payload_direction as Direction.Cardinal
	return required_direction


func _apply_payload(graph: Graph, run_state: DungeonRunState, source_vertex_id: int, payload: Dictionary) -> void:
	var action_type := String(payload.get("type", ""))
	match action_type:
		"set_edge_type":
			_apply_set_edge_type(graph, payload)
		"set_surface_override":
			_apply_set_surface_override(graph, source_vertex_id, payload)
		"set_flag":
			var flag_id: StringName = payload.get("flag_id", &"")
			var value := bool(payload.get("value", true))
			run_state.set_flag(flag_id, value)
		_:
			return


func _apply_set_edge_type(graph: Graph, payload: Dictionary) -> void:
	var edge_id := int(payload.get("edge_id", -1))
	if edge_id < 0:
		return

	var edge: Edge = graph.edges.get(edge_id)
	if edge == null:
		return

	var raw_type := int(payload.get("edge_type", int(Edge.EdgeType.CORRIDOR)))
	if raw_type < 0 or raw_type >= Edge.EdgeType.size():
		return
	edge.type = raw_type as Edge.EdgeType
	if edge.type == Edge.EdgeType.DOOR:
		var door_state_mode := String(payload.get("door_state_mode", "fixed"))
		var raw_state := int(payload.get("door_state", int(Door.DoorState.CLOSED)))
		if door_state_mode == "toggle" or raw_state < 0:
			var current_state := clampi(int(edge.door_state), 0, Door.DoorState.size() - 1)
			edge.door_state = Door.DoorState.CLOSED if current_state == int(Door.DoorState.OPEN) else Door.DoorState.OPEN
		else:
			if raw_state < 0 or raw_state >= Door.DoorState.size():
				return
			edge.door_state = raw_state
		edge.door_id = int(payload.get("door_id", edge.door_id))
	else:
		edge.door_state = Door.DoorState.CLOSED
		edge.door_id = -1


func _apply_set_surface_override(graph: Graph, source_vertex_id: int, payload: Dictionary) -> void:
	var target_vertex_id := int(payload.get("target_vertex_id", -1))
	if target_vertex_id < 0:
		target_vertex_id = source_vertex_id

	var vertex: Vertex = graph.vertices.get(target_vertex_id)
	if vertex == null:
		return

	var surface_int := int(payload.get("surface", int(Direction.Surface.NORTH)))
	if surface_int < 0 or surface_int >= Direction.Surface.size():
		return

	var texture_id := max(0, int(payload.get("texture_id", 0)))
	var writable_overrides := vertex.surface_texture_overrides.duplicate(true)
	writable_overrides[surface_int] = texture_id
	vertex.surface_texture_overrides = writable_overrides
