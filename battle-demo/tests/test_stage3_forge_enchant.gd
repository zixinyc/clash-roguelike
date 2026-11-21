extends SceneTree

const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const CardPool = preload("res://scripts/card_pool.gd")
const MapScene = preload("res://exploration_map.tscn")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FORGE_ENCHANT_FAIL: " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_card_instance_uids_and_shop_sync()
	_test_forge_enchant_lifecycle_and_per_instance()
	_test_cross_floor_persistence()
	_test_combat_rune_effects()
	await _test_forge_ui_integration()
	print("STAGE3_FORGE_ENCHANT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_card_instance_uids_and_shop_sync() -> void:
	var map = ForestRandomGenerator.generate(501)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 501)

	check(run.card_instances.size() == 10, "Card instances initialized matching 10 starter cards")
	var uids: Dictionary = {}
	for inst in run.card_instances:
		var uid: String = String(inst.get("uid", ""))
		check(not uid.is_empty(), "Instance UID is non-empty")
		check(not uids.has(uid), "Instance UID is globally unique: %s" % uid)
		uids[uid] = true

	# Reward adds new instance with unique UID
	run.in_battle = true
	run.apply_battle_result(true, run.party_hp, run.carried_cost)
	var rew_key: String = run.pending_card_rewards[0]
	var claim_res := run.claim_card_reward(0)
	check(claim_res.ok and run.card_instances.size() == 11, "Claiming reward adds to card_instances")
	var new_uid: String = String(run.card_instances[10].uid)
	check(not uids.has(new_uid) and run.card_instances[10].key == rew_key, "New reward gets unique UID")

func _test_forge_enchant_lifecycle_and_per_instance() -> void:
	var map = ForestRandomGenerator.generate(502)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 502)
	run.carried_cost = 20

	# 1. Verification of conditions
	check(not run.forge_enchant_card(0, "rune_feather").ok, "Cannot enchant when not at forge node")
	run.pending = "forge"
	check(not run.forge_enchant_card(0, "invalid_rune").ok, "Cannot enchant with invalid rune ID")
	check(not run.forge_enchant_card(-1, "rune_feather").ok, "Cannot enchant invalid negative index")
	check(not run.forge_enchant_card(99, "rune_feather").ok, "Cannot enchant out of bounds index")

	run.carried_cost = 3
	check(not run.forge_enchant_card(0, "rune_feather").ok, "Cannot enchant with insufficient cost (< 4)")
	run.carried_cost = 20

	# Find two duplicate cards in starter deck (e.g. guard at indices 2 and 3)
	var guard_indices: Array[int] = []
	for i in run.deck.size():
		if run.deck[i] == "guard":
			guard_indices.append(i)
	check(guard_indices.size() >= 2, "Starter deck contains at least 2 copies of guard")
	var g0_idx: int = guard_indices[0]
	var g1_idx: int = guard_indices[1]
	var g0_uid: String = String(run.card_instances[g0_idx].uid)
	var g1_uid: String = String(run.card_instances[g1_idx].uid)
	check(g0_uid != g1_uid, "Duplicate guard cards possess distinct instance UIDs")

	# Enchant guard #0 with rune_impact
	var enc_res := run.forge_enchant_card(g0_idx, "rune_impact")
	check(enc_res.ok and run.carried_cost == 16, "Enchanting guard #0 costs 4 cost (20 -> 16)")
	check(run.card_instances[g0_idx].enchant == "rune_impact", "Guard #0 instance has rune_impact")
	check(run.deck_enchants[g0_uid] == "rune_impact", "deck_enchants records guard #0 UID")
	check(run.card_instances[g1_idx].enchant == "", "Guard #1 instance remains completely unenchanted (per-instance isolation)")
	check(not run.deck_enchants.has(g1_uid), "Guard #1 UID is not in deck_enchants")

	# Duplicate confirm on same card with same rune rejected
	run.pending = "forge"
	check(not run.forge_enchant_card(g0_idx, "rune_impact").ok, "Cannot re-apply identical rune to same card")

	# Replacing with different rune overwrites without refund
	var rep_res := run.forge_enchant_card(g0_idx, "rune_feather")
	check(rep_res.ok and run.carried_cost == 12, "Overwriting rune deducts 4 cost (16 -> 12)")
	check(run.card_instances[g0_idx].enchant == "rune_feather", "Guard #0 rune updated to rune_feather")
	check(run.deck_enchants[g0_uid] == "rune_feather", "deck_enchants updated to rune_feather")

	# Shop removal of unenchanted guard #1 leaves guard #0 untouched
	run.pending = "shop"
	var rem_res := run.shop_remove_card(g1_idx)
	check(rem_res.ok, "Shop removes guard #1")
	var found_g0 := false
	for inst in run.card_instances:
		if String(inst.uid) == g0_uid and inst.enchant == "rune_feather":
			found_g0 = true
			break
	check(found_g0 and run.deck_enchants.has(g0_uid), "Enchanted guard #0 preserved after guard #1 removed")

func _test_cross_floor_persistence() -> void:
	var map1 = ForestRandomGenerator.generate(503)
	var run = ForestRun.new()
	run.initialize(map1, 0, [], [], 503)
	run.pending = "forge"
	run.carried_cost = 20
	run.forge_enchant_card(0, "rune_feather")
	var uid0: String = String(run.card_instances[0].uid)

	var map2 = ForestRandomGenerator.generate(504)
	run.advance_to_next_floor(map2, 504)
	check(run.floor_level == 2, "Floor level advanced to 2")
	check(run.card_instances.size() == 10, "Card instances preserved across floors")
	check(run.card_instances[0].uid == uid0, "Instance UID preserved across floors")
	check(run.card_instances[0].enchant == "rune_feather", "Card enchant preserved across floors")
	check(run.deck_enchants[uid0] == "rune_feather", "deck_enchants mapping preserved across floors")

func _test_combat_rune_effects() -> void:
	var deck: Array[String] = ["cleave", "ember", "guard", "guard"]
	var card_instances: Array[Dictionary] = [
		{"uid": "c0", "key": "cleave", "enchant": "rune_feather"}, # 3-cost cleave -> 2 cost
		{"uid": "c1", "key": "ember", "enchant": "rune_impact"},    # base 4 -> base 5 in clash
		{"uid": "c2", "key": "guard", "enchant": ""},
		{"uid": "c3", "key": "guard", "enchant": ""}
	]

	var b := DemoBattleRules.new()
	b.start(777, 0, false, false, [DemoBattleRules.ASH_ID], deck, false, [], [], {
		"deck_cycle": false,
		"card_instances": card_instances
	})

	check(b.master_deck[0].uid == "c0" and b.master_deck[0].enchant == "rune_feather", "master_deck inherits UID and rune_feather")
	check(b.master_deck[1].uid == "c1" and b.master_deck[1].enchant == "rune_impact", "master_deck inherits UID and rune_impact")

	# Test rune_feather cost reduction
	check(b.card_effective_cost(0) == 2, "Cleave with rune_feather costs 2 instead of 3")
	check(b.card_effective_cost(1) == 2, "Ember without rune_feather retains base cost 2")

	# Assign slot 0 with card 0 (cleave)
	b.assign(0, 0, 0)
	check(b.reserved_cost() == 2, "Reserved cost for feather cleave is 2 instead of 3")

	# Test rune_impact clash bonus (+1)
	for es in b.enemy_slots:
		es.active = es.id == 0
	b.enemy_slots[0].target = 0
	b.enemy_slots[0].speed = 3
	b.hero_slots[0].speed = 7
	b.cancel(0)
	b.assign(1, 0, 0) # assign card 1 (ember with rune_impact)
	var events := b.lock_and_resolve()
	check(events.any(func(e: Dictionary) -> bool: return e.type == "ability" and "破势" in String(e.message)), "Clash with rune_impact emits 破势 ability event")

func _test_forge_ui_integration() -> void:
	var m = MapScene.instantiate()
	root.add_child(m)
	await process_frame

	m.run.pending = "forge"
	m.run.carried_cost = 18
	m._open_modal("forge")
	check(m.modal_btn_3.visible and not m.modal_btn_3.disabled, "Forge modal displays enabled 符卡附魔 button")

	# Click modal_btn_3 -> opens forge enchant panel
	m.modal_btn_3.pressed.emit()
	check(m.forge_enchant_panel.visible, "Clicking 符卡附魔 button opens forge enchant panel")
	check(m.forge_card_buttons.size() == 10, "Forge enchant panel lists all 10 cards")
	check(m.forge_rune_buttons.size() == 5, "Forge enchant panel lists all 5 runes")

	# Select card 0 (cleave) and rune 0 (rune_feather)
	m._on_forge_card_selected(0)
	m._on_forge_rune_selected("rune_feather")
	check(not m.forge_enchant_confirm_btn.disabled, "Confirm button enabled after selecting card and rune")
	check("轻灵" in m.forge_enchant_feedback.text, "Feedback label describes lightweight rune effect")

	# Confirm enchant
	m.forge_enchant_confirm_btn.pressed.emit()
	check(not m.forge_enchant_panel.visible, "Forge enchant modal closes after confirming")
	check(m.run.carried_cost == 14, "Enchanting deducted 4 cost (18 -> 14)")
	check(m.run.card_instances[0].enchant == "rune_feather", "Card instance 0 successfully enchanted with rune_feather")

	m.queue_free()
	await process_frame
