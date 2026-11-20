extends Control

const Rules = preload("res://battle_rules.gd")
const TRAIL = preload("res://assets/trail.png")
const MULCH = preload("res://assets/mulch.png")
const STONE = preload("res://assets/stone.png")
const HUYEN_BAO = preload("res://assets/huyen-bao.png")
const AO_REU = preload("res://assets/ao-reu-travel.png")
const NGOC_BI_ATLAS = preload("res://assets/gu-review/ngoc-bi-co.png")
const NGOC_BI_ICON = preload("res://assets/gu-review/ngoc-bi-co-icon.png")
const SINH_CO_ATLAS = preload("res://assets/gu-review/sinh-co-diep.png")
const SINH_CO_ICON = preload("res://assets/gu-review/sinh-co-diep-icon.png")

const TILE := Vector2(91, 82)
const ORIGIN := Vector2(40, 128)
const VFX_SPAN := 112.0

const NGOC_CAST_DURS := [80, 80, 90, 90, 85, 85]
const NGOC_SUSTAIN_DURS := [110, 110, 110, 110, 110, 110]
const NGOC_IMPACT_DURS := [50, 65, 80, 85, 90, 90]
const SINH_DURS := [75, 80, 85, 95, 95, 90, 80, 80]

var active_mode := "all" # "all", "ngoc", or "sinh"
var ngoc_clip := "impact_flash"
var ngoc_ms := 0.0
var sinh_ms := 0.0
var playing := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(delta: float) -> void:
	if not playing:
		return
	var dms := delta * 1000.0
	ngoc_ms = fmod(ngoc_ms + dms, clip_duration_ms("ngoc", ngoc_clip))
	sinh_ms = fmod(sinh_ms + dms, clip_duration_ms("sinh", "heal"))
	queue_redraw()


static func clip_duration_ms(gu_id: String, clip_name: String) -> float:
	if gu_id == "sinh":
		return 680.0
	match clip_name:
		"cast":
			return 510.0
		"sustain":
			return 660.0
		_:
			return 460.0


func frame_for_durations(elapsed: float, durs: Array) -> int:
	var acc := 0.0
	for i in range(durs.size()):
		acc += float(durs[i])
		if elapsed < acc:
			return i
	return durs.size() - 1


func sample_ngoc_bi(time_ms: float, clip_name: String = "impact_flash") -> Dictionary:
	var row := 2
	var durs := NGOC_IMPACT_DURS
	if clip_name == "cast":
		row = 0
		durs = NGOC_CAST_DURS
	elif clip_name == "sustain":
		row = 1
		durs = NGOC_SUSTAIN_DURS
	var col := frame_for_durations(fmod(maxf(0.0, time_ms), clip_duration_ms("ngoc", clip_name)), durs)
	return {
		"clip": clip_name,
		"row": row,
		"col": col,
		"atlas_index": row * 6 + col,
		"is_contact": clip_name == "impact_flash" and col <= 1,
	}


func sample_sinh_co_diep(time_ms: float) -> Dictionary:
	var t := fmod(maxf(0.0, time_ms), 680.0)
	var col := frame_for_durations(t, SINH_DURS)
	return {
		"clip": "heal",
		"row": 0,
		"col": col,
		"atlas_index": col,
		"is_peak": col == 3,
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			playing = not playing
		KEY_1:
			ngoc_clip = "cast"
			ngoc_ms = 0.0
		KEY_2:
			ngoc_clip = "sustain"
			ngoc_ms = 0.0
		KEY_3:
			ngoc_clip = "impact_flash"
			ngoc_ms = 0.0
		KEY_A:
			active_mode = "all"
	queue_redraw()


func atlas_frame(texture: Texture2D, cols: int, rows: int, frame: int, center: Vector2, span: float) -> void:
	var cell_size := texture.get_size() / Vector2(cols, rows)
	@warning_ignore("integer_division")
	var region := Rect2(Vector2(frame % cols, frame / cols) * cell_size, cell_size)
	var pivot := Vector2(-span * 0.5, -span * 0.77)
	draw_set_transform(center, 0, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(pivot, Vector2(span, span)), region, Color.WHITE)
	draw_set_transform(Vector2.ZERO)


func draw_quadrant_grid(origin: Vector2, ground_top: Texture2D, ground_bot: Texture2D, skin_top_l: String, skin_top_r: String) -> void:
	var grounds := [ground_top, ground_bot]
	for qy in range(2):
		for qx in range(2):
			var qOrigin := origin + Vector2(qx * TILE.x * 2, qy * TILE.y * 2)
			for r in range(2):
				for c in range(2):
					var rect := Rect2(qOrigin + Vector2(c, r) * TILE, TILE)
					var variant := ((c + 1) * 3 + (r + 1) * 5) % 8
					var tex: Texture2D = grounds[qy]
					if qy == 0 and qx == 1:
						tex = MULCH
					var sw := tex.get_width() / 8.0
					draw_texture_rect_region(tex, rect, Rect2(variant * sw, 0, sw, tex.get_height()), Color(0.72, 0.72, 0.65))
					draw_rect(rect, Color("#64705566"), false, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#182a22"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 42),
		"Duyệt Ngọc Bì Cổ (Trái) & Sinh Cơ Diệp (Phải) trên Huyền bào / Áo rêu × Nền đất / Hang đá",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f1d89f"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 68),
		"[1] Ngọc Bì: Phát   [2] Ngọc Bì: Giữ   [3] Ngọc Bì: Lóe chịu đòn (%s)   [Space] Phát/Dừng" % ngoc_clip,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#aebfb4"))

	var leftOrigin := ORIGIN
	var rightOrigin := ORIGIN + Vector2(440, 0)
	draw_quadrant_grid(leftOrigin, TRAIL, STONE, "hb", "ar")
	draw_quadrant_grid(rightOrigin, TRAIL, STONE, "hb", "ar")

	var nSample := sample_ngoc_bi(ngoc_ms, ngoc_clip)
	var sSample := sample_sinh_co_diep(sinh_ms)

	for qy in range(2):
		for qx in range(2):
			var is_ar := qx == 1
			for side in range(2):
				var base := leftOrigin if side == 0 else rightOrigin
				var center := base + Vector2(qx * TILE.x * 2 + TILE.x, qy * TILE.y * 2 + TILE.y + 8)
				draw_set_transform(center + Vector2(0, 24), 0, Vector2(1, 0.31))
				draw_circle(Vector2.ZERO, 27.0, Color("#090f0bb8"))
				draw_arc(Vector2.ZERO, 27.0, 0, TAU, 50, Color("#a9e2bb"), 1.8, true)
				draw_set_transform(Vector2.ZERO)
				if is_ar:
					atlas_frame(AO_REU, 8, 4, 0, center, 109.0)
				else:
					atlas_frame(HUYEN_BAO, 8, 6, 13, center, 113.0)
				if side == 0:
					atlas_frame(NGOC_BI_ATLAS, 6, 3, nSample.atlas_index, center, VFX_SPAN)
				else:
					atlas_frame(SINH_CO_ATLAS, 8, 1, sSample.atlas_index, center, VFX_SPAN)

	draw_texture_rect(NGOC_BI_ICON, Rect2(leftOrigin + Vector2(TILE.x * 4 - 40, 6), Vector2(32, 32)), false)
	draw_texture_rect(SINH_CO_ICON, Rect2(rightOrigin + Vector2(TILE.x * 4 - 40, 6), Vector2(32, 32)), false)
