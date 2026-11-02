class_name Office
extends Node2D
## Static backdrop on the pixel grid: the office floor with desks, the lounge and the street.
## Animated parts live in Decor, monitors and the door in Screens.

const P := Layout.PIXEL
const PLANKS: Array[Color] = [Color("c9b491"), Color("c2ad89"), Color("cfba97"), Color("bda785")]
const PAVING: Array[Color] = [Color("a09e94"), Color("96948a"), Color("a7a59b")]
const CARPET: Array[Color] = [Color("59678c"), Color("5f6e95")]
const WALL := Color("3f4450")
const WALL_LIGHT := Color("565c6b")
const WINDOW_X: Array[float] = [100.0, 250.0, 400.0, 850.0, 1000.0, 1150.0]

const COFFEE := [
	"bbbbbbbbbbbbbbb", "bmmmmmmmmbbbbbb", "bmmmmmmmmbbrrbb", "bmmmmmmmmbbrrbb",
	"bbbbbbbbbbbbbbb", "bsssssssssssssb", "bbbbbbbbbbbbbbb",
]
const COFFEE_COLORS := {"b": Color("2c2e33"), "m": Color("57c0a0"), "r": Color("c2503f"), "s": Color("55585f")}
const PRINTER := [
	"lllllllllllllllllll", "lppppppppppppppppll", "lppppppppppppppppll",
	"lllllllllllllllllll", "ldddddddddddddddgll", "lllllllllllllllllll",
]
const PRINTER_COLORS := {"l": Color("cfccc2"), "p": Color("f6f5ef"), "d": Color("8d8a80"), "g": Color("53d769")}
const MUG := ["wwwww", "wcccw", "wcccw", "wcccw", "wwwww"]
const MUG_COLORS := {"w": Color("eee9dd"), "c": Color("4a2c1b")}
const MOUSE := ["kkk", "kgk", "kkk", "kkk"]
const MOUSE_COLORS := {"k": Color("2a2b2f"), "g": Color("6d7079")}


func _ready() -> void:
	z_index = 0


func _draw() -> void:
	_draw_street()
	_draw_floor()
	_draw_lounge()
	_draw_walls()
	Gfx.sprite(self, Vector2(332, 40), COFFEE, COFFEE_COLORS)
	Gfx.sprite(self, Vector2(868, 40), PRINTER, PRINTER_COLORS)
	for i in Layout.DESK_COUNT:
		_draw_desk(Layout.desk_center(i))
	_draw_couch(60.0, 324.0, Color("b3523f"))
	_draw_couch(924.0, 1188.0, Color("3f8a92"))
	for seat: Vector2 in [Layout.LOUNGE_SEATS[3], Layout.LOUNGE_SEATS[4]]:
		_draw_pouf(seat, Color("e0884a"))
	for seat: Vector2 in [Layout.LOUNGE_SEATS[8], Layout.LOUNGE_SEATS[9]]:
		_draw_pouf(seat, Color("e8c84a"))


## Stable pseudo-random pick, so the tiles do not change between redraws.
func _pick(x: int, y: int, count: int) -> int:
	return absi(x * 73856093 ^ y * 19349663) % count


func _draw_street() -> void:
	var row := 0
	var y := Layout.STREET_Y
	while y < Layout.ROAD_Y:
		var col := 0
		var x := -24.0 if row % 2 else 0.0
		while x < Layout.OFFICE_W:
			draw_rect(Rect2(x, y, 48, 24), PAVING[_pick(col, row, PAVING.size())])
			col += 1
			x += 48.0
		row += 1
		y += 24.0
	draw_rect(Rect2(0, Layout.ROAD_Y, Layout.OFFICE_W, 900 - Layout.ROAD_Y), Color("3a3b40"))
	draw_rect(Rect2(0, Layout.ROAD_Y, Layout.OFFICE_W, 8), Color("c6c4ba"))
	for i in 220:  # asphalt grit
		var at := Vector2(_pick(i, 3, 315) * P, Layout.ROAD_Y + 8 + _pick(i, 7, 41) * P)
		draw_rect(Rect2(at, Vector2(P, P)), Color("46474d"))
	var dash := 12.0
	while dash < Layout.OFFICE_W:  # parking lane and traffic lane
		draw_rect(Rect2(dash, Layout.LANE_LINE_Y, 52, 4), Color("d9d4b8"))
		dash += 104.0
	for start: float in [76.0, 256.0, 916.0, 1088.0]:
		for i in 11:
			var at := Vector2(start + i * P * 2, 660)
			draw_rect(Rect2(at, Vector2(P * 2, 12 + (i % 3) * P)), Color("3c6b35"))
			draw_rect(Rect2(at + Vector2(P, 0), Vector2(P, P)), Color("5f9c4e"))


func _draw_floor() -> void:
	var size := Vector2(96, 32)
	var row := 0
	var y := 32.0
	while y < Layout.WALL_Y:
		var col := 0
		var x := -48.0 if row % 2 else 0.0
		while x < Layout.OFFICE_W:
			draw_rect(Rect2(Vector2(x, y), size), PLANKS[_pick(col, row, PLANKS.size())])
			draw_rect(Rect2(x, y, P, size.y), Color("b09a79"))
			col += 1
			x += size.x
		row += 1
		y += size.y
	var runner := Rect2(Layout.CORRIDOR_X - 48, 32, 96, Layout.WALL_Y - 32)
	draw_rect(runner, Color("3f666f"))
	draw_rect(runner.grow_individual(-8, 0, -8, 0), Color("548590"))
	var dot := 40.0
	while dot < Layout.WALL_Y:
		draw_rect(Rect2(Layout.CORRIDOR_X - 4, dot, 8, 8), Color("6a9ea8"))
		dot += 32.0


func _draw_lounge() -> void:
	for side_x: float in [12.0, 672.0]:
		var left := side_x
		var width := 564.0
		var y := Layout.PARTITION_Y + 8.0
		var row := 0
		while y < Layout.WALL_Y:
			var x := left
			var col := 0
			while x < left + width:
				draw_rect(Rect2(x, y, 16, 16), CARPET[(col + row) % 2])
				x += 16.0
				col += 1
			y += 16.0
			row += 1
	for cx: float in [192.0, 1056.0]:  # rug and low table
		draw_rect(Rect2(cx - 120, 452, 240, 84), Color("3d4766"))
		draw_rect(Rect2(cx - 112, 460, 224, 68), Color("7a5a86"))
		draw_rect(Rect2(cx - 104, 468, 208, 52), Color("8c6b98"))
		draw_rect(Rect2(cx - 36 + 4, 480, 72, 28), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(cx - 36, 476, 72, 28), Color("6f4d33"))
		draw_rect(Rect2(cx - 32, 480, 64, 20), Color("94693f"))
		Gfx.sprite(self, Vector2(cx - 24, 484), ["ww", "cw"], {"w": Color("eee9dd"), "c": Color("4a2c1b")}, 4.0)
		Gfx.sprite(self, Vector2(cx + 12, 484), ["ww", "cw"], {"w": Color("eee9dd"), "c": Color("4a2c1b")}, 4.0)


func _draw_walls() -> void:
	var door_l := Layout.CORRIDOR_X - 52
	var door_r := Layout.CORRIDOR_X + 52
	draw_rect(Rect2(0, 0, Layout.OFFICE_W, 32), WALL)
	draw_rect(Rect2(0, 28, Layout.OFFICE_W, 4), WALL_LIGHT)
	draw_rect(Rect2(0, 0, 12, Layout.WALL_Y + 20), WALL)
	draw_rect(Rect2(Layout.OFFICE_W - 12, 0, 12, Layout.WALL_Y + 20), WALL)
	for span: Array in [[0.0, door_l], [door_r, Layout.OFFICE_W]]:
		draw_rect(Rect2(span[0], Layout.WALL_Y, span[1] - span[0], 20), WALL)
		draw_rect(Rect2(span[0], Layout.WALL_Y - 4, span[1] - span[0], 4), WALL_LIGHT)
	draw_rect(Rect2(door_l, Layout.WALL_Y - 4, door_r - door_l, 4), WALL_LIGHT)
	draw_rect(Rect2(door_l, Layout.WALL_Y, 104, 20), Color("6d6455"))
	for span: Array in [[12.0, 576.0], [672.0, Layout.OFFICE_W - 12.0]]:  # lounge partition, open at the corridor
		draw_rect(Rect2(span[0], Layout.PARTITION_Y, span[1] - span[0], 8), WALL)
		draw_rect(Rect2(span[0], Layout.PARTITION_Y, span[1] - span[0], 4), WALL_LIGHT)
	for x: float in WINDOW_X:
		draw_rect(Rect2(x - 46, 6, 92, 20), Color("2a2e38"))
	# whiteboard with a scribbled plan
	draw_rect(Rect2(524, 4, 200, 24), Color("ecebe4"))
	for line: Array in [[536.0, 8.0, 60.0, "3b5fb5"], [604.0, 8.0, 32.0, "c2503f"], [536.0, 16.0, 40.0, "c2503f"],
			[584.0, 16.0, 76.0, "3b5fb5"], [648.0, 8.0, 60.0, "3b5fb5"], [672.0, 16.0, 36.0, "2f8f5b"]]:
		draw_rect(Rect2(line[0], line[1], line[2], 4), Color(line[3]))


func _draw_desk(c: Vector2) -> void:
	var size := Layout.DESK_SIZE
	var top := Rect2(c - size / 2, size)
	var seat := c + Vector2(0, 64)
	draw_rect(Rect2(seat - Vector2(24, 24), Vector2(48, 48)), Color("33353c"))  # chair
	draw_rect(Rect2(seat - Vector2(28, 20), Vector2(56, 40)), Color("33353c"))
	draw_rect(Rect2(seat - Vector2(20, 16), Vector2(40, 32)), Color("4b4e58"))
	draw_rect(Rect2(top.position + Vector2(4, 8), size), Color(0, 0, 0, 0.24))
	draw_rect(top, Color("6f4d33"))
	draw_rect(top.grow(-4), Color("94693f"))
	draw_rect(Rect2(top.position + Vector2(4, 4), Vector2(size.x - 8, 4)), Color("a97b4d"))
	draw_rect(Rect2(c + Vector2(-48, 12), Vector2(96, 20)), Color("2a2b2f"))  # keyboard
	for row in 2:
		for key in 11:
			draw_rect(Rect2(c + Vector2(-44 + key * 8, 16 + row * 8), Vector2(4, 4)), Color("5a5d66"))
	Gfx.sprite(self, c + Vector2(56, 12), MOUSE, MOUSE_COLORS)
	Gfx.sprite(self, c + Vector2(-76, 12), MUG, MUG_COLORS)


## A couch against the bottom wall, backrest below the seats.
func _draw_couch(x_left: float, x_right: float, tone: Color) -> void:
	var dark := tone.darkened(0.35)
	var width := x_right - x_left
	draw_rect(Rect2(x_left + 4, 544, width, 96), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(x_left, 536, width, 96), dark)
	draw_rect(Rect2(x_left + 12, 540, width - 24, 60), tone)
	for i in range(1, int(roundf((width - 24.0) / 80.0))):
		draw_rect(Rect2(x_left + 12 + i * 80 - 2, 540, 4, 60), dark)
	draw_rect(Rect2(x_left + 4, 604, width - 8, 24), tone.darkened(0.12))
	draw_rect(Rect2(x_left + 4, 604, width - 8, 4), tone.lightened(0.1))


func _draw_pouf(at: Vector2, tone: Color) -> void:
	draw_rect(Rect2(at + Vector2(-16, -16), Vector2(40, 40)), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(at + Vector2(-16, -20), Vector2(32, 40)), tone)
	draw_rect(Rect2(at + Vector2(-20, -16), Vector2(40, 32)), tone)
	draw_rect(Rect2(at + Vector2(-12, -16), Vector2(12, 4)), tone.lightened(0.25))
	draw_rect(Rect2(at + Vector2(-20, 8), Vector2(40, 8)), tone.darkened(0.2))
