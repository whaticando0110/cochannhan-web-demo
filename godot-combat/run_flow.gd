extends Control

const Run = preload("res://run_state.gd")
const Rules = preload("res://battle_rules.gd")
const Gu = preload("res://gu_catalog.gd")
const Goods = preload("res://waypoint_goods.gd")
const Ceremony = preload("res://ceremony.gd")
const BattleScene = preload("res://combat_preview.tscn")
const HUYEN = preload("res://assets/huyen-bao-selection.png")
const REU = preload("res://assets/ao-reu-selection.png")
const GOLD := Color("#f1d89f")
const GREEN := Color("#a2d6aa")
const PALE := Color("#e3e9dc")
const TRAINING_STAGES := [Run.FLOORS[0], Run.ROUTES.ravine, Run.ROUTES.elite, Run.FLOORS[2],
	Run.CHAPTER_TWO, Run.THUNDER_FORD, Run.AMBUSH_PASS, Run.THUNDER_GATE]
const TRAINING_ROOMS := [0, 1, 1, 2, 3, 4, 5, 2]
const TRAINING_TACTICS := ["", "ravine", "elite", "king", "storm", "ford", "ambush", "thunder_boss"]
const TRAINING_GRADES := ["Đinh đẳng", "Bính đẳng", "Ất đẳng", "Giáp đẳng"]

var save_path := "user://thanh-mao-run-v1.json"
var ceremony_limit := 0
var run: Run
var current: Control
var menu: Control
var headline := SystemFont.new()
var status: Label
var save_problem := false
var boss_seal := false
var training_return: Callable
var training_options := {"opponent": 0, "grade": 0, "hero": 0, "qi": 4, "hp": Rules.MAX_HP,
	"jade_skin": false, "leaves": 0, "build": 0}


func _ready() -> void:
	headline.font_names = PackedStringArray(["Cambria", "Georgia"])
	if FileAccess.file_exists(save_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		run = Run.restore(saved)
		if run != null:
			var seal: Variant = saved.get("boss_seal", false)
			boss_seal = run.phase == "chapter_cleared" or (seal is bool and seal)
	if run == null:
		show_entry()
	else:
		show_run()


func persist() -> void:
	boss_seal = boss_seal or run.phase == "chapter_cleared"
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		save_problem = true
		return
	var saved := run.snapshot()
	if boss_seal:
		saved.boss_seal = true
	file.store_string(JSON.stringify(saved))
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
	if boss_seal:
		text(menu, Run.BOSS_SEAL + " · Đã mở Lôi Nha Trấn Ải trong Luyện trận",
			Rect2(96, 593, 1008, 38), 19, GOLD)
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
	if run.floor >= Run.RIDGE_FLOOR or run.phase == "refinement":
		var stage_number := maxi(1, run.floor - Run.RIDGE_FLOOR + 1)
		stage_number += int(run.phase in ["ford_workshop", "ambush_workshop", "waypoint", "shop", "boss_workshop"])
		section = "NHỊ CHUYỂN    /    %d TRÊN %d" % [stage_number, 4 if run.version >= Run.BOSS_VERSION else 3]
	if run.elite_room or run.phase == "elite_workshop":
		section = "NHỊ CHUYỂN    /    NHÁNH TINH ANH"
	if run.floor == Run.MARSH_FLOOR or run.phase == "marsh_workshop":
		section = "TAM CHUYỂN    /    MÀN 1"
	if run.floor == Run.WIND_FLOOR or run.phase == "wind_workshop":
		section = "TAM CHUYỂN    /    MÀN 2"
	text(menu, section, Rect2(96, 60, 815, 41), 19, GREEN)
	button(menu, "Luyện trận", Rect2(919, 58, 185, 44), open_training.bind(show_result))
	var floor: Dictionary = run.current_stage()
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
		"ford_workshop":
			title = "Chuẩn bị qua Suối Sấm"
			description = "Giữ bộ %s + %s hoặc đổi trước khi xuống suối." % [
				Gu.GU[run.battle.starter_gu].name, Gu.GU[run.battle.refined_gu].name]
		"ambush_workshop":
			title = "Chuẩn bị vào Hẻm Đá"
			description = "Nghỉ ở chân hẻm và chọn bộ trước trận phục kích." if run.elite_award.is_empty() else (
				"Đã hạ đầu đàn và nhận %s. Chọn bộ Cổ trước khi vào Hẻm Đá." % Goods.ELITE_REWARDS[run.elite_award])
		"elite_workshop":
			title = Run.ELITE_DEN.name
			description = "Điện Lang đầu đàn có %d sinh lực, luân phiên vồ vùng và lao xuyên hàng. Có một lượt hồi thế sau mỗi đòn lớn." % Run.ELITE_DEN.hp
		"elite_reward":
			title = "Chiến lợi phẩm tinh anh"
			description = "Chọn một món trước khi trở lại đường chính. Cả hai lựa chọn đều hồi tối đa %d sinh lực và %d chân nguyên." % [Goods.DEN_HEAL, Goods.DEN_QI]
		"boss_workshop":
			title = Run.THUNDER_GATE.name
			description = "Lôi Nha quét ngang. Khi còn nửa sinh lực, nó đánh cả hàng và cột. Ra khỏi vùng tím rồi phản công lúc hở lôi giáp."
		"chapter_cleared":
			title = "Hoàn thành Nhị chuyển"
			description = "Đã hạ Lôi Nha Trấn Ải. Ấn Trấn Lôi được lưu và mở trận này để luyện riêng."
		"marsh_workshop":
			title = Run.POISON_MARSH.name
			description = "Né vùng độc vàng lục và cú táp nhắm vào ô bạn đứng. Sau cú táp, áp sát đánh Tay không lúc Điện Lang hở hàm."
		"marsh_reward":
			title = "Chiến lợi phẩm Đầm Rễ Độc"
			description = "Đã vượt màn đầu Tam chuyển. Chọn một phần thưởng để giữ trong lượt chơi."
		"marsh_cleared":
			title = "Vượt qua Đầm Rễ Độc"
			description = "Đã nhận %s. Đường lên Hẻm Hàn Phong đã mở." % Run.MARSH_REWARDS[run.marsh_award]
		"wind_workshop":
			title = Run.WIND_PASS.name
			description = "Gió cắt đổi hướng sau mỗi đợt. Tìm ô khuất ở sau đá theo chiều gió, rồi né cú vồ nhắm."
		"wind_reward":
			title = "Chiến lợi phẩm Hẻm Hàn Phong"
			description = "Đã vượt màn hai Tam chuyển. Chọn bảo vật hoặc tiếp tế cho lượt chơi."
		"wind_cleared":
			title = "Vượt qua Hẻm Hàn Phong"
			description = "Đã nhận %s." % Run.WIND_REWARDS[run.wind_award]
		"waypoint":
			title = "Dừng chân bên Suối Sấm" if run.floor == Run.RIDGE_FLOOR else "Dừng chân dưới Hẻm Đá"
			description = "Chọn một điểm dừng. Có thể xem trước chi phí và tài nguyên khi rời đi."
		"shop":
			title = "Quầy đổi đồ"
			description = "Mỗi món mua được một lần tại quầy. Bảo vật mới thay món đang mang."
		"death":
			title = "Bạn đã gục"
			description = "Bạn gục ở %s. Hồi sinh đưa bạn về màn đầu." % floor.name
		"complete":
			title = "Vượt qua " + str(floor.name)
			if run.can_cross_ford():
				description = "Bến đá phía trước dẫn qua Suối Sấm."
			elif run.can_enter_pass():
				description = "Dấu chân Điện Lang dẫn vào hẻm đá bên kia suối."
			elif run.can_enter_boss():
				description = "Lôi Nha Đài nằm cuối hẻm. Chuẩn bị lần cuối trước khi đối đầu Lôi Nha Trấn Ải."
			else:
				description = "Bạn đã vượt qua cả ba màn Nhị chuyển."
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
	elif run.phase in ["refinement", "ford_workshop", "ambush_workshop", "elite_workshop", "boss_workshop", "marsh_workshop", "wind_workshop"]:
		draw_workshop()
	elif run.phase == "elite_reward":
		draw_elite_rewards()
	elif run.phase == "marsh_reward":
		draw_marsh_rewards()
	elif run.phase == "wind_reward":
		draw_wind_rewards()
	elif run.phase == "waypoint":
		draw_waypoint()
	elif run.phase == "shop":
		draw_shop()
	else:
		var can_end_at_pass := run.version < Run.BOSS_VERSION
		if not run.can_enter_boss() or can_end_at_pass:
			var next := button(menu, "Hồi sinh" if run.phase == "death" else "Lượt chơi mới",
				Rect2(96, 335 if run.phase == "death" else 480, 316, 54), show_entry)
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
		elif run.phase in ["complete", "chapter_cleared"]:
			text(menu, "Bộ đã dùng  ·  %s + %s" % [Gu.GU[run.battle.starter_gu].name, Gu.GU[run.battle.refined_gu].name],
				Rect2(96, 310, 1000, 49), 23, GOLD)
			draw_vitals(387)
			if run.can_cross_ford():
				var crossing := button(menu, "Tới Suối Sấm", Rect2(432, 480, 310, 54), cross_ford)
				crossing.name = "cross_ford"
				crossing.grab_focus()
			elif run.can_enter_pass():
				var crossing := button(menu, "Tới Hẻm Đá", Rect2(432, 480, 310, 54), enter_pass)
				crossing.name = "enter_pass"
				crossing.grab_focus()
			elif run.can_enter_boss():
				var gate := button(menu, "Tới Lôi Nha Đài", Rect2(432 if can_end_at_pass else 96, 480, 316, 54), enter_boss)
				gate.name = "enter_boss"
				gate.grab_focus()
			elif run.phase == "chapter_cleared":
				var path_name := "Qua Ổ Điện Lang · %s" % Goods.ELITE_REWARDS[run.elite_award] if not run.elite_award.is_empty() else "Đường thẳng qua Hẻm Đá"
				text(menu, path_name, Rect2(96, 352, 1008, 34), 18, GREEN)
				var climb := button(menu, "Sang Tam chuyển", Rect2(432, 480, 310, 54), enter_marsh)
				climb.name = "enter_marsh"
				climb.grab_focus()
		elif run.phase == "marsh_cleared":
			draw_vitals(355)
			var head_up := button(menu, "Tới Hẻm Hàn Phong", Rect2(432, 480, 310, 54), enter_wind_pass)
			head_up.name = "enter_wind_pass"
			head_up.grab_focus()
		elif run.phase == "wind_cleared":
			draw_vitals(355)
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


func cross_ford() -> void:
	if run.cross_ford():
		persist()
		show_result()


func enter_pass() -> void:
	if run.enter_pass():
		persist()
		show_result()


func enter_boss() -> void:
	if run.enter_boss():
		persist()
		show_result()


func enter_marsh() -> void:
	if run.enter_marsh():
		persist()
		show_result()


func enter_wind_pass() -> void:
	if run.enter_wind_pass():
		persist()
		show_result()


func draw_waypoint() -> void:
	var entries := {
		"camp": ["Lều nghỉ", "Băng bó trước khi đi. Hồi tối đa %d sinh lực." % Goods.CAMP_HEAL],
		"merchant": ["Quầy đổi đồ", "Xem Sinh Cơ Diệp và %s." % Goods.RELICS[run.shop_relic()][0]],
		"salvage": ["Túi bên bờ đá", "Băng qua đá sắc để nhặt thêm nguyên thạch."],
		"spring": ["Mạch nước trong khe", "Dùng chân nguyên lấy một lá Sinh Cơ Diệp."],
		"elite_detour": [Run.ELITE_DEN.name, "Đấu Điện Lang đầu đàn · %d sinh lực." % Run.ELITE_DEN.hp],
	}
	var vitals: Dictionary = run.workshop_vitals()
	var options := run.waypoint_options()
	var width := (1008.0 - 18 * (options.size() - 1)) / options.size()
	var i := 0
	for id in options:
		var next: Dictionary = run.waypoint_preview(id)
		var border := Color("#b0925d") if id == "elite_detour" else Color("#586c54")
		var card := panel(menu, Rect2(96 + i * (width + 18), 308, width, 258), Color("#1a2b25"), border)
		var inner := width - 36
		text(card, entries[id][0], Rect2(18, 14, inner, 62), 25 if options.size() == 4 else 28, GOLD, true)
		text(card, entries[id][1], Rect2(18, 82, inner, 63), 17)
		var detail: String
		match id:
			"camp":
				detail = "Sinh lực %d → %d" % [vitals.hp, next.hp]
			"salvage":
				detail = "Sinh lực %d → %d\nNguyên thạch %d → %d" % [vitals.hp, next.hp, run.stones, next.stones]
			"spring":
				detail = "Chân nguyên %d → %d\nSố lá %d → %d" % [run.departure_qi(), next.departure_qi, vitals.leaves, next.leaves]
			"elite_detour":
				detail = "Nhánh tự chọn\nNanh hoặc túi dược"
			_:
				detail = "Giá lá %d · Bảo vật %d nguyên thạch." % [run.shop_price("buy_leaf"), run.shop_price("buy_relic")]
		if not next.reason.is_empty():
			detail = next.reason
		text(card, detail, Rect2(18, 145, inner, 57), 17, GREEN)
		var select := button(card, "Săn tinh anh" if id == "elite_detour" else "Chọn",
			Rect2(18, 201, inner, 43), choose_waypoint.bind(id))
		select.name = id
		select.disabled = not next.reason.is_empty()
		i += 1
	draw_waypoint_vitals(584)
	var encounter_hint := "Suối Sấm · Nước tím báo dẫn lôi." if run.floor == Run.RIDGE_FLOOR else "Hẻm Đá · Ô nứt sáng báo đá rơi."
	text(menu, encounter_hint, Rect2(96, 628, 1008, 32), 18, GOLD)


func draw_elite_rewards() -> void:
	var held := "Ô bảo vật đang trống." if run.relic.is_empty() else "Thay %s đang mang." % Goods.RELICS[run.relic][0]
	var details := {"elite_fang": Goods.RELICS.elite_fang[1] + "\n" + held,
		"elite_remedy": "Hồi thêm tối đa %d sinh lực và nhận một Sinh Cơ Diệp. Giữ bảo vật đang mang." % Goods.REMEDY_HEAL}
	var i := 0
	for id in Goods.ELITE_REWARDS:
		var next: Dictionary = run.elite_reward_preview(id)
		var card := panel(menu, Rect2(96 + i * 514, 312, 494, 288), Color("#1a2b25"), Color("#b0925d"))
		text(card, Goods.ELITE_REWARDS[id], Rect2(20, 13, 450, 54), 31, GOLD, true)
		text(card, details[id], Rect2(20, 76, 452, 90), 19)
		text(card, "Sinh lực %d → %d    ·    Chân nguyên %d → %d\nSinh Cơ Diệp %d → %d" %
			[run.battle.hp, next.hp, run.battle.qi, next.qi, run.battle.leaves, next.leaves],
			Rect2(20, 175, 452, 51), 17, GREEN)
		var claim := button(card, "Nhận và tới Hẻm Đá", Rect2(20, 234, 454, 41), claim_elite_reward.bind(id))
		claim.name = id
		i += 1


func claim_elite_reward(id: String) -> void:
	if run.claim_elite_reward(id):
		persist()
		show_result()


func draw_marsh_rewards() -> void:
	var details := {"purifying_dew": "Thêm 1 sức chứa chân nguyên và hồi đầy.",
		"marsh_tonic": "Hồi tối đa %d sinh lực và nhận %d Sinh Cơ Diệp." % [Run.TONIC_HEAL, Run.TONIC_LEAVES]}
	var i := 0
	for id in Run.MARSH_REWARDS:
		var next: Dictionary = run.marsh_reward_preview(id)
		var card := panel(menu, Rect2(96 + i * 514, 310, 494, 236), Color("#1a2b25"), Color("#71935d"))
		text(card, Run.MARSH_REWARDS[id], Rect2(20, 13, 450, 54), 31, GOLD, true)
		text(card, details[id], Rect2(20, 72, 452, 58), 19)
		text(card, "Sinh lực %d → %d  ·  Chân nguyên %d/%d → %d/%d\nSinh Cơ Diệp %d → %d" %
			[run.battle.hp, next.hp, run.battle.qi, run.battle.max_qi, next.qi, next.max_qi, run.battle.leaves, next.leaves],
			Rect2(20, 128, 452, 54), 17, GREEN)
		var claim := button(card, "Nhận phần thưởng", Rect2(20, 183, 454, 41), claim_marsh_reward.bind(id))
		claim.name = id
		i += 1


func claim_marsh_reward(id: String) -> void:
	if run.claim_marsh_reward(id):
		persist()
		show_result()


func draw_wind_rewards() -> void:
	var carried := "Ô bảo vật đang trống." if run.relic.is_empty() else "Thay %s đang mang." % Goods.RELICS[run.relic][0]
	var details := {"wind_seal": Goods.RELICS.wind_seal[1] + "\n" + carried,
		"wind_supplies": "Hồi tối đa %d chân nguyên và nhận %d Sinh Cơ Diệp. Giữ bảo vật đang mang." %
		[Run.WIND_SUPPLY_QI, Run.WIND_SUPPLY_LEAVES]}
	var i := 0
	for id in Run.WIND_REWARDS:
		var next: Dictionary = run.wind_reward_preview(id)
		var card := panel(menu, Rect2(96 + i * 514, 310, 494, 289), Color("#1c2b2e"), Color("#6d9295"))
		text(card, Run.WIND_REWARDS[id], Rect2(20, 13, 450, 54), 31, GOLD, true)
		text(card, details[id], Rect2(20, 72, 452, 116), 18)
		text(card, "Chân nguyên %d/%d → %d/%d    ·    Sinh Cơ Diệp %d → %d" %
			[run.battle.qi, run.battle.max_qi, next.qi, run.battle.max_qi, run.battle.leaves, next.leaves],
			Rect2(20, 194, 452, 38), 17, GREEN)
		var claim := button(card, "Nhận phần thưởng", Rect2(20, 234, 454, 41), claim_wind_reward.bind(id))
		claim.name = id
		i += 1


func claim_wind_reward(id: String) -> void:
	if run.claim_wind_reward(id):
		persist()
		show_result()


func draw_shop() -> void:
	var for_sale: Array = Goods.RELICS[run.shop_relic()]
	var offers := [
		["buy_leaf", "Sinh Cơ Diệp", "Hồi tối đa %d sinh lực khi dùng một lá trong trận." % Rules.LEAF_HEAL],
		["buy_relic", for_sale[0], for_sale[1]],
	]
	for i in range(offers.size()):
		var offer: Array = offers[i]
		var id: String = offer[0]
		var card := panel(menu, Rect2(96 + i * 513, 308, 495, 218), Color("#1a2b25"), Color("#586c54"))
		text(card, offer[1], Rect2(18, 15, 459, 42), 28, GOLD, true)
		text(card, offer[2], Rect2(18, 69, 459, 58), 18)
		var reason := run.shop_unavailable(id)
		var price := "Giá %d nguyên thạch" % run.shop_price(id)
		text(card, price if reason.is_empty() else reason, Rect2(18, 125, 459, 28), 17, GREEN)
		var exchange := id == "buy_relic" and run.shop_price(id) == Goods.RELIC_TRADE_PRICE
		var purchase := button(card, "Đổi bảo vật" if exchange else "Mua", Rect2(18, 159, 459, 43), buy_waypoint_item.bind(id))
		purchase.name = id
		purchase.disabled = not reason.is_empty()
	draw_waypoint_vitals(541)
	var exit_shop := button(menu, "Rời quầy", Rect2(844, 607, 260, 49), leave_waypoint_shop)
	exit_shop.name = "leave_shop"


func draw_waypoint_vitals(y: float) -> void:
	var now: Dictionary = run.workshop_vitals()
	var trinket: String = Goods.RELICS[run.relic][0] if not run.relic.is_empty() else "Ô bảo vật trống"
	var summary := "Sinh lực %d/%d   ·   Chân nguyên %d/%d   ·   Số lá %d   ·   Túi %d nguyên thạch   ·   %s"
	text(menu, summary % [now.hp, Rules.MAX_HP, run.departure_qi(), run.battle.max_qi, now.leaves, run.stones, trinket],
		Rect2(96, y, 1008, 44), 18, GREEN)


func choose_waypoint(id: String) -> void:
	if run.choose_waypoint(id):
		persist()
		show_result()


func buy_waypoint_item(id: String) -> void:
	if run.buy(id):
		persist()
		show_result()


func leave_waypoint_shop() -> void:
	if run.leave_shop():
		persist()
		show_result()


func draw_workshop() -> void:
	var revised := run.revised_ward_rules()
	var count := run.workshop_size()
	var card := panel(menu, Rect2(96, 298, 1008, 332), Color("#1a2b25"), Color("#586c54"))
	var recipes: Array = []
	var starters: Array = []
	for i in range(count):
		var refined: Dictionary = Gu.GU[Gu.RECIPES[i]]
		var basic: Dictionary = Gu.GU[Gu.STARTERS[i]]
		recipes.append("%s  ·  %s" % [refined.name, Gu.FAMILIES[refined.family]])
		starters.append("%s  ·  %s" % [basic.name, Gu.FAMILIES[basic.family]])
	var recipe := dropdown(card, "workshop_recipe", "Cổ Nhị chuyển", recipes,
		maxi(0, Gu.RECIPES.find(run.battle.refined_gu)), Rect2(24, 18, 450, 46))
	var starter := dropdown(card, "workshop_starter", "Cổ Nhất chuyển", starters,
		maxi(0, Gu.STARTERS.find(run.battle.starter_gu)), Rect2(528, 18, 454, 46))
	var blend := text(card, "", Rect2(24, 126, 948, 32), 24, GOLD, true)
	var stats := text(card, "", Rect2(24, 170, 956, 54), 17)
	var synergy := text(card, "", Rect2(24, 228, 952, 34), 17, GREEN)
	var refresh := func(_index: int):
		var advanced_id: String = Gu.RECIPES[recipe.selected]
		var first_id: String = Gu.STARTERS[starter.selected]
		var family := Gu.build_family(advanced_id, first_id)
		blend.text = "Phối hệ" if family.is_empty() else "Bộ " + str(Gu.FAMILIES[family])
		stats.text = "%s\n%s" % [Gu.equip_description(advanced_id, revised), Gu.equip_description(first_id, revised)]
		synergy.text = Gu.synergy_text(family, revised)
	recipe.item_selected.connect(refresh)
	starter.item_selected.connect(refresh)
	refresh.call(0)
	var fight := button(card, "Vào trận với bộ này", Rect2(676, 270, 306, 44),
		func(): equip_build(Gu.RECIPES[recipe.selected], Gu.STARTERS[starter.selected]))
	fight.name = "equip_confirm"
	var vitals: Dictionary = run.workshop_vitals()
	text(menu, "Khi vào trận  ·  Sinh lực %d → %d  ·  Chân nguyên %d/%d → %d/%d  ·  Giữ Sinh Cơ Diệp ×%d" %
		[run.battle.hp, vitals.hp, run.battle.qi, run.battle.max_qi, run.departure_qi(), run.battle.max_qi, vitals.leaves],
		Rect2(96, 644, 1008, 39), 18, GREEN)


func training_builds() -> Array:
	var builds := [["Nhất chuyển", "", "moon"]]
	for recipe in Gu.RECIPES:
		for starter in Gu.STARTERS:
			var family := Gu.build_family(recipe, starter)
			var caption := "%s + %s" % [Gu.GU[recipe].name, Gu.GU[starter].name]
			if not family.is_empty():
				caption = "Bộ " + str(Gu.FAMILIES[family])
			builds.append([caption, recipe, starter])
	return builds


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
	if run.version >= 7 and run.floor >= Run.RIDGE_FLOOR:
		vitals += "     ·     %d nguyên thạch" % run.stones
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
	for stage in TRAINING_STAGES.slice(0, TRAINING_STAGES.size() if boss_seal else TRAINING_STAGES.size() - 1):
		opponent_items.append(stage.enemy + " · " + stage.name)
	var opponent := dropdown(card, "training_opponent", "Đối thủ", opponent_items, training_options.opponent, Rect2(28, 27, 452, 48))
	var hero := dropdown(card, "training_hero", "Nhân vật", ["Huyền bào", "Áo rêu"], training_options.hero, Rect2(525, 27, 452, 48))
	var grades := dropdown(card, "training_grade", "Tư chất", TRAINING_GRADES, training_options.grade, Rect2(28, 147, 452, 48))
	text(card, "Chân nguyên ban đầu", Rect2(525, 147, 452, 34), 18)
	var qi := starting_value(card, "training_qi", Vector2(525, 189), 0, training_options.grade + 4, training_options.qi)
	text(card, "Sinh lực ban đầu", Rect2(757, 147, 220, 34), 18)
	var hp := starting_value(card, "training_hp", Vector2(757, 189), 1, Rules.MAX_HP, training_options.hp)
	var build_labels: Array = []
	for setup in training_builds():
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
	var build: Array = training_builds()[training_options.build]
	next.configure_training({"stage": TRAINING_STAGES[opponent], "room": TRAINING_ROOMS[opponent],
		"tactic": TRAINING_TACTICS[opponent], "hp": training_options.hp,
		"moon_equipped": build[2] == "moon", "refined_gu": build[1], "starter_gu": build[2],
		"jade_skin": build[2] == "jade_skin" or (build[1].is_empty() and training_options.jade_skin), "leaves": training_options.leaves,
		"hero": "ao-reu" if training_options.hero == 1 else "huyen-bao",
		"grade": TRAINING_GRADES[grade_index], "max_qi": grade_index + 4, "qi": training_options.qi})
	next.training_setup_requested.connect(show_training_setup)
	switch_to(next)
