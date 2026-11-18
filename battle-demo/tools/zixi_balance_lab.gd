extends SceneTree

# ZiXi 符卡平衡实验台
# 用途：用真实结算代码（scripts/battle_rules.gd）跑统计，供角色设计调数值用。
# 用法（在 battle-demo 目录）：
#   godot --headless --path . --script res://tools/zixi_balance_lab.gd -- --cards [--n=3000]
#   godot --headless --path . --script res://tools/zixi_balance_lab.gd -- --turn
#   godot --headless --path . --script res://tools/zixi_balance_lab.gd -- --speed
#   godot --headless --path . --script res://tools/zixi_balance_lab.gd -- --trace
# 只读取规则层，不修改任何游戏文件。

const Rules = preload("res://scripts/battle_rules.gd")
const ZiXi = Rules.ZiXi

const CARD_SLOT := {
	ZiXi.CENTRAL_LIMIT: 3,   # 进攻格
	ZiXi.CONVERGENCE: 3,     # 进攻格
	ZiXi.MARTINGALE: 5,      # 防御格
	ZiXi.ALMOST_SURE: 4,    # 大招格
}
const ENEMY_SLOT := {
	"needle": 0,   # 裂影斥候 进攻
	"ember": 3,    # 守墓盾卫 进攻
	"nova": 4,     # 守墓盾卫 大招
}
const ENEMY_LABEL := {
	"needle": "穿隙(斥候进攻)",
	"ember": "余烬斩(盾卫进攻)",
	"nova": "破晓(盾卫大招)",
}
const CARD_LABEL := {
	ZiXi.CENTRAL_LIMIT: "中心极限定理",
	ZiXi.CONVERGENCE: "几乎处处收敛",
	ZiXi.MARTINGALE: "鞅",
	ZiXi.ALMOST_SURE: "几乎必然",
}

var iterations := 3000


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--n="):
			iterations = int(arg.substr(4))
	if args.has("--cards"):
		_run_cards()
	elif args.has("--turn"):
		_run_turn()
	elif args.has("--speed"):
		_run_speed()
	elif args.has("--trace"):
		_run_trace()
	else:
		print("用法：--cards / --turn / --speed / --trace")
	quit(0)


# ---------- 公共工具 ----------

func make_battle(seed_value: int) -> DemoBattleRules:
	var battle := DemoBattleRules.new()
	battle.start(seed_value, 0, false, true)
	return battle


func set_godlike(battle: DemoBattleRules) -> void:
	for unit in battle.heroes:
		unit.hp = 9999
	for unit in battle.enemies:
		unit.hp = 9999


func solo_enemy(battle: DemoBattleRules, enemy_slot_id: int, key: String, target: int) -> void:
	for slot in battle.enemy_slots:
		slot.active = false
		slot.key = ""
	var enemy: Dictionary = battle.enemy_slots[enemy_slot_id]
	enemy.active = true
	enemy.key = key
	enemy.target = target
	enemy.speed = 4


func summarize(events: Array[Dictionary]) -> Dictionary:
	var result := {
		"rounds": 0, "win": 0, "lose": 0, "tie": 0,
		"dmg_out": 0, "dmg_in": 0, "refund": 0, "cancelled": 0,
		"intercept": 0, "engage": 0, "shield": 0,
	}
	var last_clash := {}
	for event in events:
		match event.type:
			"clash":
				result.rounds += 1
				last_clash = event
			"strike":
				if bool(event.allied):
					result.dmg_out += int(event.damage)
				else:
					result.dmg_in += int(event.damage)
			"refund", "stalemate":
				result.refund += int(event.amount)
				if event.type == "stalemate":
					result.tie += 1
			"cancelled":
				result.cancelled += 1
			"intercept":
				result.intercept += 1
			"engage":
				result.engage += 1
			"guard":
				result.shield += int(event.amount)
	if not last_clash.is_empty():
		if int(last_clash.get("hero_remaining", 0)) > 0:
			result.win = 1
		else:
			result.lose = 1
	return result


# ---------- 单卡对位统计 ----------

func _run_cards() -> void:
	print("=== 单卡对位（真实结算代码，%d 次/组）===" % iterations)
	print("胜率=拼点赢下全部硬币；主目标输出=打在拼点目标身上的伤害；溅射=轰炸打到另一个敌人的伤害；承伤=拼输时敌方剩余硬币打出的伤害")
	print("因果律=0 是裸牌数值；因果律=3 是攒满三层时的数值（因果律同时给我方 +3 拼点、给敌方 −3）")
	for card_key in CARD_LABEL.keys():
		for enemy_key in ENEMY_SLOT.keys():
			for mode in ["普通", "强化", "强化+因果律3"]:
				var enhanced: bool = mode != "普通"
				var causality: int = 3 if mode == "强化+因果律3" else 0
				var totals := {"win": 0, "lose": 0, "tie": 0, "main": 0.0, "splash": 0.0, "dmg_in": 0.0, "layer": 0.0}
				for i in iterations:
					var seed_value := 900000 + i * 7
					var battle := make_battle(seed_value)
					set_godlike(battle)
					solo_enemy(battle, ENEMY_SLOT[enemy_key], enemy_key, 1)
					var hero: Dictionary = battle.heroes[1]
					hero.metaphysics = 6
					hero.causality = causality
					var card_index: int = battle.hand.find(card_key)
					var error: String = battle.assign(card_index, CARD_SLOT[card_key], ENEMY_SLOT[enemy_key], enhanced)
					if not error.is_empty():
						print("安排失败：", error)
						return
					var primary: int = int(battle.enemy_slots[ENEMY_SLOT[enemy_key]].unit)
					var events: Array[Dictionary] = battle.lock_and_resolve()
					var info: Dictionary = summarize(events)
					totals.win += int(info.win)
					totals.lose += int(info.lose)
					totals.tie += int(info.tie)
					totals.dmg_in += float(info.dmg_in)
					totals.layer += float(hero.metaphysics)
					for event in events:
						if event.type == "strike" and bool(event.allied):
							if int(event.target) == primary:
								totals.main += float(event.damage)
							else:
								totals.splash += float(event.damage)
				var n := float(iterations)
				print("%s(%s) vs %s：胜率 %5.1f%%｜主目标 %6.2f｜溅射 %6.2f｜承伤 %5.2f｜超形上学 %4.2f" % [
					CARD_LABEL[card_key], mode, ENEMY_LABEL[enemy_key],
					100.0 * float(totals.win) / n,
					float(totals.main) / n,
					float(totals.splash) / n,
					float(totals.dmg_in) / n,
					float(totals.layer) / n,
				])


# ---------- 回合级模拟 ----------

# 公开信息策略：只用玩家看得见的东西（敌方行动格类别、目标箭头、速度、我方费用）
var covered := {}

func plan_round(battle: DemoBattleRules) -> void:
	covered = {}
	var zixi: Dictionary = battle.heroes[1]

	# 1) ZiXi 进攻格：优先接下指向队友的大招，其次守自己的进攻格
	var candidates := _zixi_candidates(battle, 1)
	if candidates.size() > 0:
		var first_target: int = int(candidates[0])
		var first_slot: Dictionary = battle.enemy_slots[first_target]
		var attack_key: String = ZiXi.CONVERGENCE if int(first_slot.category) == 1 else ZiXi.CENTRAL_LIMIT
		var use_enhance: bool = int(zixi.metaphysics) >= ZiXi.ENHANCE_COST
		if not battle.assign(battle.hand.find(attack_key), 3, first_target, use_enhance).is_empty():
			battle.assign(battle.hand.find(attack_key), 3, first_target, false)
		covered[first_target] = true

		# 2) ZiXi 大招格：几乎必然（有 3 层且够钱就强化）
		if candidates.size() > 1:
			var ulti_target: int = int(candidates[1])
			if battle.cost - battle.reserved_cost() >= int(Rules.SKILLS[ZiXi.ALMOST_SURE].cost):
				var ulti_enhance: bool = int(zixi.metaphysics) >= ZiXi.ENHANCE_COST
				battle.assign(battle.hand.find(ZiXi.ALMOST_SURE), 4, ulti_target, ulti_enhance)
				covered[ulti_target] = true
			# 3) ZiXi 防御格：鞅
			elif candidates.size() > 1:
				battle.assign(battle.hand.find(ZiXi.MARTINGALE), 5, int(candidates[1]), false)
				covered[int(candidates[1])] = true

	# 4) 灰烬：试探守住指向自己的进攻格（避开 ZiXi 已占的格）
	for enemy in battle.enemy_slots:
		if not enemy.active or int(enemy.category) == 2 or covered.has(int(enemy.id)):
			continue
		if int(enemy.target) == 0 and battle.can_clash(battle.hero_slots[0], enemy):
			battle.assign(battle.hand.find("probe"), 0, int(enemy.id), false)
			covered[int(enemy.id)] = true
			break

	# 5) 织火：护阵
	battle.assign(battle.hand.find("cover"), 8, -1, false)


func _zixi_candidates(battle: DemoBattleRules, unit: int) -> Array:
	var list: Array = []
	for enemy in battle.enemy_slots:
		if not enemy.active or int(enemy.category) == 2:
			continue
		if not battle.can_clash(battle.hero_slots[unit * 3], enemy):
			continue
		var aimed_at_me: bool = int(enemy.target) == unit
		var weight: int = 0
		if int(enemy.category) == 1 and not aimed_at_me:
			weight = 0    # 接下指向队友的大招：收益最大
		elif int(enemy.category) == 1 and aimed_at_me:
			weight = 1
		elif int(enemy.category) == 0 and aimed_at_me:
			weight = 2
		else:
			weight = 3    # 接下指向队友的普通攻击
		list.append({"id": int(enemy.id), "weight": weight, "speed": int(enemy.speed)})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.weight) != int(b.weight):
			return int(a.weight) < int(b.weight)
		return int(a.speed) > int(b.speed))
	var ids: Array = []
	for item in list:
		ids.append(int(item.id))
	return ids


# 复刻引擎的配对逻辑：同一个敌方行动格只会被速度最高的我方行动接走
func pairings(battle: DemoBattleRules) -> Dictionary:
	var result := {}
	for enemy in battle.enemy_slots:
		if not enemy.active or int(enemy.category) == 2:
			continue
		var candidates: Array[Dictionary] = []
		for hero in battle.hero_slots:
			if hero.active and Rules.targets_enemy(hero.key) and int(hero.target) == int(enemy.id) and battle.can_clash(hero, enemy):
				candidates.append(hero)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.speed) != int(b.speed):
				return int(a.speed) > int(b.speed)
			return int(a.id) < int(b.id))
		if not candidates.is_empty():
			result[int(enemy.id)] = int(candidates[0].id)
	return result


func _run_turn() -> void:
	print("=== 回合级模拟（脚本策略，真实敌人随机，每场最多 6 回合 × 400 场）===")
	for variant in [["3-5", 3, 5], ["4-6", 4, 6], ["5-7", 5, 7]]:
		var label: String = variant[0]
		var lo: int = variant[1]
		var hi: int = variant[2]
		var agg := {
			"rounds": 0, "victory": 0, "defeat": 0,
			"zixi_dmg_out": 0.0, "team_dmg_out": 0.0, "team_dmg_in": 0.0, "zixi_dmg_in": 0.0,
			"zixi_cancel": 0, "zixi_play": 0, "intercept": 0, "engage": 0,
			"layer": 0.0, "cost_used": 0.0, "shield": 0.0, "team_shield": 0.0,
			"big_direct": 0, "big_direct_dmg": 0.0, "ally_direct": 0, "ally_direct_dmg": 0.0,
		}
		for game in 400:
			var battle := make_battle(4000 + game * 13)
			battle.heroes[1].speed_min = lo
			battle.heroes[1].speed_max = hi
			battle._prepare_round()
			for round_index in 6:
				if not battle.outcome.is_empty():
					break
				plan_round(battle)
				var pairs := pairings(battle)
				# 没人接、直接打在队友身上的敌方行动
				var direct_big := {}
				var direct_attack := {}
				for enemy in battle.enemy_slots:
					if not enemy.active or int(enemy.category) == 2 or pairs.has(int(enemy.id)):
						continue
					var hero_target: int = int(enemy.target)
					if int(enemy.category) == 1:
						direct_big[hero_target] = true
					else:
						direct_attack[hero_target] = true
				var before_cost: int = battle.cost
				var before_layer: int = int(battle.heroes[1].metaphysics)
				var events: Array[Dictionary] = battle.lock_and_resolve()
				var info: Dictionary = summarize(events)
				agg.rounds += 1
				agg.team_dmg_out += float(info.dmg_out)
				agg.team_dmg_in += float(info.dmg_in)
				agg.intercept += int(info.intercept)
				agg.engage += int(info.engage)
				agg.zixi_cancel += int(info.cancelled)
				agg.shield += float(info.shield)
				for event in events:
					if event.type == "strike" and bool(event.allied) and int(event.source) == 1:
						agg.zixi_dmg_out += float(event.damage)
					if event.type == "strike" and not bool(event.allied):
						if direct_big.has(int(event.target)):
							agg.big_direct_dmg += float(event.damage)
						elif direct_attack.has(int(event.target)):
							agg.ally_direct_dmg += float(event.damage)
				agg.big_direct += direct_big.size()
				agg.ally_direct += direct_attack.size()
				for slot in battle.hero_slots:
					if slot.active and int(slot.unit) == 1:
						agg.zixi_play += 1
				agg.layer += float(int(battle.heroes[1].metaphysics) - before_layer)
				agg.cost_used += float(before_cost - battle.cost)
				if not battle.outcome.is_empty():
					if battle.outcome == "victory":
						agg.victory += 1
					else:
						agg.defeat += 1
					break
				battle.next_round()
		var n: float = float(maxi(1, agg.rounds))
		print("速度 %s｜回合 %d｜胜 %d 负 %d｜队伍输出/回合 %.2f（ZiXi 占 %.0f%%）｜队伍承伤/回合 %.2f｜无人接的大招直击队友 %d 次/百回合、打出 %.2f 伤害/回合｜普通攻击直击队友 %.2f 伤害/回合｜ZiXi 行动作废 %d｜每回合层数 %.2f｜每回合花费 %.1f" % [
			label, int(agg.rounds), int(agg.victory), int(agg.defeat),
			float(agg.team_dmg_out) / n,
			100.0 * float(agg.zixi_dmg_out) / maxf(0.01, float(agg.team_dmg_out)),
			float(agg.team_dmg_in) / n,
			100.0 * float(agg.big_direct) / n,
			float(agg.big_direct_dmg) / n,
			float(agg.ally_direct_dmg) / n,
			int(agg.zixi_cancel),
			float(agg.layer) / n, float(agg.cost_used) / n,
		])


# ---------- 速度专项 ----------

func _run_speed() -> void:
	print("=== 速度专项：ZiXi 能不能真的接下（速度严格更高才可替队友接招）===")
	print("样本：%d 回合的真实速度与目标箭头" % iterations)
	for variant in [["3-5", 3, 5], ["4-6", 4, 6], ["5-7", 5, 7]]:
		var label: String = variant[0]
		var lo: int = variant[1]
		var hi: int = variant[2]
		var total := 0
		var aimed_me := 0
		var aimed_ally := 0
		var ally_can_take := 0
		var ally_taken := 0
		var ally_big := 0
		var ally_big_taken := 0
		for i in iterations:
			var battle := make_battle(5000 + i * 3)
			battle.heroes[1].speed_min = lo
			battle.heroes[1].speed_max = hi
			battle._prepare_round()
			for enemy in battle.enemy_slots:
				if not enemy.active or int(enemy.category) == 2:
					continue
				total += 1
				if int(enemy.target) == 1:
					aimed_me += 1
					continue
				aimed_ally += 1
				var slot: Dictionary = battle.hero_slots[3]
				if battle.can_clash(slot, enemy):
					ally_can_take += 1
				if int(enemy.category) == 1:
					ally_big += 1
					if battle.can_clash(slot, enemy):
						ally_big_taken += 1
		print("速度 %s：可拼点格 %d｜指向自己 %d｜指向队友 %d｜ZiXi 速度够接 %d（%.1f%%）｜指向队友的大招 %d｜其中够接 %d（%.1f%%）" % [
			label, total, aimed_me, aimed_ally, ally_can_take,
			100.0 * float(ally_can_take) / float(maxi(1, aimed_ally)),
			ally_big, ally_big_taken,
			100.0 * float(ally_big_taken) / float(maxi(1, ally_big)),
		])


# ---------- 单回合逐步日志 ----------

func _run_trace() -> void:
	var battle := make_battle(4100)
	battle.heroes[1].hp = 9999
	for unit in battle.enemies:
		unit.hp = 9999
	print("=== 第 1 回合详细过程 ===")
	print("敌方行动格：")
	for enemy in battle.enemy_slots:
		var target_name: String = "-"
		if int(enemy.target) >= 0:
			target_name = str(battle.heroes[int(enemy.target)].name)
		print("  格%d %s 类别%d 速度%d 启用%s 目标%s 技能%s" % [
			int(enemy.id), battle.enemies[int(enemy.unit)].name, int(enemy.category),
			int(enemy.speed), str(bool(enemy.active)), target_name, str(enemy.key),
		])
	print("我方行动格速度：")
	for slot in battle.hero_slots:
		print("  格%d %s 类别%d 速度%d" % [int(slot.id), battle.heroes[int(slot.unit)].name, int(slot.category), int(slot.speed)])
	plan_round(battle)
	print("安排：")
	for slot in battle.hero_slots:
		if slot.active:
			print("  格%d %s 使用 %s（强化=%s）目标格%s 速度%d" % [
				int(slot.id), battle.heroes[int(slot.unit)].name, Rules.SKILLS[slot.key].name,
				str(bool(slot.get("enhanced", false))), str(int(slot.target)), int(slot.speed),
			])
	print("结算：")
	var events: Array[Dictionary] = battle.lock_and_resolve()
	for event in events:
		match event.type:
			"reveal":
				print("  双方锁定")
			"engage":
				print("  迎击：%s 接下 %s 的攻击" % [battle.heroes[int(event.hero)].name, battle.enemies[int(event.enemy)].name])
			"intercept":
				print("  接招：%s 替队友接下 %s 的攻击" % [battle.heroes[int(event.hero)].name, battle.enemies[int(event.enemy)].name])
			"clash":
				print("  拼点 %d : %d（我方剩 %d 枚，敌方剩 %d 枚）" % [
					int(event.left), int(event.right), int(event.hero_remaining), int(event.enemy_remaining)])
			"strike":
				var source_name: String = ""
				var target_name2: String = ""
				if bool(event.allied):
					source_name = str(battle.heroes[int(event.source)].name)
					target_name2 = str(battle.enemies[int(event.target)].name)
				else:
					source_name = str(battle.enemies[int(event.source)].name)
					target_name2 = str(battle.heroes[int(event.target)].name)
				print("  %s 对 %s 造成 %d 伤害（挡 %d）" % [source_name, target_name2, int(event.damage), int(event.blocked)])
			"refund":
				print("  拼点失败，返还 %d cost" % int(event.amount))
			"stalemate":
				print("  僵持，返还 %d cost" % int(event.amount))
			"ability":
				print("  %s" % event.message)
			"cancelled":
				print("  取消：%s" % event.reason)
			"guard":
				print("  %s 获得 %d 护盾" % [battle.heroes[int(event.hero)].name, int(event.amount)])
	var hero: Dictionary = battle.heroes[1]
	print("回合末：ZiXi 超形上学 %d/6｜因果律 %d/3｜护盾 %d｜剩余 cost %d" % [
		int(hero.metaphysics), int(hero.causality), int(hero.shield), battle.cost])
