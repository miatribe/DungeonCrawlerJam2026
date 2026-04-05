extends Node
#class_name AudioManager
## Central audio manager — register as autoload "AudioManager" in Project > Globals.
##
## Volume is controlled via volume_db on the AudioStreamPlayer nodes directly,
## so there is no dependency on AudioServer bus index lookups.

const _MUSIC_BUS: StringName = &"Music"
const _SFX_BUS: StringName = &"SFX"
const _MASTER_BUS: StringName = &"Master"
const _SFX_POOL_SIZE: int = 16

var _music_player: AudioStreamPlayer
var _current_track: AudioStream = null

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_available: Array[AudioStreamPlayer] = []
var _sfx_queue: Array[AudioStream] = []

var _music_volume: float = 0.2
var _sfx_volume: float = 0.2
var _music_volume_dirty: bool = false

var _gameplay_track: AudioStream = null
var _boss_track: AudioStream = null
var _victory_track: AudioStream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_initialized()


func _process(_delta: float) -> void:
	_apply_music_volume_if_needed()
	if not _sfx_queue.is_empty() and not _sfx_available.is_empty():
		var p: AudioStreamPlayer = _sfx_available.pop_front()
		p.stream = _sfx_queue.pop_front()
		p.play()


# ── Setup ──────────────────────────────────────────────────────────────────

func setup_music_tracks(gameplay: AudioStream, boss: AudioStream, victory: AudioStream) -> void:
	_ensure_audio_initialized()
	_gameplay_track = gameplay
	_boss_track = boss
	_victory_track = victory


# ── Music ──────────────────────────────────────────────────────────────────

func play_gameplay_track(restart_if_same: bool = false) -> void:
	_play_track(_gameplay_track, restart_if_same)


func play_boss_track(restart_if_same: bool = false) -> void:
	_play_track(_boss_track, restart_if_same)


func play_victory_track(restart_if_same: bool = false) -> void:
	_play_track(_victory_track, restart_if_same)


func stop_music() -> void:
	_ensure_audio_initialized()
	_current_track = null
	if _music_player != null:
		_music_player.stop()


# ── SFX ────────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream) -> void:
	_ensure_audio_initialized()
	if stream == null:
		return
	_sfx_queue.append(stream)


func play_sfx_random(streams: Array[AudioStream]) -> void:
	var valid: Array[AudioStream] = []
	for s in streams:
		if s != null:
			valid.append(s)
	if valid.is_empty():
		return
	play_sfx(valid.pick_random())


# ── Volume ─────────────────────────────────────────────────────────────────

func set_music_volume(linear: float) -> void:
	_ensure_audio_initialized()
	_music_volume = clampf(linear, 0.0, 1.0)
	_music_volume_dirty = true


func set_sfx_volume(linear: float) -> void:
	_ensure_audio_initialized()
	_sfx_volume = clampf(linear, 0.0, 1.0)
	var db := _to_db(_sfx_volume)
	for p in _sfx_pool:
		p.volume_db = db


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


# ── Internal ───────────────────────────────────────────────────────────────

func _play_track(track: AudioStream, restart_if_same: bool) -> void:
	_ensure_audio_initialized()
	if track == null:
		return
	if _music_player == null:
		return
	if _current_track == track and _music_player.playing and not restart_if_same:
		return
	_current_track = track
	_music_player.stream = track
	_apply_music_volume_if_needed()
	_music_player.play()


func _on_music_finished() -> void:
	if _current_track != null:
		_music_player.stream = _current_track
		_music_player.play()


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	_sfx_available.append(player)


func _to_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)


func _apply_music_volume_if_needed() -> void:
	if not _music_volume_dirty:
		return
	if _music_player == null or not is_instance_valid(_music_player):
		return
	_music_player.volume_db = _to_db(_music_volume)
	_music_volume_dirty = false


func _resolve_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name
	push_warning("Audio bus '%s' not found; falling back to Master." % String(bus_name))
	return _MASTER_BUS


func _ensure_bus_exists(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var new_bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(new_bus_index, bus_name)
	AudioServer.set_bus_send(new_bus_index, _MASTER_BUS)


func _ensure_expected_bus_layout() -> void:
	if AudioServer.get_bus_index(_MUSIC_BUS) != -1 and AudioServer.get_bus_index(_SFX_BUS) != -1:
		return
	var layout_path_variant: Variant = ProjectSettings.get_setting("audio/default_bus_layout", "")
	if typeof(layout_path_variant) != TYPE_STRING:
		return
	var layout_path := String(layout_path_variant)
	if layout_path.is_empty():
		return
	var layout := load(layout_path)
	if layout is AudioBusLayout:
		AudioServer.set_bus_layout(layout as AudioBusLayout)


func _ensure_audio_initialized() -> void:
	if _music_player != null and is_instance_valid(_music_player) and _sfx_pool.size() == _SFX_POOL_SIZE:
		return

	_ensure_expected_bus_layout()
	_ensure_bus_exists(_MUSIC_BUS)
	_ensure_bus_exists(_SFX_BUS)
	var music_bus := _resolve_bus(_MUSIC_BUS)
	var sfx_bus := _resolve_bus(_SFX_BUS)

	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		_music_player.bus = music_bus
		_music_player.volume_db = _to_db(_music_volume)
		add_child(_music_player)
		if not _music_player.finished.is_connected(_on_music_finished):
			_music_player.finished.connect(_on_music_finished)
	else:
		_music_player.bus = music_bus

	if _sfx_pool.is_empty():
		for i in _SFX_POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.name = "SfxPlayer%d" % i
			p.bus = sfx_bus
			p.volume_db = _to_db(_sfx_volume)
			add_child(p)
			_sfx_pool.append(p)
			_sfx_available.append(p)
			p.finished.connect(_on_sfx_finished.bind(p))
	else:
		for p in _sfx_pool:
			if p != null and is_instance_valid(p):
				p.bus = sfx_bus
