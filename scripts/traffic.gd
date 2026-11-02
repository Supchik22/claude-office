class_name Traffic
extends Node2D
## Pixel cars driving along the road below the parked van.

enum Type { SEDAN, HATCH, TAXI, BUS, TRUCK }

const P := Layout.PIXEL
const WIDTH := 48.0
const COLORS: Array[Color] = [Color("c2503f"), Color("3b6fb5"), Color("4a9a6a"), Color("d9d6cc"),
		Color("6c5aa8"), Color("2d2f36"), Color("e0884a")]
const LENGTHS := {Type.SEDAN: 104.0, Type.HATCH: 88.0, Type.TAXI: 104.0, Type.BUS: 200.0, Type.TRUCK: 152.0}

var cars: Array[Dictionary] = []  # x is the front bumper
var _spawn_in := 0.5


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_spawn_in -= delta
	if _spawn_in <= 0.0:
		_spawn_in = randf_range(1.8, 5.5)
		_spawn()
	# a car never overtakes: it slows to the pace of the one ahead
	for i in cars.size():
		var car := cars[i]
		for other in cars:
			var gap: float = float(other.x) - float(other.length) - float(car.x)
			if other != car and gap > 0.0 and gap < 56.0:
				car.speed = minf(float(car.speed), float(other.speed))
		car.x = float(car.x) + float(car.speed) * delta
	cars = cars.filter(func(car: Dictionary) -> bool: return float(car.x) < Layout.OFFICE_W + 260.0)
	queue_redraw()


func _spawn() -> void:
	for car in cars:
		if float(car.x) - float(car.length) < 60.0:
			return
	var type: Type = [Type.SEDAN, Type.SEDAN, Type.HATCH, Type.HATCH, Type.TAXI, Type.BUS, Type.TRUCK].pick_random()
	var color: Color = COLORS.pick_random()
	if type == Type.TAXI:
		color = Color("e8b830")
	elif type == Type.BUS:
		color = Color("3b8fc2")
	cars.append({"x": -30.0, "speed": randf_range(150.0, 290.0), "type": type, "length": LENGTHS[type], "color": color})


func _draw() -> void:
	for car in cars:
		_draw_car(car)


func _draw_car(car: Dictionary) -> void:
	var length: float = car.length
	var type: Type = car.type
	var body: Color = car.color
	var origin := Vector2(snappedf(float(car.x), P) - length, Layout.TRAFFIC_Y - WIDTH / 2.0)
	var glass := Color("22313d")
	draw_rect(Rect2(origin + Vector2(4, 8), Vector2(length, WIDTH)), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(origin - Vector2(4, 4), Vector2(length + 8, WIDTH + 8)), body.darkened(0.55))
	draw_rect(Rect2(origin, Vector2(length, WIDTH)), body)
	for wheel_x: float in [origin.x + 12.0, origin.x + length - 36.0]:
		draw_rect(Rect2(wheel_x, origin.y - 4.0, 24, 8), Color("15161a"))
		draw_rect(Rect2(wheel_x, origin.y + WIDTH - 4.0, 24, 8), Color("15161a"))
	match type:
		Type.BUS:
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(length - 56, WIDTH - 16)), body.lightened(0.18))
			for i in 7:
				draw_rect(Rect2(origin + Vector2(16 + i * 24, 12), Vector2(16, WIDTH - 24)), glass)
			draw_rect(Rect2(origin + Vector2(length - 40, 8), Vector2(12, WIDTH - 16)), glass)
		Type.TRUCK:
			draw_rect(Rect2(origin + Vector2(4, 4), Vector2(length - 56, WIDTH - 8)), Color("c9c6bb"))
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(length - 64, 4)), Color("e2dfd3"))
			draw_rect(Rect2(origin + Vector2(length - 36, 8), Vector2(12, WIDTH - 16)), glass)
		_:
			draw_rect(Rect2(origin + Vector2(length * 0.28, 8), Vector2(length * 0.38, WIDTH - 16)), body.lightened(0.15))
			draw_rect(Rect2(origin + Vector2(snappedf(length * 0.66, P), 8), Vector2(8, WIDTH - 16)), glass)
			draw_rect(Rect2(origin + Vector2(snappedf(length * 0.24, P), 12), Vector2(4, WIDTH - 24)), glass)
			if type == Type.TAXI:
				draw_rect(Rect2(origin + Vector2(snappedf(length * 0.42, P), 20), Vector2(12, 8)), Color("fff3a8"))
	for y: float in [4.0, WIDTH - 12.0]:
		draw_rect(Rect2(origin + Vector2(length - 4.0, y), Vector2(4, 8)), Color("f6e9a8"))  # headlights
		draw_rect(Rect2(origin + Vector2(0, y), Vector2(4, 8)), Color("c2303a"))  # tail lights
