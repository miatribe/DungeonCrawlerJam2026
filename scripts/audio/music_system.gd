extends Node
class_name MusicSystem

@export var gameplay_track: AudioStream
@export var boss_track: AudioStream
@export var victory_track: AudioStream
@export var autoplay_gameplay_track: bool = true
@export var player_path: NodePath
@export var music_bus: StringName = &"Music"
@export var volume_db: float = 0.0

var _player: AudioStreamPlayer
var _current_track: AudioStream


func _ready() -> void:
	_player = _resolve_player()
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "AudioStreamPlayer"
		add_child(_player)
	_apply_player_settings()
	if not _player.finished.is_connected(_on_player_finished):
		_player.finished.connect(_on_player_finished)
	if autoplay_gameplay_track and gameplay_track != null:
		play_gameplay_track()


func play_gameplay_track(restart_if_same: bool = false) -> bool:
	return _play_track(gameplay_track, restart_if_same)


func play_boss_track(restart_if_same: bool = true) -> bool:
	return _play_track(boss_track, restart_if_same)


func play_victory_track(restart_if_same: bool = false) -> bool:
	return _play_track(victory_track, restart_if_same)


func stop_music() -> void:
	_current_track = null
	if _player != null:
		_player.stop()


func _play_track(track: AudioStream, restart_if_same: bool) -> bool:
	if track == null:
		return false
	if _player == null:
		_player = _resolve_player()
		if _player == null:
			return false
	_apply_player_settings()
	if _current_track == track and _player.playing and not restart_if_same:
		return true
	_current_track = track
	_player.stream = track
	_player.play()
	return true


func _on_player_finished() -> void:
	if _player == null:
		return
	if _current_track == null:
		return
	_player.stream = _current_track
	_player.play()


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
	_player.bus = music_bus
	_player.volume_db = volume_db
