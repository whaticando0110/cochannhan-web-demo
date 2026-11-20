extends SceneTree

const Scene = preload("res://combat_preview.tscn")
const Art = preload("res://combat_art.gd")
const Run = preload("res://run_state.gd")
var failed := false


func _initialize() -> void:
	call_deferred("exercise")


func check(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)


func capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(args[0].path_join(name)) == OK, "Capture failed for " + name)


func training(overrides: Dictionary = {}) -> Control:
	var options := {"stage": Run.CHAPTER_TWO, "room": 3, "tactic": "storm", "hero": "huyen-bao",
		"grade": "Giáp đẳng", "hp": 24, "qi": 4, "max_qi": 7, "jade_skin": true, "leaves": 1}
	options.merge(overrides, true)
	var scene := Scene.instantiate()
	scene.configure_training(options)
	root.add_child(scene)
	return scene


func wait_turn(scene: Control) -> void:
	for frame in range(150):
		if not scene.busy:
			return
		await process_frame
	check(false, "Timed exchange did not release input")


func check_frames() -> void:
	for group in [Art.CASTS, Art.LOOPS, Art.CONTACTS]:
		for name in group:
			var clip: Dictionary = group[name]
			var size: Vector2 = clip.texture.get_size()
			var bounds := Rect2(Vector2.ZERO, size)
			var end := Art.frame_region(clip, Art.length_ms(clip) - 1)
			check(bounds.encloses(end), "Atlas frame outside bounds for " + name)
			if clip.has("cue"):
				check(clip.cue > 0 and clip.cue < Art.length_ms(clip), "Invalid contact time for " + name)
	check(Art.frame_region(Art.CASTS.vital_leaf, 239).position.x == 256
		and Art.frame_region(Art.CASTS.vital_leaf, 240).position.x == 384, "Heal cue must begin on frame three")
	check(Art.frame_region(Art.LOOPS.moon_mark, 600, true).position.x == 0, "Moon mark loop did not wrap")


func test_cast(action: String, setup: Dictionary) -> void:
	var scene := training(setup)
	if action == "four_flavors":
		scene.choose("brew")
		await wait_turn(scene)
	var contacts: Array[float] = []
	scene.field.exchange_cue.connect(func(cue: String):
		if cue == "player_contact":
			var active: Array = scene.field.effects
			contacts.append(float(active[0].elapsed) if not active.is_empty() else -1.0))
	var starting_hp: String = scene.hp_label.text
	scene.choose(action)
	check(scene.busy and scene.actions[action].icon == Art.ICONS[action] and scene.hp_label.text == starting_hp,
		"Effect, icon or initial HUD is missing for " + action)
	for frame in range(50):
		if not contacts.is_empty():
			break
		await process_frame
	check(contacts.size() == 1 and is_equal_approx(contacts[0], float(Art.CASTS[action].cue)),
		"Wrong frame for action contact " + action)
	if action == "vital_leaf":
		check(scene.hp_label.text == "36 / 48", "Heal bar did not update on the leaf frame")
	if action in ["vital_leaf", "white_jade", "four_flavors", "scale_veil"]:
		await capture("godot-art-" + action + ".png")
	if action == "scale_veil":
		var lost := false
		for frame in range(90):
			if not scene.busy:
				break
			if scene.field.effects.any(func(effect: Dictionary): return effect.clip == Art.CONTACTS.lost_target and effect.elapsed >= 140):
				lost = true
				await capture("godot-art-lac-muc-tieu.png")
				break
			await process_frame
		check(lost and scene.state.hp == 24, "Evaded attack did not show the lost-target effect")
	await wait_turn(scene)
	if action == "four_flavors":
		check(scene.state.strong_strikes == 2 and scene.field.brew_stacks == 2, "Tứ Vị did not display the stronger two-stack artwork")
		await capture("godot-art-tu-vi-hai-tang.png")
	check(contacts.size() == 1, "Duplicate player contact for " + action)
	scene.reset_battle()
	check(scene.field.effects.is_empty(), "Retry left an active effect for " + action)
	scene.queue_free()
	await process_frame


func test_moon_edge() -> void:
	for marked in [false, true]:
		var scene := training({"refined_gu": "moon_edge", "jade_skin": false})
		scene.state.moon_mark = marked
		scene.field.set_state(scene.state)
		scene.choose("moon_edge")
		var seen := false
		for frame in range(74):
			await process_frame
			var flight: AtlasTexture = scene.field.projectile
			if flight != null and flight.region.position.x > 64:
				seen = true
				check(flight.atlas == Art.MOON_EDGE and flight.region.position.y == (128.0 if marked else 0.0)
					and scene.wolf_label.text == "72 / 72", "Wrong projectile row or enemy HP advanced before contact")
				await capture("godot-art-moon-marked.png" if marked else "godot-art-moon-edge.png")
				break
		await wait_turn(scene)
		check(seen and scene.state.wolf_hp == (30 if marked else 42), "Moon edge did not resolve its original damage")
		scene.queue_free()
		await process_frame


func exercise() -> void:
	check_frames()
	await test_cast("jade_skin", {})
	await test_cast("white_jade", {"refined_gu": "white_jade", "starter_gu": "jade_skin", "moon_equipped": false})
	await test_cast("vital_leaf", {"hero": "ao-reu"})
	await test_cast("brew", {"starter_gu": "brew", "moon_equipped": false, "jade_skin": false, "qi": 2})
	await test_cast("four_flavors", {"refined_gu": "four_flavors", "starter_gu": "brew", "moon_equipped": false, "jade_skin": false})
	await test_cast("stone_veil", {"starter_gu": "stone_veil", "moon_equipped": false, "jade_skin": false})
	await test_cast("scale_veil", {"refined_gu": "scale_veil", "starter_gu": "stone_veil", "moon_equipped": false, "jade_skin": false})
	await test_moon_edge()
	var ford := training({"stage": Run.THUNDER_FORD, "room": 4, "tactic": "ford"})
	check(ford.field.water_mask(Vector2i(2, 2)) == 6 and ford.field.water_mask(Vector2i(3, 2)) == 14,
		"Water masks must match the actual wet tile adjacency")
	await capture("godot-art-suoi-sam.png")
	ford.queue_free()
	await process_frame
	var canyon := training({"stage": Run.AMBUSH_PASS, "room": 5, "tactic": "ambush", "hero": "ao-reu"})
	canyon.choose("guard")
	await wait_turn(canyon)
	canyon.choose("guard")
	await wait_turn(canyon)
	check(canyon.field.rubble_warning and canyon.field.threatened == canyon.state.cracks, "Rockfall art drifted from danger cells")
	await capture("godot-art-hem-da.png")
	if not failed:
		print("Godot art passed: eight icon/atlas actions, contact cues, matched water mask and rockfall cells")
	quit(1 if failed else 0)
