extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const ZiWu = Rules.ZiWu
const Setup = preload("res://battle_setup.tscn")
const MapScene = preload("res://exploration_map.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(result: bool, message: String) -> void:
	checks += 1
	if not result:
		failures += 1
		push_error(message)

func new_battle(team: Array = [Rules.ZIWU_ID]) -> DemoBattleRules:
	var rules := Rules.new()
	rules.start(31, Rules.TRAINING_ENCOUNTER, false, false, team)
	return rules

func test_resources() -> void:
	var rules := new_battle()
	var hero := rules.heroes[0]
	check(hero.hp == 25 and hero.speed_min == 7 and hero.speed_max == 11, "burst stats")
	check(ZiWu.clash_bonus(hero, 0) == 2 and ZiWu.clash_bonus(hero, 2) == 0, "empty teammate slots strengthen solo")
	hero.insulation = 2
	check(ZiWu.clash_bonus(hero, 0) == 3, "each two layers add one clash point")
	var intercept := rules.hand.find(ZiWu.LONE_INTERCEPT)
	check(rules.assign(intercept, 0, 0, true).is_empty() and hero.insulation == 0, "enhancement reserves two layers")
	rules.cancel(0)
	check(hero.insulation == 2 and hero.enhanced_slot == -1, "cancel refunds layers")
	check(rules.assign(intercept, 0, 0, true).is_empty(), "enhanced intercept can be assigned again")
	rules.lock_and_resolve()
	check(hero.insulation == 1 and hero.next_clash_bonus == 2, "enhanced win primes next clash and solo win gains one layer")
	check(ZiWu.on_clash_win(hero, 0, rules.turn) == 0, "solo gain is once per round")
	check(ZiWu.add_insulation(hero, 9) == 4 and hero.insulation == 5, "absolute cap")
	rules.next_round()
	check(not hero.clash_gain_used and hero.enhanced_slot == -1, "round resets the gain and enhancement quotas")

func test_friendly() -> void:
	var rules := new_battle([Rules.ZIWU_ID, Rules.WEAVER_ID, Rules.ASH_ID])
	var hero := rules.heroes[0]
	var backstab := rules.hand.find(ZiWu.BACKSTAB)
	var cold := rules.hand.find(ZiWu.COLD_EDGE)
	hero.hp = 19
	rules.heroes[1].hp = 15
	rules.heroes[1].shield = 50
	check(not rules.can_assign(backstab, 0, 0, false, true).is_empty(), "friendly mode cannot target self")
	check(rules.assign(backstab, 0, 1, false, true).is_empty(), "explicit friend targeting")
	check(not rules.hero_slots[0].targeted, "friendly assignment does not pair with the enemy")
	var events := rules.lock_and_resolve()
	check(events.any(func(e: Dictionary) -> bool: return e.type == "strike" and e.get("friendly", false) and e.damage == 15 and e.blocked == 0), "friendly event identifies attacker and bypasses shield")
	check(rules.heroes[1].hp == 0 and hero.hp == 24 and hero.insulation == 2 and hero.shield == 5, "exact threshold execution and benefits")
	check(rules.cost == 31 and rules.heroes[2].hp == 48, "ally defeat refund and untouched other heroes")
	rules.next_round()
	rules.heroes[2].hp = 12
	rules.heroes[2].shield = 50
	check(rules.assign(cold, 0, 2, false, true).is_empty(), "cold edge can attack a teammate")
	rules.lock_and_resolve()
	check(rules.heroes[2].hp == 12 and rules.heroes[2].shield < 50, "cold edge damage respects shield")
	rules.next_round()
	check(rules.assign(backstab, 0, 2, false, true).is_empty(), "queue execution at 12 HP")
	rules.heroes[2].hp = 16
	rules.heroes[2].shield = 50
	rules.lock_and_resolve()
	check(rules.heroes[2].hp == 16 and rules.heroes[2].shield < 50, "healing above threshold before execution prevents the execute")

func test_ultimate() -> void:
	var rules := new_battle([Rules.ZIWU_ID, Rules.WEAVER_ID, Rules.ASH_ID])
	var hero := rules.heroes[0]
	var ending := rules.hand.find(ZiWu.MERIDIAN_SLASH)
	check("还差 3 层" in rules.can_assign(ending, 1, 0), "full lineup shows ultimate gate")
	hero.insulation = 3
	hero.hp = 4
	check(rules.assign(ending, 1, 0).is_empty(), "three layers unlock ultimate")
	check("已安排的终符" in rules.can_assign(rules.hand.find(ZiWu.LONE_INTERCEPT), 0, 0, true), "enhancement cannot invalidate a queued ultimate")
	var events := rules.lock_and_resolve()
	var strike := events.filter(func(e: Dictionary) -> bool: return e.type == "strike" and e.allied)
	check(strike.size() == 1 and strike[0].damage in [16, 21, 26], "ultimate converts three layers into six damage without duplicate passive damage")
	check(hero.insulation == 0 and hero.hp == 1 and hero.blocked_gain_turn == 2, "ultimate clears layers, retains one HP, and pauses generation")
	rules.next_round()
	rules.heroes[1].hp = 0
	rules.heroes[2].hp = 0
	check(ZiWu.on_clash_win(hero, 0, rules.turn) == 0, "next-round gain is paused")
	check(rules.can_assign(ending, 1, 0).is_empty(), "solo ultimate needs no layers")
	var failed := new_battle()
	var failed_hero := failed.heroes[0]
	failed_hero.hp = 1000
	failed_hero.insulation = 3
	failed.enemy_slots[0].key = Rules.ZiXi.ALMOST_SURE
	failed.assign(failed.hand.find(ZiWu.MERIDIAN_SLASH), 1, 0)
	var target_hp := int(failed.enemies[0].hp)
	# Test-only penalty makes every coin outcome lose.
	failed_hero.next_clash_bonus = -20
	var failed_events := failed.lock_and_resolve()
	check(failed.enemies[0].hp == target_hp and failed_hero.insulation == 0 and failed_hero.blocked_gain_turn == 2, "ultimate loss still spends layers and pauses generation")
	check(failed_events.any(func(e: Dictionary) -> bool: return e.get("message", "").contains("损失 5 HP")), "ultimate loss still charges HP")

func test_cold_edge_loss() -> void:
	var rules := new_battle()
	var hero := rules.heroes[0]
	hero.hp = 1000
	hero.next_clash_bonus = -20
	rules.enemy_slots[0].key = Rules.ZiXi.ALMOST_SURE
	rules.assign(rules.hand.find(ZiWu.COLD_EDGE), 0, 0)
	rules.lock_and_resolve()
	check(hero.vulnerable_turn == 2, "cold edge loss schedules vulnerability")
	rules.next_round()
	var events: Array[Dictionary] = []
	check(rules._deal_hit(events, false, 0, 0, 5, 1, 2) == 7, "first enemy attack segment applies vulnerability")
	check(rules._deal_hit(events, false, 0, 0, 5, 2, 2) == 5, "later segments do not stack vulnerability")

func _run() -> void:
	test_resources()
	test_friendly()
	test_ultimate()
	test_cold_edge_loss()
	var setup = Setup.instantiate()
	root.add_child(setup)
	await process_frame
	setup.get_node("%ClearLineup").pressed.emit()
	for id in [Rules.ZIWU_ID, Rules.WEAVER_ID, Rules.ASH_ID]:
		setup.role_buttons[id].button_pressed = true
	setup.enemy_picker.select(Rules.TRAINING_ENCOUNTER)
	setup.launch.pressed.emit()
	await process_frame
	var ui = setup.active_battle
	check(ui.battle.heroes[0].name == "ZiWu" and ui.battle.hand.has(ZiWu.BACKSTAB), "ZiWu and cards launch from normal setup")
	check("绝缘 0/5" in ui.hand_view.role_summary.text, "HUD displays resource")
	ui._select_card(ui.battle.hand.find(ZiWu.MERIDIAN_SLASH))
	check("终符还差 3 层" in ui.hint.text, "selected ultimate explains its gate")
	ui.battle.heroes[0].insulation = 2
	ui._select_card(ui.battle.hand.find(ZiWu.LONE_INTERCEPT))
	check(ui.hand_view.enhance_toggle.visible and not ui.hand_view.enhance_toggle.disabled, "available enhancement in the hand")
	ui.battle.heroes[1].hp = 12
	ui.battle.heroes[1].shield = 6
	ui._refresh(ui.battle.snapshot())
	ui._select_card(ui.battle.hand.find(ZiWu.BACKSTAB))
	ui.friendly_button.pressed.emit()
	check(ui.friendly_panel.visible and ui.friendly_confirm.disabled, "choosing the attack mode alone cannot schedule it")
	ui.friendly_picker.select(1)
	ui.friendly_picker.item_selected.emit(1)
	check("无视护盾" in ui.friendly_detail.text and not ui.friendly_confirm.disabled, "choosing a wounded teammate displays execution warning")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://test-output")
		await RenderingServer.frame_post_draw
		var file := "res://test-output/ziwu-battle-%d.png" % root.size.x
		check(root.get_texture().get_image().save_png(file) == OK and root.get_visible_rect().encloses(ui.friendly_panel.get_global_rect()), "friendly dialog renders entirely inside viewport")
	ui.friendly_confirm.pressed.emit()
	check(ui.battle.hero_slots[0].get("ally_target", -1) == 1, "confirm schedules the chosen teammate")
	if DisplayServer.get_name() != "headless":
		ui.speed = 4.0
		await ui._resolve()
		check(ui.battle.heroes[1].hp == 0 and ui.battle.heroes[0].insulation == 4, "animated resolution executes the selected friendly target")
	ui._cancel()
	ui._auto_plan()
	check(not ui.battle.hero_slots.any(func(slot: Dictionary) -> bool: return slot.has("ally_target")), "auto plan never attacks allies")
	setup.queue_free()
	await process_frame
	var world = MapScene.instantiate()
	root.add_child(world)
	await process_frame
	for node in world.run.map.nodes.values():
		if node.kind == ForestMapGraph.NodeKind.SHOP:
			world.run.position = node.id
			break
	world._handle_node_clicked(world.run.position)
	world.modal_shop_lineup_btn.pressed.emit()
	world.lineup_role_buttons[Rules.BLADE_ID].toggled.emit(false)
	world.lineup_role_buttons[Rules.ZIWU_ID].toggled.emit(true)
	world.lineup_save_btn.pressed.emit()
	check(world.run.lineup.has(Rules.ZIWU_ID) and world.run.deck.has(ZiWu.BACKSTAB), "shop saves ZiWu and the combat deck")
	world.queue_free()
	await process_frame
	print("ZIWU checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
