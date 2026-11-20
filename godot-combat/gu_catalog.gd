extends RefCounted

const GU := {
	"moon": {"name": "Nguyệt Quang Cổ", "family": "lunar", "rank": 1},
	"moon_edge": {"name": "Nguyệt Mang Cổ", "family": "lunar", "rank": 2},
	"jade_skin": {"name": "Ngọc Bì Cổ", "family": "ward", "rank": 1},
	"white_jade": {"name": "Bạch Ngọc Cổ", "family": "ward", "rank": 2},
	"brew": {"name": "Tửu Trùng", "family": "brew", "rank": 1},
	"four_flavors": {"name": "Tứ Vị Tửu Trùng", "family": "brew", "rank": 2},
}
const FAMILIES := {"lunar": "Nguyệt", "ward": "Hộ thể", "brew": "Tửu"}
const STARTERS := ["moon", "jade_skin", "brew"]
const RECIPES := ["moon_edge", "white_jade", "four_flavors"]
const MOON_EDGE_RANGE := 6
const MOON_EDGE_COST := 3
const MOON_EDGE_DAMAGE := 30
const MOON_MARK_BONUS := 12
const WHITE_JADE_COST := 2
const WHITE_JADE_ABSORB := 8
const WHITE_JADE_BONUS := 4
const WHITE_JADE_TURNS := 3
const WARD_COUNTER_BONUS := 8
const WHITE_JADE_REVISED_ABSORB := 11
const REVISED_COUNTER_BONUS := 10
const BREW_CHARGES := 2
const BREW_QI := 2
const FOUR_FLAVORS_COST := 2
const BREW_STRIKE_BONUS := 12


static func build_family(recipe: String, starter: String) -> String:
	if recipe not in RECIPES or starter not in STARTERS:
		return ""
	var family: String = GU[recipe].family
	return family if GU[starter].family == family else ""


static func synergy_text(family: String, revised_ward: bool = true) -> String:
	match family:
		"lunar":
			return "Nguyệt Quang đặt ấn. Nguyệt Mang tiêu ấn, gây thêm %d sát thương." % MOON_MARK_BONUS
		"ward":
			var counter := REVISED_COUNTER_BONUS if revised_ward else WARD_COUNTER_BONUS
			var discount := " và giảm 1 CN" if revised_ward else ""
			return "Thay Ngọc Bì chặn thêm %d%s. Chặn thành công tăng %d sát thương Tay không." % [WHITE_JADE_BONUS, discount, counter]
		"brew":
			return "Dùng Tửu Trùng trước để Tứ Vị cường hóa hai cú Tay không."
	return ""
