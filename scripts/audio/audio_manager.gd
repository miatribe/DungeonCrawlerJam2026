extends Node
#class_name AudioManager
## Central audio manager — register as autoload "AudioManager" in Project > Globals.
##
## Volume is controlled via volume_db on the AudioStreamPlayer nodes directly,
## so there is no dependency on AudioServer bus index lookups.

const _MUSIC_BUS: StringName = &"Music"
const _SFX_BUS: StringName = &"SFX"
const _SFX_POOL_SIZE: int = 16

var _music_player: AudioStreamPlayer
var _current_track: AudioStream = null

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_available: Array[AudioStreamPlayer] = []
var _sfx_queue: Array[AudioStream] = []

var _music_volume: float = 1.0
var _sfx_volume: float = 1.0

var _gameplay_track: AudioStream = null
var _boss_track: AudioStream = null
var _victory_track: AudioStream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = _MUSIC_BUS
	_music_player.volume_db = 0.0
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = _SFX_BUS
		p.volume_db = 0.0
		add_child(p)
		_sfx_pool.append(p)
		_sfx_available.append(p)
		p.finished.connect(_on_sfx_finished.bind(p))


func _process(_delta: float) -> void:
	if not _sfx_queue.is_empty() and not _sfx_available.is_empty():
		var p: AudioStreamPlayer = _sfx_available.pop_front()
		p.stream = _sfx_queue.pop_front()
		p.play()


# ── Setup ──────────────────────────────────────────────────────────────────

func setup_music_tracks(gameplay: AudioStream, boss: AudioStream, victory: AudioStream) -> void:
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
	_current_track = null
	_music_player.stop()


# ── SFX ────────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream) -> void:
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
	_music_volume = clampf(linear, 0.0, 1.0)
	_music_player.volume_db = _to_db(_music_volume)


func set_sfx_volume(linear: float) -> void:
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
	if track == null:
		return
	if _current_track == track and _music_player.playing and not restart_if_same:
		return
	_current_track = track
	_music_player.stream = track
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
