class_name Heart
extends Node2D
## A pixel heart floating up from a petted bug.

const LIFE := 1.0
const SHAPE := ["##.##", "#####", "#####", ".###.", "..#.."]

var _t := 0.0
var _sway := randf() * TAU


func _init() -> void:
	z_index = 9


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var at := Vector2(roundf(sin(_sway + _t * 6.0) * 2.0) * Layout.PIXEL, roundf(-k * 11.0) * Layout.PIXEL)
	var alpha := 1.0 - maxf(0.0, k - 0.6) / 0.4
	Gfx.sprite(self, at - Vector2(10, 10), SHAPE, {"#": Color(0.93, 0.27, 0.35, alpha)})
	draw_rect(Rect2(at + Vector2(-10, -10), Vector2(4, 4)), Color(1, 0.75, 0.8, alpha))
