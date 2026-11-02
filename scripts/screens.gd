class_name Screens
extends Node2D
## Everything in the office that animates without being a bug: monitors and the door.

const P := Layout.PIXEL
const QUESTION := [".###.", "#...#", "...#.", "..#..", "..#..", ".....", "..#.."]
const CODE_COLORS: Array[Color] = [Color("7cc7ff"), Color("f0a868"), Color("9be29b"), Color("d7a4f0")]

var occupants: Array = []  # index is a slot, value is an Agent or null
var walkers: Array = []  # anything that should make the door open
var _door := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	var want := false
	for walker: Node2D in walkers:
		if is_instance_valid(walker) and walker.visible \
				and walker.position.distance_to(Layout.DOOR) < 80.0:
			want = true
	_door = move_toward(_door, 1.0 if want else 0.0, delta * 3.5)
	queue_redraw()


func _draw() -> void:
	for i in Layout.DESK_COUNT:
		_draw_monitor(i)
	_draw_door()


func _draw_monitor(i: int) -> void:
	var c := Layout.desk_center(i)
	var frame := Rect2(c + Vector2(-48, -32), Vector2(96, 40))
	draw_rect(Rect2(c + Vector2(-12, 8), Vector2(24, 4)), Color("1b1c20"))
	draw_rect(frame, Color("1b1c20"))
	var screen := frame.grow(-4)
	var agent = occupants[i] if i < occupants.size() else null
	if agent == null or agent.state != Agent.State.WORKING:
		draw_rect(screen, Color("23262e"))
		return
	match agent.status():
		"busy":
			_draw_code(screen, i)
		"blocked":
			draw_rect(screen, Color("5a2b16"))
			if fmod(_t, 0.8) < 0.5:
				Gfx.sprite(self, screen.get_center() - Vector2(10, 14), QUESTION, {"#": Color("ffd18a")})
		"shell":
			_draw_terminal(screen, i)
		_:
			draw_rect(screen, Color("23262e"))
			draw_rect(Rect2(screen.end - Vector2(8, 8), Vector2(P, P)), Color("c2503f"))


func _noise(a: int) -> int:
	return absi(a * 2654435761) % 1000


func _draw_code(screen: Rect2, seed_value: int) -> void:
	draw_rect(screen, Color("1d2333"))
	var scroll := int(_t * 6.0)
	for line in 4:
		var n := _noise(scroll + line * 3 + seed_value * 7)
		var at := screen.position + Vector2(4 + (n % 4) * P, 2 + line * 8.0)
		draw_rect(Rect2(at, Vector2((3 + n % 10) * P, P)), CODE_COLORS[n % 4])


func _draw_terminal(screen: Rect2, seed_value: int) -> void:
	draw_rect(screen, Color("0c120d"))
	for line in 3:
		var n := _noise(int(_t * 1.5) + line * 5 + seed_value * 11)
		draw_rect(Rect2(screen.position + Vector2(4, 2 + line * 8.0), Vector2((4 + n % 12) * P, P)), Color("53d769"))
	if fmod(_t, 1.0) < 0.5:
		draw_rect(Rect2(screen.position + Vector2(4, 26), Vector2(8, P)), Color("53d769"))


func _draw_door() -> void:
	var width := snappedf(52.0 * (1.0 - _door * 0.85), P)
	var left := Layout.CORRIDOR_X - 52
	var right := Layout.CORRIDOR_X + 52
	var col := Color("a9805a")
	draw_rect(Rect2(left, Layout.WALL_Y + 4, width, 12), col)
	draw_rect(Rect2(right - width, Layout.WALL_Y + 4, width, 12), col)
