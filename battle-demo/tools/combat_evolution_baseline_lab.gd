extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")

func _initialize() -> void:
	print("==================================================")
	print("《余烬交锋》阶段 0 · 基线与极端值复核实验室")
	print("==================================================")
	_test_extreme_cases()
	_test_matrix_simulations()
	quit(0)

func _test_extreme_cases() -> void:
	print("\n--- 1. 极端场景精确复现 ---")
	
	# Case 1: 单币 marisa_spark (基础点数 20, 1币) vs 满三币 nova (基础点数 5, 币值 3, 3币)
	# 规则：双方进入拼点，败者掉一币，直到一方硬币归零。
	# 魔理沙仅 1 币，必须连续赢 3 次拼点才能完全击碎 nova 的 3 枚币；任何一次输掉即退场。
	# 若我方正面率 65%，敌方正面率 50%：
	# 单次掷币：魔理沙出正面 20，出反面 0。nova 满三币范围 5 ~ 14。
	# 当魔理沙为反面(0)时，必然败于 nova(>=5)；当魔理沙为正面(20)时，必然胜于 nova(<=14)。
	# 因此魔理沙单次胜率精确等于正面率 0.65。三连胜概率为 0.65^3 = 27.4625%。
	print("【案例 1：极限火花(1币) vs 破晓(3币)】")
	var spark_wins := 0
	var total_trials := 10000
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in total_trials:
		var nova_coins := 3
		var spark_coins := 1
		while nova_coins > 0 and spark_coins > 0:
			var spark_heads := rng.randf() < 0.65
			var nova_heads_count := 0
			for c in nova_coins:
				if rng.randf() < 0.50:
					nova_heads_count += 1
			var spark_score := 20 if spark_heads else 0
			var nova_score := 5 + nova_heads_count * 3
			if spark_score > nova_score:
				nova_coins -= 1
			elif spark_score < nova_score:
				spark_coins -= 1
		if spark_coins > 0:
			spark_wins += 1
	var sim_win_rate: float = float(spark_wins) / float(total_trials) * 100.0
	print("  理论胜率: 27.46% | 蒙特卡洛 10000 次模拟胜率: " + str(snapped(sim_win_rate, 0.01)) + "%")
	print("  结论：单币高威力卡在多币对局中极具方差，一旦拼败，敌方满3币进入无阻挡攻击(伤害高至10+14+14=38)，易直接导致满血40点角色濒死/退场！")
	
	# Case 2: 同单位同回合两次最终拼败
	print("\n【案例 2：同单位同回合两次最终拼败】")
	var b2 := Rules.new()
	b2.start(1337, 0, false, false, [Rules.ASH_ID], ["cleave", "ember", "steady"])
	print("  1人灰烬队伍行动格总数: %d，敌方行动格: %d" % [b2.hero_slots.size(), b2.enemy_slots.size()])
	print("  若该角色在第 1 格拼败受创，且原案在第 2 格拼败再次触发熄灭：全回合行动归零，失去全部反制手段。")
	
	# Case 3: 50% 血线跨越
	print("\n【案例 3：跨越 50% 血线】")
	var ash_max_hp: int = 48
	var hp_before := 26 # > 50% (24)
	var incoming_dmg := 8
	var hp_after := hp_before - incoming_dmg # 18 (< 50%)
	print("  初始 HP: %d (54.2%%) -> 遭受伤害: %d -> 结算 HP: %d (37.5%%)" % [hp_before, incoming_dmg, hp_after])
	print("  判定：首次由 >=50% 跌入 <50%，触发失衡。")

func _test_matrix_simulations() -> void:
	print("\n--- 2. 场景矩阵模拟（多场自动战斗基线统计）---")
	print("配置：3 阵容 (1人灰烬 / 2人灰烬长锋 / 3人常规队) × 3 敌人组 (0:斥候盾卫 / 1:追猎者 / 5:巨像Boss)")
	
	var team_configs := [
		{"name": "1人队(灰烬)", "lineup": [Rules.ASH_ID], "deck": ["cleave", "ember", "needle"]},
		{"name": "2人队(灰烬+长锋)", "lineup": [Rules.ASH_ID, Rules.BLADE_ID], "deck": ["cleave", "ember", "steady", "guard"]},
		{"name": "3人队(常规三人)", "lineup": [Rules.ASH_ID, Rules.BLADE_ID, Rules.WEAVER_ID], "deck": []}
	]
	
	var encounters := [
		{"id": 0, "name": "普通遭遇(斥候+盾卫)"},
		{"id": 1, "name": "精英遭遇(追猎者)"},
		{"id": 5, "name": "关底首领(210HP 烬心巨像)"}
	]
	
	for tc in team_configs:
		print("\n--------------------------------------------------")
		print("阵容: %s" % tc.name)
		print("--------------------------------------------------")
		for enc in encounters:
			var runs_count := 100
			var total_rounds := 0
			var total_damage_taken := 0
			var damage_list: Array[int] = []
			var victories := 0
			var wipes := 0
			var boss_idle_rounds := 0
			
			for seed_i in runs_count:
				var current_seed := 20000 + seed_i * 13
				var battle := Rules.new()
				battle.start(current_seed, enc.id, false, false, tc.lineup, tc.deck)
				battle.cost = 30
				
				var initial_team_hp: int = 0
				for h in battle.heroes:
					initial_team_hp += int(h.hp)
					
				var round_limit := 12
				while battle.outcome.is_empty() and battle.turn < round_limit:
					# 自动安排
					_auto_plan_battle(battle)
					var events := battle.lock_and_resolve()
					
					# 观察 Boss 行为
					if enc.id == 5:
						var boss_acted := false
						for e in events:
							if e.get("type") == "strike" and not bool(e.get("allied", true)):
								boss_acted = true
								break
						if not boss_acted:
							boss_idle_rounds += 1
							
					if battle.outcome.is_empty():
						battle.next_round()
						
				var final_team_hp: int = 0
				for h in battle.heroes:
					final_team_hp += int(h.hp)
				var dmg_taken := maxi(0, initial_team_hp - final_team_hp)
				damage_list.append(dmg_taken)
				total_damage_taken += dmg_taken
				total_rounds += battle.turn
				if battle.outcome == "victory":
					victories += 1
				else:
					wipes += 1
					
			damage_list.sort()
			var p50_idx := int(damage_list.size() * 0.50)
			var p95_idx := int(damage_list.size() * 0.95)
			var p50_dmg: int = damage_list[mini(p50_idx, damage_list.size() - 1)]
			var p95_dmg: int = damage_list[mini(p95_idx, damage_list.size() - 1)]
			var avg_rounds: float = float(total_rounds) / float(runs_count)
			var win_rate: float = float(victories) / float(runs_count) * 100.0
			
			print("  [敌组 %d: %-18s] 胜率: %5.1f%% | 平均回合: %4.1f | P50承伤: %2d | P95承伤: %2d | 团灭数: %d" % [
				enc.id, enc.name, win_rate, avg_rounds, p50_dmg, p95_dmg, wipes
			])
			if enc.id == 5:
				print("    -> 巨像首领战中，首领平均每场未命中回合数: %.2f" % (float(boss_idle_rounds) / float(runs_count)))

func _auto_plan_battle(battle: DemoBattleRules) -> void:
	var covered := {}
	for slot in battle.hero_slots:
		if slot.active and Rules.targets_enemy(slot.key) and battle.can_clash(slot, battle.enemy_slots[slot.target]):
			covered[slot.target] = true
	var slots: Array[Dictionary] = battle.hero_slots.duplicate()
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var prio_a := 0 if int(a.category) == 1 else (1 if int(a.category) == 0 else 2)
		var prio_b := 0 if int(b.category) == 1 else (1 if int(b.category) == 0 else 2)
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
		for card_idx in battle.hand.size():
			var key: String = battle.hand[card_idx]
			var owner: int = Rules.card_owner(key)
			if owner != -1 and owner != slot.unit:
				continue
			if Rules.targets_enemy(key):
				for target in targets:
					var clashes: bool = battle.can_clash(slot, battle.enemy_slots[target])
					if covered.has(target) and clashes:
						continue
					if battle.assign(card_idx, slot.id, target).is_empty():
						if clashes:
							covered[target] = true
						break
			else:
				battle.assign(card_idx, slot.id, -1)
			if slot.active:
				break
