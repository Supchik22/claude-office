class_name Van
extends Node2D
## The TCK van. It is only here when a session was closed: it arrives, the officers catch the
## leaver, and it drives off with it.

signal loaded(agent: Agent)

enum State { PARKED, DEPARTING, AWAY, ARRIVING }

const PARKED_AT := Vector2(1000, 780)
const LEN := 312.0
const WID := 96.0
const LETTERS := [
	["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####", "....#"],
	["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
]

var state := State.AWAY
var riders: Array[Color] = []  # one per caught session, shown behind the hatch bars
var _speed := 0.0
var _door := 0.0  # 0 closed, 1 open
var _door_hold := 0.0
var _t := 0.0


func _ready() -> void:
	position = Vector2(-400.0, PARKED_AT.y)
	z_index = 3


func is_parked() -> bool:
	return state == State.PARKED


func door_position() -> Vector2:
	return position + Vector2(-40, -WID / 2 - 14)


func load_agent(agent: Agent) -> void:
	riders.append(agent.body.body_color())
	open_door()
	loaded.emit(agent)


func open_door() -> void:
	_door_hold = 1.5


## Called when a session was closed: the van drives in from the left.
func summon() -> void:
	if state == State.AWAY:
		position.x = -260.0
		state = State.ARRIVING


func depart() -> void:
	if state == State.PARKED:
		state = State.DEPARTING
		_speed = 0.0


func _process(delta: float) -> void:
	_t += delta
	_door_hold -= delta
	_door = move_toward(_door, 1.0 if _door_hold > 0.0 and is_parked() else 0.0, delta * 4.0)
	match state:
		State.DEPARTING:
			_speed = minf(_speed + 420.0 * delta, 720.0)
			position.x += _speed * delta
			if position.x > 1900.0:
				state = State.AWAY
				position.x = -400.0
				riders.clear()
		State.ARRIVING:
			var left := PARKED_AT.x - position.x
			position.x += clampf(left * 2.6, 60.0, 720.0) * delta
			if left < 2.0:
				position = PARKED_AT
				state = State.PARKED
	queue_redraw()


func _draw() -> void:
	var half_l := LEN / 2
	var half_w := WID / 2
	var paint := Color("4f5f3c")
	var outline := Color("232b1b")
	Gfx.rrect(self, Rect2(-half_l + 8, -half_w + 12, LEN, WID), 18, Color(0, 0, 0, 0.3))
	for x: float in [-100.0, 95.0]:
		for y: float in [-half_w - 3, half_w - 7]:
			Gfx.rrect(self, Rect2(x - 24, y, 48, 10), 3, Color("121212"))
	Gfx.rrect(self, Rect2(-half_l - 2, -half_w - 2, LEN + 4, WID + 4), 20, outline)
	Gfx.rrect(self, Rect2(-half_l, -half_w, LEN, WID), 18, paint)
	# bonnet and windscreen, front faces +X
	Gfx.rrect(self, Rect2(half_l - 62, -half_w + 6, 54, WID - 12), 14, paint.lightened(0.1))
	Gfx.rrect(self, Rect2(half_l - 100, -half_w + 8, 40, WID - 16), 8, Color("22313d"))
	Gfx.rrect(self, Rect2(half_l - 94, -half_w + 13, 10, WID - 26), 4, Color("47606f"))
	Gfx.rrect(self, Rect2(-half_l + 14, -half_w + 10, LEN - 124, WID - 20), 10, paint.lightened(0.07))
	for y: float in [-half_w + 8, half_w - 22]:  # headlights
		Gfx.rrect(self, Rect2(half_l - 7, y, 6, 14), 2, Color("f3e6a6"))
	for patch: Array in [[-110.0, -28.0, 24.0, 10.0], [-40.0, 30.0, 30.0, 9.0], [36.0, -30.0, 22.0, 9.0]]:
		Gfx.ellipse(self, Vector2(patch[0], patch[1]), patch[2], patch[3], Color("3a4a2d"))
	var ink := {"#": Color("f2efdf")}
	for i in LETTERS.size():
		Gfx.sprite(self, Vector2(-108 + i * 48, -20), LETTERS[i], ink, 8.0)
	_draw_beacon(half_l - 112)
	_draw_riders(half_w)
	_draw_side_door(half_w)


func _draw_beacon(x: float) -> void:
	var red_on := fmod(_t, 0.8) < 0.4
	Gfx.rrect(self, Rect2(x - 7, -24, 14, 48), 4, Color("20242b"))
	Gfx.ellipse(self, Vector2(x, -13), 5, 9, Color("ff3b30") if red_on else Color("5a1712"))
	Gfx.ellipse(self, Vector2(x, 13), 5, 9, Color("2d3a9e") if red_on else Color("3a7bff"))


## Barred roof hatch with the catch peeking through.
func _draw_riders(half_w: float) -> void:
	var hatch := Rect2(-136, -half_w + 12, 192, 16)
	Gfx.rrect(self, hatch, 4, Color("1a1f17"))
	for i in mini(riders.size(), 9):
		var center := Vector2(hatch.position.x + 14 + i * 20, hatch.get_center().y)
		draw_rect(Rect2(center - Vector2(8, 6), Vector2(16, 12)), riders[i])
		for side: float in [-5.0, 3.0]:
			draw_rect(Rect2(center + Vector2(side, -3), Vector2(2, 4)), Color.BLACK)
	var bar := hatch.position.x + 7
	while bar < hatch.end.x:
		draw_rect(Rect2(bar, hatch.position.y, 4, hatch.size.y), Color("8d9484"))
		bar += 20


func _draw_side_door(half_w: float) -> void:
	var slide := _door * 62.0
	Gfx.rrect(self, Rect2(-72, -half_w - 3, 66, 7), 2, Color("0d0f0b"))
	Gfx.rrect(self, Rect2(-72 - slide, -half_w - 6, 66, 6), 2, Color("7a8b63"))
