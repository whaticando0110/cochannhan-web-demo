extends RefCounted

const GU := {
	"moon": {"name": "Nguyệt Quang Cổ", "family": "lunar", "rank": 1},
	"small_light": {"name": "Tiểu Quang Cổ", "family": "lunar", "rank": 1},
	"moon_edge": {"name": "Nguyệt Mang Cổ", "family": "lunar", "rank": 2},
	"moon_link": {"name": "Liên Nguyệt", "family": "lunar", "rank": 2},
	"jade_skin": {"name": "Ngọc Bì Cổ", "family": "ward", "rank": 1},
	"white_boar": {"name": "Bạch Thỉ Cổ", "rank": 1},
	"dog_control": {"name": "Ngự Khuyển Cổ", "rank": 1},
	"white_jade": {"name": "Bạch Ngọc Cổ", "family": "ward", "rank": 2},
	"brew": {"name": "Tửu Trùng", "family": "brew", "rank": 1},
	"four_flavors": {"name": "Tứ Vị Tửu Trùng", "family": "brew", "rank": 2},
	"stone_veil": {"name": "Ẩn Thạch Cổ", "family": "veil", "rank": 1},
	"scale_veil": {"name": "Ẩn Lân Cổ", "family": "veil", "rank": 2},
}
const FAMILIES := {"lunar": "Nguyệt", "ward": "Hộ thể", "brew": "Tửu", "veil": "Ẩn"}
const BOOK_ORDER := ["moon", "small_light", "moon_edge", "jade_skin", "white_boar", "white_jade", "dog_control"]
const STARTERS := ["moon", "jade_skin", "brew", "stone_veil"]
const RECIPES := ["moon_edge", "white_jade", "four_flavors", "scale_veil"]
const MOON_LINK_COST := 4
const MOON_LINK_RANGE := 5
const MOON_LINK_DAMAGE := 42
const MOON_EDGE_RANGE := 6
const MOON_EDGE_COST := 3
const MOON_EDGE_DAMAGE := 30
const MOON_MARK_BONUS := 12
const WHITE_LIGHT_NAME := "Bạch Quang Hộ Thể"
const WHITE_LIGHT_COST := 3
const WHITE_LIGHT_ABSORB := 9
const WHITE_LIGHT_HITS := 2
const WHITE_LIGHT_TURNS := 3
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
const STONE_VEIL_COST := 1
const SCALE_VEIL_COST := 2
const SCALE_VEIL_TURNS := 2


static func build_family(recipe: String, starter: String) -> String:
	if recipe not in RECIPES or starter not in STARTERS:
		return ""
	var family: String = GU[recipe].family
	return family if GU[starter].family == family else ""


static func equip_description(id: String, revised_ward: bool) -> String:
	match id:
		"moon_edge":
			return "Nguyệt Mang gây %d sát thương, tầm %d ô, tốn %d chân nguyên." % [MOON_EDGE_DAMAGE, MOON_EDGE_RANGE, MOON_EDGE_COST]
		"white_jade":
			var block := WHITE_JADE_REVISED_ABSORB if revised_ward else WHITE_JADE_ABSORB
			return "Bạch Ngọc chặn %d sát thương, tốn %d chân nguyên." % [block, WHITE_JADE_COST]
		"four_flavors":
			return "Tứ Vị tăng %d sát thương cho cú Tay không kế tiếp, tốn %d chân nguyên." % [BREW_STRIKE_BONUS, FOUR_FLAVORS_COST]
		"scale_veil":
			return "Ẩn Lân làm trượt một đòn nhắm trực tiếp trong hai lượt, tốn %d chân nguyên." % SCALE_VEIL_COST
		"stone_veil":
			return "Ẩn Thạch chuẩn bị một bước đi tối đa ba ô, tốn %d chân nguyên." % STONE_VEIL_COST
		"jade_skin":
			return "Ngọc Bì tạo một lớp ngọc phòng ngự."
		"brew":
			return "Tửu Trùng hồi tối đa %d chân nguyên, dùng được %d lần mỗi trận." % [BREW_QI, BREW_CHARGES]
		_:
			return "Nguyệt Quang phóng nguyệt nhận tầm trung."


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
		"veil":
			return "Dùng Ẩn Thạch trước để Ẩn Lân chỉ tốn 1 chân nguyên và lần Di chuyển kế tiếp đi tối đa 4 ô."
	return ""
