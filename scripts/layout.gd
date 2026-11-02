class_name Layout
## World geometry. The scene is 1600x900; the right 340px belong to the sidebar.
## Top half: two rows of desks. Bottom half: the lounge (couches) on both sides of the corridor.

const OFFICE_W := 1260.0
const WALL_Y := 640.0
const STREET_Y := 660.0
const ROAD_Y := 728.0
const LANE_LINE_Y := 832.0
const TRAFFIC_Y := 868.0
const CORRIDOR_X := 624.0
const DOOR := Vector2(CORRIDOR_X, 648)
const EXIT := Vector2(CORRIDOR_X, 696)
const STREET_ENTRY := Vector2(-40, 696)
const PARTITION_Y := 440.0

const COLS: Array[float] = [188.0, 460.0, 788.0, 1060.0]
const ROWS: Array[float] = [124.0, 304.0]
const DESK_SIZE := Vector2(168, 72)
## World units per game pixel: the whole scene renders on this grid.
const PIXEL := 4.0
const DESK_COUNT := 8
const MAX_TEAM := 6

const LOUNGE_LANE := 528.0
## Couch seats first, then poufs; the mirrored right side follows the left.
const LOUNGE_SEATS: Array[Vector2] = [
	Vector2(112, 572), Vector2(192, 572), Vector2(272, 572), Vector2(432, 572), Vector2(512, 572),
	Vector2(976, 572), Vector2(1056, 572), Vector2(1136, 572), Vector2(736, 572), Vector2(816, 572),
]


static func slot_count() -> int:
	return DESK_COUNT + LOUNGE_SEATS.size()


static func is_lounge(i: int) -> bool:
	return i >= DESK_COUNT


static func desk_center(i: int) -> Vector2:
	return Vector2(COLS[i % COLS.size()], ROWS[i / COLS.size()])


static func seat(i: int) -> Vector2:
	if is_lounge(i):
		return LOUNGE_SEATS[i - DESK_COUNT]
	return desk_center(i) + Vector2(0, 64)


static func lane_y(i: int) -> float:
	return LOUNGE_LANE if is_lounge(i) else desk_center(i).y + 112.0


## Where the subagents of a desk's owner stand: in the gap beside the desk.
static func team_pos(desk: int, k: int) -> Vector2:
	var side := -1.0 if (desk % COLS.size()) % 2 == 0 else 1.0
	return seat(desk) + Vector2(side * (92.0 + (k % 2) * 44.0), -24.0 + (k / 2) * 44.0)


static func to_corridor(i: int) -> PackedVector2Array:
	var s := seat(i)
	var y := lane_y(i)
	return PackedVector2Array([s, Vector2(s.x, y), Vector2(CORRIDOR_X, y)])


## Seat to seat, through the corridor unless both share a lane.
static func route(a: int, b: int) -> PackedVector2Array:
	var y := lane_y(a)
	if is_equal_approx(y, lane_y(b)):
		return PackedVector2Array([seat(a), Vector2(seat(a).x, y), Vector2(seat(b).x, y), seat(b)])
	var out := to_corridor(a)
	var back := to_corridor(b)
	back.reverse()
	out.append_array(back)
	return out


static func route_to_door(a: int) -> PackedVector2Array:
	var out := to_corridor(a)
	out.append(DOOR)
	out.append(EXIT)
	return out


static func route_from_street(b: int, from: Vector2) -> PackedVector2Array:
	var back := to_corridor(b)
	back.reverse()
	var out := PackedVector2Array([from, EXIT, DOOR])
	out.append_array(back)
	return out
