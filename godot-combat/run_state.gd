extends RefCounted

const Rules = preload("res://battle_rules.gd")
const Awakening = preload("res://awakening_rules.gd")
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
}
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


func _init(awakened: Dictionary, run_seed: int, save_version: int = 2) -> void:
	profile = awakened
	seed = run_seed
	version = save_version
	battle = encounter(Rules.MAX_HP, profile.max_qi, profile.max_qi)


func stage_at(index: int) -> Dictionary:
	if index == 1 and version == 2 and ROUTES.has(route):
		return ROUTES[route]
	return FLOORS[index]


func encounter(hp: int, qi: int, max_qi: int) -> Rules:
	var stage := stage_at(floor)
	var variant := floori(seed / pow(3, floor)) % 3
	return Rules.new({"hp": hp, "qi": qi, "max_qi": max_qi, "wolf_hp": stage.hp,
		"rocks": stage.rooms[variant], "heavy": stage.heavy, "damage": stage.damage,
		"bite": stage.bite, "pace": stage.pace, "moon_bonus": moon_bonus})


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
		if floor == FLOORS.size() - 1:
			phase = "victory"
		else:
			phase = "route" if floor == 0 and version == 2 else "reward"
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
	return options


func reward_preview(id: String) -> Dictionary:
	if not reward_options().has(id):
		return {}
	var outcome := {"hp": battle.hp, "qi": battle.qi, "max_qi": battle.max_qi, "moon_bonus": moon_bonus}
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
	return outcome


func reward(id: String) -> bool:
	var outcome := reward_preview(id)
	if outcome.is_empty():
		return false
	moon_bonus = outcome.moon_bonus
	floor += 1
	phase = "battle"
	battle = encounter(outcome.hp, outcome.qi, outcome.max_qi)
	journal.append([id])
	return true


func reward_history() -> PackedStringArray:
	var picked: PackedStringArray = []
	for command in journal:
		if command.size() == 1 and REWARD_NAMES.has(command[0]):
			picked.append(REWARD_NAMES[command[0]])
	return picked


func snapshot() -> Dictionary:
	return {"version": version, "hero": profile.hero, "depth": profile.depth, "seed": seed, "journal": journal}


static func restore(saved: Variant) -> RefCounted:
	if not saved is Dictionary or not finite_integer(saved.get("version"), 1, 2) or not saved.get("journal") is Array:
		return null
	if not saved.get("hero") is String or not finite_integer(saved.get("depth"), 12, 49):
		return null
	if not finite_integer(saved.get("seed"), 0, 0xffffffff):
		return null
	var profile_data := Awakening.profile_for(saved.hero, int(saved.depth))
	if profile_data.is_empty():
		return null
	var run = load("res://run_state.gd").new(profile_data, int(saved.seed), int(saved.version))
	for command in saved.journal:
		if not command is Array or command.is_empty() or not command[0] is String:
			return null
		if command.size() == 1:
			var committed: bool = run.choose_route(command[0]) if run.phase == "route" else run.reward(command[0])
			if not committed:
				return null
		elif command.size() != 2 or not finite_integer(command[1], -1, 39) or run.perform(command[0], int(command[1])).has("error"):
			return null
	return run


static func finite_integer(value: Variant, lower: int, upper: int) -> bool:
	return (value is int or value is float) and value >= lower and value <= upper and floorf(float(value)) == value
