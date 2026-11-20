extends RefCounted

const CAMP_HEAL := 6
const CACHE_COST := 8
const CACHE_STONES := 3
const SPRING_COST := 2
const LEAF_PRICE := 3
const RELIC_PRICE := 4
const RELIC_TRADE_PRICE := 2
const RIDGE_STONES := 4
const FORD_STONES := 2
const TOKEN_BLOCK := 3
const DEN_HEAL := 16
const DEN_QI := 3
const REMEDY_HEAL := 10
const FANG_BONUS := 8
const RELIC_ORDER := ["reed_boots", "jade_token", "essence_pin"]
const RELICS := {
	"reed_boots": ["Giày cỏ lau", "Lần Di chuyển đầu mỗi trận đi thêm 1 ô."],
	"jade_token": ["Ngọc bài hộ thân", "Chặn tối đa 3 sát thương còn lại của đòn đầu mỗi trận."],
	"essence_pin": ["Trâm tụ nguyên", "Bắt đầu mỗi trận với thêm 1 chân nguyên, tối đa đến trần."],
	"elite_fang": ["Nanh Tinh Anh", "Đòn đầu tiên gây sát thương mỗi trận được cộng %d sát thương." % FANG_BONUS],
}
const ELITE_REWARDS := {"elite_fang": "Nanh Tinh Anh", "elite_remedy": "Túi dược của thợ săn"}
