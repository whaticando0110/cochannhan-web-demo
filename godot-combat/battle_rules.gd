extends RefCounted

const COLUMNS := 8
const ROWS := 5
const ROCKS := [3, 12, 30, 34]
const MAX_HP := 48
const MAX_QI := 4
const VICTORY := "win"
const DEFEAT := "loss"

var turn := 1
var hero := 17
var wolf := 21
var hp := MAX_HP
var wolf_hp := MAX_HP
var qi := MAX_QI
var intent := {}
var result := ""


func _init() -> void:
	forecast()


static func grid(cell: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(cell % COLUMNS, cell / COLUMNS)


static func cell_name(cell: int) -> String:
	var point := grid(cell)
	return "%s%d" % [char(65 + point.x), point.y + 1]


static func distance(a: int, b: int) -> int:
	var offset := (grid(a) - grid(b)).abs()
	return offset.x + offset.y


static func neighbors(cell: int) -> Array[int]:
	var adjacent: Array[int] = []
	for candidate in [cell - COLUMNS, cell - 1, cell + 1, cell + COLUMNS]:
		if candidate >= 0 and candidate < COLUMNS * ROWS and distance(cell, candidate) == 1:
			adjacent.append(candidate)
	return adjacent


func reach(start: int, budget: int, blocker: int = -1) -> Dictionary:
	var walked := {start: 0}
	var queue: Array[int] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		var steps: int = walked[cell]
		if steps >= budget:
			continue
		for candidate in neighbors(cell):
			if candidate != blocker and candidate not in ROCKS and not walked.has(candidate):
				walked[candidate] = steps + 1
				queue.append(candidate)
	walked.erase(start)
	return walked


func move_targets() -> Array:
	return [] if not result.is_empty() else reach(hero, 2, wolf).keys()


func forecast() -> void:
	var gap := distance(hero, wolf)
	if (turn - 1) % 2 == 0 and gap <= 5:
		var cells: Array[int] = [hero]
		for cell in neighbors(hero):
			if cell not in ROCKS:
				cells.append(cell)
		intent = {"kind": "heavy", "name": "Vồ mồi", "cells": cells, "damage": 12}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": 8}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func unavailable(action: String) -> String:
	if not result.is_empty():
		return "Trận đấu đã kết thúc."
	match action:
		"move":
			if move_targets().is_empty():
				return "Không còn ô di chuyển."
		"strike":
			if distance(hero, wolf) != 1:
				return "Tay không cần đứng kề Điện Lang."
		"moon":
			if qi < 2:
				return "Cần 2 chân nguyên để phóng Nguyệt Quang."
			if distance(hero, wolf) > 4:
				return "Điện Lang ở ngoài tầm 4 ô."
		"guard":
			pass
		_:
			return "Hành động không hợp lệ."
	return ""


func wolf_step() -> int:
	var distances := reach(hero, COLUMNS * ROWS)
	var wolf_next := wolf
	var best: int = distances.get(wolf, 1000)
	for cell in reach(wolf, 1, hero):
		var steps: int = distances.get(cell, 1000)
		if steps < best:
			best = steps
			wolf_next = cell
	return wolf_next


func take_turn(action: String, target: int = -1) -> Dictionary:
	var error := unavailable(action)
	if not error.is_empty():
		return {"error": error}
	if action == "move" and target not in move_targets():
		return {"error": "Chọn ô có viền xanh để di chuyển."}

	var exchange := {"action": action, "hero_from": hero, "wolf_from": wolf,
		"wolf_damage": 0, "hero_damage": 0, "reaction": "", "notes": []}
	var notes: Array = exchange.notes
	match action:
		"move":
			hero = target
			notes.append("Bạn di chuyển đến %s." % cell_name(hero))
		"strike", "moon":
			qi = mini(MAX_QI, qi + (1 if action == "strike" else -2))
			var damage := mini(wolf_hp, 14 if action == "strike" else 26)
			wolf_hp -= damage
			exchange.wolf_damage = damage
			var name := "Nguyệt Quang" if action == "moon" else "Tay không"
			notes.append("%s gây %d sát thương." % [name, damage])
		"guard":
			var previous_qi := qi
			qi = mini(MAX_QI, qi + 1)
			notes.append("Thủ thế và hồi 1 chân nguyên." if qi > previous_qi else "Bạn vào thế thủ.")

	if wolf_hp <= 0:
		result = VICTORY
		notes.append("Điện Lang đã gục.")
	elif intent.kind == "advance":
		wolf = wolf_step()
		if wolf != exchange.wolf_from:
			exchange.reaction = "advance"
			notes.append("Điện Lang áp sát đến %s." % cell_name(wolf))
		else:
			notes.append("Điện Lang giữ vị trí.")
	elif hero in intent.cells:
		var damage: int = intent.damage
		if action == "guard":
			damage = ceili(damage * 0.3)
		damage = mini(hp, damage)
		hp -= damage
		exchange.hero_damage = damage
		exchange.reaction = intent.kind
		notes.append("%s trúng bạn, mất %d sinh lực." % [intent.name, damage])
		if hp <= 0:
			result = DEFEAT
	else:
		exchange.reaction = "miss"
		notes.append("Bạn né được %s." % str(intent.name).to_lower())

	if result.is_empty():
		turn += 1
		forecast()
	else:
		intent.clear()
	return exchange
