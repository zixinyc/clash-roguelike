extends SceneTree

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
		push_error("STAGE4_FAIL: " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_draw_discard_reshuffle_conservation()
	_test_slim_deck_and_determinism()
	_test_turn1_anti_brick_guarantee()
	await _test_battle_pile_ui_and_unified_hand()
	print("STAGE4_DECK_CYCLE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _collect_uids(b: DemoBattleRules) -> Array[String]:
	var uids: Array[String] = []
	for c in b.hand_instances:
		uids.append(String(c.uid))
	for c in b.draw_pile:
		uids.append(String(c.uid))
	for c in b.discard_pile:
		uids.append(String(c.uid))
	uids.sort()
	return uids

func _test_draw_discard_reshuffle_conservation() -> void:
	var deck: Array[String] = CardPool.build_starter_deck(DemoBattleRules.DEFAULT_LINEUP)
	check(deck.size() == 10, "Balanced starter deck has 10 cards")
	check(DemoBattleRules.UNOPPOSED_BONUS == 3, "Unopposed bonus tuned to +3 damage")

	var b := DemoBattleRules.new()
	b.start(404, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"deck_cycle": true, "draw_count": 6, "flex_attack_in_ultimate": true, "unopposed_bonus": true})

	var expected_uids: Array[String] = []
	for i in 10:
		expected_uids.append("card_%d" % i)
	expected_uids.sort()

	# Turn 1: 6 in hand, 4 in draw, 0 in discard
	check(b.hand.size() == 6 and b.draw_pile.size() == 4 and b.discard_pile.size() == 0, "Turn 1 draws 6/10 cards leaving 4 in draw pile")
	check(_collect_uids(b) == expected_uids, "Turn 1 conserves all 10 unique card instance IDs")

	# End Turn 1 -> Turn 2: 6 moved to discard, draws remaining 4 + reshuffles 6 + draws 2 -> hand=6, draw=4, discard=0!
	for es in b.enemy_slots:
		es.active = false
	b.lock_and_resolve()
	b.next_round()
	check(b.turn == 2 and b.hand.size() == 6 and b.draw_pile.size() == 4 and b.discard_pile.size() == 0, "Turn 2 reshuffles discard cleanly (hand=6, draw=4, discard=0)")
	check(_collect_uids(b) == expected_uids, "Turn 2 conserves all 10 unique card instance IDs with zero leaks or duplicates")

	# Turn 3 with a 15-card deck -> no reshuffle on Turn 2 (draw goes 15->9->3, discard=6), reshuffles on Turn 3!
	var big_deck: Array = deck.duplicate()
	big_deck.append_array(["needle", "steady", "observe", "follow", "nova"])
	var b2 := DemoBattleRules.new()
	b2.start(405, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, big_deck, false, [], [], {"deck_cycle": true, "draw_count": 6})
	check(b2.hand.size() == 6 and b2.draw_pile.size() == 9 and b2.discard_pile.size() == 0, "15-card deck Turn 1: hand=6 draw=9 discard=0")
	for es in b2.enemy_slots:
		es.active = false
	b2.lock_and_resolve()
	b2.next_round()
	check(b2.hand.size() == 6 and b2.draw_pile.size() == 3 and b2.discard_pile.size() == 6, "15-card deck Turn 2: hand=6 draw=3 discard=6")
	for es in b2.enemy_slots:
		es.active = false
	b2.lock_and_resolve()
	b2.next_round()
	check(b2.hand.size() == 6 and b2.draw_pile.size() == 9 and b2.discard_pile.size() == 0, "15-card deck Turn 3 reshuffles discard cleanly: hand=6 draw=9 discard=0")

func _test_slim_deck_and_determinism() -> void:
	# 5-card slim deck (< 6 draw_count) draws all 5 without hanging
	var slim := ["cleave", "ember", "guard", "probe", "cover"]
	var bs := DemoBattleRules.new()
	bs.start(406, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, slim, false, [], [], {"deck_cycle": true, "draw_count": 6})
	check(bs.hand.size() == 5 and bs.draw_pile.size() == 0 and bs.discard_pile.size() == 0, "5-card slim deck draws all 5 cards cleanly")

	# Same seed -> exact same draw order across turns
	var deck: Array[String] = CardPool.build_starter_deck(DemoBattleRules.DEFAULT_LINEUP)
	var a := DemoBattleRules.new()
	var c := DemoBattleRules.new()
	a.start(9001, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"deck_cycle": true})
	c.start(9001, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, deck, false, [], [], {"deck_cycle": true})
	check(a.snapshot() == c.snapshot(), "Same seed produces identical initial draw & piles")
	for b in [a, c]:
		for es in b.enemy_slots:
			es.active = false
		b.lock_and_resolve()
		b.next_round()
	check(a.snapshot() == c.snapshot(), "Same seed produces identical Turn 2 reshuffle")

func _test_turn1_anti_brick_guarantee() -> void:
	# Deck with 7 guards and 1 attack: Turn 1 must STILL guarantee at least 1 attack in opening hand!
	var heavy_guard := ["guard", "guard", "guard", "cover", "cover", "light_guard", "guard", "ember"]
	for s in 12:
		var b := DemoBattleRules.new()
		b.start(500 + s, 0, false, false, DemoBattleRules.DEFAULT_LINEUP, heavy_guard, false, [], [], {"deck_cycle": true, "draw_count": 6})
		var has_atk := b.hand.any(func(k: String) -> bool: return DemoBattleRules.SKILLS[k].kind == "attack")
		check(has_atk, "Turn 1 anti-brick guarantees an attack card (seed %d)" % (500 + s))

func _test_battle_pile_ui_and_unified_hand() -> void:
	var m = MapScene.instantiate()
	root.add_child(m)
	await process_frame
	m.run.in_battle = true
	m.run.current_encounter = 0
	m._start_battle(0)
	await process_frame
	var ui = m.battle
	check(ui.draw_pile_button.visible and "4" in ui.draw_pile_button.text, "Draw pile button visible with 4 cards remaining")
	check(ui.discard_pile_button.visible and "0" in ui.discard_pile_button.text, "Discard pile button visible with 0 cards")
	check(ui.hand_view.all_playable_button.visible and ui.hand_view.show_all_playable, "Unified 本轮可用 hand mode active by default in deck-cycle combat")

	ui.draw_pile_button.pressed.emit()
	check(ui.pile_popup.visible and ui.pile_rows.get_child_count() > 0, "Clicking draw pile button opens pile viewer popup")
	ui.pile_close_button.pressed.emit()
	check(not ui.pile_popup.visible, "Pile viewer closes cleanly")

	m.queue_free()
	await process_frame
