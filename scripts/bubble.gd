class_name Bubble
extends PanelContainer
## Speech bubble above a bug. Stays inside the street and office area.

const MAX_CHARS := 36

## Distance above the bug; seated bugs raise it to clear their monitor.
var lift := 72.0
var _label := Label.new()
var _left := 0.0


func _init() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.99, 0.98, 0.94)
	box.set_border_width_all(2)
	box.border_color = Color(0.1, 0.1, 0.12)
	box.set_content_margin_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	add_theme_stylebox_override("panel", box)
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	add_child(_label)
	z_index = 40
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func say(text: String, seconds := 4.0, ink := Color(0.1, 0.1, 0.12)) -> void:
	if text.length() > MAX_CHARS:
		text = text.substr(0, MAX_CHARS - 1) + "…"
	_label.text = text
	_label.add_theme_color_override("font_color", ink)
	_left = seconds
	visible = true
	reset_size()


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		return
	var anchor: Vector2 = get_parent().position
	var x := clampf(anchor.x - size.x / 2.0, 6.0, Layout.OFFICE_W - size.x - 6.0)
	var y := maxf(anchor.y - lift, 4.0)
	position = Vector2(x, y) - anchor
