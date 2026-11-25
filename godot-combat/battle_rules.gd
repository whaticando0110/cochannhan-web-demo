extends RefCounted

const Gu = preload("res://gu_catalog.gd")
const Goods = preload("res://waypoint_goods.gd")

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
const THUNDER_CROSS_BONUS := 4
const THUNDER_OPEN_BONUS := 5
const MARSH_LUNGE_DAMAGE := 16
const MARSH_JAW_BONUS := 6
const ALTAR_ARMOR := 8
const ALTAR_BREAK_TURNS := 5
const ALTAR_OPEN_STRIKE := 4
const PULSE_ENRAGE_DAMAGE := 3
const PULSE_OPEN_BONUS := 5
const HOUND_FRONT_ARMOR := 7
const HOUND_FLANK_STRIKE := 4
const NODO_HOUND_RANGE := 5
const BIND_COST := 1
const BIND_RANGE := 2

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
var moon_link_equipped := false
var moon_link_used := false
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
var cracks: Array = []
var steps_bonus := 0
var veil_turns := 0
var relic := ""
var relic_ready := false
var strike_bonus := 0
var runes: Array = []
var seal_turns := 0
var pulse_open := false
var hound_facing := -1
var hound_cell := -1
var hound_hp := 0
var hound_max := 0
var hound_mark := false
var ordered_cell := -1


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
	hound_cell = options.get("hound_cell", -1)
	hound_max = options.get("hound_hp", 0)
	hound_hp = hound_max
	moon_equipped = options.get("moon_equipped", true)
	refined_gu = options.get("refined_gu", "")
	moon_link_equipped = refined_gu == "moon_edge" and options.get("moon_link", false)
	var starter := "moon" if moon_equipped else "jade_skin" if jade_skin else ""
	starter_gu = options.get("starter_gu", starter)
	if starter_gu.is_empty():
		starter_gu = starter
	build_family = Gu.build_family(refined_gu, starter_gu)
	revised_ward = options.get("revised_ward", false)
	water = options.get("water", [])
	cracks = options.get("cracks", [])
	runes = options.get("runes", [])
	strike_bonus = options.get("strike_bonus", 0)
	brew_left = Gu.BREW_CHARGES if starter_gu == "brew" else 0
	relic = options.get("relic", "")
	relic_ready = relic in ["reed_boots", "jade_token", "elite_fang", "wind_seal", "pulse_pearl", "iron_hide"]
	if relic == "essence_pin":
		qi = mini(max_qi, qi + 1)
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


func reach(start: int, budget: int, blocker: int = -1, parents: Dictionary = {}, other: int = -1,
		occupied: Array = []) -> Dictionary:
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
			if candidate != blocker and candidate != other and candidate not in rocks and candidate not in occupied and not walked.has(candidate):
				walked[candidate] = steps + 1
				parents[candidate] = cell
				queue.append(candidate)
	walked.erase(start)
	return walked


func move_targets() -> Array:
	return [] if not result.is_empty() else reach(hero, movement_range(), wolf, {}, live_hound()).keys()


func movement_range() -> int:
	return MOVE_RANGE + steps_bonus + int(relic_ready and relic == "reed_boots")


func can_extend_veil() -> bool:
	return build_family == "veil" and steps_bonus == 1


func scale_veil_cost() -> int:
	return Gu.SCALE_VEIL_COST - int(can_extend_veil())


func live_hound() -> int:
	return hound_cell if hound_hp > 0 else -1


func attack_cell(target: int = -1) -> int:
	return wolf if tactic != "nodo" or target == -1 else target


func shot_blocker(target: int) -> int:
	var other := wolf if target == live_hound() else live_hound()
	return ray_blocker(hero, target, other)


func ray_blocker(from: int, to: int, other: int = -1) -> int:
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
		if point != end and (cell in rocks or cell == other):
			return cell
	return -1


func forecast() -> void:
	var gap := distance(hero, wolf)
	var ranged := tactic in ["storm", "ford", "ambush"]
	var enraged := enraged_phase()
	var heavy_turn := (turn - 1) % 2 == 0 or enraged
	if recovering:
		var name := "Hở lôi giáp" if tactic == "thunder_boss" else "Hồi thế"
		if tactic == "marsh":
			name = "Hở hàm"
		elif pulse_open:
			name = "Hở mạch"
		intent = {"kind": "recover", "name": name, "cells": [], "damage": 0}
	elif tactic == "thunder_boss" and gap <= 5:
		forecast_thunder()
	elif tactic == "marsh":
		forecast_marsh(gap)
	elif tactic == "wind_pass":
		forecast_wind_pass(gap)
	elif tactic == "seal_altar":
		forecast_altar(gap)
	elif tactic == "pulse_boss":
		forecast_pulse()
	elif tactic == "armored_hound":
		forecast_hound(gap)
	elif tactic == "nodo":
		forecast_nodo(gap)
	elif tactic == "kennel":
		if gap == 1:
			intent = {"kind": "strike", "name": "Chó hoang táp", "cells": [hero], "damage": bite_damage}
		else:
			intent = {"kind": "advance", "name": "Chó hoang áp sát", "cells": [], "damage": 0}
	elif tactic == "ford" and heavy_turn and heavy_count % 2 == 0:
		intent = {"kind": "flood", "name": "Dẫn lôi qua nước", "cells": water, "damage": heavy_damage, "pattern": "water"}
	elif tactic == "ambush" and heavy_turn and heavy_count % 2 == 1:
		intent = {"kind": "fall", "name": "Đá rơi", "cells": cracks, "damage": heavy_damage + 3, "pattern": "rubble"}
	elif ranged and heavy_turn and gap <= (5 if tactic == "ambush" else Gu.MOON_EDGE_RANGE) and ray_blocker(wolf, hero) < 0:
		if tactic == "ambush":
			intent = {"kind": "ambush", "name": "Vồ phục kích", "cells": cells_around_hero(), "damage": heavy_damage}
		else:
			intent = {"kind": "shot", "name": "Hồ quang", "cells": [hero], "damage": heavy_damage, "pattern": "bolt"}
	elif not ranged and heavy_turn and gap <= 5:
		var is_charge := (tactic in ["elite", "den"] and heavy_count % 2 == 1) or (
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
		intent = {"kind": "heavy", "name": heavy_name, "cells": cells_around_hero(), "damage": heavy_damage}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func enraged_phase() -> bool:
	return tactic == "king" and wolf_hp * 2 < wolf_max


func forecast_pulse() -> void:
	var enraged := wolf_hp * 2 <= wolf_max
	var radius := 3 if enraged else 2
	var inner := heavy_count % 2 == 0
	var cells: Array[int] = []
	for cell in range(COLUMNS * ROWS):
		if cell not in rocks and (distance(cell, wolf) <= radius) == inner:
			cells.append(cell)
	intent = {"kind": "core_wave", "pattern": "core_wave", "name": heavy_name if inner else "Ngoại Chấn",
		"cells": cells, "damage": heavy_damage + (PULSE_ENRAGE_DAMAGE if enraged else 0),
		"inner": inner, "radius": radius}


func forecast_hound(gap: int) -> void:
	if turn % 3 == 1:
		var origin := grid(wolf)
		var direction := signi(grid(hero).x - origin.x)
		if direction != 0:
			hound_facing = direction
		var cells: Array[int] = []
		var column := origin.x + hound_facing
		while column >= 0 and column < COLUMNS:
			var cell := origin.y * COLUMNS + column
			if cell in rocks:
				break
			cells.append(cell)
			column += hound_facing
		if not cells.is_empty():
			intent = {"kind": "heavy", "name": heavy_name, "cells": cells,
				"damage": heavy_damage, "pattern": "hound_rush"}
			return
	if gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func forecast_nodo(gap: int) -> void:
	if live_hound() >= 0 and ordered_cell >= 0:
		if distance(hound_cell, ordered_cell) <= NODO_HOUND_RANGE and ray_blocker(hound_cell, ordered_cell, wolf) < 0:
			intent = {"kind": "nodo_hound", "name": "Khuyển thú vồ", "cells": [ordered_cell],
				"damage": heavy_damage, "pattern": "hound_rush"}
		else:
			intent = {"kind": "nodo_hound_advance", "name": "Khuyển thú áp sát", "cells": [],
				"damage": 0, "destination": enemy_step(hound_cell, 1, wolf)}
	elif live_hound() >= 0 and (turn - 1) % 3 == 0:
		intent = {"kind": "nodo_command", "name": "Ra lệnh khuyển thú", "cells": [], "damage": 0}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cổ sư đánh tay không", "cells": [hero], "damage": bite_damage}
	elif gap <= Gu.MOON_EDGE_RANGE and ray_blocker(wolf, hero, live_hound()) < 0:
		intent = {"kind": "nodo_shot", "name": "Cổ sư phóng Cổ", "cells": [hero], "damage": bite_damage, "pattern": "bolt"}
	else:
		intent = {"kind": "advance", "name": "Cổ sư áp sát", "cells": [], "damage": 0}


func hound_guards(from: int) -> bool:
	return tactic == "armored_hound" and signi(grid(from).x - grid(wolf).x) == hound_facing


func forecast_altar(gap: int) -> void:
	if turn % 3 == 1:
		var cells: Array[int] = []
		var center := grid(hero)
		for cell in range(COLUMNS * ROWS):
			var offset := (grid(cell) - center).abs()
			if offset.x <= 1 and offset.y <= 1 and cell not in rocks:
				cells.append(cell)
		intent = {"kind": "seal_burst", "name": heavy_name, "cells": cells, "damage": heavy_damage, "pattern": "seal_burst"}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func forecast_thunder() -> void:
	var cross := wolf_hp * 2 <= wolf_max
	var target := grid(hero)
	var cells: Array[int] = []
	for cell in range(COLUMNS * ROWS):
		var point := grid(cell)
		if cell not in rocks and (point.y == target.y or (cross and point.x == target.x)):
			cells.append(cell)
	intent = {"kind": "thunder", "name": "Lôi chữ thập" if cross else heavy_name,
		"cells": cells, "damage": heavy_damage + (THUNDER_CROSS_BONUS if cross else 0),
		"pattern": "thunder", "cross": cross}


func forecast_marsh(gap: int) -> void:
	if turn % 3 == 1:
		@warning_ignore("integer_division")
		var left := ((turn - 1) / 3) % 2 == 0
		var cells := water.filter(func(cell: int) -> bool: return (grid(cell).x < COLUMNS / 2.0) == left)
		intent = {"kind": "poison", "name": heavy_name, "cells": cells, "damage": heavy_damage, "pattern": "poison"}
	elif turn % 3 == 2 and gap <= 4 and ray_blocker(wolf, hero) < 0:
		intent = {"kind": "ambush", "name": "Táp độc", "cells": [hero], "damage": MARSH_LUNGE_DAMAGE}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func forecast_wind_pass(gap: int) -> void:
	if turn % 3 == 1:
		@warning_ignore("integer_division")
		var from_west := ((turn - 1) / 3) % 2 == 0
		var cells: Array[int] = []
		for row in range(ROWS):
			for step in range(COLUMNS):
				var column := step if from_west else COLUMNS - 1 - step
				var cell := row * COLUMNS + column
				if cell in rocks:
					break
				cells.append(cell)
		intent = {"kind": "wind", "pattern": "wind", "name": heavy_name, "cells": cells,
			"damage": heavy_damage, "direction": 1 if from_west else -1}
	elif turn % 3 == 2 and gap <= 4 and ray_blocker(wolf, hero) < 0:
		intent = {"kind": "ambush", "name": "Vồ qua gió", "cells": [hero], "damage": heavy_damage - 2}
	elif gap == 1:
		intent = {"kind": "strike", "name": "Cắn xé", "cells": [hero], "damage": bite_damage}
	else:
		intent = {"kind": "advance", "name": "Áp sát", "cells": [], "damage": 0}


func cells_around_hero() -> Array[int]:
	var cells: Array[int] = [hero]
	for cell in neighbors(hero):
		if cell not in rocks:
			cells.append(cell)
	return cells


func uses_cover() -> bool:
	return tactic in ["ravine", "storm", "ford", "ambush", "den", "thunder_boss", "marsh", "wind_pass", "seal_altar", "pulse_boss", "armored_hound", "nodo", "kennel"]


func aim_can_be_lost() -> bool:
	return intent.kind in ["shot", "ambush", "strike", "nodo_shot"]


func white_jade_absorb() -> int:
	return Gu.WHITE_JADE_REVISED_ABSORB if revised_ward else Gu.WHITE_JADE_ABSORB


func white_jade_cost() -> int:
	return Gu.WHITE_JADE_COST - int(revised_ward and can_upgrade_ward())


func can_upgrade_ward() -> bool:
	return build_family == "ward" and jade_turns > 0 and ward_strength == JADE_ABSORB


func counter_bonus() -> int:
	return Gu.REVISED_COUNTER_BONUS if revised_ward else Gu.WARD_COUNTER_BONUS


func shot_unavailable(action: String, cost: int, attack_range: int, target: int) -> String:
	if qi < cost:
		return "Cần %d chân nguyên để phóng %s." % [cost, Gu.GU[action].name]
	if distance(hero, target) > attack_range:
		return "Đối thủ ở ngoài tầm %d ô." % attack_range
	if uses_cover():
		var cover := shot_blocker(target)
		if cover >= 0 and (cover == live_hound() or cover == wolf):
			return "Đối thủ ở %s chắn đường phóng." % cell_name(cover)
		if cover >= 0:
			return "Vách đá ở %s chặn %s." % [cell_name(cover), Gu.GU[action].name]
	return ""


func unavailable(action: String, target: int = -1) -> String:
	if not result.is_empty():
		return "Trận đấu đã kết thúc."
	if action == "bind_hound":
		if tactic != "kennel":
			return "Không có Ngự Khuyển Cổ cho trận này."
		if target not in [-1, wolf]:
			return "Chọn đúng ô của chó hoang."
		if qi < BIND_COST:
			return "Cần %d chân nguyên để thôi động Ngự Khuyển." % BIND_COST
		if distance(hero, wolf) > BIND_RANGE:
			return "Chó hoang ở ngoài tầm %d ô." % BIND_RANGE
		var cover := ray_blocker(hero, wolf)
		return "Tảng đá ở %s chắn đường thu phục." % cell_name(cover) if cover >= 0 else ""
	if tactic == "kennel" and action not in ["move", "guard"]:
		return "Phúc địa đang phong cấm bộ Cổ và đòn đánh của cổ sư."
	var aim := attack_cell(target)
	if action in ["strike", "moon", "moon_edge", "moon_link"] and aim != wolf and (aim < 0 or aim != live_hound()):
		return "Chọn một đối thủ còn trên sân."
	match action:
		"move":
			if move_targets().is_empty():
				return "Không còn ô di chuyển."
		"strike":
			if distance(hero, aim) != 1:
				return "Tay không cần đứng kề đối thủ."
		"moon":
			if not moon_equipped:
				return "Nguyệt Quang Cổ chưa được trang bị."
			return shot_unavailable(action, MOON_COST, MOON_RANGE, aim)
		"moon_edge":
			if refined_gu != action:
				return "Nguyệt Mang Cổ chưa được trang bị."
			return shot_unavailable(action, Gu.MOON_EDGE_COST, Gu.MOON_EDGE_RANGE, aim)
		"moon_link":
			if not moon_link_equipped:
				return "Cần hợp thành Liên Nguyệt và mang Nguyệt Mang."
			if moon_link_used:
				return "Liên Nguyệt đã dùng trong trận này."
			return shot_unavailable(action, Gu.MOON_LINK_COST, Gu.MOON_LINK_RANGE, aim)
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
		"stone_veil":
			if starter_gu != action:
				return "Ẩn Thạch Cổ chưa được trang bị."
			if steps_bonus > 0:
				return "Bước ẩn đang được chuẩn bị."
			if qi < Gu.STONE_VEIL_COST:
				return "Cần %d chân nguyên để dùng Ẩn Thạch Cổ." % Gu.STONE_VEIL_COST
		"scale_veil":
			if refined_gu != action:
				return "Ẩn Lân Cổ chưa được trang bị."
			if veil_turns > 0:
				return "Ẩn Lân vẫn còn hiệu lực."
			if qi < scale_veil_cost():
				return "Cần %d chân nguyên để dùng Ẩn Lân Cổ." % scale_veil_cost()
		"vital_leaf":
			if leaves <= 0:
				return "Đã hết Sinh Cơ Diệp."
			if hp >= MAX_HP:
				return "Sinh lực đang đầy."
		_:
			return "Hành động không hợp lệ."
	return ""


func enemy_step(start: int, speed: int, other: int = -1) -> int:
	var distances := reach(hero, COLUMNS * ROWS, other)
	var destination := start
	var best: int = distances.get(start, 1000)
	for cell in reach(start, speed, hero, {}, other):
		var steps: int = distances.get(cell, 1000)
		if steps < best:
			best = steps
			destination = cell
	return destination


func preview_action(action: String, target: int = -1) -> Dictionary:
	var error := unavailable(action, target)
	if not error.is_empty():
		return {"error": error}
	var steps := 0
	var path: Array[int] = []
	if action == "move":
		var parents := {}
		steps = reach(hero, movement_range(), wolf, parents, live_hound()).get(target, 0)
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
	var attack := action in ["strike", "moon", "moon_edge", "moon_link"]
	var aim := attack_cell(target) if attack else wolf
	var hits_hound := attack and aim != wolf
	var defender_hp := hound_hp if hits_hound else wolf_hp
	var mark := hound_mark if hits_hound else moon_mark
	var counter := counter_ready
	var brew_setup := brew_ready
	var boosted := strong_strikes
	var extra_steps := steps_bonus
	var concealment := veil_turns
	var ready_relic := relic_ready
	var set_trigger := false
	var relic_qi := 0
	var next_seal_turns := maxi(0, seal_turns - 1)
	match action:
		"move":
			extra_steps = 0
			if target in runes:
				next_seal_turns = ALTAR_BREAK_TURNS
			if relic == "reed_boots":
				ready_relic = false
			elif relic == "wind_seal" and ready_relic and hero in intent.cells and target not in intent.cells:
				relic_qi = mini(Goods.WIND_SEAL_QI, max_qi - qi)
				qi_after += relic_qi
				ready_relic = relic_qi == 0
		"strike":
			set_trigger = counter_ready or boosted > 0
			var bonus := counter_bonus() if counter_ready else Gu.BREW_STRIKE_BONUS if boosted > 0 else 0
			dealt = STRIKE_DAMAGE + strike_bonus + bonus
			boosted = maxi(0, boosted - 1)
			counter = false
			qi_after = mini(max_qi, qi + 1)
		"moon":
			dealt = moon_damage
			qi_after = qi - MOON_COST
			mark = build_family == "lunar"
		"moon_edge":
			set_trigger = mark
			dealt = Gu.MOON_EDGE_DAMAGE + (Gu.MOON_MARK_BONUS if set_trigger else 0)
			qi_after = qi - Gu.MOON_EDGE_COST
			mark = false
		"moon_link":
			dealt = Gu.MOON_LINK_DAMAGE
			qi_after -= Gu.MOON_LINK_COST
		"bind_hound":
			qi_after -= BIND_COST
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
		"stone_veil":
			extra_steps = 1
			qi_after -= Gu.STONE_VEIL_COST
		"scale_veil":
			concealment = Gu.SCALE_VEIL_TURNS
			qi_after -= scale_veil_cost()
			set_trigger = can_extend_veil()
			if set_trigger:
				extra_steps = 2
		"vital_leaf":
			healed = mini(LEAF_HEAL, MAX_HP - hp)
	var armor_block := 0
	if tactic == "seal_altar" and seal_turns == 0:
		armor_block = mini(dealt, ALTAR_ARMOR)
	elif hound_guards(hero):
		armor_block = mini(dealt, HOUND_FRONT_ARMOR)
	dealt = mini(defender_hp, dealt - armor_block)
	var exposed_damage := 0
	if recovering and dealt > 0:
		if tactic == "thunder_boss":
			exposed_damage = mini(THUNDER_OPEN_BONUS, defender_hp - dealt)
		elif tactic == "marsh" and action == "strike":
			exposed_damage = mini(MARSH_JAW_BONUS, defender_hp - dealt)
		elif pulse_open:
			exposed_damage = mini(PULSE_OPEN_BONUS, defender_hp - dealt)
	if tactic == "seal_altar" and seal_turns > 0 and action == "strike":
		exposed_damage = mini(ALTAR_OPEN_STRIKE, defender_hp - dealt)
	elif tactic == "armored_hound" and action == "strike" and not hound_guards(hero):
		exposed_damage = mini(HOUND_FLANK_STRIKE, defender_hp - dealt)
	dealt += exposed_damage
	var relic_damage := 0
	if relic == "elite_fang" and ready_relic and dealt > 0:
		relic_damage = mini(Goods.FANG_BONUS, defender_hp - dealt)
		dealt += relic_damage
		ready_relic = false
	if relic == "pulse_pearl" and ready_relic and qi_after < qi:
		relic_qi = mini(Goods.PULSE_PEARL_QI, qi - qi_after)
		qi_after += relic_qi
		ready_relic = false
	var receives := 0
	var absorbed := 0
	var relic_block := 0
	var ends_fight := action == "bind_hound" or (dealt >= defender_hp and not hits_hound)
	var interrupts: bool = intent.kind == "nodo_command" and dealt > 0 and not hits_hound
	var stops_hound := hits_hound and dealt >= defender_hp
	var hit: bool = not ends_fight and not (stops_hound and intent.kind == "nodo_hound") and position_after in intent.cells
	var evaded := hit and concealment > 0 and aim_can_be_lost()
	if evaded:
		concealment = 0
	elif hit:
		var damage: int = intent.damage
		if action == "guard":
			damage = ceili(damage * (1.0 - GUARD_REDUCTION))
		if ward > 0:
			absorbed = mini(protection, damage)
			ward = 0
			if absorbed > 0 and build_family == "ward" and protection >= white_jade_absorb():
				counter = true
		if relic == "jade_token" and ready_relic and damage > absorbed:
			relic_block = mini(Goods.TOKEN_BLOCK, damage - absorbed)
			ready_relic = false
		elif relic == "iron_hide" and ready_relic and action == "guard" and damage > absorbed:
			relic_block = mini(Goods.IRON_HIDE_BLOCK, damage - absorbed)
			ready_relic = false
		receives = mini(hp + healed, damage - absorbed - relic_block)
	var qi_drained := int(receives > 0 and intent.kind == "poison" and qi_after > 0)
	qi_after -= qi_drained
	return {"dealt": dealt, "receives": receives, "qi": qi_after, "steps": steps, "path": path,
		"healed": healed, "absorbed": absorbed, "jade_turns": maxi(0, ward - 1) if not ends_fight else 0,
		"target_cell": aim, "hits_hound": hits_hound, "interrupts": interrupts, "stops_hound": stops_hound,
		"ward_strength": protection, "moon_mark": mark and dealt < defender_hp, "set_trigger": set_trigger,
		"counter_ready": counter and not ends_fight, "brew_ready": brew_setup, "strong_strikes": boosted,
		"steps_bonus": extra_steps, "veil_turns": maxi(0, concealment - 1), "evaded": evaded,
		"relic_ready": ready_relic, "relic_block": relic_block, "relic_damage": relic_damage,
		"exposed_damage": exposed_damage, "qi_drained": qi_drained, "relic_qi": relic_qi,
		"armor_block": armor_block, "seal_turns": next_seal_turns}


func take_turn(action: String, target: int = -1) -> Dictionary:
	var preview := preview_action(action, target)
	if preview.has("error"):
		return preview

	var exchange := {"action": action, "hero_from": hero, "wolf_from": wolf,
		"wolf_damage": 0, "hound_damage": 0, "target_cell": preview.target_cell, "hero_damage": 0, "reaction": "", "notes": [], "hero_path": preview.path,
		"healed": preview.healed, "absorbed": preview.absorbed, "enemy_intent": intent,
		"set_trigger": preview.set_trigger, "evaded": preview.evaded}
	var notes: Array = exchange.notes
	var previous_qi := qi
	qi = preview.qi
	seal_turns = preview.seal_turns
	var action_qi: int = qi + preview.qi_drained
	pulse_open = intent.kind == "core_wave" and action == "move" and hero in intent.cells and target not in intent.cells
	jade_turns = preview.jade_turns
	ward_strength = preview.ward_strength if jade_turns > 0 else 0
	var had_mark := hound_mark if preview.hits_hound else moon_mark
	if preview.hits_hound:
		hound_mark = preview.moon_mark
	else:
		moon_mark = preview.moon_mark
	var had_counter := counter_ready
	counter_ready = preview.counter_ready
	brew_ready = preview.brew_ready
	strong_strikes = preview.strong_strikes
	steps_bonus = preview.steps_bonus
	veil_turns = preview.veil_turns
	var used_relic: bool = relic_ready and not preview.relic_ready
	relic_ready = preview.relic_ready
	match action:
		"move":
			hero = target
			notes.append("Bạn di chuyển đến %s." % cell_name(hero))
			if target in runes:
				notes.append("Ấn đá vô hiệu Thạch Giáp trong %d lượt kế tiếp." % seal_turns)
			if preview.relic_qi > 0:
				notes.append("Ấn Dẫn Phong hồi %d chân nguyên." % preview.relic_qi)
			elif used_relic:
				notes.append("Giày cỏ lau đã hỗ trợ bước đầu.")
		"strike", "moon", "moon_edge", "moon_link":
			if action == "moon_link":
				moon_link_used = true
			var damage: int = preview.dealt
			if preview.hits_hound:
				hound_hp -= damage
				exchange.hound_damage = damage
			else:
				wolf_hp -= damage
				exchange.wolf_damage = damage
			var name: String = Gu.GU[action].name if Gu.GU.has(action) else "Tay không"
			if tactic == "nodo":
				var recipient := "khuyển thú" if preview.hits_hound else "cổ sư Nô đạo"
				notes.append("%s gây %d sát thương lên %s." % [name, damage, recipient])
			else:
				notes.append("%s gây %d sát thương." % [name, damage])
			if preview.armor_block > 0:
				notes.append("Thạch Giáp chặn %d sát thương." % preview.armor_block)
			if preview.exposed_damage > 0:
				var opening_name: String = intent.name
				if tactic == "seal_altar":
					opening_name = "Vỡ Thạch Giáp"
				elif tactic == "armored_hound":
					opening_name = "Đánh sườn"
				notes.append("%s cộng %d sát thương." % [opening_name, preview.exposed_damage])
			if preview.relic_damage > 0:
				notes.append("Nanh Tinh Anh cộng %d sát thương." % preview.relic_damage)
			if action == "moon_edge" and preview.set_trigger:
				notes.append("Nguyệt Mang kích phát Nguyệt Ấn.")
			elif action == "strike" and preview.set_trigger:
				notes.append("Bạn dùng thế Phản đòn." if had_counter else "Đòn tay không được tinh nguyên cường hóa.")
			elif preview.moon_mark and not had_mark:
				notes.append("Nguyệt Ấn bám trên đối thủ.")
		"guard":
			notes.append("Thủ thế và hồi 1 chân nguyên." if action_qi > previous_qi else "Bạn vào thế thủ.")
		"jade_skin":
			notes.append("Ngọc Bì Cổ tạo một lớp bảo hộ.")
		"white_jade":
			notes.append("Bạch Ngọc tạo lớp chặn %d sát thương." % preview.ward_strength)
		"brew":
			brew_left -= 1
			notes.append("Tửu Trùng hồi %d chân nguyên." % (action_qi - previous_qi))
		"four_flavors":
			notes.append("Tứ Vị cường hóa %d cú Tay không." % strong_strikes)
		"stone_veil":
			notes.append("Ẩn Thạch chuẩn bị một bước đi xa.")
		"scale_veil":
			notes.append("Ẩn Lân che thân và y phục.")
			if preview.set_trigger:
				notes.append("Bước ẩn kế tiếp đi tối đa 4 ô.")
		"vital_leaf":
			leaves -= 1
			hp += int(preview.healed)
			notes.append("Sinh Cơ Diệp hồi %d sinh lực." % preview.healed)
	if relic == "pulse_pearl" and preview.relic_qi > 0:
		notes.append("Châu Hoàn Nguyên hoàn lại %d chân nguyên." % preview.relic_qi)
	if pulse_open:
		notes.append("Né đúng nhịp. Đòn trúng lượt sau được cộng %d sát thương." % PULSE_OPEN_BONUS)

	if action == "bind_hound":
		result = VICTORY
		notes.append("Ngự Khuyển đã thu phục chó hoang. Sinh lực của nó giữ nguyên.")
	elif wolf_hp <= 0:
		result = VICTORY
		notes.append("Cổ sư Nô đạo bại trận. Khuyển thú còn sống rút đi." if live_hound() >= 0 else "Đối thủ đã gục.")
	elif preview.stops_hound and intent.kind in ["nodo_command", "nodo_hound", "nodo_hound_advance"]:
		notes.append("Khuyển thú đã gục. Lệnh vồ mất hiệu lực.")
	elif intent.kind == "nodo_command":
		if preview.interrupts:
			notes.append("Đòn trúng cổ sư, ngắt lệnh vồ.")
		else:
			ordered_cell = hero
			notes.append("Khuyển thú nhận lệnh nhắm ô %s." % cell_name(ordered_cell))
	elif intent.kind == "nodo_hound_advance":
		if intent.destination != hound_cell and intent.destination != hero:
			hound_cell = intent.destination
			exchange.reaction = "hound_advance"
			notes.append("Khuyển thú áp sát tới %s." % cell_name(hound_cell))
		else:
			notes.append("Khuyển thú giữ vị trí.")
	elif intent.kind == "recover":
		notes.append("Đối thủ hồi thế. Bạn có một lượt an toàn.")
	elif intent.kind == "advance":
		wolf = enemy_step(wolf, pace, live_hound())
		if wolf != exchange.wolf_from:
			exchange.reaction = "advance"
			notes.append("Đối thủ áp sát đến %s." % cell_name(wolf))
		else:
			notes.append("Đối thủ giữ vị trí.")
	elif preview.evaded:
		exchange.reaction = "miss"
		notes.append("Ẩn Lân làm đối thủ mất dấu.")
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
		if preview.relic_block > 0:
			notes.append("%s chặn thêm %d sát thương." % [Goods.RELICS[relic][0], preview.relic_block])
		if preview.qi_drained > 0:
			notes.append("Độc rút %d chân nguyên." % preview.qi_drained)
		if counter_ready and (not had_counter or action == "strike"):
			notes.append("Phản đòn đã sẵn sàng.")
		if hp <= 0:
			result = DEFEAT
	else:
		exchange.reaction = "miss"
		notes.append("Bạn đứng ngoài vùng nước nhiễm điện." if intent.kind == "flood" else "Bạn né được %s." % str(intent.name).to_lower())

	if preview.stops_hound and intent.kind not in ["nodo_hound", "nodo_hound_advance", "nodo_command"]:
		notes.append("Khuyển thú đã gục.")
	if intent.kind in ["nodo_hound", "nodo_hound_advance"] or not result.is_empty():
		ordered_cell = -1
	if result.is_empty():
		if intent.kind in ["heavy", "shot", "flood", "ambush", "fall", "core_wave"]:
			heavy_count += 1
		recovering = (intent.kind == "heavy" and tactic in ["king", "den", "armored_hound"]) or intent.kind in ["shot", "flood", "ambush", "fall", "thunder", "seal_burst", "core_wave"]
		turn += 1
		forecast()
	else:
		intent = {}
		jade_turns = 0
		ward_strength = 0
		moon_mark = false
		hound_mark = false
		counter_ready = false
		brew_ready = false
		strong_strikes = 0
		steps_bonus = 0
		veil_turns = 0
	return exchange
