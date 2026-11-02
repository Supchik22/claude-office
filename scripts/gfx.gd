class_name Gfx
## Polygon helpers: _draw has no ellipse or rounded rectangle primitive.


static func ellipse_points(c: Vector2, rx: float, ry: float, rot := 0.0, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry, rot), col)


static func rrect_points(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centers := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
			r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for q in 4:
		for s in 7:
			var a := -PI / 2 + q * PI / 2 + s * PI / 12
			pts.append(centers[q] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	ci.draw_colored_polygon(rrect_points(r, rad), col)


## Draws rows of characters as pixels; `palette` maps a character to its colour.
static func sprite(ci: CanvasItem, pos: Vector2, rows: Array, palette: Dictionary, cell := Layout.PIXEL) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if palette.has(row[x]):
				ci.draw_rect(Rect2(pos + Vector2(x, y) * cell, Vector2(cell, cell)), palette[row[x]])
