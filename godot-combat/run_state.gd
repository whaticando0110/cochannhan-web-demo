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
const REWARDS := {
	"medicine": ["Dược thảo", "Hồi tối đa 24 sinh lực"],
	"stone": ["Nguyên thạch", "+1 sức chứa và hồi đầy chân nguyên"],
	"refine": ["Luyện Nguyệt Quang", "+7 sát thương Nguyệt Quang trong lượt này"],
}

var profile: Dictionary
var seed: int
var floor := 0
var moon_bonus := 0
var phase := "battle"
var battle: Rules
var journal: Array = []


func _init(awakened: Dictionary, run_seed: int) -> void:
	profile = awakened
	seed = run_seed
	battle = encounter(Rules.MAX_HP, profile.max_qi, profile.max_qi)


func encounter(hp: int, qi: int, max_qi: int) -> Rules:
	var stage: Dictionary = FLOORS[floor]
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
		phase = "victory" if floor == FLOORS.size() - 1 else "reward"
	return exchange


func reward(id: String) -> bool:
	if phase != "reward" or not REWARDS.has(id):
		return false
	var hp: int = battle.hp
	var max_qi: int = battle.max_qi
	var qi: int = battle.qi
	match id:
		"medicine":
			hp = mini(Rules.MAX_HP, hp + 24)
		"stone":
			max_qi += 1
			qi = max_qi
		"refine":
			moon_bonus += 7
	floor += 1
	phase = "battle"
	battle = encounter(hp, qi, max_qi)
	journal.append([id])
	return true


func snapshot() -> Dictionary:
	return {"version": 1, "hero": profile.hero, "depth": profile.depth, "seed": seed, "journal": journal}


static func restore(saved: Variant) -> RefCounted:
	if not saved is Dictionary or saved.get("version") != 1 or not saved.get("journal") is Array:
		return null
	if not saved.get("hero") is String or not finite_integer(saved.get("depth"), 12, 49):
		return null
	if not finite_integer(saved.get("seed"), 0, 0xffffffff):
		return null
	var profile_data := Awakening.profile_for(saved.hero, int(saved.depth))
	if profile_data.is_empty():
		return null
	var run = load("res://run_state.gd").new(profile_data, int(saved.seed))
	for command in saved.journal:
		if not command is Array or command.is_empty() or not command[0] is String:
			return null
		if command.size() == 1:
			if not run.reward(command[0]):
				return null
		elif command.size() != 2 or not finite_integer(command[1], -1, 39) or run.perform(command[0], int(command[1])).has("error"):
			return null
	return run


static func finite_integer(value: Variant, lower: int, upper: int) -> bool:
	return (value is int or value is float) and value >= lower and value <= upper and floorf(float(value)) == value
