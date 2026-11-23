extends SceneTree

const Scene = preload("res://run_flow.tscn")
const Run = preload("res://run_state.gd")
const Rules = preload("res://battle_rules.gd")
const Gu = preload("res://gu_catalog.gd")
const Goods = preload("res://waypoint_goods.gd")
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


func select_kit(recipe: String, starter: String) -> void:
	for choice in [["workshop_recipe", Gu.RECIPES.find(recipe)], ["workshop_starter", Gu.STARTERS.find(starter)]]:
		var input := flow.find_child(choice[0], true, false) as OptionButton
		check(input != null and choice[1] in range(input.item_count), "Missing workshop selection for " + str(choice[0]))
		if input == null or choice[1] not in range(input.item_count):
			return
		input.select(choice[1])
		input.item_selected.emit(choice[1])
	await click_button("equip_confirm")


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
	var current_run := Run.new(Awakening.profile_for("huyen-bao", 40), 5, 3)
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


func check_rank_two_gu() -> void:
	var lunar := Rules.new({"refined_gu": "moon_edge", "wolf_hp": 110, "qi": 7, "max_qi": 7})
	var sneak := Rules.new({"refined_gu": "moon_edge", "moon_equipped": false, "jade_skin": true, "qi": 3})
	check(lunar.build_family == "lunar" and sneak.build_family.is_empty(), "The equipped pair determines the set")
	check(sneak.take_turn("moon").has("error") and sneak.turn == 1, "Unequipped Cổ remained usable")
	check(sneak.preview_action("moon_edge").dealt == 30, "Mixed set received the mark bonus")
	check(lunar.preview_action("moon").moon_mark and not lunar.moon_mark, "Forecast must not place a mark")
	lunar.take_turn("moon")
	check(lunar.moon_mark and lunar.wolf_hp == 84, "Moon Quang did not apply Nguyệt Ấn")
	var forecast := lunar.preview_action("moon_edge")
	check(forecast.set_trigger and forecast.dealt == 42 and lunar.moon_mark, "Refined shot forecast missed Nguyệt Ấn")
	check(lunar.take_turn("moon_edge").wolf_damage == 42 and not lunar.moon_mark, "The boosted shot did not consume its mark")
	var armor := Rules.new({"refined_gu": "white_jade", "moon_equipped": false, "jade_skin": true})
	armor.intent = {"kind": "recover", "cells": [], "damage": 0}
	armor.take_turn("jade_skin")
	check(armor.ward_strength == Rules.JADE_ABSORB and armor.jade_turns == 1, "Ngọc Bì did not persist into the next response")
	armor.intent = {"kind": "shot", "name": "Hồ quang", "cells": [armor.hero], "damage": 16}
	forecast = armor.preview_action("white_jade")
	check(forecast.set_trigger and forecast.absorbed == 12 and forecast.receives == 4 and armor.ward_strength == 5,
		"Bạch Ngọc forecast did not upgrade the existing ward")
	var exchange := armor.take_turn("white_jade")
	check(exchange.reaction == "shot" and armor.ward_strength == 0 and armor.hp == 44 and armor.qi == 1,
		"Incoming shot must consume the stronger ward")
	armor.wolf = armor.hero + 1
	armor.intent = {"kind": "recover", "cells": [], "damage": 0}
	check(armor.counter_ready and armor.preview_action("strike").dealt == 22, "A successful armor block did not prime the counter")
	check(armor.take_turn("strike").wolf_damage == 22 and not armor.counter_ready, "The next unarmed strike did not spend its counter")
	var mixed := Rules.new({"refined_gu": "white_jade"})
	check(mixed.preview_action("white_jade").absorbed == 8 and not mixed.preview_action("white_jade").counter_ready,
		"Bạch Ngọc on a mixed set should only retain its base strength")
	var storm := Rules.new({"tactic": "storm", "wolf_cell": 22, "rocks": [20], "refined_gu": "moon_edge"})
	check(storm.intent.kind == "advance" and storm.take_turn("moon_edge").has("error") and storm.qi == 4,
		"Cover must block both a long-range Gu and the enemy shot")


func play_rank_two() -> void:
	check(flow.run.version == 3 and flow.run.can_begin_chapter(), "v3 victory did not expose rank two")
	await click_button("chapter_two")
	check(flow.run.version == Run.CURRENT_VERSION and flow.run.phase == "refinement", "Opening the workshop did not upgrade/save the run")
	await launch()
	check(flow.run.phase == "refinement" and not flow.run.equip_build("wrong", "moon"), "Reload lost the workshop or accepted an unknown Gu")
	await capture("godot-rank2-bo-co.png")
	var workshop: Dictionary = flow.run.snapshot().duplicate(true)
	for recipe in Gu.RECIPES:
		for starter in Gu.STARTERS:
			var copy: RefCounted = Run.restore(flow.run.snapshot())
			check(copy.equip_build(recipe, starter) and copy.battle.build_family == Gu.build_family(recipe, starter)
				and copy.battle.moon_equipped == (starter == "moon") and copy.battle.jade_skin == (starter == "jade_skin")
				and not copy.equip_build(recipe, starter), "Wrong equipment or repeated workshop transaction for " + recipe + "/" + starter)
	await select_kit("moon_edge", "moon")
	check(flow.current.state.refined_gu == "moon_edge" and flow.current.actions.has("moon_edge") and flow.current.state.qi == 3,
		"Chapter II did not equip Nguyệt Mang or restore the displayed Qi")
	await capture("godot-rank2-san-dau.png")
	await shoot(KEY_7)
	check(flow.run.battle.wolf_hp == 42 and flow.run.battle.hp == 4 and flow.run.battle.intent.kind == "recover",
		"Rank II hotkey, ranged hit or recovery timing is incorrect")
	await launch()
	check(flow.run.battle.build_family == "lunar" and flow.run.battle.wolf_hp == 42 and flow.run.battle.intent.kind == "recover",
		"Mid-fight reload altered the rank II battle")
	# Staying in front of the next shot at low HP should expose the normal rebirth flow.
	await shoot(KEY_4)
	await shoot(KEY_4)
	check(flow.run.phase == "death" and flow.run.floor == Run.FLOORS.size(), "Death in rank two did not end the run")
	await click_button("rebirth")
	await click_button("skip_ceremony")
	check(flow.run.battle.refined_gu.is_empty() and flow.run.battle.moon_equipped and not flow.run.battle.jade_skin
		and flow.run.floor == 0, "Rebirth kept the rank II equipment")
	flow.run = Run.restore(workshop)
	flow.show_run()
	await select_kit("moon_edge", "moon")
	await play_commands([[KEY_1, 18], [KEY_4], [KEY_3], [KEY_4]])
	check(flow.run.battle.moon_mark and flow.run.battle.wolf_hp == 39 and flow.run.battle.qi == 3,
		"The ranged duel did not expose the intended marked shot")
	await shoot(KEY_7)
	check(flow.run.phase == "complete" and flow.find_child("new_run", true, false) != null, "The successful combo did not end Chapter II")
	await launch()
	check(flow.run.phase == "complete" and flow.run.battle.hp == 4, "Chapter II victory did not replay")
	var current_save: Dictionary = flow.run.snapshot().duplicate(true)
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = 4
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.can_cross_ford() and not flow.run.battle.revised_ward, "v4 victory did not retain legacy rules")
	if flow.run == null:
		return
	flow.show_run()
	await click_button("cross_ford")
	check(flow.run.phase == "ford_workshop" and flow.run.snapshot().chapter_rules == 4, "Old save did not migrate on crossing")
	await launch()
	check(flow.run.phase == "ford_workshop" and flow.run.version == 4, "Reload lost v4 replay rules or the crossing")
	await capture("godot-suoisam-chon-bo.png")
	await select_kit("four_flavors", "brew")
	check(flow.run.floor == 4 and flow.current.actions.has("brew") and flow.current.actions.has("four_flavors")
		and flow.run.battle.brew_left == 2, "Crossing failed to equip the new family")
	await capture("godot-suoisam.png")
	await shoot(KEY_3)
	check(flow.run.battle.qi == 4 and flow.run.battle.brew_ready and flow.run.battle.hp == 24,
		"Tửu Trùng key failed or an electrified ford hit a dry cell")
	await shoot(KEY_7)
	check(flow.run.battle.strong_strikes == 2 and flow.run.battle.qi == 2, "Tứ Vị did not consume the prep")
	await launch()
	check(flow.run.battle.strong_strikes == 2 and flow.run.battle.brew_left == 1 and flow.run.battle.intent.kind == "shot",
		"Reload reverted the ford, Tửu charges or enemy forecast")
	await play_commands([[KEY_1, 19], [KEY_1, 21], [KEY_2], [KEY_2]])
	check(flow.run.battle.strong_strikes == 0 and flow.run.battle.wolf_hp == 24 and flow.run.battle.hp == 6,
		"Both boosted strikes and the electrified water must resolve once")
	await play_commands([[KEY_1, 14], [KEY_2], [KEY_2]])
	check(flow.run.phase == "complete" and flow.run.floor == 4 and flow.find_child("cross_ford", true, false) == null,
		"Finishing the ford did not close Chapter II")
	await launch()
	check(flow.run.phase == "complete" and flow.run.battle.hp == 6, "The migrated final victory did not replay")
	await click_button("enter_pass")
	check(flow.run.phase == "ambush_workshop" and flow.run.snapshot().version == 6 and flow.run.snapshot().chapter_rules == 4,
		"Continuing from the ford did not preserve the earliest rule version")
	await launch()
	check(flow.run.phase == "ambush_workshop" and flow.run.workshop_size() == 4, "Hẻm Đá did not reopen with four families")
	await capture("godot-hem-da-chon-bo.png")
	await select_kit("scale_veil", "stone_veil")
	check(flow.run.floor == 5 and flow.current.actions.has("stone_veil") and flow.current.actions.has("scale_veil"),
		"Could not equip the new pair in the new encounter")
	await capture("godot-hem-da-phuc-kich.png")
	await shoot(KEY_7)
	check(flow.run.battle.hp == 28 and flow.run.battle.intent.kind == "recover", "Ẩn Lân did not evade the first ambush")
	await shoot(KEY_3)
	await shoot(KEY_4)
	await shoot(KEY_7)
	check(flow.run.battle.movement_range() == 4 and flow.run.battle.veil_turns == 1, "Paired veil did not prepare a four-step move")
	await launch()
	check(flow.run.battle.movement_range() == 4 and flow.run.battle.veil_turns == 1,
		"Saved Hẻm Đá state lost the pending movement or concealment")
	await shoot(KEY_1, 21)
	check(flow.run.battle.hero == 21 and flow.run.battle.movement_range() == 2 and flow.run.battle.hp == 28,
		"The four-step move did not consume the bonus or avoid the old target cells")
	await play_waypoints(current_save)


func play_waypoints(ridge_save: Dictionary) -> void:
	flow.run = Run.restore(ridge_save)
	flow.show_run()
	check(flow.run.stones == Goods.RIDGE_STONES, "Winning the ridge must pay once")
	await click_button("cross_ford")
	check(flow.run.phase == "waypoint" and flow.find_child("salvage", true, false) != null, "The ford's detour screen is missing")
	await capture("godot-v7-diem-dung-suoi.png")
	var base: Dictionary = flow.run.workshop_vitals()
	var danger: Dictionary = flow.run.waypoint_preview("salvage")
	check(danger.hp == base.hp - Goods.CACHE_COST and danger.stones == Goods.RIDGE_STONES + Goods.CACHE_STONES,
		"Salvage preview did not expose its trade-off")
	var other: RefCounted = Run.restore(flow.run.snapshot())
	check(other.choose_waypoint("salvage") and other.workshop_vitals().hp == danger.hp and other.stones == danger.stones
		and not other.choose_waypoint("salvage"), "Salvage may grant its price and reward only once")
	other = Run.restore(flow.run.snapshot())
	check(other.choose_waypoint("camp") and other.workshop_vitals().hp == mini(Rules.MAX_HP, base.hp + Goods.CAMP_HEAL),
		"Camp healing must be capped and show up in the workshop")
	await click_button("merchant")
	check(flow.run.phase == "shop" and flow.run.shop_relic() == "reed_boots", "The shop offer did not follow the run seed")
	var cheap: RefCounted = Run.restore(flow.run.snapshot())
	check(cheap.buy("buy_leaf") and not cheap.buy("buy_leaf") and not cheap.buy("buy_relic")
		and cheap.workshop_vitals().leaves == base.leaves + 1, "Shop allowed a repeat sale or purchase without enough stones")
	await capture("godot-v7-quay-doi-do.png")
	await click_button("buy_relic")
	await launch()
	check(flow.run.phase == "shop" and flow.run.relic == "reed_boots" and flow.run.stones == 0
		and not flow.run.buy("buy_relic"), "Reload changed the purchased item or wallet")
	await click_button("leave_shop")
	await select_kit("four_flavors", "brew")
	check(flow.run.battle.movement_range() == 3 and flow.run.battle.relic_ready, "Boots did not enter the ford battle")
	await play_commands([[KEY_3], [KEY_7], [KEY_1, 19]])
	check(flow.run.battle.movement_range() == 2 and not flow.run.battle.relic_ready, "Boots must spend their charge on a committed move")
	await play_commands([[KEY_1, 21], [KEY_2], [KEY_2], [KEY_1, 14], [KEY_2], [KEY_2]])
	check(flow.run.can_enter_pass() and flow.run.stones == Goods.FORD_STONES, "Victory did not carry the wallet to the second stop")
	await click_button("enter_pass")
	check(flow.run.phase == "waypoint" and flow.find_child("spring", true, false) != null, "The pass's event is missing")
	var swap: RefCounted = Run.restore(flow.run.snapshot())
	check(swap.choose_waypoint("merchant") and swap.shop_relic() == "jade_token"
		and swap.shop_price("buy_relic") == Goods.RELIC_TRADE_PRICE and swap.buy("buy_relic")
		and swap.relic == "jade_token" and swap.stones == 0, "Shop did not swap the carried relic at the advertised price")
	var spring: Dictionary = flow.run.waypoint_preview("spring")
	await click_button("spring")
	await launch()
	check(flow.run.phase == "ambush_workshop" and flow.run.workshop_vitals().leaves == spring.leaves
		and flow.run.workshop_vitals().qi == spring.qi and flow.run.relic == "reed_boots",
		"Reload changed the spring trade or the carried relic")
	await select_kit("scale_veil", "stone_veil")
	check(flow.run.battle.leaves == spring.leaves and flow.run.battle.qi == spring.qi and flow.run.battle.relic_ready,
		"Supplies must be applied once and the relic must reset for the new fight")


func check_relic_rules() -> void:
	var boot := Rules.new({"relic": "reed_boots"})
	check(boot.movement_range() == 3 and boot.preview_action("move", 20).steps == 3 and boot.relic_ready,
		"Forecast consumed the boots or lost the third step")
	check(boot.take_turn("move", 20).action == "move" and not boot.relic_ready and boot.movement_range() == 2,
		"Boots did not expire after the actual move")
	var token := Rules.new({"relic": "jade_token"})
	var guard := token.preview_action("guard")
	check(guard.relic_block == 3 and guard.receives == 1 and token.relic_ready,
		"Ngọc bài must reduce damage after guard without mutating preview")
	token.take_turn("guard")
	check(token.hp == 47 and not token.relic_ready, "The token did not absorb once")
	var jade := Rules.new({"relic": "jade_token", "jade_skin": true})
	jade.intent = {"kind": "strike", "name": "Cắn xé", "cells": [jade.hero], "damage": 4}
	check(jade.preview_action("jade_skin").relic_block == 0, "A fully blocked hit cannot spend the token")
	jade.take_turn("jade_skin")
	check(jade.relic_ready, "A fully blocked hit consumed the token")
	check(Rules.new({"relic": "essence_pin", "qi": 2}).qi == 3
		and Rules.new({"relic": "essence_pin", "qi": 4}).qi == 4, "Trâm tụ nguyên must grant capped starting Qi")
	var fang := Rules.new({"relic": "elite_fang"})
	check(fang.preview_action("moon").relic_damage == Goods.FANG_BONUS and fang.relic_ready,
		"Fang preview must show the bonus without consuming it")
	fang.take_turn("guard")
	check(fang.relic_ready and fang.take_turn("moon").wolf_damage == fang.moon_damage + Goods.FANG_BONUS
		and not fang.relic_ready and fang.preview_action("moon").relic_damage == 0, "Fang must boost only the first damaging attack")
	var finisher := Rules.new({"relic": "elite_fang", "wolf_hp": Rules.STRIKE_DAMAGE + 1, "wolf_cell": 18})
	var blow := finisher.take_turn("strike")
	check(blow.wolf_damage == Rules.STRIKE_DAMAGE + 1 and blow.hero_damage == 0 and finisher.result == Rules.VICTORY,
		"Fang bonus must cap at the target HP and prevent the defeated enemy's reply")


func play_elite_detour() -> void:
	var checkpoint := {"version": Run.CURRENT_VERSION, "hero": "huyen-bao", "depth": 12, "seed": 0, "journal": [
		["moon", -1], ["moon", -1], ["elite"], ["refine"], ["move", 10], ["guard", -1], ["guard", -1],
		["moon", -1], ["strike", -1], ["strike", -1], ["moon", -1], ["stone"], ["rest_qi"],
		["move", 19], ["moon", -1], ["move", 12], ["moon", -1], ["move", 20], ["strike", -1], ["strike", -1],
		["chapter_two"], ["equip", "moon_edge", "moon"], ["move", 18], ["moon", -1], ["guard", -1], ["moon_edge", -1],
		["cross_ford"], ["merchant"], ["leave_shop"], ["equip", "moon_edge", "moon"],
		["moon_edge", -1], ["move", 19], ["move", 21], ["strike", -1], ["strike", -1], ["moon", -1], ["enter_pass"]]}
	var old := checkpoint.duplicate(true)
	old.version = 7
	var legacy: RefCounted = Run.restore(old)
	check(legacy != null and legacy.waypoint_options().size() == 3 and not legacy.choose_waypoint("elite_detour"),
		"v7 saves must retain the old waypoint choices")
	flow.run = Run.restore(checkpoint)
	flow.show_run()
	check(flow.run.phase == "waypoint" and not flow.run.claim_elite_reward("elite_fang"), "Reward must be locked before the elite fight")
	await capture("godot-v8-nhanh-tinh-anh.png")
	var stones: int = flow.run.stones
	await click_button("elite_detour")
	await launch()
	check(flow.run.phase == "elite_workshop", "Reload lost the chosen elite detour")
	await select_kit("moon_edge", "moon")
	check(flow.current.room_title == Run.ELITE_DEN.name and flow.run.battle.tactic == "den",
		"The optional room must have its own stage and opponent")
	await capture("godot-v8-o-dien-lang.png")
	var doomed: RefCounted = Run.restore(flow.run.snapshot())
	for i in range(20):
		if doomed.phase == "battle":
			doomed.perform("guard")
	check(doomed.phase == "death" and not doomed.claim_elite_reward("elite_fang")
		and Run.restore(doomed.snapshot()).phase == "death", "Dying to the elite must end the run without a reward")
	await shoot(KEY_4)
	check(flow.run.battle.intent.kind == "recover", "Pounce must have a recovery turn")
	var before_recovery: int = flow.run.battle.hp
	await shoot(KEY_3)
	check(flow.run.battle.hp == before_recovery, "The recovery turn must allow a safe counterattack")
	await launch()
	check(flow.run.elite_room and flow.run.battle.intent.get("pattern") == "row", "Reload lost the telegraphed charge")
	await play_commands([[KEY_4], [KEY_3], [KEY_4], [KEY_3]])
	check(flow.run.phase == "elite_reward" and flow.run.stones == stones, "Elite victory must grant only its own reward")
	await launch()
	await capture("godot-v8-chien-loi-pham.png")
	var prize: Dictionary = flow.run.elite_reward_preview("elite_fang")
	var remedy: RefCounted = Run.restore(flow.run.snapshot())
	check(remedy.claim_elite_reward("elite_remedy") and remedy.workshop_vitals().hp == mini(Rules.MAX_HP, prize.hp + Goods.REMEDY_HEAL)
		and remedy.workshop_vitals().leaves == prize.leaves + 1 and remedy.relic.is_empty(), "Remedy must grant HP and one leaf instead of a relic")
	await click_button("elite_fang")
	await launch()
	check(flow.run.phase == "ambush_workshop" and not flow.run.elite_room and flow.run.elite_award == "elite_fang"
		and not flow.run.claim_elite_reward("elite_remedy"), "Elite reward must survive reload and be claimed just once")
	await select_kit("moon_edge", "moon")
	check(flow.run.floor == Run.AMBUSH_FLOOR and flow.run.battle.hp == prize.hp and flow.run.battle.qi == prize.qi
		and flow.run.battle.relic == "elite_fang" and flow.run.battle.relic_ready, "The elite prize must carry into the main route")
	await play_thunder_boss(checkpoint)


func play_thunder_boss(checkpoint: Dictionary) -> void:
	flow.run = Run.restore(checkpoint)
	flow.run.choose_waypoint("camp")
	flow.run.equip_build("moon_edge", "moon")
	for command in [["move", 19], ["moon", -1], ["move", 21], ["strike", -1], ["moon", -1], ["strike", -1]]:
		check(not flow.run.perform(command[0], command[1]).has("error"), "Invalid Hẻm Đá fixture")
	check(flow.run.can_enter_boss() and not flow.boss_seal, "Clearing Hẻm Đá must unlock the gate, with the seal still locked")
	var old_save: Dictionary = flow.run.snapshot().duplicate(true)
	old_save.version = 8
	var old: RefCounted = Run.restore(old_save)
	check(old != null and old.phase == "complete" and old.snapshot().version == 8, "v8 clear must replay without an automatic upgrade")
	check(old.enter_boss() and old.snapshot().version == Run.BOSS_VERSION
		and Run.restore(old.snapshot()).phase == "boss_workshop", "A v8 clear must be able to continue into the new boss")
	flow.show_run()
	flow.open_training(flow.show_run)
	var opponent := flow.find_child("training_opponent", true, false) as OptionButton
	check(opponent != null and opponent.item_count == flow.TRAINING_STAGES.size() - 1, "Boss training must start locked")
	await click_button("training_back")
	await click_button("enter_boss")
	await launch()
	check(flow.run.phase == "boss_workshop" and not flow.run.enter_boss(), "Boss preparation must survive a reload")
	var departure: Dictionary = flow.run.workshop_vitals()
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	check(flow.run.floor == Run.BOSS_FLOOR and flow.current.room_title == Run.THUNDER_GATE.name and battle.hp == departure.hp
		and battle.qi == departure.qi and battle.leaves == departure.leaves, "Boss arena did not apply preparation")
	check(battle.intent.kind == "thunder" and not battle.intent.cross and battle.preview_action("move", 10).receives == 0,
		"The first sweep must be telegraphed and avoidable")
	await capture("godot-v9-loi-quet.png")
	await shoot(KEY_1, 10)
	check(battle.intent.kind == "recover" and battle.preview_action("moon").exposed_damage == Rules.THUNDER_OPEN_BONUS
		and battle.hp == departure.hp and battle.wolf_hp == battle.wolf_max, "The open armor preview mutated combat or lost the bonus")
	await play_commands([[KEY_3], [KEY_4], [KEY_3]])
	await launch()
	battle = flow.run.battle
	var center := Rules.grid(battle.hero)
	var cross_cells: Array[int] = []
	for cell in range(Rules.COLUMNS * Rules.ROWS):
		var point := Rules.grid(cell)
		if cell not in battle.rocks and (point.x == center.x or point.y == center.y):
			cross_cells.append(cell)
	check(battle.intent.cross and battle.intent.cells == cross_cells and flow.current.field.threatened == cross_cells,
		"Below half HP the forecast and painted cross must match, including after reload")
	await capture("godot-v9-loi-chu-thap.png")
	var doomed: RefCounted = Run.restore(flow.run.snapshot())
	for i in range(20):
		if doomed.phase == "battle":
			doomed.perform("guard")
	check(doomed.phase == "death" and Run.restore(doomed.snapshot()).phase == "death" and not flow.boss_seal,
		"Death against the boss must replay as defeat and never award the seal")
	await play_commands([[KEY_4], [KEY_3]])
	check(flow.run.phase == "chapter_cleared" and flow.boss_seal, "Boss victory must immediately award the seal")
	await launch()
	check(flow.run.phase == "chapter_cleared" and flow.boss_seal, "Victory or seal disappeared after reload")
	await capture("godot-v9-an-tran-loi.png")
	await play_poison_marsh()
	await play_wind_pass()
	await play_seal_altar()
	await click_button("new_run")
	flow.start_new_run(Awakening.profile_for("ao-reu", 12))
	await launch()
	check(flow.run.floor == 0 and flow.boss_seal and flow.run.battle.tactic.is_empty(), "The seal must survive a new run")
	var campaign := FileAccess.get_file_as_string(path)
	flow.open_training(flow.show_run)
	opponent = flow.find_child("training_opponent", true, false) as OptionButton
	check(opponent != null and opponent.item_count == flow.TRAINING_STAGES.size(), "The seal must unlock the boss in training")
	opponent.select(opponent.item_count - 1)
	await click_button("training_begin")
	check(flow.current.state.tactic == "thunder_boss" and flow.current.state.wolf_hp == Run.THUNDER_GATE.hp
		and FileAccess.get_file_as_string(path) == campaign, "Practice must use boss rules and leave the campaign untouched")


func play_poison_marsh() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = 9
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.phase == "chapter_cleared", "v9 must still replay to the original boss result")
	flow.show_run()
	check(not flow.run.claim_marsh_reward("purifying_dew"), "A chapter clear must not grant the marsh reward")
	await click_button("enter_marsh")
	await launch()
	check(flow.run.phase == "marsh_workshop" and flow.run.version == Run.MARSH_VERSION and flow.boss_seal,
		"Continuing a v9 save must upgrade only after entry and keep the seal")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	var first_cells: Array = battle.intent.cells
	var escape := battle.preview_action("move", 16)
	var waiting := battle.preview_action("guard")
	check(battle.tactic == "marsh" and battle.intent.kind == "poison" and first_cells == flow.current.field.threatened
		and escape.receives == 0 and waiting.qi_drained == 1 and battle.qi == battle.max_qi, "Poison forecast must match terrain and preview")
	var other: RefCounted = Run.restore(flow.run.snapshot())
	other.battle.jade_turns = 1
	other.battle.ward_strength = Rules.JADE_ABSORB + 1
	var blocked: Dictionary = other.battle.preview_action("guard")
	check(blocked.receives == 0 and blocked.qi_drained == 0, "A fully blocked poison hit must not siphon Qi")
	other.battle.jade_turns = 0
	var hit: Dictionary = other.perform("guard")
	check(other.battle.qi == waiting.qi and other.battle.hp == battle.hp - waiting.receives and not hit.has("error"),
		"Committing a poison hit must match its Qi and HP preview")
	check(other.battle.intent.name == "Táp độc" and other.battle.intent.cells == [other.battle.hero]
		and other.battle.aim_can_be_lost(), "The follow-up must aim at one square and allow concealment")
	var close: RefCounted = Run.restore(flow.run.snapshot())
	close.perform("move", 19)
	close.perform("move", 20)
	check(close.battle.intent.kind == "recover" and close.battle.preview_action("strike").exposed_damage == Rules.MARSH_JAW_BONUS
		and close.battle.preview_action("moon").exposed_damage == 0, "The missed lunge must open a melee-only counterattack")
	for i in range(36):
		if other.phase == "battle":
			other.perform("guard")
	check(other.phase == "death" and not other.claim_marsh_reward("purifying_dew")
		and Run.restore(other.snapshot()).phase == "death", "Defeat in the marsh must not grant a reward")
	await capture("godot-v10-dam-re-doc.png")
	await play_commands([[KEY_1, 16], [KEY_1, 18], [KEY_3]])
	await launch()
	battle = flow.run.battle
	check(battle.intent.kind == "poison" and not battle.intent.cells.is_empty()
		and first_cells.all(func(cell): return cell not in battle.intent.cells), "Reload must preserve the alternate poison pool")
	await play_commands([[KEY_3], [KEY_4], [KEY_2], [KEY_3]])
	check(flow.run.phase == "marsh_reward", "Winning the marsh must award a choice")
	await launch()
	await capture("godot-v10-phan-thuong-tam-chuyen.png")
	var tonic: RefCounted = Run.restore(flow.run.snapshot())
	var old_qi: int = tonic.battle.max_qi
	var old_leaves: int = tonic.battle.leaves
	var old_hp: int = tonic.battle.hp
	check(tonic.claim_marsh_reward("marsh_tonic") and tonic.battle.leaves == old_leaves + Run.TONIC_LEAVES
		and tonic.battle.hp == mini(Rules.MAX_HP, old_hp + Run.TONIC_HEAL) and tonic.battle.max_qi == old_qi,
		"Tonic must grant recovery and leaves")
	check(tonic.enter_wind_pass() and tonic.equip_build("moon_edge", "moon") and tonic.battle.max_qi == old_qi
		and tonic.battle.leaves == old_leaves + Run.TONIC_LEAVES and tonic.battle.hp == Rules.MAX_HP,
		"Entering the wind pass must carry the marsh tonic supplies")
	await click_button("purifying_dew")
	await launch()
	check(flow.run.phase == "marsh_cleared" and flow.run.marsh_award == "purifying_dew" and flow.run.battle.max_qi == old_qi + 1
		and flow.run.battle.qi == flow.run.battle.max_qi and not flow.run.claim_marsh_reward("marsh_tonic"),
		"Dew must raise and refill capacity once across reload")


func play_wind_pass() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = Run.MARSH_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.phase == "marsh_cleared" and flow.run.marsh_award == "purifying_dew",
		"A v10 clear must keep its original reward")
	flow.show_run()
	await click_button("enter_wind_pass")
	await launch()
	check(flow.run.phase == "wind_workshop" and flow.run.version == Run.WIND_VERSION
		and not flow.run.enter_wind_pass() and not flow.run.claim_wind_reward("wind_seal"), "The wind pass must open exactly once")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	check(battle.tactic == "wind_pass" and battle.max_qi == flow.run.profile.max_qi + 1 and battle.qi == battle.max_qi,
		"Original dew capacity must reach the new fight")
	check(battle.intent.kind == "wind" and battle.intent.direction == 1
		and battle.intent.cells == flow.current.field.threatened and 26 not in battle.intent.cells
		and battle.preview_action("move", 26).receives == 0 and battle.preview_action("move", 19).receives > 0,
		"Only tiles downwind of a stone must shelter from the first gust")
	await capture("godot-v11-hem-han-phong.png")
	var doomed: RefCounted = Run.restore(flow.run.snapshot())
	for i in range(28):
		if doomed.phase == "battle":
			doomed.perform("guard")
	check(doomed.phase == "death" and not doomed.claim_wind_reward("wind_supplies")
		and Run.restore(doomed.snapshot()).phase == "death", "A lost wind fight must not grant rewards")
	await play_commands([[KEY_3], [KEY_1, 16], [KEY_7]])
	await launch()
	battle = flow.run.battle
	check(battle.intent.kind == "wind" and battle.intent.direction == -1 and 26 in battle.intent.cells
		and flow.current.field.wind_direction == -1, "Reload must preserve reversed wind and reversed shelter")
	await play_commands([[KEY_4], [KEY_4], [KEY_3], [KEY_2]])
	check(flow.run.phase == "wind_reward", "Winning the wind pass must open the reward choice")
	await launch()
	await capture("godot-v11-chien-loi-pham.png")
	var supplies: RefCounted = Run.restore(flow.run.snapshot())
	var departure: Dictionary = supplies.wind_reward_preview("wind_supplies")
	check(supplies.claim_wind_reward("wind_supplies") and supplies.battle.leaves == departure.leaves
		and supplies.battle.qi == departure.qi and Run.restore(supplies.snapshot()).wind_award == "wind_supplies",
		"Wind supplies must survive replay")
	await click_button("wind_seal")
	await launch()
	check(flow.run.phase == "wind_cleared" and flow.run.relic == "wind_seal" and not flow.run.claim_wind_reward("wind_supplies"),
		"The seal must occupy the relic slot and prevent a second reward")
	var kit := {"relic": flow.run.relic}
	var full := Run.battle_for(Run.WIND_PASS, 0, 48, 4, 4, 0, kit, "wind_pass", true)
	full.take_turn("move", 26)
	check(full.relic_ready, "A full essence bar must not spend the wind seal")
	var trial := Run.battle_for(Run.WIND_PASS, 0, 48, 1, 4, 0, kit, "wind_pass", true)
	check(trial.preview_action("move", 19).relic_qi == 0
		and trial.preview_action("move", 26).relic_qi == Goods.WIND_SEAL_QI and trial.relic_ready and trial.qi == 1,
		"Preview must show the wind seal gain only when escaping, without consuming it")
	trial.take_turn("move", 26)
	check(trial.qi == 1 + Goods.WIND_SEAL_QI and not trial.relic_ready, "An actual escape must trigger the wind seal once")


func play_seal_altar() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = Run.WIND_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.phase == "wind_cleared" and flow.run.relic == "wind_seal",
		"The v11 clear must keep its selected relic")
	flow.show_run()
	await click_button("enter_altar")
	await launch()
	check(flow.run.version == Run.ALTAR_VERSION and flow.run.phase == "altar_workshop"
		and not flow.run.enter_altar() and not flow.run.claim_altar_reward("stone_marrow"),
		"Entry must upgrade v11 once and lock the reward")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	var current_qi := battle.qi
	var armored := battle.preview_action("moon")
	var escape := battle.preview_action("move", 19)
	check(battle.tactic == "seal_altar" and battle.intent.kind == "seal_burst" and battle.hero in battle.intent.cells
		and flow.current.field.threatened == battle.intent.cells and 19 in battle.runes and escape.receives == 0
		and escape.seal_turns == Rules.ALTAR_BREAK_TURNS and battle.seal_turns == 0, "Rune and attack previews must match the board")
	check(armored.armor_block == Rules.ALTAR_ARMOR and armored.dealt == battle.moon_damage - Rules.ALTAR_ARMOR
		and escape.relic_qi == mini(Goods.WIND_SEAL_QI, battle.max_qi - current_qi), "Armor and escape should forecast actual damage and Qi")
	var finisher := Rules.new({"tactic": "seal_altar", "wolf_hp": 10})
	check(finisher.take_turn("moon").wolf_damage == 10 and finisher.result == Rules.VICTORY,
		"Armor must apply before capping damage at the enemy's remaining HP")
	await capture("godot-v12-dai-tran-an.png")
	await shoot(KEY_1, 19)
	await launch()
	battle = flow.run.battle
	check(battle.seal_turns == Rules.ALTAR_BREAK_TURNS and battle.qi == current_qi + escape.relic_qi
		and not battle.relic_ready and battle.preview_action("moon").armor_block == 0,
		"Landing on the rune must disable armor and activate the carried seal on the same turn")
	await capture("godot-v12-khoa-thach-giap.png")
	var cooldown: RefCounted = Run.restore(flow.run.snapshot())
	for remaining in range(Rules.ALTAR_BREAK_TURNS - 1, -1, -1):
		cooldown.perform("guard")
		check(cooldown.battle.seal_turns == remaining, "Armor must return on schedule even while standing on a rune")
	check(cooldown.battle.preview_action("strike").armor_block == Rules.ALTAR_ARMOR,
		"Armor must block damage again after the rune effect expires")
	await play_commands([[KEY_3], [KEY_7], [KEY_4], [KEY_2], [KEY_3]])
	check(flow.run.phase == "altar_reward", "Altar victory must open the reward choice")
	await launch()
	await capture("godot-v12-chien-loi-pham.png")
	var cache: RefCounted = Run.restore(flow.run.snapshot())
	var before_stones: int = cache.stones
	var before_leaves: int = cache.battle.leaves
	check(cache.claim_altar_reward("altar_cache") and cache.stones == before_stones + Run.ALTAR_CACHE_STONES
		and cache.battle.leaves == before_leaves + 1 and Run.restore(cache.snapshot()).altar_award == "altar_cache",
		"The cache must grant and replay both resources")
	await click_button("stone_marrow")
	await launch()
	check(flow.run.phase == "altar_cleared" and flow.run.strike_bonus == Run.ALTAR_STRIKE_BONUS
		and flow.run.relic == "wind_seal" and not flow.run.claim_altar_reward("altar_cache"),
		"The damage reward must persist separately from the relic and can only be taken once")
	var next := Run.battle_for(Run.SEAL_ALTAR, 0, 48, 4, 4, 0, {"strike_bonus": flow.run.strike_bonus}, "seal_altar", true)
	next.wolf = 18
	next.seal_turns = 1
	check(next.preview_action("strike").dealt == Rules.STRIKE_DAMAGE + Run.ALTAR_STRIKE_BONUS + Rules.ALTAR_OPEN_STRIKE,
		"The reward damage must apply in a new encounter and stack with broken armor")


func check_ambush_kit() -> void:
	var kit := {"starter_gu": "stone_veil", "moon_equipped": false, "refined_gu": "scale_veil"}
	var pass_rules := Run.battle_for(Run.AMBUSH_PASS, 0, 48, 4, 4, 0, kit, "ambush", true)
	check(pass_rules.intent.kind == "ambush" and pass_rules.preview_action("scale_veil").evaded
		and pass_rules.veil_turns == 0, "Preview did not evade a direct ambush, or mutated the veil")
	check(pass_rules.take_turn("scale_veil").reaction == "miss" and pass_rules.hp == 48, "The ambush landed through concealment")
	pass_rules.take_turn("stone_veil")
	check(pass_rules.movement_range() == 3, "Ẩn Thạch should prepare a three-step move")
	pass_rules.take_turn("guard")
	pass_rules.hero = 19
	pass_rules.intent = {"kind": "fall", "name": "Đá rơi", "cells": pass_rules.cracks, "damage": 20}
	var falling := pass_rules.preview_action("scale_veil")
	check(not falling.evaded and falling.receives == 20 and falling.steps_bonus == 2 and falling.qi == 1,
		"Ẩn Lân must leave area damage intact and extend movement only for a matching pair")
	pass_rules.take_turn("scale_veil")
	check(pass_rules.scale_veil_cost() == 2 and pass_rules.steps_bonus == 2,
		"The pending enhanced move must not discount a second Ẩn Lân")
	var mixed := Rules.new({"refined_gu": "scale_veil"})
	check(mixed.scale_veil_cost() == 2 and mixed.build_family.is_empty(), "Mixed Ẩn Lân must retain its base cost")
	for variant in range(3):
		var trial := Run.battle_for(Run.AMBUSH_PASS, variant, 48, 4, 4, 0, {}, "ambush", true)
		check(trial.hero not in trial.cracks and trial.wolf not in trial.cracks and trial.intent.kind == "ambush",
			"Spawn or first attack does not match the layout design")
		for cell in trial.cracks:
			check(cell not in trial.rocks, "A cracked floor cell also claims to be a wall")


func check_ford_gu() -> void:
	for variant in range(3):
		var crossing := Run.battle_for(Run.THUNDER_FORD, variant, 48, 4, 4, 0, {}, "ford", true)
		check(crossing.hero not in crossing.water and crossing.wolf not in crossing.water
			and not crossing.move_targets().is_empty(), "A ford layout blocked or flooded a spawn")
		for cell in crossing.water:
			check(cell not in crossing.rocks, "A shallow-water tile also claims to be a wall")
	var ward := Rules.new({"refined_gu": "white_jade", "moon_equipped": false, "jade_skin": true, "revised_ward": true})
	ward.intent = {"kind": "recover", "cells": [], "damage": 0}
	ward.take_turn("jade_skin")
	ward.intent = {"kind": "shot", "name": "Hồ quang", "cells": [ward.hero], "damage": 16}
	var result := ward.preview_action("white_jade")
	check(result.absorbed == 15 and result.receives == 1 and result.qi == 2
		and ward.take_turn("white_jade").hero_damage == 1 and ward.counter_ready and ward.counter_bonus() == 10,
		"Revised armor combo was not stronger and cheaper")
	var mixed := Rules.new({"refined_gu": "white_jade", "starter_gu": "brew", "moon_equipped": false, "revised_ward": true})
	check(mixed.preview_action("white_jade").absorbed == 11 and mixed.white_jade_cost() == 2,
		"Mixed revised armor incorrectly gained the set bonus")

	var ford := Run.battle_for(Run.THUNDER_FORD, 0, 48, 3, 4, 0,
		{"starter_gu": "brew", "moon_equipped": false, "refined_gu": "four_flavors"}, "ford", true)
	check(ford.intent.kind == "flood" and ford.move_targets().has(18)
		and ford.preview_action("move", 18).receives == 18 and ford.preview_action("move", 25).receives == 0,
		"Ford water must be walkable, with a deterministic live-water damage forecast")
	check(ford.preview_action("brew").brew_ready and ford.brew_left == 2 and not ford.brew_ready,
		"Tửu forecast changed inventory")
	ford.take_turn("brew")
	check(ford.qi == 4 and ford.brew_left == 1 and ford.take_turn("brew").has("error"),
		"Tửu Trùng must cap Qi, consume exactly one charge and reject full Qi")
	ford.take_turn("four_flavors")
	ford.wolf = ford.hero + 1
	ford.intent = {"kind": "recover", "cells": [], "damage": 0}
	check(ford.take_turn("four_flavors").has("error") and ford.preview_action("strike").dealt == 26, "Tinh nguyên must not stack")
	ford.take_turn("strike")
	check(ford.strong_strikes == 1 and ford.brew_left == 1, "Tay không did not use exactly one Tinh nguyên")
	var off_set := Rules.new({"refined_gu": "four_flavors"})
	check(off_set.preview_action("four_flavors").strong_strikes == 1, "Tứ Vị without Tửu Trùng received two charges")


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
	check_rank_two_gu()
	check_ford_gu()
	check_ambush_kit()
	check_relic_rules()
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
	await play_rank_two()
	await play_elite_detour()
	DirAccess.remove_absolute(path)
	if not failed:
		print("Godot run passed: legacy journals, wind and altar rewards, armor timing and relic carry")
	quit(1 if failed else 0)
