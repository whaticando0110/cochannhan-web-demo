extends RefCounted

const Rules = preload("res://battle_rules.gd")
const Awakening = preload("res://awakening_rules.gd")
const Gu = preload("res://gu_catalog.gd")
const CURRENT_VERSION := 5
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
const CHAPTER_HEAL := 18
const CHAPTER_QI := 3
const FORD_HEAL := 20
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


func _init(awakened: Dictionary, run_seed: int, save_version: int = CURRENT_VERSION) -> void:
	profile = awakened
	seed = run_seed
	version = save_version
	battle = encounter(Rules.MAX_HP, profile.max_qi, profile.max_qi)


func stage_at(index: int) -> Dictionary:
	if index == FLOORS.size() + 1:
		return THUNDER_FORD
	if index == FLOORS.size():
		return CHAPTER_TWO
	if index == 1 and version >= 2 and ROUTES.has(route):
		return ROUTES[route]
	return FLOORS[index]


func encounter(hp: int, qi: int, max_qi: int, arsenal: Dictionary = {}) -> Rules:
	var stage := stage_at(floor)
	var variant := floori(seed / pow(3, floor)) % 3
	var tactic := ""
	if version >= 3:
		match floor:
			1:
				tactic = route
			2:
				tactic = "king"
			3:
				tactic = "storm"
			4:
				tactic = "ford"
	return battle_for(stage, variant, hp, qi, max_qi, moon_bonus, arsenal, tactic, revised_ward_rules())


static func battle_for(stage: Dictionary, variant: int, hp: int, qi: int, max_qi: int, bonus: int = 0,
		arsenal: Dictionary = {}, tactic: String = "", revised_ward: bool = false) -> Rules:
	return Rules.new({"hp": hp, "qi": qi, "max_qi": max_qi, "wolf_hp": stage.hp,
		"rocks": RAVINE_COVERS[variant] if tactic == "ravine" else stage.rooms[variant],
		"water": stage.water[variant] if stage.has("water") else [],
		"heavy": stage.heavy, "damage": stage.damage,
		"bite": stage.bite, "pace": stage.pace, "moon_bonus": bonus, "tactic": tactic,
		"jade_skin": arsenal.get("jade_skin", false), "leaves": arsenal.get("leaves", 0),
		"wolf_cell": stage.get("wolf_cell", 21), "moon_equipped": arsenal.get("moon_equipped", true),
		"refined_gu": arsenal.get("refined_gu", ""), "starter_gu": arsenal.get("starter_gu", ""),
		"revised_ward": revised_ward})


func perform(action: String, target: int = -1) -> Dictionary:
	if phase != "battle":
		return {"error": "Trận đã kết thúc."}
	var exchange: Dictionary = battle.take_turn(action, target)
	if exchange.has("error"):
		return exchange
	journal.append([action, target])
	if battle.result == Rules.DEFEAT:
		phase = "death"
	elif battle.result == Rules.VICTORY:
		if floor >= FLOORS.size():
			phase = "complete"
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
	var heal := FORD_HEAL if phase == "ford_workshop" else CHAPTER_HEAL
	return {"hp": mini(Rules.MAX_HP, battle.hp + heal),
		"qi": mini(battle.max_qi, battle.qi + CHAPTER_QI)}


func revised_ward_rules() -> bool:
	return version >= 5 or floor > FLOORS.size() or phase == "ford_workshop"


func can_cross_ford() -> bool:
	return phase == "complete" and floor == FLOORS.size()


func cross_ford() -> bool:
	if not can_cross_ford():
		return false
	phase = "ford_workshop"
	journal.append(["cross_ford"])
	return true


func equip_build(recipe: String, starter: String) -> bool:
	if phase not in ["refinement", "ford_workshop"] or recipe not in Gu.RECIPES or starter not in Gu.STARTERS:
		return false
	if not revised_ward_rules() and (recipe == "four_flavors" or starter == "brew"):
		return false
	var vitals := workshop_vitals()
	var arsenal := {"refined_gu": recipe, "moon_equipped": starter == "moon",
		"jade_skin": starter == "jade_skin", "starter_gu": starter, "leaves": battle.leaves}
	floor = FLOORS.size() + int(phase == "ford_workshop")
	battle = encounter(vitals.hp, vitals.qi, battle.max_qi, arsenal)
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
	if version == 4 and (phase == "ford_workshop" or floor > FLOORS.size()):
		saved.version = CURRENT_VERSION
		saved.chapter_rules = 4
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
		if saved.version != 5 or not finite_integer(saved.chapter_rules, 4, 4):
			return null
		rules_version = 4
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
				"victory":
					committed = run.version >= 4 and command[0] == "chapter_two" and run.begin_chapter()
				"complete":
					committed = saved.version >= 5 and command[0] == "cross_ford" and run.cross_ford()
				_:
					committed = run.reward(command[0])
			if not committed:
				return null
		elif command.size() != 2 or not finite_integer(command[1], -1, 39) or run.perform(command[0], int(command[1])).has("error"):
			return null
	if saved.has("chapter_rules") and run.phase != "ford_workshop" and run.floor <= FLOORS.size():
		return null
	return run


static func finite_integer(value: Variant, lower: int, upper: int) -> bool:
	return (value is int or value is float) and value >= lower and value <= upper and floorf(float(value)) == value
