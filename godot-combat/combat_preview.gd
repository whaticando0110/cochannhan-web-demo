extends Control

signal action_committed
signal battle_finished

const Rules = preload("res://battle_rules.gd")
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
var field: Arena
var turn_label: Label
var hp_label: Label
var qi_label: Label
var wolf_label: Label
var intent_name: Label
var intent_copy: Label
var report_label: Label
var hint_label: Label
var hp_bar: ProgressBar
var qi_bar: ProgressBar
var wolf_bar: ProgressBar
var reset_button: Button
var actions := {}
var report: Array[String] = []
var headline := SystemFont.new()
var busy := false
var selecting := false


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
	var floor_data: Dictionary = RunData.FLOORS[run.floor]
	room_title = floor_data.name
	enemy_name = floor_data.enemy
	hero_name = "Cổ sư Áo rêu" if run.profile.hero == "ao-reu" else "Cổ sư Huyền bào"
	grade = "%s · Nguyên Hải %d%%" % [run.profile.grade, run.profile.sea_pct]


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
	label("CỔ CHÂN NHÂN  /  THANH MAO SƠN", 36, 22, 600, 30, 17, GREEN)
	label(room_title, 34, 48, 790, 60, 54, GOLD, true)
	var mode := "Trận theo lượt"
	if run != null:
		mode = "Màn %d / %d" % [run.floor + 1, RunData.FLOORS.size()]
	label("%s  ·  %s" % [mode, enemy_name], 38, 113, 600, 27, 20, MUTE)
	turn_label = label("", 678, 105, 160, 33, 20, GOLD, true)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reset_button = button("Chơi lại trận", 1006, 44, 160, 46)
	reset_button.visible = run == null
	reset_button.pressed.connect(reset_battle)
	panel(33, 151, 805, 481)
	field = Arena.new()
	if run != null:
		field.room = run.floor
		field.skin = run.profile.hero
	set_bounds(field, 34, 153, 803, 477)
	field.cell_selected.connect(select_cell)

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
	label("Chân nguyên", 880, 263, 169, 22, 16, IVORY)
	qi_label = label("", 1054, 263, 94, 22, 16, CYAN)
	qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qi_bar = bar(880, 290, 267, CYAN, state.max_qi)

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
	report_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var descriptions := [
		["move", "1   Di chuyển\n      Tối đa 2 ô"],
		["strike", "2   Tay không\n      14 sát thương · +1 CN"],
		["moon", "3   Nguyệt Quang\n      Tầm 4 ô · −2 chân nguyên"],
		["guard", "4   Thủ thế\n      Giảm 70% · +1 chân nguyên"],
	]
	for index in range(descriptions.size()):
		var row: Array = descriptions[index]
		var action: String = row[0]
		var node := button(row[1], 34 + index * 286, 648, 274, 67)
		node.pressed.connect(func(): choose(action))
		actions[action] = node
	hint_label = label("", 35, 728, 1125, 25, 15, MUTE)


func update_hud() -> void:
	hp_label.text = "%d / %d" % [state.hp, Rules.MAX_HP]
	qi_label.text = "%d / %d" % [state.qi, state.max_qi]
	wolf_label.text = "%d / %d" % [state.wolf_hp, state.wolf_max]
	hp_bar.value = state.hp
	qi_bar.value = state.qi
	wolf_bar.value = state.wolf_hp
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
			if state.intent.damage > 0:
				intent_copy.text = "Gây %d sát thương ở vùng đỏ." % state.intent.damage
			else:
				intent_copy.text = "%s sẽ tiến về phía bạn." % enemy_name
	report_label.text = "\n".join(report.slice(0, 3))
	for action in actions:
		var control: Button = actions[action]
		control.disabled = busy or not state.unavailable(action).is_empty()
		control.tooltip_text = state.unavailable(action)
	actions.move.modulate = GREEN if selecting else Color.WHITE


func reset_battle() -> void:
	if busy or run != null:
		return
	state = Rules.new()
	show_battle()


func show_battle() -> void:
	selecting = false
	field.clear_effects()
	field.set_selecting(false)
	field.set_state(state)
	report.assign(["%s đang chuẩn bị hành động." % enemy_name])
	hint_label.text = "Chọn hành động. Ô đỏ sẽ bị đánh sau lượt của bạn."
	update_hud()
	reset_button.release_focus()


func choose(action: String) -> void:
	if busy:
		return
	var reason := state.unavailable(action)
	if not reason.is_empty():
		hint_label.text = reason
		return
	if action == "move":
		selecting = not selecting
		field.set_selecting(selecting)
		hint_label.text = "Chọn ô viền xanh. Các ô đỏ nằm trong vùng địch đánh." if selecting else "Chọn hành động."
		update_hud()
		return
	resolve(action)


func select_cell(cell: int) -> void:
	if selecting and not busy:
		resolve("move", cell)


func resolve(action: String, cell: int = -1) -> void:
	var exchange: Dictionary = state.take_turn(action, cell) if run == null else run.perform(action, cell)
	if exchange.has("error"):
		hint_label.text = exchange.error
		return
	busy = true
	action_committed.emit()
	selecting = false
	field.set_selecting(false)
	for control in actions.values():
		control.disabled = true
	reset_button.disabled = true
	hint_label.text = "Đang giải quyết lượt…"
	await field.play_exchange(exchange)
	busy = false
	reset_button.disabled = false
	for note in exchange.notes:
		report.push_front(note)
	report = report.slice(0, 4)
	update_hud()
	if state.result.is_empty():
		hint_label.text = "Chọn hành động cho lượt tiếp theo."
	elif run == null:
		hint_label.text = "Nhấn R hoặc chọn Chơi lại trận."
	else:
		battle_finished.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_actions := {KEY_1: "move", KEY_2: "strike", KEY_3: "moon", KEY_4: "guard"}
	if key_actions.has(event.keycode):
		choose(key_actions[event.keycode])
	elif event.keycode == KEY_R and run == null:
		reset_battle()
	else:
		return
	get_viewport().set_input_as_handled()
