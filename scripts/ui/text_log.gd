extends Control
class_name TextLog

const GROUP_NAME := "text_log"

@export_range(10, 5000, 1) var max_lines: int = 300
@export var show_timestamps: bool = false
@export var text_color: Color = Color(0.32549, 1.0, 0.415686, 1.0)
@export_range(8, 40, 1) var scrollbar_width: int = 16

var _lines: PackedStringArray = []
@onready var _scroll: ScrollContainer = %Scroll
@onready var _label: RichTextLabel = %MessageLabel


func _ready() -> void:
	add_to_group(GROUP_NAME)
	if _label != null:
		_label.add_theme_color_override("default_color", text_color)
	_apply_scrollbar_theme()


func add_message(message: String) -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty():
		return

	var line := clean_message
	if show_timestamps:
		line = "%s %s" % [_timestamp(), line]

	_lines.append(line)
	_trim_lines()
	_refresh_text()


func clear_log() -> void:
	_lines.clear()
	_refresh_text()


func get_lines() -> PackedStringArray:
	return _lines.duplicate()


func _trim_lines() -> void:
	while _lines.size() > max_lines:
		_lines.remove_at(0)


func _refresh_text() -> void:
	if _label == null:
		return
	_label.text = "\n".join(_lines)
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	if get_tree() != null:
		await get_tree().process_frame
	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll == null:
		return
	_scroll.scroll_vertical = int(v_scroll.max_value)
	v_scroll.value = v_scroll.max_value


func _apply_scrollbar_theme() -> void:
	if _scroll == null:
		return
	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll == null:
		return
	v_scroll.custom_minimum_size.x = scrollbar_width

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.02, 0.08, 0.02, 1.0)
	track_style.border_width_left = 1
	track_style.border_width_top = 1
	track_style.border_width_right = 1
	track_style.border_width_bottom = 1
	track_style.border_color = Color(0.18, 0.65, 0.18, 1.0)

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.2, 0.95, 0.2, 1.0)
	grabber_style.corner_radius_top_left = 2
	grabber_style.corner_radius_top_right = 2
	grabber_style.corner_radius_bottom_right = 2
	grabber_style.corner_radius_bottom_left = 2

	v_scroll.add_theme_stylebox_override("scroll", track_style)
	v_scroll.add_theme_stylebox_override("scroll_focus", track_style)
	v_scroll.add_theme_stylebox_override("grabber", grabber_style)
	v_scroll.add_theme_stylebox_override("grabber_highlight", grabber_style)
	v_scroll.add_theme_stylebox_override("grabber_pressed", grabber_style)


func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [now.hour, now.minute, now.second]
