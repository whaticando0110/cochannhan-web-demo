extends Control

const Run = preload("res://run_state.gd")
const Ceremony = preload("res://ceremony.gd")
const BattleScene = preload("res://combat_preview.tscn")
const HUYEN = preload("res://assets/huyen-bao-selection.png")
const REU = preload("res://assets/ao-reu-selection.png")
const GOLD := Color("#f1d89f")
const GREEN := Color("#a2d6aa")
const PALE := Color("#e3e9dc")

var save_path := "user://thanh-mao-run-v1.json"
var ceremony_limit := 0
var run: Run
var current: Control
var menu: Control
var headline := SystemFont.new()
var status: Label
var save_problem := false


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
	switch_to(next)
	if save_problem:
		next.hint_label.text = "Không ghi được bản lưu. Lượt chơi vẫn tiếp tục."


func show_result() -> void:
	menu = make_menu()
	switch_to(menu)
	text(menu, "VƯỢT THANH MAO    /    MÀN %d TRÊN %d" % [run.floor + 1, Run.FLOORS.size()],
		Rect2(96, 60, 1000, 41), 19, GREEN)
	var floor: Dictionary = Run.FLOORS[run.floor]
	var title: String
	var description: String
	match run.phase:
		"reward":
			title = "Chọn chiến lợi phẩm"
			description = "Đã hạ %s. Chọn một món trước khi tới %s." % [floor.enemy, Run.FLOORS[run.floor + 1].name]
		"death":
			title = "Bạn đã gục"
			description = "Bạn gục ở %s. Hồi sinh đưa bạn về màn đầu." % floor.name
		_:
			title = "Vượt qua Thanh Mao Sơn"
			description = "Cuồng Điện Lang đã gục. Bạn đã vượt qua cả ba màn."
	text(menu, title, Rect2(92, 119, 1020, 99), 56, GOLD, true)
	text(menu, description, Rect2(96, 231, 1020, 60), 23)
	if run.phase == "reward":
		var i := 0
		for id in Run.REWARDS:
			var reward: Array = Run.REWARDS[id]
			var card := panel(menu, Rect2(96 + i * 337, 324, 312, 222), Color("#1a2b25"), Color("#586c54"))
			text(card, reward[0], Rect2(20, 20, 270, 63), 28, GOLD, true)
			text(card, reward[1], Rect2(20, 88, 269, 52), 18)
			var choose := button(card, "Nhận chiến lợi phẩm", Rect2(20, 158, 272, 45), func(): choose_reward(id))
			choose.name = id
			i += 1
		text(menu, "Sinh lực %d / 48     ·     Chân nguyên %d / %d" % [run.battle.hp, run.battle.qi, run.battle.max_qi],
			Rect2(96, 580, 980, 40), 20, GREEN)
	else:
		var next := button(menu, "Hồi sinh" if run.phase == "death" else "Lượt chơi mới",
			Rect2(96, 335, 316, 54), show_entry)
		next.name = "rebirth" if run.phase == "death" else "new_run"
		next.grab_focus()
	status = text(menu, "", Rect2(96, 674, 1000, 48), 17, PALE)
	report_save_problem()


func choose_reward(id: String) -> void:
	if run.reward(id):
		persist()
		show_run()
