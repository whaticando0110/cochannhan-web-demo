extends Control

signal cell_selected(cell: int)
signal cell_focused(cell: int)
signal exchange_cue(cue: String)

const Rules = preload("res://battle_rules.gd")
const Art = preload("res://combat_art.gd")
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
var projectile_span := 50.0
var shock_point := Vector2.ZERO
var shock_damage := 0
var shock_progress := 1.0
var shock_cold := true
var shock_guarded := false
var shock_caption := ""
var shock_tween: Tween
var ward_kind := ""
var mark_visible := false
var brew_prepared := false
var brew_stacks := 0
var stone_prepared := false
var loop_time := 0.0
var effects: Array[Dictionary] = []
var warned_row := -1
var charge_direction := 1
var bolt_warning := false
var thunder_warning := false
var poison_warning := false
var wind_direction := 0
var seal_warning := false
var pulse_warning := false
var area_active := false
var flood_warning := false
var flood_active := false
var rubble_warning := false
var rubble_progress := 1.0
var veiled := false
var cover_ray := 0
var bolt := PackedVector2Array()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_CLICK
	mouse_exited.connect(point_to.bind(-1))
	set_process(false)


func _process(delta: float) -> void:
	loop_time += delta * 1000.0
	queue_redraw()


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
	ward_kind = ""
	if rules.jade_turns > 0:
		ward_kind = "white_jade" if rules.ward_strength > Rules.JADE_ABSORB else "jade_skin"
	mark_visible = rules.moon_mark
	brew_prepared = rules.brew_ready
	brew_stacks = rules.strong_strikes
	stone_prepared = rules.steps_bonus > 0
	warned_row = rules.intent.get("row", -1)
	charge_direction = rules.intent.get("direction", 1)
	bolt_warning = rules.intent.get("pattern") == "bolt"
	thunder_warning = rules.intent.get("pattern") == "thunder"
	poison_warning = rules.intent.get("pattern") == "poison"
	wind_direction = rules.intent.get("direction", 0) if rules.intent.get("pattern") == "wind" else 0
	seal_warning = rules.intent.get("pattern") == "seal_burst"
	pulse_warning = rules.intent.get("pattern") == "core_wave"
	flood_warning = rules.intent.get("pattern") == "water"
	rubble_warning = rules.intent.get("pattern") == "rubble"
	veiled = rules.veil_turns > 0
	set_process(not ward_kind.is_empty() or mark_visible or brew_prepared or brew_stacks > 0 or stone_prepared or veiled)
	queue_redraw()


func set_selecting(value: bool) -> void:
	selecting = value
	if not value:
		mouse_cell = -1
	queue_redraw()


func show_cover_ray(value: int) -> void:
	cover_ray = value
	queue_redraw()


func clear_effects() -> void:
	if shock_tween != null and shock_tween.is_valid():
		shock_tween.kill()
	shock_progress = 1.0
	projectile = null
	bolt.clear()
	flood_active = false
	area_active = false
	rubble_progress = 1.0
	for effect in effects:
		effect.tween.kill()
	effects.clear()
	loop_time = 0.0
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
	var marsh := rules != null and rules.tactic == "marsh"
	var wind_pass := rules != null and rules.tactic == "wind_pass"
	for cell in range(Rules.ROWS * Rules.COLUMNS):
		var point := Rules.grid(cell)
		var rect := Rect2(ORIGIN + Vector2(point) * TILE, TILE)
		var variant := (point.x * 3 + point.y * 5 + point.x * point.y) % 8
		var edge := mini(point.x, Rules.COLUMNS - point.x - 1)
		var shade := 0.67 + 0.05 * mini(edge, 2)
		var rock: bool = rules != null and cell in rules.rocks
		var tint := Color(shade, shade, shade)
		if room == 4:
			var wet: bool = rules != null and cell in rules.water
			terrain_frame(Art.FORD, rect, Vector2i(variant % 4, 0), tint * Color("#d5dfb3") if marsh else tint)
			if wet or rock:
				terrain_frame(Art.FORD, rect, Vector2i((2 if wet else 0) + variant % 2, 1), tint)
			if wet:
				var mask := water_mask(point)
				@warning_ignore("integer_division")
				terrain_frame(Art.WATER, rect, Vector2i(mask % 4, mask / 4), Color("#91a56b") if marsh else Color.WHITE)
		elif room == 5:
			var cracked: bool = rules != null and cell in rules.cracks
			terrain_frame(Art.CANYON, rect, Vector2i(variant % 4, 0), tint * Color("#b4d7e9") if wind_pass else tint)
			if cracked or rock:
				terrain_frame(Art.CANYON, rect, Vector2i((2 if rock else 0) + variant % 2, 1), tint)
		else:
			var ground: Texture2D = [TRAIL, MULCH, STONE][mini(room, 2)]
			var sample := ground.get_width() / 8.0
			draw_texture_rect_region(ground, rect, Rect2(variant * sample, 0, sample, ground.get_height()), Color(shade, shade, shade * .88))
		draw_rect(rect, Color("#a0ad793b"), false, 1.0)
		if rock:
			if rules.uses_cover():
				terrain_frame(Art.TELEGRAPHS, rect, Vector2i.ZERO)
			if room < 4:
				draw_texture_rect(ROCK, Rect2(rect.get_center() - Vector2(39, 40), Vector2(78, 78)), false)
		var danger := cell in threatened
		var accessible := selecting and cell in available
		if danger and point.y == warned_row:
			var column := point.x if charge_direction > 0 else Rules.COLUMNS - 1 - point.x
			var tile := 0 if column == 0 else 2 if column == Rules.COLUMNS - 1 else 1
			terrain_frame(Art.TELEGRAPHS, rect, Vector2i(tile, 2 if room == 2 else 1), Color.WHITE, charge_direction > 0)
			if accessible:
				paint_marker(rect, Color("#ffc29a"), false, true)
		elif danger and flood_warning:
			var connected := water_mask(point)
			var column := 3 if (connected & 5) != 0 and (connected & 10) != 0 else 2 if (connected & 5) != 0 else 1
			draw_rect(rect.grow(-1), Color("#9766eaa6") if flood_active else Color("#9e70d65c"))
			terrain_frame(Art.FLOOD, rect, Vector2i(0, 1) if flood_active else Vector2i(column, 0), Color("#f4c9ff"))
			if accessible:
				paint_marker(rect, Color("#cebcff"), false, true)
		elif danger and rubble_warning:
			var tile := 3 if rubble_progress >= .65 and rubble_progress < 1.0 else 2 if rubble_progress < 1.0 else variant % 2
			terrain_frame(Art.ROCKFALL, rect, Vector2i(tile, 0))
			if accessible:
				paint_marker(rect, Color("#ffca87"), false, true)
		elif danger and (thunder_warning or poison_warning):
			var pulse := Color("#eff280ed") if poison_warning else Color("#aa78ffff")
			var wash := Color("#c7cf5aa6") if poison_warning else Color("#9671e17d")
			draw_rect(rect.grow(-1), pulse if area_active else wash)
			var glyph_color := Color("#f5ee9a") if poison_warning else Color("#edcaff")
			terrain_frame(Art.FLOOD, rect, Vector2i(0, 1) if area_active else Vector2i(1, 0), glyph_color)
			if accessible:
				paint_marker(rect, glyph_color if poison_warning else Color("#cebcff"), false, true)
		elif danger and seal_warning:
			draw_rect(rect.grow(-1), Color("#ff9699bf") if area_active else Color("#db697c7a"))
			paint_marker(rect, Color("#ffc9d2"), true, accessible)
		elif danger and pulse_warning:
			draw_rect(rect.grow(-1), Color("#ffd287de") if area_active else Color("#d786546e"))
			paint_marker(rect, Color("#ffe0af"), true, accessible)
		elif danger and wind_direction != 0:
			draw_rect(rect.grow(-1), Color("#9be0f6bf") if area_active else Color("#65b6d86b"))
			var center := rect.get_center()
			var direction := Vector2(wind_direction, 0)
			var arrow := center + direction * 12
			draw_polyline(PackedVector2Array([arrow - direction * 10 - Vector2(0, 8), arrow,
				arrow - direction * 10 + Vector2(0, 8)]), Color("#d9eff8"), 2.0)
			if accessible:
				paint_marker(rect, Color("#c7ebf7"), false, true)
		elif danger and bolt_warning:
			paint_marker(rect, Color("#a4d8ff") if accessible else Color("#87a6eb"), false, accessible)
			var icon_at := rect.position + Vector2(16, 20)
			draw_polyline(PackedVector2Array([icon_at + Vector2(3, -11), icon_at + Vector2(-5, -1),
				icon_at + Vector2(4, -1), icon_at + Vector2(-2, 10)]), Color("#d6e7ffd0"), 2.0, true)
		elif danger:
			paint_marker(rect, Color("#ffc29a") if accessible else Color("#fb816a"), true, accessible)
		elif accessible:
			paint_marker(rect, GREEN, false, true)
		if rules != null and cell in rules.runes:
			var center := rect.get_center()
			var diamond := PackedVector2Array([center + Vector2(0, -17), center + Vector2(18, 0),
				center + Vector2(0, 17), center + Vector2(-18, 0)])
			draw_colored_polygon(diamond, Color("#564185d8"))
			diamond.append(diamond[0])
			draw_polyline(diamond, Color("#dbc3ff"), 2.0)
		if mouse_cell == cell:
			draw_rect(rect.grow(-3), Color("#f4dfbcb8"), false, 2.0)
	if room < 2:
		for x in range(52, 752, 84):
			draw_texture_rect(THICKET, Rect2(x, 1, 84, 34), false, Color("#91a47e"))
			draw_texture_rect(THICKET, Rect2(x - 10, 438, 90, 32), false, Color("#7c967a"))
	for index in range(Rules.COLUMNS):
		draw_string(ThemeDB.fallback_font, Vector2(ORIGIN.x + TILE.x * index + 40, 27), char(65 + index),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5dfb2"))
	for index in range(Rules.ROWS):
		draw_string(ThemeDB.fallback_font, Vector2(16, ORIGIN.y + TILE.y * index + 45), str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5dfb2"))


func water_mask(point: Vector2i) -> int:
	var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var mask := 0
	for bit in range(offsets.size()):
		var neighbor: Vector2i = point + offsets[bit]
		if Rect2i(0, 0, Rules.COLUMNS, Rules.ROWS).has_point(neighbor) and neighbor.y * Rules.COLUMNS + neighbor.x in rules.water:
			mask |= 1 << bit
	return mask


func terrain_frame(texture: Texture2D, rect: Rect2, cell: Vector2i, tint: Color = Color.WHITE, flip: bool = false) -> void:
	var source := Rect2(Vector2(cell) * TILE, TILE)
	if flip:
		draw_set_transform(Vector2(rect.end.x, rect.position.y), 0, Vector2(-1, 1))
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, TILE), source, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(texture, rect, source, tint)


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


func draw_effect(clip: Dictionary, elapsed: float, at: Vector2, span: float, face: int, loop: bool = false) -> void:
	var pivot := Vector2(-span * .5, -span * float(clip.get("pivot", .77)))
	draw_set_transform(at, 0, Vector2(face, 1))
	draw_texture_rect_region(clip.texture, Rect2(pivot, Vector2.ONE * span), Art.frame_region(clip, elapsed, loop))
	draw_set_transform(Vector2.ZERO)


func play_effect(clip: Dictionary, at: Vector2, span: float = 112.0, face: int = 1, cue: Callable = Callable()) -> Tween:
	var tween := create_tween()
	var effect := {"clip": clip, "at": at, "span": span, "face": face, "elapsed": 0.0, "tween": tween}
	effects.append(effect)
	var update := func(elapsed: float):
		effect.elapsed = elapsed
		queue_redraw()
	var length := float(Art.length_ms(clip))
	var split: float = clip.cue if cue.is_valid() else 0.0
	if cue.is_valid():
		tween.tween_method(update, 0.0, split, split / 1000.0)
		tween.tween_callback(cue)
	tween.tween_method(update, split, length, (length - split) / 1000.0)
	tween.tween_callback(func():
		effects.erase(effect)
		queue_redraw())
	return tween


func _draw() -> void:
	paint_tiles()
	if rules == null:
		return
	var direction := 1 if hero_point.x <= wolf_point.x else -1
	actor_ring(hero_point, GREEN)
	actor_ring(wolf_point, AMBER)
	if cover_ray > 0 and rules.uses_cover():
		var blocker := rules.ray_blocker(rules.hero, rules.wolf)
		if blocker >= 0 and Rules.distance(rules.hero, rules.wolf) <= cover_ray:
			var stop := cell_center(blocker)
			draw_dashed_line(hero_point, stop, Color("#c5f7ffb0"), 2.0, 7.0, true, true)
			terrain_frame(Art.TELEGRAPHS, Rect2(stop - TILE * .5, TILE), Vector2i(3, 0), Color.WHITE, hero_point.x > stop.x)
	var hero_tint := Color("#7f8b86") if rules.result == Rules.DEFEAT and hero_art == "ready" else Color.WHITE
	if veiled:
		hero_tint = Color("#b6e7e7a6")
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
	if not fallen and rules.tactic == "thunder_boss":
		wolf_tint = Color("#c9bcff") if rules.wolf_hp * 2 <= rules.wolf_max else Color("#acc9ff")
	elif not fallen and rules.tactic == "marsh":
		wolf_tint = Color("#bddf9b")
	elif not fallen and rules.tactic == "wind_pass":
		wolf_tint = Color("#bbdeff")
	elif not fallen and rules.tactic == "seal_altar":
		wolf_tint = Color("#bdb2dc") if rules.seal_turns == 0 else Color("#edd2b8")
	elif not fallen and rules.tactic == "pulse_boss":
		wolf_tint = Color("#f49c73") if rules.wolf_hp * 2 <= rules.wolf_max else Color("#ded0b1")
	if room == 2:
		atlas_frame(WOLF_KING, 4, 5, wolf_frame, wolf_point + Vector2(0, 25), 193, -direction, wolf_tint)
	else:
		var wolf_size := 142 if rules.tactic in ["den", "marsh", "wind_pass"] else 118
		atlas_frame(WOLF, 4, 4, wolf_frame, wolf_point + Vector2(0, 11), wolf_size, -direction, wolf_tint)
	if not ward_kind.is_empty():
		draw_effect(Art.LOOPS[ward_kind], loop_time, hero_point, 112, direction, true)
	if brew_stacks > 0:
		draw_effect(Art.LOOPS.stack_two if brew_stacks == 2 else Art.LOOPS.stack_one, loop_time, hero_point, 112, direction, true)
	elif brew_prepared:
		draw_effect(Art.LOOPS.brew, loop_time, hero_point, 112, direction, true)
	if veiled:
		draw_effect(Art.LOOPS.scale_veil, loop_time, hero_point, 112, direction, true)
	elif stone_prepared:
		draw_effect(Art.LOOPS.stone_veil, loop_time, hero_point, 112, direction, true)
	if mark_visible:
		draw_effect(Art.LOOPS.moon_mark, loop_time, wolf_point + Vector2(0, -57), 42, 1, true)
	for effect in effects:
		draw_effect(effect.clip, effect.elapsed, effect.at, effect.span, effect.face)
	if projectile != null:
		draw_circle(projectile_point, 15, Color("#92ddf245"))
		draw_set_transform(projectile_point, projectile_angle)
		var span := Vector2.ONE * projectile_span
		draw_texture_rect(projectile, Rect2(-span * .5, span), false)
		draw_set_transform(Vector2.ZERO)
	if not bolt.is_empty():
		draw_polyline(bolt, Color("#7999eb99"), 7.0, true)
		draw_polyline(bolt, Color("#e4f2ff"), 2.0, true)
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


func cast(at: Vector2, refined: bool, empowered: bool) -> void:
	hero_art = "cast"
	var cast_pose := create_tween()
	cast_pose.tween_method(set_hero_frame, 0.0, 4.0, .31)
	await cast_pose.finished
	var to := at - Vector2(0, 6)
	var launch := hero_point + Vector2(23 if to.x >= hero_point.x else -23, -8)
	projectile = AtlasTexture.new()
	projectile.atlas = Art.MOON_EDGE if refined else MOON
	projectile_span = (73.0 if empowered else 61.0) if refined else 50.0
	var cell := 64 if refined else 32
	var row := 2 if refined and empowered else 0
	var duration := .32 if refined else .24
	projectile.region = Rect2(0, row * cell, cell, cell)
	projectile_angle = launch.angle_to_point(to)
	var flight := create_tween().set_parallel()
	flight.tween_method(func(point: Vector2):
		projectile_point = point
		var phase := clampf(launch.distance_to(point) / maxf(launch.distance_to(to), 1), 0, 1)
		projectile.region.position.x = mini(7, floori(phase * 8)) * cell
		queue_redraw(), launch, to, duration)
	flight.tween_method(set_hero_frame, 4.0, 7.9, duration)
	await flight.finished
	projectile = null
	hero_art = "ready"
	hero_frame = 13


func enemy_contact(exchange: Dictionary, point: Vector2, guarding: bool, recoil: bool = false) -> void:
	exchange_cue.emit("enemy_contact")
	var face := 1 if hero_point.x <= wolf_point.x else -1
	if exchange.evaded:
		veiled = false
		play_effect(Art.CONTACTS.uncloak, hero_point, 112, face)
		play_effect(Art.CONTACTS.lost_target, wolf_point + Vector2(0, -58), 44)
		impact(hero_point + Vector2(0, -15), 0, true, false, "Mất dấu")
		return
	if exchange.absorbed > 0 and Art.CONTACTS.has(ward_kind):
		play_effect(Art.CONTACTS[ward_kind], hero_point, 112, face)
		ward_kind = ""
	if exchange.hero_damage > 0:
		var caption := "Chặn %d  /  −%d" % [exchange.absorbed, exchange.hero_damage] if exchange.absorbed > 0 else ""
		impact(point, exchange.hero_damage, false, guarding, caption)
		if recoil:
			if guarding:
				hero_frame = 14
			else:
				hero_art = "cast"
				hero_frame = 9
	elif exchange.absorbed > 0:
		impact(point, 0, true, false, "Chặn %d" % exchange.absorbed)


func storm_shot(target: Vector2, exchange: Dictionary, guarding: bool) -> void:
	set_wolf_frame(8)
	await get_tree().create_timer(.20).timeout
	var origin := wolf_point + Vector2(0, -22)
	var end := target + Vector2(0, -19)
	var cross := (end - origin).normalized().orthogonal() * 12
	bolt = PackedVector2Array([origin, origin.lerp(end, .24) + cross, origin.lerp(end, .47) - cross,
		origin.lerp(end, .68) + cross, end])
	set_wolf_frame(10)
	enemy_contact(exchange, end, guarding, true)
	queue_redraw()
	await get_tree().create_timer(.16).timeout
	bolt.clear()
	queue_redraw()
	await get_tree().create_timer(.14).timeout


func gu_contact(exchange: Dictionary) -> void:
	match exchange.action:
		"jade_skin", "white_jade":
			ward_kind = exchange.action
		"vital_leaf":
			impact(hero_point + Vector2(0, -16), 0, false, true, "+%d" % exchange.healed)
		"brew", "four_flavors":
			brew_prepared = rules.brew_ready
			brew_stacks = rules.strong_strikes
		"stone_veil":
			stone_prepared = true
		"scale_veil":
			veiled = true
	exchange_cue.emit("player_contact")


func play_exchange(exchange: Dictionary) -> void:
	available.clear()
	exchange_cue.emit("player")
	var guarding: bool = exchange.action == "guard"
	var has_cast_art := Art.CASTS.has(exchange.action)
	var direction := 1 if hero_point.x <= wolf_point.x else -1
	if exchange.action == "move":
		hero_art = "move"
		await slide_hero(exchange.hero_path)
		if stone_prepared and not veiled:
			play_effect(Art.CONTACTS.step_reveal, hero_point, 112, direction)
		stone_prepared = false
	elif exchange.action in ["moon", "moon_edge"]:
		await cast(wolf_point, exchange.action == "moon_edge", exchange.set_trigger)
		mark_visible = rules.moon_mark
	elif exchange.action == "strike":
		var rally := hero_point
		var forward := (wolf_point - hero_point).normalized() * 15
		var strike := create_tween()
		strike.tween_method(func(p: Vector2): hero_point = p; queue_redraw(), rally, rally + forward, .11)
		strike.tween_method(func(p: Vector2): hero_point = p; queue_redraw(), rally + forward, rally, .10)
		await strike.finished
		brew_stacks = rules.strong_strikes
	elif guarding:
		hero_art = "guard"
		var brace := create_tween()
		brace.tween_method(set_hero_frame, 6.0, 13.0, .23)
		await brace.finished
	elif has_cast_art:
		await play_effect(Art.CASTS[exchange.action], hero_point, 112, direction, gu_contact.bind(exchange)).finished
	if not guarding:
		hero_art = "ready"
	if not has_cast_art:
		exchange_cue.emit("player_contact")
	if exchange.wolf_damage > 0:
		if exchange.action == "moon_edge":
			var clip: Dictionary = Art.CONTACTS.marked_edge if exchange.set_trigger else Art.CONTACTS.moon_edge
			play_effect(clip, wolf_point + Vector2(0, 12), 94 if exchange.set_trigger else 78, direction)
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
	elif exchange.enemy_intent.kind in ["thunder", "poison", "wind", "seal_burst", "core_wave"] and not exchange.reaction.is_empty():
		await get_tree().create_timer(.18).timeout
		area_active = true
		queue_redraw()
		enemy_contact(exchange, hero_point + Vector2(0, -15), guarding)
		await get_tree().create_timer(.3).timeout
		area_active = false
	elif exchange.enemy_intent.kind == "flood" and not exchange.reaction.is_empty():
		await get_tree().create_timer(.18).timeout
		flood_active = true
		queue_redraw()
		enemy_contact(exchange, hero_point + Vector2(0, -15), guarding)
		await get_tree().create_timer(.35).timeout
		flood_active = false
	elif exchange.enemy_intent.kind == "fall" and not exchange.reaction.is_empty():
		var rubble := create_tween()
		rubble.tween_method(func(p: float): rubble_progress = p; queue_redraw(), 0.0, .64, .31)
		await rubble.finished
		rubble_progress = .75
		queue_redraw()
		enemy_contact(exchange, hero_point + Vector2(0, -15), guarding)
		await get_tree().create_timer(.22).timeout
		rubble_progress = 1.0
	elif exchange.enemy_intent.kind == "shot" and not exchange.reaction.is_empty():
		await storm_shot(cell_center(exchange.enemy_intent.cells[0]), exchange, guarding)
	elif exchange.reaction in ["heavy", "strike", "ambush", "miss"]:
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
		enemy_contact(exchange, hero_point + (Vector2(0, -9) if guarding else Vector2.ZERO), guarding, true)
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
