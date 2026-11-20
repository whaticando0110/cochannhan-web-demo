extends Control

const Run = preload("res://run_state.gd")
const Rules = preload("res://battle_rules.gd")
const Gu = preload("res://gu_catalog.gd")
const Ceremony = preload("res://ceremony.gd")
const BattleScene = preload("res://combat_preview.tscn")
const HUYEN = preload("res://assets/huyen-bao-selection.png")
const REU = preload("res://assets/ao-reu-selection.png")
const GOLD := Color("#f1d89f")
const GREEN := Color("#a2d6aa")
const PALE := Color("#e3e9dc")
const TRAINING_STAGES := [Run.FLOORS[0], Run.ROUTES.ravine, Run.ROUTES.elite, Run.FLOORS[2], Run.CHAPTER_TWO]
const TRAINING_ROOMS := [0, 1, 1, 2, 3]
const TRAINING_TACTICS := ["", "ravine", "elite", "king", "storm"]
const TRAINING_BUILDS := [
	["Nhất chuyển", "", "moon"],
	["Bộ Nguyệt", "moon_edge", "moon"],
	["Bộ Hộ thể", "white_jade", "jade_skin"],
	["Nguyệt Mang + Ngọc Bì", "moon_edge", "jade_skin"],
	["Bạch Ngọc + Nguyệt Quang", "white_jade", "moon"],
]
const TRAINING_GRADES := ["Đinh đẳng", "Bính đẳng", "Ất đẳng", "Giáp đẳng"]

var save_path := "user://thanh-mao-run-v1.json"
var ceremony_limit := 0
var run: Run
var current: Control
var menu: Control
var headline := SystemFont.new()
var status: Label
var save_problem := false
var training_return: Callable
var training_options := {"opponent": 0, "grade": 0, "hero": 0, "qi": 4, "hp": Rules.MAX_HP,
	"jade_skin": false, "leaves": 0, "build": 0}


func _ready() -> void:
	headline.font_names = PackedStringArray(["Cambria", "Georgia"])
	if FileAccess.file_exists(save_path):
		run = Run.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	if run == null:
		show_entry()
	else:
		show_run()


func persist() -> void:
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_problem = true
		return
	file.store_string(JSON.stringify(run.snapshot()))
	var written := file.get_error() == OK
	file.close()
	save_problem = not written
	if written:
		save_problem = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),
			ProjectSettings.globalize_path(save_path)) != OK


func switch_to(view: Control) -> void:
	if current != null:
		remove_child(current)
		current.queue_free()
	current = view
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)


func panel(parent: Control, box: Rect2, tint: Color, border: Color) -> Panel:
	var node := Panel.new()
	node.position = box.position
	node.size = box.size
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node


func text(parent: Control, value: String, box: Rect2, px: int, tint: Color = PALE, serif: bool = false) -> Label:
	var node := Label.new()
	node.position = box.position
	node.size = box.size
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_color_override("font_color", tint)
	node.add_theme_font_size_override("font_size", px)
	if serif:
		node.add_theme_font_override("font", headline)
	parent.add_child(node)
	return node


func button(parent: Control, value: String, box: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.position = box.position
	node.size = box.size
	node.text = value
	node.add_theme_font_size_override("font_size", 20)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


func make_menu() -> Control:
	var next := Control.new()
	next.name = "RunMenu"
	return next


func hero_card(id: String, title: String, image: Texture2D, x: float) -> void:
	var card := panel(menu, Rect2(x, 258, 292, 265), Color("#192d27"), Color("#526f5f"))
	var portrait := TextureRect.new()
	portrait.texture = image
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(68, 16)
	portrait.size = Vector2(156, 156)
	card.add_child(portrait)
	var caption := text(card, title, Rect2(16, 166, 260, 39), 25, GOLD, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var choose := button(card, "Vào Đại điển", Rect2(24, 211, 244, 42), func(): show_ceremony(id))
	choose.name = id.replace("-", "_")


func show_entry() -> void:
	menu = make_menu()
	switch_to(menu)
	text(menu, "CỔ CHÂN NHÂN    /    THANH MAO SƠN", Rect2(94, 48, 980, 43), 20, GREEN)
	button(menu, "Luyện trận", Rect2(919, 53, 185, 44), open_training.bind(show_entry))
	var reborn := run != null and run.phase == "death"
	text(menu, "Hồi sinh" if reborn else "Đại điển Khai Khiếu", Rect2(92, 96, 1000, 83), 58, GOLD, true)
	var lead := "Chọn nhân vật để qua hang Nguyệt Lan. Tư chất quyết định sức chứa chân nguyên khi xuất trận."
	if reborn:
		lead = "Khai khiếu lại với một nhân vật hoặc giữ tư chất cũ để bắt đầu lượt mới."
	text(menu, lead, Rect2(96, 188, 1000, 49), 22)
	hero_card("huyen-bao", "Huyền bào", HUYEN, 160 if reborn else 296)
	hero_card("ao-reu", "Áo rêu", REU, 470 if reborn else 612)
	if reborn:
		var card := panel(menu, Rect2(787, 258, 292, 265), Color("#273128"), Color("#8b7850"))
		text(card, "Khai Khiếu trước", Rect2(22, 25, 250, 46), 28, GOLD, true)
		var hero_name := "Áo rêu" if run.profile.hero == "ao-reu" else "Huyền bào"
		text(card, "%s · %s\nNguyên Hải %d%% · %d chân nguyên" %
			[hero_name, run.profile.grade, run.profile.sea_pct, run.profile.max_qi], Rect2(22, 90, 250, 92), 19)
		var skip := button(card, "Bỏ qua Khai Khiếu", Rect2(24, 211, 244, 42), skip_ceremony)
		skip.name = "skip_ceremony"
	status = text(menu, "", Rect2(96, 674, 1000, 48), 17, PALE)
	report_save_problem()


func report_save_problem() -> void:
	if save_problem and is_instance_valid(status):
		status.text = "Không ghi được bản lưu. Bạn vẫn có thể chơi trong phiên này."


func show_ceremony(id: String) -> void:
	var next := Ceremony.new()
	next.name = "Ceremony"
	next.hero_id = id
	next.fixed_limit = ceremony_limit
	next.awakened.connect(start_new_run)
	next.back_requested.connect(show_entry)
	switch_to(next)


func start_new_run(profile: Dictionary) -> void:
	run = Run.new(profile, randi())
	persist()
	show_run()


func skip_ceremony() -> void:
	if run != null and run.phase == "death":
		start_new_run(run.profile)


func show_run() -> void:
	if run.phase != "battle":
		show_result()
		return
	var next := BattleScene.instantiate()
	next.configure(run)
	next.action_committed.connect(persist)
	next.battle_finished.connect(show_result)
	next.training_requested.connect(open_training.bind(show_run))
	switch_to(next)
	if save_problem:
		next.hint_label.text = "Không ghi được bản lưu. Lượt chơi vẫn tiếp tục."


func show_result() -> void:
	menu = make_menu()
	switch_to(menu)
	var section := "VƯỢT THANH MAO    /    MÀN %d TRÊN %d" % [run.floor + 1, Run.FLOORS.size()]
	if run.floor == Run.FLOORS.size() or run.phase == "refinement":
		section = "NHỊ CHUYỂN    /    SƯỜN ĐÁ MÙ SƯƠNG"
	text(menu, section, Rect2(96, 60, 815, 41), 19, GREEN)
	button(menu, "Luyện trận", Rect2(919, 58, 185, 44), open_training.bind(show_result))
	var floor: Dictionary = run.stage_at(run.floor)
	var title: String
	var description: String
	match run.phase:
		"route":
			title = "Chọn đường qua Thanh Mao"
			description = "Điện Lang đã gục. Chọn lối vào màn hai trước khi nhận chiến lợi phẩm."
		"reward":
			title = "Chọn chiến lợi phẩm"
			description = "Đã hạ %s. Chọn một món trước khi tới %s." % [floor.enemy, run.stage_at(run.floor + 1).name]
		"rest":
			title = "Dừng chân trước cửa hang"
			description = "Còn một khoảng yên tĩnh trước khi vào hang. Chọn một việc để chuẩn bị."
		"refinement":
			title = "Chọn bộ Cổ Nhị chuyển"
			description = "Mang một Cổ Nhị chuyển và một Cổ Nhất chuyển. Ghép cùng hệ để mở hiệu ứng bộ."
		"death":
			title = "Bạn đã gục"
			description = "Bạn gục ở %s. Hồi sinh đưa bạn về màn đầu." % floor.name
		"complete":
			title = "Vượt qua Sườn đá Mù Sương"
			description = "Điện Lang phóng lôi đã gục. Bạn hoàn thành màn Nhị chuyển đầu tiên."
		_:
			title = "Vượt qua Thanh Mao Sơn"
			description = "Cuồng Điện Lang đã gục. Bạn đã vượt qua cả ba màn."
	text(menu, title, Rect2(92, 119, 1020, 99), 56, GOLD, true)
	text(menu, description, Rect2(96, 231, 1020, 60), 23)
	if run.phase == "route":
		draw_routes()
	elif run.phase == "reward":
		draw_rewards()
	elif run.phase == "rest":
		draw_rest()
	elif run.phase == "refinement":
		draw_workshop()
	else:
		var next := button(menu, "Hồi sinh" if run.phase == "death" else "Lượt chơi mới",
			Rect2(96, 480 if run.phase in ["victory", "complete"] else 335, 316, 54), show_entry)
		next.name = "rebirth" if run.phase == "death" else "new_run"
		next.grab_focus()
		if run.phase == "victory":
			var picks := " · ".join(run.reward_history())
			var route_name := "Đường đã đi  ·  %s" % run.stage_at(1).name
			text(menu, route_name, Rect2(96, 305, 1000, 38), 21, GOLD)
			text(menu, "Chiến lợi phẩm  ·  %s" % picks, Rect2(96, 352, 1000, 38), 20)
			draw_vitals(405)
			if run.can_begin_chapter():
				var workshop := button(menu, "Sang Nhị chuyển", Rect2(432, 480, 310, 54), begin_chapter)
				workshop.name = "chapter_two"
				workshop.grab_focus()
		elif run.phase == "complete":
			var starter := "moon" if run.battle.moon_equipped else "jade_skin"
			text(menu, "Bộ đã dùng  ·  %s + %s" % [Gu.GU[starter].name, Gu.GU[run.battle.refined_gu].name],
				Rect2(96, 310, 1000, 49), 23, GOLD)
			draw_vitals(387)
	status = text(menu, "", Rect2(96, 674, 1000, 48), 17, PALE)
	report_save_problem()


func choose_reward(id: String) -> void:
	if run.reward(id):
		persist()
		show_run()


func choose_route(id: String) -> void:
	if run.choose_route(id):
		persist()
		show_result()


func draw_rest() -> void:
	var i := 0
	for id in Run.REST_OPTIONS:
		var preview: Dictionary = run.rest_preview(id)
		var card := panel(menu, Rect2(96 + i * 341, 316, 326, 208), Color("#1a2b25"), Color("#586c54"))
		text(card, Run.REST_OPTIONS[id], Rect2(18, 18, 290, 42), 28, GOLD, true)
		var delta := "Giữ nguyên sinh lực và chân nguyên."
		if id == "rest_hp":
			delta = "Sinh lực %d → %d" % [run.battle.hp, preview.hp]
		elif id == "rest_qi":
			delta = "Chân nguyên %d/%d → %d/%d" % [run.battle.qi, run.battle.max_qi, preview.qi, run.battle.max_qi]
		text(card, delta, Rect2(18, 68, 290, 54), 19, GREEN)
		var choice := button(card, "Chọn", Rect2(18, 146, 290, 44), choose_rest.bind(id))
		choice.name = id
		i += 1
	draw_vitals(546)


func choose_rest(id: String) -> void:
	if run.rest(id):
		persist()
		show_run()


func begin_chapter() -> void:
	if run.begin_chapter():
		persist()
		show_result()


func draw_workshop() -> void:
	for i in range(Gu.RECIPES.size()):
		var recipe: String = Gu.RECIPES[i]
		var family: String = Gu.GU[recipe].family
		var card := panel(menu, Rect2(96 + i * 516, 304, 492, 304), Color("#1a2b25"), Color("#586c54"))
		text(card, "Hệ %s · Nhị chuyển" % Gu.FAMILIES[family], Rect2(20, 15, 450, 32), 16, GREEN)
		text(card, Gu.GU[recipe].name, Rect2(20, 48, 450, 45), 31, GOLD, true)
		var stats := "%d sát thương · tầm %d ô · −%d chân nguyên" % [Gu.MOON_EDGE_DAMAGE, Gu.MOON_EDGE_RANGE, Gu.MOON_EDGE_COST]
		if family == "ward":
			stats = "Chặn %d · hiệu lực %d lượt · −%d chân nguyên" % [Gu.WHITE_JADE_ABSORB, Gu.WHITE_JADE_TURNS, Gu.WHITE_JADE_COST]
		text(card, stats, Rect2(20, 100, 450, 28), 17)
		text(card, Gu.synergy_text(family), Rect2(20, 138, 450, 51), 17, GREEN)
		for j in range(Gu.STARTERS.size()):
			var starter: String = Gu.STARTERS[j]
			var suffix := " · cùng hệ" if not Gu.build_family(recipe, starter).is_empty() else " · phối hệ"
			var choice := button(card, Gu.GU[starter].name + suffix, Rect2(20, 199 + j * 47, 452, 42),
				equip_build.bind(recipe, starter))
			choice.name = recipe + "_" + starter
	var vitals: Dictionary = run.workshop_vitals()
	text(menu, "Khi vào trận  ·  Sinh lực %d → %d  ·  Chân nguyên %d/%d → %d/%d  ·  Giữ Sinh Cơ Diệp ×%d" %
		[run.battle.hp, vitals.hp, run.battle.qi, run.battle.max_qi, vitals.qi, run.battle.max_qi, run.battle.leaves],
		Rect2(96, 621, 1008, 39), 19, GREEN)


func equip_build(recipe: String, starter: String) -> void:
	if run.equip_build(recipe, starter):
		persist()
		show_run()


func draw_vitals(y: float) -> void:
	var vitals := "Sinh lực %d / %d     ·     Chân nguyên %d / %d" % [run.battle.hp, Rules.MAX_HP, run.battle.qi, run.battle.max_qi]
	if run.battle.jade_skin:
		vitals += "     ·     Ngọc Bì"
	if run.battle.leaves > 0:
		vitals += "     ·     Sinh Cơ ×%d" % run.battle.leaves
	text(menu, vitals, Rect2(96, y, 980, 40), 20, GREEN)


func draw_routes() -> void:
	var i := 0
	for id in Run.ROUTES:
		var stage: Dictionary = Run.ROUTES[id]
		var elite: bool = id == "elite"
		var fill := Color("#302823") if elite else Color("#1a2d26")
		var edge := Color("#916c4d") if elite else Color("#577b64")
		var card := panel(menu, Rect2(96 + i * 516, 307, 490, 295), fill, edge)
		text(card, stage.name, Rect2(23, 22, 444, 45), 34, GOLD, true)
		text(card, "%s  ·  %d sinh lực" % [stage.enemy, stage.hp], Rect2(24, 88, 441, 31), 22)
		var danger := "%s  ·  %d sát thương" % [stage.heavy, stage.damage]
		if run.version >= 3:
			danger = "Vồ và lao xuyên hàng  ·  %d sát thương" % stage.damage if elite else "Vách đá chặn Nguyệt Quang"
		text(card, danger, Rect2(24, 122, 441, 28), 18)
		var heal := Run.ELITE_HEAL if elite else Run.NORMAL_HEAL
		var energy := Run.ELITE_QI if elite else Run.NORMAL_QI
		var benefit := "Hồi %d sinh lực hoặc %d chân nguyên" % [heal, energy]
		if elite:
			benefit += "\nCó món tăng sức chứa chân nguyên."
		elif run.version >= 3:
			benefit += "\nCó thể nhận Sinh Cơ Diệp sau trận."
		text(card, benefit, Rect2(24, 164, 441, 57), 18, GREEN if not elite else GOLD)
		var choose := button(card, "Chọn tuyến tinh anh" if elite else "Đi qua khe đá",
			Rect2(23, 231, 444, 45), choose_route.bind(id))
		choose.name = id
		i += 1
	draw_vitals(621)


func draw_rewards() -> void:
	var options: Dictionary = run.reward_options()
	var i := 0
	var width := (1008.0 - 15.0 * (options.size() - 1)) / options.size()
	for id in options:
		var option: Array = options[id]
		var preview: Dictionary = run.reward_preview(id)
		var card := panel(menu, Rect2(96 + i * (width + 15), 316, width, 269), Color("#1a2b25"), Color("#586c54"))
		var inner := width - 36
		text(card, option[0], Rect2(18, 18, inner, 66), 27, GOLD, true)
		text(card, option[1], Rect2(18, 94, inner, 54), 17)
		var delta := text(card, reward_delta(id, preview), Rect2(18, 160, inner, 44), 18, GREEN)
		delta.name = id + "_delta"
		var choose := button(card, "Nhận", Rect2(18, 207, inner, 44), choose_reward.bind(id))
		choose.name = id
		i += 1
	draw_vitals(606)


func reward_delta(id: String, preview: Dictionary) -> String:
	match id:
		"medicine":
			return "Sinh lực %d → %d" % [run.battle.hp, preview.hp]
		"stone":
			return "Chân nguyên %d/%d → %d/%d" % [run.battle.qi, run.battle.max_qi, preview.qi, preview.max_qi]
		"refine":
			return "Sát thương %d → %d" % [run.battle.moon_damage, run.battle.moon_damage - run.moon_bonus + preview.moon_bonus]
		"expand":
			return "Sức chứa %d → %d" % [run.battle.max_qi, preview.max_qi]
		"jade_skin":
			return "Mở lệnh Ngọc Bì cho lượt chơi"
		"vital_leaf":
			return "Số lá %d → %d" % [run.battle.leaves, preview.leaves]
	return ""


func open_training(return_to: Callable) -> void:
	training_return = return_to
	show_training_setup()


func dropdown(parent: Control, id: String, title: String, items: Array, selected: int, bounds: Rect2) -> OptionButton:
	text(parent, title, Rect2(bounds.position, Vector2(bounds.size.x, 34)), 18)
	var select := OptionButton.new()
	select.name = id
	select.position = bounds.position + Vector2(0, 42)
	select.size = bounds.size
	select.add_theme_font_size_override("font_size", 20)
	for item in items:
		select.add_item(item)
	select.select(selected)
	parent.add_child(select)
	return select


func show_training_setup() -> void:
	menu = make_menu()
	menu.name = "TrainingSetup"
	switch_to(menu)
	text(menu, "Luyện trận", Rect2(94, 75, 990, 95), 57, GOLD, true)
	text(menu, "Chọn đối thủ, sinh lực và Cổ để tập với cùng luật của Vượt Thanh Mao.",
		Rect2(96, 174, 1006, 56), 22)
	var card := panel(menu, Rect2(96, 252, 1008, 355), Color("#1a2b25"), Color("#586c54"))
	var opponent_items: Array = []
	for stage in TRAINING_STAGES:
		opponent_items.append(stage.enemy + " · " + stage.name)
	var opponent := dropdown(card, "training_opponent", "Đối thủ", opponent_items, training_options.opponent, Rect2(28, 27, 452, 48))
	var hero := dropdown(card, "training_hero", "Nhân vật", ["Huyền bào", "Áo rêu"], training_options.hero, Rect2(525, 27, 452, 48))
	var grades := dropdown(card, "training_grade", "Tư chất", TRAINING_GRADES, training_options.grade, Rect2(28, 147, 452, 48))
	text(card, "Chân nguyên ban đầu", Rect2(525, 147, 452, 34), 18)
	var qi := starting_value(card, "training_qi", Vector2(525, 189), 0, training_options.grade + 4, training_options.qi)
	text(card, "Sinh lực ban đầu", Rect2(757, 147, 220, 34), 18)
	var hp := starting_value(card, "training_hp", Vector2(757, 189), 1, Rules.MAX_HP, training_options.hp)
	var build_labels: Array = []
	for setup in TRAINING_BUILDS:
		build_labels.append(setup[0])
	var build := dropdown(card, "training_build", "Bộ Cổ", build_labels, training_options.build, Rect2(28, 252, 452, 43))
	var jade := training_check(card, "training_jade", "Thêm Ngọc Bì (Nhất chuyển)", Vector2(525, 258), training_options.jade_skin)
	var leaf := training_check(card, "training_leaf", "Mang một Sinh Cơ Diệp", Vector2(525, 301), training_options.leaves > 0)
	jade.disabled = build.selected != 0
	build.item_selected.connect(func(index: int): jade.disabled = index != 0)
	grades.item_selected.connect(func(index: int):
		var was_full := qi.value == qi.max_value
		qi.max_value = index + 4
		qi.suffix = "/ %d" % int(qi.max_value)
		if was_full:
			qi.value = qi.max_value)
	var back := button(menu, "Quay lại", Rect2(96, 631, 220, 52), training_return)
	back.name = "training_back"
	var begin := button(menu, "Bắt đầu luyện", Rect2(807, 631, 297, 52), func():
		training_options = {"opponent": opponent.selected, "grade": grades.selected, "hero": hero.selected,
			"qi": int(qi.value), "hp": int(hp.value), "jade_skin": jade.button_pressed, "leaves": int(leaf.button_pressed),
			"build": build.selected}
		show_training_battle())
	begin.name = "training_begin"


func starting_value(parent: Control, id: String, at: Vector2, minimum: int, maximum: int, value: int) -> SpinBox:
	var input := SpinBox.new()
	input.name = id
	input.position = at
	input.size = Vector2(204, 48)
	input.min_value = minimum
	input.max_value = maximum
	input.value = value
	input.suffix = "/ %d" % maximum
	input.get_line_edit().add_theme_font_size_override("font_size", 20)
	parent.add_child(input)
	return input


func training_check(parent: Control, id: String, title: String, at: Vector2, enabled: bool) -> CheckBox:
	var check := CheckBox.new()
	check.name = id
	check.text = title
	check.position = at
	check.size = Vector2(450, 45)
	check.button_pressed = enabled
	check.add_theme_font_size_override("font_size", 20)
	parent.add_child(check)
	return check


func show_training_battle() -> void:
	var next := BattleScene.instantiate()
	var grade_index: int = training_options.grade
	var opponent: int = training_options.opponent
	var build: Array = TRAINING_BUILDS[training_options.build]
	next.configure_training({"stage": TRAINING_STAGES[opponent], "room": TRAINING_ROOMS[opponent],
		"tactic": TRAINING_TACTICS[opponent], "hp": training_options.hp,
		"moon_equipped": build[2] == "moon", "refined_gu": build[1],
		"jade_skin": build[2] == "jade_skin" or (build[1].is_empty() and training_options.jade_skin), "leaves": training_options.leaves,
		"hero": "ao-reu" if training_options.hero == 1 else "huyen-bao",
		"grade": TRAINING_GRADES[grade_index], "max_qi": grade_index + 4, "qi": training_options.qi})
	next.training_setup_requested.connect(show_training_setup)
	switch_to(next)
