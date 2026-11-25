extends RefCounted

const Rules = preload("res://battle_rules.gd")
const Awakening = preload("res://awakening_rules.gd")
const Gu = preload("res://gu_catalog.gd")
const Goods = preload("res://waypoint_goods.gd")
const Pack = preload("res://kennel_pack.gd")
const CURRENT_VERSION := 17
const RIDGE_FLOOR := 3
const FORD_FLOOR := 4
const AMBUSH_FLOOR := 5
const BOSS_FLOOR := 6
const BOSS_VERSION := 9
const MARSH_FLOOR := 7
const MARSH_VERSION := 10
const WIND_FLOOR := 8
const WIND_VERSION := 11
const ALTAR_FLOOR := 9
const ALTAR_VERSION := 12
const PULSE_FLOOR := 10
const PULSE_VERSION := 13
const XOA_FLOOR := 11
const XOA_VERSION := 14
const NODO_FLOOR := 12
const NODO_VERSION := 15
const KENNEL_FLOOR := 13
const KENNEL_VERSION := 16
const KENNEL_TWO_FLOOR := 14
const KENNEL_TWO_VERSION := 17
const FLOORS := [
	{"name": "Rìa rừng Thanh Mao", "enemy": "Điện Lang", "damage": 12, "bite": 8, "hp": 48,
		"heavy": "Vồ mồi", "pace": 1, "rooms": [[3, 12, 30, 34], [4, 10, 27, 36], [2, 13, 25, 37]]},
	{"name": "Khe đá Hoang Nha", "enemy": "Điện Lang tinh anh", "damage": 17, "bite": 11, "hp": 62,
		"heavy": "Vồ xuyên khe", "pace": 2, "rooms": [[5, 12, 26, 36], [3, 10, 29, 38], [2, 11, 26, 35]]},
	{"name": "Hang Cuồng Điện Lang", "enemy": "Cuồng Điện Lang", "damage": 23, "bite": 13, "hp": 84,
		"heavy": "Cuồng lôi vồ", "pace": 2, "rooms": [[2, 11, 28, 35], [5, 10, 29, 34], [3, 13, 26, 36]]},
]
const ROUTES := {
	"ravine": {"name": "Khe đá Hoang Nha", "enemy": "Điện Lang", "damage": 14, "bite": 9, "hp": 56,
		"heavy": "Vồ qua khe", "pace": 1, "rooms": [[4, 11, 25, 30], [5, 12, 27, 37], [2, 13, 26, 35]]},
	"elite": {"name": "Lối săn tinh anh", "enemy": "Điện Lang tinh anh", "damage": 17, "bite": 11, "hp": 62,
		"heavy": "Vồ xuyên khe", "pace": 2, "rooms": [[5, 12, 26, 36], [3, 10, 29, 38], [2, 11, 26, 35]]},
}
const RAVINE_COVERS := [[4, 11, 20, 30], [5, 12, 19, 37], [2, 13, 18, 35]]
const CHAPTER_TWO := {"name": "Sườn đá Mù Sương", "enemy": "Điện Lang phóng lôi", "damage": 16,
	"bite": 9, "hp": 72, "heavy": "Hồ quang", "pace": 1, "wolf_cell": 22,
	"rooms": [[4, 12, 26, 37], [5, 11, 29, 34], [3, 10, 27, 36]]}
const THUNDER_FORD := {"name": "Bãi Đá Suối Sấm", "enemy": "Điện Lang dẫn lôi", "damage": 18,
	"bite": 10, "hp": 76, "heavy": "Hồ quang", "pace": 1, "wolf_cell": 22,
	"rooms": [[5, 11, 28, 35], [4, 12, 27, 38], [3, 13, 29, 34]],
	"water": [[18, 19, 20, 21, 26, 27], [10, 11, 18, 19, 20, 21], [18, 19, 20, 21, 27, 28]]}
const AMBUSH_PASS := {"name": "Hẻm Đá Phục Kích", "enemy": "Điện Lang phục kích", "damage": 17,
	"bite": 10, "hp": 82, "heavy": "Vồ phục kích", "pace": 2, "wolf_cell": 22,
	"rooms": [[4, 11, 13, 26, 35], [3, 12, 27, 29, 36], [2, 10, 14, 25, 34]],
	"cracks": [[19, 20, 21, 27, 28], [18, 19, 20, 21, 28], [18, 19, 20, 21, 28, 29]]}
const ELITE_DEN := {"name": "Ổ Điện Lang", "enemy": "Điện Lang đầu đàn", "damage": 21,
	"bite": 12, "hp": 96, "heavy": "Vồ giữ ổ", "pace": 2, "wolf_cell": 21,
	"rooms": [[4, 11, 22, 27, 35], [5, 12, 19, 26, 38], [3, 13, 20, 29, 34]]}
const THUNDER_GATE := {"name": "Lôi Nha Đài", "enemy": "Lôi Nha Trấn Ải", "damage": 20,
	"bite": 12, "hp": 108, "heavy": "Lôi quét ngang", "pace": 2, "wolf_cell": 21,
	"rooms": [[3, 12, 27, 35], [4, 11, 26, 37], [5, 13, 28, 34]]}
const POISON_MARSH := {"name": "Đầm Rễ Độc", "enemy": "Điện Lang nhiễm độc", "damage": 18,
	"bite": 10, "hp": 112, "heavy": "Phun độc", "pace": 1, "wolf_cell": 21,
	"rooms": [[4, 12, 26, 37], [3, 13, 27, 36], [5, 11, 28, 35]],
	"water": [[9, 10, 17, 18, 25, 29, 30, 33, 34, 38, 39],
		[8, 9, 16, 17, 18, 22, 23, 30, 31, 34], [9, 10, 17, 18, 25, 22, 23, 30, 31, 38]]}
const MARSH_HEAL := 30
const MARSH_QI := 4
const TONIC_HEAL := 18
const TONIC_LEAVES := 2
const MARSH_REWARDS := {"purifying_dew": "Tinh Lộ Tịnh Mạch", "marsh_tonic": "Cao giải độc"}
const WIND_PASS := {"name": "Hẻm Hàn Phong", "enemy": "Điện Lang Hàn Phong", "damage": 19,
	"bite": 12, "hp": 120, "heavy": "Gió cắt", "pace": 2, "wolf_cell": 21,
	"rooms": [[4, 10, 25, 35, 37], [3, 8, 19, 28, 37], [6, 10, 19, 24, 36]]}
const WIND_HEAL := 24
const WIND_QI := 3
const WIND_SUPPLY_QI := 3
const WIND_SUPPLY_LEAVES := 2
const WIND_REWARDS := {"wind_seal": "Ấn Dẫn Phong", "wind_supplies": "Túi Hàn Dược"}
const SEAL_ALTAR := {"name": "Đài Trấn Ấn", "enemy": "Thạch Giáp Lang", "damage": 18,
	"bite": 12, "hp": 124, "heavy": "Chấn Ấn", "pace": 2, "wolf_cell": 21,
	"rooms": [[4, 11, 27, 35], [3, 13, 25, 35], [5, 10, 26, 36]],
	"runes": [[19, 28], [1, 20], [19, 12]]}
const ALTAR_HEAL := 24
const ALTAR_QI := 2
const ALTAR_STRIKE_BONUS := 3
const ALTAR_CACHE_STONES := 6
const ALTAR_REWARDS := {"stone_marrow": "Thạch Tủy Luyện Thể", "altar_cache": "Hộp tiếp tế cổ trận"}
const PULSE_HALL := {"name": "Điện Trấn Mạch", "enemy": "Thạch Vương", "damage": 18,
	"bite": 12, "hp": 140, "heavy": "Nội Chấn", "pace": 2, "wolf_cell": 21,
	"rooms": [[4, 10, 27, 35], [3, 12, 26, 37], [5, 11, 28, 34]]}
const PULSE_HEAL := 30
const PULSE_QI := 3
const PULSE_RITE_PRICE := 8
const PULSE_RITE_HEAL := 6
const PULSE_CACHE_STONES := 8
const PULSE_CACHE_LEAVES := 2
const PULSE_SEAL := "Ấn Trấn Mạch"
const PULSE_REWARDS := {"pulse_pearl": "Châu Hoàn Nguyên", "pulse_cache": "Rương Trấn Mạch"}
const XOA_TRAIL := {"name": "Bãi đá chân núi Tam Xoa", "enemy": "Chó Thiết Giáp", "damage": 18,
	"bite": 12, "hp": 132, "heavy": "Húc giáp", "pace": 2, "wolf_cell": 21,
	"rooms": [[4, 11, 27, 35], [3, 13, 26, 37], [5, 10, 18, 34]]}
const XOA_HEAL := 22
const XOA_QI := 2
const XOA_HIDE_PRICE := 7
const XOA_REWARDS := {"iron_hide": "Giáp da Thiết Giáp", "sell_iron_hide": "Đổi da lấy nguyên thạch"}
const NODO_ROAD := {"name": "Đường núi Tam Xoa", "enemy": "Cổ sư Nô đạo", "damage": 19,
	"bite": 10, "hp": 104, "heavy": "Khuyển thú vồ", "pace": 2, "wolf_cell": 21, "hound_hp": 40,
	"hound_cells": [29, 28, 25], "rooms": [[4, 11, 26, 35], [3, 14, 27, 37], [5, 10, 19, 34]]}
const NODO_HEAL := 21
const NODO_QI := 3
const NODO_REST_HEAL := 10
const NODO_SUPPLY_PRICE := 6
const NODO_SUPPLY_LEAVES := 2
const NODO_CAMP := {"nodo_rest": "Nghỉ lấy sức", "nodo_supplies": "Đổi lấy Sinh Cơ Diệp"}
const KENNEL_TRIAL := {"name": "Bãi cỏ phúc địa", "enemy": "Chó hoang", "damage": 11,
	"bite": 11, "hp": 32, "heavy": "Táp", "pace": 2,
	"rooms": [[4, 11, 27, 35], [3, 19, 26, 37], [5, 12, 20, 35]]}
const KENNEL_TWO := {"name": "Gò cỏ úa", "enemy": "Đàn chó hoang"}
const BOSS_SEAL := "Ấn Trấn Lôi"
const BOSS_HEAL := 32
const BOSS_QI := 4
const CHAPTER_HEAL := 18
const CHAPTER_QI := 3
const FORD_HEAL := 20
const AMBUSH_HEAL := 22
const LEGACY_REWARDS := {
	"medicine": ["Dược thảo", "Hồi tối đa 24 sinh lực"],
	"stone": ["Nguyên thạch", "+1 sức chứa và hồi đầy chân nguyên"],
	"refine": ["Luyện Nguyệt Quang", "+7 sát thương Nguyệt Quang trong lượt này"],
}
const REWARD_NAMES := {
	"medicine": "Dược thảo",
	"stone": "Nguyên thạch",
	"refine": "Luyện Nguyệt Quang",
	"expand": "Mở rộng Nguyên Hải",
	"jade_skin": "Ngọc Bì Cổ",
	"vital_leaf": "Sinh Cơ Diệp",
}
const REST_OPTIONS := {"rest_hp": "Băng bó", "rest_qi": "Tĩnh tọa", "rest_skip": "Đi tiếp"}
const NORMAL_HEAL := 18
const NORMAL_QI := 3
const ELITE_HEAL := 22
const ELITE_QI := 4
const REFINE_BONUS := 7

var profile: Dictionary
var seed: int
var version: int
var floor := 0
var route := ""
var moon_bonus := 0
var phase := "battle"
var battle: Rules
var journal: Array = []
var stones := 0
var relic := ""
var stop := {}
var visited_shop := {}
var elite_room := false
var elite_award := ""
var marsh_award := ""
var wind_award := ""
var altar_award := ""
var pulse_award := ""
var pulse_rite := false
var xoa_award := ""
var strike_bonus := 0
var hound_gu := 0
var outside_battle: Rules


func _init(awakened: Dictionary, run_seed: int, save_version: int = CURRENT_VERSION) -> void:
	profile = awakened
	seed = run_seed
	version = save_version
	battle = encounter(Rules.MAX_HP, profile.max_qi, profile.max_qi)


func stage_at(index: int) -> Dictionary:
	match index:
		RIDGE_FLOOR:
			return CHAPTER_TWO
		FORD_FLOOR:
			return THUNDER_FORD
		AMBUSH_FLOOR:
			return AMBUSH_PASS
		BOSS_FLOOR:
			return THUNDER_GATE
		MARSH_FLOOR:
			return POISON_MARSH
		WIND_FLOOR:
			return WIND_PASS
		ALTAR_FLOOR:
			return SEAL_ALTAR
		PULSE_FLOOR:
			return PULSE_HALL
		XOA_FLOOR:
			return XOA_TRAIL
		NODO_FLOOR:
			return NODO_ROAD
		KENNEL_FLOOR:
			return KENNEL_TRIAL
		KENNEL_TWO_FLOOR:
			return KENNEL_TWO
	if index == 1 and version >= 2 and ROUTES.has(route):
		return ROUTES[route]
	return FLOORS[index]


func current_stage() -> Dictionary:
	return ELITE_DEN if elite_room else stage_at(floor)


func encounter(hp: int, qi: int, max_qi: int, arsenal: Dictionary = {}) -> Rules:
	if elite_room:
		var den_variant := floori(seed / pow(3, AMBUSH_FLOOR)) % 3
		return battle_for(ELITE_DEN, den_variant, hp, qi, max_qi, moon_bonus, arsenal, "den", true)
	var stage := stage_at(floor)
	var variant := floori(seed / pow(3, floor)) % 3
	var tactic := ""
	if version >= 3:
		match floor:
			1:
				tactic = route
			2:
				tactic = "king"
			RIDGE_FLOOR:
				tactic = "storm"
			FORD_FLOOR:
				tactic = "ford"
			AMBUSH_FLOOR:
				tactic = "ambush"
			BOSS_FLOOR:
				tactic = "thunder_boss"
			MARSH_FLOOR:
				tactic = "marsh"
			WIND_FLOOR:
				tactic = "wind_pass"
			ALTAR_FLOOR:
				tactic = "seal_altar"
			PULSE_FLOOR:
				tactic = "pulse_boss"
			XOA_FLOOR:
				tactic = "armored_hound"
			NODO_FLOOR:
				tactic = "nodo"
			KENNEL_FLOOR:
				tactic = "kennel"
	return battle_for(stage, variant, hp, qi, max_qi, moon_bonus, arsenal, tactic, revised_ward_rules())


static func battle_for(stage: Dictionary, variant: int, hp: int, qi: int, max_qi: int, bonus: int = 0,
		arsenal: Dictionary = {}, tactic: String = "", revised_ward: bool = false) -> Rules:
	return Rules.new({"hp": hp, "qi": qi, "max_qi": max_qi, "wolf_hp": stage.hp,
		"rocks": RAVINE_COVERS[variant] if tactic == "ravine" else stage.rooms[variant],
		"water": stage.water[variant] if stage.has("water") else [],
		"cracks": stage.cracks[variant] if stage.has("cracks") else [],
		"runes": stage.runes[variant] if stage.has("runes") else [],
		"heavy": stage.heavy, "damage": stage.damage,
		"hound_cell": stage.hound_cells[variant] if stage.has("hound_cells") else -1,
		"hound_hp": stage.get("hound_hp", 0),
		"bite": stage.bite, "pace": stage.pace, "moon_bonus": bonus, "tactic": tactic,
		"jade_skin": arsenal.get("jade_skin", false), "leaves": arsenal.get("leaves", 0),
		"wolf_cell": stage.get("wolf_cell", 21), "moon_equipped": arsenal.get("moon_equipped", true),
		"refined_gu": arsenal.get("refined_gu", ""), "starter_gu": arsenal.get("starter_gu", ""),
		"strike_bonus": arsenal.get("strike_bonus", 0),
		"revised_ward": revised_ward, "relic": arsenal.get("relic", "")})


func perform(action: String, target: int = -1) -> Dictionary:
	if phase != "battle":
		return {"error": "Trận đã kết thúc."}
	var exchange: Dictionary = battle.take_turn(action, target)
	if exchange.has("error"):
		return exchange
	journal.append([action, target])
	if battle is Pack:
		hound_gu = (battle as Pack).gu_left
	if battle.result == Rules.DEFEAT:
		phase = "death"
	elif battle.result == Rules.VICTORY:
		if elite_room:
			phase = "elite_reward"
		elif floor == BOSS_FLOOR:
			phase = "chapter_cleared"
		elif floor == MARSH_FLOOR:
			phase = "marsh_reward"
		elif floor == WIND_FLOOR:
			phase = "wind_reward"
		elif floor == ALTAR_FLOOR:
			phase = "altar_reward"
		elif floor == PULSE_FLOOR:
			phase = "pulse_reward"
		elif floor == XOA_FLOOR:
			phase = "xoa_reward"
		elif floor == NODO_FLOOR:
			phase = "nodo_cleared"
		elif floor == KENNEL_FLOOR:
			phase = "kennel_cleared"
			# The first Gu bound the dog. The trial grants the next one.
			hound_gu = 1
		elif floor == KENNEL_TWO_FLOOR:
			phase = "kennel_two_cleared"
		elif floor >= FLOORS.size():
			phase = "complete"
			if version >= 7:
				match floor:
					RIDGE_FLOOR:
						stones += Goods.RIDGE_STONES
					FORD_FLOOR:
						stones += Goods.FORD_STONES
		elif floor == FLOORS.size() - 1:
			phase = "victory"
		else:
			phase = "route" if floor == 0 and version >= 2 else "reward"
	return exchange


func choose_route(id: String) -> bool:
	if phase != "route" or not ROUTES.has(id):
		return false
	route = id
	phase = "reward"
	journal.append([id])
	return true


func reward_options() -> Dictionary:
	if phase != "reward":
		return {}
	if version == 1:
		return LEGACY_REWARDS
	var elite_reward := floor == 1 and route == "elite"
	var hp := ELITE_HEAL if elite_reward else NORMAL_HEAL
	var energy := ELITE_QI if elite_reward else NORMAL_QI
	var options := {
		"medicine": [REWARD_NAMES.medicine, "Hồi tối đa %d sinh lực." % hp],
		"stone": [REWARD_NAMES.stone, "Hồi tối đa %d chân nguyên." % energy],
	}
	if moon_bonus == 0:
		options.refine = [REWARD_NAMES.refine, "Nguyệt Quang mạnh hơn trong lượt chơi này."]
	if elite_reward:
		options.expand = [REWARD_NAMES.expand, "Thêm 1 sức chứa. Lượng chân nguyên giữ nguyên."]
	if version >= 3:
		if floor == 0:
			options.jade_skin = [REWARD_NAMES.jade_skin, "Học tạo lớp ngọc chặn một đòn."]
		elif route == "ravine":
			options.vital_leaf = [REWARD_NAMES.vital_leaf, "Mang một lá trị thương vào hang."]
	return options


func reward_preview(id: String) -> Dictionary:
	if not reward_options().has(id):
		return {}
	var outcome := {"hp": battle.hp, "qi": battle.qi, "max_qi": battle.max_qi, "moon_bonus": moon_bonus,
		"jade_skin": battle.jade_skin, "leaves": battle.leaves}
	var elite_reward := floor == 1 and route == "elite"
	match id:
		"medicine":
			var healed := 24 if version == 1 else (ELITE_HEAL if elite_reward else NORMAL_HEAL)
			outcome.hp = mini(Rules.MAX_HP, battle.hp + healed)
		"stone":
			if version == 1:
				outcome.max_qi += 1
				outcome.qi = outcome.max_qi
			else:
				outcome.qi = mini(battle.max_qi, battle.qi + (ELITE_QI if elite_reward else NORMAL_QI))
		"refine":
			outcome.moon_bonus += REFINE_BONUS
		"expand":
			outcome.max_qi += 1
		"jade_skin":
			outcome.jade_skin = true
		"vital_leaf":
			outcome.leaves += 1
	return outcome


func reward(id: String) -> bool:
	var outcome := reward_preview(id)
	if outcome.is_empty():
		return false
	moon_bonus = outcome.moon_bonus
	floor += 1
	phase = "rest" if floor == 2 and version >= 3 else "battle"
	battle = encounter(outcome.hp, outcome.qi, outcome.max_qi, outcome)
	journal.append([id])
	return true


func rest_preview(id: String) -> Dictionary:
	if phase != "rest" or not REST_OPTIONS.has(id):
		return {}
	return {
		"hp": mini(Rules.MAX_HP, battle.hp + (8 if id == "rest_hp" else 0)),
		"qi": mini(battle.max_qi, battle.qi + (1 if id == "rest_qi" else 0)),
	}


func rest(id: String) -> bool:
	var outcome := rest_preview(id)
	if outcome.is_empty():
		return false
	battle.hp = outcome.hp
	battle.qi = outcome.qi
	phase = "battle"
	journal.append([id])
	return true


func can_begin_chapter() -> bool:
	return phase == "victory" and version >= 3


func begin_chapter() -> bool:
	if not can_begin_chapter():
		return false
	if version == 3:
		version = CURRENT_VERSION
	phase = "refinement"
	journal.append(["chapter_two"])
	return true


func workshop_vitals() -> Dictionary:
	if not stop.is_empty():
		return stop.duplicate()
	if phase == "boss_workshop":
		return {"hp": mini(Rules.MAX_HP, battle.hp + BOSS_HEAL), "qi": mini(battle.max_qi, battle.qi + BOSS_QI),
			"leaves": battle.leaves}
	if phase == "marsh_workshop":
		return {"hp": mini(Rules.MAX_HP, battle.hp + MARSH_HEAL), "qi": mini(battle.max_qi, battle.qi + MARSH_QI),
			"leaves": battle.leaves}
	if phase == "wind_workshop":
		return {"hp": mini(Rules.MAX_HP, battle.hp + WIND_HEAL), "qi": mini(battle.max_qi, battle.qi + WIND_QI),
			"leaves": battle.leaves}
	if phase == "altar_workshop":
		return {"hp": mini(Rules.MAX_HP, battle.hp + ALTAR_HEAL), "qi": mini(battle.max_qi, battle.qi + ALTAR_QI),
			"leaves": battle.leaves}
	if phase == "pulse_workshop":
		var capacity := battle.max_qi + int(pulse_rite)
		var healed := PULSE_HEAL + (PULSE_RITE_HEAL if pulse_rite else 0)
		return {"hp": mini(Rules.MAX_HP, battle.hp + healed),
			"qi": capacity if pulse_rite else mini(capacity, battle.qi + PULSE_QI), "max_qi": capacity,
			"leaves": battle.leaves}
	if phase == "xoa_workshop":
		return {"hp": mini(Rules.MAX_HP, battle.hp + XOA_HEAL), "qi": mini(battle.max_qi, battle.qi + XOA_QI),
			"leaves": battle.leaves}
	if phase == "xoa_camp":
		return {"hp": mini(Rules.MAX_HP, battle.hp + NODO_HEAL), "qi": mini(battle.max_qi, battle.qi + NODO_QI),
			"leaves": battle.leaves}
	var heal := CHAPTER_HEAL
	if phase != "refinement":
		heal = AMBUSH_HEAL if floor == FORD_FLOOR else FORD_HEAL
	return {"hp": mini(Rules.MAX_HP, battle.hp + heal),
		"qi": mini(battle.max_qi, battle.qi + CHAPTER_QI), "leaves": battle.leaves}


func departure_qi() -> int:
	var vitals := workshop_vitals()
	return vitals.qi if phase == "pulse_workshop" and pulse_rite else starting_qi(vitals.qi)


func starting_qi(qi: int) -> int:
	return mini(battle.max_qi, qi + int(relic == "essence_pin"))


func revised_ward_rules() -> bool:
	return version >= 5 or floor >= FORD_FLOOR or phase == "ford_workshop"


func can_cross_ford() -> bool:
	return phase == "complete" and floor == RIDGE_FLOOR


func cross_ford() -> bool:
	if not can_cross_ford():
		return false
	enter_waypoint("ford_workshop")
	journal.append(["cross_ford"])
	return true


func can_enter_pass() -> bool:
	return phase == "complete" and floor == FORD_FLOOR


func enter_pass() -> bool:
	if not can_enter_pass():
		return false
	enter_waypoint("ambush_workshop")
	journal.append(["enter_pass"])
	return true


func can_enter_boss() -> bool:
	return version >= 8 and phase == "complete" and floor == AMBUSH_FLOOR


func enter_boss() -> bool:
	if not can_enter_boss():
		return false
	version = maxi(version, BOSS_VERSION)
	phase = "boss_workshop"
	journal.append(["enter_boss"])
	return true


func enter_marsh() -> bool:
	if phase != "chapter_cleared":
		return false
	version = maxi(version, MARSH_VERSION)
	phase = "marsh_workshop"
	journal.append(["enter_marsh"])
	return true


func marsh_reward_preview(id: String) -> Dictionary:
	if phase != "marsh_reward" or not MARSH_REWARDS.has(id):
		return {}
	var next := {"hp": battle.hp, "qi": battle.qi, "max_qi": battle.max_qi, "leaves": battle.leaves}
	if id == "purifying_dew":
		next.max_qi += 1
		next.qi = next.max_qi
	else:
		next.hp = mini(Rules.MAX_HP, next.hp + TONIC_HEAL)
		next.leaves += TONIC_LEAVES
	return next


func claim_marsh_reward(id: String) -> bool:
	var next := marsh_reward_preview(id)
	if next.is_empty():
		return false
	battle.hp = next.hp
	battle.qi = next.qi
	battle.max_qi = next.max_qi
	battle.leaves = next.leaves
	marsh_award = id
	phase = "marsh_cleared"
	journal.append([id])
	return true


func enter_wind_pass() -> bool:
	if phase != "marsh_cleared":
		return false
	version = maxi(version, WIND_VERSION)
	phase = "wind_workshop"
	journal.append(["enter_wind_pass"])
	return true


func wind_reward_preview(id: String) -> Dictionary:
	if phase != "wind_reward" or not WIND_REWARDS.has(id):
		return {}
	var next := {"qi": battle.qi, "leaves": battle.leaves, "relic": relic}
	if id == "wind_seal":
		next.relic = id
	else:
		next.qi = mini(battle.max_qi, battle.qi + WIND_SUPPLY_QI)
		next.leaves += WIND_SUPPLY_LEAVES
	return next


func claim_wind_reward(id: String) -> bool:
	var next := wind_reward_preview(id)
	if next.is_empty():
		return false
	battle.qi = next.qi
	battle.leaves = next.leaves
	relic = next.relic
	wind_award = id
	phase = "wind_cleared"
	journal.append([id])
	return true


func enter_altar() -> bool:
	if phase != "wind_cleared":
		return false
	version = maxi(version, ALTAR_VERSION)
	phase = "altar_workshop"
	journal.append(["enter_altar"])
	return true


func claim_altar_reward(id: String) -> bool:
	if phase != "altar_reward" or not ALTAR_REWARDS.has(id):
		return false
	if id == "stone_marrow":
		strike_bonus += ALTAR_STRIKE_BONUS
	else:
		stones += ALTAR_CACHE_STONES
		battle.leaves += 1
	altar_award = id
	phase = "altar_cleared"
	journal.append([id])
	return true


func enter_pulse_hall() -> bool:
	if phase != "altar_cleared":
		return false
	version = maxi(version, PULSE_VERSION)
	phase = "pulse_workshop"
	journal.append(["enter_pulse_hall"])
	return true


func can_buy_pulse_rite() -> bool:
	return phase == "pulse_workshop" and not pulse_rite and stones >= PULSE_RITE_PRICE


func buy_pulse_rite() -> bool:
	if not can_buy_pulse_rite():
		return false
	stones -= PULSE_RITE_PRICE
	pulse_rite = true
	journal.append(["pulse_rite"])
	return true


func claim_pulse_reward(id: String) -> bool:
	if phase != "pulse_reward" or not PULSE_REWARDS.has(id):
		return false
	if id == "pulse_pearl":
		relic = id
	else:
		stones += PULSE_CACHE_STONES
		battle.leaves += PULSE_CACHE_LEAVES
	pulse_award = id
	phase = "rank_three_cleared"
	journal.append([id])
	return true


func enter_xoa_trail() -> bool:
	if phase != "rank_three_cleared":
		return false
	version = maxi(version, XOA_VERSION)
	phase = "xoa_workshop"
	journal.append(["enter_xoa_trail"])
	return true


func claim_xoa_reward(id: String) -> bool:
	if phase != "xoa_reward" or not XOA_REWARDS.has(id):
		return false
	if id == "iron_hide":
		relic = id
	else:
		stones += XOA_HIDE_PRICE
	xoa_award = id
	phase = "xoa_cleared"
	journal.append([id])
	return true


func enter_xoa_camp() -> bool:
	if phase != "xoa_cleared":
		return false
	version = maxi(version, NODO_VERSION)
	phase = "xoa_camp"
	journal.append(["enter_xoa_camp"])
	return true


func nodo_camp_preview(id: String) -> Dictionary:
	if phase != "xoa_camp" or not NODO_CAMP.has(id):
		return {}
	var next := workshop_vitals()
	next.stones = stones
	next.reason = ""
	if id == "nodo_rest":
		next.hp = mini(Rules.MAX_HP, next.hp + NODO_REST_HEAL)
	else:
		next.stones -= NODO_SUPPLY_PRICE
		next.leaves += NODO_SUPPLY_LEAVES
		if next.stones < 0:
			next.reason = "Cần %d nguyên thạch để đổi." % NODO_SUPPLY_PRICE
	return next


func choose_nodo_camp(id: String) -> bool:
	var next := nodo_camp_preview(id)
	if next.is_empty() or not next.reason.is_empty():
		return false
	stones = next.stones
	stop = {"hp": next.hp, "qi": next.qi, "leaves": next.leaves}
	phase = "nodo_workshop"
	journal.append([id])
	return true


func reach_kennel_gate() -> bool:
	if phase != "nodo_cleared":
		return false
	version = maxi(version, KENNEL_VERSION)
	phase = "kennel_gate"
	journal.append(["reach_kennel_gate"])
	return true


func refine_hound_gu() -> bool:
	if phase != "kennel_gate":
		return false
	hound_gu = 1
	phase = "kennel_ready"
	journal.append(["refine_hound_gu"])
	return true


func enter_kennel() -> bool:
	if phase != "kennel_ready" or hound_gu != 1:
		return false
	outside_battle = battle
	floor = KENNEL_FLOOR
	battle = encounter(outside_battle.hp, maxi(outside_battle.qi, Rules.BIND_COST), outside_battle.max_qi,
		{"moon_equipped": false})
	phase = "battle"
	journal.append(["enter_kennel"])
	return true


func enter_kennel_two() -> bool:
	if phase != "kennel_cleared" or hound_gu != 1:
		return false
	version = maxi(version, KENNEL_TWO_VERSION)
	floor = KENNEL_TWO_FLOOR
	var layout := floori(seed / pow(3, floor)) % Pack.BOARD.size()
	battle = Pack.new({"hp": battle.hp, "qi": battle.qi, "max_qi": battle.max_qi,
		"dog_hp": battle.wolf_hp, "dog_max": battle.wolf_max}, layout)
	phase = "battle"
	journal.append(["enter_kennel_two"])
	return true


func workshop_size() -> int:
	if version >= 6 or phase == "ambush_workshop":
		return 4
	return 3 if revised_ward_rules() else 2


func enter_waypoint(next_workshop: String) -> void:
	if version >= 7:
		phase = "waypoint"
		stop = workshop_vitals()
	else:
		phase = next_workshop


func waypoint_options() -> Array:
	if phase != "waypoint":
		return []
	if floor == RIDGE_FLOOR:
		return ["camp", "merchant", "salvage"]
	var options := ["camp", "merchant", "spring"]
	if version >= 8:
		options.append("elite_detour")
	return options


func waypoint_preview(id: String) -> Dictionary:
	if id not in waypoint_options():
		return {}
	var next := stop.duplicate()
	next.stones = stones
	next.reason = ""
	match id:
		"camp":
			next.hp = mini(Rules.MAX_HP, next.hp + Goods.CAMP_HEAL)
		"salvage":
			if next.hp <= Goods.CACHE_COST:
				next.reason = "Cần hơn %d sinh lực." % Goods.CACHE_COST
			next.hp -= Goods.CACHE_COST
			next.stones += Goods.CACHE_STONES
		"spring":
			if next.qi < Goods.SPRING_COST:
				next.reason = "Cần %d chân nguyên." % Goods.SPRING_COST
			next.qi -= Goods.SPRING_COST
			next.leaves += 1
	next.departure_qi = starting_qi(next.qi)
	return next


func choose_waypoint(id: String) -> bool:
	var next := waypoint_preview(id)
	if next.is_empty() or not next.reason.is_empty():
		return false
	stones = next.stones
	stop = {"hp": next.hp, "qi": next.qi, "leaves": next.leaves}
	match id:
		"merchant":
			phase = "shop"
		"elite_detour":
			phase = "elite_workshop"
		_:
			leave_waypoint()
	journal.append([id])
	return true


func elite_reward_preview(id: String) -> Dictionary:
	if phase != "elite_reward" or not Goods.ELITE_REWARDS.has(id):
		return {}
	var remedy := id == "elite_remedy"
	return {"hp": mini(Rules.MAX_HP, battle.hp + Goods.DEN_HEAL + (Goods.REMEDY_HEAL if remedy else 0)),
		"qi": mini(battle.max_qi, battle.qi + Goods.DEN_QI),
		"leaves": battle.leaves + int(remedy), "relic": relic if remedy else "elite_fang"}


func claim_elite_reward(id: String) -> bool:
	var next := elite_reward_preview(id)
	if next.is_empty():
		return false
	relic = next.relic
	stop = {"hp": next.hp, "qi": next.qi, "leaves": next.leaves}
	elite_award = id
	elite_room = false
	phase = "ambush_workshop"
	journal.append([id])
	return true


func shop_relic() -> String:
	var index := (seed + floor - RIDGE_FLOOR) % Goods.RELIC_ORDER.size()
	return Goods.RELIC_ORDER[index]


func shop_price(id: String) -> int:
	if id == "buy_leaf":
		return Goods.LEAF_PRICE
	return Goods.RELIC_TRADE_PRICE if not relic.is_empty() and relic != shop_relic() else Goods.RELIC_PRICE


func shop_unavailable(id: String) -> String:
	if phase != "shop" or id not in ["buy_leaf", "buy_relic"]:
		return "Món hàng không còn được bán."
	if visited_shop.has(id):
		return "Đã mua món này tại quầy."
	if id == "buy_relic" and relic == shop_relic():
		return "Bạn đang mang bảo vật này."
	var price := shop_price(id)
	if stones < price:
		return "Cần %d nguyên thạch." % price
	return ""


func buy(id: String) -> bool:
	if not shop_unavailable(id).is_empty():
		return false
	stones -= shop_price(id)
	visited_shop[id] = true
	if id == "buy_leaf":
		stop.leaves += 1
	else:
		relic = shop_relic()
	journal.append([id])
	return true


func leave_shop() -> bool:
	if phase != "shop":
		return false
	leave_waypoint()
	visited_shop.clear()
	journal.append(["leave_shop"])
	return true


func leave_waypoint() -> void:
	phase = "ford_workshop" if floor == RIDGE_FLOOR else "ambush_workshop"


func equip_build(recipe: String, starter: String) -> bool:
	if phase not in ["refinement", "ford_workshop", "ambush_workshop", "elite_workshop", "boss_workshop", "marsh_workshop", "wind_workshop", "altar_workshop", "pulse_workshop", "xoa_workshop", "nodo_workshop"]:
		return false
	var count := workshop_size()
	if recipe not in Gu.RECIPES.slice(0, count) or starter not in Gu.STARTERS.slice(0, count):
		return false
	var vitals := workshop_vitals()
	var arsenal := {"refined_gu": recipe, "moon_equipped": starter == "moon",
		"jade_skin": starter == "jade_skin", "starter_gu": starter, "leaves": vitals.leaves,
		"relic": relic, "strike_bonus": strike_bonus}
	match phase:
		"ford_workshop":
			floor = FORD_FLOOR
		"ambush_workshop":
			floor = AMBUSH_FLOOR
		"boss_workshop":
			floor = BOSS_FLOOR
		"marsh_workshop":
			floor = MARSH_FLOOR
		"wind_workshop":
			floor = WIND_FLOOR
		"altar_workshop":
			floor = ALTAR_FLOOR
		"pulse_workshop":
			floor = PULSE_FLOOR
		"xoa_workshop":
			floor = XOA_FLOOR
		"nodo_workshop":
			floor = NODO_FLOOR
		"elite_workshop":
			elite_room = true
		_:
			floor = RIDGE_FLOOR
	battle = encounter(vitals.hp, vitals.qi, vitals.get("max_qi", battle.max_qi), arsenal)
	stop.clear()
	phase = "battle"
	journal.append(["equip", recipe, starter])
	return true


func reward_history() -> PackedStringArray:
	var picked: PackedStringArray = []
	for command in journal:
		if command.size() == 1 and REWARD_NAMES.has(command[0]):
			picked.append(REWARD_NAMES[command[0]])
	return picked


func snapshot() -> Dictionary:
	var saved := {"version": version, "hero": profile.hero, "depth": profile.depth, "seed": seed, "journal": journal}
	var schema := version
	if phase == "ambush_workshop" or floor >= AMBUSH_FLOOR:
		schema = maxi(schema, 6)
	elif version == 4 and (phase == "ford_workshop" or floor >= FORD_FLOOR):
		schema = 5
	if schema != version:
		saved.version = schema
		saved.chapter_rules = version
	return saved


static func restore(saved: Variant) -> RefCounted:
	if not saved is Dictionary or not finite_integer(saved.get("version"), 1, CURRENT_VERSION) or not saved.get("journal") is Array:
		return null
	if not saved.get("hero") is String or not finite_integer(saved.get("depth"), 12, 49):
		return null
	if not finite_integer(saved.get("seed"), 0, 0xffffffff):
		return null
	var profile_data := Awakening.profile_for(saved.hero, int(saved.depth))
	if profile_data.is_empty():
		return null
	var rules_version := int(saved.version)
	if saved.has("chapter_rules"):
		if saved.version < 5 or saved.version > 6 or not finite_integer(saved.chapter_rules, 4, int(saved.version) - 1):
			return null
		rules_version = int(saved.chapter_rules)
	var run = load("res://run_state.gd").new(profile_data, int(saved.seed), rules_version)
	for command in saved.journal:
		if not command is Array or command.is_empty() or not command[0] is String:
			return null
		if command.size() == 3:
			if command[0] != "equip" or not command[1] is String or not command[2] is String or not run.equip_build(command[1], command[2]):
				return null
		elif command.size() == 1:
			var committed: bool
			match run.phase:
				"route":
					committed = run.choose_route(command[0])
				"rest":
					committed = run.rest(command[0])
				"waypoint":
					committed = run.choose_waypoint(command[0])
				"shop":
					committed = run.leave_shop() if command[0] == "leave_shop" else run.buy(command[0])
				"elite_reward":
					committed = run.claim_elite_reward(command[0])
				"chapter_cleared":
					committed = command[0] == "enter_marsh" and run.enter_marsh()
				"marsh_reward":
					committed = run.claim_marsh_reward(command[0])
				"marsh_cleared":
					committed = command[0] == "enter_wind_pass" and run.enter_wind_pass()
				"wind_reward":
					committed = run.claim_wind_reward(command[0])
				"wind_cleared":
					committed = command[0] == "enter_altar" and run.enter_altar()
				"altar_reward":
					committed = run.claim_altar_reward(command[0])
				"altar_cleared":
					committed = command[0] == "enter_pulse_hall" and run.enter_pulse_hall()
				"pulse_workshop":
					committed = command[0] == "pulse_rite" and run.buy_pulse_rite()
				"pulse_reward":
					committed = run.claim_pulse_reward(command[0])
				"rank_three_cleared":
					committed = command[0] == "enter_xoa_trail" and run.enter_xoa_trail()
				"xoa_reward":
					committed = run.claim_xoa_reward(command[0])
				"xoa_cleared":
					committed = command[0] == "enter_xoa_camp" and run.enter_xoa_camp()
				"xoa_camp":
					committed = run.choose_nodo_camp(command[0])
				"nodo_cleared":
					committed = command[0] == "reach_kennel_gate" and run.reach_kennel_gate()
				"kennel_gate":
					committed = command[0] == "refine_hound_gu" and run.refine_hound_gu()
				"kennel_ready":
					committed = command[0] == "enter_kennel" and run.enter_kennel()
				"kennel_cleared":
					committed = command[0] == "enter_kennel_two" and run.enter_kennel_two()
				"victory":
					committed = run.version >= 4 and command[0] == "chapter_two" and run.begin_chapter()
				"complete":
					if command[0] == "cross_ford":
						committed = saved.version >= 5 and run.cross_ford()
					elif command[0] == "enter_pass":
						committed = saved.version >= 6 and run.enter_pass()
					elif command[0] == "enter_boss":
						committed = run.enter_boss()
				_:
					committed = run.reward(command[0])
			if not committed:
				return null
		elif command.size() != 2 or not finite_integer(command[1], -1, 39) or run.perform(command[0], int(command[1])).has("error"):
			return null
	if run.snapshot().version != saved.version:
		return null
	return run


static func finite_integer(value: Variant, lower: int, upper: int) -> bool:
	return (value is int or value is float) and value >= lower and value <= upper and floorf(float(value)) == value
