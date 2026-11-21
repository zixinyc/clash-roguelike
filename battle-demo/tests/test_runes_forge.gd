extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAILURE: " + label)

func _initialize() -> void:
	test_rune_feather_cost_and_passives()
	test_rune_leech_healing_and_caps()
	test_rune_impact_clash_bonus()
	test_rune_echo_prob_and_limits()
	test_rune_overcharge_shield_consumption()
	test_forest_run_forge_lifecycle()
	test_forge_hero_swap_and_shared_cards()
	test_runes_backward_compatibility()
	print("RUNES_FORGE_TESTS checks complete, failures=", failures)
	quit(1 if failures else 0)

func test_rune_feather_cost_and_passives() -> void:
	var b := Rules.new()
	var enchants := {
		"training_tap": "rune_feather", # 0 cost -> 0 cost (no negative cost)
		"needle": "rune_feather",       # 1 cost -> 1 cost (floor at 1)
		"ember": "rune_feather",        # 2 cost -> 1 cost
		"cleave": "rune_feather",       # 3 cost -> 2 cost
		"nova": "rune_feather",         # 4 cost -> 3 cost
		"steady_edge": "rune_feather",  # 3 cost -> 2 cost (Blade passive check)
	}
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true, "deck_enchants": enchants})
	
	# 1. Cost deductions and flooring
	check(b.get_card_cost("training_tap") == 0, "0 cost card remains 0 with feather")
	check(b.get_card_cost("needle") == 1, "1 cost card floored at 1 with feather")
	check(b.get_card_cost("ember") == 1, "2 cost card becomes 1 with feather")
	check(b.get_card_cost("cleave") == 2, "3 cost card becomes 2 with feather")
	check(b.get_card_cost("nova") == 3, "4 cost card becomes 3 with feather")
	
	# 2. Blade passive maintains original 3-cost threshold
	var blade_bonus := Rules.clash_bonus("steady_edge", Rules.BLADE_ID, 0)
	check(blade_bonus == 2, "Blade passive checks original cost >= 3, bonus still +2")
	
	# 3. Reserved cost and refund quotation unified
	b.hero_slots[0].active = true
	b.hero_slots[0].key = "cleave"
	check(b.reserved_cost() == 2, "Reserved cost uses effective cost (2 instead of 3)")
	
	# Extinguish refund test
	var ev: Array[Dictionary] = []
	b.cost = 10
	b._extinguish_remaining_slots(ev, b.heroes[0], true)
	check(b.cost == 12, "Extinguish refunds effective cost (+2)")

func test_rune_leech_healing_and_caps() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true, "deck_enchants": {"cleave": "rune_leech"}})
	
	# Damage enemy and verify 15% heal, capped at 5
	b.heroes[0].hp = 30 # wounded (max 48)
	b.heroes[1].hp = 42 # full (max 42)
	b.heroes[2].hp = 46 # full (max 46)
	
	var ev: Array[Dictionary] = []
	# 20 actual HP damage * 0.15 = 3 heal
	b._apply_rune_leech(ev, "cleave", 0, 20)
	check(b.heroes[0].hp == 33, "Leech heals 3 HP on 20 damage")
	
	# 50 actual HP damage * 0.15 = 7.5 -> capped at 5
	b.heroes[0].hp = 30
	ev.clear()
	b._apply_rune_leech(ev, "cleave", 0, 50)
	check(b.heroes[0].hp == 35, "Leech capped at 5 HP on 50 damage")
	
	# Full HP hero does not overflow
	b.heroes[0].hp = 48
	ev.clear()
	b._apply_rune_leech(ev, "cleave", 0, 20)
	check(b.heroes[0].hp == 48, "Leech does not overflow max HP")
	
	# Dead hero cannot be revived
	b.heroes[0].hp = 0
	b.heroes[1].hp = 40
	ev.clear()
	b._apply_rune_leech(ev, "cleave", 1, 20)
	check(b.heroes[0].hp == 0, "Dead hero is not revived by leech")
	check(b.heroes[1].hp == 42, "Living wounded teammate gets the heal instead")

func test_rune_impact_clash_bonus() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true, "deck_enchants": {"steady": "rune_impact"}})
	
	# Base of steady is 7. With impact, left_skill.base should be 8.
	b.hero_slots[0].active = true
	b.hero_slots[0].key = "steady"
	b.enemy_slots[0].active = true
	b.enemy_slots[0].key = "training_tap"
	
	var ev: Array[Dictionary] = []
	b._clash(ev, b.hero_slots[0], b.enemy_slots[0])
	var impact_emitted := ev.any(func(e: Dictionary) -> bool: return e.get("type") == "ability" and e.get("message", "").contains("破势"))
	check(impact_emitted, "Rune impact ability message emitted")

func test_rune_echo_prob_and_limits() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true, "deck_enchants": {"ember": "rune_echo"}})
	
	b.enemies[0].hp = 40
	b.enemies[0].shield = 5
	
	# Force rng seed to trigger echo (randf < 0.25)
	var triggered := false
	for seed_val in range(1, 50):
		b.rng.seed = seed_val
		b.echo_triggered_this_round = false
		b.enemies[0].hp = 40
		b.enemies[0].shield = 5
		var ev: Array[Dictionary] = []
		b._apply_rune_echo(ev, "ember", 0, 0, 20)
		if b.echo_triggered_this_round:
			triggered = true
			# 20 * 0.35 = 7 raw echo. 5 absorbed by shield, 2 dealt to HP.
			check(b.enemies[0].shield == 0, "Echo absorbed by shield first")
			check(b.enemies[0].hp == 38, "Echo remainder penetrates to HP")
			var echo_evt := ev.any(func(e: Dictionary) -> bool: return e.get("type") == "echo")
			check(echo_evt, "Echo event emitted")
			
			# Team max 1 echo per round
			ev.clear()
			b._apply_rune_echo(ev, "ember", 0, 0, 20)
			check(ev.is_empty(), "Second echo in same round blocked by team limit")
			break
	check(triggered, "Echo successfully triggers within random trials")

func test_rune_overcharge_shield_consumption() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true, "deck_enchants": {"ember": "rune_overcharge"}})
	
	# Case 1: 10 shield -> consumes 8 shield for +30%
	b.heroes[0].shield = 10
	var ev: Array[Dictionary] = []
	var mult := b._apply_rune_overcharge(ev, "ember", 0)
	check(mult == 1.30, "10 shield gives +30% multiplier")
	check(b.heroes[0].shield == 2, "8 shield consumed, 2 remaining")
	
	# Case 2: 5 shield -> consumes 4 shield for +15%
	b.heroes[0].shield = 5
	ev.clear()
	mult = b._apply_rune_overcharge(ev, "ember", 0)
	check(mult == 1.15, "5 shield gives +15% multiplier")
	check(b.heroes[0].shield == 1, "4 shield consumed, 1 remaining")
	
	# Case 3: 3 shield (<4) -> consumes 0 shield for +0%
	b.heroes[0].shield = 3
	ev.clear()
	mult = b._apply_rune_overcharge(ev, "ember", 0)
	check(mult == 1.0, "3 shield gives 1.0 multiplier")
	check(b.heroes[0].shield == 3, "0 shield consumed")

func test_forest_run_forge_lifecycle() -> void:
	var graph_script = preload("res://scripts/forest_random_generator.gd")
	var map = graph_script.generate(101)
	var run := ForestRun.new()
	run.initialize(map, 0, [], [], 101)
	
	# Find a forge node and move/place run there
	var forge_node_id := ""
	for nid in map.nodes:
		if map.nodes[nid].kind == ForestMapGraph.NodeKind.FORGE:
			forge_node_id = nid
			break
	check(not forge_node_id.is_empty(), "Forge node exists in map")
	
	run.position = forge_node_id
	run.pending = "forge"
	run.carried_cost = 10
	
	# Validation: invalid rune rejected
	var check_res := run.can_enchant_card("cleave", "rune_unknown")
	check(not check_res.ok, "Unknown rune rejected")
	
	# Validation: card not in team rejected
	check_res = run.can_enchant_card("sakuya_knife", "rune_feather")
	check(not check_res.ok, "Card not in team rejected")
	
	# Validation: successful enchant
	var ok := run.enchant_card("cleave", "rune_feather")
	check(ok, "Enchant card succeeded")
	check(run.carried_cost == 6, "4 cost deducted")
	check(run.deck_enchants.get("cleave") == "rune_feather", "Rune stored in run")
	check(run.cleared.has(forge_node_id), "Forge node marked cleared")
	check(run.pending.is_empty(), "Pending state cleared")
	
	# Advance to next floor: enchants preserved
	var map2 = graph_script.generate(102)
	run.advance_to_next_floor(map2, 102)
	check(run.floor_level == 2, "Advanced to floor 2")
	check(run.deck_enchants.get("cleave") == "rune_feather", "Deck enchant preserved across floors")
	
	# Restart / initialize: enchants cleared
	run.initialize(map, 0, [], [], 101)
	check(run.deck_enchants.is_empty(), "New run clears enchants")

func test_forge_hero_swap_and_shared_cards() -> void:
	var graph_script = preload("res://scripts/forest_random_generator.gd")
	var map = graph_script.generate(103)
	var run := ForestRun.new()
	run.initialize(map, 0, [], [], 103) # Lineup: Ash, Blade, Weaver
	
	run.deck_enchants["cleave"] = "rune_feather"      # Shared card
	run.deck_enchants["steady_edge"] = "rune_impact"  # Blade personal card
	run.deck_enchants["observe"] = "rune_leech"       # Ash personal card
	
	var active := run.get_active_deck_enchants()
	check(active.size() == 3, "All 3 enchants active with initial lineup")
	
	# Swap out Blade for Sakuya
	run.set_lineup_and_deck([Rules.ASH_ID, Rules.SAKUYA_ID, Rules.WEAVER_ID], [])
	active = run.get_active_deck_enchants()
	check(active.has("cleave"), "Shared card remains active after swap")
	check(active.has("observe"), "Ash personal card remains active")
	check(not active.has("steady_edge"), "Blade card is dormant when benched")
	
	# Swap Blade back in
	run.set_lineup_and_deck([Rules.ASH_ID, Rules.BLADE_ID, Rules.WEAVER_ID], [])
	active = run.get_active_deck_enchants()
	check(active.has("steady_edge"), "Blade card enchant restored when unbenched")

func test_runes_backward_compatibility() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [])
	check(b.deck_enchants.is_empty(), "Default start has empty deck_enchants")
	check(b.get_card_cost("cleave") == 3, "Default cleave cost is original 3")
	check(b.get_card_cost("needle") == 1, "Default needle cost is original 1")
