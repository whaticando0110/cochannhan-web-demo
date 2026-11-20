extends RefCounted

const WIDTH := 57
const HEIGHT := 9
const BANK := 6
const HOPE := [Vector2i(8, 4), Vector2i(14, 3), Vector2i(20, 3), Vector2i(26, 4),
	Vector2i(32, 5), Vector2i(38, 5), Vector2i(44, 4)]

var position := Vector2i(1, 4)
var depth := 0
var limit: int
var gathered: Array[Vector2i] = []


func _init(fixed_limit: int = 0) -> void:
	if fixed_limit >= 12 and fixed_limit <= 49:
		limit = fixed_limit
	else:
		var roll := randf()
		if roll < .18:
			limit = randi_range(12, 19)
		elif roll < .56:
			limit = randi_range(21, 29)
		elif roll < .84:
			limit = randi_range(31, 39)
		else:
			limit = randi_range(41, 49)


static func terrain(point: Vector2i) -> String:
	if point.x < 0 or point.x > 55 or point.y < 2 or point.y > 6:
		return "rock"
	if point.x >= 3 and point.x <= 5:
		return "ford" if point.y == 4 else "water"
	return "garden" if point.x >= BANK else "bank"


static func walkable(point: Vector2i) -> bool:
	return terrain(point) not in ["rock", "water"]


static func profile_for(hero: String, steps: int) -> Dictionary:
	if hero not in ["huyen-bao", "ao-reu"] or steps < 12 or steps > 49:
		return {}
	@warning_ignore("integer_division")
	var tier := steps / 10 - 1
	var percent := roundi(20 + 20 * tier + (steps - (tier + 1) * 10) * 17.0 / 9.0)
	return {"hero": hero, "depth": steps, "grade": ["Đinh đẳng", "Bính đẳng", "Ất đẳng", "Giáp đẳng"][tier],
		"sea_pct": percent, "max_qi": 4 + tier}


func finished() -> bool:
	return depth >= limit


func step(target: Vector2i) -> bool:
	var gap := (position - target).abs()
	if finished() or gap.x + gap.y != 1 or not walkable(target):
		return false
	position = target
	depth = maxi(depth, target.x - BANK)
	if target in HOPE and target not in gathered:
		gathered.append(target)
	return true


func seconds() -> float:
	var remaining := limit - depth
	if depth == 0 or remaining > 4:
		return .145
	return [.86, .62, .44, .31, .22][remaining]


func path_to(target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(target) or finished():
		return result
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, WIDTH, HEIGHT)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell := Vector2i(x, y)
			grid.set_point_solid(cell, not walkable(cell))
	result.assign(grid.get_id_path(position, target).slice(1))
	return result
