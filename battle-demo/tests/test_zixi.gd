extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")
const ZiXi = Rules.ZiXi

class FixedCoins extends "res://scripts/battle_rules.gd":
	var ally_heads := 0
	var enemy_bonus := 0

	func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
		var heads := mini(coins, ally_heads) if chance > 0.5 else 0
		return {"heads": heads, "value": maxi(0, base + heads * power + (0 if chance > 0.5 else enemy_bonus))}

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh() -> FixedCoins:
	var battle := FixedCoins.new()
	battle.start(73129, 0, false, true)
	set_attacks(battle)
	return battle

func set_attacks(battle: DemoBattleRules, active_ids: Array = [0, 3]) -> void:
	for slot in battle.enemy_slots:
		slot.active = slot.id in active_ids
		if slot.active:
			slot.key = "needle"
			slot.target = 1
			slot.speed = 6 if slot.id == 0 else 4

func play(battle: DemoBattleRules, key: String, slot: int, target: int, enhanced: bool = false) -> bool:
	return battle.assign(battle.hand.find(key), slot, target, enhanced).is_empty()

func hits_to(events: Array[Dictionary], target: int) -> int:
	var result := 0
	for event in events:
		if event.type == "strike" and event.allied and event.target == target:
			result += event.damage
	return result

func clashes(events: Array[Dictionary]) -> Array[Dictionary]:
	return events.filter(func(event: Dictionary) -> bool: return event.type == "clash")

func test_planning() -> void:
	var battle := fresh()
	var hero := battle.heroes[1]
	check(hero.hp == 50 and hero.speed_min == 3 and hero.speed_max == 5, "ZiXi HP and speed match approved preview")
	check(battle.hand.has(ZiXi.ALMOST_SURE) and not battle.hand.has("all_in") and battle.hand.has("cover"), "ZiXi replaces only Long Blade")
	check(not play(battle, ZiXi.CENTRAL_LIMIT, 3, 0, true), "no enhancement below three layers")
	hero.metaphysics = 6
	check(play(battle, ZiXi.CENTRAL_LIMIT, 3, 0, true) and hero.metaphysics == 3 and battle.cost == 30, "declaration consumes layers and reserves cost")
	check(play(battle, ZiXi.CENTRAL_LIMIT, 3, 0, true) and hero.metaphysics == 3, "editing same enhancement does not spend twice")
	check(not play(battle, ZiXi.MARTINGALE, 5, 3, true) and hero.metaphysics == 3, "one enhancement even with six starting layers")
	check(not play(battle, ZiXi.CENTRAL_LIMIT, 3, 1, true) and hero.metaphysics == 3, "invalid replacement preserves prior choice")
	battle.cancel(3)
	check(hero.metaphysics == 6 and hero.enhanced_slot == -1 and battle.reserved_cost() == 0, "cancelling returns layers and cost reservation")
	check(play(battle, ZiXi.MARTINGALE, 5, 3, true), "can reserve another card after cancellation")
	check(play(battle, ZiXi.MARTINGALE, 5, 3) and hero.metaphysics == 6, "replacing with normal use returns layers")
	battle.enemy_slots[0].target = 0
	check(not play(battle, ZiXi.CENTRAL_LIMIT, 3, 0), "a faster attack aimed at another ally cannot be intercepted")
	check(not play(battle, ZiXi.CENTRAL_LIMIT, 0, 3), "other allies cannot use ZiXi cards")

func test_gain() -> void:
	var battle := fresh()
	var hero := battle.heroes[1]
	for round_index in 3:
		set_attacks(battle)
		play(battle, ZiXi.CENTRAL_LIMIT, 3, 0)
		play(battle, ZiXi.MARTINGALE, 5, 3)
		var events := battle.lock_and_resolve()
		check(hero.metaphysics == mini(6, (round_index + 1) * 3), "winning two clashes gains at most three stacks per round and six total")
		if round_index == 0:
			var rolls := clashes(events)
			check(rolls[2].left == 16 and hero.next_clash.is_empty(), "center's +1 is used by the next clash only")
		battle.next_round()
		check(hero.round_gain == 0, "the gain budget resets each round")
	hero.causality = 3
	hero.no_margin_round = battle.turn
	hero.metaphysics = 0
	hero.next_clash[ZiXi.CENTRAL_LIMIT] = 1
	hero.next_clash[ZiXi.CONVERGENCE] = 2
	set_attacks(battle, [0])
	play(battle, ZiXi.CENTRAL_LIMIT, 3, 0, true)
	check(not battle.hero_slots[3].active, "zero layers prevents reservation")
	play(battle, ZiXi.CENTRAL_LIMIT, 3, 0)
	var events := battle.lock_and_resolve()
	var rolls := clashes(events)
	check(rolls[0].left == 17 and rolls[0].right == 0, "causality changes both scores and different next-clash effects add")
	check(hero.metaphysics == 1 and hero.next_clash.size() == 1 and hero.next_clash[ZiXi.CENTRAL_LIMIT] == 1, "suppressed margin pays only the basic layer")
	hero = ZiXi.create_unit()
	check(ZiXi.win_clash(hero, ZiXi.CENTRAL_LIMIT, 4, 1) == 1 and ZiXi.win_clash(hero, ZiXi.CENTRAL_LIMIT, 5, 1) == 2, "margin bonus begins exactly at five points")

func test_coins() -> void:
	var battle := fresh()
	var hero := battle.heroes[1]
	hero.metaphysics = 3
	set_attacks(battle, [0])
	play(battle, ZiXi.CONVERGENCE, 3, 0, true)
	var events := battle.lock_and_resolve()
	var rolls := clashes(events)
	check(rolls[0].left_heads == 1 and rolls[1].left_heads == 0, "only the skill's first tail flips")
	check(hits_to(events, 0) == 2 and hero.causality == 1, "clash flip is not reused during attack")
	check(hero.next_clash[ZiXi.CONVERGENCE] == 2, "convergence grants +2 to the next clash")
	battle = fresh()
	hero = battle.heroes[1]
	hero.metaphysics = 3
	battle.ally_heads = 3
	set_attacks(battle, [0])
	play(battle, ZiXi.CONVERGENCE, 3, 0, true)
	check(hits_to(battle.lock_and_resolve(), 0) == 14, "three natural heads give the extra three damage")
	battle = fresh()
	hero = battle.heroes[1]
	hero.metaphysics = 3
	hero.causality = 3
	battle.ally_heads = 2
	set_attacks(battle, [0])
	play(battle, ZiXi.CENTRAL_LIMIT, 3, 0, true)
	events = battle.lock_and_resolve()
	check(clashes(events)[0].left == 20 and hits_to(events, 0) == 11 and hero.causality == 3, "enhancement affects center's clash and damage, causality stays capped")

func test_shield() -> void:
	var battle := fresh()
	var hero := battle.heroes[1]
	hero.metaphysics = 3
	battle.enemy_bonus = 60
	set_attacks(battle, [0])
	play(battle, ZiXi.MARTINGALE, 5, 0, true)
	var events := battle.lock_and_resolve()
	var strike_index := events.find_custom(func(event: Dictionary) -> bool: return event.type == "strike")
	var shield_index := events.find_custom(func(event: Dictionary) -> bool: return event.type == "guard")
	check(strike_index >= 0 and shield_index > strike_index and events[strike_index].blocked == 0, "loss shield is granted after incoming damage")
	check(hero.hp < 50 and hero.shield == 4 and hero.causality == 1 and hero.next_clash[ZiXi.MARTINGALE] == 3, "enhanced loss grants shield, next bonus and causality")
	battle.next_round()
	check(hero.shield == 4, "remaining loss shield carries into the following round")
	set_attacks(battle, [])
	events.clear()
	hero.shield += 3
	battle._deal_hit(events, false, 0, 1, 5, 1, 1)
	check(hero.shield == 2 and hero.shield_until[battle.turn] == 2, "damage consumes the carried shield")
	battle.lock_and_resolve()
	battle.next_round()
	check(hero.shield == 0 and hero.shield_until.is_empty(), "remaining shield expires after next round")
	battle = fresh()
	hero = battle.heroes[1]
	hero.metaphysics = 3
	set_attacks(battle, [0])
	play(battle, ZiXi.MARTINGALE, 5, 0, true)
	events = battle.lock_and_resolve()
	check(hero.shield == 12 and hits_to(events, 0) == 0, "winning enhanced Martingale grants 12 shield and no damage")
	battle.next_round()
	set_attacks(battle, [0])
	play(battle, ZiXi.MARTINGALE, 5, 0)
	battle.lock_and_resolve()
	check(hero.shield == 20, "normal Martingale adds eight while the older shield is still active")
	battle.next_round()
	check(hero.shield == 8, "each shield grant expires separately")

func test_blast() -> void:
	var battle := fresh()
	var hero := battle.heroes[1]
	hero.metaphysics = 3
	hero.causality = 2
	battle.ally_heads = 2
	set_attacks(battle, [0])
	play(battle, ZiXi.ALMOST_SURE, 4, 0, true)
	var events := battle.lock_and_resolve()
	check(hits_to(events, 0) == 38 and hits_to(events, 1) == 21, "bomb uses new third causality layer; single hit uses original two")
	check(hero.causality == 0 and hero.metaphysics == 2 and hero.no_margin_round == 2, "winning bomb clears causality after learning and suppresses next margin")
	battle = fresh()
	hero = battle.heroes[1]
	hero.metaphysics = 3
	hero.causality = 1
	battle.enemy_bonus = 60
	set_attacks(battle, [0])
	play(battle, ZiXi.ALMOST_SURE, 4, 0, true)
	events = battle.lock_and_resolve()
	check(hits_to(events, 1) == 0 and hero.causality == 2 and hero.metaphysics == 0 and hero.no_margin_round == 0, "losing enhancement gives causality but cannot bomb or refund layers")
	battle = fresh()
	hero = battle.heroes[1]
	hero.metaphysics = 3
	hero.hp = 1
	play(battle, ZiXi.ALMOST_SURE, 4, 3, true)
	events = battle.lock_and_resolve()
	check(hero.hp == 0 and hero.causality == 0 and hero.metaphysics == 0 and hits_to(events, 1) == 0, "earlier lethal attack cancels the unexecuted enhancement")

func _run() -> void:
	test_planning()
	test_gain()
	test_coins()
	test_shield()
	test_blast()
	var scene := BattleScene.instantiate()
	root.add_child(scene)
	scene.sound.enabled = false
	scene.zixi_button.pressed.emit()
	var deck = scene.hand_view
	check(deck.visible_indices.size() == 4 and deck.role_summary.text.contains("因果律 0/3"), "ZiXi preset exposes the four cards and resources")
	var chosen: int = scene.battle.hand.find(ZiXi.CENTRAL_LIMIT)
	scene._select_card(chosen)
	check(deck.enhance_toggle.visible and deck.enhance_toggle.disabled, "zero stacks disable enhancement")
	scene.battle.heroes[1].metaphysics = 3
	scene._refresh(scene.battle.snapshot())
	check(not deck.enhance_toggle.disabled and deck.cards[chosen].can_enhance, "ready card and toggle show enhancement availability")
	deck.enhance_toggle.button_pressed = true
	check(deck.cards[chosen].enhanced and scene.hint.text.contains("正态近似"), "toggle previews the enhanced effect")
	scene._assign()
	check(scene.battle.hero_slots[3].enhanced and deck.role_summary.text.contains("超形上学 0/6"), "assigning enhancement updates resource display")
	check(not deck.cards[scene.battle.hand.find(ZiXi.MARTINGALE)].can_enhance, "an enhancement assigned to attack disables the defense badge")
	scene._cancel()
	check(deck.role_summary.text.contains("超形上学 3/6") and not deck.cards[chosen].enhanced, "cancelling restores UI state")
	if "--zixi-preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		deck.enhance_toggle.button_pressed = true
		await process_frame
		await RenderingServer.frame_post_draw
		var width := DisplayServer.window_get_size().x
		var saved := root.get_texture().get_image().save_png("res://test-output/zixi-runtime-%d.png" % width)
		check(saved == OK and scene.stage.zixi_texture != null, "real viewport shows the local portrait")
	scene.queue_free()
	await process_frame
	print("ZIXI checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
