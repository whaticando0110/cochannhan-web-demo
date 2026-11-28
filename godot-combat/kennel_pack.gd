extends "res://battle_rules.gd"

const HERO_ID := -1
const NO_ACTOR := -2
const DOG_STEPS := 2
const ALLY_BITE := 11
const WILD_BITE := 6
const DOG_HP := 18
const PIT_CELL := 35
const PIT_FLANKS := [26, 28]
const LEAD_MOVE := "lead_move"
const LEAD_BITE := "lead_bite"
const BOUND_MOVE := "bound_move"
const BOUND_BITE := "bound_bite"
const BOARD := [
	{"rocks": [10, 14, 27, 33], "wild": [3, 16, 22]},
	{"rocks": [11, 25, 29, 37], "wild": [2, 21, 35]},
	{"rocks": [12, 20, 26, 28], "wild": [5, 17, 38]},
]

const PIT_BOARD := [
	{"rocks": [9, 14, 25, 29, 32, 33, 34, 36, 37, 38, 39], "wild": [10, 12, 0, 2, 4, 7]},
	{"rocks": [8, 15, 25, 29, 32, 33, 34, 36, 37, 38, 39], "wild": [9, 14, 1, 3, 5, 6]},
	{"rocks": [10, 13, 25, 29, 32, 33, 34, 36, 37, 38, 39], "wild": [11, 12, 0, 1, 6, 7]},
]

const RIDGE_BOARD := [
	{"rocks": [10, 13, 18, 21, 26, 29, 33, 38], "wild": [3, 4, 7, 0, 15]},
	{"rocks": [9, 14, 18, 22, 26, 29, 32, 39], "wild": [2, 5, 6, 1, 15]},
	{"rocks": [11, 12, 18, 22, 26, 29, 33, 39], "wild": [8, 15, 3, 1, 6]},
]
const RIDGE_FORMATIONS := {"ridge_hold": [35, 27, 34], "ridge_flank": [37, 28, 36]}

const HOWL_BOARD := [
	{"rocks": [9, 14, 18, 21, 26, 29, 33, 38], "wild": [11, 4, 22, 0, 7]},
	{"rocks": [10, 15, 18, 22, 26, 30, 32, 39], "wild": [12, 2, 21, 1, 7]},
	{"rocks": [8, 13, 18, 22, 26, 29, 34, 39], "wild": [11, 6, 20, 0, 15]},
]
const HOWL_FORMATION := [35, 27, 36]
const HOWL_TURN := 2
const RESERVE_TURN := 6

var round_number := 2
var first_wild_id := 1
var dogs: Array[Dictionary] = []
var bound_id := NO_ACTOR
var gu_left := 1


func _init(vitals: Dictionary = {}, layout: int = 0) -> void:
	round_number = vitals.get("round", 2)
	var boards := BOARD
	if round_number == 3:
		boards = PIT_BOARD
	elif round_number == 4:
		boards = RIDGE_BOARD
	elif round_number == 5:
		boards = HOWL_BOARD
	var board: Dictionary = boards[layout]
	super({"hp": vitals.get("hp", MAX_HP), "qi": vitals.get("qi", MAX_QI),
		"max_qi": vitals.get("max_qi", MAX_QI), "rocks": board.rocks,
		"moon_equipped": false, "tactic": "kennel_pack"})
	if round_number >= 3:
		var formation: Array = HOWL_FORMATION
		if round_number == 3:
			formation = [PIT_CELL, PIT_FLANKS[0], PIT_FLANKS[1]]
		elif round_number == 4:
			formation = RIDGE_FORMATIONS[vitals.formation]
		hero = formation[0]
		gu_left = vitals.get("gu_left", 0)
		var companions: Array = vitals.get("companions", [])
		for index in range(companions.size()):
			var dog: Dictionary = companions[index]
			dogs.append({"cell": formation[index + 1], "hp": dog.hp, "max_hp": dog.max_hp, "allied": true})
		first_wild_id = companions.size()
		if companions.size() == 2:
			bound_id = 1
		for index in range(board.wild.size()):
			var injury := index >= (2 if round_number == 3 else 3)
			var wake := 3 + (index % 2) if injury else 1
			if round_number == 5 and injury:
				wake = RESERVE_TURN
			dogs.append({"cell": board.wild[index], "hp": 8 if injury else DOG_HP, "max_hp": DOG_HP,
				"allied": false, "wake_turn": wake})
	else:
		hero = 19
		dogs.append({"cell": 18, "hp": vitals.get("dog_hp", 32), "max_hp": vitals.get("dog_max", 32), "allied": true})
		for cell in board.wild:
			dogs.append({"cell": cell, "hp": DOG_HP, "max_hp": DOG_HP, "allied": false})
	forecast()


func actor_name(id: int) -> String:
	if id == HERO_ID:
		return "Cổ sư"
	if id == 0:
		return "Chó vòng đầu"
	if id == bound_id:
		return "Chó mới"
	if round_number == 5 and id == first_wild_id:
		return "Chó đầu đàn"
	return "Chó hoang %d" % wild_label(id)


func wild_label(id: int) -> int:
	return id - first_wild_id + 1


func actor_cell(id: int) -> int:
	return hero if id == HERO_ID else int(dogs[id].cell)


func actor_at(cell: int) -> int:
	if cell == hero:
		return HERO_ID
	for id in range(dogs.size()):
		if dogs[id].hp > 0 and dogs[id].cell == cell:
			return id
	return NO_ACTOR


func living_dogs(allied: bool) -> Array[int]:
	var living: Array[int] = []
	for id in range(dogs.size()):
		if dogs[id].hp > 0 and dogs[id].allied == allied:
			living.append(id)
	return living


func occupied_except(id: int) -> Array:
	var cells: Array = [] if id == HERO_ID else [hero]
	for other in range(dogs.size()):
		if other != id and dogs[other].hp > 0:
			cells.append(dogs[other].cell)
	return cells


func attack_cell(target: int = -1) -> int:
	return target if target >= 0 else wolf


func uses_cover() -> bool:
	return true


func move_targets() -> Array:
	return targets_for("move")


func forecast() -> void:
	var orders: Array[Dictionary] = []
	var cells: Array[int] = []
	var allies := living_dogs(true)
	var howler := NO_ACTOR
	for id in living_dogs(false):
		if turn < int(dogs[id].get("wake_turn", 1)):
			continue
		if round_number == 5 and turn == HOWL_TURN and id == first_wild_id:
			howler = id
			orders.append({"dog": id, "howl": true})
			continue
		var from := actor_cell(id)
		var target := HERO_ID
		var gap := distance(from, hero)
		for ally in allies:
			var distance_to_ally := distance(from, actor_cell(ally))
			if distance_to_ally < gap or (distance_to_ally == 1 and target == HERO_ID):
				gap = distance_to_ally
				target = ally
		var tile := actor_cell(target)
		orders.append({"dog": id, "target": target, "cell": tile, "bite": gap == 1})
		if gap == 1 and tile not in cells:
			cells.append(tile)
	intent = {"kind": "pack", "name": "Đàn chó áp sát" if cells.is_empty() else "Đàn chó chuẩn bị táp",
		"cells": cells, "damage": WILD_BITE, "orders": orders}
	if howler >= 0:
		intent.name = "Chó đầu đàn sắp hú"
		intent.howler = howler


func command_actor(action: String) -> int:
	match action:
		LEAD_MOVE, LEAD_BITE:
			return 0
		BOUND_MOVE, BOUND_BITE:
			return bound_id
	return HERO_ID


func bite_origin(id: int, cell: int) -> int:
	var from := actor_cell(id)
	if distance(from, cell) == 1:
		return from
	var occupied := occupied_except(id)
	for step in neighbors(from):
		if step not in rocks and step not in occupied and distance(step, cell) == 1:
			return step
	return -1


func targets_for(action: String) -> Array:
	if not result.is_empty():
		return []
	var actor := command_actor(action)
	match action:
		"move", LEAD_MOVE, BOUND_MOVE:
			if actor == NO_ACTOR or (actor >= 0 and dogs[actor].hp <= 0):
				return []
			var steps := movement_range() if actor == HERO_ID else DOG_STEPS
			return reach(actor_cell(actor), steps, -1, {}, -1, occupied_except(actor)).keys()
		LEAD_BITE, BOUND_BITE:
			if actor == NO_ACTOR or dogs[actor].hp <= 0:
				return []
			return living_dogs(false).map(func(id: int): return dogs[id].cell).filter(
				func(cell: int): return bite_origin(actor, cell) >= 0)
		"bind_hound":
			if gu_left == 0 or qi < BIND_COST:
				return []
			return living_dogs(false).map(func(id: int): return dogs[id].cell).filter(
				func(cell: int): return distance(hero, cell) <= BIND_RANGE and ray_blocker(hero, cell) < 0)
	return []


func unavailable(action: String, target: int = -1) -> String:
	if not result.is_empty():
		return "Vòng này đã kết thúc."
	match action:
		"guard":
			return "" if target == -1 else "Thủ thế dùng tại ô đang đứng."
		"bind_hound":
			if gu_left == 0:
				return "Đã dùng Ngự Khuyển Cổ của vòng này."
			if qi < BIND_COST:
				return "Cần %d chân nguyên để thu phục." % BIND_COST
		"move", LEAD_MOVE, LEAD_BITE, BOUND_MOVE, BOUND_BITE:
			var dog := command_actor(action)
			if dog == NO_ACTOR or (dog >= 0 and dogs[dog].hp <= 0):
				return "Chó này không thể nhận lệnh."
		_:
			return "Phúc địa phong cấm bộ Cổ và đòn đánh của cổ sư."
	var options := targets_for(action)
	if target == -1:
		if not options.is_empty():
			return ""
		return "Chưa có chó hoang trong tầm và đường phóng thông." if action == "bind_hound" else "Chưa có ô hợp lệ cho lệnh này."
	if target in options:
		return ""
	if action == "bind_hound" and target >= 0 and target < COLUMNS * ROWS:
		var victim := actor_at(target)
		if victim < 0 or dogs[victim].allied:
			return "Chỉ thu phục được chó hoang."
		if distance(hero, target) <= BIND_RANGE:
			return "Đá chắn đường thu phục."
		return "Chó hoang cách quá %d ô." % BIND_RANGE
	return "Ô này ngoài tầm hoặc đang bị chiếm."


func preview_action(action: String, target: int = -1) -> Dictionary:
	var reason := unavailable(action, target)
	if not reason.is_empty():
		return {"error": reason}
	if target == -1 and action != "guard":
		return {"error": "Hãy chọn một ô trên sân."}
	var steps: Array[int] = []
	var actor := command_actor(action)
	var dealt := 0
	match action:
		"move", LEAD_MOVE, BOUND_MOVE:
			var origin := actor_cell(actor)
			var parents := {}
			reach(origin, DOG_STEPS if actor >= 0 else movement_range(), -1, parents, -1, occupied_except(actor))
			var next := target
			while next != origin:
				steps.push_front(next)
				next = parents[next]
		LEAD_BITE, BOUND_BITE:
			dealt = mini(ALLY_BITE, dogs[actor_at(target)].hp)
			var strike_from := bite_origin(actor, target)
			if actor_cell(actor) != strike_from:
				steps.append(strike_from)
	return {"path": steps, "dealt": dealt, "actor": actor}


func advance_enemy(id: int, target: int) -> int:
	var origin := actor_cell(id)
	var goal := actor_cell(target)
	var occupied := occupied_except(id)
	occupied.erase(goal)
	var distances := reach(goal, COLUMNS * ROWS, -1, {}, -1, occupied)
	for step in neighbors(origin):
		if step != goal and step not in occupied and int(distances.get(step, 100)) < int(distances.get(origin, 100)):
			return step
	return origin


func take_turn(action: String, target: int = -1) -> Dictionary:
	var preview := preview_action(action, target)
	if preview.has("error"):
		return preview

	var notes: Array[String] = []
	var exchange := {"action": action, "hero_path": [], "hero_damage": 0, "notes": notes,
		"player_events": [], "enemy_events": [], "hero_guard": action == "guard"}
	var actor: int = preview.actor
	var howler: int = intent.get("howler", NO_ACTOR)
	var interrupted_howl := howler >= 0 and action in [LEAD_BITE, BOUND_BITE, "bind_hound"] and actor_at(target) == howler
	var steps: Array = preview.path
	if not steps.is_empty():
		if actor == HERO_ID:
			hero = steps.back()
			exchange.hero_path = steps
		else:
			dogs[actor].cell = steps.back()
			exchange.player_events.append({"kind": "move", "actor": actor, "path": steps})
		notes.append("%s đến %s." % [actor_name(actor), cell_name(steps.back())])
	match action:
		"guard":
			qi = mini(max_qi, qi + 1)
			notes.append("Cổ sư Thủ thế.")
		"bind_hound":
			bound_id = actor_at(target)
			gu_left = 0
			qi -= BIND_COST
			dogs[bound_id].allied = true
			exchange.player_events.append({"kind": "bind", "actor": bound_id})
			notes.append("Thu phục thành công. Chó giữ nguyên sinh lực.")
		LEAD_BITE, BOUND_BITE:
			var wild := actor_at(target)
			apply_bite(exchange.player_events, notes, actor, wild, preview.dealt, false)

	for order: Dictionary in intent.orders:
		if hp == 0:
			break
		var wild: int = order.dog
		if order.get("howl", false):
			if interrupted_howl:
				notes.append("Đã ngắt tiếng hú. Tiếp viện tới ở lượt %d." % RESERVE_TURN)
			else:
				for reserve in living_dogs(false):
					if dogs[reserve].wake_turn > turn:
						dogs[reserve].wake_turn = turn + 1
				notes.append("Tiếng hú gọi tiếp viện tới lượt sau.")
			continue
		if dogs[wild].allied or dogs[wild].hp <= 0:
			continue
		if order.bite:
			var victim := actor_at(order.cell)
			if victim == HERO_ID or (victim >= 0 and dogs[victim].allied):
				apply_bite(exchange.enemy_events, notes, wild, victim, WILD_BITE, exchange.hero_guard)
		else:
			var victim: int = order.target
			if victim >= 0 and dogs[victim].hp == 0:
				victim = HERO_ID
			var next := advance_enemy(wild, victim)
			if next != actor_cell(wild):
				dogs[wild].cell = next
				exchange.enemy_events.append({"kind": "move", "actor": wild, "path": [next]})

	for event: Dictionary in exchange.enemy_events:
		if event.kind == "bite" and event.victim == HERO_ID:
			exchange.hero_damage += event.damage
	if hp == 0 or (gu_left == 0 and living_dogs(true).is_empty()):
		result = DEFEAT
	elif living_dogs(false).is_empty():
		result = VICTORY
	if result.is_empty():
		turn += 1
		forecast()
	else:
		intent = {}
	return exchange


func apply_bite(events: Array, notes: Array[String], attacker: int, victim: int, damage: int, guard: bool) -> void:
	var left: int
	if victim == HERO_ID:
		var received := ceili(damage * (1.0 - GUARD_REDUCTION)) if guard else damage
		damage = mini(hp, received)
		hp -= damage
		left = hp
	else:
		damage = mini(damage, dogs[victim].hp)
		dogs[victim].hp -= damage
		left = dogs[victim].hp
	events.append({"kind": "bite", "actor": attacker, "victim": victim, "hp": left, "damage": damage})
	notes.append("%s táp %s · −%d sinh lực." % [actor_name(attacker), actor_name(victim).to_lower(), damage])
