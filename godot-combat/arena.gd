extends Control

signal cell_selected(cell: int)
signal cell_focused(cell: int)
signal exchange_cue(cue: String)

const Rules = preload("res://battle_rules.gd")
const TRAIL = preload("res://assets/trail.png")
const THICKET = preload("res://assets/thicket.png")
const ROCK = preload("res://assets/rock-ridge.png")
const HERO = preload("res://assets/huyen-bao.png")
const TRAVEL = preload("res://assets/huyen-bao-travel.png")
const CAST = preload("res://assets/huyen-bao-combat.png")
const WOLF = preload("res://assets/dien-lang.png")
const MOON = preload("res://assets/nguyet-quang.png")
const MULCH = preload("res://assets/mulch.png")
const STONE = preload("res://assets/stone.png")
const WOLF_KING = preload("res://assets/cuong-dien-lang-motion.png")
const REU_TRAVEL = preload("res://assets/ao-reu-travel.png")
const REU_CAST = preload("res://assets/ao-reu-combat.png")
const REU_GUARD = preload("res://assets/ao-reu-guard.png")
const ORIGIN := Vector2(39, 35)
const TILE := Vector2(91, 82)
const GREEN := Color("#a9e2bb")
const AMBER := Color("#efae82")

var rules: Rules
var room := 0
var skin := "huyen-bao"
var hero_point := Vector2.ZERO
var wolf_point := Vector2.ZERO
var hero_frame := 13
var wolf_frame := 0
var hero_art := "ready"
var selecting := false
var mouse_cell := -1
var available: Array = []
var threatened: Array = []
var projectile: AtlasTexture
var projectile_point := Vector2.ZERO
var projectile_angle := 0.0
var shock_point := Vector2.ZERO
var shock_damage := 0
var shock_progress := 1.0
var shock_cold := true
var shock_guarded := false
var shock_caption := ""
var shock_tween: Tween
var ward_visible := false
var warned_row := -1
var charge_direction := 1
var cover_ray := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_CLICK
	mouse_exited.connect(point_to.bind(-1))


func set_state(state: Rules) -> void:
	rules = state
	hero_point = cell_center(rules.hero)
	wolf_point = cell_center(rules.wolf)
	hero_art = "ready"
	hero_frame = 13
	if room == 2:
		wolf_frame = 13 if rules.wolf_hp == 0 else 16
	else:
		wolf_frame = 8 if rules.wolf_hp == 0 else 0
	available = rules.move_targets()
	threatened = rules.intent.get("cells", []).duplicate()
	ward_visible = rules.jade_turns > 0
	warned_row = rules.intent.get("row", -1)
	charge_direction = rules.intent.get("direction", 1)
	queue_redraw()


func set_selecting(value: bool) -> void:
	selecting = value
	if not value:
		mouse_cell = -1
	queue_redraw()


func show_cover_ray(value: bool) -> void:
	cover_ray = value
	queue_redraw()


func clear_effects() -> void:
	if shock_tween != null and shock_tween.is_valid():
		shock_tween.kill()
	shock_progress = 1.0
	projectile = null
	queue_redraw()


func cell_center(cell: int) -> Vector2:
	return ORIGIN + (Vector2(Rules.grid(cell)) + Vector2(0.5, 0.5)) * TILE


func point_to(cell: int) -> void:
	if mouse_cell == cell:
		return
	mouse_cell = cell
	cell_focused.emit(cell)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var point := (((event as InputEventMouse).position - ORIGIN) / TILE).floor()
		var cell := -1
		if point.x >= 0 and point.y >= 0 and point.x < Rules.COLUMNS and point.y < Rules.ROWS:
			cell = int(point.x + point.y * Rules.COLUMNS)
		point_to(cell)
		if cell >= 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			cell_selected.emit(cell)
			accept_event()


func paint_marker(rect: Rect2, color: Color, striped: bool, destination: bool) -> void:
	draw_rect(rect.grow(-1), Color(color, 0.25))
	draw_rect(rect.grow(-1), Color(color, 0.92), false, 1.5)
	if striped:
		for line in range(10, int(rect.size.x + rect.size.y), 14):
			var start := Vector2(maxf(0, line - rect.size.y), minf(line, rect.size.y))
			var end := Vector2(minf(line, rect.size.x), maxf(0, line - rect.size.x))
			draw_line(rect.position + start, rect.position + end, Color(color, 0.24), 1.5, true)
	if destination:
		var center := rect.get_center()
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0),
			center + Vector2(0, 5), center + Vector2(-5, 0)]), color)


func paint_tiles() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182a22"))
	var grid_rect := Rect2(ORIGIN, TILE * Vector2(Rules.COLUMNS, Rules.ROWS))
	draw_rect(grid_rect.grow(5), Color("#65563b"))
	for cell in range(Rules.ROWS * Rules.COLUMNS):
		var point := Rules.grid(cell)
		var rect := Rect2(ORIGIN + Vector2(point) * TILE, TILE)
		var variant := (point.x * 3 + point.y * 5 + point.x * point.y) % 8
		var edge := mini(point.x, Rules.COLUMNS - point.x - 1)
		var shade := 0.67 + 0.05 * mini(edge, 2)
		var ground: Texture2D = [TRAIL, MULCH, STONE][room]
		var sample := ground.get_width() / 8.0
		draw_texture_rect_region(ground, rect, Rect2(variant * sample, 0, sample, ground.get_height()), Color(shade, shade, shade * 0.88))
		draw_rect(rect, Color("#a0ad793b"), false, 1.0)
		if rules != null and cell in rules.rocks:
			draw_texture_rect(ROCK, Rect2(rect.get_center() - Vector2(39, 40), Vector2(78, 78)), false)
			if rules.tactic == "ravine":
				draw_rect(rect.grow(-3), Color("#b8cfe064"), false, 1.5)
		var danger := cell in threatened
		var accessible := selecting and cell in available
		if danger and point.y == warned_row:
			paint_marker(rect, Color("#ffc29a") if accessible else Color("#f6a36c"), false, accessible)
			var middle := rect.get_center()
			for x in [-25, 0, 25]:
				var tip := middle + Vector2(x + 5 * charge_direction, 0)
				var tail := -10 * charge_direction
				draw_polyline(PackedVector2Array([tip + Vector2(tail, -9), tip, tip + Vector2(tail, 9)]),
					Color("#ffe3adab"), 2.0, true)
		elif danger:
			paint_marker(rect, Color("#ffc29a") if accessible else Color("#fb816a"), true, accessible)
		elif accessible:
			paint_marker(rect, GREEN, false, true)
		if mouse_cell == cell:
			draw_rect(rect.grow(-3), Color("#f4dfbcb8"), false, 2.0)
	if room != 2:
		for x in range(52, 752, 84):
			draw_texture_rect(THICKET, Rect2(x, 1, 84, 34), false, Color("#91a47e"))
			draw_texture_rect(THICKET, Rect2(x - 10, 438, 90, 32), false, Color("#7c967a"))
	for index in range(Rules.COLUMNS):
		draw_string(ThemeDB.fallback_font, Vector2(ORIGIN.x + TILE.x * index + 40, 27), char(65 + index),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5dfb2"))
	for index in range(Rules.ROWS):
		draw_string(ThemeDB.fallback_font, Vector2(16, ORIGIN.y + TILE.y * index + 45), str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5dfb2"))


func atlas_frame(texture: Texture2D, cols: int, rows: int, frame: int, center: Vector2, span: float, face: int, tint: Color) -> void:
	var cell_size := texture.get_size() / Vector2(cols, rows)
	@warning_ignore("integer_division")
	var region := Rect2(Vector2(frame % cols, frame / cols) * cell_size, cell_size)
	var pivot := Vector2(-span * .5, -span * .77)
	draw_set_transform(center, 0, Vector2(face, 1))
	draw_texture_rect_region(texture, Rect2(pivot, Vector2(span, span)), region, tint)
	draw_set_transform(Vector2.ZERO)


func actor_ring(center: Vector2, tone: Color) -> void:
	draw_set_transform(center + Vector2(0, 24), 0, Vector2(1, .31))
	draw_circle(Vector2.ZERO, 27.0, Color("#090f0bb8"))
	draw_arc(Vector2.ZERO, 27.0, 0, TAU, 50, tone, 1.8, true)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	paint_tiles()
	if rules == null:
		return
	var direction := 1 if hero_point.x <= wolf_point.x else -1
	actor_ring(hero_point, GREEN)
	if ward_visible:
		draw_arc(hero_point + Vector2(0, -17), 29.0, PI * .92, PI * 2.08, 24, Color("#a2efd1bd"), 2.0, true)
	actor_ring(wolf_point, AMBER)
	if cover_ray and rules.tactic == "ravine":
		var blocker := rules.ray_blocker(rules.hero, rules.wolf)
		if blocker >= 0 and Rules.distance(rules.hero, rules.wolf) <= Rules.MOON_RANGE:
			var stop := cell_center(blocker)
			draw_dashed_line(hero_point, stop, Color("#c5f7ffb0"), 2.0, 7.0, true, true)
			draw_arc(stop, 10, 0, TAU, 20, Color("#ffc49c"), 2.0, true)
	var hero_tint := Color("#7f8b86") if rules.result == Rules.DEFEAT and hero_art == "ready" else Color.WHITE
	var female := skin == "ao-reu"
	if hero_art == "cast":
		atlas_frame(REU_CAST if female else CAST, 8, 2, hero_frame, hero_point, 112, direction, hero_tint)
	elif female and hero_art == "guard":
		atlas_frame(REU_GUARD, 1, 1, 0, hero_point, 112, direction, hero_tint)
	elif female or hero_art == "move":
		atlas_frame(REU_TRAVEL if female else TRAVEL, 8, 4, hero_frame if hero_art == "move" else 0,
			hero_point, 109, direction, hero_tint)
	else:
		atlas_frame(HERO, 8, 6, hero_frame, hero_point, 113, direction, hero_tint)
	var fallen := rules.wolf_hp == 0 and wolf_frame == (13 if room == 2 else 8)
	var wolf_tint := Color("#818985") if fallen else Color.WHITE
	if room == 2:
		atlas_frame(WOLF_KING, 4, 5, wolf_frame, wolf_point + Vector2(0, 25), 193, -direction, wolf_tint)
	else:
		atlas_frame(WOLF, 4, 4, wolf_frame, wolf_point + Vector2(0, 11), 118, -direction, wolf_tint)
	if projectile != null:
		draw_circle(projectile_point, 15, Color("#92ddf245"))
		draw_set_transform(projectile_point, projectile_angle)
		draw_texture_rect(projectile, Rect2(Vector2(-25, -25), Vector2(50, 50)), false)
		draw_set_transform(Vector2.ZERO)
	if shock_progress < 1.0:
		var tone := Color("#f8d68c") if shock_guarded else Color("#c5f7ff") if shock_cold else Color("#ffb994")
		var alpha := 1.0 - shock_progress
		draw_arc(shock_point, 6 + shock_progress * 26, 0, TAU, 24, Color(tone, alpha * 0.8), 2.0, true)
		var marker := shock_caption if not shock_caption.is_empty() else ("Đỡ  −%d" % shock_damage if shock_guarded else "−%d" % shock_damage)
		draw_string(ThemeDB.fallback_font, shock_point + Vector2(-12, -10 - 26 * shock_progress), marker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(tone, alpha))


func set_hero_frame(frame: float) -> void:
	hero_frame = int(frame)
	queue_redraw()


func set_wolf_frame(frame: float) -> void:
	wolf_frame = int(frame)
	queue_redraw()


func impact(point: Vector2, damage: int, cold: bool, guarded: bool = false, caption: String = "") -> void:
	shock_point = point
	shock_damage = damage
	shock_cold = cold
	shock_guarded = guarded
	shock_caption = caption
	if shock_tween != null and shock_tween.is_valid():
		shock_tween.kill()
	shock_tween = create_tween()
	shock_tween.tween_method(func(progress: float): shock_progress = progress; queue_redraw(), 0.0, 1.0, .38)


func slide_hero(path: Array[int]) -> void:
	var tween := create_tween()
	var step_start := hero_point
	for cell in path:
		var step_end := cell_center(cell)
		tween.tween_method(func(value: Vector2): hero_point = value; queue_redraw(), step_start, step_end, .15)
		tween.parallel().tween_method(set_hero_frame, 0.0, 7.9, .15)
		step_start = step_end
	await tween.finished


func cast(at: Vector2) -> void:
	hero_art = "cast"
	var cast_pose := create_tween()
	cast_pose.tween_method(set_hero_frame, 0.0, 4.0, .31)
	await cast_pose.finished
	var to := at - Vector2(0, 6)
	var launch := hero_point + Vector2(23 if to.x >= hero_point.x else -23, -8)
	projectile = AtlasTexture.new()
	projectile.atlas = MOON
	projectile.region = Rect2(0, 0, 32, 32)
	projectile_angle = launch.angle_to_point(to)
	var flight := create_tween().set_parallel()
	flight.tween_method(func(point: Vector2):
		projectile_point = point
		var phase := clampf(launch.distance_to(point) / maxf(launch.distance_to(to), 1), 0, 1)
		projectile.region.position.x = floorf(phase * 7) * 32
		queue_redraw(), launch, to, .24)
	flight.tween_method(set_hero_frame, 4.0, 7.9, .24)
	await flight.finished
	projectile = null
	hero_art = "ready"
	hero_frame = 13


func play_exchange(exchange: Dictionary) -> void:
	available.clear()
	exchange_cue.emit("player")
	var guarding: bool = exchange.action == "guard"
	if exchange.action == "move":
		hero_art = "move"
		await slide_hero(exchange.hero_path)
	elif exchange.action == "moon":
		await cast(wolf_point)
	elif exchange.action == "strike":
		var rally := hero_point
		var forward := (wolf_point - hero_point).normalized() * 15
		var strike := create_tween()
		strike.tween_method(func(p: Vector2): hero_point = p; queue_redraw(), rally, rally + forward, .11)
		strike.tween_method(func(p: Vector2): hero_point = p; queue_redraw(), rally + forward, rally, .10)
		await strike.finished
	elif guarding:
		hero_art = "guard"
		var brace := create_tween()
		brace.tween_method(set_hero_frame, 6.0, 13.0, .23)
		await brace.finished
	elif exchange.action == "jade_skin":
		ward_visible = true
		impact(hero_point + Vector2(0, -16), 0, true, false, "Ngọc Bì")
		await get_tree().create_timer(.28).timeout
	elif exchange.action == "vital_leaf":
		impact(hero_point + Vector2(0, -16), 0, false, true, "+%d" % exchange.healed)
		await get_tree().create_timer(.38).timeout
	if not guarding:
		hero_art = "ready"
	exchange_cue.emit("player_contact")
	if exchange.wolf_damage > 0:
		impact(wolf_point, exchange.wolf_damage, true)
		var hit := create_tween()
		hit.tween_method(set_wolf_frame, 12.0, 15.9, .18)
		await hit.finished
	if not exchange.reaction.is_empty():
		exchange_cue.emit("enemy")
	if exchange.reaction == "advance":
		var approach := create_tween().set_parallel()
		approach.tween_method(func(p: Vector2): wolf_point = p; queue_redraw(), wolf_point, cell_center(rules.wolf), .26)
		var walk_start := 0.0 if room == 2 else 4.0
		approach.tween_method(set_wolf_frame, walk_start, walk_start + 3.99, .26)
		await approach.finished
	elif exchange.reaction in ["heavy", "strike", "miss"]:
		var start := wolf_point
		var target := cell_center(rules.hero) if exchange.reaction != "miss" else cell_center(exchange.hero_from)
		var vector := target - start
		var landing := target - vector.normalized() * minf(47, vector.length() * .42)
		var row: int = exchange.enemy_intent.get("row", -1)
		var charge_start := start
		var charge_end := landing
		if row >= 0:
			var first := cell_center(row * Rules.COLUMNS)
			var last := cell_center(row * Rules.COLUMNS + Rules.COLUMNS - 1)
			var rightward: bool = exchange.enemy_intent.direction > 0
			charge_start = first if rightward else last
			charge_end = last if rightward else first
			landing = Vector2(clampf(target.x, first.x, last.x), first.y)
		var windup := create_tween().set_parallel()
		var coil := 14.0 if room == 2 else 8.0
		windup.tween_method(set_wolf_frame, coil, coil, .20)
		var windup_end := charge_start if row >= 0 else start - vector.normalized() * 10
		windup.tween_method(func(p: Vector2): wolf_point = p; queue_redraw(), start, windup_end, .20)
		await windup.finished
		var attack := create_tween().set_parallel()
		attack.tween_method(func(p: Vector2): wolf_point = p; queue_redraw(), wolf_point, landing, .17)
		var strike_start := 14.0 if room == 2 else 8.0
		attack.tween_method(set_wolf_frame, strike_start, strike_start + (1.0 if room == 2 else 2.0), .17)
		await attack.finished
		exchange_cue.emit("enemy_contact")
		if exchange.absorbed > 0:
			ward_visible = false
		if exchange.hero_damage > 0:
			var caption := "Ngọc Bì %d  /  −%d" % [exchange.absorbed, exchange.hero_damage] if exchange.absorbed > 0 else ""
			impact(hero_point + (Vector2(0, -9) if guarding else Vector2.ZERO), exchange.hero_damage, false, guarding, caption)
			if guarding:
				hero_frame = 14
			else:
				hero_art = "cast"
				hero_frame = 9
		elif exchange.absorbed > 0:
			impact(hero_point + Vector2(0, -9), 0, true, false, "Chặn %d" % exchange.absorbed)
		var recover := create_tween()
		if row >= 0 and not landing.is_equal_approx(charge_end):
			recover.tween_method(func(p: Vector2): wolf_point = p; queue_redraw(), landing, charge_end, .18)
		recover.tween_method(func(p: Vector2): wolf_point = p; queue_redraw(), charge_end if row >= 0 else landing, start, .17)
		await recover.finished
	if guarding:
		var lower := create_tween()
		lower.tween_method(set_hero_frame, 14.0, 18.0, .20)
		await lower.finished
	set_state(rules)
