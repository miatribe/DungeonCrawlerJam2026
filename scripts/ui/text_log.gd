extends Control
class_name TextLog

@export_range(10, 5000, 1) var max_lines: int = 300
@export var show_timestamps: bool = false

var _lines: PackedStringArray = []
var _panel: PanelContainer
var _scroll: ScrollContainer
var _label: RichTextLabel


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.scroll_active = false
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_label)


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
