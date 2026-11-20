extends RefCounted

const COLUMNS := 8
const ROWS := 5
const ROCKS := [3, 12, 30, 34]
const MAX_HP := 48
const MAX_QI := 4
const VICTORY := "win"
const DEFEAT := "loss"
const MOVE_RANGE := 2
const MOON_RANGE := 4
const MOON_COST := 2
const STRIKE_DAMAGE := 14
const GUARD_REDUCTION := .7

var turn := 1
var hero := 17
var wolf := 21
var hp := MAX_HP
var wolf_hp := MAX_HP
var qi := MAX_QI
var intent := {}
var result := ""
var rocks: Array = ROCKS
var max_qi := MAX_QI
var wolf_max := MAX_HP
var heavy_name := "Vồ mồi"
var heavy_damage := 12
var bite_damage := 8
var pace := 1
var moon_damage := 26


func _init(options: Dictionary = {}) -> void:
	rocks = options.get("rocks", ROCKS)
	hp = options.get("hp", MAX_HP)
	qi = options.get("qi", MAX_QI)
	max_qi = options.get("max_qi", MAX_QI)
	wolf_max = options.get("wolf_hp", MAX_HP)
	wolf_hp = wolf_max
	heavy_name = options.get("heavy", heavy_name)
	heavy_damage = options.get("damage", heavy_damage)
	bite_damage = options.get("bite", bite_damage)
	pace = options.get("pace", pace)
	moon_damage += int(options.get("moon_bonus", 0))
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


func reach(start: int, budget: int, blocker: int = -1, parents: Dictionary = {}) -> Dictionary:
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
			if candidate != blocker and candidate not in rocks and not walked.has(candidate):
				walked[candidate] = steps + 1
				parents[candidate] = cell
				queue.append(candidate)
	walked.erase(start)
	return walked


func move_targets() -> Array:
	return [] if not result.is_empty() else reach(hero, MOVE_RANGE, wolf).keys()


func forecast() -> void:
	var gap := distance(hero, wolf)
	if (turn - 1) % 2 == 0 and gap <= 5:
		var cells: Array[int] = [hero]
		for cell in neighbors(hero):
			if cell not in rocks:
				cells.append(cell)
		intent = {"kind": "heavy", "name": heavy_name, "cells": cells, "damage": heavy_damage}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
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
			if qi < MOON_COST:
				return "Cần %d chân nguyên để phóng Nguyệt Quang." % MOON_COST
			if distance(hero, wolf) > MOON_RANGE:
				return "Đối thủ ở ngoài tầm %d ô." % MOON_RANGE
		"guard":
			pass
		_:
			return "Hành động không hợp lệ."
	return ""


func wolf_step() -> int:
	var distances := reach(hero, COLUMNS * ROWS)
	var wolf_next := wolf
	var best: int = distances.get(wolf, 1000)
	for cell in reach(wolf, pace, hero):
		var steps: int = distances.get(cell, 1000)
		if steps < best:
			best = steps
			wolf_next = cell
	return wolf_next


func preview_action(action: String, target: int = -1) -> Dictionary:
	var error := unavailable(action)
	if not error.is_empty():
		return {"error": error}
	var steps := 0
	var path: Array[int] = []
	if action == "move":
		var parents := {}
		steps = reach(hero, MOVE_RANGE, wolf, parents).get(target, 0)
		if steps == 0:
			return {"error": "Chọn ô có ký hiệu chỉ đường để di chuyển."}
		var cell := target
		while cell != hero:
			path.push_front(cell)
			cell = parents[cell]
	var position_after := target if action == "move" else hero
	var dealt := 0
	var qi_after := qi
	match action:
		"strike":
			dealt = mini(wolf_hp, STRIKE_DAMAGE)
			qi_after = mini(max_qi, qi + 1)
		"moon":
			dealt = mini(wolf_hp, moon_damage)
			qi_after = qi - MOON_COST
		"guard":
			qi_after = mini(max_qi, qi + 1)
	var receives := 0
	if dealt < wolf_hp and position_after in intent.cells:
		var damage: int = intent.damage
		if action == "guard":
			damage = ceili(damage * (1.0 - GUARD_REDUCTION))
		receives = mini(hp, damage)
	return {"dealt": dealt, "receives": receives, "qi": qi_after, "steps": steps, "path": path}


func take_turn(action: String, target: int = -1) -> Dictionary:
	var preview := preview_action(action, target)
	if preview.has("error"):
		return preview

	var exchange := {"action": action, "hero_from": hero, "wolf_from": wolf,
		"wolf_damage": 0, "hero_damage": 0, "reaction": "", "notes": [], "hero_path": preview.path}
	var notes: Array = exchange.notes
	var previous_qi := qi
	qi = preview.qi
	match action:
		"move":
			hero = target
			notes.append("Bạn di chuyển đến %s." % cell_name(hero))
		"strike", "moon":
			var damage: int = preview.dealt
			wolf_hp -= damage
			exchange.wolf_damage = damage
			var name := "Nguyệt Quang" if action == "moon" else "Tay không"
			notes.append("%s gây %d sát thương." % [name, damage])
		"guard":
			notes.append("Thủ thế và hồi 1 chân nguyên." if qi > previous_qi else "Bạn vào thế thủ.")

	if wolf_hp <= 0:
		result = VICTORY
		notes.append("Đối thủ đã gục.")
	elif intent.kind == "advance":
		wolf = wolf_step()
		if wolf != exchange.wolf_from:
			exchange.reaction = "advance"
			notes.append("Đối thủ áp sát đến %s." % cell_name(wolf))
		else:
			notes.append("Đối thủ giữ vị trí.")
	elif hero in intent.cells:
		var damage: int = preview.receives
		hp -= damage
		exchange.hero_damage = damage
		exchange.reaction = intent.kind
		if action == "guard":
			notes.append("Đỡ %s, còn chịu %d sát thương." % [str(intent.name).to_lower(), damage])
		else:
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
