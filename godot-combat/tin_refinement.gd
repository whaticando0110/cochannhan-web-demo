extends RefCounted

const HEAT_NAMES := ["Thấp", "Vừa", "Cao"]
const STAGES := ["Sơ chế", "Dung hợp", "Định hình"]
const RECIPES := [[1, 2, 1], [1, 0, 1], [2, 1, 0]]
const START_HEAT := [0, 1, 2]
const TURN_LIMIT := 7

const HEAT_UP := "tin_heat_up"
const HEAT_DOWN := "tin_heat_down"
const REFINE := "tin_refine"

var recipe: Array
var heat: int
var turns := 0
var progress := 0
var won := false
var lost := false
var report := "Cả hai bên nhận cùng một phần nguyên liệu."


func _init(layout: int) -> void:
	recipe = RECIPES[layout]
	heat = START_HEAT[layout]


func opponent_progress() -> int:
	if lost:
		return STAGES.size()
	return mini(STAGES.size() - 1, floori(turns / 2.0))


func unavailable(action: String) -> String:
	if won or lost:
		return "Vòng đã kết thúc."
	match action:
		HEAT_UP:
			return "Lửa đã ở mức cao." if heat == HEAT_NAMES.size() - 1 else ""
		HEAT_DOWN:
			return "Lửa đã ở mức thấp." if heat == 0 else ""
		REFINE:
			return ""
	return "Chỉ được điều lửa và luyện theo bí phương của đài."


func apply(action: String) -> bool:
	if not unavailable(action).is_empty():
		return false
	turns += 1
	match action:
		HEAT_UP:
			heat += 1
			report = "Bạn nâng lửa lên mức %s." % HEAT_NAMES[heat].to_lower()
		HEAT_DOWN:
			heat -= 1
			report = "Bạn hạ lửa xuống mức %s." % HEAT_NAMES[heat].to_lower()
		REFINE:
			if heat != recipe[progress]:
				report = "Sai nhiệt. Phôi chưa tiến thêm."
			else:
				report = "%s thành công." % STAGES[progress]
				progress += 1
	won = progress == STAGES.size()
	lost = not won and turns == TURN_LIMIT
	return true
