class_name Puff
extends Node2D
## A pixel smoke ring: a subagent appearing or leaving.

const LIFE := 0.6

var tint := Color("e8e4d4")
var _t := 0.0


func _init() -> void:
	z_index = 8


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var size := 8.0 if k < 0.5 else 4.0
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		var at := (Vector2(cos(a), sin(a)) * (8.0 + k * 38.0) / Layout.PIXEL).round() * Layout.PIXEL
		draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), Color(tint, 1.0 - k))
