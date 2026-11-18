extends SceneTree

const Setup = preload("res://battle_setup.tscn")
const Rules = preload("res://scripts/battle_rules.gd")
const SOLO_CARDS := ["probe", "all_in", "cover", "murder_doll", "yin_yang_orb", "zixi_central_limit"]
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var setup := Setup.instantiate()
	root.add_child(setup)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-output")
		_capture("setup")
	setup.get_node("%ClearLineup").pressed.emit()
	check(setup.launch.disabled and setup.members.is_empty(), "clear lineup disables battle")
	for id in SOLO_CARDS.size():
		setup.role_buttons[id].button_pressed = true
		var key: String = SOLO_CARDS[id]
		for card in Rules.available_cards([id]):
			setup._toggle_card(card == key, card)
		setup.launch.pressed.emit()
		var ui: Control = setup.active_battle
		if ui == null:
			check(false, "solo battle opens")
			continue
		ui.sound.enabled = false
		await process_frame
		var battle: DemoBattleRules = ui.battle
		check(battle.heroes.size() == 1 and battle.hero_slots.size() == 3, "only selected hero and slots")
		check(battle.heroes[0].character_id == id and battle.hand == [key], "solo identity and selected deck")
		check(ui.hand_view.visible_indices.size() == 1 and not ui.hand_view.hero_buttons[1].visible, "solo card and roster view")
		for enemy in battle.enemy_slots:
			if enemy.active and enemy.category != 2:
				check(enemy.target == 0, "enemy targets solo hero")
		ui._select_card(0)
		var target := 0
		for enemy in battle.enemy_slots:
			if battle.can_assign(0, ui.selected_slot, enemy.id).is_empty():
				target = enemy.id
				break
		check(battle.assign(0, ui.selected_slot, target).is_empty(), "identity can use exclusive card")
		if DisplayServer.get_name() != "headless" and id == Rules.ZIXI_ID:
			ui._refresh(battle.snapshot())
			await RenderingServer.frame_post_draw
			_capture("solo")
		var events := battle.lock_and_resolve()
		check(not events.is_empty() and not battle.can_assign(0, ui.selected_slot, target).is_empty(), "solo combat resolves")
		if battle.phase == "finished":
			battle.next_round()
			check(battle.hand == [key], "selected deck persists in next round")
		ui.setup_button.pressed.emit()
		await process_frame
		check(setup.page.visible and setup.members == [id], "back preserves setup")
		setup.role_buttons[id].button_pressed = false

	for id in [Rules.REIMU_ID, Rules.ZIXI_ID, Rules.SAKUYA_ID]:
		setup.role_buttons[id].button_pressed = true
	setup.role_buttons[Rules.ASH_ID].button_pressed = true
	check(setup.members == [Rules.REIMU_ID, Rules.ZIXI_ID, Rules.SAKUYA_ID], "lineup capped at three")
	for key in setup._selected_cards():
		setup._toggle_card(false, key)
	check(setup.launch.disabled, "empty deck cannot start")
	setup._toggle_card(true, "private_square")
	setup._toggle_card(true, "zixi_central_limit")
	setup._toggle_card(true, "yin_yang_orb")
	setup.enemy_picker.select(1)
	setup.launch.pressed.emit()
	var mixed: DemoBattleRules = setup.active_battle.battle
	check(mixed.enemies[0].kind == "priest", "encounter chosen in setup")
	check(mixed.sakuya_slot == 2 and mixed.reimu_slot == 0, "mixed identities track real slots")
	check(not mixed.can_assign(mixed.hand.find("private_square"), 2, 0).is_empty(), "same category does not bypass ownership")
	check(mixed.assign(mixed.hand.find("private_square"), 8, 0).is_empty(), "mixed Sakuya uses private square")
	check(mixed.assign(mixed.hand.find("yin_yang_orb"), 0, 0).is_empty(), "mixed Reimu uses exclusive attack")
	mixed.lock_and_resolve()
	setup.active_battle.setup_button.pressed.emit()
	await process_frame
	setup.get_node("%ClearLineup").pressed.emit()
	setup.role_buttons[Rules.ZIXI_ID].button_pressed = true
	setup._toggle_card(true, "needle")
	setup.enemy_picker.select(Rules.TRAINING_ENCOUNTER)
	setup.launch.pressed.emit()
	await process_frame
	var training: DemoBattleRules = setup.active_battle.battle
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	check(training.enemies.size() == 1 and training.enemies[0].hp == 99999, "training encounter has one high-HP dummy")
	check(training.enemy_slots[0].active and not training.enemy_slots[1].active and not training.enemy_slots[2].active, "training offers clash and unopposed targets")
	var events := training.lock_and_resolve()
	check(training.heroes[0].hp == 50 and not events.any(func(event: Dictionary) -> bool: return event.type == "strike"), "unopposed practice attack is harmless")
	training.next_round()
	check(training.assign(training.hand.find("zixi_central_limit"), 0, 0).is_empty(), "clash-required card can target the dummy")
	events = training.lock_and_resolve()
	check(events.any(func(event: Dictionary) -> bool: return event.type == "clash") and training.enemies[0].hp < 99999, "dummy takes real clash damage")
	training.next_round()
	var previous_hp: int = training.enemies[0].hp
	check(training.assign(training.hand.find("needle"), 0, 1).is_empty(), "idle slot accepts a solo attack")
	events = training.lock_and_resolve()
	check(not events.any(func(event: Dictionary) -> bool: return event.type == "clash") and training.enemies[0].hp < previous_hp, "dummy takes real unopposed damage")
	setup.queue_free()
	await process_frame
	print("BATTLE_SETUP failures=", failures)
	quit(1 if failures else 0)

func _capture(name: String) -> void:
	var width := DisplayServer.window_get_size().x
	check(root.get_texture().get_image().save_png("res://test-output/lineup-%s-%d.png" % [name, width]) == OK, "screenshot saved")
