extends SceneTree

const Scene = preload("res://run_flow.tscn")
const Run = preload("res://run_state.gd")
const Rules = preload("res://battle_rules.gd")
const Pack = preload("res://kennel_pack.gd")
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


func select_kit(recipe: String, starter: String, expected_art: String = "") -> void:
	for choice in [["workshop_recipe", Gu.RECIPES.find(recipe)], ["workshop_starter", Gu.STARTERS.find(starter)]]:
		var input := flow.find_child(choice[0], true, false) as OptionButton
		check(input != null and choice[1] in range(input.item_count), "Missing workshop selection for " + str(choice[0]))
		if input == null or choice[1] not in range(input.item_count):
			return
		input.select(choice[1])
		input.item_selected.emit(choice[1])
	if not expected_art.is_empty():
		var slot := flow.find_child("workshop_art_slot", true, false) as Label
		check(slot != null and slot.text.contains(expected_art) and slot.text.contains("Phụ trợ: Tiểu Quang Cổ"),
			"The workshop must show the equipped art, full cost and support Gu in one slot")
		await capture("godot-owned-art-%s.png" % recipe)
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
	var claimant: Run = Run.restore(flow.run.snapshot())
	var original_vitals := [claimant.battle.hp, claimant.battle.qi, claimant.stones]
	check(claimant.claim_gu_loot(), "A v4 clear should be able to claim the new loot")
	var migrated: Run = Run.restore(claimant.snapshot())
	check(migrated != null and migrated.version == Run.GU_BOOK_VERSION and migrated.snapshot().chapter_rules == 4
		and [migrated.battle.hp, migrated.battle.qi, migrated.stones] == original_vitals
		and migrated.owned_gu.small_light == 2 and not migrated.claim_gu_loot(),
		"A v4 loot upgrade must preserve the original battle, wallet and replay rules")
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


func play_gu_trade() -> void:
	var before_trade: Dictionary = flow.run.snapshot().duplicate(true)
	var wallet: int = flow.run.stones
	check(not flow.run.commit_shop_action("refine_owned_moon") and not flow.run.commit_shop_action("study_moon_link"),
		"Recipes must require the actual Gu in the pouch")
	await click_button("buy_small_light")
	await launch()
	check(flow.run.version == maxi(before_trade.version, Run.GU_SHOP_VERSION)
		and flow.run.owned_gu.small_light == Run.SMALL_LIGHT_BUNDLE
		and flow.run.stones == wallet - Run.SMALL_LIGHT_PRICE and not flow.run.buy("buy_small_light")
		and not flow.run.buy("buy_leaf"), "Buying Gu must cost actual stones and duplicate purchases must be rejected")
	await click_button("refine_owned_moon")
	await launch()
	check(flow.run.owned_gu == {"moon": 0, "small_light": 1, "moon_edge": 1}
		and not flow.run.commit_shop_action("refine_owned_moon"), "Refining must consume one Nguyệt Quang and two Tiểu Quang once")
	await click_button("study_moon_link")
	await launch()
	check(flow.run.moon_link_known and flow.run.owned_gu.small_light == 1
		and flow.run.gu_receipts.count({"gu": "small_light", "change": -2, "source": "Hợp luyện Nguyệt Mang"}) == 1
		and not flow.run.commit_shop_action("study_moon_link"), "The learned combination must save without consuming its components")
	var v18_shop: Dictionary = flow.run.snapshot().duplicate(true)
	v18_shop.version = Run.GU_SHOP_VERSION
	var old_shop := Run.restore(v18_shop) as Run
	check(old_shop != null and old_shop.owned_gu == flow.run.owned_gu and old_shop.moon_link_known
		and old_shop.gu_receipts == flow.run.gu_receipts,
		"A v18 save with a purchase and refinement must rebuild the same inventory and receipts")
	await capture("godot-v18-quay-co.png")
	await click_button("leave_shop")
	await select_kit("moon_edge", "moon", "Liên Nguyệt · %d CN" % Gu.MOON_LINK_COST)
	var battle: Rules = flow.run.battle
	check(battle.moon_link_equipped and flow.current.actions.has("moon_link"),
		"The new art must appear with Nguyệt Mang in a normal fight")
	for step in range(3):
		if battle.unavailable("moon_link").is_empty():
			break
		await shoot(KEY_4)
	var before_hp := battle.wolf_hp
	var before_qi := battle.qi
	check(battle.unavailable("moon_link").is_empty(), "The test must reach a valid line for Liên Nguyệt")
	await shoot(KEY_8)
	await launch()
	battle = flow.run.battle
	check(battle.moon_link_used and battle.wolf_hp == before_hp - Gu.MOON_LINK_DAMAGE
		and battle.qi == before_qi - Gu.MOON_LINK_COST and not battle.unavailable("moon_link").is_empty(),
		"Liên Nguyệt damage, cost and charge must all replay")
	var v18_battle: Dictionary = flow.run.snapshot().duplicate(true)
	v18_battle.version = Run.GU_SHOP_VERSION
	var old_battle := Run.restore(v18_battle) as Run
	check(old_battle != null and old_battle.battle.moon_link_used and old_battle.battle.wolf_hp == battle.wolf_hp
		and old_battle.battle.qi == battle.qi, "A v18 combat record must replay Liên Nguyệt with the same damage and cost")
	flow.run = Run.restore(before_trade)
	flow.persist()
	flow.show_run()


func play_gu_book(ridge_save: Dictionary) -> void:
	var legacy := ridge_save.duplicate(true)
	legacy.version = Run.GU_SHOP_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.can_cross_ford(), "A v18 victory must remain playable")
	flow.persist()
	flow.show_run()
	var wallet: int = flow.run.stones
	await capture("godot-v19-chien-loi-pham.png")
	await click_button("claim_gu_loot")
	await launch()
	check(flow.run.version == Run.GU_BOOK_VERSION and flow.run.stones == wallet and flow.run.owned_gu.small_light == 2
		and not flow.run.claim_gu_loot(), "A v18 loot upgrade must claim once and preserve the wallet")
	var duplicate: Dictionary = flow.run.snapshot().duplicate(true)
	duplicate.journal.append(["claim_gu_loot"])
	check(Run.restore(duplicate) == null, "A duplicated claim in the journal must not be loaded")
	await click_button("cross_ford")
	await click_button("merchant")
	var light_branch := Run.restore(flow.run.snapshot()) as Run
	check(light_branch.buy("buy_small_light") and light_branch.owned_gu.small_light == 5,
		"Purchased and looted copies of a stackable Gu must add together")
	var light_reload := Run.restore(light_branch.snapshot()) as Run
	check(light_reload != null and light_reload.owned_gu.small_light == 5 and not light_reload.buy("buy_small_light"),
		"Combined Gu quantities and the per-shop purchase limit must survive reload")
	await click_button("buy_jade_skin")
	await launch()
	check(flow.run.phase == "shop" and flow.run.owned_gu.jade_skin == 1 and flow.run.stones == wallet - 3
		and not flow.run.buy("buy_jade_skin") and not flow.run.buy("buy_small_light")
		and flow.run.owned_gu.small_light == 2, "The shop must reject repeat and unaffordable Gu purchases")
	duplicate = flow.run.snapshot().duplicate(true)
	duplicate.journal.append(["buy_jade_skin"])
	check(Run.restore(duplicate) == null, "The journal must not replay a duplicate Ngọc Bì purchase")
	await capture("godot-v19-quay-co.png")
	await click_button("leave_shop")
	await select_kit("four_flavors", "brew")
	var before_turn: int = flow.run.battle.turn
	var before_journal: int = flow.run.journal.size()
	await click_button("open_gu_book")
	check(flow.current.name == "GuBook" and flow.find_child("gu_row_jade_skin", true, false) != null
		and flow.find_child("gu_row_small_light", true, false) != null
		and flow.find_child("gu_row_brew", true, false) == null,
		"The book must show purchased and looted Gu and exclude the loaned kit")
	var blocked := flow.find_child("refine_owned_jade", true, false) as Button
	check(blocked != null and blocked.disabled and not flow.run.commit_book_action("refine_owned_jade"),
		"The book cannot complete recipes during battle")
	await click_button("close_gu_book")
	check(flow.run.battle.turn == before_turn and flow.run.journal.size() == before_journal,
		"Reading the book during a fight must not submit an action")
	await play_commands([[KEY_3], [KEY_7], [KEY_1, 19], [KEY_1, 21], [KEY_2], [KEY_2], [KEY_1, 14], [KEY_2], [KEY_2]])
	check(flow.run.can_enter_pass(), "The Gu economy must still allow the original Ford fight without a relic")
	await click_button("claim_gu_loot")
	await launch()
	check(flow.run.owned_gu.white_boar == 1 and flow.run.owned_gu.small_light == 2 and flow.run.owned_gu.jade_skin == 1
		and flow.run.gu_loot_claimed.size() == 2 and not flow.run.claim_gu_loot(), "Both claim sources must survive reload")
	check(flow.run.gu_receipts.count({"gu": "jade_skin", "change": 1, "source": "Quầy dừng bên Suối Sấm"}) == 1
		and flow.run.gu_receipts.count({"gu": "white_boar", "change": 1, "source": "Chiến lợi phẩm · Bãi Đá Suối Sấm"}) == 1,
		"The journal must preserve distinct, single-receipt sources")
	await click_button("open_gu_book")
	check(flow.find_child("gu_row_white_boar", true, false) != null, "The book must show both combat rewards")
	await capture("godot-v19-so-co.png")
	await play_white_jade_recipe()
	await click_button("enter_pass")
	await click_button("merchant")
	check(flow.run.shop_unavailable("buy_jade_skin").contains("Đã có Ngọc Bì") and not flow.run.buy("buy_jade_skin"),
		"The second shop must not sell a duplicate owned copy")


func play_white_jade_recipe() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	check(legacy.version == Run.GU_BOOK_VERSION, "The jade recipe test must start with an actual v19 journal")
	var wallet: int = flow.run.stones
	var qi: int = flow.run.battle.qi
	var hp: int = flow.run.battle.hp
	var missing: Run = Run.restore(legacy) as Run
	missing.owned_gu.white_boar = 0
	var owned_before := missing.owned_gu.duplicate()
	var entries := missing.journal.size()
	check(not missing.commit_book_action("refine_owned_jade") and missing.owned_gu == owned_before
		and missing.journal.size() == entries, "Missing ingredients must leave the whole ledger unchanged")
	check(not flow.run.commit_book_action("study_white_light"), "A loaned Bạch Ngọc must not unlock the art")
	await click_button("refine_owned_jade")
	check(flow.current.name == "GuBook" and flow.find_child("gu_row_white_jade", true, false) != null
		and flow.run.owned_gu.jade_skin == 0 and flow.run.owned_gu.white_boar == 0 and flow.run.owned_gu.white_jade == 1
		and flow.run.stones == wallet and flow.run.battle.qi == qi and flow.run.battle.hp == hp,
		"Refining in the book must consume the two Gu and only those Gu")
	await launch()
	check(flow.run.version == Run.WHITE_JADE_VERSION and flow.run.owned_gu.white_jade == 1
		and flow.run.gu_receipts.count({"gu": "white_jade", "change": 1, "source": "Hợp luyện Bạch Ngọc"}) == 1
		and not flow.run.commit_book_action("refine_owned_jade"), "Save must rebuild a single crafting result")
	await click_button("open_gu_book")
	await click_button("study_white_light")
	await capture("godot-v20-so-co.png")
	await launch()
	check(flow.run.white_light_known and flow.run.owned_gu.small_light == 2 and flow.run.owned_gu.white_jade == 1
		and not flow.run.commit_book_action("study_white_light"), "The art must be learned once without consuming either Gu")
	var forged: Dictionary = flow.run.snapshot().duplicate(true)
	forged.journal.append(["refine_owned_jade"])
	check(Run.restore(forged) == null, "A repeated crafting command must not replay with missing materials")
	forged = flow.run.snapshot().duplicate(true)
	forged.version = Run.GU_BOOK_VERSION
	check(Run.restore(forged) == null, "A v19 header must not accept the new recipe")
	await click_button("enter_pass")
	await click_button("camp")
	var learned: Run = Run.restore(flow.run.snapshot()) as Run
	check(learned.equip_build("moon_edge", "moon") and not learned.battle.white_light_equipped,
		"The art must require Bạch Ngọc in the current kit")
	await select_kit("white_jade", "jade_skin", "%s · %d CN" % [Gu.WHITE_LIGHT_NAME, Gu.WHITE_LIGHT_COST])
	var battle: Rules = flow.run.battle
	check(battle.white_light_equipped and flow.current.actions.has("white_light"), "Bạch Ngọc must unlock the trained art in battle")
	var peek := battle.preview_action("white_light")
	var before_qi := battle.qi
	var before_hp := battle.hp
	await shoot(KEY_8)
	await launch()
	battle = flow.run.battle
	check(battle.white_light_used and battle.qi == before_qi - Gu.WHITE_LIGHT_COST
		and battle.hp == before_hp - int(peek.receives) and battle.white_light_hits == peek.white_light_hits
		and battle.jade_turns == peek.jade_turns and flow.current.actions.white_light.disabled
		and flow.run.owned_gu.white_jade == 1 and flow.run.owned_gu.small_light == 2,
		"Reload must restore the ward, its charge and the still-owned Gu")
	await capture("godot-v20-bach-quang.png")
	var action_count: int = flow.run.journal.size()
	check(flow.run.perform("white_light").has("error") and flow.run.journal.size() == action_count,
		"The second cast must be rejected without writing a turn")
	flow.run = Run.restore(legacy)
	flow.persist()
	flow.show_run()


func play_owned_brew(ridge_save: Dictionary) -> void:
	var legacy := ridge_save.duplicate(true)
	legacy.version = Run.WHITE_JADE_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.version == Run.WHITE_JADE_VERSION and flow.run.wine_sets == 0
		and flow.run.owned_gu.get("brew", 0) == 0, "Old saves must not be granted recipe materials")
	flow.persist()
	flow.show_run()
	await click_button("cross_ford")
	await click_button("merchant")
	await capture("godot-v21-quay-ruou.png")
	var wine_first := Run.restore(flow.run.snapshot()) as Run
	check(wine_first.buy("buy_wine_set") and wine_first.wine_sets == 1
		and wine_first.stones == Goods.RIDGE_STONES - Run.WINE_SET_PRICE
		and not wine_first.buy("buy_brew") and not wine_first.commit_book_action("refine_owned_brew"),
		"Buying wine first must pay its own price and require the Gu pair")
	await click_button("buy_brew")
	await launch()
	check(flow.run.version == Run.FOUR_FLAVORS_VERSION and flow.run.owned_gu.brew == Run.BREW_BUNDLE
		and flow.run.stones == 0 and not flow.run.buy("buy_brew") and not flow.run.buy("buy_wine_set"),
		"Buying the Gu pair must charge the wallet once and leave the wine unpaid")
	var old_header: Dictionary = flow.run.snapshot().duplicate(true)
	old_header.version = Run.WHITE_JADE_VERSION
	check(Run.restore(old_header) == null, "A v20 header must reject the new shop transaction")
	await click_button("open_gu_book")
	var refine := flow.find_child("refine_owned_brew", true, false) as Button
	check(refine != null and refine.disabled and not flow.run.commit_book_action("refine_owned_brew"),
		"The pair alone must not complete the recipe")
	await click_button("close_gu_book")
	await click_button("leave_shop")
	await select_kit("four_flavors", "brew")
	await play_commands([[KEY_3], [KEY_7], [KEY_1, 19], [KEY_1, 21], [KEY_2], [KEY_2], [KEY_1, 14], [KEY_2], [KEY_2]])
	check(flow.run.can_enter_pass() and flow.run.stones == Goods.FORD_STONES
		and flow.run.owned_gu.get("four_flavors", 0) == 0 and flow.run.owned_gu.brew == Run.BREW_BUNDLE,
		"The loaned version must keep the old path winnable without altering the Sổ Cổ")
	await click_button("enter_pass")
	await click_button("merchant")
	await click_button("buy_wine_set")
	await launch()
	check(flow.run.wine_sets == 1 and flow.run.stones == 0 and not flow.run.buy("buy_wine_set"),
		"Save and reload must keep the wine set, charge and per-shop limit")
	await click_button("open_gu_book")
	await capture("godot-v21-bi-phuong-tu-vi.png")
	await click_button("refine_owned_brew")
	await launch()
	check(flow.run.wine_sets == 0 and flow.run.owned_gu.brew == 0 and flow.run.owned_gu.four_flavors == 1
		and flow.run.gu_receipts.count({"gu": "brew", "change": -Run.BREW_BUNDLE, "source": "Hợp luyện Tứ Vị Tửu Trùng"}) == 1
		and not flow.run.commit_book_action("refine_owned_brew"), "Refining must consume both materials, persist and reject a duplicate")
	var replay: Dictionary = flow.run.snapshot().duplicate(true)
	replay.journal.append(["refine_owned_brew"])
	check(Run.restore(replay) == null, "The journal must reject a forged second refinement")
	await click_button("open_gu_book")
	await capture("godot-v21-so-co-tu-vi.png")
	await click_button("close_gu_book")
	await click_button("leave_shop")
	var choices := flow.find_child("workshop_recipe", true, false) as OptionButton
	check(choices != null and choices.get_item_text(Gu.RECIPES.find("four_flavors")).contains("Sở hữu"),
		"The crafted Gu must be shown as owned at the workshop")
	await select_kit("four_flavors", "brew")
	var charge: int = flow.run.battle.qi
	await shoot(KEY_7)
	await launch()
	check(flow.run.battle.strong_strikes == 1 and flow.run.battle.build_family == "brew"
		and flow.run.battle.qi == charge - Gu.FOUR_FLAVORS_COST
		and flow.run.owned_gu.four_flavors == 1 and flow.run.owned_gu.brew == 0,
		"The owned result must keep the existing combat effect, including after reload")


func play_owned_veil(ridge_save: Dictionary) -> void:
	var legacy := ridge_save.duplicate(true)
	legacy.version = Run.FOUR_FLAVORS_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and not flow.run.owned_gu.has("fish_scale"), "A v21 save must load without free veil materials")
	flow.persist()
	flow.show_run()
	await click_button("cross_ford")
	await click_button("merchant")
	await capture("godot-v22-quay-co-an.png")
	await click_button("buy_stone_veil")
	await launch()
	check(flow.run.version == Run.OWNED_VEIL_VERSION and flow.run.stones == 1 and flow.run.owned_gu.stone_veil == 1
		and not flow.run.buy("buy_stone_veil") and not flow.run.buy("buy_fish_scale"),
		"Pay three stones for Ẩn Thạch and reject duplicates and unaffordable materials")
	check(not flow.run.commit_book_action("refine_owned_veil"), "Ẩn Thạch alone must not complete the recipe")
	await click_button("leave_shop")
	await select_kit("four_flavors", "brew")
	await play_commands([[KEY_3], [KEY_7], [KEY_1, 19], [KEY_1, 21], [KEY_2], [KEY_2], [KEY_1, 14], [KEY_2], [KEY_2]])
	await click_button("enter_pass")
	await click_button("merchant")
	await click_button("buy_fish_scale")
	await click_button("open_gu_book")
	await capture("godot-v22-bi-phuong-an-lan.png")
	await click_button("refine_owned_veil")
	await launch()
	check(flow.run.stones == 1 and flow.run.owned_gu.stone_veil == 0 and flow.run.owned_gu.fish_scale == 0
		and flow.run.owned_gu.scale_veil == 1 and not flow.run.commit_book_action("refine_owned_veil"),
		"The five-stone route must spend both ingredients and replay one product")
	var forged: Dictionary = flow.run.snapshot().duplicate(true)
	forged.version = Run.FOUR_FLAVORS_VERSION
	check(Run.restore(forged) == null, "A v21 header cannot replay the new materials")
	await click_button("leave_shop")
	var workshop := flow.find_child("workshop_recipe", true, false) as OptionButton
	check(workshop != null and workshop.get_item_text(Gu.RECIPES.find("scale_veil")).contains("Sở hữu"),
		"The kit must distinguish the crafted Ẩn Lân from the loan")
	await select_kit("scale_veil", "stone_veil")
	var previous_hp: int = flow.run.battle.hp
	var previous_qi: int = flow.run.battle.qi
	await shoot(KEY_7)
	await launch()
	check(flow.run.battle.hp == previous_hp and flow.run.battle.qi == previous_qi - Gu.SCALE_VEIL_COST
		and flow.run.owned_gu.scale_veil == 1, "The owned Gu must evade the opening ambush and replay its existing cost")


func play_waypoints(ridge_save: Dictionary) -> void:
	await play_gu_book(ridge_save)
	await play_owned_brew(ridge_save)
	await play_owned_veil(ridge_save)
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
	await play_gu_trade()
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
	check(opponent != null and opponent.item_count == flow.TRAINING_STAGES.size() - 2, "Boss training must start locked")
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
	await play_pulse_boss()
	await play_xoa_trail()
	await play_nodo_road()
	await play_tin_refinement()
	await play_kennel_trial()
	await play_kennel_two()
	await play_kennel_three()
	await play_kennel_four()
	await click_button("new_run")
	flow.start_new_run(Awakening.profile_for("ao-reu", 12))
	await launch()
	check(flow.run.floor == 0 and flow.boss_seal and flow.pulse_seal and flow.run.battle.tactic.is_empty(),
		"Both training unlocks must survive a new run")
	var campaign := FileAccess.get_file_as_string(path)
	flow.open_training(flow.show_run)
	opponent = flow.find_child("training_opponent", true, false) as OptionButton
	check(opponent != null and opponent.item_count == flow.TRAINING_STAGES.size(), "Both boss training encounters must unlock")
	opponent.select(opponent.item_count - 1)
	await click_button("training_begin")
	check(flow.current.state.tactic == "pulse_boss" and flow.current.state.wolf_hp == Run.PULSE_HALL.hp
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
	var old_capacity: int = cache.battle.max_qi
	var old_hp: int = cache.battle.hp
	check(cache.enter_pulse_hall() and cache.buy_pulse_rite() and not cache.buy_pulse_rite(),
		"The altar cache must be able to fund a single preparation rite")
	cache = Run.restore(cache.snapshot())
	check(cache != null and cache.pulse_rite and not cache.buy_pulse_rite()
		and cache.stones == before_stones + Run.ALTAR_CACHE_STONES - Run.PULSE_RITE_PRICE,
		"The rite and its cost must survive reloading once")
	check(cache.equip_build("moon_edge", "moon") and cache.battle.leaves == before_leaves + 1
		and cache.battle.strike_bonus == 0 and cache.battle.max_qi == old_capacity + 1 and cache.battle.qi == cache.battle.max_qi
		and cache.battle.hp == mini(Rules.MAX_HP, old_hp + Run.PULSE_HEAL + Run.PULSE_RITE_HEAL),
		"The paid preparation and cache supplies must carry into the boss")
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


func play_pulse_boss() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = Run.ALTAR_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.phase == "altar_cleared" and not flow.pulse_seal,
		"A v12 result must retain the altar prize without unlocking the boss reward")
	flow.show_run()
	await click_button("enter_pulse_hall")
	await launch()
	check(flow.run.version == Run.PULSE_VERSION and flow.run.phase == "pulse_workshop"
		and not flow.run.enter_pulse_hall() and not flow.run.claim_pulse_reward("pulse_pearl")
		and not flow.run.buy_pulse_rite(), "Boss entry must upgrade once and reject unfunded preparation")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	check(battle.tactic == "pulse_boss" and battle.strike_bonus == Run.ALTAR_STRIKE_BONUS
		and battle.intent.inner and battle.intent.radius == 2 and battle.intent.cells == flow.current.field.threatened,
		"Thạch Tủy and the inner wave must reach the battle")
	await capture("godot-v13-noi-chan.png")
	var doomed: RefCounted = Run.restore(flow.run.snapshot())
	for i in range(44):
		if doomed.phase == "battle":
			doomed.perform("guard")
	check(doomed.phase == "death" and not doomed.claim_pulse_reward("pulse_cache")
		and Run.restore(doomed.snapshot()).phase == "death", "Boss defeat must never award loot")
	await play_commands([[KEY_3], [KEY_1, 18]])
	check(not battle.intent.inner and battle.hero in battle.intent.cells
		and battle.preview_action("move", 20).receives == 0, "Outer wave must leave a safe route inwards")
	await shoot(KEY_1, 20)
	await launch()
	battle = flow.run.battle
	check(battle.pulse_open and battle.intent.kind == "recover" and battle.preview_action("strike").exposed_damage == Rules.PULSE_OPEN_BONUS
		and battle.preview_action("strike").dealt == Rules.STRIKE_DAMAGE + Run.ALTAR_STRIKE_BONUS + Rules.PULSE_OPEN_BONUS,
		"Escaping the wave must preserve the one-turn opening across reload")
	await play_commands([[KEY_2], [KEY_7], [KEY_2]])
	check(battle.wolf_hp * 2 <= battle.wolf_max and battle.intent.radius == 3 and not battle.intent.inner
		and battle.intent.damage == Run.PULSE_HALL.damage + Rules.PULSE_ENRAGE_DAMAGE and not battle.pulse_open,
		"The next pulse below half HP must shift the boundary and raise damage")
	await capture("godot-v13-ngoai-chan.png")
	await shoot(KEY_3)
	check(flow.run.phase == "pulse_reward" and flow.pulse_seal, "Victory must grant the practice unlock before choosing loot")
	await launch()
	await capture("godot-v13-chien-loi-pham.png")
	var cache: RefCounted = Run.restore(flow.run.snapshot())
	var stones: int = cache.stones
	var leaves: int = cache.battle.leaves
	check(cache.claim_pulse_reward("pulse_cache") and cache.stones == stones + Run.PULSE_CACHE_STONES
		and cache.battle.leaves == leaves + Run.PULSE_CACHE_LEAVES and Run.restore(cache.snapshot()).pulse_award == "pulse_cache",
		"The boss cache must persist both currencies")
	check(cache.enter_xoa_trail() and cache.equip_build("moon_edge", "moon")
		and cache.battle.relic == "wind_seal" and cache.battle.leaves == leaves + Run.PULSE_CACHE_LEAVES,
		"The cache must bring its leaves and keep the prior relic at Tam Xoa")
	await click_button("pulse_pearl")
	await launch()
	check(flow.run.phase == "rank_three_cleared" and flow.run.relic == "pulse_pearl" and flow.pulse_seal
		and not flow.run.claim_pulse_reward("pulse_cache"), "The pearl and chapter clear must survive reload")
	var pearl := Rules.new({"qi": 2, "relic": flow.run.relic, "wolf_hp": 120})
	check(pearl.preview_action("moon").relic_qi == Goods.PULSE_PEARL_QI and pearl.relic_ready and pearl.qi == 2,
		"Preview must report the refund without changing the relic")
	pearl.take_turn("moon")
	check(pearl.qi == 2 and not pearl.relic_ready and pearl.preview_action("moon").relic_qi == 0,
		"The pearl should refund only the first actual paid cast")
	var empty := Rules.new({"qi": 1, "relic": flow.run.relic})
	check(empty.take_turn("moon").has("error") and empty.relic_ready and empty.qi == 1,
		"The refund must not let a player cast with insufficient Qi")


func play_xoa_trail() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	legacy.version = Run.PULSE_VERSION
	flow.run = Run.restore(legacy)
	check(flow.run != null and flow.run.phase == "rank_three_cleared" and flow.run.relic == "pulse_pearl",
		"The v13 clear must keep its prize before entering the new rank")
	flow.show_run()
	await click_button("enter_xoa_trail")
	await launch()
	check(flow.run.version == Run.XOA_VERSION and flow.run.phase == "xoa_workshop" and not flow.run.enter_xoa_trail()
		and not flow.run.claim_xoa_reward("iron_hide"), "The Tam Xoa trail must open once and lock its reward")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	var frontal := battle.preview_action("moon")
	check(battle.tactic == "armored_hound" and battle.hound_facing == -1 and battle.intent.cells == flow.current.field.threatened
		and battle.hero in battle.intent.cells and frontal.armor_block == Rules.HOUND_FRONT_ARMOR
		and frontal.relic_qi == Goods.PULSE_PEARL_QI and battle.relic_ready,
		"The forecast must show the opening rush, front armor and unspent pearl refund")
	await capture("godot-v14-bai-da-tam-xoa.png")
	var flank := Run.battle_for(Run.XOA_TRAIL, 0, 48, 4, 4, 0, {}, "armored_hound", true)
	flank.hero = 13
	flank.forecast()
	check(flank.preview_action("strike").armor_block == 0
		and flank.preview_action("strike").exposed_damage == Rules.HOUND_FLANK_STRIKE,
		"A hit from the hound column must bypass front armor and add flank damage")
	flank.hero = 22
	flank.turn = 2
	flank.forecast()
	check(flank.hound_facing == -1 and not flank.hound_guards(flank.hero), "The hound must hold facing between rushes")
	flank.turn = 4
	flank.forecast()
	check(flank.hound_facing == 1 and flank.intent.cells == [22, 23] and flank.hound_guards(flank.hero),
		"A new rush must turn the armor and switch the danger lane")
	var shelter := Run.battle_for(Run.XOA_TRAIL, 2, 48, 4, 4, 0, {}, "armored_hound", true)
	check(shelter.intent.cells == [20, 19] and shelter.hero not in shelter.intent.cells,
		"A boulder in the lane must stop the rush forecast")
	await play_commands([[KEY_4], [KEY_3], [KEY_3], [KEY_1, 26]])
	await launch()
	battle = flow.run.battle
	check(battle.hero == 26 and battle.intent.kind == "recover" and not battle.relic_ready,
		"Moving out of the locked row and consuming the pearl must replay")
	await play_commands([[KEY_4], [KEY_3], [KEY_2], [KEY_2], [KEY_3]])
	check(flow.run.phase == "xoa_reward", "The hound victory must offer its hide")
	await launch()
	await capture("godot-v14-da-thiet-giap.png")
	var sale: RefCounted = Run.restore(flow.run.snapshot())
	var stones: int = sale.stones
	check(sale.claim_xoa_reward("sell_iron_hide") and sale.stones == stones + Run.XOA_HIDE_PRICE and sale.relic == "pulse_pearl"
		and Run.restore(sale.snapshot()).xoa_award == "sell_iron_hide", "Selling the hide must keep the old relic and add stones")
	await click_button("iron_hide")
	await launch()
	check(flow.run.phase == "xoa_cleared" and flow.run.relic == "iron_hide"
		and not flow.run.claim_xoa_reward("sell_iron_hide"), "Equipping the hide must persist and close the loot choice")
	var trial := Rules.new({"relic": flow.run.relic})
	check(trial.preview_action("moon").relic_block == 0 and trial.preview_action("guard").relic_block > 0 and trial.relic_ready,
		"The hide must only protect a guarded hit and preview without mutation")
	trial.take_turn("guard")
	check(not trial.relic_ready, "The first guarded hit must consume the hide charge")


func play_nodo_road() -> void:
	var legacy: Dictionary = flow.run.snapshot().duplicate(true)
	check(legacy.version == Run.XOA_VERSION, "Leaving the bãi đá save must not upgrade until camp")
	await click_button("enter_xoa_camp")
	await launch()
	check(flow.run.version == Run.NODO_VERSION and flow.run.phase == "xoa_camp" and flow.run.relic == "iron_hide"
		and not flow.run.enter_xoa_camp(), "Camp must upgrade a v14 journal once and retain the hide")
	await capture("godot-v15-trai-tam.png")
	var sale: RefCounted = Run.restore(legacy)
	sale.stones = 0
	check(sale.enter_xoa_camp() and not sale.choose_nodo_camp("nodo_supplies") and sale.stones == 0,
		"An unaffordable camp purchase must leave the journal and inventory alone")
	var source: RefCounted = Run.restore(legacy)
	source.phase = "xoa_reward"
	source.journal.pop_back()
	source.relic = "pulse_pearl"
	check(source.claim_xoa_reward("sell_iron_hide") and source.enter_xoa_camp(),
		"The sale branch must also reach camp")
	var offer: Dictionary = source.nodo_camp_preview("nodo_supplies")
	var previous_leaves: int = source.battle.leaves
	var previous_stones: int = source.stones
	check(offer.reason.is_empty() and source.choose_nodo_camp("nodo_supplies")
		and source.stones == previous_stones - Run.NODO_SUPPLY_PRICE
		and source.workshop_vitals().leaves == previous_leaves + Run.NODO_SUPPLY_LEAVES
		and not source.choose_nodo_camp("nodo_supplies"),
		"Supplies must spend the displayed stones and grant leaves once")
	var restored_sale: RefCounted = Run.restore(source.snapshot())
	check(restored_sale != null and restored_sale.phase == "nodo_workshop" and restored_sale.relic == "pulse_pearl"
		and restored_sale.stones == source.stones and restored_sale.workshop_vitals() == source.workshop_vitals(),
		"The sold-hide branch must restore its prior relic and purchased leaves")
	await click_button("nodo_rest")
	await launch()
	check(flow.run.phase == "nodo_workshop", "Rest choice must persist before equipment")
	await select_kit("moon_edge", "moon")
	var battle: Rules = flow.run.battle
	check(battle.intent.kind == "nodo_command" and battle.preview_action("moon").interrupts,
		"Targeting the controller during command must preview interruption")
	await capture("godot-v15-duong-nui-tam-xoa.png")
	await click_button("target_hound")
	check(flow.current.attack_target("moon_edge") == battle.hound_cell
		and battle.preview_action("moon_edge", battle.hound_cell).get("hits_hound", false),
		"Selecting the hound must use its own tile, range and hit forecast: %s" % battle.unavailable("moon_edge", battle.hound_cell))
	await play_commands([[KEY_7]])
	check(battle.hound_hp < battle.hound_max and battle.wolf_hp == battle.wolf_max and battle.intent.kind == "nodo_hound",
		"An attack on the hound must resolve on the hound and allow a non-interrupted order")
	await launch()
	battle = flow.run.battle
	check(battle.intent.kind == "nodo_hound" and battle.ordered_cell == battle.hero
		and battle.intent.cells == flow.current.field.threatened and battle.hound_hp < battle.hound_max,
		"Reload must reconstruct both targets and the locked tile from actual moves")
	await capture("godot-v15-khuyen-thu-vo.png")
	var brace := battle.preview_action("guard")
	check(brace.relic_block > 0 and brace.receives < battle.intent.damage,
		"The hide must mitigate a guarded hound lunge")
	await play_commands([[KEY_4]])
	check(not battle.relic_ready and battle.ordered_cell == -1, "The lunge must spend the guarded hide and clear the order")
	for i in range(18):
		if flow.run.phase != "battle":
			break
		var code := KEY_4
		if battle.unavailable("moon").is_empty() and (battle.intent.kind in ["nodo_command", "advance"] or battle.wolf_hp <= battle.moon_damage):
			code = KEY_3
		elif battle.hp <= 20 and battle.unavailable("vital_leaf").is_empty():
			code = KEY_6
		await play_commands([[code]])
	check(flow.run.phase == "nodo_cleared", "Winning the two-target fight must open the route result")
	await launch()
	check(flow.run.phase == "nodo_cleared" and flow.run.battle.ordered_cell == -1,
		"The camp, target choices and victory must replay in the saved run")


func play_tin_refinement() -> void:
	var road: Dictionary = flow.run.snapshot().duplicate(true)
	await click_button("reach_tam_xoa_gate")
	await launch()
	check(flow.run.version == Run.TIN_VERSION and flow.run.phase == "tam_xoa_gate",
		"The old road result must open the new selection and restore it")
	var kennel := Run.restore(flow.run.snapshot()) as Run
	check(kennel != null and kennel.reach_kennel_gate() and kennel.phase == "kennel_gate"
		and not kennel.reach_tin_gate() and not kennel.owned_gu.has("paper_crane"),
		"Khuyển Vương must stay accessible from the new gate without granting the lam key")
	await capture("godot-v24-cua-tam-vuong.png")
	await click_button("reach_tin_gate")
	await launch()
	check(flow.run.phase == "tin_gate" and flow.run.owned_gu.paper_crane == 1
		and not flow.run.reach_tin_gate() and not flow.run.hound_gu,
		"The lam gate must grant one key, with no crossover into the kennel")
	await click_button("enter_tin_trial")
	await launch()
	check(flow.run.phase == "tin_trial" and flow.run.floor == Run.TIN_FLOOR
		and flow.run.book_unavailable("refine_owned_veil").contains("phúc địa")
		and flow.run.perform("moon").has("error"), "The trial must seal outside Gu and crafting")
	await capture("godot-v24-dai-luyen-tin-vuong.png")
	var entry: Dictionary = flow.run.snapshot().duplicate(true)
	var forged := entry.duplicate(true)
	forged.version = Run.KENNEL_FOUR_VERSION
	check(Run.restore(forged) == null, "The new gate and trial must not replay with a v23 header")
	forged = entry.duplicate(true)
	forged.journal.append(["buy_wine_set"])
	check(Run.restore(forged) == null, "Unrelated shop actions cannot replay as furnace actions")
	await click_button("tin_refine")
	check(flow.run.tin_refinement.turns == 1 and flow.run.tin_refinement.progress == 0,
		"A wrong temperature must spend time without advancing the player")
	await click_button("tin_heat_up")
	await click_button("tin_refine")
	await launch()
	check(flow.run.tin_refinement.heat == 1 and flow.run.tin_refinement.turns == 3
		and flow.run.tin_refinement.progress == 1 and flow.run.tin_refinement.opponent_progress() == 1,
		"Reload must restore both competitors' progress, furnace heat and remaining turns")
	for action: String in ["tin_heat_up", "tin_refine", "tin_heat_down", "tin_refine"]:
		await click_button(action)
	await launch()
	check(flow.run.phase == "tin_cleared" and flow.run.tin_refinement.won and flow.run.owned_gu.paper_crane == 1
		and not flow.run.act_tin_refinement("tin_refine"), "A final-turn win and the retained key must replay once")
	await capture("godot-v24-vuot-tin-vuong.png")
	flow.run = Run.restore(entry)
	flow.persist()
	flow.show_run()
	for step in range(Run.TinRefinement.TURN_LIMIT):
		await click_button("tin_refine")
	await launch()
	check(flow.run.phase == "death" and flow.run.tin_refinement.lost
		and flow.find_child("rebirth", true, false) != null, "A lost duel must replay and offer the existing rebirth flow")
	flow.run = Run.restore(road)
	flow.persist()
	flow.show_run()


func play_kennel_trial() -> void:
	var saved_v15: Dictionary = flow.run.snapshot().duplicate(true)
	check(saved_v15.version == Run.NODO_VERSION, "The road remains v15 before going to the pillar")
	var legacy: RefCounted = Run.restore(saved_v15)
	check(legacy != null and legacy.phase == "nodo_cleared" and not legacy.enter_kennel()
		and not legacy.refine_hound_gu(), "A v15 win must restore at the road with both gate actions locked")
	var old_relic: String = flow.run.battle.relic
	var old_leaves: int = flow.run.battle.leaves
	var old_refined: String = flow.run.battle.refined_gu
	check(flow.run.reach_kennel_gate(), "The legacy direct route must remain valid in existing journals")
	flow.persist()
	flow.show_run()
	await launch()
	check(flow.run.phase == "kennel_gate" and flow.run.version == Run.KENNEL_VERSION and flow.run.hound_gu == 0
		and not flow.run.enter_kennel(), "Entering Tam Xoa must upgrade the save and require refining the first Gu")
	await capture("godot-v16-cot-sang-khuyen-vuong.png")
	await click_button("refine_hound_gu")
	await launch()
	check(flow.run.phase == "kennel_ready" and flow.run.hound_gu == 1 and not flow.run.refine_hound_gu(),
		"Refining the key must persist and must be single-use")
	await click_button("enter_kennel")
	await launch()
	var battle: Rules = flow.run.battle
	check(flow.run.floor == Run.KENNEL_FLOOR and battle.tactic == "kennel" and flow.run.outside_battle.relic == old_relic
		and flow.run.outside_battle.leaves == old_leaves and flow.run.outside_battle.refined_gu == old_refined
		and battle.relic.is_empty() and battle.leaves == 0 and battle.refined_gu.is_empty(),
		"The aperture must lock outside equipment while preserving it in the run")
	check(flow.current.actions.has("bind_hound") and flow.current.actions.size() == 3
		and battle.unavailable("strike").contains("phong cấm")
		and battle.unavailable("moon_edge").contains("phong cấm"), "Only movement, guarding and the proper Gu are available")
	var journal_size: int = flow.run.journal.size()
	check(flow.run.perform("bind_hound").has("error") and flow.run.journal.size() == journal_size,
		"A bind out of range must be harmless")
	for step in range(5):
		if battle.unavailable("bind_hound").is_empty():
			break
		await play_commands([[KEY_4]])
	var position := battle.wolf
	var health := battle.wolf_hp
	var before_qi := battle.qi
	await launch()
	battle = flow.run.battle
	check(battle.wolf == position and battle.unavailable("bind_hound").is_empty(), "Save must restore the dog's approach")
	await capture("godot-v16-bai-co-phuc-dia.png")
	await play_commands([[KEY_3]])
	await launch()
	check(flow.run.phase == "kennel_cleared" and flow.run.battle.wolf_hp == health
		and flow.run.battle.qi == before_qi - Rules.BIND_COST and flow.run.hound_gu == 1
		and flow.run.gu_receipts.count({"gu": "dog_control", "change": -1, "source": "Thu phục ở vòng 1 Khuyển Vương"}) == 1
		and flow.run.gu_receipts.count({"gu": "dog_control", "change": 1, "source": "Thưởng vòng 1 Khuyển Vương"}) == 1,
		"Winning must save the healthy dog and the next Gu after spending the first one")
	await capture("godot-v16-qua-vong-dau.png")
	var duplicate: Dictionary = flow.run.snapshot().duplicate(true)
	duplicate.journal.append(["bind_hound", -1])
	check(Run.restore(duplicate) == null, "The reward cannot be awarded twice by replay")
	duplicate = flow.run.snapshot().duplicate(true)
	duplicate.version = Run.NODO_VERSION
	check(Run.restore(duplicate) == null, "The v15 schema must not accept an inner-trial journal")


func play_kennel_two() -> void:
	var old: Dictionary = flow.run.snapshot().duplicate(true)
	check(old.version == Run.KENNEL_VERSION, "The first round must still load from the v16 result")
	var original: Rules = flow.run.battle
	await click_button("enter_kennel_two")
	await launch()
	var pack := flow.run.battle as Pack
	check(flow.run.version == Run.KENNEL_TWO_VERSION and pack != null and pack.living_dogs(false).size() == 3
		and pack.living_dogs(true) == [0] and pack.dogs[0].hp == original.wolf_hp
		and pack.hp == original.hp and pack.qi == original.qi and pack.gu_left == 1,
		"The second round must carry the actual dog, Gu and vitals from v16")
	await capture("godot-v17-go-co.png")
	await play_commands([[KEY_5, 16]])
	check(pack.dogs[2].hp == Pack.DOG_HP - Pack.ALLY_BITE and pack.dogs[0].cell == 17,
		"The first dog must take a step and bite when ordered")
	var starting_qi := pack.qi
	await play_commands([[KEY_3, 11]])
	check(pack.gu_left == 0 and flow.run.hound_gu == 0 and pack.bound_id == 1 and pack.dogs[1].hp == Pack.DOG_HP
		and pack.qi == starting_qi - Rules.BIND_COST and pack.living_dogs(false).size() == 2,
		"The second Gu must spend one charge and change just the chosen dog to allied")
	var after_capture := pack.dogs.duplicate(true)
	var threat := pack.intent.duplicate(true)
	var mid_save: Dictionary = flow.run.snapshot().duplicate(true)
	await launch()
	pack = flow.run.battle as Pack
	check(pack != null and pack.dogs == after_capture and pack.intent == threat and pack.gu_left == 0
		and flow.run.hound_gu == 0 and flow.run.gu_receipts.count({"gu": "dog_control", "change": -1, "source": "Thu phục ở vòng 2 Khuyển Vương"}) == 1,
		"Loading after capture must recover all dogs and their queued intentions")
	var invalid := mid_save.duplicate(true)
	invalid.journal.append(["bind_hound", 20])
	check(Run.restore(invalid) == null and not flow.run.enter_kennel_two(), "Replays cannot duplicate equipment or enter twice")
	await capture("godot-v17-hai-cho.png")
	await click_button("select_pack_dog_1")
	await play_commands([[KEY_5, 20]])
	check(pack.dogs[3].hp == Pack.DOG_HP - Pack.ALLY_BITE and pack.dogs[1].cell == 12,
		"The captured dog must take its own order from the HUD")
	key(KEY_6)
	await play_commands([[KEY_5, 16]])
	key(KEY_6)
	await play_commands([[KEY_5, 20]])
	check(flow.run.phase == "kennel_two_cleared" and pack.living_dogs(true) == [0, 1] and flow.run.hound_gu == 0,
		"Round two must end with both dogs and the spent Gu")
	var winning_dogs := pack.dogs.duplicate(true)
	var remaining_hp := pack.hp
	await launch()
	check(flow.run.phase == "kennel_two_cleared" and (flow.run.battle as Pack).dogs == winning_dogs
		and flow.run.battle.hp == remaining_hp and flow.run.hound_gu == 0,
		"Loading the win must preserve both remaining dogs and their wounds")
	await capture("godot-v17-vuot-vong-hai.png")


func play_kennel_three() -> void:
	var original: Pack = flow.run.battle as Pack
	var old: Dictionary = flow.run.snapshot().duplicate(true)
	check(old.version == Run.KENNEL_TWO_VERSION, "Round two must still load before entering the new arena")
	await click_button("enter_kennel_three")
	await launch()
	var pack := flow.run.battle as Pack
	check(flow.run.version == Run.KENNEL_THREE_VERSION and pack.round_number == 3 and pack.hp == original.hp
		and pack.hero == Pack.PIT_CELL and pack.gu_left == 0 and pack.living_dogs(false).size() == 6,
		"The third round carries the caster into the pit with six enemies and no fresh Gu")
	check(pack.dogs[0].hp == original.dogs[0].hp and pack.dogs[1].hp == original.dogs[original.bound_id].hp
		and pack.intent.orders.size() == 2 and pack.unavailable("moon_link").contains("phong cấm"),
		"The two wounded allies must carry over, and only the two healthy wild dogs act first")
	await capture("godot-v18-ho-da.png")
	await play_commands([[KEY_5, 10], [KEY_5, 20]])
	var halfway := pack.dogs.duplicate(true)
	var intent := pack.intent.duplicate(true)
	await launch()
	pack = flow.run.battle as Pack
	check(pack.dogs == halfway and pack.intent == intent and pack.turn == 3 and pack.intent.orders.size() == 4,
		"Loading must preserve the wounded pack and the staggered four-dog approach")
	key(KEY_6)
	await play_commands([[KEY_5, 20]])
	key(KEY_6)
	await play_commands([[KEY_5, 11], [KEY_5, 11], [KEY_5, 11], [KEY_5, 18], [KEY_5, 3]])
	var final_pack := pack.dogs.duplicate(true)
	check(flow.run.phase == "kennel_three_cleared" and pack.living_dogs(false).is_empty()
		and pack.living_dogs(true).size() == 2, "The pit can be cleared with both wounded dogs")
	await launch()
	check(flow.run.phase == "kennel_three_cleared" and (flow.run.battle as Pack).dogs == final_pack,
		"The third round result must restore both survivors exactly")
	await capture("godot-v18-vuot-ho-da.png")


func play_kennel_four() -> void:
	var checkpoint: Dictionary = flow.run.snapshot().duplicate(true)
	check(checkpoint.version == Run.KENNEL_THREE_VERSION and not flow.run.enter_kennel_four("unknown"),
		"The saved third round must open the choices but reject an unknown formation")
	var restart := flow.find_child("new_run", true, false) as Button
	var hold := flow.find_child("ridge_hold", true, false) as Button
	check(restart != null and hold != null and hold.get_global_rect().end.y < restart.get_global_rect().position.y,
		"The formation controls must leave the new-run button reachable")
	await capture("godot-v23-chon-the-dan.png")
	for id: String in Run.KENNEL_FORMATIONS:
		flow.run = Run.restore(checkpoint)
		flow.persist()
		flow.show_run()
		var before := flow.run.battle as Pack
		await click_button(id)
		await launch()
		var pack := flow.run.battle as Pack
		var formation: Array = Pack.RIDGE_FORMATIONS[id]
		check(flow.run.version == Run.KENNEL_FOUR_VERSION and pack.hero == formation[0]
			and pack.dogs[0].cell == formation[1] and pack.dogs[1].cell == formation[2]
			and pack.dogs[0].hp == before.dogs[0].hp and pack.dogs[1].hp == before.dogs[before.bound_id].hp
			and pack.gu_left == 0 and pack.hp == before.hp and pack.qi == before.qi
			and pack.living_dogs(false).size() == 5 and pack.intent.orders.size() == 3,
			"The chosen formation must replay with unchanged reserves and the five-dog encounter")
		var wrong_version: Dictionary = flow.run.snapshot().duplicate(true)
		wrong_version.version = Run.OWNED_VEIL_VERSION
		check(Run.restore(wrong_version) == null and not flow.run.enter_kennel_four(id)
			and pack.unavailable("scale_veil").contains("phong cấm"),
			"The formation cannot replay in an old schema, repeat mid-battle or lift the Gu restriction")
		await capture("godot-v23-%s.png" % id)
		await shoot(KEY_2, 19 if id == "ridge_hold" else 20)
		var dogs := pack.dogs.duplicate(true)
		var forecast := pack.intent.duplicate(true)
		await launch()
		check(flow.run.battle.dogs == dogs and flow.run.battle.intent == forecast
			and flow.run.battle.turn == 2, "The first order and telegraph must replay on both paths")
		if id == "ridge_hold":
			await play_commands([[KEY_5, 12], [KEY_5, 11], [KEY_5, 12], [KEY_5, 11], [KEY_5, 5],
				[KEY_5, 5], [KEY_5, 3], [KEY_5, 6]])
		else:
			await play_commands([[KEY_5, 11], [KEY_5, 12], [KEY_5, 11], [KEY_5, 12], [KEY_5, 2],
				[KEY_5, 5], [KEY_5, 5]])
			key(KEY_6)
			await shoot(KEY_2, 34)
			key(KEY_6)
			await shoot(KEY_5, 6)
		check(flow.run.phase == "kennel_four_cleared", "Each formation must win from the actual pit save")
		var survivors: Array = flow.run.battle.dogs.duplicate(true)
		await launch()
		check(flow.run.phase == "kennel_four_cleared" and flow.run.battle.dogs == survivors,
			"The saved victory must retain its surviving pack")
	await capture("godot-v23-ket-qua-vong-bon.png")


func check_pack_rules() -> void:
	var pack := Pack.new({"qi": 1})
	pack.rocks = [11]
	check(pack.unavailable("bind_hound", 3).contains("Đá chắn"), "Stone must obstruct the new Gu in round two")
	check(pack.unavailable("bind_hound", 18).contains("chó hoang") and pack.unavailable("moon_edge").contains("phong cấm")
		and pack.unavailable("vital_leaf").contains("phong cấm") and pack.unavailable("strike").contains("phong cấm")
		and not pack.unavailable(Pack.BOUND_MOVE).is_empty(), "The Gu only targets wild dogs, and the ordinary kit stays sealed")
	pack.rocks = []
	pack.dogs[1].cell = 11
	pack.dogs[1].hp = 7
	pack.forecast()
	var peek := pack.preview_action("bind_hound", 11)
	check(not peek.has("error") and pack.gu_left == 1 and pack.dogs[1].hp == 7 and not pack.dogs[1].allied,
		"Preview must not spend the Gu or change the wounded target")
	var exchange := pack.take_turn("bind_hound", 11)
	check(pack.gu_left == 0 and pack.dogs[1].hp == 7 and exchange.hero_damage == 0
		and pack.dogs[1].allied and pack.take_turn("bind_hound", 21).has("error"),
		"A bound dog keeps its wounds and cancels its old strike immediately")
	check(pack.hero not in pack.targets_for(Pack.BOUND_MOVE) and pack.actor_cell(0) not in pack.targets_for("move"),
		"The hero and the dog must not share cells")
	pack = Pack.new({"hp": 1, "qi": 0})
	pack.dogs[1].cell = 11
	pack.forecast()
	pack.take_turn("guard")
	check(pack.result == Pack.DEFEAT, "Ignoring a red bite must still be lethal at low HP")
	pack = Pack.new({}, 2)
	check(pack.actor_cell(0) in pack.intent.cells, "Layout three must telegraph a bite on the first dog")
	exchange = pack.take_turn(Pack.LEAD_MOVE, 10)
	check(not exchange.has("error") and pack.actor_cell(0) == 10 and pack.dogs[0].hp == pack.dogs[0].max_hp,
		"Moving the dog off a locked tile must dodge the bite")


func check_kennel_rules() -> void:
	var battle := Rules.new({"tactic": "kennel", "qi": 1, "wolf_cell": 19, "rocks": [18]})
	check(battle.unavailable("bind_hound").contains("Tảng đá")
		and battle.unavailable("bind_hound", 20).contains("đúng ô"),
		"Cover and invalid targets must both stop the bind")
	check(Rules.new().unavailable("bind_hound").contains("Không có"), "The new action must be restricted to the trial")
	battle = Rules.new({"tactic": "kennel", "hp": 1, "qi": 0, "wolf_cell": 18, "rocks": []})
	check(battle.unavailable("bind_hound").contains("chân nguyên"), "The cast must require essence")
	battle.take_turn("guard")
	check(battle.result == Rules.DEFEAT, "The protected inventory must not prevent death in the trial")
	for layout in range(3):
		for capacity in range(4, 8):
			for hp in [1, 8, 24, 48]:
				var run := Run.new(Awakening.profile_for("huyen-bao", 12), 1594323 * layout, Run.NODO_VERSION)
				run.phase = "nodo_cleared"
				run.battle = Rules.new({"hp": hp, "qi": 0, "max_qi": capacity})
				check(run.reach_kennel_gate() and run.refine_hound_gu() and run.enter_kennel() and run.battle.qi == 1,
					"Every gate entry must supply enough for one bind")
				for step in range(6):
					if run.battle.unavailable("bind_hound").is_empty():
						run.perform("bind_hound")
						break
					run.perform("guard")
				check(run.phase == "kennel_cleared" and run.battle.hp == hp
					and run.battle.wolf_hp == Run.KENNEL_TRIAL.hp and run.hound_gu == 1,
					"A cautious first round must work in layout %d with %d HP and %d capacity" % [layout, hp, capacity])


func check_nodo_targets() -> void:
	var battle := Rules.new({"tactic": "nodo", "hound_cell": 19, "hound_hp": 40, "wolf_cell": 21, "rocks": [],
		"starter_gu": "moon", "refined_gu": "moon_edge", "qi": 6, "max_qi": 6})
	check(battle.shot_blocker(battle.wolf) == battle.hound_cell and battle.unavailable("moon").contains("chắn")
		and battle.unavailable("moon", 10).contains("đối thủ") and battle.hound_cell not in battle.move_targets(),
		"Live actors must block a shot and movement while invalid targets are rejected")
	battle.take_turn("moon", 19)
	check(battle.hound_mark and not battle.moon_mark and battle.ordered_cell == 17,
		"Lunar marking the hound alone must not interrupt the master")
	var cut := battle.take_turn("moon_edge", 19)
	check(cut.hound_damage == 14 and cut.set_trigger and cut.hero_damage == 0 and battle.hound_hp == 0
		and battle.wolf_hp == battle.wolf_max and battle.ordered_cell == -1 and battle.shot_blocker(battle.wolf) < 0,
		"Only the hound's mark is spent, killing it cancels the lunge and frees the tile")
	battle = Rules.new({"tactic": "nodo", "hound_cell": 13, "hound_hp": 40, "wolf_cell": 21, "rocks": []})
	var strike := battle.take_turn("moon")
	check(strike.wolf_damage > 0 and battle.hound_hp == 40 and battle.ordered_cell == -1
		and battle.intent.kind != "nodo_hound", "Hitting the master while ordering must interrupt the hound")
	battle = Rules.new({"tactic": "nodo", "wolf_hp": 20, "hound_cell": 13, "hound_hp": 40, "rocks": []})
	battle.take_turn("guard")
	var finish := battle.take_turn("moon")
	check(battle.result == Rules.VICTORY and finish.hero_damage == 0 and battle.hound_hp == 40,
		"Defeating the controller must cancel even a queued lunge")
	battle = Rules.new({"tactic": "nodo", "hound_cell": 22, "hound_hp": 40, "rocks": []})
	battle.take_turn("guard")
	check(battle.intent.kind == "nodo_hound_advance" and battle.intent.destination != battle.wolf,
		"A hound blocked by its master must approach on an open tile")
	battle.take_turn("guard")
	check(battle.hound_cell != 22 and battle.hound_cell != battle.wolf and battle.ordered_cell == -1,
		"Approach must move on the grid and consume the order")


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


func check_tin_recipes() -> void:
	var Tin = Run.TinRefinement
	for layout in range(Tin.RECIPES.size()):
		var trial = Tin.new(layout)
		var wrong: String = Tin.HEAT_DOWN if trial.heat == 0 else Tin.HEAT_UP if trial.heat == 2 else "guard"
		check(not trial.apply(wrong) and trial.turns == 0 and trial.progress == 0,
			"Blocked heat controls cannot advance the opponent")
		for temperature: int in trial.recipe:
			var direction: String = Tin.HEAT_UP if trial.heat < temperature else Tin.HEAT_DOWN
			for step in range(absi(trial.heat - temperature)):
				check(trial.apply(direction), "The recipe's required temperature must be reachable")
			check(trial.apply(Tin.REFINE), "The recipe's current step must be available")
		check(trial.won and not trial.lost and trial.turns <= Tin.TURN_LIMIT, "Every seeded recipe must have a winning line")


func check_owned_brew_recipe() -> void:
	var run := Run.new(Awakening.profile_for("huyen-bao", 12), 0)
	run.phase = "ford_workshop"
	run.wine_sets = 1
	run.owned_gu["brew"] = 1
	check(not run.commit_book_action("refine_owned_brew") and run.wine_sets == 1 and run.owned_gu.brew == 1,
		"One Tửu Trùng and the wine cannot complete the recipe")
	run.owned_gu.brew = Run.BREW_BUNDLE
	run.phase = "battle"
	check(not run.commit_book_action("refine_owned_brew"), "The recipe must be sealed during a fight")
	run.phase = "kennel_ready"
	run.floor = Run.KENNEL_FLOOR
	check(not run.commit_book_action("refine_owned_brew") and run.wine_sets == 1 and run.owned_gu.brew == Run.BREW_BUNDLE,
		"The recipe must remain sealed in Khuyển Vương")


func check_owned_art_slots() -> void:
	var profile := Awakening.profile_for("huyen-bao", 12)
	for starter: String in Gu.STARTERS:
		for recipe: String in ["moon_edge", "white_jade"]:
			var run := Run.new(profile, 0)
			run.moon_link_known = true
			run.white_light_known = true
			run.owned_gu["small_light"] = 1
			check(run.art_for_build(recipe).is_empty(), "The workshop loan must not unlock an art")
			run.owned_gu["moon_edge"] = 1
			run.owned_gu["white_jade"] = 1
			run.owned_gu["small_light"] = 0
			check(run.art_for_build(recipe).is_empty(), "The art must still require Tiểu Quang after learning")
			run.owned_gu["small_light"] = 1
			var stock := run.owned_gu.duplicate()
			run.phase = "ambush_workshop"
			check(run.equip_build(recipe, starter)
				and run.battle.moon_link_equipped == (recipe == "moon_edge")
				and run.battle.white_light_equipped == (recipe == "white_jade")
				and run.battle.starter_gu == starter and run.owned_gu == stock,
				"One owned art must fit alongside any starter without spending the support Gu")

	var shot := Rules.new({"refined_gu": "moon_edge", "moon_link": true, "wolf_hp": 100,
		"wolf_cell": 22, "rocks": [], "qi": Gu.MOON_LINK_COST - 1})
	shot.hero = 17
	check(shot.unavailable("moon_link").contains("chân nguyên"), "Liên Nguyệt must require its full cost")
	shot.qi = Gu.MOON_LINK_COST
	check(shot.preview_action("moon_link").get("dealt", -1) == Gu.MOON_LINK_DAMAGE, "Liên Nguyệt must reach five tiles")
	shot.wolf = 23
	check(shot.unavailable("moon_link").contains("ngoài tầm") and shot.unavailable("moon_edge").is_empty(),
		"Nguyệt Mang must retain its longer range")
	shot.moon_mark = true
	check(shot.preview_action("moon_edge").get("dealt", -1) == Gu.MOON_LINK_DAMAGE and Gu.MOON_EDGE_COST < Gu.MOON_LINK_COST,
		"A marked Nguyệt Mang must retain its cheaper follow-up")

	for kit: Array in [["moon_edge", "moon_link", Gu.MOON_LINK_COST], ["white_jade", "white_light", Gu.WHITE_LIGHT_COST]]:
		var options := {"refined_gu": kit[0], "moon_link": true, "white_light": true,
			"wolf_cell": 18, "qi": kit[2] - 1, "relic": "pulse_pearl", "rocks": []}
		var battle := Rules.new(options)
		check(battle.take_turn(kit[1]).has("error") and battle.qi == kit[2] - 1 and battle.relic_ready,
			"Châu Hoàn Nguyên must not pay an up-front cost")
		battle.qi = kit[2]
		battle.take_turn(kit[1])
		check(battle.qi == Goods.PULSE_PEARL_QI and not battle.relic_ready
			and battle.take_turn(kit[1]).has("error"), "An equipped art must pay and receive the one-time refund once")
		options.tactic = "kennel"
		battle = Rules.new(options)
		check(battle.unavailable(kit[1]).contains("phong cấm") and not Pack.new().unavailable(kit[1]).is_empty(),
			"Khuyển Vương must keep the two outside arts sealed")


func check_white_light_balance() -> void:
	var options := {"refined_gu": "white_jade", "starter_gu": "jade_skin", "jade_skin": true,
		"revised_ward": true, "white_light": true, "wolf_cell": 18, "qi": 3}
	var skills := ["guard", "jade_skin", "white_jade", "white_light"]
	var scenarios := [[8, 8, [11, 11, 8, 0]], [18, 18, [24, 31, 25, 18]],
		[24, 0, [8, 19, 13, 15]], [24, 8, [16, 27, 21, 15]]]
	for scenario: Array in scenarios:
		for index in range(skills.size()):
			var battle := Rules.new(options)
			battle.intent = {"kind": "strike", "name": "Đòn thử", "damage": scenario[0], "cells": [battle.hero]}
			var peek := battle.preview_action(skills[index])
			check(not peek.has("error") and not battle.white_light_used and battle.hp == Rules.MAX_HP,
				"Preview must leave the shield, charge and HP unspent")
			var initial := battle.take_turn(skills[index])
			var continued := 0
			if scenario[1] > 0:
				battle.intent = {"kind": "strike", "name": "Đòn thử", "damage": scenario[1], "cells": [battle.hero]}
				continued = battle.take_turn("strike").hero_damage
			check(initial.hero_damage + continued == scenario[2][index],
				"Defense balance drifted for %s against %s" % [skills[index], scenario.slice(0, 2)])
			if skills[index] == "white_light":
				check(not battle.counter_ready and not battle.unavailable("white_light").is_empty()
					and (scenario[1] == 0 or battle.white_light_hits == 0),
					"The art must expire after two contacts and cannot grant the ward counter or repeat")
	var battle := Rules.new(options)
	battle.intent = {"kind": "recover", "name": "Hồi thế", "damage": 0, "cells": []}
	battle.take_turn("jade_skin")
	check(battle.unavailable("white_light").contains("phòng hộ"), "The art must not stack onto a current ward")
	battle = Rules.new(options)
	battle.qi = 2
	check(battle.unavailable("white_light").contains("chân nguyên"), "The art must require its full cost")
	battle.qi = 3
	for action: String in ["white_light", "guard", "guard"]:
		battle.intent = {"kind": "recover", "name": "Hồi thế", "damage": 0, "cells": []}
		battle.take_turn(action)
	check(battle.white_light_used and battle.white_light_hits == 0 and battle.jade_turns == 0,
		"Unused blocks must expire after three turns, including the cast turn")


func exercise() -> void:
	var data := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(data)
	path = data.path_join("run-flow-%d.json" % Time.get_ticks_usec())
	check_gu_and_tactics()
	check_owned_brew_recipe()
	check_tin_recipes()
	check_owned_art_slots()
	check_white_light_balance()
	check_third_save()
	check_rank_two_gu()
	check_ford_gu()
	check_ambush_kit()
	check_relic_rules()
	check_nodo_targets()
	check_kennel_rules()
	check_pack_rules()
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
		print("Godot run passed: legacy journals, Rank III boss, Tam Xoa camp, lunge replay, both hide routes, Gu ledger, owned Gu recipes, both arts, four Khuyển Vương trials and the Tín Vương duel")
	quit(1 if failed else 0)
