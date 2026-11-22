extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Run = preload("res://scripts/forest_run.gd")
const MapGraph = preload("res://scripts/forest_map_graph.gd")

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAILURE: " + label)
	else:
		print("  PASS: " + label)

func _initialize() -> void:
	print("--- Running test_content_expansion ---")
	_test_shop_revival()
	_test_gamble_and_events()
	_test_new_enemies()
	_test_new_items()
	print("CONTENT_EXPANSION_TEST failures=", failures)
	quit(1 if failures else 0)

func _test_shop_revival() -> void:
	print("Testing shop teammate revival...")
	var graph = MapGraph.new()
	var run = Run.new()
	run.initialize(graph)
	run.carried_cost = 25
	run.party_hp.assign([40, 0, 35])
	run.party_max_hp.assign([48, 50, 46])

	# Check dead slots detection
	var dead := run.get_dead_hero_slots()
	check(dead == [1], "get_dead_hero_slots identifies hero at slot 1")

	# Check can_revive_hero
	check(not run.can_revive_hero(0).ok, "living hero cannot be revived")
	check(run.can_revive_hero(1).ok, "dead hero can be revived with sufficient cost")

	# Insufficient cost check
	run.carried_cost = 5
	check(not run.can_revive_hero(1).ok, "cannot revive hero with insufficient cost")

	# Successful shop revival
	run.carried_cost = 15
	var res := run.shop_revive_hero(1)
	check(res.ok, "shop_revive_hero succeeds")
	check(run.carried_cost == 5, "deducted 10 cost on revival")
	check(run.party_hp[1] == 20, "revives hero at 40% max HP (50 * 0.4 = 20)")
	check(run.get_dead_hero_slots().is_empty(), "dead hero list is now empty")

	# Greedy contract discount check
	run.relics.append("greedy_contract")
	check(run.get_revive_cost() == 7, "greedy contract discounts revival cost from 10 to 7")

func _test_gamble_and_events() -> void:
	print("Testing high-randomness gamble and event variants...")
	var graph = MapGraph.new()
	var run = Run.new()
	run.initialize(graph)

	# Gamble - High roller (choice 1)
	run.pending = "gamble"
	run.carried_cost = 15
	run.party_hp.assign([30, 30, 30])
	var choice_res := run.apply_choice(1)
	check(choice_res, "gamble choice 1 (high roller) resolves successfully")
	check(run.pending.is_empty(), "pending cleared after gamble")

	# Gamble - Blood Roulette (choice 2)
	run.pending = "gamble"
	run.party_hp.assign([40, 40, 40])
	var old_destiny: int = run.destiny
	var old_fatigue: int = run.fatigue
	var blood_res := run.apply_choice(2)
	check(blood_res, "gamble choice 2 (blood roulette) resolves successfully")
	check(run.party_hp[0] < 40 and run.party_hp[1] < 40, "blood roulette deducted health from party")

	# Event - Variant 3 (Wishing Well)
	run.pending = "event"
	run.event_variant = 3
	run.carried_cost = 10
	var wish_res := run.apply_choice(0)
	check(wish_res, "event variant 3 (wish well coin drop) resolves")

	# Event - Variant 4 (Cursed Lockbox)
	run.pending = "event"
	run.event_variant = 4
	run.carried_cost = 10
	var lock_res := run.apply_choice(1)
	check(lock_res, "event variant 4 (careful lockpick) resolves")

	# Event - Variant 5 (Mad Prophet)
	run.pending = "event"
	run.event_variant = 5
	run.carried_cost = 10
	run.fatigue = 4
	var prophet_res := run.apply_choice(1)
	check(prophet_res and run.fatigue == 0 and run.items.has("clarity_elixir"), "mad prophet elixir purchase eliminates fatigue and grants clarity_elixir")

func _test_new_enemies() -> void:
	print("Testing new enemies (Encounters 6 & 7)...")
	var b = Rules.new()

	# Encounter 6: Phantom Assassin & Lich
	b.start(42, 6)
	check(b.enemies.size() == 2, "encounter 6 has 2 enemies")
	check(b.enemies[0].kind == "phantom" and b.enemies[0].name == "幽魂刺客", "encounter 6 enemy 0 is phantom")
	check(b.enemies[1].kind == "lich" and b.enemies[1].name == "蚀骨巫师", "encounter 6 enemy 1 is lich")
	check(b.enemies[0].speed_min == 6 and b.enemies[0].speed_max == 9, "phantom has high speed 6..9")
	check(b.enemy_slots[0].key == "shadow_strike", "phantom slot 0 uses shadow_strike")

	# Lich guard provides shield to living ally
	var ev: Array[Dictionary] = []
	b.enemies[0].shield = 0
	b.enemies[1].shield = 0
	b._solo(ev, {"key": "guard", "unit": 1, "category": 2}, false)
	check(b.enemies[1].shield == 11, "lich self-guard is 11")
	check(b.enemies[0].shield == 5, "lich shields living phantom ally with 5 shield")

	# Encounter 7: Wasteland Marauder & Wyvern
	b.start(42, 7)
	check(b.enemies.size() == 2, "encounter 7 has 2 enemies")
	check(b.enemies[0].kind == "marauder" and b.enemies[0].name == "荒原掠夺者", "encounter 7 enemy 0 is marauder")
	check(b.enemies[1].kind == "wyvern" and b.enemies[1].name == "狂暴飞龙", "encounter 7 enemy 1 is wyvern")
	check(b.enemies[1].max_hp >= 135, "wyvern has robust boss-like HP")
	check(b.enemy_slots[3].key == "wyvern_breath", "wyvern slot 0 uses wyvern_breath")

	# ENCOUNTER_NAMES check
	check(Rules.ENCOUNTER_NAMES.size() == 8, "ENCOUNTER_NAMES has all 8 encounters")

func _test_new_items() -> void:
	print("Testing tactical consumables...")
	var b = Rules.new()
	b.start(42, 0)
	b.active_items.assign(["phoenix_feather", "shatter_bomb", "clarity_elixir", "gambler_die"])

	# Test shatter_bomb in combat
	b.enemies[0].shield = 20
	b.enemies[1].shield = 15
	var shatter_res := b.use_item("shatter_bomb")
	check(shatter_res.ok, "shatter_bomb use_item succeeds")
	check(b.enemies[0].shield == 8 and b.enemies[1].shield == 3, "shatter_bomb destroys 12 shield on all enemies")
	check(b.round_clash_bonus == 1, "shatter_bomb grants +1 clash power")

	# Test clarity_elixir in combat
	var old_cost: int = b.cost
	var elixir_res := b.use_item("clarity_elixir")
	check(elixir_res.ok and b.cost == old_cost + 4, "clarity_elixir grants +4 cost")

	# Test phoenix_feather in combat
	b.heroes[0].hp = 10
	b.heroes[1].hp = 15
	var feather_res := b.use_item("phoenix_feather")
	check(feather_res.ok, "phoenix_feather use_item succeeds")
	check(b.heroes[0].hp == 20 and b.heroes[0].shield >= 6, "phoenix_feather heals 10 HP and grants 6 shield")

	# Test gambler_die in combat
	var die_res := b.use_item("gambler_die")
	check(die_res.ok, "gambler_die use_item succeeds")

	# Test phoenix_feather out of combat (revival in exploration)
	var graph = MapGraph.new()
	var run = Run.new()
	run.initialize(graph)
	run.party_hp.assign([30, 0, 30])
	run.party_max_hp.assign([48, 50, 46])
	var dead := run.get_dead_hero_slots()
	check(dead == [1], "hero 1 is dead")
	var feather_revive := run.revive_hero_with_feather(dead[0], 0.30)
	check(feather_revive.ok and run.party_hp[1] == 15, "phoenix feather revives dead hero at 30% max HP")
