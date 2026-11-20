extends SceneTree

const Scene = preload("res://run_flow.tscn")
const Run = preload("res://run_state.gd")
const Rules = preload("res://battle_rules.gd")
const Awakening = preload("res://awakening_rules.gd")

var failed := false
var path: String
var flow: Control


func _initialize() -> void:
	call_deferred("exercise")


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func click_button(name: String) -> void:
	var button := flow.find_child(name, true, false) as Button
	check(button != null, "Missing button %s" % name)
	if button != null:
		click(button.get_global_rect().get_center())
	await process_frame


func wait_until(condition: Callable, message: String, frames: int = 900) -> void:
	for index in range(frames):
		if condition.call():
			return
		await process_frame
	check(false, message)


func shoot(code: Key, target: int = -1) -> void:
	var active: Control = flow.current
	var handle := active.get_instance_id()
	key(code)
	if target >= 0:
		click(active.field.position + active.field.cell_center(target))
	await wait_until(func(): return flow.current.get_instance_id() != handle or not flow.current.busy, "Unfinished exchange")
	await process_frame


func launch() -> void:
	if is_instance_valid(flow):
		root.remove_child(flow)
		flow.queue_free()
	flow = Scene.instantiate()
	flow.save_path = path
	flow.ceremony_limit = 12
	root.add_child(flow)
	await process_frame


func capture(name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(args[0].path_join(name)) == OK, "Could not save " + name)


func play_commands(commands: Array) -> void:
	for command in commands:
		await shoot(command[0], command[1] if command.size() == 2 else -1)


func check_gu_and_tactics() -> void:
	var ward := Rules.new({"jade_skin": true})
	var peek := ward.preview_action("jade_skin")
	check(peek.absorbed == 5 and peek.receives == 7 and peek.qi == 3
		and ward.turn == 1 and ward.hp == 48 and ward.jade_turns == 0, "Ngọc Bì forecast mutated or misread the exchange")
	check(ward.take_turn("jade_skin").absorbed == 5 and ward.hp == 41 and ward.jade_turns == 0, "First hit did not spend the ward")
	ward.intent = {"kind": "advance", "cells": [], "damage": 0}
	ward.take_turn("jade_skin")
	check(ward.jade_turns == 1 and ward.take_turn("jade_skin").has("error"), "An active ward may not be replaced")
	ward.intent = {"kind": "heavy", "name": "Vồ mồi", "cells": [ward.hero], "damage": 12}
	peek = ward.preview_action("guard")
	check(peek.absorbed == 4 and peek.receives == 0, "Guard should reduce damage before Ngọc Bì")
	ward.take_turn("guard")
	check(ward.jade_turns == 0 and ward.hp == 41, "Guard plus ward changed the wrong HP")

	var missed := Rules.new({"jade_skin": true})
	missed.intent = {"kind": "advance", "cells": [], "damage": 0}
	missed.take_turn("jade_skin")
	missed.intent = {"kind": "advance", "cells": [], "damage": 0}
	missed.take_turn("guard")
	check(missed.jade_turns == 0, "Ward must expire after two enemy responses even without contact")

	var herbs := Rules.new({"hp": 44, "leaves": 1})
	peek = herbs.preview_action("vital_leaf")
	check(peek.healed == 4 and peek.receives == 12 and herbs.leaves == 1, "Leaf forecast did not cap healing")
	herbs.take_turn("vital_leaf")
	check(herbs.hp == 36 and herbs.leaves == 0 and herbs.qi == 4, "Leaf must heal before retaliation and spend exactly one leaf")
	check(herbs.take_turn("vital_leaf").has("error") and herbs.turn == 2, "Empty inventory spent a turn")
	var full := Rules.new({"leaves": 1})
	check(full.take_turn("vital_leaf").has("error") and full.leaves == 1, "Leaf was spent at full health")

	var ravine := Run.battle_for(Run.ROUTES.ravine, 0, 48, 4, 4, 0, {}, "ravine")
	check(ravine.ray_blocker(17, 21) == 20 and ravine.ray_blocker(21, 17) == 20, "Cover must block both directions")
	check(ravine.take_turn("moon").has("error") and ravine.qi == 4 and ravine.turn == 1, "Blocked shot spent resources")
	ravine.hero = 13
	check(ravine.ray_blocker(13, 21) == -1 and ravine.preview_action("moon").dealt == 26, "An open firing line was rejected")
	var elite := Run.battle_for(Run.ROUTES.elite, 0, 48, 4, 4, 0, {}, "elite")
	elite.take_turn("move", 10)
	elite.take_turn("guard")
	check(elite.intent.pattern == "row" and elite.intent.row == 1 and 12 not in elite.intent.cells, "Elite did not lock the expected row")
	peek = elite.preview_action("move", 2)
	check(peek.receives == 0, "Changing rows should avoid the charge")
	check(elite.take_turn("move", 2).reaction == "miss", "Averted charge did not resolve as a miss")
	var king := Run.battle_for(Run.FLOORS[2], 0, 48, 7, 7, 0, {}, "king")
	check(king.intent.get("pattern") == null, "The king begins with a pounce")
	king.take_turn("moon")
	check(king.intent.kind == "recover", "The king must recover after a heavy")
	king.take_turn("guard")
	check(king.intent.get("pattern") == "row", "The king must switch to a sweep")
	king.take_turn("moon")
	check(king.enraged_phase() and king.intent.kind == "recover", "Crossing the threshold must preserve the recovery window")
	king.take_turn("guard")
	check(king.intent.get("pattern") == "row", "Enraged cadence must change the next committed pattern")


func check_third_save() -> void:
	var current_run := Run.new(Awakening.profile_for("huyen-bao", 40), 5)
	current_run.perform("moon")
	current_run.perform("moon")
	check(current_run.choose_route("ravine") and current_run.reward("jade_skin"), "Run did not award Ngọc Bì")
	check(current_run.battle.jade_skin and current_run.battle.jade_turns == 0, "Ngọc Bì did not travel into room two")
	check(not current_run.perform("jade_skin").has("error"), "Unlocked Ngọc Bì could not be used")
	var young: RefCounted = Run.restore(current_run.snapshot())
	check(young != null and young.battle.qi == current_run.battle.qi
		and young.battle.hp == current_run.battle.hp and young.battle.jade_turns == current_run.battle.jade_turns,
		"Reload changed the ward exchange")
	var fresh := Run.new(current_run.profile, 5)
	check(not fresh.battle.jade_skin and fresh.battle.leaves == 0, "A new run inherited Gu")


func play_rest_and_leaf() -> void:
	var starting := {"version": 3, "hero": "huyen-bao", "depth": 12, "seed": 0,
		"journal": [["moon", -1], ["moon", -1], ["ravine"], ["refine"], ["move", 19], ["move", 28],
			["strike", -1], ["strike", -1], ["moon", -1]]}
	flow.run = Run.restore(starting)
	check(flow.run != null and flow.run.phase == "reward", "v3 did not reach the Khe đá reward")
	if flow.run == null:
		return
	flow.show_run()
	await click_button("vital_leaf")
	check(flow.run.phase == "rest" and flow.run.battle.leaves == 1, "Leaf reward did not lead to rest")
	await launch()
	check(flow.run.phase == "rest" and flow.run.battle.leaves == 1, "Reload lost the rest choice or leaf")
	await capture("godot-v3-diem-nghi.png")
	var rest_copy: RefCounted = Run.restore(flow.run.snapshot())
	var hp_before: int = rest_copy.battle.hp
	check(rest_copy.rest("rest_hp") and rest_copy.battle.hp == mini(48, hp_before + 8)
		and not rest_copy.rest("rest_qi"), "Rest healing must cap and can only happen once")
	var qi_before: int = flow.run.battle.qi
	await click_button("rest_qi")
	check(flow.run.phase == "battle" and flow.run.battle.qi == mini(4, qi_before + 1), "Rest did not move to the boss")
	await play_commands([[KEY_1, 24], [KEY_4], [KEY_6]])
	check(flow.run.battle.leaves == 0, "Could not use the carried leaf in the boss room")
	await launch()
	check(flow.run.battle.leaves == 0 and not flow.current.actions.has("vital_leaf"), "Reload replenished a consumed leaf")
	await play_commands([[KEY_3], [KEY_1, 16], [KEY_2], [KEY_2], [KEY_3]])
	check(flow.run.phase == "victory" and flow.run.battle.hp == 2, "v3 victory line no longer resolves correctly")


func training_detour() -> void:
	var save_before := FileAccess.get_file_as_string(path)
	var snapshot_before: Dictionary = flow.run.snapshot().duplicate(true)
	var open: Button = flow.current.training_button
	click(open.get_global_rect().get_center())
	await process_frame
	check(flow.current.name == "TrainingSetup", "Could not open training during a run")
	var opponent := flow.find_child("training_opponent", true, false) as OptionButton
	var hero := flow.find_child("training_hero", true, false) as OptionButton
	var grade := flow.find_child("training_grade", true, false) as OptionButton
	var qi := flow.find_child("training_qi", true, false) as SpinBox
	if opponent == null or hero == null or grade == null or qi == null:
		check(false, "Training selection controls are missing")
		return
	opponent.select(3)
	hero.select(1)
	grade.select(3)
	grade.item_selected.emit(3)
	check(qi.max_value == 7, "Training Qi limit did not follow aptitude")
	qi.value = 0
	await capture("godot-luyen-thiet-lap.png")
	await click_button("training_begin")
	check(flow.current.state.wolf_hp == 84 and flow.current.state.qi == 0 and flow.current.state.max_qi == 7
		and flow.current.field.skin == "ao-reu", "Training ignored opponent, skin or essence options")
	await capture("godot-luyen-cuong-dien-lang.png")
	await shoot(KEY_4)
	check(flow.current.state.qi == 1 and flow.current.state.hp == 41, "Training did not use campaign combat laws")
	key(KEY_R)
	check(flow.current.state.hp == 48 and flow.current.state.qi == 0 and flow.current.state.turn == 1,
		"Training retry changed the start conditions")
	open = flow.current.training_button
	click(open.get_global_rect().get_center())
	await process_frame
	var hp := flow.find_child("training_hp", true, false) as SpinBox
	var jade := flow.find_child("training_jade", true, false) as CheckBox
	var leaf := flow.find_child("training_leaf", true, false) as CheckBox
	check(hp != null and jade != null and leaf != null, "Training loadout is missing")
	if hp != null and jade != null and leaf != null:
		hp.value = 28
		jade.button_pressed = true
		leaf.button_pressed = true
		(flow.find_child("training_qi", true, false) as SpinBox).value = 3
		await click_button("training_begin")
		flow.current.inspect_action("vital_leaf")
		check("Hồi 12" in flow.current.hint_label.text and "23 sát thương" in flow.current.hint_label.text,
			"Leaf tooltip must show healing and the expected counter")
		await capture("godot-luyen-hai-co.png")
		await shoot(KEY_6)
		check(flow.current.state.hp == 17 and flow.current.state.leaves == 0 and flow.current.actions.vital_leaf.disabled,
			"Training key did not consume the leaf exactly once")
		await shoot(KEY_5)
		check(flow.current.state.jade_turns == 1 and flow.current.state.qi == 2, "Recovery did not allow an unbroken ward")
		key(KEY_R)
		check(flow.current.state.hp == 28 and flow.current.state.leaves == 1 and flow.current.state.jade_turns == 0,
			"Training retry did not refill loadout")
		open = flow.current.training_button
		click(open.get_global_rect().get_center())
		await process_frame
	await click_button("training_back")
	check(flow.run.snapshot() == snapshot_before and FileAccess.get_file_as_string(path) == save_before
		and flow.current.state == flow.run.battle, "Training modified the campaign or did not restore its battle")


func play_route(id: String, second_room: Array, boss: Array) -> void:
	var elite := id == "elite"
	flow.run = Run.new(Awakening.profile_for("huyen-bao", 12), 5, 2)
	flow.show_run()
	await play_commands([[KEY_1, 10], [KEY_3], [KEY_3]])
	check(flow.run.phase == "route" and flow.run.floor == 0, "First victory must open the fork")
	await launch()
	check(flow.run != null and flow.run.phase == "route" and flow.run.route.is_empty(), "Route menu did not survive reload")
	if elite:
		await capture("godot-nga-re.png")
	await click_button(id)
	check(flow.run.phase == "reward" and flow.run.route == id, "Route selection did not open the first reward")
	await launch()
	check(flow.run.phase == "reward" and flow.run.route == id, "Selected route was lost after reload")
	var refine: Label = flow.find_child("refine_delta", true, false)
	check(refine != null and refine.text == "Sát thương 26 → 33", "Refine preview is wrong")
	var stone: Label = flow.find_child("stone_delta", true, false)
	check(stone != null and stone.text == "Chân nguyên 0/4 → 3/4", "First stone preview is wrong")
	if elite:
		await capture("godot-thuong-man-dau.png")
	await click_button("refine")
	check(flow.run.floor == 1 and flow.run.battle.qi == 0 and flow.run.battle.moon_damage == 33
		and flow.run.battle.wolf_hp == (62 if elite else 56), "Chosen route or first reward did not reach room two")
	if not elite:
		await capture("godot-khe-da-an-toan.png")
	else:
		await training_detour()
	await play_commands(second_room)
	check(flow.run.phase == "reward" and flow.run.floor == 1, "Second victory did not open a reward")
	check(not flow.run.reward_options().has("refine"), "Refine may only be awarded once")
	check(flow.run.reward_options().has("expand") == elite, "Expansion is reserved for the elite route")
	var before: int = flow.run.battle.hp
	var qi: int = flow.run.battle.qi
	var expected := mini(4, qi + (4 if elite else 3))
	check(flow.run.reward_preview("medicine").hp == mini(48, before + (22 if elite else 18)), "Healing preview is wrong")
	if elite:
		var duplicate: RefCounted = Run.restore(flow.run.snapshot())
		check(duplicate.reward("expand") and duplicate.battle.qi == qi and duplicate.battle.max_qi == 5,
			"Expanding essence capacity must preserve current essence")
		await capture("godot-thuong-tinh-anh.png")
	await click_button("stone")
	check(flow.run.battle.qi == expected and flow.run.battle.max_qi == 4 and flow.run.battle.hp == before,
		"Partial essence refill or carried health is wrong")
	await play_commands(boss)
	check(flow.run.phase == "victory" and flow.run.reward_history() == PackedStringArray(["Luyện Nguyệt Quang", "Nguyên thạch"]),
		"New route did not end with the two rewards")
	if elite:
		await capture("godot-ket-qua-tuyen.png")


func exercise() -> void:
	var data := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(data)
	path = data.path_join("run-flow-%d.json" % Time.get_ticks_usec())
	check_gu_and_tactics()
	check_third_save()
	for row in [[12, 24, 4], [20, 40, 5], [30, 60, 6], [40, 80, 7], [49, 97, 7]]:
		var profile := Awakening.profile_for("huyen-bao", row[0])
		check(profile.sea_pct == row[1] and profile.max_qi == row[2], "Incorrect aptitude boundary")
	var rite := Awakening.new(12)
	var ford := rite.path_to(Vector2i(8, 4))
	for point in ford:
		check(rite.step(point), "Khai Khiếu path rejected an open cell")
	check(rite.gathered == [Vector2i(8, 4)] and rite.depth == 2, "Hope Gu must be collected once")

	await launch()
	check(flow.find_child("skip_ceremony", true, false) == null, "First run exposed Skip")
	await click_button("huyen_bao")
	if flow.current.name != "Ceremony":
		check(false, "Hero selection did not open Khai Khiếu")
		quit(1)
		return
	key(KEY_D)
	await wait_until(func(): return flow.current.state.depth >= 8, "Did not reach the orchid garden")
	await capture("godot-hang-nguyet-lan.png")
	await wait_until(func(): return flow.current.result_confirm != null, "Khai Khiếu never completed")
	key(KEY_D, false)
	var confirm: Button = flow.current.result_confirm
	await create_timer(.9).timeout
	await capture("godot-khai-khieu.png")
	click(confirm.get_global_rect().get_center())
	await process_frame
	check(flow.run != null and flow.run.phase == "battle" and flow.run.battle.qi == 4, "Khai Khiếu did not initialize combat")
	await capture("godot-rung-thanh-mao.png")
	for index in range(24):
		if flow.run.phase == "death":
			break
		await shoot(KEY_4)
	check(flow.run.phase == "death" and flow.run.battle.hp == 0, "Expected defeat did not occur")
	await launch()
	check(flow.run != null and flow.run.phase == "death", "Defeat did not survive restart")
	var fallen: Dictionary = flow.run.snapshot()
	await click_button("rebirth")
	await capture("godot-hoi-sinh.png")
	await click_button("ao_reu")
	check(flow.current.name == "Ceremony" and flow.current.hero_id == "ao-reu", "Rebirth did not allow a new ceremony")
	await wait_until(func(): return flow.current.state != null, "New ceremony did not load")
	flow.current.back_requested.emit()
	await process_frame
	await click_button("skip_ceremony")
	check(flow.run.profile.hero == "huyen-bao" and flow.run.profile.depth == 12 and flow.run.battle.hp == 48
		and flow.run.battle.qi == 4 and flow.run.journal.is_empty(), "Skipping did not preserve only the profile")
	check(flow.find_child("skip_ceremony", true, false) == null, "Skipping stayed available during combat")

	flow.run = Run.restore(fallen)
	flow.show_run()
	flow.ceremony_limit = 15
	await click_button("rebirth")
	await click_button("ao_reu")
	click(Vector2(34 + 21 * 51 + 25, 144 + 4 * 51 + 25))
	await wait_until(func(): return flow.current.result_confirm != null, "Could not finish the rebirth ceremony with the mouse")
	var renewed: Button = flow.current.result_confirm
	if renewed != null:
		click(renewed.get_global_rect().get_center())
	await process_frame
	check(flow.run.profile.hero == "ao-reu" and flow.run.profile.depth == 15 and flow.run.floor == 0
		and flow.run.journal.is_empty(), "Repeating Khai Khiếu did not use the new profile")

	flow.run = Run.new(Awakening.profile_for("huyen-bao", 12), 5, 1)
	flow.show_run()
	for code in [KEY_3, KEY_3]:
		await shoot(code)
	check(flow.run.phase == "reward", "First victory did not open rewards")
	await capture("godot-chien-loi-pham.png")
	await launch()
	check(flow.run.version == 1 and flow.run.phase == "reward" and flow.run.floor == 0, "Legacy reward did not survive restart")
	await click_button("stone")
	check(flow.run.floor == 1 and flow.run.battle.qi == 5 and flow.run.battle.hp < 48, "Reward or retained HP mismatch")
	await capture("godot-khe-da.png")
	for code in [KEY_3, KEY_3, KEY_4, KEY_3]:
		await shoot(code)
	await click_button("stone")
	check(flow.run.floor == 2 and flow.run.battle.wolf_hp == 84, "Boss encounter did not open")
	await capture("godot-cuong-dien-lang.png")
	for action in [[KEY_4], [KEY_3], [KEY_1, 1], [KEY_3], [KEY_1, 8], [KEY_3], [KEY_2]]:
		await shoot(action[0], action[1] if action.size() == 2 else -1)
	check(flow.run.phase == "victory", "Three-room encounter did not reach victory")
	await capture("godot-vuot-thanh-mao.png")
	await launch()
	check(flow.run.phase == "victory", "Victory did not survive restart")
	await click_button("new_run")
	check(flow.find_child("skip_ceremony", true, false) == null, "Victory exposed Skip")
	await play_route("ravine", [[KEY_4], [KEY_1, 19], [KEY_2], [KEY_3], [KEY_2]],
		[[KEY_1, 10], [KEY_3], [KEY_1, 1], [KEY_3], [KEY_1, 8], [KEY_4], [KEY_1, 24], [KEY_4], [KEY_3]])
	await play_route("elite", [[KEY_4], [KEY_4], [KEY_4], [KEY_3], [KEY_4], [KEY_3]],
		[[KEY_1, 10], [KEY_3], [KEY_4], [KEY_3], [KEY_1, 1], [KEY_4], [KEY_3]])
	await play_rest_and_leaf()
	DirAccess.remove_absolute(path)
	if not failed:
		print("Godot run passed: ceremony, rebirth, v1/v2 restore, v3 Gu forecasts, training, rest/leaf reload and victory")
	quit(1 if failed else 0)
