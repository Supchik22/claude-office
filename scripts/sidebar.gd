class_name Sidebar
extends CanvasLayer
## Right panel: totals, the roster and details of the selected agent.

signal picked(id: String)

const STATUS_TEXT := {"busy": "працює", "shell": "виконує команду",
		"blocked": "чекає дозволу", "idle": "простоює"}
const X := 1260.0
const W := 340.0

var _stats := Label.new()
var _alert := Label.new()
var _rows := VBoxContainer.new()
var _details := RichTextLabel.new()
var _row_of := {}


func _ready() -> void:
	layer = 2
	var panel := Panel.new()
	panel.position = Vector2(X, 0)
	panel.size = Vector2(W, 900)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b1c20")
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.position = Vector2(14, 12)
	margin.size = Vector2(W - 28, 876)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Офіс жуків"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	_stats.add_theme_color_override("font_color", Color("c3c2b7"))
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_stats)
	_alert.add_theme_color_override("font_color", Color("ff8f7a"))
	_alert.autowrap_mode = TextServer.AUTOWRAP_WORD
	_alert.visible = false
	column.add_child(_alert)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.1
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_rows)

	column.add_child(HSeparator.new())
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("default_color", Color("dedcd2"))
	_details.selection_enabled = true
	column.add_child(_details)


func set_alert(text: String) -> void:
	_alert.text = text
	_alert.visible = text != ""


func set_stats(working: int, resting: int, team: int, taken: int, pets: int) -> void:
	_stats.text = "Працюють: %d  Відпочивають: %d\nСубагентів: %d  Вивезено: %d\nПогладжено: %d" % [
			working, resting, team, taken, pets]


func update_roster(agents: Array) -> void:
	var alive := {}
	for agent: Agent in agents:
		alive[agent.id] = true
		if not _row_of.has(agent.id):
			_row_of[agent.id] = _make_row(agent)
		_fill_row(_row_of[agent.id], agent)
	for id: String in _row_of.keys():
		if not alive.has(id):
			_row_of[id].queue_free()
			_row_of.erase(id)


func show_details(agent: Agent) -> void:
	if agent == null:
		_details.text = "Клацніть на жука, щоб побачити деталі. Затисніть кнопку й проведіть по ньому, щоб погладити."
		return
	var d := agent.data
	var lines := PackedStringArray([
		Agent.text_of(d, "title", "Без назви"),
		"",
		"Сесія: " + Agent.text_of(d, "name", "?"),
		"Стан: " + place_text(agent),
		"Папка: " + Agent.text_of(d, "cwd", "?"),
		"Модель: %s (%s)" % [Agent.text_of(d, "model", "?"), BugBody.kind_name(agent.kind)],
		"Контекст: %s токенів" % _count(d, "context"),
		"Запитів: %s, викликів: %s" % [_count(d, "turns"), _count(d, "toolCalls")],
		"Погладжено: %d" % agent.pets,
	])
	if not agent.team_lines.is_empty():
		lines.append("")
		lines.append("Команда (%d):" % agent.team_lines.size())
		for line in agent.team_lines:
			lines.append("  " + line)
	lines.append("")
	lines.append("Зараз: " + agent.current_action())
	lines.append("")
	lines.append("Останній запит: " + Agent.text_of(d, "lastPrompt", "—"))
	_details.text = "\n".join(lines)


## JSON numbers arrive as floats.
static func _count(d: Dictionary, key: String) -> String:
	var value = d.get(key)
	return "?" if value == null else str(int(value))


static func place_text(agent: Agent) -> String:
	var status: String = STATUS_TEXT.get(agent.status(), agent.status())
	match agent.state:
		Agent.State.WALKING:
			if agent.goal == Agent.Goal.STREET:
				return "іде з офісу"
			return "іде відпочивати" if Layout.is_lounge(agent.slot) else "іде до столу"
		Agent.State.RESTING:
			return agent.act_text()
		Agent.State.FLEEING:
			return "тікає від ТЦК"
		Agent.State.ESCORTED:
			return "ведуть до буса"
		Agent.State.OUTSIDE:
			return "чекає вільного місця"
	return status


func _make_row(agent: Agent) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26272d")
	style.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(agent.id))
	var label := Label.new()
	label.name = "Text"
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	_rows.add_child(row)
	return row


func _fill_row(row: Control, agent: Agent) -> void:
	var label: Label = row.find_child("Text", true, false)
	var team := " +%d" % (agent.team + agent.team_extra) if agent.team > 0 else ""
	label.text = "%s [%s]%s · %s\n%s" % [Agent.text_of(agent.data, "name", "?"), BugBody.kind_name(agent.kind),
			team, place_text(agent), Agent.text_of(agent.data, "title", "")]
