extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	test_fracture_lifecycle()
	test_half_health_stagger()
	test_momentum_chain()
	test_shared_support()
	test_specialized_support()
	test_shared_attacks()
	test_next_action_bonuses()
	print("CORE_COMBAT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(event: Dictionary) -> bool: return event.type == type)

func test_fracture_lifecycle() -> void:
	var battle := Rules.new()
	var weaknesses := [
		["斩击", "重击"], ["突刺", "重击"], ["重击"], ["斩击", "突刺"],
		["突刺", "重击"], ["重击"], ["突刺", "斩击"], ["斩击", "突刺"],
	]
	for encounter in weaknesses.size():
		battle.start(42, encounter)
		for i in battle.enemies.size():
			var enemy := battle.enemies[i]
			check(enemy.weakness == weaknesses[encounter][i] and enemy.fracture == 0, "Enemy starts with its assigned weakness and zero fracture")

	battle.start(42)
	var scout := battle.enemies[0]
	var events: Array[Dictionary] = []
	scout.shield = 100
	battle._attack(events, true, 0, 0, 1, 0, 1, 0.0, "needle")
	check(scout.fracture == 0, "A different attack tag leaves fracture unchanged")
	battle._attack(events, true, 0, 0, 1, 0, 3, 0.0, "ember")
	var fractures := of_type(events, "fracture_hit")
	check(fractures.size() == 3 and fractures[2].fracture == 3 and fractures[2].tag == "斩击", "Every matching hit builds fracture through shields")
	check(scout.is_shattered and scout.shield == 0 and of_type(events, "shatter_stagger").size() == 1, "Third fracture shatters and strips remaining shield")
	check(battle._deal_hit(events, true, 0, 0, 8, 1, 1, false, "ember") == 8, "Shatter vulnerability waits until the next round")
	check(scout.fracture == 3 and of_type(events, "shatter_stagger").size() == 1, "Fracture is capped and shatter does not repeat during its window")
	battle.lock_and_resolve()
	battle.next_round()
	check(scout.speed_min == 1 and scout.speed_max == 1, "The next round locks speed bounds to one")
	check(battle.enemy_slots.slice(0, 3).all(func(slot: Dictionary) -> bool: return slot.speed == 1), "All of the shattered enemy's slots have speed one")
	check(battle._deal_hit(events, true, 0, 0, 8, 1, 1) == 12, "Shatter gives 50 percent vulnerability on its scheduled round")
	battle.enable_evolution(true, false)
	scout.is_staggered = true
	check(battle._deal_hit(events, true, 0, 0, 8, 1, 1) == 12, "Shatter sets the total vulnerability to 50 percent even with ordinary stagger")
	battle.lock_and_resolve()
	battle.next_round()
	check(not scout.is_shattered and scout.fracture == 0 and scout.speed_min == 4 and scout.speed_max == 7, "Recovery resets fracture and restores the original speed bounds")
	check(battle._deal_hit(events, true, 0, 0, 8, 1, 1) == 8, "Vulnerability lasts exactly one round")

func test_half_health_stagger() -> void:
	var battle := Rules.new()
	battle.start(42)
	battle.enable_evolution(true, false)
	var scout := battle.enemies[0]
	var events: Array[Dictionary] = []
	scout.hp = 29
	check(not battle._check_stagger_after_action(events, scout, false, 30) and not scout.is_shattered, "Exactly half health does not shatter")
	scout.hp = 28
	scout.shield = 6
	battle._check_stagger_after_action(events, scout, false, 29)
	check(scout.is_staggered and scout.is_shattered and scout.fracture == 0 and scout.shield == 0, "Falling under half health while staggered can shatter without three fractures")
	check(of_type(events, "shatter_stagger").size() == 1, "Bloodline shatter emits once")

func test_momentum_chain() -> void:
	var battle := Rules.new()
	battle.start(42, Rules.TRAINING_ENCOUNTER)
	var events: Array[Dictionary] = []
	var dummy := battle.enemies[0]
	var enemy_slot := battle.enemy_slots[0]
	var hero_slot := {"unit": 0, "key": "steady"}
	dummy.shield = 999
	for i in 4:
		battle.custom_coin_rolls.assign([0.99, 0.99, 0.99])
		battle._clash(events, hero_slot, enemy_slot)
		var clash := of_type(events, "clash").back() as Dictionary
		check(clash.left == 7 + mini(i, 3), "The next clash uses the existing momentum as base power")
	var gains := of_type(events, "momentum_gain")
	check(gains.size() == 4 and gains[0].momentum == 1 and gains[3].momentum == 3, "A victory increments momentum up to three")
	var strikes := of_type(events, "strike")
	check(strikes[0].damage == 2 and strikes[1].damage == 2 and strikes[0].blocked > 0, "First win adds true damage per hit, even into full shields")
	check(strikes.back().momentum_damage == 6 and strikes.back().damage == 6, "Three momentum gives six HP damage through shields")
	var before_reflect := int(dummy.hp)
	battle._deal_hit(events, true, 0, 0, 1, 1, 1, true)
	check(dummy.hp == before_reflect, "Passive reflection does not add attack momentum")
	hero_slot.key = "needle"
	enemy_slot.key = "nova"
	battle.custom_coin_rolls.assign([0.99, 0.99, 0.0, 0.0, 0.0, 0.99, 0.0, 0.0, 0.0])
	battle._clash(events, hero_slot, enemy_slot)
	check(battle.round_momentum == 0 and of_type(events, "momentum_break").size() == 1, "A loss clears an active momentum chain")
	battle.round_momentum = 3
	battle.lock_and_resolve()
	battle.next_round()
	check(battle.round_momentum == 0, "Preparing the next round resets momentum")

func test_shared_support() -> void:
	var battle := Rules.new()
	var config := {"deck_enchants": {"cover": "rune_feather"}}
	battle.start(42, Rules.TRAINING_ENCOUNTER, false, false, [], null, false, [], [], config)
	var cover := battle.hand.find("cover")
	var guard := battle.hand.find("guard")
	var steady := battle.hand.find("steady")
	check(not battle.assign_support(steady, 0).is_empty(), "An attack cannot be assigned to the support slot")
	check(not battle.assign_support(cover, 0).is_empty(), "The support slot respects card ownership")
	check(battle.assign(guard, 2, -1).is_empty(), "A guard can also occupy a regular slot")
	check(not battle.assign_support(guard, 2).is_empty(), "A card instance assigned to a regular slot cannot be reserved twice")
	battle.cancel(2)
	check(battle.assign_support(guard, 0).is_empty(), "A common guard can be assigned")
	check(not battle.assign(guard, 2, -1).is_empty(), "A reserved support instance cannot also be used as a regular action")
	check(battle.assign_support(cover, 2).is_empty() and battle.reserved_cost() == 1, "Replacing support frees the old reserve and uses discounted Cost")
	battle.cancel_support()
	check(not battle.shared_support_slot.active and battle.reserved_cost() == 0 and battle.cost == Rules.START_COST, "Cancellation frees the reservation without charging")
	battle.cost = 2
	check(battle.assign_support(cover, 2).is_empty() and not battle.assign(steady, 0, 0).is_empty(), "Regular actions account for the support reserve")
	battle.cost = 3
	check(battle.assign(steady, 0, 0).is_empty(), "Support leaves the regular attack slot available")
	var events := battle.lock_and_resolve()
	check(events[0].type == "support_slot_resolve" and events[0].paid == 1, "Phase zero charges the configured support before the timeline")
	var reveal := of_type(events, "reveal")[0] as Dictionary
	check(reveal.snapshot.heroes[2].shield == 9 and reveal.snapshot.heroes[0].shield == 6, "Weaver support grants its own and team shields before the reveal")
	check(of_type(events, "support_slot_resolve").size() == 1 and battle.plays == 2 and not battle.shared_support_slot.active, "Support consumes one play and clears the slot after use")
	check(battle.lock_and_resolve().is_empty(), "Locking again cannot repeat support")

func test_specialized_support() -> void:
	var battle := Rules.new()
	battle.start(42, Rules.TRAINING_ENCOUNTER, false, false, [Rules.REIMU_ID, Rules.ZIXI_ID, Rules.ZIXINGYC_ID])
	battle.heroes[0].dream_due = 4
	battle.heroes[0].dream_orbs = 1
	check(battle.assign_support(battle.hand.find("demon_seal"), 0).is_empty(), "Enemy-targeted support accepts a default target")
	var events := battle.lock_and_resolve()
	check(battle.enemies[0].seal_pending and battle.heroes[0].dream_orbs == 1 and of_type(events, "clash").is_empty(), "Sealing applies its card effect without a clash or dream progress")
	battle.next_round()
	check(battle.assign_support(battle.hand.find("zixi_martingale"), 1).is_empty(), "Martingale uses the shared support slot")
	battle.lock_and_resolve()
	check(battle.heroes[1].shield == 4, "Martingale grants its base shield without a clash")
	battle.next_round()
	check(battle.assign_support(battle.hand.find("zixingyc_yesterday"), 2).is_empty(), "Yesterday uses the shared support slot")
	battle.lock_and_resolve()
	check(battle.heroes[2].shield == 10 and battle.heroes[2].memory_log.size() == 1, "Yesterday grants shield and its card-specific reflection")

func test_shared_attacks() -> void:
	for character in [Rules.MARISA_ID, Rules.PUFUFU_ID, Rules.ZIWU_ID]:
		var battle := Rules.new()
		battle.start(42, Rules.TRAINING_ENCOUNTER, false, false, [character])
		check(battle.assign(battle.hand.find("cleave"), 0, 0).is_empty(), "A specialist can assign a common attack")
		var events := battle.lock_and_resolve()
		check(battle.enemies[0].fracture == 2 and of_type(events, "strike").size() == 2, "A specialist's common attack still deals both tagged hits")

func test_next_action_bonuses() -> void:
	var battle := Rules.new()
	battle.start(42, Rules.TRAINING_ENCOUNTER, false, false, [Rules.ASH_ID, Rules.ZIXI_ID, Rules.ZIWU_ID])
	var ash := battle.heroes[0]
	ash.next_clash["prelude"] = 2
	ash.next_clash["harmony"] = 4
	ash.next_damage_bonus["infusion"] = 5
	ash.next_damage_bonus["echo"] = 2
	check(battle.heroes[1].next_clash.is_empty() and battle.heroes[1].next_damage_bonus.is_empty(), "Each hero has independent next-action bonuses")

	var events: Array[Dictionary] = []
	battle._deal_hit(events, true, 0, 0, 1, 1, 1, true)
	battle._deal_hit(events, true, 0, 0, 0, 1, 1)
	check(ash.next_damage_bonus.size() == 2, "Reflection and zero-damage hits preserve an attack bonus")
	battle.enemies[0].shield = 20
	battle.custom_coin_rolls.assign([0.99, 0.99, 0.99])
	battle._clash(events, {"unit": 0, "key": "steady"}, battle.enemy_slots[0])
	check(of_type(events, "clash").back().left == 13 and ash.next_clash.is_empty(), "The first real clash consumes the sum of next-clash bonuses")
	var strikes := of_type(events, "strike")
	check(strikes[2].next_damage_bonus == 7 and strikes[2].blocked >= 14, "The first damaging hit adds all attack bonuses before shield absorption")
	check(ash.next_damage_bonus.is_empty() and not strikes[3].has("next_damage_bonus"), "Later hits do not reuse the spent attack bonuses")

	for i in range(1, 3):
		var baseline := battle.heroes[i].duplicate(true)
		battle.heroes[i].next_clash["harmony"] = 4
		battle.round_momentum = 0
		battle.custom_coin_rolls.assign([0.99, 0.99, 0.99])
		events.clear()
		battle._clash(events, {"unit": i, "key": "steady"}, battle.enemy_slots[0])
		var buffed_clash := int(of_type(events, "clash").back().left)
		check(battle.heroes[i].next_clash.is_empty(), "Specialist clashes also consume the shared container")
		battle.heroes[i] = baseline
		battle.round_momentum = 0
		battle.custom_coin_rolls.assign([0.99, 0.99, 0.99])
		events.clear()
		battle._clash(events, {"unit": i, "key": "steady"}, battle.enemy_slots[0])
		check(buffed_clash == int(of_type(events, "clash").back().left) + 4, "Character-specific logic does not count the shared bonus twice")
