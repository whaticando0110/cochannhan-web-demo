extends Control

signal exchange_contact(at_ms: float)
signal exchange_completed

const Rules = preload("res://battle_rules.gd")
const TRAIL = preload("res://assets/trail.png")
const THICKET = preload("res://assets/thicket.png")
const ROCK = preload("res://assets/rock-ridge.png")
const HERO_OLD = preload("res://assets/huyen-bao.png")
const WOLF = preload("res://assets/dien-lang.png")
const GUARD_ATLAS = preload("res://assets/guard-review/huyen-bao-guard.png")

const ORIGIN := Vector2(39, 135)
const TILE := Vector2(91, 82)
const HERO_CELL := 18 # C3 (col 2, row 2)
const WOLF_CELL := 19 # D3 (col 3, row 2)
const HERO_SPAN := 112.0
const WOLF_SPAN := 118.0
const CELL_SIZE := Vector2i(128, 128)
const FOOT_ANCHOR_128 := Vector2(64, 120)
const SLEEVE_BLOCK_128 := Vector2(88, 76)
const SLEEVE_BLOCK_OFFSET_112 := Vector2(21.0, -19.7)

const FRAME_DURATIONS_MS := [70, 80, 90, 280, 95, 115, 100, 100]
const FRAME_TIMES_MS := [0, 70, 150, 240, 520, 615, 730, 830]
const TOTAL_DURATION_MS := 930.0
const CONTACT_MS := 520.0
const CONTACT_HERO_FRAME := 4
const CONTACT_WARD_FX_FRAME := 12
const CONTACT_WOLF_FRAME := 10

var elapsed_ms := 0.0
var playing := true
var loop_playback := true
var show_ward_fx := true
var show_block_reticle := true
var compare_old_pose := false
var contact_emitted := false
var current_sample := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	current_sample = sample_exchange(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not playing:
		return
	var prev_ms := elapsed_ms
	elapsed_ms += delta * 1000.0
	if prev_ms < CONTACT_MS and elapsed_ms >= CONTACT_MS and not contact_emitted:
		contact_emitted = true
		exchange_contact.emit(CONTACT_MS)
	if elapsed_ms >= TOTAL_DURATION_MS:
		exchange_completed.emit()
		if loop_playback:
			elapsed_ms = fmod(elapsed_ms, TOTAL_DURATION_MS)
			contact_emitted = false
		else:
			elapsed_ms = TOTAL_DURATION_MS
			playing = false
	current_sample = sample_exchange(elapsed_ms)
	queue_redraw()


func cell_center(cell: int) -> Vector2:
	return ORIGIN + (Vector2(Rules.grid(cell)) + Vector2(0.5, 0.5)) * TILE


func hero_frame_at(time_ms: float) -> int:
	var clamped := clampf(time_ms, 0.0, TOTAL_DURATION_MS - 0.01)
	var idx := 0
	for i in range(FRAME_TIMES_MS.size()):
		if clamped >= float(FRAME_TIMES_MS[i]):
			idx = i
	return idx


func sample_exchange(time_ms: float) -> Dictionary:
	var t := clampf(time_ms, 0.0, TOTAL_DURATION_MS)
	var hero_idx := hero_frame_at(t)
	var hero_pos := cell_center(HERO_CELL)
	var wolf_start := cell_center(WOLF_CELL)
	var direction := 1 if hero_pos.x <= wolf_start.x else -1
	var vector := hero_pos - wolf_start
	var landing := hero_pos - vector.normalized() * minf(47.0, vector.length() * 0.42)
	var coil_pos := wolf_start - vector.normalized() * 10.0

	var wolf_idx := 0
	var wolf_pos := wolf_start
	var phase := "brace"

	if t < 240.0:
		phase = "brace"
		wolf_idx = 0
		wolf_pos = wolf_start
	elif t < 400.0:
		phase = "wolf_lunge"
		wolf_idx = 8
		var p := (t - 240.0) / 160.0
		wolf_pos = wolf_start.lerp(coil_pos, p)
	elif t < CONTACT_MS:
		phase = "wolf_lunge"
		wolf_idx = 9
		var p := (t - 400.0) / (CONTACT_MS - 400.0)
		wolf_pos = coil_pos.lerp(landing, p)
	elif t < 615.0:
		phase = "block_impact"
		wolf_idx = CONTACT_WOLF_FRAME
		wolf_pos = landing
	elif t < 730.0:
		phase = "block_impact"
		wolf_idx = 11
		var p := (t - 615.0) / (730.0 - 615.0)
		wolf_pos = landing.lerp(wolf_start, p * 0.55)
	else:
		phase = "recover"
		var p := (t - 730.0) / (TOTAL_DURATION_MS - 730.0)
		wolf_idx = 11 if p < 0.5 else 0
		wolf_pos = landing.lerp(wolf_start, 0.55 + p * 0.45)

	var block_point := hero_pos + Vector2(SLEEVE_BLOCK_OFFSET_112.x * direction, SLEEVE_BLOCK_OFFSET_112.y)
	return {
		"elapsed_ms": t,
		"phase": phase,
		"hero_frame": hero_idx,
		"ward_fx_frame": 8 + hero_idx,
		"wolf_frame": wolf_idx,
		"hero_point": hero_pos,
		"wolf_point": wolf_pos,
		"direction": direction,
		"sleeve_block_point": block_point,
		"is_contact": t >= CONTACT_MS and t < 615.0,
	}


func step_to_frame(index: int) -> void:
	playing = false
	var clamped := clampi(index, 0, FRAME_TIMES_MS.size() - 1)
	elapsed_ms = float(FRAME_TIMES_MS[clamped]) + 1.0
	current_sample = sample_exchange(elapsed_ms)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			if not playing and elapsed_ms >= TOTAL_DURATION_MS:
				elapsed_ms = 0.0
				contact_emitted = false
			playing = not playing
		KEY_RIGHT:
			step_to_frame((int(current_sample.get("hero_frame", 0)) + 1) % 8)
		KEY_LEFT:
			step_to_frame((int(current_sample.get("hero_frame", 0)) + 7) % 8)
		KEY_V:
			show_ward_fx = not show_ward_fx
			queue_redraw()
		KEY_B:
			show_block_reticle = not show_block_reticle
			queue_redraw()
		KEY_C:
			compare_old_pose = not compare_old_pose
			queue_redraw()


func atlas_frame(texture: Texture2D, cols: int, rows: int, frame: int, center: Vector2, span: float, face: int) -> void:
	var cell_size := texture.get_size() / Vector2(cols, rows)
	@warning_ignore("integer_division")
	var region := Rect2(Vector2(frame % cols, frame / cols) * cell_size, cell_size)
	var pivot := Vector2(-span * 0.5, -span * 0.77)
	draw_set_transform(center, 0, Vector2(face, 1))
	draw_texture_rect_region(texture, Rect2(pivot, Vector2(span, span)), region, Color.WHITE)
	draw_set_transform(Vector2.ZERO)


func actor_ring(center: Vector2, tone: Color) -> void:
	draw_set_transform(center + Vector2(0, 24), 0, Vector2(1, 0.31))
	draw_circle(Vector2.ZERO, 27.0, Color("#090f0bb8"))
	draw_arc(Vector2.ZERO, 27.0, 0, TAU, 50, tone, 1.8, true)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182a22"))
	var grid_rect := Rect2(ORIGIN, TILE * Vector2(Rules.COLUMNS, Rules.ROWS))
	draw_rect(grid_rect.grow(5), Color("#65563b"))
	var rocks := [9, 14, 26]
	for cell in range(Rules.ROWS * Rules.COLUMNS):
		var point := Rules.grid(cell)
		var rect := Rect2(ORIGIN + Vector2(point) * TILE, TILE)
		var variant := (point.x * 3 + point.y * 5 + point.x * point.y) % 8
		var edge := mini(point.x, Rules.COLUMNS - point.x - 1)
		var shade := 0.67 + 0.05 * mini(edge, 2)
		var sample := TRAIL.get_width() / 8.0
		draw_texture_rect_region(TRAIL, rect, Rect2(variant * sample, 0, sample, TRAIL.get_height()), Color(shade, shade, shade * 0.88))
		draw_rect(rect, Color("#a0ad793b"), false, 1.0)
		if cell in rocks:
			draw_texture_rect(ROCK, Rect2(rect.get_center() - Vector2(39, 40), Vector2(78, 78)), false)
		if cell == HERO_CELL and current_sample.get("elapsed_ms", 0.0) < CONTACT_MS:
			draw_rect(rect.grow(-1), Color("#ffc29a40"))
			draw_rect(rect.grow(-1), Color("#ffc29aeb"), false, 1.5)

	for x in range(52, 752, 84):
		draw_texture_rect(THICKET, Rect2(x, ORIGIN.y - 34, 84, 34), false, Color("#91a47e"))
		draw_texture_rect(THICKET, Rect2(x - 10, ORIGIN.y + TILE.y * Rules.ROWS + 3, 90, 32), false, Color("#7c967a"))

	var s := current_sample if not current_sample.is_empty() else sample_exchange(0.0)
	var hero_pt: Vector2 = s.hero_point
	var wolf_pt: Vector2 = s.wolf_point
	var dir: int = s.direction
	actor_ring(hero_pt, Color("#a9e2bb"))
	actor_ring(wolf_pt, Color("#efae82"))

	if compare_old_pose:
		var old_map := [13, 10, 12, 13, 14, 15, 16, 13]
		atlas_frame(HERO_OLD, 8, 6, old_map[s.hero_frame], hero_pt, 113.0, dir)
	else:
		atlas_frame(GUARD_ATLAS, 8, 2, s.hero_frame, hero_pt, HERO_SPAN, dir)

	atlas_frame(WOLF, 4, 4, s.wolf_frame, wolf_pt + Vector2(0, 11), WOLF_SPAN, -dir)

	if show_ward_fx and not compare_old_pose:
		atlas_frame(GUARD_ATLAS, 8, 2, s.ward_fx_frame, hero_pt, HERO_SPAN, dir)

	if s.elapsed_ms >= CONTACT_MS and s.elapsed_ms < 820.0:
		var prog := clampf((s.elapsed_ms - CONTACT_MS) / 300.0, 0.0, 1.0)
		var alpha := 1.0 - prog
		var blk: Vector2 = s.sleeve_block_point
		draw_arc(blk, 6.0 + prog * 26.0, 0, TAU, 24, Color(Color("#f8d68c"), alpha * 0.85), 2.0, true)
		draw_string(ThemeDB.fallback_font, hero_pt + Vector2(-18, -22 - 24 * prog), "Đỡ  −4",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Color("#f8d68c"), alpha))

	if show_block_reticle:
		var blk: Vector2 = s.sleeve_block_point
		draw_line(blk + Vector2(-6, 0), blk + Vector2(6, 0), Color("#78f5ff"), 1.5)
		draw_line(blk + Vector2(0, -6), blk + Vector2(0, 6), Color("#78f5ff"), 1.5)

	draw_string(ThemeDB.fallback_font, Vector2(39, 44),
		"Duyệt Mẫu Thủ Thế & Đỡ Đòn Điện Lang  ·  Khung %d/7 (%s)  ·  %.0f / %.0f ms" %
		[s.hero_frame, s.phase, s.elapsed_ms, TOTAL_DURATION_MS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f1d89f"))
	draw_string(ThemeDB.fallback_font, Vector2(39, 72),
		"[Space] Phát/Dừng   [Left/Right] Từng khung   [V] Bật/tắt VFX hộ thân   [B] Tâm chặn tay áo [88,76]   [C] So sánh pose cũ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#aebfb4"))
