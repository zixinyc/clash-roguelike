extends SceneTree

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const MapScene = preload("res://exploration_map.tscn")
const MainScene = preload("res://main.tscn")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DESTINY_FAIL: " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_map_gates_and_reachability()
	_test_destiny_ledger_and_gate_transactions()
	_test_clash_probability_and_boundaries()
	await _test_ui_integration()
	_test_balance_and_late_game_smoothness()
	print("DESTINY_SYSTEM checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _battle_free_reachable(graph: ForestMapGraph, start_id: String, target_id: String) -> bool:
	var queue: Array[String] = [start_id]
	var seen := {start_id: true}
	var battle_kinds := [
		ForestMapGraph.NodeKind.BATTLE,
		ForestMapGraph.NodeKind.ELITE,
		ForestMapGraph.NodeKind.CENTER,
		ForestMapGraph.NodeKind.EXIT
	]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == target_id:
			return true
		for edge in graph.get_links(cur):
			if edge.hidden:
				continue
			var nxt: String = edge.other(cur)
			if seen.has(nxt):
				continue
			var node := graph.get_node(nxt)
			if node == null:
				continue
			if nxt != target_id and node.kind in battle_kinds:
				continue
			seen[nxt] = true
			queue.append(nxt)
	return false

func _test_map_gates_and_reachability() -> void:
	# 1. Existing enum values preserved
	check(ForestMapGraph.NodeKind.SPAWN == 0, "SPAWN enum index remains 0")
	check(ForestMapGraph.NodeKind.EXIT == 15, "EXIT enum index remains 15")
	check(ForestMapGraph.NodeKind.DESTINY_GATE == 16, "DESTINY_GATE appended at 16")
	check(ForestMapGraph.kind_title(ForestMapGraph.NodeKind.DESTINY_GATE) == "命运石之门", "DESTINY_GATE title is 命运石之门")
	check(ForestMapGraph.kind_key(ForestMapGraph.NodeKind.DESTINY_GATE) == "destiny_gate", "DESTINY_GATE key is destiny_gate")
	check(not ForestMapGraph.kind_summary(ForestMapGraph.NodeKind.DESTINY_GATE).is_empty(), "DESTINY_GATE has summary")

	# 2. Check 30 fixed seeds for gate distribution, battle-free early reachability, and preserved guaranteed nodes
	for s in range(100, 130):
		var g := ForestRandomGenerator.generate(s)
		var gates: Array[ForestMapGraph.MapNode] = []
		var kinds_present := {}
		for node in g.nodes.values():
			var n := node as ForestMapGraph.MapNode
			kinds_present[n.kind] = int(kinds_present.get(n.kind, 0)) + 1
			if n.kind == ForestMapGraph.NodeKind.DESTINY_GATE:
				gates.append(n)
		check(gates.size() >= 2, "Seed %d has at least 2 Destiny Gates (got %d)" % [s, gates.size()])
		for req_kind in [
			ForestMapGraph.NodeKind.SPAWN, ForestMapGraph.NodeKind.SUPPLY, ForestMapGraph.NodeKind.BATTLE,
			ForestMapGraph.NodeKind.LOOKOUT, ForestMapGraph.NodeKind.SHRINE, ForestMapGraph.NodeKind.HIDEOUT,
			ForestMapGraph.NodeKind.DANGER, ForestMapGraph.NodeKind.FORGE, ForestMapGraph.NodeKind.CENTER,
			ForestMapGraph.NodeKind.ELITE, ForestMapGraph.NodeKind.EVENT, ForestMapGraph.NodeKind.SHOP,
			ForestMapGraph.NodeKind.CAMP, ForestMapGraph.NodeKind.EXIT
		]:
			check(kinds_present.has(req_kind), "Seed %d keeps guaranteed node kind %d" % [s, req_kind])
		# At least one gate is reachable from SPAWN without passing through any battle node
		var any_safe_gate := false
		for gn in gates:
			if _battle_free_reachable(g, g.start_id, gn.id):
				any_safe_gate = true
				break
		check(any_safe_gate, "Seed %d has a Destiny Gate reachable before any mandatory battle" % s)
		check(g.distance_between(g.start_id, g.center_id, false) < 999, "Seed %d keeps start->center path" % s)
		check(g.distance_between(g.center_id, g.exit_id, false) < 999, "Seed %d keeps center->exit path" % s)

func _find_nodes_of_kind(g: ForestMapGraph, kind: int) -> Array[String]:
	var out: Array[String] = []
	for node in g.nodes.values():
		if node.kind == kind:
			out.append(node.id)
	out.sort()
	return out

func _test_destiny_ledger_and_gate_transactions() -> void:
	var g := ForestRandomGenerator.generate(2026)
	var run := ForestRun.new()
	run.initialize(g, 0, [], [], 2026)

	# Initial values
	check(run.destiny == 0 and run.destiny_tier == 0, "Run starts at 0 destiny and tier 0")
	check(is_equal_approx(run.get_clash_heads_rate(), 0.45) and run.get_clash_heads_percent() == 45, "Initial clash heads rate is 45%")
	check(run.get_destiny_upgrade_cost() == 2 and run.get_next_destiny_heads_percent() == 60, "Tier 0->1 costs 2 for 60%")

	# Outside gate: claim and upgrade rejected
	check(not run.claim_destiny_gate().ok, "Cannot claim destiny outside Destiny Gate")
	run.destiny = 5
	check(not run.upgrade_destiny_tier(1).ok and run.destiny == 5 and run.destiny_tier == 0, "Cannot upgrade outside Destiny Gate")
	run.destiny = 0

	# Enter Gate #1 -> claim +2 -> immediately upgrade 45% -> 60%
	var gates := _find_nodes_of_kind(g, ForestMapGraph.NodeKind.DESTINY_GATE)
	check(gates.size() >= 2, "Map has at least 2 Destiny Gates for ledger tests")
	var gate1 := gates[0]
	var gate2 := gates[1]
	run.position = gate1
	run.enter_node()
	check(run.pending == "destiny_gate", "Entering Destiny Gate sets pending=destiny_gate")
	var c1 := run.claim_destiny_gate()
	check(c1.ok and int(c1.gained) == 2 and run.destiny == 2, "Gate #1 claim grants +2 destiny")
	check(run.is_destiny_gate_claimed(gate1), "Gate #1 marked claimed")
	check(not run.claim_destiny_gate().ok and run.destiny == 2, "Repeat claim on Gate #1 rejected")
	var u1 := run.upgrade_destiny_tier(1)
	check(u1.ok and run.destiny == 0 and run.destiny_tier == 1 and run.get_clash_heads_percent() == 60, "Immediate upgrade after claim: 45% -> 60% (-2 destiny)")

	# Duplicate submission with stale expected_target_tier rejected without deducting destiny
	run.destiny = 5
	var dup_u := run.upgrade_destiny_tier(1)
	check(not dup_u.ok and run.destiny == 5 and run.destiny_tier == 1, "Stale expected_target_tier rejected cleanly")

	# Leave gate and return later -> still cannot re-claim Gate #1, CAN upgrade
	check(run.leave_destiny_gate() and run.pending.is_empty(), "Can leave Destiny Gate")
	run.enter_node()
	check(run.pending == "destiny_gate", "Can re-enter Destiny Gate after leaving")
	check(not run.claim_destiny_gate().ok, "Re-entering Gate #1 still blocks second claim")

	# Full capacity (10/10) on Gate #2: cannot claim while full -> upgrade to free space -> claim +2
	run.leave_destiny_gate()
	run.position = gate2
	run.destiny = ForestRun.DESTINY_MAX
	run.enter_node()
	check(not run.claim_destiny_gate().ok and not run.is_destiny_gate_claimed(gate2), "At 10/10, Gate #2 claim blocked and preserved until space is freed")
	var u2 := run.upgrade_destiny_tier(2)
	check(u2.ok and run.destiny == 7 and run.destiny_tier == 2 and run.get_clash_heads_percent() == 75, "Upgrade 60% -> 75% frees space (10 -> 7)")
	var c2 := run.claim_destiny_gate()
	check(c2.ok and int(c2.gained) == 2 and run.destiny == 9 and run.is_destiny_gate_claimed(gate2), "After freeing space, Gate #2 grants +2 (7 -> 9)")

	# Test 1-slot-left preview and claim (+1 only)
	run.destiny_gate_claimed.erase(run._destiny_node_key(gate2)) # simulate a fresh gate while at 9/10
	check(run.get_destiny_gate_claimable_amount(gate2) == 1, "At 9/10, claimable preview reports exactly 1")
	var c2_one := run.claim_destiny_gate()
	check(c2_one.ok and int(c2_one.gained) == 1 and run.destiny == 10, "At 9/10, claiming grants +1 up to cap 10")

	# Consecutive upgrades to max tier: 75% -> 90% (-4, 10->6), 90% -> 100% (-5, 6->1)
	var u3 := run.upgrade_destiny_tier(3)
	check(u3.ok and run.destiny == 6 and run.destiny_tier == 3 and run.get_clash_heads_percent() == 90, "Upgrade 75% -> 90% (-4 destiny)")
	var u4 := run.upgrade_destiny_tier(4)
	check(u4.ok and run.destiny == 1 and run.destiny_tier == 4 and run.get_clash_heads_percent() == 100 and run.is_destiny_max_tier(), "Upgrade 90% -> 100% (-5 destiny)")
	# Max tier upgrade request does not spend destiny
	run.destiny = 10
	var u_max := run.upgrade_destiny_tier()
	check(not u_max.ok and run.destiny == 10 and run.destiny_tier == 4, "Max tier upgrade rejected without deducting destiny")

	# Insufficient destiny check
	run.destiny_tier = 2
	run.destiny = 3 # need 4 for tier 3
	var u_insuff := run.upgrade_destiny_tier(3)
	check(not u_insuff.ok and run.destiny == 3 and run.destiny_tier == 2, "Insufficient destiny rejected without mutation")

	# Lineup swap preserves destiny and tier
	run.leave_destiny_gate()
	run.set_lineup_and_deck([DemoBattleRules.ASH_ID, DemoBattleRules.ZIXI_ID], ["ember", "guard", "zixi_central_limit"])
	check(run.destiny == 3 and run.destiny_tier == 2, "Changing lineup preserves destiny balance and tier")

	# Cross-floor preserves destiny and tier, and Floor 2 gates are fresh
	var g2 := ForestRandomGenerator.generate(2027)
	run.floor_cleared = true
	check(run.advance_to_next_floor(g2, 2027, "balanced"), "A cleared floor can accept an enemy modifier")
	check(run.floor_level == 2 and run.destiny == 3 and run.destiny_tier == 2, "Advancing floor preserves destiny and tier")
	var f2_gates := _find_nodes_of_kind(g2, ForestMapGraph.NodeKind.DESTINY_GATE)
	run.position = f2_gates[0]
	run.enter_node()
	check(not run.is_destiny_gate_claimed(f2_gates[0]), "Floor 2 Destiny Gate is unclaimed even if same node ID existed on Floor 1")
	var f2_claim := run.claim_destiny_gate()
	check(f2_claim.ok and run.destiny == 5, "Floor 2 Destiny Gate grants +2 destiny")

	# Random drop rules: miss uses up attempt, patrol/shrine-cancel/defeat/revisit never roll, overflow discarded
	var r_drop := ForestRun.new()
	r_drop.initialize(g, 0, [], [], 9001)
	var lookouts := _find_nodes_of_kind(g, ForestMapGraph.NodeKind.LOOKOUT)
	var shrines := _find_nodes_of_kind(g, ForestMapGraph.NodeKind.SHRINE)
	var battles := _find_nodes_of_kind(g, ForestMapGraph.NodeKind.BATTLE)

	# Shrine open & cancel (no apply_choice) -> never rolls
	r_drop.position = shrines[0]
	r_drop.enter_node()
	check(r_drop.pending == "shrine" and not r_drop.destiny_drop_rolled.has(r_drop._destiny_node_key(shrines[0])), "Opening shrine modal does not roll destiny")
	r_drop.pending = ""
	check(not r_drop.destiny_drop_rolled.has(r_drop._destiny_node_key(shrines[0])), "Cancelling shrine modal does not roll destiny")

	# Patrol victory -> never rolls
	r_drop.position = g.start_id
	r_drop.in_battle = true
	r_drop.patrol_encounter = true
	r_drop.current_encounter = 3
	r_drop.apply_battle_result(true, r_drop.party_hp, r_drop.carried_cost)
	check(not r_drop.destiny_drop_rolled.has(r_drop._destiny_node_key(g.start_id)), "Patrol encounter victory does not roll destiny")

	# Defeat -> never rolls
	r_drop.position = battles[0]
	r_drop.in_battle = true
	r_drop.current_encounter = 0
	r_drop.apply_battle_result(false, [0, 0, 0], r_drop.carried_cost)
	check(not r_drop.destiny_drop_rolled.has(r_drop._destiny_node_key(battles[0])), "Battle defeat does not roll destiny")

	# Miss uses up opportunity; second roll on same node is rejected
	r_drop.initialize(g, 0, [], [], 9002)
	var res_miss := r_drop._try_roll_destiny_drop(lookouts[0], 0.0, "测试落空")
	check(res_miss.rolled and not res_miss.hit and res_miss.gained == 0, "Forced miss records rolled=true, hit=false")
	var res_second := r_drop._try_roll_destiny_drop(lookouts[0], 1.0, "测试重复")
	check(not res_second.rolled and res_second.gained == 0, "Missed node cannot be rolled a second time")

	# Full cap overflow discarded on random drop
	r_drop.destiny = ForestRun.DESTINY_MAX
	var res_full := r_drop._try_roll_destiny_drop(shrines[0], 1.0, "满额测试")
	check(res_full.rolled and res_full.hit and res_full.gained == 0 and r_drop.destiny == ForestRun.DESTINY_MAX, "Random drop at 10/10 discards overflow")

	# Statistical check of drop probabilities across 400 seeds (Lookout 30%, Shrine 30%, Battle 20%, Elite 35%, Boss 50%)
	var hits_lookout := 0
	var hits_shrine := 0
	var hits_battle := 0
	var hits_elite := 0
	var hits_boss := 0
	var elites := _find_nodes_of_kind(g, ForestMapGraph.NodeKind.ELITE)
	var trials := 400
	for i in trials:
		var tr := ForestRun.new()
		tr.initialize(g, 0, [], [], 50000 + i)
		tr.position = lookouts[0]
		tr.enter_node()
		if tr.destiny == 1:
			hits_lookout += 1
		var before_s := tr.destiny
		tr.position = shrines[0]
		tr.enter_node()
		tr.apply_choice(0)
		if tr.destiny > before_s:
			hits_shrine += 1
		var before_b := tr.destiny
		tr.position = battles[0]
		tr.enter_node()
		tr.apply_battle_result(true, tr.party_hp, tr.carried_cost)
		tr.pending = ""
		if tr.destiny > before_b:
			hits_battle += 1
		var before_e := tr.destiny
		tr.position = elites[0]
		tr.enter_node()
		tr.apply_battle_result(true, tr.party_hp, tr.carried_cost)
		tr.pending = ""
		if tr.destiny > before_e:
			hits_elite += 1
		var before_boss := tr.destiny
		tr.position = g.center_id
		tr.enter_node()
		tr.apply_battle_result(true, tr.party_hp, tr.carried_cost)
		tr.pending = ""
		if tr.destiny > before_boss:
			hits_boss += 1
	var r_lookout := float(hits_lookout) / float(trials)
	var r_shrine := float(hits_shrine) / float(trials)
	var r_battle := float(hits_battle) / float(trials)
	var r_elite := float(hits_elite) / float(trials)
	var r_boss := float(hits_boss) / float(trials)
	print("DESTINY_DROPS(N=%d) lookout=%.1f%% shrine=%.1f%% battle=%.1f%% elite=%.1f%% boss=%.1f%%" % [trials, r_lookout * 100, r_shrine * 100, r_battle * 100, r_elite * 100, r_boss * 100])
	check(r_lookout > 0.22 and r_lookout < 0.38, "Lookout drop rate near 30%% (got %.1f%%)" % (r_lookout * 100))
	check(r_shrine > 0.22 and r_shrine < 0.38, "Shrine drop rate near 30%% (got %.1f%%)" % (r_shrine * 100))
	check(r_battle > 0.13 and r_battle < 0.27, "Battle drop rate near 20%% (got %.1f%%)" % (r_battle * 100))
	check(r_elite > 0.27 and r_elite < 0.43, "Elite drop rate near 35%% (got %.1f%%)" % (r_elite * 100))
	check(r_boss > 0.42 and r_boss < 0.58, "Boss drop rate near 50%% (got %.1f%%)" % (r_boss * 100))

	# Verify journal records hit drop
	var j_run := ForestRun.new()
	j_run.initialize(g, 0, [], [], 777)
	j_run._try_roll_destiny_drop(lookouts[0], 1.0, "登上哨塔")
	check(j_run.journal.any(func(e: Dictionary) -> bool: return "命运" in String(e.get("message", ""))), "Hit random destiny drop is logged to journal")

	# Restart resets destiny and tier back to 0 and 45%
	run.initialize(g, 0, [], [], 2026)
	check(run.destiny == 0 and run.destiny_tier == 0 and run.get_clash_heads_percent() == 45, "Restarting exploration resets destiny to 0 and rate to 45%")

func _test_clash_probability_and_boundaries() -> void:
	# 1. Standalone & training default stays 65%
	var b_std := DemoBattleRules.new()
	b_std.start(73129, 0)
	check(is_equal_approx(b_std.ally_clash_heads_chance, 0.65), "Standalone battle defaults to 65% clash heads rate")
	var b_train := DemoBattleRules.new()
	b_train.start(73129, DemoBattleRules.TRAINING_ENCOUNTER)
	check(is_equal_approx(b_train.ally_clash_heads_chance, 0.65), "Training dummy battle defaults to 65% clash heads rate")

	# 2. Explicit 100% boundary: even when random float is exactly 1.0, natural coin MUST be heads!
	var b_max := DemoBattleRules.new()
	b_max.start(100, 0, false, false, [DemoBattleRules.ASH_ID], ["cleave", "ember", "guard"], false, [], [], {"ally_clash_heads_chance": 1.0})
	b_max.custom_coin_rolls = [1.0, 1.0, 1.0, 1.0]
	var r100 := b_max._roll(5, 4, 3, 1.0)
	check(r100.heads == 3 and r100.value == 17, "At 100%% chance, roll value == 1.0 still counts as heads (heads=%d val=%d)" % [r100.heads, r100.value])

	# Full clash at 100% with custom_coin_rolls == 1.0 for ally coins and 0.99 (tails) for enemy coins
	b_max.start(101, 0, false, false, [DemoBattleRules.ASH_ID], ["ember", "guard"], false, [], [], {"ally_clash_heads_chance": 1.0})
	for es in b_max.enemy_slots:
		es.active = es.id == 0
	b_max.enemy_slots[0].key = "ember"
	b_max.enemy_slots[0].target = 0
	b_max.enemy_slots[0].speed = 3
	b_max.hero_slots[0].speed = 6
	# Round 1 clash: ally 2 coins (1.0, 1.0 -> 2 heads -> 4+6=10), enemy 2 coins (0.9, 0.9 -> 0 heads -> 4)
	# Round 2 clash: ally 2 coins (1.0, 1.0 -> 2 heads -> 10), enemy 1 coin (0.9 -> 0 heads -> 4)
	b_max.custom_coin_rolls = [1.0, 1.0, 0.9, 0.9, 1.0, 1.0, 0.9]
	b_max.assign(0, 0, 0)
	var ev_max := b_max.lock_and_resolve()
	var clash_ev := ev_max.filter(func(e: Dictionary) -> bool: return e.type == "clash")
	check(clash_ev.size() == 2 and clash_ev[0].left_heads == 2 and clash_ev[1].left_heads == 2, "At 100%, every clash coin rolls heads even when rng returns 1.0")

	# 3. Even at 100%, weaker card STILL loses to stronger enemy card!
	var b_lose := DemoBattleRules.new()
	b_lose.start(102, 0, false, false, [DemoBattleRules.ASH_ID], ["needle", "guard"], false, [], [], {"ally_clash_heads_chance": 1.0})
	for es in b_lose.enemy_slots:
		es.active = es.id == 0
	b_lose.enemy_slots[0].key = "nova" # base 6 + 4*3 = 18 vs needle max 3 + 2*2 = 7
	b_lose.enemy_slots[0].target = 0
	b_lose.enemy_slots[0].speed = 3
	b_lose.hero_slots[0].speed = 6
	# Enemy rolls heads (0.1) so enemy gets 18 > 7 both times
	b_lose.custom_coin_rolls = [1.0, 1.0, 0.1, 0.1, 0.1, 1.0, 0.1, 0.1, 0.1]
	b_lose.assign(0, 0, 0)
	var ev_lose := b_lose.lock_and_resolve()
	var clash_lose := ev_lose.filter(func(e: Dictionary) -> bool: return e.type == "clash")
	check(clash_lose.size() == 2 and clash_lose[0].left_heads == 2 and clash_lose[0].winner == 1 and clash_lose[1].left_heads == 1 and clash_lose[1].winner == 1, "At 100% heads, weaker needle still loses to stronger enemy nova")

	# 4. Weighted coin (guaranteed_heads) still works at 45%
	var b_wc := DemoBattleRules.new()
	b_wc.start(103, 0, false, false, [DemoBattleRules.ASH_ID], ["ember", "guard"], false, [], ["weighted_coin"], {"ally_clash_heads_chance": 0.45})
	check(b_wc.use_item("weighted_coin").ok and b_wc.guaranteed_heads, "Weighted coin primes guaranteed_heads at 45% tier")
	b_wc.custom_coin_rolls = [0.99, 0.99, 0.99, 0.99]
	var r_wc := b_wc._roll(4, 3, 2, 0.45)
	check(r_wc.heads == 2 and not b_wc.guaranteed_heads, "Weighted coin forces heads on next allied roll and clears flag")

	# 5. ZiXi tail conversion works at 45% (flips tail) and at 100% (doesn't waste tail_available during clash)
	var b_zixi := DemoBattleRules.new()
	b_zixi.start(104, 0, false, false, [DemoBattleRules.ZIXI_ID], ["zixi_convergence", "guard"], false, [], [], {"ally_clash_heads_chance": 0.45})
	b_zixi.heroes[0].metaphysics = 3
	for es in b_zixi.enemy_slots:
		es.active = es.id == 0
	b_zixi.enemy_slots[0].key = "needle"
	b_zixi.enemy_slots[0].target = 0
	b_zixi.enemy_slots[0].speed = 2
	b_zixi.hero_slots[0].speed = 6
	# Ally rolls 3 tails (0.9, 0.9, 0.9), ZiXi converts 1 tail -> 1 head!
	b_zixi.custom_coin_rolls = [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9]
	check(b_zixi.assign(0, 0, 0, true).is_empty(), "ZiXi can assign enhanced convergence")
	var ev_zixi := b_zixi.lock_and_resolve()
	var c_zixi := ev_zixi.filter(func(e: Dictionary) -> bool: return e.type == "clash")
	check(not c_zixi.is_empty() and c_zixi[0].left_heads == 1, "ZiXi convert_tail flips 1 tail to head at 45% tier")

	# 6. All team members (all 3 heroes in 3-hero lineup) share the team ally_clash_heads_chance
	var b_team := DemoBattleRules.new()
	b_team.start(105, 0, false, false, [DemoBattleRules.ASH_ID, DemoBattleRules.BLADE_ID, DemoBattleRules.WEAVER_ID], ["ember", "steady_edge", "support_strike", "guard"], false, [], [], {"ally_clash_heads_chance": 1.0})
	for es in b_team.enemy_slots:
		es.active = es.id in [0, 3]
	b_team.enemy_slots[0].key = "needle"
	b_team.enemy_slots[0].target = 0
	b_team.enemy_slots[0].speed = 2
	b_team.enemy_slots[3].key = "needle"
	b_team.enemy_slots[3].target = 2
	b_team.enemy_slots[3].speed = 2
	b_team.hero_slots[0].speed = 6
	b_team.hero_slots[6].speed = 6
	b_team.assign(0, 0, 0) # Ash
	b_team.assign(2, 6, 3) # Weaver
	var ev_team := b_team.lock_and_resolve()
	var c_team := ev_team.filter(func(e: Dictionary) -> bool: return e.type == "clash")
	check(c_team.size() >= 2, "Multiple heroes clashed")
	for ce in c_team:
		check(int(ce.left_heads) == int(ce.hero_coins), "At 100%%, hero %d rolled all heads (%d/%d)" % [int(ce.hero), int(ce.left_heads), int(ce.hero_coins)])

func _test_ui_integration() -> void:
	var m = MapScene.instantiate()
	m.initial_seed = 4040
	root.add_child(m)
	await process_frame

	# Top bar shows initial 0/10 and 45%
	check("命运 0/10" in m.destiny_label.text and "45%" in m.destiny_label.text, "Map top bar shows initial Destiny 0/10 and 45%")

	# Move to early Destiny Gate and open modal
	var gates := _find_nodes_of_kind(m.run.map, ForestMapGraph.NodeKind.DESTINY_GATE)
	var gate1 := gates[0]
	var gate2 := gates[1]
	m.run.position = gate1
	m.run.known[gate1] = true
	m.run.enter_node()
	m._refresh_ui()
	m._open_modal("destiny_gate")
	check(m.modal_panel.visible and m.destiny_gate_section.visible, "Destiny Gate modal opens with rich two-column UI")
	check("领取命运 +2" in m.destiny_claim_title_lbl.text and not m.destiny_claim_btn.disabled, "Unclaimed gate shows +2 claim button")
	check("45% → 60%" in m.destiny_upgrade_rate_lbl.text and "花费 2 命运" in m.destiny_upgrade_btn.text and m.destiny_upgrade_btn.disabled, "At 0 destiny, upgrade button is disabled and previews 45%->60% for 2")
	check(m.destiny_preview_rate_lbl.text == "45%", "Right preview card shows 45%")

	# Click claim button -> 2/10, upgrade becomes enabled
	m.destiny_claim_btn.pressed.emit()
	check(m.run.destiny == 2 and m.destiny_claim_btn.disabled and m.destiny_claim_btn.text == "已领取", "Claiming updates balance to 2/10 and disables claim button")
	check(not m.destiny_upgrade_btn.disabled, "After claiming +2, upgrade button becomes enabled immediately")
	check("命运 2/10" in m.destiny_label.text, "Top bar updates to Destiny 2/10")

	# Click upgrade button -> 60%, 0/10
	m.destiny_upgrade_btn.pressed.emit()
	check(m.run.destiny == 0 and m.run.destiny_tier == 1 and m.destiny_preview_rate_lbl.text == "60%", "Upgrading updates tier to 60% and preview card to 60%")
	check("60% → 75%" in m.destiny_upgrade_rate_lbl.text and "花费 3 命运" in m.destiny_upgrade_btn.text, "Next upgrade previews 60% -> 75% for 3 destiny")
	check("命运 0/10" in m.destiny_label.text and "60%" in m.destiny_label.text, "Top bar updates to Destiny 0/10 and 60%")

	# Leave gate and re-click current gate node on map
	m.modal_leave_btn.pressed.emit()
	check(not m.modal_panel.visible and m.run.pending.is_empty(), "Leave button closes Destiny Gate modal")
	m._handle_node_clicked(gate1)
	check(m.modal_panel.visible and m.run.pending == "destiny_gate", "Clicking current Destiny Gate node reopens modal")
	m.modal_leave_btn.pressed.emit()

	# Test 1-slot-left preview at Gate #2 when destiny == 9
	m.run.position = gate2
	m.run.destiny = 9
	m.run.enter_node()
	m._open_modal("destiny_gate")
	check("领取命运 +1" in m.destiny_claim_title_lbl.text and "只剩 1 个空位" in m.destiny_claim_sub_lbl.text, "At 9/10, Gate UI explicitly warns only +1 will be gained")
	m.modal_leave_btn.pressed.emit()

	# Start exploration battle -> verify planning UI receives 60% and displays it
	m.run.in_battle = true
	m.run.current_encounter = 0
	m._start_battle(0)
	await process_frame
	check(is_equal_approx(m.battle.battle.ally_clash_heads_chance, 0.60), "Exploration battle receives upgraded 60% clash heads chance")
	check("我方拼点正面率 60%" in m.battle.clash_rate_label.text, "Battle planning UI displays 我方拼点正面率 60%")
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	if m.card_reward_panel.visible:
		m.card_reward_skip_btn.pressed.emit()

	# Max tier UI check
	m.run.position = gate2
	m.run.destiny_tier = 4
	m.run.destiny = 5
	m.run.enter_node()
	m._open_modal("destiny_gate")
	check("已满级" in m.destiny_upgrade_btn.text and m.destiny_upgrade_btn.disabled and m.destiny_preview_rate_lbl.text == "100%", "Max tier UI shows 已满级 and disables upgrade button")
	m.modal_leave_btn.pressed.emit()

	# Enter battle at max tier -> planning UI shows 100%
	m.run.in_battle = true
	m.run.current_encounter = 5
	m._start_battle(5)
	await process_frame
	check(is_equal_approx(m.battle.battle.ally_clash_heads_chance, 1.00), "Max-tier exploration battle receives 100% clash heads chance")
	check("我方拼点正面率 100%" in m.battle.clash_rate_label.text, "Battle planning UI displays 我方拼点正面率 100%")
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	if m.card_reward_panel.visible:
		m.card_reward_skip_btn.pressed.emit()

	# Restart exploration resets top bar back to 0/10 and 45%
	m._restart()
	check(m.run.destiny == 0 and m.run.destiny_tier == 0 and "命运 0/10" in m.destiny_label.text and "45%" in m.destiny_label.text, "Restarting exploration resets HUD to 0/10 and 45%")

	m.queue_free()
	await process_frame

func _simulate_two_coin_clash_winrate(ally_chance: float, trials: int) -> float:
	var wins := 0
	var b := DemoBattleRules.new()
	for i in trials:
		b.start(80000 + i, 0, false, false, [DemoBattleRules.ASH_ID], ["ember", "guard"], false, [], [], {"ally_clash_heads_chance": ally_chance})
		for es in b.enemy_slots:
			es.active = es.id == 0
		b.enemy_slots[0].key = "ember"
		b.enemy_slots[0].target = 0
		b.enemy_slots[0].speed = 3
		b.hero_slots[0].speed = 6
		b.assign(0, 0, 0)
		var ev := b.lock_and_resolve()
		var deciders := ev.filter(func(e: Dictionary) -> bool: return e.type == "clash" and bool(e.get("decider", false)))
		if not deciders.is_empty() and int(deciders[0].winner) == 0:
			wins += 1
	return float(wins) / float(trials)

func _auto_plan_rules(b: DemoBattleRules) -> void:
	var covered := {}
	for slot in b.hero_slots:
		if slot.active:
			continue
		for card_idx in b.hand.size():
			var key: String = b.hand[card_idx]
			if DemoBattleRules.targets_enemy(key):
				var assigned := false
				for e_slot in b.enemy_slots:
					if b.enemies[e_slot.unit].hp <= 0:
						continue
					var clashes := b.can_clash(slot, e_slot)
					if covered.has(e_slot.id) and clashes:
						continue
					if b.assign(card_idx, slot.id, e_slot.id).is_empty():
						if clashes:
							covered[e_slot.id] = true
						assigned = true
						break
				if assigned:
					break
			else:
				if b.assign(card_idx, slot.id, -1).is_empty():
					break

func _simulate_battle_suite(encounter: int, ally_chance: float, lineup: Array, trials: int) -> Dictionary:
	var wins := 0
	var total_hp_left := 0
	var total_turns := 0
	var clash_wins := 0
	var clash_total := 0
	var deck := ["cleave", "ember", "ember", "needle", "steady", "guard", "guard", "probe", "exploit", "steady_edge", "all_in", "cover", "support_strike"]
	for i in trials:
		var b := DemoBattleRules.new()
		b.start(90000 + i * 7 + encounter, encounter, false, false, lineup, deck, false, [], [], {
			"flex_attack_in_ultimate": true,
			"unopposed_bonus": true,
			"deck_cycle": false,
			"ally_clash_heads_chance": ally_chance
		})
		for _r in 25:
			if not b.outcome.is_empty():
				break
			_auto_plan_rules(b)
			var ev := b.lock_and_resolve()
			for e in ev:
				if e.type == "clash" and bool(e.get("decider", false)):
					clash_total += 1
					if int(e.winner) == 0:
						clash_wins += 1
			if b.outcome.is_empty():
				b.next_round()
		if b.outcome == "victory":
			wins += 1
		for h in b.heroes:
			total_hp_left += int(h.hp)
		total_turns += b.turn
	return {
		"win_rate": float(wins) / float(trials),
		"clash_win_rate": float(clash_wins) / float(maxi(1, clash_total)),
		"avg_hp": float(total_hp_left) / float(trials),
		"avg_turns": float(total_turns) / float(trials)
	}

func _test_balance_and_late_game_smoothness() -> void:
	# 1. Exact 2-coin equal-power clash win rate curve (expected ~42.4% / 64.7% / 83.1% / 95.4% / ~100%)
	var w45 := _simulate_two_coin_clash_winrate(0.45, 500)
	var w60 := _simulate_two_coin_clash_winrate(0.60, 500)
	var w75 := _simulate_two_coin_clash_winrate(0.75, 500)
	var w90 := _simulate_two_coin_clash_winrate(0.90, 500)
	var w100 := _simulate_two_coin_clash_winrate(1.00, 500)
	print("CLASH_CURVE(2-coin even, N=500): 45%%=%.1f%% 60%%=%.1f%% 75%%=%.1f%% 90%%=%.1f%% 100%%=%.1f%%" % [w45 * 100, w60 * 100, w75 * 100, w90 * 100, w100 * 100])
	check(w45 < w60 and w60 < w75 and w75 < w90 and w90 < w100, "2-coin clash win rate increases strictly across all 5 tiers")
	check(w45 > 0.34 and w45 < 0.51, "45%% tier clash win rate near 42.4%% (got %.1f%%)" % (w45 * 100))
	check(w60 > 0.56 and w60 < 0.73, "60%% tier clash win rate near 64.7%% (got %.1f%%)" % (w60 * 100))
	check(w75 > 0.75 and w75 < 0.90, "75%% tier clash win rate near 83.1%% (got %.1f%%)" % (w75 * 100))
	check(w90 > 0.89 and w90 <= 1.00, "90%% tier clash win rate near 95.4%% (got %.1f%%)" % (w90 * 100))
	check(w100 >= 0.98, "100%% tier equal-card clash win rate >= 98%% (got %.1f%%)" % (w100 * 100))

	# 2. Full battle comparison: Normal (enc 0), Elite (enc 1), Boss (enc 5) across tiers
	var n45 := _simulate_battle_suite(0, 0.45, DemoBattleRules.DEFAULT_LINEUP, 40)
	var n60 := _simulate_battle_suite(0, 0.60, DemoBattleRules.DEFAULT_LINEUP, 40)
	var n65 := _simulate_battle_suite(0, 0.65, DemoBattleRules.DEFAULT_LINEUP, 40)
	var n90 := _simulate_battle_suite(0, 0.90, DemoBattleRules.DEFAULT_LINEUP, 40)
	var n100 := _simulate_battle_suite(0, 1.00, DemoBattleRules.DEFAULT_LINEUP, 40)
	print("NORMAL_BATTLE(N=40) 45%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 60%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 65%%(old):win=%.0f%%/hp=%.1f | 90%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 100%%:win=%.0f%%/clash=%.0f%%/hp=%.1f" % [
		n45.win_rate * 100, n45.clash_win_rate * 100, n45.avg_hp,
		n60.win_rate * 100, n60.clash_win_rate * 100, n60.avg_hp,
		n65.win_rate * 100, n65.avg_hp,
		n90.win_rate * 100, n90.clash_win_rate * 100, n90.avg_hp,
		n100.win_rate * 100, n100.clash_win_rate * 100, n100.avg_hp
	])
	check(n45.win_rate >= 0.50, "Pre-gate 45%% normal battle remains playable (win_rate=%.0f%%)" % (n45.win_rate * 100))
	check(1.0 - n90.clash_win_rate < (1.0 - n45.clash_win_rate) * 0.5, "90%% tier more than halves the clash loss rate compared with 45%%")
	check(n100.avg_hp > n45.avg_hp, "100%% tier preserves more party HP than 45%% in normal battle")

	# Elite (Encounter 1) comparison
	var e45 := _simulate_battle_suite(1, 0.45, DemoBattleRules.DEFAULT_LINEUP, 40)
	var e65 := _simulate_battle_suite(1, 0.65, DemoBattleRules.DEFAULT_LINEUP, 40)
	var e90 := _simulate_battle_suite(1, 0.90, DemoBattleRules.DEFAULT_LINEUP, 40)
	var e100 := _simulate_battle_suite(1, 1.00, DemoBattleRules.DEFAULT_LINEUP, 40)
	print("ELITE_BATTLE(N=40) 45%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 65%%(old):win=%.0f%%/clash=%.0f%%/hp=%.1f | 90%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 100%%:win=%.0f%%/clash=%.0f%%/hp=%.1f" % [
		e45.win_rate * 100, e45.clash_win_rate * 100, e45.avg_hp,
		e65.win_rate * 100, e65.clash_win_rate * 100, e65.avg_hp,
		e90.win_rate * 100, e90.clash_win_rate * 100, e90.avg_hp,
		e100.win_rate * 100, e100.clash_win_rate * 100, e100.avg_hp
	])
	check(e90.clash_win_rate > e65.clash_win_rate and e100.avg_hp > e65.avg_hp, "Elite battle at 90%%/100%% clearly surpasses legacy 65%%")

	# Late-game Boss (Encounter 5: Colossus) comparison: 45% vs 65% (legacy) vs 90% vs 100%
	var b45 := _simulate_battle_suite(5, 0.45, DemoBattleRules.DEFAULT_LINEUP, 40)
	var b65 := _simulate_battle_suite(5, 0.65, DemoBattleRules.DEFAULT_LINEUP, 40)
	var b90 := _simulate_battle_suite(5, 0.90, DemoBattleRules.DEFAULT_LINEUP, 40)
	var b100 := _simulate_battle_suite(5, 1.00, DemoBattleRules.DEFAULT_LINEUP, 40)
	print("BOSS_BATTLE(N=40) 45%%:win=%.0f%%/clash=%.0f%%/hp=%.1f/turns=%.1f | 65%%(old):win=%.0f%%/clash=%.0f%%/hp=%.1f/turns=%.1f | 90%%:win=%.0f%%/clash=%.0f%%/hp=%.1f/turns=%.1f | 100%%:win=%.0f%%/clash=%.0f%%/hp=%.1f/turns=%.1f" % [
		b45.win_rate * 100, b45.clash_win_rate * 100, b45.avg_hp, b45.avg_turns,
		b65.win_rate * 100, b65.clash_win_rate * 100, b65.avg_hp, b65.avg_turns,
		b90.win_rate * 100, b90.clash_win_rate * 100, b90.avg_hp, b90.avg_turns,
		b100.win_rate * 100, b100.clash_win_rate * 100, b100.avg_hp, b100.avg_turns
	])
	check(b90.clash_win_rate > b65.clash_win_rate and b100.clash_win_rate >= b90.clash_win_rate, "Late-game Boss clash win rate clearly surpasses legacy 65%% baseline")
	check(b100.avg_hp > b65.avg_hp and b100.win_rate >= b65.win_rate, "Late-game Boss battle is smoother (higher HP left & win rate) at 100%% than legacy 65%%")

	# Short-team (2-hero) comparison
	var duo45 := _simulate_battle_suite(0, 0.45, [DemoBattleRules.ASH_ID, DemoBattleRules.BLADE_ID], 30)
	var duo100 := _simulate_battle_suite(0, 1.00, [DemoBattleRules.ASH_ID, DemoBattleRules.BLADE_ID], 30)
	print("DUO_BATTLE(N=30) 45%%:win=%.0f%%/clash=%.0f%%/hp=%.1f | 100%%:win=%.0f%%/clash=%.0f%%/hp=%.1f" % [
		duo45.win_rate * 100, duo45.clash_win_rate * 100, duo45.avg_hp,
		duo100.win_rate * 100, duo100.clash_win_rate * 100, duo100.avg_hp
	])
	check(duo100.clash_win_rate > duo45.clash_win_rate and duo100.avg_hp > duo45.avg_hp, "2-hero team also sees clear improvement from 45%% to 100%%")

	# 3. 3-floor progression simulation across 20 seeds: verify players naturally reach 90% and 100% by Floors 2-3
	var reached_90_count := 0
	var reached_100_count := 0
	var floor_sum_90 := 0
	var floor_sum_100 := 0
	for s in 20:
		var sim_run := ForestRun.new()
		var map1 := ForestRandomGenerator.generate(3000 + s * 10 + 1)
		sim_run.initialize(map1, 0, [], [], 3000 + s * 10 + 1)
		var f_90 := 0
		var f_100 := 0
		for fl in range(1, 4):
			if fl > 1:
				var next_m := ForestRandomGenerator.generate(3000 + s * 10 + fl)
				sim_run.floor_cleared = true
				check(sim_run.advance_to_next_floor(next_m, 3000 + s * 10 + fl, "balanced"), "Simulation advances with an enemy modifier")
			var cur_g := sim_run.map as ForestMapGraph
			var fl_gates := _find_nodes_of_kind(cur_g, ForestMapGraph.NodeKind.DESTINY_GATE)
			var fl_lookouts := _find_nodes_of_kind(cur_g, ForestMapGraph.NodeKind.LOOKOUT)
			var fl_shrines := _find_nodes_of_kind(cur_g, ForestMapGraph.NodeKind.SHRINE)
			var fl_battles := _find_nodes_of_kind(cur_g, ForestMapGraph.NodeKind.BATTLE)
			var fl_elites := _find_nodes_of_kind(cur_g, ForestMapGraph.NodeKind.ELITE)
			# Visit Early Gate -> claim + upgrade as much as possible
			if fl_gates.size() >= 1:
				sim_run.position = fl_gates[0]
				sim_run.enter_node()
				sim_run.claim_destiny_gate()
				while sim_run.upgrade_destiny_tier().ok:
					pass
				sim_run.leave_destiny_gate()
			# Explore lookout, shrine, 1 normal battle, 1 elite, center boss
			if not fl_lookouts.is_empty():
				sim_run.position = fl_lookouts[0]
				sim_run.enter_node()
			if not fl_shrines.is_empty():
				sim_run.position = fl_shrines[0]
				sim_run.enter_node()
				sim_run.apply_choice(0)
			if not fl_battles.is_empty():
				sim_run.position = fl_battles[0]
				sim_run.enter_node()
				sim_run.apply_battle_result(true, sim_run.party_hp, sim_run.carried_cost)
				sim_run.pending = ""
			if not fl_elites.is_empty():
				sim_run.position = fl_elites[0]
				sim_run.enter_node()
				sim_run.apply_battle_result(true, sim_run.party_hp, sim_run.carried_cost)
				sim_run.pending = ""
			sim_run.position = cur_g.center_id
			sim_run.enter_node()
			sim_run.apply_battle_result(true, sim_run.party_hp, sim_run.carried_cost)
			sim_run.pending = ""
			# Visit Late Gate -> upgrade to free space if needed, claim +2, upgrade as much as possible
			if fl_gates.size() >= 2:
				sim_run.position = fl_gates[1]
				sim_run.enter_node()
				if sim_run.destiny >= ForestRun.DESTINY_MAX:
					sim_run.upgrade_destiny_tier()
				sim_run.claim_destiny_gate()
				while sim_run.upgrade_destiny_tier().ok:
					pass
				sim_run.leave_destiny_gate()
			if f_90 == 0 and sim_run.destiny_tier >= 3:
				f_90 = fl
			if f_100 == 0 and sim_run.destiny_tier >= 4:
				f_100 = fl
		if f_90 > 0:
			reached_90_count += 1
			floor_sum_90 += f_90
		if f_100 > 0:
			reached_100_count += 1
			floor_sum_100 += f_100
	print("RUN_PROGRESSION(N=20, 3 floors): reached_90=%d/20 (avg floor %.2f) | reached_100=%d/20 (avg floor %.2f)" % [
		reached_90_count, float(floor_sum_90) / float(maxi(1, reached_90_count)),
		reached_100_count, float(floor_sum_100) / float(maxi(1, reached_100_count))
	])
	check(reached_90_count == 20, "All 20 simulated 3-floor runs reach 90%% tier")
	check(reached_100_count >= 18, "Almost all simulated 3-floor runs reach 100%% max tier (got %d/20)" % reached_100_count)
