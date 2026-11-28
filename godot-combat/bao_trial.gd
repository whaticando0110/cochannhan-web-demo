extends RefCounted

const Rules = preload("res://battle_rules.gd")
const BOARD := [
	{"hero": 34, "enemies": [4, 13, 23], "rocks": [9, 12, 18, 22, 28]},
	{"hero": 37, "enemies": [0, 10, 20], "rocks": [5, 13, 18, 25, 31, 36]},
	{"hero": 35, "enemies": [0, 7, 14], "rocks": [9, 12, 19, 21, 26, 29]},
]
const CAST_RANGE := 4
const CAST_COST := 1
const HIT_DAMAGE := 6

var hero: int
var rocks: Array[int] = []
var enemies: Array[int] = []
var hp: int
var qi: int
var capacity: int
var turns := 0
var spent := false
var won := false
var lost := false
var report := "Đàn địch đang áp sát từ bãi đá."


func _init(layout: int, health: int, essence: int, maximum: int) -> void:
	var board: Dictionary = BOARD[layout]
	hero = board.hero
	rocks.assign(board.rocks)
	enemies.assign(board.enemies)
	hp = health
	qi = essence
	capacity = maximum


func walkable(cell: int) -> bool:
	return cell in Rules.neighbors(hero) and cell not in rocks and cell not in enemies


func attackers() -> int:
	var count := 0
	for enemy in enemies:
		if Rules.distance(enemy, hero) == 1:
			count += 1
	return count


func castable(cell: int) -> bool:
	if cell < 0 or cell >= Rules.COLUMNS * Rules.ROWS or spent or qi < CAST_COST or cell in rocks:
		return false
	return Rules.distance(hero, cell) in range(2, CAST_RANGE + 1)


func blast(cell: int) -> Array[int]:
	if not castable(cell):
		return []
	var area := Rules.neighbors(cell)
	area.push_front(cell)
	return area


func targets_hit(area: Array[int]) -> int:
	var count := 0
	for cell in enemies:
		count += int(cell in area)
	return count


func approach() -> Array[int]:
	var order: Array[int] = []
	for cell in enemies:
		var next := cell
		for candidate in Rules.neighbors(cell):
			if candidate != hero and candidate not in rocks and candidate not in enemies and candidate not in order:
				if Rules.distance(candidate, hero) < Rules.distance(cell, hero):
					next = candidate
					break
		order.append(next)
	return order


func apply(action: String, target: int) -> bool:
	if won or lost:
		return false
	match action:
		"bao_cast":
			var area := blast(target)
			if area.is_empty():
				return false
			turns += 1
			qi -= CAST_COST
			spent = true
			enemies.assign(enemies.filter(func(cell: int): return cell not in area))
			won = enemies.is_empty()
			lost = not won
			report = "Cả đàn đã gục trong một lần thi triển." if won else "Cổ đã dùng hết. Còn %d đối thủ trên sân." % enemies.size()
			return true
		"bao_move":
			if not walkable(target):
				return false
		"bao_guard":
			if target != -1:
				return false
		_:
			return false

	var order := approach()
	var damage := attackers() * ceili(HIT_DAMAGE * (1.0 - Rules.GUARD_REDUCTION)) if action == "bao_guard" else 0
	turns += 1
	if action == "bao_move":
		hero = target
	else:
		qi = mini(capacity, qi + 1)
	for index in range(order.size()):
		if order[index] != hero:
			enemies[index] = order[index]
	hp = maxi(0, hp - damage)
	lost = hp == 0
	report = "Đã chịu %d sát thương khi Thủ thế." % damage if damage > 0 else "Đàn địch áp sát thêm."
	return true
