class_name Minion
extends Node2D
## A subagent: a small bug that pops out next to the session that spawned it.

const SPEED := 220.0
const PET_LINES: Array[String] = ["Хі-хі", "Я ще працюю!", "Дякую, шефе", "Мур"]

var world: Node
var lead: Agent
var key := ""
var index := 0
var body := BugBody.new()
var bubble := Bubble.new()
var _tag := Node2D.new()
var _label := Label.new()
var _desc := ""
var _say_in := randf_range(4.0, 10.0)
var _heart_cd := 0.0
var _line_cd := 0.0
var _t := 0.0


func _init(owner_world: Node, leader: Agent, minion_key: String) -> void:
	world = owner_world
	lead = leader
	key = minion_key
	z_index = 5
	position = leader.position
	body.mini = true
	add_child(body)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.custom_minimum_size = Vector2(48, 0)  # the team stands close together
	_label.position = Vector2(-24, 20)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_color", Color("d8d4c0"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_child(_label)
	_tag.add_child(bubble)
	bubble.lift = 52.0
	world.overlay.add_child(_tag)


func _ready() -> void:
	_puff()


func apply(info: Dictionary, i: int) -> void:
	index = i
	var type := Agent.text_of(info, "type", "agent")
	_label.text = type
	_desc = Agent.text_of(info, "desc", "")
	body.kind = lead.kind
	body.hat = Color.from_hsv(float(hash(type) % 1000) / 1000.0, 0.7, 0.9)


func dismiss() -> void:
	_puff(Color("ffe9a8"))
	queue_free()


## Strokes the subagent.
func pet() -> void:
	body.happy = 1.2
	if _heart_cd <= 0.0:
		_heart_cd = 0.25
		world.spawn_heart(position + Vector2(randf_range(-10.0, 10.0), -26.0))
	if _line_cd <= 0.0:
		_line_cd = 3.0
		bubble.say(PET_LINES.pick_random(), 2.0, Color("b02a48"))


func _puff(tint := Color("e8e4d4")) -> void:
	var puff := Puff.new()
	puff.tint = tint
	puff.position = position
	world.spawn_effect(puff)


func _formation() -> Vector2:
	if lead.slot >= 0 and not Layout.is_lounge(lead.slot):
		return Layout.team_pos(lead.slot, index)
	return lead.position + Vector2(64.0 + index * 36.0, 16.0)


func _process(delta: float) -> void:
	_t += delta
	_heart_cd -= delta
	_line_cd -= delta
	if not is_instance_valid(lead):
		queue_free()
		return
	var arrived := _step_to(_formation(), SPEED, delta)
	if arrived:
		body.pose = BugBody.Pose.TYPE
		body.look = Vector2i(clampi(roundi((lead.position.x - position.x) / 40.0), -1, 1), 0)
		_say_in -= delta
		if _say_in <= 0.0 and _desc != "":
			_say_in = randf_range(12.0, 22.0)
			bubble.say(_desc, 3.0)
	else:
		body.pose = BugBody.Pose.WALK
	_tag.position = position


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
