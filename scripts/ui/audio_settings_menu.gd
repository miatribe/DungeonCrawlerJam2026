extends PanelContainer
class_name AudioSettingsMenu

@onready var _music_slider: HSlider = $Margin/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Margin/VBox/SfxRow/SfxSlider
@onready var _music_value_label: Label = $Margin/VBox/MusicRow/MusicValue
@onready var _sfx_value_label: Label = $Margin/VBox/SfxRow/SfxValue


func _ready() -> void:
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_slider_value_changed)
	if _sfx_slider != null:
		_sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	_sync_from_audio_manager()


func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	_update_label(_music_value_label, value)


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_update_label(_sfx_value_label, value)


func _sync_from_audio_manager() -> void:
	var mv: float = AudioManager.get_music_volume()
	var sv: float = AudioManager.get_sfx_volume()
	if _music_slider != null:
		_music_slider.set_value_no_signal(mv)
	_update_label(_music_value_label, mv)
	if _sfx_slider != null:
		_sfx_slider.set_value_no_signal(sv)
	_update_label(_sfx_value_label, sv)


func _update_label(label: Label, linear: float) -> void:
	if label == null:
		return
	label.text = "%d%%" % int(round(linear * 100.0))

