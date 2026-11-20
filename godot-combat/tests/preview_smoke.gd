extends SceneTree

const Scene = preload("res://combat_preview.tscn")
var failed := false


func _initialize() -> void:
	call_deferred("exercise")


func verify(condition: bool, description: String) -> void:
	if condition:
		return
	failed = true
	push_error(description)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func wait_turn(scene: Control) -> void:
	for frame in range(180):
		await process_frame
		if not scene.busy:
			return
	verify(false, "Turn animation did not complete")


func capture(filename: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	verify(root.get_texture().get_image().save_png(args[0].path_join(filename)) == OK, "Could not save screenshot")


func hold(seconds: float) -> void:
	if not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless":
		await create_timer(seconds).timeout


func exercise() -> void:
	var scene := Scene.instantiate()
	root.add_child(scene)
	await process_frame
	verify(scene.state.intent.cells.size() == 5, "First turn must telegraph five danger cells")
	verify(scene.state.hero == 17 and scene.state.wolf == 21, "Invalid starting positions")
	await capture("godot-dien-lang.png")
	await hold(.7)
	var guard: Dictionary = scene.state.preview_action("guard")
	verify(guard.receives == 4 and scene.state.hp == 48 and scene.state.turn == 1, "Guard forecast changed the live turn")
	key(KEY_2)
	verify(scene.state.turn == 1, "Out-of-range strike spent a turn")
	key(KEY_1)
	verify(scene.selecting, "Keyboard failed to select move mode")
	key(KEY_RIGHT)
	verify(scene.target_cell == 18 and "chịu 12 sát thương" in scene.hint_label.text, "Dangerous legal target is unclear")
	key(KEY_UP)
	verify(scene.target_cell == 10 and "né được đòn" in scene.hint_label.text, "Safe destination forecast is missing")
	var path: Array = scene.state.preview_action("move", 10).path
	verify(path == [9, 10], "Move preview must find an orthogonal path")
	await capture("godot-chon-o.png")
	await hold(.7)
	key(KEY_ENTER)
	await wait_turn(scene)
	verify(scene.state.turn == 2 and scene.state.hero == 10 and scene.state.hp == 48,
		"Valid dodge through board input failed: turn %d, cell %d, HP %d, pointer cell %d" %
		[scene.state.turn, scene.state.hero, scene.state.hp, scene.field.mouse_cell])
	await hold(.3)
	key(KEY_3)
	key(KEY_3)
	await hold(.42)
	await capture("godot-nguyet-quang.png")
	await wait_turn(scene)
	verify(scene.state.wolf_hp == 22 and scene.state.qi == 2 and scene.state.turn == 3, "Cast or repeat input failed")
	verify(scene.state.preview_action("moon").receives == 0, "Forecast included retaliation after a killing blow")
	await hold(.35)
	key(KEY_3)
	await wait_turn(scene)
	verify(scene.state.result == "win" and scene.state.qi == 0 and scene.state.wolf_hp == 0, "Killing blow did not commit")
	await capture("godot-thang.png")
	await hold(.9)
	if "clip" in OS.get_cmdline_user_args():
		quit(1 if failed else 0)
		return
	key(KEY_R)
	verify(scene.state.turn == 1 and scene.state.hp == 48 and scene.state.qi == 4, "Restart did not restore a fresh battle")
	key(KEY_4)
	verify(scene.hp_label.text == "48 / 48" and scene.busy, "HP changed in the HUD before the wolf hit")
	for frame in range(80):
		if scene.hp_label.text == "44 / 48":
			break
		await process_frame
	verify(scene.hp_label.text == "44 / 48" and scene.busy and scene.field.hero_art == "guard",
		"Guard contact should update HP while the turn remains locked")
	await capture("godot-do-don.png")
	await wait_turn(scene)
	verify(scene.state.hp == 44 and scene.state.turn == 2, "Guard should reduce 12 damage to 4")
	key(KEY_R)
	scene.state.hp = 1
	key(KEY_4)
	await wait_turn(scene)
	verify(scene.state.result == "loss" and scene.state.hp == 0, "Defeat did not stop combat")
	key(KEY_R)
	verify(scene.state.result.is_empty() and scene.state.wolf_hp == 48 and scene.state.hp == 48, "Retry did not reset defeat")
	key(KEY_1)
	click(scene.field.position + scene.field.cell_center(10))
	await wait_turn(scene)
	verify(scene.state.hero == 10 and scene.state.turn == 2, "Mouse could not commit a selected cell")
	if not failed:
		print("Godot preview passed: forecasts, keyboard and mouse path, committed contact, duplicate key, win, guard, loss, retry")
	quit(1 if failed else 0)
