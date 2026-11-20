extends RefCounted

const Gu = preload("res://gu_catalog.gd")

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
var moon_equipped := true
var refined_gu := ""
var build_family := ""
var moon_mark := false
var ward_strength := 0
var counter_ready := false
var starter_gu := ""
var revised_ward := false
var water: Array = []
var brew_left := 0
var brew_ready := false
var strong_strikes := 0


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
	wolf = options.get("wolf_cell", wolf)
	moon_equipped = options.get("moon_equipped", true)
	refined_gu = options.get("refined_gu", "")
	var starter := "moon" if moon_equipped else "jade_skin" if jade_skin else ""
	starter_gu = options.get("starter_gu", starter)
	if starter_gu.is_empty():
		starter_gu = starter
	build_family = Gu.build_family(refined_gu, starter_gu)
	revised_ward = options.get("revised_ward", false)
	water = options.get("water", [])
	brew_left = Gu.BREW_CHARGES if starter_gu == "brew" else 0
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
	elif tactic == "ford" and heavy_turn and heavy_count % 2 == 0:
		intent = {"kind": "flood", "name": "Dẫn lôi qua nước", "cells": water, "damage": heavy_damage, "pattern": "water"}
	elif tactic in ["storm", "ford"] and heavy_turn and gap <= Gu.MOON_EDGE_RANGE and ray_blocker(wolf, hero) < 0:
		intent = {"kind": "shot", "name": "Hồ quang", "cells": [hero], "damage": heavy_damage, "pattern": "bolt"}
	elif tactic not in ["storm", "ford"] and heavy_turn and gap <= 5:
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


func uses_cover() -> bool:
	return tactic in ["ravine", "storm", "ford"]


func white_jade_absorb() -> int:
	return Gu.WHITE_JADE_REVISED_ABSORB if revised_ward else Gu.WHITE_JADE_ABSORB


func white_jade_cost() -> int:
	return Gu.WHITE_JADE_COST - int(revised_ward and can_upgrade_ward())


func can_upgrade_ward() -> bool:
	return build_family == "ward" and jade_turns > 0 and ward_strength == JADE_ABSORB


func counter_bonus() -> int:
	return Gu.REVISED_COUNTER_BONUS if revised_ward else Gu.WARD_COUNTER_BONUS


func shot_unavailable(action: String, cost: int, attack_range: int) -> String:
	if qi < cost:
		return "Cần %d chân nguyên để phóng %s." % [cost, Gu.GU[action].name]
	if distance(hero, wolf) > attack_range:
		return "Đối thủ ở ngoài tầm %d ô." % attack_range
	if uses_cover():
		var cover := ray_blocker(hero, wolf)
		if cover >= 0:
			return "Vách đá ở %s chặn %s." % [cell_name(cover), Gu.GU[action].name]
	return ""


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
			if not moon_equipped:
				return "Nguyệt Quang Cổ chưa được trang bị."
			return shot_unavailable(action, MOON_COST, MOON_RANGE)
		"moon_edge":
			if refined_gu != action:
				return "Nguyệt Mang Cổ chưa được trang bị."
			return shot_unavailable(action, Gu.MOON_EDGE_COST, Gu.MOON_EDGE_RANGE)
		"guard":
			pass
		"jade_skin":
			if not jade_skin:
				return "Bạn chưa có Ngọc Bì Cổ."
			if jade_turns > 0:
				return "Lớp ngọc vẫn còn hiệu lực."
			if qi < JADE_COST:
				return "Cần %d chân nguyên để dùng Ngọc Bì Cổ." % JADE_COST
		"white_jade":
			if refined_gu != action:
				return "Bạch Ngọc Cổ chưa được trang bị."
			if jade_turns > 0 and ward_strength >= white_jade_absorb():
				return "Lớp Bạch Ngọc vẫn còn hiệu lực."
			if qi < white_jade_cost():
				return "Cần %d chân nguyên để dùng Bạch Ngọc Cổ." % white_jade_cost()
		"brew":
			if starter_gu != action:
				return "Tửu Trùng chưa được trang bị."
			if brew_left <= 0:
				return "Tửu Trùng đã dùng hết lượt trong trận."
			if qi >= max_qi:
				return "Chân nguyên đang đầy."
		"four_flavors":
			if refined_gu != action:
				return "Tứ Vị Tửu Trùng chưa được trang bị."
			if strong_strikes > 0:
				return "Cú Tay không vẫn đang được cường hóa."
			if qi < Gu.FOUR_FLAVORS_COST:
				return "Cần %d chân nguyên để dùng Tứ Vị Tửu Trùng." % Gu.FOUR_FLAVORS_COST
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
	var protection := ward_strength
	var mark := moon_mark
	var counter := counter_ready
	var brew_setup := brew_ready
	var boosted := strong_strikes
	var set_trigger := false
	match action:
		"strike":
			set_trigger = counter_ready or boosted > 0
			var bonus := counter_bonus() if counter_ready else Gu.BREW_STRIKE_BONUS if boosted > 0 else 0
			dealt = mini(wolf_hp, STRIKE_DAMAGE + bonus)
			boosted = maxi(0, boosted - 1)
			counter = false
			qi_after = mini(max_qi, qi + 1)
		"moon":
			dealt = mini(wolf_hp, moon_damage)
			qi_after = qi - MOON_COST
			mark = build_family == "lunar" and dealt < wolf_hp
		"moon_edge":
			set_trigger = mark
			dealt = mini(wolf_hp, Gu.MOON_EDGE_DAMAGE + (Gu.MOON_MARK_BONUS if set_trigger else 0))
			qi_after = qi - Gu.MOON_EDGE_COST
			mark = false
		"guard":
			qi_after = mini(max_qi, qi + 1)
		"jade_skin":
			qi_after -= JADE_COST
			ward = JADE_TURNS
			protection = JADE_ABSORB
		"white_jade":
			set_trigger = can_upgrade_ward()
			qi_after -= white_jade_cost()
			ward = Gu.WHITE_JADE_TURNS
			protection = white_jade_absorb() + (Gu.WHITE_JADE_BONUS if set_trigger else 0)
		"brew":
			qi_after = mini(max_qi, qi + Gu.BREW_QI)
			brew_setup = build_family == "brew"
		"four_flavors":
			set_trigger = brew_ready
			qi_after -= Gu.FOUR_FLAVORS_COST
			boosted = 2 if set_trigger else 1
			brew_setup = false
		"vital_leaf":
			healed = mini(LEAF_HEAL, MAX_HP - hp)
	var receives := 0
	var absorbed := 0
	if dealt < wolf_hp and position_after in intent.cells:
		var damage: int = intent.damage
		if action == "guard":
			damage = ceili(damage * (1.0 - GUARD_REDUCTION))
		if ward > 0:
			absorbed = mini(protection, damage)
			ward = 0
			if absorbed > 0 and build_family == "ward" and protection >= white_jade_absorb():
				counter = true
		receives = mini(hp + healed, damage - absorbed)
	return {"dealt": dealt, "receives": receives, "qi": qi_after, "steps": steps, "path": path,
		"healed": healed, "absorbed": absorbed, "jade_turns": maxi(0, ward - 1) if dealt < wolf_hp else 0,
		"ward_strength": protection, "moon_mark": mark and dealt < wolf_hp, "set_trigger": set_trigger,
		"counter_ready": counter and dealt < wolf_hp, "brew_ready": brew_setup, "strong_strikes": boosted}


func take_turn(action: String, target: int = -1) -> Dictionary:
	var preview := preview_action(action, target)
	if preview.has("error"):
		return preview

	var exchange := {"action": action, "hero_from": hero, "wolf_from": wolf,
		"wolf_damage": 0, "hero_damage": 0, "reaction": "", "notes": [], "hero_path": preview.path,
		"healed": preview.healed, "absorbed": preview.absorbed, "enemy_intent": intent, "set_trigger": preview.set_trigger}
	var notes: Array = exchange.notes
	var previous_qi := qi
	qi = preview.qi
	jade_turns = preview.jade_turns
	ward_strength = preview.ward_strength if jade_turns > 0 else 0
	var had_mark := moon_mark
	moon_mark = preview.moon_mark
	var had_counter := counter_ready
	counter_ready = preview.counter_ready
	brew_ready = preview.brew_ready
	strong_strikes = preview.strong_strikes
	match action:
		"move":
			hero = target
			notes.append("Bạn di chuyển đến %s." % cell_name(hero))
		"strike", "moon", "moon_edge":
			var damage: int = preview.dealt
			wolf_hp -= damage
			exchange.wolf_damage = damage
			var name: String = Gu.GU[action].name if Gu.GU.has(action) else "Tay không"
			notes.append("%s gây %d sát thương." % [name, damage])
			if action == "moon_edge" and preview.set_trigger:
				notes.append("Nguyệt Mang kích phát Nguyệt Ấn.")
			elif action == "strike" and preview.set_trigger:
				notes.append("Bạn dùng thế Phản đòn." if had_counter else "Đòn tay không được tinh nguyên cường hóa.")
			elif moon_mark and not had_mark:
				notes.append("Nguyệt Ấn bám trên đối thủ.")
		"guard":
			notes.append("Thủ thế và hồi 1 chân nguyên." if qi > previous_qi else "Bạn vào thế thủ.")
		"jade_skin":
			notes.append("Ngọc Bì Cổ tạo một lớp bảo hộ.")
		"white_jade":
			notes.append("Bạch Ngọc tạo lớp chặn %d sát thương." % preview.ward_strength)
		"brew":
			brew_left -= 1
			notes.append("Tửu Trùng hồi %d chân nguyên." % (qi - previous_qi))
		"four_flavors":
			notes.append("Tứ Vị cường hóa %d cú Tay không." % strong_strikes)
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
		if counter_ready and (not had_counter or action == "strike"):
			notes.append("Phản đòn đã sẵn sàng.")
		if hp <= 0:
			result = DEFEAT
	else:
		exchange.reaction = "miss"
		notes.append("Bạn đứng ngoài vùng nước nhiễm điện." if intent.kind == "flood" else "Bạn né được %s." % str(intent.name).to_lower())

	if result.is_empty():
		if intent.kind in ["heavy", "shot", "flood"]:
			heavy_count += 1
		recovering = (intent.kind == "heavy" and tactic == "king") or intent.kind in ["shot", "flood"]
		turn += 1
		forecast()
	else:
		intent = {}
		jade_turns = 0
		ward_strength = 0
		moon_mark = false
		counter_ready = false
		brew_ready = false
		strong_strikes = 0
	return exchange
