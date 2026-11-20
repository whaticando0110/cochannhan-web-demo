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
const JADE_COST := 1
const JADE_ABSORB := 5
const JADE_TURNS := 2
const LEAF_HEAL := 12

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
var jade_skin := false
var jade_turns := 0
var leaves := 0
var tactic := ""
var heavy_count := 0
var recovering := false


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
	jade_skin = options.get("jade_skin", false)
	leaves = options.get("leaves", 0)
	tactic = options.get("tactic", "")
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


func ray_blocker(from: int, to: int) -> int:
	var point := grid(from)
	var end := grid(to)
	var delta := end - point
	var step := delta.sign()
	var span := delta.abs()
	var crossed := Vector2i.ZERO
	# Exact corner crossings enter the diagonal cell. Grazing a corner does not hit it.
	while point != end:
		var decision := (2 * crossed.x + 1) * span.y - (2 * crossed.y + 1) * span.x
		if decision <= 0:
			point.x += step.x
			crossed.x += 1
		if decision >= 0:
			point.y += step.y
			crossed.y += 1
		var cell := point.y * COLUMNS + point.x
		if point != end and cell in rocks:
			return cell
	return -1


func forecast() -> void:
	var gap := distance(hero, wolf)
	var enraged := enraged_phase()
	var heavy_turn := (turn - 1) % 2 == 0 or enraged
	if recovering:
		intent = {"kind": "recover", "name": "Hồi thế", "cells": [], "damage": 0}
	elif heavy_turn and gap <= 5:
		var is_charge := (tactic == "elite" and heavy_count % 2 == 1) or (
			tactic == "king" and (heavy_count % 2 == 0) == enraged)
		if is_charge:
			var cells: Array[int] = []
			var row := grid(hero).y
			for column in range(COLUMNS):
				var cell := row * COLUMNS + column
				if cell not in rocks:
					cells.append(cell)
			intent = {"kind": "heavy", "name": "Quét hành lang" if tactic == "king" else "Lao xuyên hàng",
				"cells": cells, "damage": heavy_damage, "pattern": "row", "row": row,
				"direction": 1 if grid(wolf).x <= grid(hero).x else -1}
			return
		var cells: Array[int] = [hero]
		for cell in neighbors(hero):
			if cell not in rocks:
				cells.append(cell)
		intent = {"kind": "heavy", "name": heavy_name, "cells": cells, "damage": heavy_damage}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func enraged_phase() -> bool:
	return tactic == "king" and wolf_hp * 2 < wolf_max


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
			if tactic == "ravine":
				var cover := ray_blocker(hero, wolf)
				if cover >= 0:
					return "Vách đá ở %s chặn Nguyệt Quang." % cell_name(cover)
		"guard":
			pass
		"jade_skin":
			if not jade_skin:
				return "Bạn chưa có Ngọc Bì Cổ."
			if jade_turns > 0:
				return "Lớp ngọc vẫn còn hiệu lực."
			if qi < JADE_COST:
				return "Cần %d chân nguyên để dùng Ngọc Bì Cổ." % JADE_COST
		"vital_leaf":
			if leaves <= 0:
				return "Đã hết Sinh Cơ Diệp."
			if hp >= MAX_HP:
				return "Sinh lực đang đầy."
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
	var healed := 0
	var ward := jade_turns
	match action:
		"strike":
			dealt = mini(wolf_hp, STRIKE_DAMAGE)
			qi_after = mini(max_qi, qi + 1)
		"moon":
			dealt = mini(wolf_hp, moon_damage)
			qi_after = qi - MOON_COST
		"guard":
			qi_after = mini(max_qi, qi + 1)
		"jade_skin":
			qi_after -= JADE_COST
			ward = JADE_TURNS
		"vital_leaf":
			healed = mini(LEAF_HEAL, MAX_HP - hp)
	var receives := 0
	var absorbed := 0
	if dealt < wolf_hp and position_after in intent.cells:
		var damage: int = intent.damage
		if action == "guard":
			damage = ceili(damage * (1.0 - GUARD_REDUCTION))
		if ward > 0:
			absorbed = mini(JADE_ABSORB, damage)
			ward = 0
		receives = mini(hp + healed, damage - absorbed)
	return {"dealt": dealt, "receives": receives, "qi": qi_after, "steps": steps, "path": path,
		"healed": healed, "absorbed": absorbed, "jade_turns": maxi(0, ward - 1) if dealt < wolf_hp else 0}


func take_turn(action: String, target: int = -1) -> Dictionary:
	var preview := preview_action(action, target)
	if preview.has("error"):
		return preview

	var exchange := {"action": action, "hero_from": hero, "wolf_from": wolf,
		"wolf_damage": 0, "hero_damage": 0, "reaction": "", "notes": [], "hero_path": preview.path,
		"healed": preview.healed, "absorbed": preview.absorbed, "enemy_intent": intent}
	var notes: Array = exchange.notes
	var previous_qi := qi
	qi = preview.qi
	jade_turns = preview.jade_turns
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
		"jade_skin":
			notes.append("Ngọc Bì Cổ tạo một lớp bảo hộ.")
		"vital_leaf":
			leaves -= 1
			hp += int(preview.healed)
			notes.append("Sinh Cơ Diệp hồi %d sinh lực." % preview.healed)

	if wolf_hp <= 0:
		result = VICTORY
		notes.append("Đối thủ đã gục.")
	elif intent.kind == "recover":
		notes.append("Đối thủ hồi thế. Bạn có một lượt an toàn.")
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
		if preview.absorbed > 0:
			notes.append("Lớp ngọc chặn %d sát thương." % preview.absorbed)
		if hp <= 0:
			result = DEFEAT
	else:
		exchange.reaction = "miss"
		notes.append("Bạn né được %s." % str(intent.name).to_lower())

	if result.is_empty():
		if intent.kind == "heavy":
			heavy_count += 1
		recovering = intent.kind == "heavy" and tactic == "king"
		turn += 1
		forecast()
	else:
		intent = {}
		jade_turns = 0
	return exchange
