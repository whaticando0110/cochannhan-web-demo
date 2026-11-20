extends Control

var target := 0.0
var fill := 0.0
var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	fill = target * (1 - pow(1 - clampf(elapsed / .85, 0, 1), 3))
	queue_redraw()


func _draw() -> void:
	var center := size / 2
	draw_circle(center, 80, Color("#80c3b31e"), true, -1, true)
	draw_circle(center, 71, Color("#101e25"), true, -1, true)
	var horizon := 70.0 - fill * 140
	for y in range(ceili(horizon), 70):
		var span := sqrt(maxf(0, 70 * 70 - y * y))
		var depth := clampf((y - horizon) / 110.0, 0, 1)
		var shade := Color("#61b096").lerp(Color("#1a3b3c"), depth)
		if y % 7 < 2:
			shade = shade.lightened(.1 + sin(y + elapsed * 2) * .07)
		draw_line(center + Vector2(-span, y), center + Vector2(span, y), shade, 1.4)
	var breadth := sqrt(maxf(0, 70.0 * 70 - horizon * horizon))
	draw_line(center + Vector2(-breadth, horizon), center + Vector2(breadth, horizon), Color("#bdeedc"), 2.0, true)
	draw_arc(center, 72, 0, TAU, 100, Color("#aeece1"), 4, true)
	draw_arc(center, 75, 0, TAU, 100, Color("#defaf0"), 1.5, true)
