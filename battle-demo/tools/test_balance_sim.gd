extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const CardPool = preload("res://scripts/card_pool.gd")

func _initialize() -> void:
	print("==================================================")
	print("《余烬交锋》阶段 3+4 真实规则平衡性模拟实验室")
	print("规则：初始 Cost 18, 每回合抽 6 张, 尖塔初始牌库, 大招格兼放攻击牌, 夹击 +3 增伤")
	print("==================================================")
	_run_simulation_matrix()
	quit(0)

func _run_simulation_matrix() -> void:
	var teams := [
		{"name": "3人常规队(灰烬+长锋+织火)", "lineup": [Rules.ASH_ID, Rules.BLADE_ID, Rules.WEAVER_ID]},
		{"name": "2人小队(灰烬+长锋)", "lineup": [Rules.ASH_ID, Rules.BLADE_ID]},
		{"name": "1人单兵(灰烬)", "lineup": [Rules.ASH_ID]}
	]
	
	var encounters := [
		{"id": 0, "name": "普通遭遇(斥候+盾卫)"},
		{"id": 1, "name": "精英遭遇(祭司+行刑者)"},
		{"id": 3, "name": "巡游恶兽(潜伏犬+毒蛛)"},
		{"id": 5, "name": "关底首领(210HP 烬心巨像)"}
	]
	
	for tm in teams:
		var starter_deck: Array[String] = CardPool.build_starter_deck(tm.lineup)
		print("\n--------------------------------------------------------------------------------")
		print("【阵容】%s | 初始牌库规模: %d 张" % [tm.name, starter_deck.size()])
		print("  牌库清单: %s" % str(starter_deck))
		print("--------------------------------------------------------------------------------")
		
		for enc in encounters:
			var trials := 100
			var wins := 0
			var total_turns := 0
			var total_dmg_taken := 0
			var damages: Array[int] = []
			var boss_idle_turns := 0
			var unplayed_hands_sum := 0
			var avg_cost_left_sum := 0
			
			for trial_i in trials:
				var battle := Rules.new()
				var seed_val := 30000 + trial_i * 31
				battle.flex_attack_in_ultimate = true
				battle.unopposed_bonus_enabled = true
				battle.deck_cycle_enabled = true
				battle.hand_draw_count = 6
				
				# Start battle with lineup and starter deck
				battle.start(seed_val, enc.id, false, false, tm.lineup, starter_deck)
				
				var max_rounds := 15
				var team_max_hp := 0
				for h in battle.heroes:
					team_max_hp += int(h.hp)
					
				while battle.outcome.is_empty() and battle.turn <= max_rounds:
					_auto_plan(battle)
					var events := battle.lock_and_resolve()
					if enc.id == 5:
						var boss_acted := false
						for ev in events:
							if ev.get("type") == "strike" and not bool(ev.get("allied", true)):
								boss_acted = true
								break
						if not boss_acted:
							boss_idle_turns += 1
							
					if battle.outcome.is_empty():
						battle.next_round()
						
				total_turns += battle.turn
				avg_cost_left_sum += battle.cost
				unplayed_hands_sum += battle.hand.size()
				
				var team_end_hp := 0
				for h in battle.heroes:
					team_end_hp += int(h.hp)
				var dmg := maxi(0, team_max_hp - team_end_hp)
				damages.append(dmg)
				total_dmg_taken += dmg
				
				if battle.outcome == "victory":
					wins += 1
					
			damages.sort()
			var p50 := damages[int(trials * 0.50)]
			var p90 := damages[mini(int(trials * 0.90), damages.size() - 1)]
			var win_rate := float(wins) / float(trials) * 100.0
			var avg_turns := float(total_turns) / float(trials)
			var avg_dmg := float(total_dmg_taken) / float(trials)
			var avg_cost_left := float(avg_cost_left_sum) / float(trials)
			
			print("  [敌组 %d: %-16s] 胜率: %5.1f%% | 平均回合: %4.1f | 均承伤: %4.1f (P50: %2d, P90: %2d) | 结余Cost: %4.1f" % [
				enc.id, enc.name, win_rate, avg_turns, avg_dmg, p50, p90, avg_cost_left
			])
			if enc.id == 5:
				print("    -> 巨像首领战，巨像未命中率: %.2f%%" % (float(boss_idle_turns) / float(trials * avg_turns) * 100.0))

func _auto_plan(battle: Rules) -> void:
	var covered := {}
	for slot in battle.hero_slots:
		if slot.active and Rules.targets_enemy(slot.key) and battle.can_clash(slot, battle.enemy_slots[slot.target]):
			covered[slot.target] = true
			
	var slots: Array[Dictionary] = battle.hero_slots.duplicate()
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Attack (0) or Ultimate (1) first, Defense (2) last
		var prio_a := 0 if int(a.category) in [0, 1] else 1
		var prio_b := 0 if int(b.category) in [0, 1] else 1
		if prio_a != prio_b:
			return prio_a < prio_b
		return int(a.speed) > int(b.speed)
	)
	
	for slot in slots:
		if slot.active:
			continue
		var own_targets: Array[int] = []
		var intercepts: Array[int] = []
		var remaining_targets: Array[int] = []
		for enemy in battle.enemy_slots:
			if battle.enemies[enemy.unit].hp <= 0:
				continue
			if covered.has(enemy.id) or not battle.can_clash(slot, enemy):
				remaining_targets.append(enemy.id)
			elif enemy.target == slot.unit:
				own_targets.append(enemy.id)
			else:
				intercepts.append(enemy.id)
		var targets := own_targets + intercepts + remaining_targets
		
		# Card order prioritizing match to slot category
		var card_order := _get_card_order(battle, slot.unit, int(slot.category))
		for card in card_order:
			var key: String = battle.hand[card]
			if Rules.targets_enemy(key):
				for target in targets:
					var clashes: bool = battle.can_clash(slot, battle.enemy_slots[target])
					if covered.has(target) and (clashes or Rules.SKILLS[key].get("requires_clash", false)):
						continue
					if battle.assign(card, slot.id, target).is_empty():
						if clashes:
							covered[target] = true
						break
			else:
				battle.assign(card, slot.id, -1)
			if slot.active:
				break

func _get_card_order(battle: Rules, unit: int, slot_category: int) -> Array:
	var hero: Dictionary = battle.heroes[unit]
	var owner_id := int(hero.character_id)
	var cat_match: Array[int] = []
	var other_own: Array[int] = []
	var cat_shared: Array[int] = []
	var other_shared: Array[int] = []
	
	for card in battle.hand.size():
		var key: String = battle.hand[card]
		var card_cat := battle.category_for(key)
		var owner := Rules.card_owner(key)
		if owner == owner_id:
			if card_cat == slot_category:
				cat_match.append(card)
			else:
				other_own.append(card)
		elif owner < 0:
			if card_cat == slot_category:
				cat_shared.append(card)
			else:
				other_shared.append(card)
	return cat_match + other_own + cat_shared + other_shared
