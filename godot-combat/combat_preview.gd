extends Control

signal action_committed
signal battle_finished
signal training_requested
signal training_setup_requested

const Rules = preload("res://battle_rules.gd")
const Art = preload("res://combat_art.gd")
const Gu = preload("res://gu_catalog.gd")
const Goods = preload("res://waypoint_goods.gd")
const Arena = preload("res://arena.gd")
const RunData = preload("res://run_state.gd")
const PORTRAIT = preload("res://assets/huyen-bao-selection.png")
const REU_PORTRAIT = preload("res://assets/ao-reu-selection.png")
const GOLD := Color("#f1d89f")
const IVORY := Color("#f0e8d6")
const MUTE := Color("#aebfb4")
const GREEN := Color("#a2d6aa")
const CYAN := Color("#9ed6eb")
const RED := Color("#ec9b85")

var state: Rules = Rules.new()
var run: RunData
var room_title := "Rìa rừng Thanh Mao"
var enemy_name := "Điện Lang"
var hero_name := "Cổ sư Huyền bào"
var grade := "Đinh đẳng"
var skin := "huyen-bao"
var room := 0
var training: Dictionary = {}
var field: Arena
var turn_label: Label
var hp_label: Label
var qi_label: Label
var wolf_label: Label
var intent_name: Label
var intent_copy: Label
var report_label: Label
var hint_label: Label
var wards_label: Label
var relic_label: Label
var hp_bar: ProgressBar
var qi_bar: ProgressBar
var wolf_bar: ProgressBar
var reset_button: Button
var training_button: Button
var actions := {}
var report: Array[String] = []
var headline := SystemFont.new()
var busy := false
var selecting := false
var target_cell := -1
var hp_at_contact := -1


func _ready() -> void:
	headline.font_names = PackedStringArray(["Cambria", "Georgia", "Noto Serif"])
	build_hud()
	if run == null:
		reset_battle()
	else:
		show_battle()


func configure(current_run: RunData) -> void:
	run = current_run
	state = run.battle
	var floor_data: Dictionary = run.current_stage()
	var known_grade := "%s · Nguyên Hải %d%%" % [run.profile.grade, run.profile.sea_pct]
	var arena_room := run.floor
	if run.elite_room:
		arena_room = 1
	elif run.floor == RunData.BOSS_FLOOR:
		arena_room = 2
	elif run.floor == RunData.MARSH_FLOOR:
		arena_room = 4
	elif run.floor == RunData.WIND_FLOOR:
		arena_room = 5
	elif run.floor in [RunData.ALTAR_FLOOR, RunData.PULSE_FLOOR]:
		arena_room = 2
	elif run.floor == RunData.XOA_FLOOR:
		arena_room = 1
	configure_identity(floor_data, arena_room, run.profile.hero, known_grade)


func configure_training(settings: Dictionary) -> void:
	training = settings.duplicate()
	configure_identity(training.stage, training.room, training.hero, training.grade)
	state = training_battle()


func training_battle() -> Rules:
	return RunData.battle_for(training.stage, 0, training.hp, training.qi, training.max_qi, 0, training, training.tactic, true)


func configure_identity(stage: Dictionary, arena_room: int, chosen_skin: String, starting_grade: String) -> void:
	room_title = stage.name
	enemy_name = stage.enemy
	room = arena_room
	skin = chosen_skin
	grade = starting_grade
	hero_name = "Cổ sư Áo rêu" if skin == "ao-reu" else "Cổ sư Huyền bào"


func style(fill: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box


func set_bounds(node: Control, x: float, y: float, w: float, h: float) -> void:
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)
	add_child(node)


func label(text: String, x: float, y: float, w: float, h: float, text_size: int,
		tint: Color = IVORY, serif: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", text_size)
	node.add_theme_color_override("font_color", tint)
	if serif:
		node.add_theme_font_override("font", headline)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_bounds(node, x, y, w, h)
	return node


func panel(x: float, y: float, w: float, h: float, tint: Color = Color("#162822")) -> void:
	var node := Panel.new()
	node.add_theme_stylebox_override("panel", style(tint, Color("#3e5749"), 6))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_bounds(node, x, y, w, h)


func bar(x: float, y: float, w: float, tint: Color, maximum: int) -> ProgressBar:
	var node := ProgressBar.new()
	node.max_value = maximum
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", style(Color("#2b4037"), Color("#2b4037")))
	node.add_theme_stylebox_override("fill", style(tint, tint))
	set_bounds(node, x, y, w, 7)
	return node


func button(text: String, x: float, y: float, w: float, h: float) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", IVORY)
	node.add_theme_color_override("font_disabled_color", Color("#8a9d91"))
	node.add_theme_stylebox_override("normal", style(Color("#20362c"), Color("#536f5a"), 5))
	node.add_theme_stylebox_override("hover", style(Color("#30483b"), GOLD, 5))
	node.add_theme_stylebox_override("pressed", style(Color("#315740"), GREEN, 5))
	node.add_theme_stylebox_override("disabled", style(Color("#182a24"), Color("#33493e"), 5))
	set_bounds(node, x, y, w, h)
	return node


func build_hud() -> void:
	var area := "NAM CƯƠNG · NÚI TAM XOA" if state.tactic == "armored_hound" else "THANH MAO SƠN"
	label("CỔ CHÂN NHÂN  /  " + area, 36, 22, 600, 30, 17, GREEN)
	if Goods.RELICS.has(state.relic):
		relic_label = label("", 655, 10, 333, 31, 15, GOLD)
		relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		relic_label.mouse_filter = Control.MOUSE_FILTER_PASS
		relic_label.tooltip_text = Goods.RELICS[state.relic][1]
	label(room_title, 34, 48, 790, 60, 54, GOLD, true)
	var mode := "Trận theo lượt"
	if run != null and run.elite_room:
		mode = "Nhánh tinh anh"
	elif run != null and run.floor == RunData.MARSH_FLOOR:
		mode = "Tam chuyển · Màn 1"
	elif run != null and run.floor == RunData.WIND_FLOOR:
		mode = "Tam chuyển · Màn 2"
	elif run != null and run.floor == RunData.ALTAR_FLOOR:
		mode = "Tam chuyển · Màn 3"
	elif run != null and run.floor == RunData.PULSE_FLOOR:
		mode = "Tam chuyển · Boss cuối"
	elif run != null and run.floor == RunData.XOA_FLOOR:
		mode = "Tứ chuyển · Màn 1"
	elif run != null:
		mode = "Màn %d / %d" % [run.floor + 1, RunData.FLOORS.size()]
		if run.floor >= RunData.RIDGE_FLOOR:
			mode = "Nhị chuyển · %d/%d" % [run.floor - RunData.RIDGE_FLOOR + 1, 4 if run.version >= RunData.BOSS_VERSION else 3]
	elif not training.is_empty():
		mode = "Luyện trận"
	label("%s  ·  %s" % [mode, enemy_name], 38, 113, 600, 27, 20, MUTE)
	if not state.refined_gu.is_empty():
		var build := "Phối hệ" if state.build_family.is_empty() else "Bộ " + str(Gu.FAMILIES[state.build_family])
		var tag := label(build, 520, 110, 145, 27, 16, GREEN)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.tooltip_text = Gu.synergy_text(state.build_family, state.revised_ward)
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
	turn_label = label("", 678, 105, 160, 33, 20, GOLD, true)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wards_label = label("", 860, 105, 306, 33, 15, GREEN)
	wards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reset_button = button("Chơi lại trận", 1006, 44, 160, 46)
	reset_button.visible = run == null
	reset_button.pressed.connect(reset_battle)
	if run != null:
		training_button = button("Luyện trận", 1006, 44, 160, 46)
		training_button.pressed.connect(func(): training_requested.emit())
	elif not training.is_empty():
		training_button = button("Đổi thiết lập", 833, 44, 160, 46)
		training_button.pressed.connect(func(): training_setup_requested.emit())
	panel(33, 151, 805, 481)
	field = Arena.new()
	field.room = room
	field.skin = skin
	set_bounds(field, 34, 153, 803, 477)
	field.cell_selected.connect(select_cell)
	field.cell_focused.connect(inspect_cell)
	field.exchange_cue.connect(show_exchange)

	panel(860, 151, 306, 160)
	var portrait := TextureRect.new()
	portrait.texture = REU_PORTRAIT if field.skin == "ao-reu" else PORTRAIT
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_bounds(portrait, 869, 156, 55, 61)
	label(hero_name, 925, 160, 228, 31, 26, GOLD, true)
	label(grade, 926, 192, 223, 24, 15, MUTE)
	label("Sinh lực", 880, 222, 220, 21, 16, IVORY)
	hp_label = label("", 1054, 222, 94, 21, 16, GREEN)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_bar = bar(880, 248, 267, GREEN, Rules.MAX_HP)
	var gold_essence := state.tactic == "armored_hound"
	var qi_tint := GOLD if gold_essence else CYAN
	label("Chân nguyên hoàng kim" if gold_essence else "Chân nguyên", 880, 263, 169, 22, 16, IVORY)
	qi_label = label("", 1054, 263, 94, 22, 16, qi_tint)
	qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qi_bar = bar(880, 290, 267, qi_tint, state.max_qi)

	panel(860, 325, 306, 146, Color("#282a23"))
	label(enemy_name, 880, 337, 190, 30, 21, GOLD, true)
	wolf_label = label("", 1054, 342, 94, 24, 16, RED)
	wolf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wolf_bar = bar(880, 374, 267, RED, state.wolf_max)
	intent_name = label("", 880, 394, 266, 26, 21, RED, true)
	intent_copy = label("", 880, 425, 264, 40, 14, IVORY)
	intent_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	panel(860, 485, 306, 147)
	label("Diễn biến", 880, 496, 265, 31, 25, GOLD, true)
	report_label = label("", 880, 534, 264, 92, 14, MUTE)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.max_lines_visible = 4
	report_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var descriptions := [
		["move", "1   Di chuyển\nTối đa %d ô" % Rules.MOVE_RANGE],
		["strike", "2   Tay không\n%d sát thương · +1 CN" % (Rules.STRIKE_DAMAGE + state.strike_bonus)],
	]
	if state.moon_equipped:
		descriptions.append(["moon", "3   Nguyệt Quang\nTầm %d ô · −%d CN" % [Rules.MOON_RANGE, Rules.MOON_COST]])
	elif state.starter_gu == "brew":
		descriptions.append(["brew", "3   Tửu Trùng\n+%d chân nguyên" % Gu.BREW_QI])
	elif state.starter_gu == "stone_veil":
		descriptions.append(["stone_veil", "3   Ẩn Thạch\nBước ẩn 3 ô · −%d CN" % Gu.STONE_VEIL_COST])
	descriptions.append(["guard", "4   Thủ thế\nGiảm %d%% · +1 CN" % roundi(Rules.GUARD_REDUCTION * 100)])
	if state.jade_skin:
		descriptions.append(["jade_skin", "5   Ngọc Bì Cổ\nChặn %d · −%d CN" % [Rules.JADE_ABSORB, Rules.JADE_COST]])
	if state.leaves > 0:
		descriptions.append(["vital_leaf", "6   Sinh Cơ Diệp\nHồi ≤%d sinh lực" % Rules.LEAF_HEAL])
	if state.refined_gu == "moon_edge":
		descriptions.append(["moon_edge", "7   Nguyệt Mang\nTầm %d ô · −%d CN" % [Gu.MOON_EDGE_RANGE, Gu.MOON_EDGE_COST]])
	elif state.refined_gu == "white_jade":
		descriptions.append(["white_jade", "7   Bạch Ngọc"])
	elif state.refined_gu == "four_flavors":
		descriptions.append(["four_flavors", "7   Tứ Vị Tửu Trùng\nTay không +%d · −%d CN" % [Gu.BREW_STRIKE_BONUS, Gu.FOUR_FLAVORS_COST]])
	elif state.refined_gu == "scale_veil":
		descriptions.append(["scale_veil", "7   Ẩn Lân"])
	var width := (1132.0 - 12.0 * (descriptions.size() - 1)) / descriptions.size()
	for index in range(descriptions.size()):
		var row: Array = descriptions[index]
		var action: String = row[0]
		var node := button(row[1], 34 + index * (width + 12), 648, width, 67)
		if Art.ICONS.has(action):
			node.icon = Art.ICONS[action]
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.add_theme_constant_override("icon_max_width", 20)
		if descriptions.size() > 5:
			node.add_theme_font_size_override("font_size", 15)
		node.pressed.connect(func(): choose(action))
		node.mouse_entered.connect(inspect_action.bind(action))
		node.focus_entered.connect(inspect_action.bind(action))
		node.mouse_exited.connect(show_hint)
		node.focus_exited.connect(show_hint)
		actions[action] = node
	hint_label = label("", 35, 728, 1125, 25, 15, MUTE)


func update_hero_hp(value: int) -> void:
	hp_label.text = "%d / %d" % [value, Rules.MAX_HP]
	hp_bar.value = value


func update_player_contact() -> void:
	qi_label.text = "%d / %d" % [state.qi, state.max_qi]
	wolf_label.text = "%d / %d" % [state.wolf_hp, state.wolf_max]
	qi_bar.value = state.qi
	wolf_bar.value = state.wolf_hp


func update_hud() -> void:
	update_hero_hp(state.hp)
	update_player_contact()
	var supplies: PackedStringArray = []
	if state.jade_turns > 0:
		supplies.append("Ngọc %d · %d lượt" % [state.ward_strength, state.jade_turns])
	if state.moon_mark:
		supplies.append("Có Nguyệt Ấn")
	if state.counter_ready:
		supplies.append("Phản đòn +%d" % state.counter_bonus())
	if state.brew_ready:
		supplies.append("Dưỡng tửu")
	if state.strong_strikes > 0:
		supplies.append("Tinh nguyên ×%d" % state.strong_strikes)
	if state.veil_turns > 0:
		supplies.append("Ẩn Lân · %d lượt" % state.veil_turns)
	if actions.has("vital_leaf"):
		supplies.append("Sinh Cơ ×%d" % state.leaves)
	if state.tactic == "seal_altar":
		supplies.append("Vỡ giáp · %d lượt" % state.seal_turns if state.seal_turns > 0 else "Thạch Giáp · chặn %d" % Rules.ALTAR_ARMOR)
	elif state.tactic == "armored_hound":
		supplies.append("Thiết Giáp · %s" % ("phía Tây" if state.hound_facing < 0 else "phía Đông"))
	wards_label.text = "    ".join(supplies)
	if is_instance_valid(relic_label):
		var status := " · Sẵn sàng" if state.relic_ready else " · Đã dùng"
		if state.relic == "essence_pin":
			status = ""
		relic_label.text = str(Goods.RELICS[state.relic][0]) + status
	turn_label.text = "Lượt %02d" % state.turn
	match state.result:
		Rules.VICTORY:
			intent_name.text = "Thắng trận"
			intent_copy.text = "Bạn đã hạ %s." % enemy_name
		Rules.DEFEAT:
			intent_name.text = "Bạn đã gục"
			intent_copy.text = "Chọn Chơi lại trận hoặc nhấn R." if run == null else "Lượt chơi đã kết thúc."
		_:
			intent_name.text = state.intent.name
			if state.enraged_phase():
				intent_name.text += " · Cuồng nộ"
			if state.intent.get("pattern") == "row":
				intent_copy.text = "Hàng %d · %d sát thương. Rời hàng để né." % [int(state.intent.row) + 1, state.intent.damage]
			elif state.intent.get("pattern") == "hound_rush":
				intent_copy.text = "Húc về %s · %d sát thương. Né sang hàng khác." % [
					"Tây" if state.hound_facing < 0 else "Đông", state.intent.damage]
			elif state.intent.kind == "shot":
				intent_copy.text = "Hồ quang khóa ô %s · %d sát thương." % [Rules.cell_name(state.intent.cells[0]), state.intent.damage]
			elif state.intent.kind == "flood":
				intent_copy.text = "Nước tím gây %d sát thương. Hãy lên ô khô." % state.intent.damage
			elif state.intent.kind == "fall":
				intent_copy.text = "Đá rơi vào ô nứt · %d sát thương." % state.intent.damage
			elif state.intent.kind == "ambush":
				var scope := "Nhắm vào ô bạn đang đứng" if state.tactic in ["marsh", "wind_pass"] else "Vồ vùng quanh bạn"
				intent_copy.text = "%s · %d sát thương." % [scope, state.intent.damage]
			elif state.intent.kind == "poison":
				intent_copy.text = "Ô vàng lục · %d sát thương · −1 CN nếu mất sinh lực." % state.intent.damage
			elif state.intent.kind == "wind":
				var direction := "Tây → Đông" if state.intent.direction > 0 else "Đông → Tây"
				intent_copy.text = "%s · %d sát thương. Nấp sau đá." % [direction, state.intent.damage]
			elif state.intent.kind == "seal_burst":
				intent_copy.text = "Vùng 3 × 3 quanh bạn · %d sát thương." % state.intent.damage
			elif state.intent.kind == "core_wave":
				var distance_text := "≤" if state.intent.inner else ">"
				intent_copy.text = "Cách boss %s %d ô · %d sát thương." % [distance_text, state.intent.radius, state.intent.damage]
			elif state.intent.kind == "thunder":
				var pattern := "Cả hàng và cột" if state.intent.cross else "Hàng đang đứng"
				intent_copy.text = "%s · %d sát thương. Rời vùng tím." % [pattern, state.intent.damage]
			elif state.intent.kind == "recover":
				match state.tactic:
					"thunder_boss":
						intent_copy.text = "Đòn trúng được cộng %d sát thương." % Rules.THUNDER_OPEN_BONUS
					"marsh":
						intent_copy.text = "Tay không được cộng %d sát thương." % Rules.MARSH_JAW_BONUS
					"pulse_boss":
						intent_copy.text = "Đòn trúng được cộng %d sát thương." % Rules.PULSE_OPEN_BONUS if state.pulse_open else "Thạch Vương đang hồi thế."
					_:
						intent_copy.text = "Đối thủ hồi thế trong lượt này."
			elif state.intent.damage > 0:
				intent_copy.text = "Gây %d sát thương ở vùng gạch đỏ sau hành động của bạn." % state.intent.damage
			else:
				intent_copy.text = "%s sẽ tiến về phía bạn." % enemy_name
	report_label.text = "\n".join(report.slice(0, 3))
	actions.move.text = "1   Di chuyển\nTối đa %d ô" % state.movement_range()
	if actions.has("brew"):
		actions.brew.text = "3   Tửu Trùng\n+%d CN · còn %d" % [Gu.BREW_QI, state.brew_left]
	if actions.has("white_jade"):
		var block := state.white_jade_absorb() + (Gu.WHITE_JADE_BONUS if state.can_upgrade_ward() else 0)
		actions.white_jade.text = "7   Bạch Ngọc\nChặn %d · −%d CN" % [block, state.white_jade_cost()]
	if actions.has("scale_veil"):
		actions.scale_veil.text = "7   Ẩn Lân\nMất dấu · −%d CN" % state.scale_veil_cost()
	for action in actions:
		var control: Button = actions[action]
		control.disabled = busy or not state.unavailable(action).is_empty()
		control.tooltip_text = state.unavailable(action)
	actions.move.modulate = GREEN if selecting else Color.WHITE


func reset_battle() -> void:
	if busy or run != null:
		return
	if training.is_empty():
		state = Rules.new()
	else:
		state = training_battle()
	if is_instance_valid(qi_bar):
		qi_bar.max_value = state.max_qi
		wolf_bar.max_value = state.wolf_max
	show_battle()


func show_battle() -> void:
	selecting = false
	target_cell = -1
	field.clear_effects()
	field.set_selecting(false)
	field.set_state(state)
	report.assign(["%s đang chuẩn bị hành động." % enemy_name])
	update_hud()
	show_hint()
	reset_button.release_focus()


func show_hint() -> void:
	field.show_cover_ray(0)
	if busy or not state.result.is_empty():
		return
	if selecting:
		if state.intent.kind == "wind":
			hint_label.text = "Ô lục an toàn. Ô có mũi tên nằm trong luồng gió. Bấm ô hoặc dùng phím mũi tên + Enter."
		else:
			hint_label.text = "Ô xanh né được đòn. Ô có dấu báo đòn vẫn có thể bị đánh. Bấm ô hoặc dùng phím mũi tên + Enter."
	else:
		if state.tactic == "ford":
			hint_label.text = "Đi được qua nước nông. Ô nước chuyển tím khi có điện. Vách đá chặn đòn đánh xa."
		elif state.tactic == "ambush":
			hint_label.text = "Ô nứt đi được. Khi ô nứt sáng hổ phách, đá sẽ rơi vào đó sau lượt của bạn."
		else:
			hint_label.text = "Vách đá chặn đòn đánh xa. Chọn lệnh để xem kết quả dự kiến." if state.uses_cover() else "Địch đáp trả sau hành động của bạn. Chọn lệnh để xem kết quả dự kiến."


func show_exchange(cue: String) -> void:
	match cue:
		"player":
			hint_label.text = "Bạn đang hành động…"
		"player_contact":
			update_player_contact()
			update_hero_hp(hp_at_contact)
		"enemy":
			hint_label.text = "%s đang đáp trả…" % enemy_name
		"enemy_contact":
			update_hero_hp(state.hp)


func inspect_action(action: String) -> void:
	if busy or not state.result.is_empty():
		return
	field.show_cover_ray(shot_range(action))
	if action == "move":
		hint_label.text = "Chọn Di chuyển để thấy các ô đến được trong %d bước." % state.movement_range()
		return
	var result := state.preview_action(action)
	if result.has("error"):
		hint_label.text = result.error
		return
	var pieces: PackedStringArray = []
	if result.dealt > 0:
		pieces.append("Gây %d sát thương" % result.dealt)
	if result.set_trigger:
		match action:
			"moon_edge":
				pieces.append("Kích phát Nguyệt Ấn")
			"white_jade":
				pieces.append("Ghép Ngọc Bì → Bạch Ngọc")
			"strike":
				pieces.append("Phản đòn +%d" % state.counter_bonus() if state.counter_ready else "Tinh nguyên +%d" % Gu.BREW_STRIKE_BONUS)
			"scale_veil":
				pieces.append("Bước ẩn kế tiếp tối đa 4 ô")
	elif action == "moon" and result.moon_mark and not state.moon_mark:
		pieces.append("Đặt Nguyệt Ấn")
	if result.healed > 0:
		pieces.append("Hồi %d sinh lực" % result.healed)
	if result.absorbed > 0:
		pieces.append("Lớp ngọc chặn %d" % result.absorbed)
	elif result.jade_turns > 0:
		pieces.append("Lớp ngọc %d · còn %d lượt" % [result.ward_strength, result.jade_turns])
	if result.relic_block > 0:
		pieces.append("%s chặn %d" % [Goods.RELICS[state.relic][0], result.relic_block])
	if result.relic_damage > 0:
		pieces.append("Nanh Tinh Anh +%d" % result.relic_damage)
	if action != "move" and result.relic_qi > 0:
		pieces.append("Châu Hoàn Nguyên hoàn %d chân nguyên" % result.relic_qi)
	if result.exposed_damage > 0:
		var opening: String = state.intent.name
		if state.tactic == "seal_altar":
			opening = "Vỡ Thạch Giáp"
		elif state.tactic == "armored_hound":
			opening = "Đánh sườn"
		pieces.append("%s +%d" % [opening, result.exposed_damage])
	if result.armor_block > 0:
		pieces.append("%s chặn %d" % ["Thiết Giáp" if state.tactic == "armored_hound" else "Thạch Giáp", result.armor_block])
	if result.qi_drained > 0:
		pieces.append("Độc rút %d chân nguyên" % result.qi_drained)
	if result.receives > 0:
		pieces.append("Chịu %d sát thương%s" % [result.receives, " sau khi đỡ" if action == "guard" else ""])
	elif result.dealt >= state.wolf_hp:
		pieces.append("Kết liễu đối thủ trước khi địch đáp trả")
	elif result.healed == 0 and result.absorbed == 0 and result.relic_block == 0:
		pieces.append("Lượt này giữ nguyên sinh lực")
	if result.healed > 0 or result.absorbed > 0 or result.relic_block > 0:
		pieces.append("Sinh lực còn %d/%d" % [state.hp + result.healed - result.receives, Rules.MAX_HP])
	if action == "brew" and result.brew_ready:
		pieces.append("Chuẩn bị bộ Tửu")
	if action == "four_flavors":
		pieces.append("Cường hóa %d cú Tay không" % result.strong_strikes)
	if action == "stone_veil":
		pieces.append("Bước ẩn kế tiếp tối đa 3 ô")
	if result.evaded:
		pieces.append("Ẩn Lân làm đòn nhắm trượt")
	elif action == "scale_veil" and result.veil_turns > 0:
		pieces.append("Ẩn Lân còn %d lượt" % result.veil_turns)
	pieces.append("Chân nguyên còn %d/%d" % [result.qi, state.max_qi])
	hint_label.text = "  ·  ".join(pieces)


func inspect_cell(cell: int) -> void:
	if not selecting or busy:
		return
	if cell < 0:
		show_hint()
		return
	target_cell = cell
	var preview := state.preview_action("move", cell)
	var name := Rules.cell_name(cell)
	if preview.has("error"):
		hint_label.text = "%s · %s" % [name, "Ô có đá chặn." if cell in state.rocks else "Ô này ngoài tầm hoặc đang bị chiếm."]
		return
	var outcome: String
	if preview.evaded:
		outcome = "Ẩn Lân làm đối thủ mất dấu"
	elif preview.absorbed > 0:
		outcome = "Lớp ngọc chặn %d · còn chịu %d sát thương" % [preview.absorbed, preview.receives]
	elif preview.relic_block > 0:
		outcome = "Ngọc bài chặn %d · còn chịu %d sát thương" % [preview.relic_block, preview.receives]
	elif preview.receives > 0:
		outcome = "Vẫn nằm trong vùng đánh · chịu %d sát thương" % preview.receives
	elif not state.intent.cells.is_empty():
		outcome = "Ra khỏi vùng đánh · né được đòn"
	else:
		outcome = "Giữ nguyên sinh lực trong lượt này"
	var qi_note := " · mất %d chân nguyên" % preview.qi_drained if preview.qi_drained > 0 else ""
	if preview.relic_qi > 0:
		qi_note = " · Ấn Dẫn Phong hồi %d chân nguyên" % preview.relic_qi
	if cell in state.runes:
		qi_note += " · Khóa Thạch Giáp %d lượt" % preview.seal_turns
	hint_label.text = "%s · %d bước · %s%s" % [name, preview.steps, outcome, qi_note]


func choose(action: String) -> void:
	if busy:
		return
	var reason := state.unavailable(action)
	if not reason.is_empty():
		field.show_cover_ray(shot_range(action))
		hint_label.text = reason
		return
	if action == "move":
		selecting = not selecting
		field.set_selecting(selecting)
		target_cell = state.hero if selecting else -1
		if selecting:
			field.grab_focus()
		else:
			field.release_focus()
		show_hint()
		update_hud()
		return
	resolve(action)


func shot_range(action: String) -> int:
	if action == "moon_edge" and state.refined_gu == action:
		return Gu.MOON_EDGE_RANGE
	return Rules.MOON_RANGE if action == "moon" and state.moon_equipped else 0


func select_cell(cell: int) -> void:
	if selecting and not busy:
		resolve("move", cell)


func resolve(action: String, cell: int = -1) -> void:
	var exchange: Dictionary = state.take_turn(action, cell) if run == null else run.perform(action, cell)
	if exchange.has("error"):
		hint_label.text = exchange.error
		return
	hp_at_contact = state.hp + int(exchange.hero_damage)
	field.show_cover_ray(0)
	busy = true
	action_committed.emit()
	selecting = false
	field.set_selecting(false)
	for control in actions.values():
		control.disabled = true
	reset_button.disabled = true
	if is_instance_valid(training_button):
		training_button.disabled = true
	await field.play_exchange(exchange)
	busy = false
	reset_button.disabled = false
	if is_instance_valid(training_button):
		training_button.disabled = false
	for note in exchange.notes:
		report.push_front(note)
	report = report.slice(0, 4)
	update_hud()
	if state.result.is_empty():
		show_hint()
	elif run == null:
		hint_label.text = "Nhấn R hoặc chọn Chơi lại trận."
	else:
		battle_finished.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var third := state.starter_gu if state.starter_gu in ["brew", "stone_veil"] else "moon"
	var key_actions := {KEY_1: "move", KEY_2: "strike", KEY_3: third,
		KEY_4: "guard", KEY_5: "jade_skin", KEY_6: "vital_leaf"}
	if key_actions.has(event.keycode):
		choose(key_actions[event.keycode])
	elif event.keycode == KEY_7 and not state.refined_gu.is_empty():
		choose(state.refined_gu)
	elif event.keycode == KEY_R and run == null:
		reset_battle()
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if selecting and not busy and event is InputEventKey and event.pressed and not event.echo:
		if navigate_selection(event.keycode):
			get_viewport().set_input_as_handled()


func navigate_selection(code: Key) -> bool:
	var arrows := {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		select_cell(target_cell)
	elif arrows.has(code):
		var point: Vector2i = Rules.grid(target_cell) + arrows[code]
		if Rect2i(0, 0, Rules.COLUMNS, Rules.ROWS).has_point(point):
			field.point_to(point.y * Rules.COLUMNS + point.x)
	else:
		return false
	return true
