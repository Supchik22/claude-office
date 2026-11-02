class_name BugBody
extends Node2D
## The pixel agent on a 17x10 grid of 4px cells. Agents, subagents and TCK officers share it.
## It never rotates: the eyes show the direction, legs and arms carry the animation.
## The model sets colour, size and headwear; a crown marks a session that leads a team.

enum Pose { WALK, TYPE, WAIT, RAISE, PANIC, SLEEP, SIP, DANCE }
enum Kind { OPUS, SONNET, HAIKU, FABLE, OTHER }

const CELL := 4.0
const ORIGIN := Vector2(-36, -24)
const EYE := Color.BLACK
const GOLD := Color("f2c230")
const BLUSH := Color("ff8fa3")
const LOOKS := {
	Kind.OPUS: {"color": Color("d77757"), "bw": 13, "bh": 8, "name": "Opus"},
	Kind.SONNET: {"color": Color("6c8ef5"), "bw": 11, "bh": 8, "name": "Sonnet"},
	Kind.HAIKU: {"color": Color("5fbf8f"), "bw": 9, "bh": 6, "name": "Haiku"},
	Kind.FABLE: {"color": Color("a574e0"), "bw": 13, "bh": 8, "name": "Fable"},
	Kind.OTHER: {"color": Color("a3a29a"), "bw": 11, "bh": 7, "name": "?"},
}
const Z_GLYPH := ["###", "..#", ".#.", "#..", "###"]
const ALERT_GLYPH := ["#", "#", "#", "#", ".", "#"]

var kind := Kind.OPUS
var mini := false  # a subagent
var uniform := false  # TCK: camouflage, cap and a summons in hand
var crowned := false  # leads a team of subagents
var alert := false
var tint := Color(0, 0, 0, 0)  # replaces the model colour when its alpha is above zero
var hat := Color("c2503f")  # subagent cap
var pose := Pose.WALK
var look := Vector2i.ZERO  # eye offset in cells
var happy := 0.0  # seconds of being petted left
var _stride := 0.0
var _t := randf() * 10.0


static func kind_of(model: String) -> Kind:
	var m := model.to_lower()
	if "opus" in m:
		return Kind.OPUS
	if "sonnet" in m:
		return Kind.SONNET
	if "haiku" in m:
		return Kind.HAIKU
	if "fable" in m:
		return Kind.FABLE
	return Kind.OTHER


static func kind_name(k: Kind) -> String:
	var spec: Dictionary = LOOKS[k]
	return spec.name


func body_color() -> Color:
	if tint.a > 0.0:
		return tint
	var spec: Dictionary = LOOKS[kind]
	return spec.color


func face(angle: float, _delta: float) -> void:
	look = Vector2i(roundi(cos(angle)), roundi(sin(angle)))


func walk(distance: float) -> void:
	_stride += distance * 0.07


func _process(delta: float) -> void:
	_t += delta
	happy = maxf(0.0, happy - delta)
	# stay on the pixel grid while the parent glides between cells
	var parent_position: Vector2 = get_parent().position
	var shake := Vector2(CELL if happy > 0.0 and int(_t * 12.0) % 2 == 0 else 0.0, 0.0)
	position = (parent_position / CELL).round() * CELL - parent_position + shake
	queue_redraw()


func _cell(col: float, row: float, w: float, h: float, col_color: Color) -> void:
	draw_rect(Rect2(ORIGIN + Vector2(col, row) * CELL, Vector2(w, h) * CELL), col_color)


func _draw() -> void:
	if mini:
		_draw_mini()
		return
	var spec: Dictionary = LOOKS[kind]
	var color := body_color()
	var bw: int = spec.bw
	var bh: int = spec.bh
	var x0 := int(8.5 - bw / 2.0)
	var y0 := 8 - bh
	var step := int(_stride) % 2
	var moving := pose == Pose.WALK and look != Vector2i.ZERO
	var bob := float(step) if moving else 0.0
	if pose == Pose.DANCE:
		bob = float(int(_t * 6.0) % 2)
	_cell(1, 10, 15, 1, Color(0, 0, 0, 0.25))
	_draw_legs(x0, bw, color, step, moving)
	_cell(x0, y0 + bob, bw, bh, color)
	_draw_arms(x0, bw, y0 + 4.0 + bob, color)
	if uniform:
		_draw_uniform(bob)
	_draw_eyes(x0, bw, y0, bob)
	if not uniform:
		_draw_headwear(y0 + bob)
	if pose == Pose.SLEEP and happy <= 0.0:
		_draw_zzz(x0 + bw, y0)
	if alert and fmod(_t, 0.7) < 0.45:
		Gfx.sprite(self, ORIGIN + Vector2(8, y0 - 9) * CELL, ALERT_GLYPH, {"#": Color("ff5a3c")})


func _draw_legs(x0: int, bw: int, color: Color, step: int, moving: bool) -> void:
	for col: int in [x0, x0 + bw - 3]:
		_cell(col, 8, 1, 1.0 if moving and step == 0 else 2.0, color)
	for col: int in [x0 + 2, x0 + bw - 1]:
		_cell(col, 8, 1, 1.0 if moving and step == 1 else 2.0, color)


func _draw_arms(x0: int, bw: int, base: float, color: Color) -> void:
	var left := base
	var right := base
	var cup := false
	match pose:
		Pose.TYPE:  # arms hammer the keyboard in turn
			var beat := int(_t * 11.0) % 2
			left += float(beat)
			right += float(1 - beat)
		Pose.WAIT:
			left += float(int(_t * 1.5) % 2)
			right = left
		Pose.RAISE:  # gives orders or asks for permission
			left = base - 4.0 + float(int(_t * 6.0) % 2)
		Pose.PANIC:
			var beat := float(int(_t * 12.0) % 2)
			left = base - 3.0 + beat
			right = base - 2.0 - beat
		Pose.DANCE:  # both arms up, swapping
			var beat := int(_t * 6.0) % 2
			left = base - 4.0 + float(beat)
			right = base - 4.0 + float(1 - beat)
		Pose.SIP:
			right = base - 2.0
			cup = true
		Pose.SLEEP:
			left = base + 1.0
			right = base + 1.0
	_cell(x0 - 2, left, 2, 2, color)
	_cell(x0 + bw, right, 2, 2, color)
	if cup:
		_cell(x0 + bw + 2, right - 1.0, 2, 2, Color("eee9dd"))
		if int(_t * 3.0) % 2 == 0:
			_cell(x0 + bw + 2, right - 3.0, 1, 1, Color(1, 1, 1, 0.7))


func _draw_eyes(x0: int, bw: int, y0: int, bob: float) -> void:
	var blink := fmod(_t, 3.4) < 0.14
	var row := y0 + 2.0 + bob + look.y
	for col: int in [x0 + 2, x0 + bw - 3]:
		var c := float(col + look.x)
		if happy > 0.0:  # ^ ^ and a blush
			_cell(c, row, 1, 1, EYE)
			_cell(c - 1.0, row + 1.0, 1, 1, EYE)
			_cell(c + 1.0, row + 1.0, 1, 1, EYE)
			_cell(c - 1.0, row + 2.0, 2, 1, BLUSH)
		elif pose == Pose.SLEEP or blink:
			_cell(c, row + 1.0, 1, 1, EYE)
		else:
			_cell(c, row, 1, 2, EYE)


func _draw_headwear(top: float) -> void:
	if crowned:
		_cell(5, top - 1, 7, 1, GOLD)
		for col: int in [5, 8, 11]:
			_cell(col, top - 2, 1, 1, GOLD)
		_cell(8, top - 1, 1, 1, Color("c2303a"))
		if fmod(_t, 4.0) < 0.2:
			_cell(11, top - 3, 1, 1, Color.WHITE)
		return
	match kind:
		Kind.SONNET:  # antenna with a bead
			_cell(8, top - 2, 1, 2, body_color().darkened(0.35))
			_cell(8, top - 3, 1, 1, body_color().lightened(0.45))
		Kind.HAIKU:  # a sprout
			_cell(8, top - 1, 1, 1, Color("2f7a3c"))
			_cell(7, top - 2, 1, 1, Color("4fb35a"))
			_cell(9, top - 2, 1, 1, Color("4fb35a"))
		Kind.FABLE:  # a wizard hat with a star
			var cloth := Color("5b3b99")
			_cell(4, top - 1, 9, 1, cloth)
			_cell(6, top - 2, 5, 1, cloth)
			_cell(7, top - 3, 3, 1, cloth)
			_cell(8, top - 4, 1, 1, cloth)
			_cell(8, top - 2, 1, 1, GOLD)


func _draw_zzz(x_right: int, y0: int) -> void:
	for i in 2:
		var phase := fmod(_t * 0.7 + i * 0.5, 1.0)
		var pos := ORIGIN + Vector2(roundf(x_right + 1.0 + i * 2.0 + phase * 2.0), roundf(y0 - 3.0 - phase * 5.0)) * CELL
		Gfx.sprite(self, pos, Z_GLYPH, {"#": Color(1, 1, 1, 1.0 - phase)})


func _draw_uniform(bob: float) -> void:
	var color := body_color()
	var patch := color.darkened(0.3)
	var sand := color.lightened(0.28)
	for spot: Array in [[3.0, 5.0, 3.0, 1.0], [10.0, 6.0, 3.0, 2.0], [7.0, 3.0, 2.0, 2.0]]:
		_cell(spot[0], spot[1] + bob, spot[2], spot[3], patch)
	for spot: Array in [[6.0, 6.0, 2.0, 1.0], [12.0, 4.0, 2.0, 1.0]]:
		_cell(spot[0], spot[1] + bob, spot[2], spot[3], sand)
	_cell(3, bob - 2.0, 11, 3, Color("2f3b26"))
	_cell(1, bob, 15, 1, Color("1e2618"))
	_cell(7, bob - 1.0, 3, 1, Color("c23b3b"))
	_cell(14, 5 + bob, 4, 4, Color("f1eee2"))  # the summons
	_cell(15, 6 + bob, 2, 1, Color("8a8676"))


## A subagent: the same bug, smaller, in a cap.
func _draw_mini() -> void:
	var color := body_color()
	var step := int(_stride) % 2
	var moving := pose == Pose.WALK and look != Vector2i.ZERO
	var bob := float(step) if moving else 0.0
	_cell(3, 10, 11, 1, Color(0, 0, 0, 0.25))
	for col: int in [5, 11]:
		if not moving or step == 0:
			_cell(col, 9, 1, 1, color)
	for col: int in [7, 9]:
		if not moving or step == 1:
			_cell(col, 9, 1, 1, color)
	_cell(5, 4 + bob, 7, 5, color)
	var left := 6.0 + bob
	var right := 6.0 + bob
	if pose == Pose.TYPE:
		var beat := int(_t * 11.0) % 2
		left += float(beat)
		right += float(1 - beat)
	_cell(4, left, 1, 2, color)
	_cell(12, right, 1, 2, color)
	_cell(6, 3 + bob, 5, 1, hat)
	_cell(7, 2 + bob, 3, 1, hat)
	for col: int in [6, 10]:
		_cell(col + look.x, 5 + bob, 1, 1, EYE)
		if happy > 0.0:
			_cell(col + look.x, 6 + bob, 1, 1, BLUSH)
	if pose == Pose.TYPE:  # code bits rising off the keyboard
		_cell(13, 6.0 - float(int(_t * 6.0) % 3), 1, 1, Color("7cc7ff"))
