extends Node
class_name RandomSfxPlayer

@export var sounds: Array[AudioStream] = []
@export var player_path: NodePath
@export var audio_bus: StringName = &"SFX"
@export var volume_db: float = 0.0
@export_range(0.1, 3.0, 0.01) var min_pitch_scale: float = 1.0
@export_range(0.1, 3.0, 0.01) var max_pitch_scale: float = 1.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = _resolve_player()
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "AudioStreamPlayer"
		add_child(_player)
	_apply_player_settings()


func play_random() -> bool:
	if _player == null:
		_player = _resolve_player()
		if _player == null:
			return false
	var stream := _pick_random_sound()
	if stream == null:
		return false
	_apply_player_settings()
	if max_pitch_scale >= min_pitch_scale:
		_player.pitch_scale = randf_range(min_pitch_scale, max_pitch_scale)
	else:
		_player.pitch_scale = min_pitch_scale
	_player.stream = stream
	_player.play()
	return true


func add_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	sounds.append(stream)


func clear_sounds() -> void:
	sounds.clear()


func _pick_random_sound() -> AudioStream:
	var valid_streams: Array[AudioStream] = []
	for stream in sounds:
		if stream != null:
			valid_streams.append(stream)
	if valid_streams.is_empty():
		return null
	return valid_streams.pick_random()


func _resolve_player() -> AudioStreamPlayer:
	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		if node is AudioStreamPlayer:
			return node as AudioStreamPlayer
	for child in get_children():
		if child is AudioStreamPlayer:
			return child as AudioStreamPlayer
	return null


func _apply_player_settings() -> void:
	if _player == null:
		return
	_player.bus = audio_bus
	_player.volume_db = volume_db