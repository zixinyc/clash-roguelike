extends SceneTree

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")

var checks := 0
var failures := 0

func _init() -> void:
	print("--- Running Forest Map & Relic Tests ---")
	_test_relic_database()
	_test_map_generator()
	_test_forest_run_navigation()
	_test_action_dice_system()
	_test_forest_run_nodes_and_patrol()
	_test_forest_run_center_boss_and_escape()
	_test_battle_relic_effects()
	_test_battle_consumables()
	_test_floor_progression_and_exit_boss()
	_test_custom_lineup_and_shop_adjustment()
	
	print("FOREST_MAP_TESTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: %s" % message)

func _test_relic_database() -> void:
	check(RelicSystem.RELIC_DB.size() >= 12, "Relic database contains at least 12 universal relics")
	check(RelicSystem.CONSUMABLE_DB.size() >= 4, "Consumable database contains at least 4 items")
	
	var r_mercury: Dictionary = RelicSystem.get_relic("mercury_die")
	check(r_mercury.get("name", "") == "水银骰子", "mercury_die has correct name")
	check(r_mercury.get("rarity", "") == "rare", "mercury_die rarity is rare")
	
	var unowned := RelicSystem.get_unowned_relics(["mercury_die", "adversity_blade"])
	check(not unowned.has("mercury_die") and not unowned.has("adversity_blade"), "Unowned relics correctly filters owned ones")
	check(unowned.size() == RelicSystem.RELIC_DB.size() - 2, "Unowned relics count is correct")

func _test_map_generator() -> void:
	var map = ForestRandomGenerator.generate(42)
	check(map != null, "Map generated successfully")
	check(map.nodes.size() >= 15, "Map has sufficient nodes (actual: %d)" % map.nodes.size())
	check(map.edges.size() >= 15, "Map has sufficient edges (actual: %d)" % map.edges.size())
	check(not map.start_id.is_empty() and map.has_node(map.start_id), "Map has valid start node")
	check(not map.exit_id.is_empty() and map.has_node(map.exit_id), "Map has valid exit node")
	check(not map.center_id.is_empty() and map.has_node(map.center_id), "Map has valid center boss node")
	check(not map.patrol_route.is_empty(), "Map has patrol route defined")
	
	var start_node = map.get_node(map.start_id)
	check(start_node.kind == ForestMapGraph.NodeKind.SPAWN, "Start node is SPAWN")
	var exit_node = map.get_node(map.exit_id)
	check(exit_node.kind == ForestMapGraph.NodeKind.EXIT, "Exit node is EXIT")
	var center_node = map.get_node(map.center_id)
	check(center_node.kind == ForestMapGraph.NodeKind.CENTER, "Center node is CENTER")
	
	var dist: float = float(map.distance(map.start_id, map.center_id))
	check(dist < 999.0, "Path exists from start to center (distance: %.1f)" % dist)
	var exit_dist: float = float(map.distance(map.center_id, map.exit_id))
	check(exit_dist < 999.0, "Path exists from center to exit (distance: %.1f)" % exit_dist)

func _test_forest_run_navigation() -> void:
	var map = ForestRandomGenerator.generate(100)
	var run = ForestRun.new()
	run.initialize(map, 0, ["mercury_die"], ["dense_smoke"], 100)
	
	check(run.position == map.start_id, "Run starts at map start_id")
	check(not run.dice_rolled, "Turn 1 starts unrolled")
	check(run.actions_left == 0, "Initial actions_left is 0 before rolling")
	check(run.action_budget == 0, "Initial action_budget is 0 before rolling")
	check(run.carried_cost == ForestRun.START_COST and run.carried_cost == 18, "Initial carried cost is 18")
	check(run.relics == ["mercury_die"], "Initial relics contains mercury_die")
	check(run.items == ["dense_smoke"], "Initial items contains dense_smoke")
	check(not run.ember_core, "Initial ember_core is false")
	
	# Find adjacent node - blocked before rolling dice
	var links: Array = map.get_links(run.position)
	check(not links.is_empty(), "Start node has links")
	var next_id: String = links[0].other(run.position)
	check(not run.can_move(next_id) and "行动骰" in run.move_error(next_id), "Cannot move before rolling action dice")
	
	# Roll 1d4 dice (forced 3 for deterministic navigation assertion)
	var roll_res: Dictionary = run.roll_action_dice(3)
	check(roll_res.get("ok", false) and roll_res.get("steps", 0) == 3, "Rolling action dice grants 3 steps")
	check(run.dice_rolled and run.action_budget == 3 and run.actions_left == 3, "Dice state updated cleanly")
	check(run.can_move(next_id), "Can move to adjacent node after rolling dice")
	
	var moved := run.move(next_id)
	check(moved, "Movement to next_id succeeded")
	check(run.position == next_id, "Current position updated")
	check(run.actions_left == 2, "Actions left deducted by 1 (now %d)" % run.actions_left)
	check(run.fatigue == 1, "Fatigue increased to 1")
	check(run.visited.has(next_id), "Node marked visited")
	
	if run.in_battle:
		run.apply_battle_result(true, run.party_hp, run.carried_cost)
		if run.pending == "card_reward":
			run.skip_card_reward()
	elif not run.pending.is_empty():
		run.apply_choice(0)
	
	# End turn resets dice state for turn 2
	var end_ok := run.end_turn()
	check(end_ok, "End turn succeeded")
	check(run.turn == 2, "Turn advanced to 2")
	check(not run.dice_rolled and run.actions_left == 0 and run.action_budget == 0, "Dice resets on new turn")

func _test_action_dice_system() -> void:
	var map = ForestRandomGenerator.generate(150)
	var run_a = ForestRun.new()
	var run_b = ForestRun.new()
	run_a.initialize(map, 0, [], [], 7777)
	run_b.initialize(map, 0, [], [], 7777)
	
	# 1. Deterministic 1d4 sequence across turns with same seed
	var rolls_a: Array[int] = []
	var rolls_b: Array[int] = []
	for _i in 6:
		var ra: Dictionary = run_a.roll_action_dice()
		var rb: Dictionary = run_b.roll_action_dice()
		check(ra.ok and rb.ok, "Auto dice roll succeeds")
		check(ra.raw >= ForestRun.DICE_MIN and ra.raw <= ForestRun.DICE_MAX, "1d4 roll stays within 1..4 (got %d)" % ra.raw)
		rolls_a.append(int(ra.raw))
		rolls_b.append(int(rb.raw))
		# Duplicate roll same turn rejected
		var dup: Dictionary = run_a.roll_action_dice()
		check(not dup.ok, "Cannot roll action dice twice in the same turn")
		run_a.end_turn()
		run_b.end_turn()
		if run_a.in_battle:
			run_a.apply_battle_result(true, run_a.party_hp, run_a.carried_cost)
			if run_a.pending == "card_reward":
				run_a.skip_card_reward()
		if run_b.in_battle:
			run_b.apply_battle_result(true, run_b.party_hp, run_b.carried_cost)
			if run_b.pending == "card_reward":
				run_b.skip_card_reward()
	check(rolls_a == rolls_b, "Same seed yields identical dice sequence")
	
	# 2. High fatigue (>= 6) applies -1 penalty with minimum floor 1
	var run_f = ForestRun.new()
	run_f.initialize(map, 0, [], [], 8888)
	run_f.fatigue = 6
	var r_high: Dictionary = run_f.roll_action_dice(4)
	check(r_high.ok and r_high.raw == 4 and r_high.penalty == 1 and r_high.steps == 3, "High fatigue reduces roll 4 to 3 steps")
	check(run_f.actions_left == 3 and run_f.last_dice_penalty == 1, "Penalty recorded on run state")
	
	run_f.end_turn()
	if run_f.in_battle:
		run_f.apply_battle_result(true, run_f.party_hp, run_f.carried_cost)
		if run_f.pending == "card_reward":
			run_f.skip_card_reward()
	run_f.fatigue = 7
	var r_floor: Dictionary = run_f.roll_action_dice(1)
	check(r_floor.ok and r_floor.raw == 1 and r_floor.penalty == 1 and r_floor.steps == 1, "High fatigue never drops steps below 1")
	
	# 3. Resting without rolling reduces fatigue by 2
	run_f.end_turn()
	if run_f.in_battle:
		run_f.apply_battle_result(true, run_f.party_hp, run_f.carried_cost)
		if run_f.pending == "card_reward":
			run_f.skip_card_reward()
	run_f.fatigue = 5
	check(not run_f.dice_rolled and run_f.phase_text() == "等待掷骰", "Phase text reports waiting for dice roll")
	run_f.end_turn()
	check(run_f.fatigue == 3, "Ending turn without rolling counts as resting (-2 fatigue)")
	
	# 4. Floor advance resets dice state
	var map2 = ForestRandomGenerator.generate(151)
	run_f.roll_action_dice(4)
	run_f.floor_cleared = true
	check(run_f.advance_to_next_floor(map2, 151, "balanced"), "Can advance after selecting a modifier")
	check(not run_f.dice_rolled and run_f.actions_left == 0 and run_f.action_budget == 0, "Advancing floor resets dice state")

func _test_forest_run_nodes_and_patrol() -> void:
	var map = ForestRandomGenerator.generate(200)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 200)
	
	# Test camp
	run.pending = "camp"
	var party_prev_hp: int = run.party_hp[0]
	run.party_hp[0] = 30 # Injured
	run.fatigue = 4
	var camp_choice_ok := run.apply_choice(0) # Rest (+10 HP, -3 fatigue)
	check(camp_choice_ok, "Camp rest applied")
	check(run.party_hp[0] == 40, "Party hero healed to 40 (was 30)")
	check(run.fatigue == 1, "Fatigue reduced to 1 (was 4)")
	check(run.pending.is_empty(), "Pending cleared after choice")
	
	# Test shop buy relic
	for node in map.nodes.values():
		if node.kind == ForestMapGraph.NodeKind.SHOP:
			run.position = node.id
			break
	run.enter_node()
	run.carried_cost = 25
	var buy_relic_ok := run.apply_choice(1) # Buy relic (-12 cost)
	check(buy_relic_ok, "Shop buy relic applied")
	check(run.carried_cost == 13, "Carried cost deducted by 12 (now 13)")
	check(run.relics.size() == 1, "Relics acquired (size 1)")
	check(run.pending == "shop" and not run.apply_choice(2), "Shop stays open for lineup changes after one transaction")
	
	# Test shrine blessing
	run.pending = "shrine"
	var prev_max_hp: int = run.party_max_hp[0]
	var shrine_ok := run.apply_choice(1) # Sacred blessing (+4 max HP)
	check(shrine_ok, "Shrine blessing applied")
	check(run.party_max_hp[0] == prev_max_hp + 4, "Party max HP increased by 4")
	
	# Test hideout stealth vs patrol
	run.hidden_turns = 2
	run.patrol_node = run.position # Force patrol onto current position
	run._check_patrol_contact()
	check(not run.in_battle, "Patrol contact avoided due to hidden_turns > 0")

func _test_forest_run_center_boss_and_escape() -> void:
	var map = ForestRandomGenerator.generate(300)
	var run = ForestRun.new()
	run.initialize(map, 0, [], [], 300)
	
	# Move run to Center Boss node
	run.position = map.center_id
	run.enter_node()
	check(run.in_battle, "Center node triggered battle")
	check(run.current_encounter == 5, "Center node encounter is Boss (5)")
	
	# Simulate boss victory
	run.apply_battle_result(true, [40, 35, 38], 45)
	check(not run.in_battle, "Battle resolved")
	check(run.ember_core, "Ember Core acquired from center boss!")
	check(run.relics.size() >= 1, "Relic rewarded from center boss victory")
	
	# Move to Exit node
	run.position = map.exit_id
	run.enter_node()
	check(run.finished, "Run finished upon reaching exit with Ember Core")

func _test_battle_relic_effects() -> void:
	var rules := DemoBattleRules.new()
	
	# 1. Warden Bell (+5 shield at start)
	rules.start(1234, 0, false, false, [], null, false, ["warden_bell"])
	check(rules.heroes[0].shield == 5, "warden_bell gives 5 shield at turn 1")
	
	# 2. Everburning Tinder (+10 income on next round)
	rules.cost = 10
	rules.phase = "finished"
	rules.active_relics = ["everburning_tinder"]
	rules.next_round()
	check(rules.cost == 20, "everburning_tinder gives 10 income (was 10 -> 20)")
	
	# 3. Weight of Balance (wins tie clash)
	rules.active_relics = ["weight_of_balance"]
	check(rules.has_relic("weight_of_balance"), "weight_of_balance is active")
	
	# 4. Adversity Blade
	rules.active_relics = ["adversity_blade"]
	check(rules.has_relic("adversity_blade"), "adversity_blade is active")
	
	# 5. New Encounters setup
	rules.start(1234, 3)
	check(rules.enemies.size() == 2 and rules.enemies[0].name == "迷雾潜伏犬", "Encounter 3 (Forest beasts) loaded correctly")
	rules.start(1234, 4)
	check(rules.enemies.size() == 2 and rules.enemies[0].name == "鸦天狗斥候", "Encounter 4 (Scout & Bear) loaded correctly")
	rules.start(1234, 5)
	check(rules.enemies.size() == 1 and rules.enemies[0].name == "烬心巨像 · 赫斯提斯", "Encounter 5 (Colossus Boss) loaded correctly")

func _test_battle_consumables() -> void:
	var rules := DemoBattleRules.new()
	rules.start(1234, 0, false, false, [], null, false, [], ["ember_catalyst", "dense_smoke", "field_poultice", "weighted_coin", "weighted_coin"])
	
	# Test ember_catalyst
	var initial_cost: int = rules.cost
	var cat_res := rules.use_item("ember_catalyst")
	check(cat_res.ok, "ember_catalyst used successfully")
	check(rules.cost == initial_cost + 5, "Cost increased by 5 (was %d, now %d)" % [initial_cost, rules.cost])
	
	# Test dense_smoke
	var smoke_res := rules.use_item("dense_smoke")
	check(smoke_res.ok, "dense_smoke used successfully")
	check(rules.heroes[0].shield == 8, "Hero shield increased to 8")
	
	# Test field_poultice
	check(not rules.use_item("field_poultice").ok and rules.active_items.has("field_poultice"), "full health prevents wasting the poultice")
	rules.heroes[0].hp = 20
	var poultice_res := rules.use_item("field_poultice")
	check(poultice_res.ok, "field_poultice used successfully")
	check(rules.heroes[0].hp == 32, "Hero healed by 12 HP (was 20, now 32)")
	check(rules.use_item("weighted_coin").ok and rules.guaranteed_heads, "weighted coin primes the next allied roll")
	check(not rules.use_item("weighted_coin").ok and rules.active_items.has("weighted_coin"), "a pending weighted coin prevents spending another")
	rules.phase = "resolve"
	rules.guaranteed_heads = false
	check(not rules.use_item("weighted_coin").ok and rules.active_items.has("weighted_coin"), "items cannot be used outside planning")

func _test_floor_progression_and_exit_boss() -> void:
	var map1 = ForestRandomGenerator.generate(500)
	var run = ForestRun.new()
	run.initialize(map1, 0, ["mercury_die"], ["field_poultice"], 500)
	
	# Verify guaranteed shop before exit
	var links: Array = map1.get_links(map1.exit_id)
	var has_pre_boss_shop := false
	for l in links:
		var neighbor = map1.get_node(l.other(map1.exit_id))
		if neighbor and neighbor.kind == ForestMapGraph.NodeKind.SHOP:
			has_pre_boss_shop = true
			break
	check(has_pre_boss_shop, "Guaranteed shop before boss connected to exit")
	
	# Directly enter exit node
	run.position = map1.exit_id
	run.enter_node()
	check(run.in_battle, "Entering exit node triggers Boss battle")
	check(run.current_encounter == 5, "Exit encounter is Boss (5)")
	check(not run.floor_cleared, "Floor not yet cleared during combat")
	
	# Win boss battle
	run.apply_battle_result(true, [45, 40, 42], 50)
	check(run.floor_cleared, "Boss victory clears floor (floor_cleared = true)")
	check(run.ember_core, "Ember Core acquired upon clearing floor")
	check(run.cleared.has(map1.exit_id), "Exit node marked cleared")
	
	# Advance to next floor
	var map2 = ForestRandomGenerator.generate(501)
	check(run.carried_cost == 65, "Boss awards 15 Cost")
	if run.pending == "card_reward":
		run.skip_card_reward()
	var cost_before := int(run.carried_cost)
	check(run.advance_to_next_floor(map2, 501, "fortified"), "Boss rewards and a modifier unlock the next floor")
	check(run.floor_level == 2, "Floor level increased to 2")
	check(not run.floor_cleared, "Floor 2 is not cleared upon entry")
	check(run.position == map2.start_id, "Position reset to map2 start_id")
	check(run.party_hp == [45, 40, 42], "Party HP preserved across floors")
	check(run.relics.has("mercury_die"), "Relics preserved across floors")
	check(run.carried_cost == cost_before, "Cost preserved across floors")
	check(not run.ember_core, "the next floor starts without the previous Ember Core")
	run.position = map2.exit_id
	run.enter_node()
	check(run.in_battle and run.current_encounter == 5, "the next floor still requires its own boss battle")

func _test_custom_lineup_and_shop_adjustment() -> void:
	var map = ForestRandomGenerator.generate(600)
	var run = ForestRun.new()
	
	# Initialize with Touhou custom lineup (Reimu, Sakuya, Marisa)
	var custom_team = [DemoBattleRules.REIMU_ID, DemoBattleRules.SAKUYA_ID, DemoBattleRules.MARISA_ID]
	var custom_deck = ["needle", "cleave", "steady"]
	run.initialize(map, 0, [], [], 600, custom_team, custom_deck)
	
	check(run.lineup == custom_team, "Custom lineup correctly initialized")
	check(run.party_names == ["博丽灵梦", "十六夜咲夜", "雾雨魔理沙"], "Party names match custom lineup")
	check(run.party_hp.size() == 3, "Party HP matches team size")
	check(run.deck == custom_deck, "Custom deck initialized")
	
	# Simulate shop lineup adjustment (e.g. swap to ZiXi and Ash)
	var new_team = [DemoBattleRules.ASH_ID, DemoBattleRules.ZIXI_ID]
	var new_deck = ["ember", "nova", "guard"]
	run.set_lineup_and_deck(new_team, new_deck)
	
	check(run.lineup == new_team, "Lineup updated via set_lineup_and_deck")
	check(run.party_names == ["灰烬", "ZiXi"], "Party names updated")
	check(run.deck == new_deck, "Deck updated")
	
	# Test out-of-combat field poultice healing
	run.party_hp[1] = 10
	run.heal_lowest_hero(12)
	check(run.party_hp[1] == 22, "Lowest hero healed by 12 via heal_lowest_hero")
