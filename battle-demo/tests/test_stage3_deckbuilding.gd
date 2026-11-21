extends SceneTree

const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const CardPool = preload("res://scripts/card_pool.gd")
const MapScene = preload("res://exploration_map.tscn")
const MainScene = preload("res://main.tscn")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("STAGE3_FAIL: " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_starter_deck_and_limits()
	_test_post_battle_draft_and_skip()
	_test_shop_card_buy_and_remove()
	_test_duplicate_copies_and_flex_unopposed_combat()
	await _test_ui_integration()
	print("STAGE3_DECKBUILDING checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_starter_deck_and_limits() -> void:
	var map = ForestRandomGenerator.generate(301)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 301)

	check(run.deck.size() == 10, "3-hero default run starts with balanced 10-card starter deck (got %d)" % run.deck.size())
	check(CardPool.count_copies(run.deck, "guard") == 2, "Starter deck has 2x guard")
	check(run.deck.has("cleave") and run.deck.has("ember"), "Starter deck has cleave and ember")
	check(run.deck.has("probe") and run.deck.has("exploit") and run.deck.has("steady_edge") and run.deck.has("all_in") and run.deck.has("cover") and run.deck.has("support_strike"), "Starter deck includes each hero's 2 signature cards")
	check(not run.deck.has("nova") and not run.deck.has("shatter"), "Starter deck does not start with rare ultimates")

	# 2-hero custom lineup -> 4 neutral + 4 hero starters = 8 cards
	var run2 = ForestRun.new()
	run2.initialize(map, 0, [], [], 302, [DemoBattleRules.ASH_ID, DemoBattleRules.ZIXI_ID])
	check(run2.deck.size() == 8 and run2.deck.has("zixi_central_limit") and run2.deck.has("zixi_convergence"), "2-hero custom run gets 8-card starter deck")

	# Rarity copy caps: common=3, uncommon=2, rare=1
	var test_deck: Array[String] = ["needle", "needle", "needle"]
	check(not CardPool.can_add_card(test_deck, "needle").ok, "Common card capped at 3 copies")
	test_deck = ["cleave", "cleave"]
	check(not CardPool.can_add_card(test_deck, "cleave").ok, "Uncommon card capped at 2 copies")
	test_deck = ["nova"]
	check(not CardPool.can_add_card(test_deck, "nova").ok, "Rare card capped at 1 copy")

	# Deck capacity 5..22
	var full_deck: Array[String] = []
	for _i in CardPool.MAX_DECK_SIZE:
		full_deck.append("ember")
	check(not CardPool.can_add_card(full_deck, "steady").ok, "Deck capped at MAX_DECK_SIZE cards")
	var min_deck: Array[String] = ["needle", "needle", "ember", "guard", "guard"]
	check(not CardPool.can_remove_card(min_deck, 0).ok, "Deck cannot be trimmed below 5 cards")

func _test_post_battle_draft_and_skip() -> void:
	var map = ForestRandomGenerator.generate(303)
	var run_a = ForestRun.new()
	var run_b = ForestRun.new()
	run_a.initialize(map, 0, [], [], 303)
	run_b.initialize(map, 0, [], [], 303)

	run_a.in_battle = true
	run_b.in_battle = true
	run_a.apply_battle_result(true, run_a.party_hp, run_a.carried_cost)
	run_b.apply_battle_result(true, run_b.party_hp, run_b.carried_cost)

	check(run_a.pending == "card_reward" and run_a.pending_card_rewards.size() == 3, "Battle victory generates 3-choose-1 card reward")
	check(run_a.pending_card_rewards == run_b.pending_card_rewards, "Same seed yields deterministic 3-choose-1 card choices")
	check(not run_a.end_turn(), "Cannot end turn while card reward is pending")

	# Claim card 0 on run_a
	var picked_key: String = run_a.pending_card_rewards[0]
	var claim_res: Dictionary = run_a.claim_card_reward(0)
	check(claim_res.ok and run_a.deck.size() == 11 and run_a.deck[10] == picked_key, "Claiming reward adds card to deck")
	check(run_a.pending.is_empty() and run_a.pending_card_rewards.is_empty(), "Pending cleared after claim")

	# Skip reward on run_b -> +2 cost
	var cost_before: int = run_b.carried_cost
	var skip_res: Dictionary = run_b.skip_card_reward()
	check(skip_res.ok and run_b.carried_cost == cost_before + CardPool.SKIP_REWARD_COST, "Skipping reward grants +2 cost")
	check(run_b.deck.size() == 10 and run_b.pending.is_empty(), "Skipping keeps deck unchanged and clears pending")

func _test_shop_card_buy_and_remove() -> void:
	var map = ForestRandomGenerator.generate(304)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 304)
	for node in map.nodes.values():
		if node.kind == ForestMapGraph.NodeKind.SHOP:
			run.position = node.id
			break
	run.enter_node()
	run.carried_cost = 30
	var offers := run.ensure_shop_offers()
	check(offers.size() == 3, "Shop generates 3 card offers")

	var price0: int = int(offers[0].price)
	var key0: String = String(offers[0].key)
	var buy_res: Dictionary = run.shop_buy_card(0)
	check(buy_res.ok and run.carried_cost == 30 - price0 and run.deck.size() == 11 and run.deck.back() == key0, "Buying shop card deducts cost and adds card")
	check(not run.shop_buy_card(0).ok, "Same shop card slot cannot be bought twice")

	var cost_before_rem: int = run.carried_cost
	var rem_res: Dictionary = run.shop_remove_card(0)
	check(rem_res.ok and run.carried_cost == cost_before_rem - CardPool.REMOVE_CARD_COST and run.deck.size() == 10, "Shop card removal costs 5 and shrinks deck")
	check(not run.shop_remove_card(0).ok, "Shop removal limited to once per shop")

func _test_duplicate_copies_and_flex_unopposed_combat() -> void:
	var deck := ["needle", "needle", "ember", "guard", "guard", "probe"]
	var base_b := DemoBattleRules.new()
	base_b.start(555, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"flex_attack_in_ultimate": true, "unopposed_bonus": false})
	check(base_b.hand.size() == 6 and base_b.hand[0] == "needle" and base_b.hand[1] == "needle", "Duplicate card copies preserved in battle hand")

	# Flex ultimate slot: hero 0 puts needle#0 in 攻 (slot 0) AND needle#1 in 大 (slot 1)!
	check(base_b.assign(0, 0, 0).is_empty(), "Assign 1st needle to attack slot")
	check(base_b.assign(1, 1, 1).is_empty(), "Assign 2nd needle to ultimate slot via flex_attack_in_ultimate")

	# Compare unopposed solo attack damage with vs without unopposed_bonus
	var plain := DemoBattleRules.new()
	plain.start(777, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"flex_attack_in_ultimate": true, "unopposed_bonus": false})
	var boosted := DemoBattleRules.new()
	boosted.start(777, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"flex_attack_in_ultimate": true, "unopposed_bonus": true})

	# Force enemy slot 0 active targeting hero 0 (speed 3); hero 0 (speed 7) clashes it, hero 1 (speed 5) flanks it!
	for b in [plain, boosted]:
		for es in b.enemy_slots:
			es.active = es.id == 0
		b.enemy_slots[0].target = 0
		b.enemy_slots[0].speed = 3
		b.hero_slots[0].speed = 7
		b.hero_slots[3].speed = 5
		b.assign(0, 0, 0) # Hero 0 clashes enemy 0
		check(b.predicted_clash_hero(0, 3) == 0, "predicted_clash_hero identifies Hero 0 as clash holder for Hero 1 flanking check")
		b.assign(1, 3, 0) # Hero 1 flanks enemy 0 unopposed!

	var ev_plain := plain.lock_and_resolve()
	var ev_boost := boosted.lock_and_resolve()
	check(ev_boost.any(func(e: Dictionary) -> bool: return e.type == "unopposed" and int(e.bonus) == DemoBattleRules.UNOPPOSED_BONUS), "Unopposed flanking strike emits unopposed event (+2)")
	var dmg_plain := 0
	for e in ev_plain:
		if e.type == "strike" and e.allied and int(e.source) == 1:
			dmg_plain += int(e.damage)
	var dmg_boost := 0
	for e in ev_boost:
		if e.type == "strike" and e.allied and int(e.source) == 1:
			dmg_boost += int(e.damage)
	check(dmg_boost == dmg_plain + DemoBattleRules.UNOPPOSED_BONUS, "Unopposed flanking strike deals +2 extra damage (%d vs %d)" % [dmg_boost, dmg_plain])

func _test_ui_integration() -> void:
	# 1. Exploration map card reward & deck viewer UI
	var m = MapScene.instantiate()
	root.add_child(m)
	await process_frame
	check(m.run.deck.size() == 10 and "10/22" in m.deck_viewer_button.text, "Deck viewer button shows initial 10/22 count")
	m.deck_viewer_button.pressed.emit()
	check(m.deck_viewer_panel.visible and m.deck_viewer_grid.get_child_count() == 10, "Deck viewer modal displays all 10 starter cards")
	m.deck_viewer_close_btn.pressed.emit()
	check(not m.deck_viewer_panel.visible, "Deck viewer closes cleanly")

	# Trigger post-battle return victory -> opens 3-choose-1 modal
	m.run.in_battle = true
	m.run.current_encounter = 0
	m._start_battle(0)
	await process_frame
	check(m.battle.battle.deck_cycle_enabled and m.battle.battle.hand.size() == DemoBattleRules.DEFAULT_DRAW_COUNT, "Exploration battle enables deck cycle and draws 6-card hand")
	check(m.battle.hand_view.cards.size() == DemoBattleRules.DEFAULT_DRAW_COUNT, "RoleHand renders all 6 drawn card instances")
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	check(m.card_reward_panel.visible and m.card_reward_container.get_child_count() == 3, "Returning from victory opens 3-choose-1 card reward modal")
	var cost_pre_skip: int = m.run.carried_cost
	m.card_reward_skip_btn.pressed.emit()
	check(not m.card_reward_panel.visible and m.run.carried_cost == cost_pre_skip + 2, "Skip button closes reward modal and grants +2 cost")
	m.queue_free()
	await process_frame

	# 2. Planning UI flanking tag & flex ultimate slot check
	var ui = MainScene.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	await process_frame
	check(ui.battle.flex_attack_in_ultimate and ui.battle.unopposed_bonus_enabled, "Planning UI enables flex ultimate attack slot and unopposed bonus")
	for es in ui.battle.enemy_slots:
		es.active = es.id == 0
	ui.battle.enemy_slots[0].target = 0
	ui.battle.enemy_slots[0].speed = 3
	ui.battle.hero_slots[0].speed = 8
	ui.battle.hero_slots[3].speed = 5
	ui._select_card(ui.battle.hand.find("probe"))
	ui._slot_selected(false, 0)
	ui._assign()
	ui._slot_selected(true, 3)
	ui.hand_view.group_buttons[1].pressed.emit()
	ui._select_card(ui.battle.hand.find("ember"))
	var flank_g: Dictionary = ui._target_guidance(0)
	check(flank_g.valid and flank_g.get("kind", "") == "flank" and flank_g.get("tag", "") == "夹击", "Second ally aiming at already-clashed enemy slot shows 夹击 tag")
	ui.queue_free()
	await process_frame
