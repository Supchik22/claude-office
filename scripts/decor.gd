class_name Decor
extends Node2D
## Animated scenery: windows with a day/night cycle, clock, plants, steam, printer,
## vending machine and aquarium. `--hour=23` forces the time of day.

const P := Layout.PIXEL
const FRAME := Color("3f4450")
const WINDOWS: Array[float] = [100.0, 250.0, 400.0, 850.0, 1000.0, 1150.0]
const PLANT := [
	"...g..g..g...", "..gGg.g.gGg..", ".gGGgGgGgGGg.", "..gGGGGGGGg..", "ggGGdGGGdGGgg",
	".gGGGdGdGGGg.", "..ggGGdGGgg..", ".gGGGdGdGGGg.", "ggGGdGGGdGGgg", "..gGGGGGGGg..",
	".gGGgGgGgGGg.", "..gGg.g.gGg..", "...g..g..g...",
]
const PLANT_COLORS := {"g": Color("2f6b3c"), "G": Color("4c9a50"), "d": Color("7cc46f")}
const SNACKS: Array[Color] = [Color("e0884a"), Color("4a9a6a"), Color("e8d44a"), Color("c2503f"), Color("6c8ef5")]

var _t := 0.0
var _hours := 12.0
var _dark := 0.0
var _hour_override := -1.0
var _check_in := 0.0
var _tint := NightTint.new()


class NightTint extends Node2D:
	var dark := 0.0

	func _draw() -> void:
		if dark > 0.01:
			draw_rect(Rect2(0, 0, Layout.OFFICE_W, 900), Color(0.04, 0.07, 0.22, 0.3 * dark))


func _ready() -> void:
	z_index = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hour="):
			_hour_override = float(arg.substr(7))
	_tint.z_index = 30
	add_child(_tint)


func _process(delta: float) -> void:
	_t += delta
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 5.0
		_update_daylight()
	queue_redraw()


func _update_daylight() -> void:
	_hours = _hour_override
	if _hours < 0.0:
		var now := Time.get_datetime_dict_from_system()
		_hours = float(now.hour) + float(now.minute) / 60.0
	if _hours < 5.0 or _hours >= 21.0:
		_dark = 1.0
	elif _hours < 8.0:
		_dark = 1.0 - (_hours - 5.0) / 3.0
	elif _hours < 18.0:
		_dark = 0.0
	else:
		_dark = (_hours - 18.0) / 3.0
	_tint.dark = _dark
	_tint.queue_redraw()


func _draw() -> void:
	_draw_windows()
	_draw_clock()
	for at: Vector2 in [Vector2(20, 40), Vector2(1188, 40), Vector2(20, 584), Vector2(1188, 584)]:
		_draw_plant(at)
	_steam(Vector2(352, 36), 3)
	for cx: float in [192.0, 1056.0]:  # coffee on the lounge tables
		_steam(Vector2(cx - 20, 478), 2)
		_steam(Vector2(cx + 16, 478), 2)
	_draw_printer_paper()
	_draw_vending(Vector2(524, 452))
	_draw_aquarium(Vector2(680, 452))


func _draw_windows() -> void:
	var sky := Color("9fd3e6").lerp(Color("e79a6b"), clampf(_dark * 2.0, 0.0, 1.0)) \
			.lerp(Color("1b2440"), clampf(_dark * 2.0 - 1.0, 0.0, 1.0))
	for i in WINDOWS.size():
		var x: float = WINDOWS[i] - 44.0
		draw_rect(Rect2(x, 8, 88, 16), sky)
		if _dark < 0.5:
			var left := fposmod(_t * 4.0 + i * 37.0, 150.0) - 24.0
			var from := snappedf(maxf(left, 0.0), P)
			var to := snappedf(minf(left + 20.0, 88.0), P)
			if to > from:
				draw_rect(Rect2(x + from, 12, to - from, 4), Color(1, 1, 1, 0.85))
		else:
			for k in 3:
				if fmod(_t + k + i, 3.0) < 2.6:
					draw_rect(Rect2(x + 8.0 + float((i * 29 + k * 31) % 72), 8.0 + float((k * 5 + i * 3) % 4) * 4.0, P, P),
							Color(1, 1, 1, _dark))
		draw_rect(Rect2(x + 42, 8, 4, 16), FRAME)


func _draw_clock() -> void:
	draw_rect(Rect2(468, 2, 32, 28), FRAME)
	draw_rect(Rect2(472, 4, 28, 28 - 2), Color("ecebe4"))
	var center := Vector2(484, 16)
	draw_rect(Rect2(center, Vector2(P, P)), Color("1b1c20"))
	var minute := fmod(_hours, 1.0) * 60.0
	var a_min := minute / 60.0 * TAU - PI / 2.0
	var a_hour := fmod(_hours, 12.0) / 12.0 * TAU - PI / 2.0
	for r in [1.0, 2.0]:
		draw_rect(Rect2(center + Vector2(roundf(cos(a_min) * r), roundf(sin(a_min) * r)) * P, Vector2(P, P)), Color("3b5fb5"))
	draw_rect(Rect2(center + Vector2(roundf(cos(a_hour)), roundf(sin(a_hour))) * P, Vector2(P, P)), Color("c2503f"))


func _draw_plant(at: Vector2) -> void:
	var sway := int(_t * 1.2) % 2 == 1
	for y in PLANT.size():
		var row: String = PLANT[y]
		var shift := P if sway and y < 5 else 0.0
		for x in row.length():
			if PLANT_COLORS.has(row[x]):
				draw_rect(Rect2(at + Vector2(x * P + shift, y * P), Vector2(P, P)), PLANT_COLORS[row[x]])


func _steam(at: Vector2, count: int) -> void:
	for i in count:
		var phase := fmod(_t * 0.6 + i * 0.33, 1.0)
		var p := Vector2(at.x + snappedf(sin(_t * 2.0 + i * 2.0) * 4.0, P), snappedf(at.y - phase * 20.0, P))
		draw_rect(Rect2(p, Vector2(P, P)), Color(1, 1, 1, 0.7 * (1.0 - phase)))


func _draw_printer_paper() -> void:
	var c := fmod(_t, 14.0)
	var rows := 0.0
	if c < 1.0:
		rows = floorf(c * 3.0) + 1.0
	elif c < 4.0:
		rows = 3.0
	if rows > 0.0:
		draw_rect(Rect2(892, 64, 16, rows * P), Color("f6f5ef"))
		draw_rect(Rect2(896, 64 + P, 8, P), Color("8d8a80"))


func _draw_vending(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(4, 4), Vector2(56, 68)), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(at, Vector2(48, 60)), Color("b6463a"))
	draw_rect(Rect2(at + Vector2(4, 4), Vector2(28, 44)), Color("1c2733"))
	for row in 3:
		for col in 3:
			draw_rect(Rect2(at + Vector2(8 + col * 8, 8 + row * 14), Vector2(4, 8)), SNACKS[(row * 3 + col) % SNACKS.size()])
	draw_rect(Rect2(at + Vector2(36, 4), Vector2(8, 44)), Color("2a2b2f"))
	for i in 3:
		var lit := int(_t * 2.0) % 3 == i
		draw_rect(Rect2(at + Vector2(36, 8 + i * 12), Vector2(8, 4)), Color("53d769") if lit else Color("2f5a3a"))
	draw_rect(Rect2(at + Vector2(4, 52), Vector2(28, 4)), Color("0d0f12"))


func _draw_aquarium(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(4, 4), Vector2(88, 56)), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(at, Vector2(80, 48)), Color("232830"))
	draw_rect(Rect2(at + Vector2(4, 4), Vector2(72, 40)), Color("3b7fa6"))
	draw_rect(Rect2(at + Vector2(4, 36), Vector2(72, 8)), Color("c9b27c"))
	draw_rect(Rect2(at + Vector2(12, 24), Vector2(4, 12)), Color("2f7a3c"))
	draw_rect(Rect2(at + Vector2(16, 28), Vector2(4, 8)), Color("4fb35a"))
	draw_rect(Rect2(at + Vector2(60, 28), Vector2(4, 8)), Color("2f7a3c"))
	var x1 := snappedf(8.0 + fposmod(_t * 12.0, 56.0), P)
	draw_rect(Rect2(at + Vector2(x1, 12), Vector2(8, 4)), Color("e0884a"))
	draw_rect(Rect2(at + Vector2(x1 - 4.0, 12), Vector2(4, 4)), Color("c2603a"))
	draw_rect(Rect2(at + Vector2(x1 + 4.0, 12), Vector2(4, 4)), Color("1b1c20"))
	var x2 := snappedf(64.0 - fposmod(_t * 9.0 + 20.0, 52.0), P)
	draw_rect(Rect2(at + Vector2(x2, 24), Vector2(8, 4)), Color("e8d44a"))
	draw_rect(Rect2(at + Vector2(x2 + 8.0, 24), Vector2(4, 4)), Color("b89a2a"))
	for k in 2:
		var y := 36.0 - fposmod(_t * 10.0 + k * 13.0, 32.0)
		draw_rect(Rect2(at + Vector2(24.0 + k * 28.0, snappedf(y, P)), Vector2(P, P)), Color(1, 1, 1, 0.6))
