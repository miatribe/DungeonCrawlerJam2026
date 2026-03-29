extends Control
class_name TextLog

const GROUP_NAME := "text_log"

@export_range(10, 5000, 1) var max_lines: int = 300
@export var show_timestamps: bool = false

var _lines: PackedStringArray = []
@onready var _scroll: ScrollContainer = %Scroll
@onready var _label: RichTextLabel = %MessageLabel


func _ready() -> void:
	add_to_group(GROUP_NAME)


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
	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll == null:
		return
	v_scroll.value = v_scroll.max_value


func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [now.hour, now.minute, now.second]
