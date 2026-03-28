@tool
extends Node3D
class_name GraphRenderer


const OPEN_NORTH := 1
const OPEN_EAST := 2
const OPEN_SOUTH := 4
const OPEN_WEST := 8

@export var graph: Graph:
	set(value):
		graph = _reload_graph_from_disk(value)
		if _should_auto_render():
			call_deferred("render_graph")

@export_range(0.25, 32.0, 0.25) var cell_size: float = 2.0:
	set(value):
		cell_size = maxf(value, 0.25)
		if _should_auto_render():
			call_deferred("render_graph")

@export var auto_render_in_editor: bool = true
@export var auto_render_in_runtime: bool = true

@export var enable_runtime_camera_culling: bool = true:
	set(value):
		enable_runtime_camera_culling = value
		_update_culling_process_mode()
		if not enable_runtime_camera_culling:
			_set_all_instances_visible(true)
		else:
			_update_runtime_culling()

@export_range(0.02, 1.0, 0.01) var culling_update_interval: float = 0.1:
	set(value):
		culling_update_interval = clampf(value, 0.02, 1.0)

@export_range(2.0, 512.0, 1.0) var culling_max_distance: float = 32.0:
	set(value):
		culling_max_distance = maxf(value, 2.0)
		if enable_runtime_camera_culling:
			_update_runtime_culling()

@export var enable_alternating_floor_darkening: bool = false:
	set(value):
		enable_alternating_floor_darkening = value
		if _should_auto_render():
			call_deferred("render_graph")

@export_range(0.0, 1.0, 0.01) var alternating_floor_darken: float = 0.9:
	set(value):
		alternating_floor_darken = clampf(value, 0.0, 1.0)
		if _should_auto_render():
			call_deferred("render_graph")

var _fallback_tileset: GraphTileset = preload("res://addons/dungeoncrafterrenderer/assets/default_tileset.tres")
var _fallback_door: Door = preload("res://addons/dungeoncrafterrenderer/assets/default_door.tres")
var _floor_darken_shader: Shader = preload("res://addons/dungeoncrafterrenderer/assets/shaders/alternating_floor_darken.gdshader")
var _door_slide_shader: Shader = preload("res://addons/dungeoncrafterrenderer/assets/shaders/door_slide_vertical.gdshader")
var _instance_rids: Array[RID] = []
var _instance_positions: Dictionary = {}
var _mesh_cache: Dictionary[int, RID] = {}
var _material_cache: Dictionary[String, Material] = {}
var _texture_alpha_cache: Dictionary[int, bool] = {}
var _door_animation_states: Dictionary = {}
var _animated_door_materials_by_edge: Dictionary = {}
var _culling_timer: float = 0.0
var _last_edge_visual_signature: int = -1
var _render_refresh_pending: bool = false


func _reload_graph_from_disk(value: Graph) -> Graph:
	if value == null: return null
	if value.resource_path.is_empty(): return value
	var reloaded := ResourceLoader.load(value.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if reloaded is Graph: return reloaded
	return value


func _ready() -> void:
	_update_culling_process_mode()
	if _should_auto_render():
		call_deferred("render_graph")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if auto_render_in_runtime and _has_edge_visual_state_changed():
		_queue_render_refresh()
	_update_door_animations()

	if not enable_runtime_camera_culling:
		return
	_culling_timer += delta
	if _culling_timer < culling_update_interval:
		return
	_culling_timer = 0.0
	_update_runtime_culling()


func _should_auto_render() -> bool:
	if Engine.is_editor_hint():
		return auto_render_in_editor
	return auto_render_in_runtime


func _exit_tree() -> void:
	_clear_render()


func render_graph() -> void:
	_render_refresh_pending = false
	_clear_render()

	if graph == null:
		_last_edge_visual_signature = 0
		_door_animation_states.clear()
		return

	var visual_signature := _compute_graph_visual_signature()
	var door_surface_data_by_vertex := _build_door_surface_data_map()

	var world := get_world_3d()
	if world == null: return
	_animated_door_materials_by_edge.clear()

	for vertex in graph.vertices.values():
		if vertex == null: continue
		var opening_mask := _opening_mask_for_vertex(vertex)
		var mesh_rid := _get_or_create_mesh(opening_mask)
		var surface_indices := _get_surface_indices_for_opening_mask(opening_mask)
		var door_surface_data: Dictionary = door_surface_data_by_vertex.get(vertex.id, {})

		var instance_rid := RenderingServer.instance_create()
		RenderingServer.instance_set_base(instance_rid, mesh_rid)
		RenderingServer.instance_set_scenario(instance_rid, world.scenario)
		_apply_surface_materials(instance_rid, vertex, surface_indices, door_surface_data)

		var world_pos := Vector3(vertex.position.x * cell_size, 0.0, vertex.position.y * cell_size)
		var xform := Transform3D(Basis.IDENTITY, world_pos)
		RenderingServer.instance_set_transform(instance_rid, xform)
		RenderingServer.instance_set_visible(instance_rid, true)

		_instance_rids.append(instance_rid)
		_instance_positions[instance_rid] = world_pos

	if enable_runtime_camera_culling:
		_update_runtime_culling()
	_update_door_animations()

	_last_edge_visual_signature = visual_signature


func _opening_mask_for_vertex(vertex: Vertex) -> int:
	var mask := 0
	if not vertex.surface_texture_overrides.has(Direction.Surface.NORTH) and _is_opening_edge(vertex.edges.get(Direction.Cardinal.NORTH, null)): mask |= OPEN_NORTH
	if not vertex.surface_texture_overrides.has(Direction.Surface.EAST) and _is_opening_edge(vertex.edges.get(Direction.Cardinal.EAST, null)): mask |= OPEN_EAST
	if not vertex.surface_texture_overrides.has(Direction.Surface.SOUTH) and _is_opening_edge(vertex.edges.get(Direction.Cardinal.SOUTH, null)): mask |= OPEN_SOUTH
	if not vertex.surface_texture_overrides.has(Direction.Surface.WEST) and _is_opening_edge(vertex.edges.get(Direction.Cardinal.WEST, null)): mask |= OPEN_WEST
	return mask


func _is_opening_edge(edge: Edge) -> bool:
	if edge == null:
		return false
	return edge.type != Edge.EdgeType.DOOR


func _get_or_create_mesh(opening_mask: int) -> RID:
	if _mesh_cache.has(opening_mask): return _mesh_cache[opening_mask]
	var mesh_rid := _create_cube_mesh(opening_mask)
	_mesh_cache[opening_mask] = mesh_rid
	return mesh_rid


func _create_cube_mesh(opening_mask: int) -> RID:
	var half := cell_size * 0.5
	var mesh_rid := RenderingServer.mesh_create()
	if (opening_mask & OPEN_NORTH) == 0:
		_add_quad_surface(mesh_rid, Direction.Surface.NORTH, Vector3(-half, -half, -half), Vector3(-half, half, -half), Vector3(half, half, -half), Vector3(half, -half, -half), Vector3.BACK)
	if (opening_mask & OPEN_EAST) == 0:
		_add_quad_surface(mesh_rid, Direction.Surface.EAST, Vector3(half, -half, -half), Vector3(half, half, -half), Vector3(half, half, half), Vector3(half, -half, half), Vector3.LEFT)
	if (opening_mask & OPEN_SOUTH) == 0:
		_add_quad_surface(mesh_rid, Direction.Surface.SOUTH, Vector3(-half, -half, half), Vector3(half, -half, half), Vector3(half, half, half), Vector3(-half, half, half), Vector3.FORWARD)
	if (opening_mask & OPEN_WEST) == 0:
		_add_quad_surface(mesh_rid, Direction.Surface.WEST, Vector3(-half, -half, -half), Vector3(-half, -half, half), Vector3(-half, half, half), Vector3(-half, half, -half), Vector3.RIGHT)
	_add_quad_surface(mesh_rid, Direction.Surface.CEILING, Vector3(-half, half, -half), Vector3(-half, half, half), Vector3(half, half, half), Vector3(half, half, -half), Vector3.DOWN)
	_add_quad_surface(mesh_rid, Direction.Surface.FLOOR, Vector3(-half, -half, -half), Vector3(half, -half, -half), Vector3(half, -half, half), Vector3(-half, -half, half), Vector3.UP)
	return mesh_rid


func _get_surface_indices_for_opening_mask(opening_mask: int) -> Dictionary[Direction.Surface, int]:
	var surface_indices: Dictionary[Direction.Surface, int] = {}
	var surface_index := 0

	if (opening_mask & OPEN_NORTH) == 0:
		surface_indices[Direction.Surface.NORTH] = surface_index
		surface_index += 1

	if (opening_mask & OPEN_EAST) == 0:
		surface_indices[Direction.Surface.EAST] = surface_index
		surface_index += 1

	if (opening_mask & OPEN_SOUTH) == 0:
		surface_indices[Direction.Surface.SOUTH] = surface_index
		surface_index += 1

	if (opening_mask & OPEN_WEST) == 0:
		surface_indices[Direction.Surface.WEST] = surface_index
		surface_index += 1

	surface_indices[Direction.Surface.CEILING] = surface_index
	surface_index += 1
	surface_indices[Direction.Surface.FLOOR] = surface_index

	return surface_indices


func _apply_surface_materials(instance_rid: RID, vertex: Vertex, surface_indices: Dictionary[Direction.Surface, int], door_surface_data: Dictionary) -> void:
	for surface in surface_indices:
		var texture := _resolve_surface_texture(vertex, surface, door_surface_data)
		var material: Material = _get_or_create_material(texture, surface)
		var door_entry: Dictionary = door_surface_data.get(surface, {})
		if not door_entry.is_empty() and _supports_door_slide_animation(door_entry):
			material = _create_door_slide_material(door_entry)
		RenderingServer.instance_set_surface_override_material(instance_rid, surface_indices[surface], material.get_rid())


func _resolve_surface_texture(vertex: Vertex, surface: Direction.Surface, door_surface_data: Dictionary) -> Texture2D:
	if graph != null and vertex.surface_texture_overrides.has(surface):
		var override_index := int(vertex.surface_texture_overrides[surface])
		if override_index >= 0 and override_index < graph.override_textures.size():
			var override_texture_ref := graph.override_textures[override_index]
			if override_texture_ref != null:
				return override_texture_ref.texture
	if door_surface_data.has(surface):
		var door_entry: Dictionary = door_surface_data[surface]
		return door_entry.get("texture", null)
	if graph == null: return null
	var tileset := _resolve_tileset_for_vertex(vertex)
	if tileset == null: return null
	return _resolve_stable_tileset_texture(vertex, surface, tileset)


func _resolve_stable_tileset_texture(vertex: Vertex, surface: Direction.Surface, tileset: GraphTileset) -> Texture2D:
	# Keep base tileset picks stable across re-renders so unrelated runtime updates do not reshuffle textures.
	var rng := RandomNumberGenerator.new()
	var seed_key := "%d:%d:%d" % [int(vertex.id), int(vertex.type_tileset_id), int(surface)]
	rng.seed = abs(seed_key.hash())
	return tileset.get_texture_for_surface(surface, rng)


func _resolve_tileset_for_vertex(vertex: Vertex) -> GraphTileset:
	if graph != null and vertex.type_tileset_id >= 0 and vertex.type_tileset_id < graph.tilesets.size():
		var vertex_tileset := graph.tilesets[vertex.type_tileset_id]
		if vertex_tileset != null: return vertex_tileset
	if graph != null and graph.tilesets.size() > 0:
		var first_tileset := graph.tilesets[0]
		if first_tileset != null: return first_tileset
	return _fallback_tileset


func _build_door_surface_data_map() -> Dictionary:
	var door_surface_data_by_vertex: Dictionary = {}
	if graph == null:
		return door_surface_data_by_vertex

	var active_edge_ids: Dictionary = {}

	for edge in graph.edges.values():
		if edge == null:
			continue
		if edge.type != Edge.EdgeType.DOOR:
			continue
		active_edge_ids[edge.id] = true

		var door_definition := _resolve_door_definition_for_edge(edge)
		if door_definition == null:
			continue

		var target_state := clampi(int(edge.door_state), 0, Door.DoorState.size() - 1)
		var animation_type := _resolve_door_animation_type(door_definition)
		var animation_duration := _resolve_door_animation_duration(door_definition)
		var animation_travel := _resolve_door_animation_travel(door_definition)
		_update_door_animation_state(edge.id, target_state, animation_type, animation_duration, animation_travel)

		var door_texture: Texture2D
		if animation_type == int(Door.OpenAnimation.SLIDE_VERTICAL):
			door_texture = _resolve_door_closed_texture(door_definition)
		else:
			door_texture = _resolve_door_texture_for_state(door_definition, target_state)

		if door_texture == null:
			continue

		var door_entry := {
			"texture": door_texture,
			"edge_id": int(edge.id),
			"animation_type": animation_type,
			"animation_travel": animation_travel,
		}

		_assign_door_surface_data(door_surface_data_by_vertex, edge.vertex_a_id, edge.direction_from_a, door_entry)
		_assign_door_surface_data(door_surface_data_by_vertex, edge.vertex_b_id, edge.direction_from_b, door_entry)

	_prune_stale_door_animation_states(active_edge_ids)

	return door_surface_data_by_vertex


func _assign_door_surface_data(door_surface_data_by_vertex: Dictionary, vertex_id: int, cardinal: Direction.Cardinal, door_entry: Dictionary) -> void:
	if not graph.vertices.has(vertex_id):
		return
	var surface := _surface_from_cardinal(cardinal)
	if surface < 0:
		return
	if not door_surface_data_by_vertex.has(vertex_id):
		door_surface_data_by_vertex[vertex_id] = {}
	var vertex_surface_data: Dictionary = door_surface_data_by_vertex[vertex_id]
	vertex_surface_data[surface] = door_entry


func _surface_from_cardinal(cardinal: Direction.Cardinal) -> int:
	match cardinal:
		Direction.Cardinal.NORTH:
			return Direction.Surface.NORTH
		Direction.Cardinal.EAST:
			return Direction.Surface.EAST
		Direction.Cardinal.SOUTH:
			return Direction.Surface.SOUTH
		Direction.Cardinal.WEST:
			return Direction.Surface.WEST
		_:
			return -1


func _resolve_door_texture_for_edge(edge: Edge) -> Texture2D:
	var door_definition := _resolve_door_definition_for_edge(edge)
	if door_definition == null:
		return null

	var target_state := clampi(int(edge.door_state), 0, Door.DoorState.size() - 1)
	var state_texture := _resolve_door_texture_for_state(door_definition, target_state)
	if state_texture != null:
		return state_texture
	if door_definition != _fallback_door and _fallback_door != null:
		return _resolve_door_texture_for_state(_fallback_door, target_state)
	return null


func _resolve_door_texture_for_state(door_resource: Resource, target_state: int) -> Texture2D:
	if door_resource == null:
		return null

	var base_texture_variant := door_resource.get("base_texture")
	var closed_texture_variant := door_resource.get("closed_texture")
	var base_texture := base_texture_variant as Texture2D
	var closed_texture := closed_texture_variant as Texture2D

	if target_state == int(Door.DoorState.OPEN):
		return base_texture
	if closed_texture != null:
		return closed_texture
	return base_texture


func _resolve_door_closed_texture(door_resource: Resource) -> Texture2D:
	if door_resource == null:
		return null
	var closed_texture_variant := door_resource.get("closed_texture")
	var base_texture_variant := door_resource.get("base_texture")
	var closed_texture := closed_texture_variant as Texture2D
	if closed_texture != null:
		return closed_texture
	return base_texture_variant as Texture2D


func _resolve_door_animation_type(door_resource: Resource) -> int:
	if door_resource == null:
		return int(Door.OpenAnimation.NONE)
	var animation_variant := door_resource.get("open_animation")
	if animation_variant == null:
		return int(Door.OpenAnimation.NONE)
	return int(animation_variant)


func _resolve_door_animation_duration(door_resource: Resource) -> float:
	if door_resource == null:
		return 0.35
	var duration_variant := door_resource.get("open_animation_duration")
	if duration_variant == null:
		return 0.35
	return maxf(float(duration_variant), 0.01)


func _resolve_door_animation_travel(door_resource: Resource) -> float:
	if door_resource == null:
		return 1.0
	var travel_variant := door_resource.get("open_animation_travel")
	if travel_variant == null:
		return 1.0
	return float(travel_variant)


func _update_door_animation_state(edge_id: int, target_state: int, animation_type: int, animation_duration: float, animation_travel: float) -> void:
	var now_seconds := Time.get_ticks_msec() / 1000.0
	if not _door_animation_states.has(edge_id):
		var initial_slide := animation_travel if target_state == int(Door.DoorState.OPEN) else 0.0
		_door_animation_states[edge_id] = {
			"from_slide": initial_slide,
			"to_slide": initial_slide,
			"started_at": now_seconds,
			"duration": animation_duration,
			"animation_type": animation_type,
			"travel": animation_travel,
		}
		return

	var state: Dictionary = _door_animation_states[edge_id]
	state["animation_type"] = animation_type
	state["duration"] = animation_duration
	state["travel"] = animation_travel

	var desired_slide := animation_travel if target_state == int(Door.DoorState.OPEN) else 0.0
	var current_slide := _sample_edge_slide(edge_id, now_seconds)
	if absf(desired_slide - float(state.get("to_slide", desired_slide))) > 0.0001:
		state["from_slide"] = current_slide
		state["to_slide"] = desired_slide
		state["started_at"] = now_seconds
		state["duration"] = animation_duration

	_door_animation_states[edge_id] = state


func _prune_stale_door_animation_states(active_edge_ids: Dictionary) -> void:
	var stale_edge_ids: Array = []
	for edge_id_variant in _door_animation_states.keys():
		if not active_edge_ids.has(edge_id_variant):
			stale_edge_ids.append(edge_id_variant)
	for edge_id_variant in stale_edge_ids:
		_door_animation_states.erase(edge_id_variant)


func _supports_door_slide_animation(door_entry: Dictionary) -> bool:
	if door_entry.is_empty():
		return false
	return int(door_entry.get("animation_type", int(Door.OpenAnimation.NONE))) == int(Door.OpenAnimation.SLIDE_VERTICAL)


func _create_door_slide_material(door_entry: Dictionary) -> Material:
	var edge_id := int(door_entry.get("edge_id", -1))
	var texture := door_entry.get("texture", null) as Texture2D
	var travel := float(door_entry.get("animation_travel", 1.0))
	var slide := _sample_edge_slide(edge_id, Time.get_ticks_msec() / 1000.0)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _door_slide_shader
	shader_material.set_shader_parameter("texture_albedo", texture)
	shader_material.set_shader_parameter("slide", slide)

	if not _animated_door_materials_by_edge.has(edge_id):
		_animated_door_materials_by_edge[edge_id] = []
	var material_list: Array = _animated_door_materials_by_edge[edge_id]
	material_list.append({"material": shader_material, "travel": travel})

	return shader_material


func _sample_edge_slide(edge_id: int, now_seconds: float) -> float:
	if not _door_animation_states.has(edge_id):
		return 0.0
	var state: Dictionary = _door_animation_states[edge_id]
	if int(state.get("animation_type", int(Door.OpenAnimation.NONE))) != int(Door.OpenAnimation.SLIDE_VERTICAL):
		return float(state.get("to_slide", 0.0))

	var from_slide := float(state.get("from_slide", 0.0))
	var to_slide := float(state.get("to_slide", 0.0))
	var duration := maxf(float(state.get("duration", 0.35)), 0.01)
	var started_at := float(state.get("started_at", now_seconds))
	var progress := clampf((now_seconds - started_at) / duration, 0.0, 1.0)
	var slide := lerpf(from_slide, to_slide, progress)
	if progress >= 1.0:
		state["from_slide"] = to_slide
		state["to_slide"] = to_slide
		state["started_at"] = now_seconds
		_door_animation_states[edge_id] = state
	return slide


func _update_door_animations() -> void:
	if _animated_door_materials_by_edge.is_empty():
		return
	var now_seconds := Time.get_ticks_msec() / 1000.0
	for edge_id_variant in _animated_door_materials_by_edge.keys():
		var edge_id := int(edge_id_variant)
		var slide := _sample_edge_slide(edge_id, now_seconds)
		var material_refs: Array = _animated_door_materials_by_edge[edge_id]
		for material_ref_variant in material_refs:
			var material_ref: Dictionary = material_ref_variant
			var shader_material := material_ref.get("material", null) as ShaderMaterial
			if shader_material == null:
				continue
			shader_material.set_shader_parameter("slide", slide)


func _resolve_door_definition_for_edge(edge: Edge) -> Door:
	if graph != null:
		var door_definition := graph.get_door_definition(edge.door_id)
		if door_definition != null:
			return door_definition
	return _fallback_door


func _get_or_create_material(texture: Texture2D, surface: Direction.Surface) -> Material:
	var texture_key := 0 if texture == null else int(texture.get_instance_id())
	var use_darkened_floor := enable_alternating_floor_darkening and surface == Direction.Surface.FLOOR
	var key := "%d:%d:%d" % [int(surface), texture_key, int(use_darkened_floor)]
	if _material_cache.has(key): return _material_cache[key]

	var material: Material
	if use_darkened_floor:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = _floor_darken_shader
		shader_material.set_shader_parameter("texture_albedo", texture)
		shader_material.set_shader_parameter("darken", alternating_floor_darken)
		shader_material.set_shader_parameter("cell_world_size", cell_size)
		material = shader_material
	else:
		var standard_material := StandardMaterial3D.new()
		standard_material.albedo_texture = texture
		standard_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if _texture_has_alpha(texture):
			standard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			standard_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material = standard_material

	_material_cache[key] = material
	return material


func _texture_has_alpha(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var texture_id := int(texture.get_instance_id())
	if _texture_alpha_cache.has(texture_id):
		return _texture_alpha_cache[texture_id]

	var image := texture.get_image()
	if image == null:
		_texture_alpha_cache[texture_id] = false
		return false

	var has_alpha := image.detect_alpha() != Image.ALPHA_NONE
	_texture_alpha_cache[texture_id] = has_alpha
	return has_alpha

func _add_quad_surface(mesh_rid: RID, surface: Direction.Surface, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	var positions := PackedVector3Array([p0, p1, p2, p3])
	var normals := PackedVector3Array([normal, normal, normal, normal])
	var uvs := _get_uvs_for_surface(surface)
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	RenderingServer.mesh_add_surface_from_arrays(mesh_rid, RenderingServer.PRIMITIVE_TRIANGLES, arrays)


func _get_uvs_for_surface(surface: Direction.Surface) -> PackedVector2Array:
	# Base mapping is the current floor orientation.
	match surface:
		Direction.Surface.NORTH, Direction.Surface.EAST:
			return PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)])
		Direction.Surface.CEILING:
			return PackedVector2Array([Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0)])
		Direction.Surface.SOUTH, Direction.Surface.WEST:
			return PackedVector2Array([Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0)])
		_:
			return PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])


func _clear_render() -> void:
	for instance_rid in _instance_rids:
		if instance_rid.is_valid(): RenderingServer.free_rid(instance_rid)
	_instance_rids.clear()
	_instance_positions.clear()
	_culling_timer = 0.0

	for mesh_rid in _mesh_cache.values():
		if mesh_rid.is_valid(): RenderingServer.free_rid(mesh_rid)
	_mesh_cache.clear()

	_material_cache.clear()
	_texture_alpha_cache.clear()


func _update_culling_process_mode() -> void:
	set_process(not Engine.is_editor_hint() and (enable_runtime_camera_culling or auto_render_in_runtime))


func _set_all_instances_visible(visible: bool) -> void:
	for instance_rid in _instance_rids:
		if instance_rid.is_valid(): RenderingServer.instance_set_visible(instance_rid, visible)


func _update_runtime_culling() -> void:
	if Engine.is_editor_hint():
		_set_all_instances_visible(true)
		return
	if not enable_runtime_camera_culling:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		_set_all_instances_visible(true)
		return

	var camera_pos := camera.global_position
	var max_distance_sq := culling_max_distance * culling_max_distance

	for instance_rid in _instance_rids:
		if not instance_rid.is_valid():
			continue
		var instance_pos: Vector3 = _instance_positions.get(instance_rid, Vector3.ZERO)
		var to_instance := instance_pos - camera_pos
		var within_range := to_instance.length_squared() <= max_distance_sq
		RenderingServer.instance_set_visible(instance_rid, within_range)


func _compute_graph_visual_signature() -> int:
	if graph == null:
		return 0
	var signature := 17

	var vertex_ids: Array = graph.vertices.keys()
	vertex_ids.sort()
	for vertex_id_variant in vertex_ids:
		var vertex_id := int(vertex_id_variant)
		var vertex: Vertex = graph.vertices.get(vertex_id)
		if vertex == null:
			continue
		signature = signature * 31 + vertex_id
		signature = signature * 31 + int(vertex.type_tileset_id)
		var override_surfaces: Array = vertex.surface_texture_overrides.keys()
		override_surfaces.sort()
		for surface_variant in override_surfaces:
			var surface := int(surface_variant)
			signature = signature * 31 + surface
			signature = signature * 31 + int(vertex.surface_texture_overrides.get(surface, 0))

	var edge_ids: Array = graph.edges.keys()
	edge_ids.sort()
	for edge_id_variant in edge_ids:
		var edge_id := int(edge_id_variant)
		var edge: Edge = graph.edges.get(edge_id)
		if edge == null:
			continue
		signature = signature * 31 + edge_id
		signature = signature * 31 + int(edge.type)
		signature = signature * 31 + int(edge.door_id)
		signature = signature * 31 + int(edge.door_state)
	return signature


func _has_edge_visual_state_changed() -> bool:
	return _compute_graph_visual_signature() != _last_edge_visual_signature


func _queue_render_refresh() -> void:
	if _render_refresh_pending:
		return
	_render_refresh_pending = true
	call_deferred("render_graph")
