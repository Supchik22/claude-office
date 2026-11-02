class_name Officer
extends Node2D
## A TCK officer. Rides in the van, steps out to catch a leaver, and climbs back in afterwards.

enum State { HIDDEN, CHASE, ESCORT, BOARD }

const RUN_SPEED := 255.0
const ESCORT_SPEED := 125.0
const LINES: Array[String] = ["Повістка!", "Документи!", "Стій, жук!", "Дані оновлював?",
		"Куди зібрався?", "Пройдемо до буса"]
const PET_LINES: Array[String] = ["Не заважай службі!", "...Ну гаразд.", "Це не за статутом", "Я при виконанні!"]

var state := State.HIDDEN
var target: Agent
var van: Van
var world: Node
var body := BugBody.new()
var bubble := Bubble.new()
var _tag := Node2D.new()
var _heart_cd := 0.0
var _line_cd := 0.0


func _init(squad_van: Van, owner_world: Node) -> void:
	van = squad_van
	world = owner_world
	z_index = 6
	visible = false
	body.kind = BugBody.Kind.OPUS
	body.tint = Color("66774c")
	body.uniform = true
	add_child(body)
	_tag.add_child(bubble)
	owner_world.overlay.add_child(_tag)


## Free to take a new leaver: sitting in the van or already on the way back to it.
func is_free() -> bool:
	return state == State.HIDDEN or state == State.BOARD


func chase(agent: Agent) -> void:
	if state == State.HIDDEN:
		position = _van_door()
		visible = true
		van.open_door()
	target = agent
	state = State.CHASE


## Even a TCK officer likes being stroked, though he will not admit it.
func pet() -> void:
	body.happy = 1.2
	if _heart_cd <= 0.0:
		_heart_cd = 0.25
		world.spawn_heart(position + Vector2(randf_range(-18.0, 18.0), -36.0))
	if _line_cd <= 0.0:
		_line_cd = 3.0
		bubble.say(PET_LINES.pick_random(), 2.2, Color("8e2020"))


func _van_door() -> Vector2:
	return van.door_position() + Vector2(46, -8)


func _exit_tree() -> void:
	_tag.queue_free()


func _process(delta: float) -> void:
	_tag.position = position
	_tag.visible = visible
	_heart_cd -= delta
	_line_cd -= delta
	match state:
		State.BOARD:
			if _step_to(_van_door(), RUN_SPEED * 0.6, delta):
				state = State.HIDDEN
				visible = false
				van.open_door()
		State.CHASE:
			_chase(delta)
		State.ESCORT:
			_escort(delta)


func _chase(delta: float) -> void:
	if not is_instance_valid(target):
		state = State.BOARD
		return
	_step_to(target.position, RUN_SPEED, delta)
	if position.distance_to(target.position) < 62.0:
		target.caught()
		bubble.say(LINES.pick_random(), 2.6, Color("8e2020"))
		state = State.ESCORT


func _escort(delta: float) -> void:
	if not is_instance_valid(target):
		state = State.BOARD
		return
	# the prisoner trails behind, so it reaches the van door last
	var leash := target.position.direction_to(position) * 62.0
	target.drag_to(position - leash, ESCORT_SPEED * 1.4, delta)
	if not van.is_parked():
		return
	if _step_to(_van_door(), ESCORT_SPEED, delta) and target.position.distance_to(position) < 84.0:
		var prisoner := target
		target = null
		state = State.BOARD
		van.load_agent(prisoner)


func _step_to(where: Vector2, speed: float, delta: float) -> bool:
	var to := where - position
	var dist := to.length()
	if dist < 2.0:
		return true
	var step := minf(speed * delta, dist)
	position += to / dist * step
	body.face(to.angle(), delta)
	body.walk(step)
	return dist <= step
