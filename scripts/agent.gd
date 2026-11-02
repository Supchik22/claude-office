class_name Agent
extends Node2D
## One Claude Code session, as a pixel bug. Works at a desk, rests in the lounge when idle,
## and is walked out, caught by the TCK and driven off when the session is closed.

enum State { WALKING, WORKING, RESTING, FLEEING, ESCORTED, OUTSIDE }
enum Goal { SEAT, STREET }
## What a bug does while resting in the lounge.
enum Act { SLEEP, SIP, WANDER, LOOK, DANCE, RETURN }

const WALK_SPEED := 140.0
const FLEE_SPEED := 175.0
const CAUGHT_LINES: Array[String] = ["Я ж тільки PR закрив!", "У мене бронь!", "Дайте закомітити!",
		"Я агент, а не солдат!", "Тести ще не пройшли!", "Це не я, це сабагент!"]
const CLOSED_LINES: Array[String] = ["Мене закрили...", "Кінець контексту", "Сесію завершено"]
const STROLL_SPEED := 95.0
## Places to visit in the lounge, all on its lane: where to stand, what to do, how to face, what to say.
const POIS := [
	{"at": Vector2(548, 528), "act": Act.LOOK, "face": Vector2i(0, -1), "line": "Ціни кусаються...", "what": "дивиться на автомат"},
	{"at": Vector2(720, 528), "act": Act.LOOK, "face": Vector2i(0, -1), "line": "Дивись, рибка!", "what": "дивиться на рибок"},
	{"at": Vector2(192, 528), "act": Act.DANCE, "face": Vector2i(0, 1), "line": "Ла-ла-ла", "what": "танцює"},
	{"at": Vector2(1056, 528), "act": Act.DANCE, "face": Vector2i(0, 1), "line": "Ла-ла-ла", "what": "танцює"},
]
const PET_LINES: Array[String] = ["Мур!", "Ще!", "Приємно~", "Дякую!", "Хі-хі", "Не зупиняйся"]

var world: Node
var id := ""
var data := {}
var state := State.WORKING
var goal := Goal.SEAT
var slot := -1
var home_desk := -1
var home_lounge := -1
var wants_rest := false
var ended := false
var kind := BugBody.Kind.OTHER
var team := 0  # live subagents shown
var team_extra := 0
var team_lines := PackedStringArray()
var pets := 0
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var body := BugBody.new()
var bubble := Bubble.new()
var _tag := Node2D.new()  # text lives on the overlay, above the low-resolution world
var _name_label := Label.new()
var _task_label := Label.new()
var _path := PackedVector2Array()
var _path_i := 0
var _flee_to := Vector2.ZERO
var _last_action := ""
var _act: int = Act.SLEEP
var _act_left := 0.0
var _poi := {}
var _order_left := 0.0
var _heart_cd := 0.0
var _line_cd := 0.0
var _t := randf() * 20.0


func _init(owner_world: Node, session_id: String) -> void:
	world = owner_world
	id = session_id
	z_index = 5
	add_child(body)
	for label in [_name_label, _task_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(176, 0)
		label.position = Vector2(-88, 0)
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag.add_child(label)
	_name_label.position.y = 22
	_task_label.position.y = 38
	_task_label.add_theme_color_override("font_color", Color("e8e4d4"))
	_tag.add_child(bubble)
	world.overlay.add_child(_tag)


func apply(session: Dictionary) -> void:
	data = session
	kind = BugBody.kind_of(Agent.text_of(session, "model", ""))
	_task_label.text = Agent.text_of(session, "title", "")
	_refresh_name()
	var action := current_action()
	if action != _last_action:
		_last_action = action
		if action != "" and state == State.WORKING:
			bubble.say(action, 4.5)


func set_team(count: int, extra: int, lines: PackedStringArray) -> void:
	team = count
	team_extra = extra
	team_lines = lines
	_refresh_name()


func order(info: Dictionary) -> void:
	_order_left = 1.4
	bubble.say("Вперед, %s!" % Agent.text_of(info, "type", "команда"), 2.5, Color("7a5200"))


func _refresh_name() -> void:
	var text := Agent.text_of(data, "name", "сесія")
	if team > 0:
		text += " x%d" % (team + team_extra)
	_name_label.text = text


func status() -> String:
	return Agent.text_of(data, "status", "")


## What the session is doing right now, in one line.
func current_action() -> String:
	if status() == "blocked":
		return "Чекаю дозволу"
	var commands: Array = data.get("commands", [])
	if status() == "shell" and not commands.is_empty():
		return "$ " + str(commands[0])
	var feed: Array = data.get("feed", [])
	if feed.is_empty():
		return ""
	var item: Dictionary = feed[0]
	if item.get("kind") == "tool":
		return "%s: %s" % [Agent.text_of(item, "tool", ""), Agent.text_of(item, "text", "")]
	return Agent.text_of(item, "text", "")


static func text_of(d: Dictionary, key: String, fallback: String) -> String:
	var value = d.get(key)
	return fallback if value == null or str(value) == "" else str(value)


func place_at(i: int) -> void:
	slot = i
	position = Layout.seat(i)
	_sit()


func walk_in(i: int, from: Vector2) -> void:
	slot = i
	position = from
	visible = true
	_begin(Layout.route_from_street(i, from), Goal.SEAT)


func wait_outside() -> void:
	state = State.OUTSIDE
	visible = false


func caught() -> void:
	state = State.ESCORTED
	body.pose = BugBody.Pose.PANIC
	bubble.say(CAUGHT_LINES.pick_random(), 2.6)


func drag_to(target: Vector2, speed: float, delta: float) -> void:
	_step_to(target, speed, delta)


## Strokes the bug: it purrs, shakes with pleasure and sends up hearts.
func pet() -> void:
	body.happy = 1.2
	if _heart_cd <= 0.0:
		_heart_cd = 0.2
		pets += 1
		world.spawn_heart(position + Vector2(randf_range(-18.0, 18.0), -34.0))
	if _line_cd <= 0.0 and state != State.FLEEING and state != State.ESCORTED:
		_line_cd = 3.0
		bubble.say(PET_LINES.pick_random(), 2.0, Color("b02a48"))


func _begin(points: PackedVector2Array, destination: Goal) -> void:
	goal = destination
	state = State.WALKING
	_path = points
	_path_i = 0
	body.pose = BugBody.Pose.WALK
	bubble.lift = 72.0


func _sit() -> void:
	state = State.RESTING if Layout.is_lounge(slot) else State.WORKING
	bubble.lift = 80.0 if state == State.RESTING else 122.0
	body.look = Vector2i(0, -1)
	if state == State.RESTING:
		_start_act(Act.SLEEP if randf() < 0.5 else Act.SIP)
	_update_pose()


func act_text() -> String:
	match _act:
		Act.SLEEP:
			return "спить на дивані"
		Act.SIP:
			return "п'є каву"
		Act.WANDER:
			return "гуляє лаунджем"
		Act.RETURN:
			return "вертається на місце"
		_:
			return str(_poi.get("what", "відпочиває"))


func _start_act(act: int) -> void:
	_act = act
	match act:
		Act.SLEEP:
			_act_left = randf_range(5.0, 9.0)
		Act.SIP:
			_act_left = randf_range(4.0, 6.0)
		Act.LOOK, Act.DANCE:
			_act_left = randf_range(3.5, 6.0)
			body.look = _poi.face
			bubble.say(_poi.line, 3.0)


func _next_act() -> void:
	if _act == Act.LOOK or _act == Act.DANCE:
		_walk_lounge([Vector2(Layout.seat(slot).x, Layout.lane_y(slot)), Layout.seat(slot)], Act.RETURN)
	elif randf() < 0.65:
		_poi = POIS.pick_random()
		_walk_lounge([Vector2(Layout.seat(slot).x, Layout.lane_y(slot)), _poi.at], Act.WANDER)
	else:
		_start_act(Act.SIP if _act == Act.SLEEP else Act.SLEEP)


func _walk_lounge(points: Array, act: int) -> void:
	_act = act
	_path = PackedVector2Array(points)
	_path_i = 0
	bubble.lift = 72.0


## Resting is not only sleeping: strolls to the vending machine and the aquarium, dancing on the rug.
func _rest_life(delta: float) -> void:
	match _act:
		Act.WANDER:
			if _follow(STROLL_SPEED, delta):
				_start_act(_poi.act)
		Act.RETURN:
			if _follow(STROLL_SPEED, delta):
				body.look = Vector2i(0, -1)
				bubble.lift = 80.0
				_start_act(Act.SIP if randf() < 0.5 else Act.SLEEP)
		_:
			_act_left -= delta
			if _act_left <= 0.0:
				_next_act()


## A route that starts where the bug is now, not at its seat, when it has wandered off.
func _from_here(points: PackedVector2Array, away: bool) -> PackedVector2Array:
	if not away:
		return points
	var out := PackedVector2Array([position])
	out.append_array(points.slice(2))
	return out


func _update_pose() -> void:
	if _order_left > 0.0:
		body.pose = BugBody.Pose.RAISE
	elif state == State.RESTING:
		match _act:
			Act.SLEEP:
				body.pose = BugBody.Pose.SLEEP
			Act.SIP:
				body.pose = BugBody.Pose.SIP
			Act.DANCE:
				body.pose = BugBody.Pose.DANCE
			Act.LOOK:
				body.pose = BugBody.Pose.WAIT
			_:
				body.pose = BugBody.Pose.WALK
	else:
		match status():
			"busy":
				body.pose = BugBody.Pose.TYPE
			"blocked":
				body.pose = BugBody.Pose.RAISE
			_:
				body.pose = BugBody.Pose.WAIT


func _process(delta: float) -> void:
	_t += delta
	_order_left = maxf(0.0, _order_left - delta)
	_heart_cd -= delta
	_line_cd -= delta
	match state:
		State.WALKING:
			if _follow(WALK_SPEED, delta):
				_arrive()
		State.WORKING, State.RESTING:
			_settled(delta)
		State.FLEEING:
			if _step_to(_flee_to, FLEE_SPEED, delta):
				_flee_to = _random_street_point()
	body.kind = kind
	body.crowned = team > 0
	body.alert = status() == "blocked" and state == State.WORKING
	_tag.position = position
	_tag.visible = visible
	_task_label.visible = state == State.WORKING  # lounge seats are too close for a second line


func _arrive() -> void:
	if goal == Goal.STREET:
		state = State.FLEEING
		body.pose = BugBody.Pose.PANIC
		_flee_to = _random_street_point()
		world.release_slot(self)
	else:
		_sit()


## Seated: follow the session's status, and move between desk and lounge as it changes.
func _settled(delta: float) -> void:
	var away := Layout.is_lounge(slot) and position.distance_to(Layout.seat(slot)) > 8.0
	if ended:
		_begin(_from_here(Layout.route_to_door(slot), away), Goal.STREET)
		bubble.say(CLOSED_LINES.pick_random(), 2.5)
		return
	if Layout.is_lounge(slot) != wants_rest:
		var from := slot
		var target: int = world.claim_slot(self, wants_rest)
		if target >= 0:
			_begin(_from_here(Layout.route(from, target), away), Goal.SEAT)
			return
	if state == State.RESTING:
		_rest_life(delta)
	_update_pose()


func _random_street_point() -> Vector2:
	return Vector2(randf_range(40.0, 1210.0), randf_range(675.0, 720.0))


func _follow(speed: float, delta: float) -> bool:
	if _path_i >= _path.size():
		return true
	if _step_to(_path[_path_i], speed, delta):
		_path_i += 1
	return _path_i >= _path.size()


func _step_to(target: Vector2, speed: float, delta: float) -> bool:
	var to := target - position
	var dist := to.length()
	if dist < 1.0:
		return true
	var step := minf(speed * delta, dist)
	position += to / dist * step
	body.face(to.angle(), delta)
	body.walk(step)
	return dist <= step


func _exit_tree() -> void:
	_tag.queue_free()


func _draw() -> void:
	if selected:
		draw_arc(Vector2(0, -4), 46, 0, TAU, 40, Color(1, 0.95, 0.5), Layout.PIXEL)
