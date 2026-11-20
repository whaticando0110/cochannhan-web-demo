extends RefCounted

const GU := {
	"moon": {"name": "Nguyệt Quang Cổ", "family": "lunar", "rank": 1},
	"moon_edge": {"name": "Nguyệt Mang Cổ", "family": "lunar", "rank": 2},
	"jade_skin": {"name": "Ngọc Bì Cổ", "family": "ward", "rank": 1},
	"white_jade": {"name": "Bạch Ngọc Cổ", "family": "ward", "rank": 2},
}
const FAMILIES := {"lunar": "Nguyệt", "ward": "Hộ thể"}
const STARTERS := ["moon", "jade_skin"]
const RECIPES := ["moon_edge", "white_jade"]
const MOON_EDGE_RANGE := 6
const MOON_EDGE_COST := 3
const MOON_EDGE_DAMAGE := 30
const MOON_MARK_BONUS := 12
const WHITE_JADE_COST := 2
const WHITE_JADE_ABSORB := 8
const WHITE_JADE_BONUS := 4
const WHITE_JADE_TURNS := 3
const WARD_COUNTER_BONUS := 8


static func build_family(recipe: String, starter: String) -> String:
	if recipe not in RECIPES or starter not in STARTERS:
		return ""
	var family: String = GU[recipe].family
	return family if GU[starter].family == family else ""


static func synergy_text(family: String) -> String:
	match family:
		"lunar":
			return "Nguyệt Quang đặt Nguyệt Ấn. Nguyệt Mang tiêu ấn để gây thêm %d sát thương." % MOON_MARK_BONUS
		"ward":
			return "Thay lớp Ngọc Bì để chặn thêm %d. Bạch Ngọc chặn đòn giúp Tay không kế tiếp gây thêm %d." % [WHITE_JADE_BONUS, WARD_COUNTER_BONUS]
	return ""
