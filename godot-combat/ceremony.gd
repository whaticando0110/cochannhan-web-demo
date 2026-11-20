extends Control

signal awakened(profile: Dictionary)
signal back_requested

const Rules = preload("res://awakening_rules.gd")
const Aperture = preload("res://aperture.gd")
const CAVE = preload("res://assets/cave-tiles.png")
const FLOWERS = preload("res://assets/nguyet-lan-tiles.png")
const HOPE_ART = preload("res://assets/hy-vong-gu.png")
const SPRING = preload("res://assets/cave-spring.png")
const HERO = preload("res://assets/huyen-bao-travel.png")
const REU = preload("res://assets/ao-reu-travel.png")
const BOARD := Rect2(34, 144, 1132, 459)
const TILE := 51.0
const GOLD := Color("#f1d89f")
const CYAN := Color("#91d8db")
const PALE := Color("#d0e0d6")
const TEXT := [
	"Thuở hoang sơ, bầy thú Khốn Cảnh săn đuổi Nhân Tổ khắp mọi nẻo.",
	"Nhân Tổ đổi tuổi trẻ lấy Sức Mạnh Cổ, rồi đổi tuổi trung niên lấy Trí Tuệ Cổ.",
	"Khi cả hai bỏ đi, một con Cổ nhỏ bé đến xin Nhân Tổ trao cho nó một trái tim.",
	"Nhân Tổ bằng lòng. Ánh sáng từ Hy Vọng Cổ đẩy lùi bầy thú Khốn Cảnh.",
	"Từ đó, ngay cả trong tuyệt cảnh, con người vẫn có một tia hy vọng để bước tiếp.",
]
const KEYS := {
	KEY_W: Vector2i.UP, KEY_UP: Vector2i.UP, KEY_A: Vector2i.LEFT, KEY_LEFT: Vector2i.LEFT,
	KEY_S: Vector2i.DOWN, KEY_DOWN: Vector2i.DOWN, KEY_D: Vector2i.RIGHT, KEY_RIGHT: Vector2i.RIGHT,
}

var hero_id := "huyen-bao"
var fixed_limit := 0
var state: Rules
var world_point := Vector2(1, 4)
var last_point := world_point
var remaining := 0.0
var duration := 1.0
var time := 0.0
var facing := 1
var route: Array[Vector2i] = []
var held: Array[int] = []
var heading: Label
var story: Label
var story_index := -1
var convergence := 0.0
var result_panel: Panel
var result_confirm: Button
var result: Dictionary


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	state = Rules.new(fixed_limit)
	add_text("CỔ NGUYỆT SƠN TRẠI    /    HANG NGUYỆT LAN", Rect2(34, 22, 870, 25), 16, CYAN)
	add_text("Đại điển Khai Khiếu", Rect2(32, 52, 830, 64), 49, GOLD, true)
	heading = add_text("Độ sâu  0 bước", Rect2(850, 71, 310, 42), 20, PALE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := add_button(self, "Quay lại", Rect2(1001, 21, 165, 42))
	back.pressed.connect(func(): back_requested.emit())
	add_text("NHÂN TỔ TRUYỆN", Rect2(38, 623, 270, 24), 15, GOLD)
	story = add_text("Qua sông ngầm ở đoạn nước nông để bắt đầu nghi lễ.", Rect2(38, 650, 1126, 46), 19, PALE)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_text("WASD / Phím mũi tên · Bấm một ô để tự đi", Rect2(38, 716, 1122, 27), 15, PALE)


func add_text(text: String, bounds: Rect2, font_size: int, tint: Color, serif: bool = false, parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = bounds.position
	node.size = bounds.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", tint)
	node.add_theme_font_size_override("font_size", font_size)
	if serif:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Cambria", "Georgia"])
		node.add_theme_font_override("font", font)
	(self if parent == null else parent).add_child(node)
	return node


func add_button(parent: Control, text: String, bounds: Rect2) -> Button:
	var node := Button.new()
	node.text = text
	node.position = bounds.position
	node.size = bounds.size
	node.add_theme_font_size_override("font_size", 19)
	parent.add_child(node)
	return node


func camera() -> float:
	return clampf((world_point.x + .5) * TILE - BOARD.size.x * .34, 0, Rules.WIDTH * TILE - BOARD.size.x)


func advance(point: Vector2i) -> void:
	var before: Vector2i = state.position
	if not state.step(point):
		return
	if point.x != before.x:
		facing = signi(point.x - before.x)
	last_point = world_point
	duration = state.seconds()
	remaining = duration
	var profile := Rules.profile_for(hero_id, state.depth)
	var rank := " · %s" % profile.grade if not profile.is_empty() else ""
	if state.depth == 10 or state.depth == 11:
		rank = " · Đinh đẳng"
	heading.text = "%d bước%s" % [state.depth, rank]
	var line := -1
	if state.depth >= 34:
		line = 4
	elif state.depth >= 22:
		line = 3
	elif state.depth >= 12:
		line = 2
	elif state.depth >= 2:
		line = 1
	elif point.x >= 3:
		line = 0
	story_index = maxi(story_index, line)
	if story_index >= 0:
		story.text = TEXT[story_index]
		if state.limit - state.depth <= 4 and not state.finished():
			story.text += "  Bước chân nặng dần."


func _process(delta: float) -> void:
	time += delta
	if remaining > 0.0:
		remaining = maxf(remaining - delta, 0)
		world_point = last_point.lerp(Vector2(state.position), 1.0 - remaining / duration)
	if remaining == 0.0 and result_panel == null:
		if state.finished():
			convergence += delta
			if convergence >= .62:
				show_result()
		elif not held.is_empty():
			advance(state.position + KEYS[held.back()])
		elif not route.is_empty():
			advance(route.pop_front())
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not KEYS.has(event.keycode) or result_panel != null:
		return
	if event.pressed and not event.echo:
		route.clear()
		held.erase(event.keycode)
		held.append(event.keycode)
	elif not event.pressed:
		held.erase(event.keycode)
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if result_panel != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and BOARD.has_point(event.position):
		var target := (Vector2(event.position) - BOARD.position + Vector2(camera(), 0)) / TILE
		held.clear()
		route = state.path_to(Vector2i(target.floor()))
		accept_event()


func tile_art(atlas: Texture2D, src: Vector2, atlas_size: float, point: Vector2, span: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(atlas, Rect2(point, Vector2.ONE * span), Rect2(src * atlas_size, Vector2.ONE * atlas_size), tint)


func draw_map() -> void:
	var offset := camera()
	var first := floori(offset / TILE)
	var last := mini(Rules.WIDTH - 1, ceili((offset + BOARD.size.x) / TILE))
	for y in range(Rules.HEIGHT):
		for x in range(first, last + 1):
			var p := BOARD.position + Vector2(x * TILE - offset, y * TILE)
			var v := (x * 13 + y * 11 + x * y) % 12
			var cell := Vector2i(x, y)
			var src: Vector2
			match Rules.terrain(cell):
				"bank": src = Vector2(v % 3, 1)
				"ford": src = Vector2(x + 2, 1)
				"water": src = Vector2(3 + v % 2, 1)
				"garden": src = Vector2(4 + v % 2 if y == 4 else v % 4, 2)
				_: src = Vector2(v % 3, 0)
			tile_art(CAVE, src, 32, p, TILE)
			if y in [1, 7]:
				tile_art(CAVE, Vector2(3 + v % 3 if y == 1 else 6 + v % 2, 0), 32, p, TILE)
			if Rules.terrain(cell) == "garden" and x < 55 and (y != 4 or v % 2 == 0):
				tile_art(FLOWERS, Vector2(v % 4, 0), 32, p + Vector2(4 + v, v % 4), TILE * (.70 if y == 4 else .91))
				if y != 4 and v > 4:
					tile_art(FLOWERS, Vector2((v + 1) % 4, 0), 32, p + Vector2(20, 13), TILE * .65)
			if cell in Rules.HOPE and cell not in state.gathered:
				var fly := p + Vector2(23 + sin(time * 3 + x) * 8, 15 + cos(time * 4 + x) * 9)
				draw_circle(fly, 15, Color("#87ddd14c"))
				tile_art(HOPE_ART, Vector2(floori(time * 8) % 4, 0), 16, fly - Vector2(13, 13), 26)
	if last >= 55:
		draw_texture_rect(SPRING, Rect2(BOARD.position + Vector2(55 * TILE - offset, 2 * TILE), Vector2(2, 5) * TILE), false)
	var center := BOARD.position + (world_point + Vector2(.5, .5)) * TILE - Vector2(offset, 0)
	draw_set_transform(center + Vector2(0, 14), 0, Vector2(1, .28))
	draw_circle(Vector2.ZERO, 18, Color("#061512c7"))
	draw_set_transform(center, 0, Vector2(facing, 1))
	var anim := mini(7, floori(8.0 * (1 - remaining / duration))) if remaining > 0 else 0
	tile_art(REU if hero_id == "ao-reu" else HERO, Vector2(anim, 0), 64, Vector2(-50, -72), 100)
	draw_set_transform(Vector2.ZERO)
	for i in range(state.gathered.size()):
		var orbit := Vector2.from_angle(time * 2.3 + i * TAU / state.gathered.size())
		var fly := center + Vector2(orbit.x * 33, orbit.y * 17 - 16)
		tile_art(HOPE_ART, Vector2(floori(time * 8 + i) % 4, 0), 16, fly - Vector2(9, 9), 18)
	if convergence > 0.0 and result_panel == null:
		var progress := clampf(convergence / .62, 0, 1)
		draw_circle(center - Vector2(0, 12), 18 + 37 * progress, Color("#b8edc924"))
		for i in range(13):
			var heading_angle := i * TAU / 13.0 + progress * 1.8
			var fly := center - Vector2(0, 12) + Vector2.from_angle(heading_angle) * lerpf(104, 4, progress)
			tile_art(HOPE_ART, Vector2((floori(time * 8) + i) % 4, 0), 16, fly - Vector2(10, 10), 20)
	draw_rect(Rect2(0, BOARD.position.y, BOARD.position.x, BOARD.size.y), Color("#0b1210"))
	draw_rect(Rect2(BOARD.end.x, BOARD.position.y, 34, BOARD.size.y), Color("#0b1210"))
	draw_rect(BOARD, Color("#50766c"), false, 2)


func _draw() -> void:
	if state != null:
		draw_map()


func show_result() -> void:
	result = Rules.profile_for(hero_id, state.depth)
	held.clear()
	route.clear()
	var shade := ColorRect.new()
	shade.color = Color("#0b1513bf")
	shade.size = size
	add_child(shade)
	result_panel = Panel.new()
	result_panel.position = Vector2(306, 177)
	result_panel.size = Vector2(588, 409)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#152b27")
	box.border_color = GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	result_panel.add_theme_stylebox_override("panel", box)
	add_child(result_panel)
	add_text("Không Khiếu đã mở", Rect2(34, 26, 524, 52), 37, GOLD, true, result_panel)
	var aperture := Aperture.new()
	aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aperture.position = Vector2(30, 106)
	aperture.size = Vector2(190, 190)
	aperture.target = result.sea_pct / 100.0
	result_panel.add_child(aperture)
	add_text("%s  ·  %d bước" % [result.grade, result.depth], Rect2(241, 114, 312, 38), 23, PALE, false, result_panel)
	add_text("Thanh Đồng Nguyên Hải  %d%%" % result.sea_pct, Rect2(241, 166, 312, 38), 21, CYAN, false, result_panel)
	add_text("Sức chứa khởi điểm   %d chân nguyên" % result.max_qi,
		Rect2(241, 219, 321, 34), 18, PALE, false, result_panel)
	result_confirm = add_button(result_panel, "Bắt đầu lượt chơi", Rect2(36, 320, 516, 52))
	result_confirm.pressed.connect(func(): awakened.emit(result))
	result_confirm.grab_focus()
