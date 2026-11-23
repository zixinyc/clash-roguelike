extends SceneTree

# ZiWu 角色脚本的独立测试。
# 本文件只测角色本身（scripts/characters/ziwu.gd），不依赖引擎接线，
# 因此引擎整合完成前后都能跑。整合方接线后可再补一层战斗流程测试。

const ZiWu = preload("res://scripts/characters/ziwu.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func hero() -> Dictionary:
	return ZiWu.create_unit()

# 造一个阵容：[ZiWu, 织火, 灰烬]，hp 为 0 表示已退场。
func team(weaver_alive: bool, ash_alive: bool) -> Array:
	return [
		{"name": "ZiWu", "hp": 25},
		{"name": "织火", "hp": 46 if weaver_alive else 0},
		{"name": "灰烬", "hp": 48 if ash_alive else 0},
	]

func slot(key: String, enhanced: bool = false) -> Dictionary:
	return {"key": key, "enhanced": enhanced}

func skill(key: String) -> Dictionary:
	return ZiWu.card(key)

# ------------------------------------------------------------
# 基础数值与牌面
# ------------------------------------------------------------

func test_unit_and_cards() -> void:
	var h := hero()
	check(h.name == "ZiWu" and h.role == "绝缘独行客", "角色名与定位")
	check(h.hp == 25 and h.max_hp == 25, "生命 25")
	check(h.speed_min == 6 and h.speed_max == 10, "速度 6~10")
	check(h.insulation == 0 and h.round_clash_gain == 0 and h.enhanced_slot == -1, "初始状态清零")
	check(h.killed_allies.is_empty() and h.ally_cost_refunded == false, "友军击倒记录初始为空")
	check(ZiWu.CARDS.size() == 9, "九张符卡")
	check(ZiWu.card(ZiWu.COLD_EDGE).name == "冷刃试锋", "冷刃试锋牌面")
	check(ZiWu.card(ZiWu.BACKSTAB).name == "断缘处决", "断缘处决牌面")
	check(ZiWu.card(ZiWu.LONE_INTERCEPT).name == "孤影截杀", "孤影截杀牌面")
	check(ZiWu.card(ZiWu.MERIDIAN_SLASH).name == "子午绝灭斩", "子午绝灭斩牌面")
	check(bool(ZiWu.card(ZiWu.BACKSTAB).get("can_target_ally", false)), "只有断缘处决可以指向友军")
	check(not bool(ZiWu.card(ZiWu.COLD_EDGE).get("can_target_ally", false)), "冷刃试锋不能指向友军")
	check(bool(ZiWu.card(ZiWu.LONE_INTERCEPT).has("enhance_name")), "孤影截杀可强化")

# ------------------------------------------------------------
# 独行上下文
# ------------------------------------------------------------

func test_solo_context() -> void:
	var full := team(true, true)
	check(ZiWu.living_teammates(full, 0) == 2, "满编时有 2 名存活友军")
	check(ZiWu.missing_allies(full, 0) == 0, "满编不缺友军")
	check(not ZiWu.is_solo(full, 0), "满编不是独行")
	var one_down := team(true, false)
	check(ZiWu.missing_allies(one_down, 0) == 1, "倒 1 人缺 1 名友军")
	check(not ZiWu.is_solo(one_down, 0), "还有 1 名友军不算独行")
	var alone := team(false, false)
	check(ZiWu.missing_allies(alone, 0) == 2, "独行缺 2 名友军")
	check(ZiWu.is_solo(alone, 0), "没有存活友军即独行")
	var ctx := ZiWu.round_context(alone, 0)
	check(int(ctx.missing_allies) == 2 and bool(ctx.is_solo), "round_context 与单独计算一致")

# ------------------------------------------------------------
# 回合准备
# ------------------------------------------------------------

func test_prepare_round() -> void:
	var h := hero()
	h.insulation = 3
	h.enhanced_slot = 2
	h.ally_cost_refunded = true
	h.round_clash_gain = 1
	ZiWu.prepare_round(h, 4, 2, true)
	check(int(h.round_clash_gain) == 0 and int(h.enhanced_slot) == -1, "回合开始清空拼点额度与强化次数")
	check(not bool(h.ally_cost_refunded), "回合开始清空友军击倒返还额度")
	check(int(h.missing_allies) == 2 and bool(h.is_solo), "回合开始写入独行上下文")
	check(int(h.extra_cards) == 1, "独行时多抽 1 张牌")
	ZiWu.prepare_round(h, 5, 0, false)
	check(int(h.extra_cards) == 0, "不独行时不额外抽牌")
	check(int(h.enhanced_slot) == -1, "再次准备仍清空强化")

func test_prepare_round_shield() -> void:
	var h := hero()
	ZiWu.add_shield(h, 8, 3)
	ZiWu.prepare_round(h, 3, 0, false)
	check(int(h.shield) == 8, "当回合护盾保留")
	ZiWu.prepare_round(h, 4, 0, false)
	check(int(h.shield) == 0 and h.shield_until.is_empty(), "过期护盾清空")

# ------------------------------------------------------------
# 拼点加成
# ------------------------------------------------------------

func test_begin_clash_bonus() -> void:
	var h := hero()
	h.missing_allies = 2
	h.insulation = 3
	var clash := ZiWu.begin_clash(h, slot(ZiWu.COLD_EDGE), skill(ZiWu.COLD_EDGE))
	# 缺 2 名友军 +4，绝缘 3 层 +3
	check(int(clash.bonus) == 7, "拼点加成 = 缺友军 + 绝缘")
	# 伤害：缺 2 名友军 +6，绝缘 3 层 +6
	check(int(clash.damage_bonus) == 12, "伤害加成 = 缺友军 + 绝缘")
	check(int(clash.insulation_snapshot) == 3, "记录拼点开始时的绝缘层数")

func test_begin_clash_enhanced_and_next() -> void:
	var h := hero()
	h.insulation = 2
	var clash := ZiWu.begin_clash(h, slot(ZiWu.LONE_INTERCEPT, true), skill(ZiWu.LONE_INTERCEPT))
	check(int(clash.bonus) == 2 + 4, "强化额外 +4 拼点")
	check(bool(clash.enhanced), "强化状态透传")
	h.next_clash[ZiWu.LONE_INTERCEPT] = 3
	clash = ZiWu.begin_clash(h, slot(ZiWu.COLD_EDGE), skill(ZiWu.COLD_EDGE))
	check(int(clash.bonus) == 2 + 3, "上次预备的拼点加成在本次生效（另有 2 层绝缘）")
	check(h.next_clash.is_empty(), "预备加成使用后清空")
	var h2 := hero()
	ZiWu.win_clash(h2, ZiWu.COLD_EDGE, false, 1)
	check(int(h2.next_clash.get(ZiWu.LONE_INTERCEPT, 0)) == 0, "未强化的拼赢没有预备")

func test_begin_clash_backstab_low_hp() -> void:
	var h := hero()
	var target := {"hp": 20, "max_hp": 40}
	var clash := ZiWu.begin_clash(h, slot(ZiWu.BACKSTAB), skill(ZiWu.BACKSTAB), target)
	check(int(clash.bonus) == 3, "目标血量 ≤50% 时拼点 +3")
	target = {"hp": 21, "max_hp": 40}
	clash = ZiWu.begin_clash(h, slot(ZiWu.BACKSTAB), skill(ZiWu.BACKSTAB), target)
	check(int(clash.bonus) == 0, "目标血量高于 50% 时没有额外拼点")

# ------------------------------------------------------------
# 拼赢与绝缘
# ------------------------------------------------------------

func test_win_clash_solo_gain() -> void:
	var h := hero()
	h.missing_allies = 2
	h.is_solo = true
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 1) == 1, "独行拼赢产 1 层绝缘")
	check(int(h.insulation) == 1, "绝缘 +1")
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 1) == 0, "每回合拼点产绝缘上限 1 层")
	check(int(h.insulation) == 1, "超出额度不再增加")
	ZiWu.prepare_round(h, 2, 2, true)
	check(int(h.round_clash_gain) == 0, "新回合拼点产绝缘额度重置")
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 2) == 1, "新回合可以再产 1 层绝缘")

func test_win_clash_not_solo() -> void:
	var h := hero()
	h.missing_allies = 1
	h.is_solo = false
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 1) == 0, "不是独行时不产绝缘")
	check(int(h.insulation) == 0, "绝缘不变")

func test_win_clash_enhanced_next_clash() -> void:
	var h := hero()
	h.is_solo = false
	ZiWu.win_clash(h, ZiWu.LONE_INTERCEPT, true, 1)
	check(int(h.next_clash.get(ZiWu.LONE_INTERCEPT, 0)) == 3, "绝影突袭拼赢后下次拼点 +3")
	check(ZiWu.next_clash_bonus(h) == 3, "预备加成可读取")
	ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 1)
	check(int(h.next_clash.get(ZiWu.LONE_INTERCEPT, 0)) == 3, "未强化的拼赢不新增预备，也不消耗已有预备")

func test_insulation_cap() -> void:
	var h := hero()
	check(ZiWu.gain_insulation(h, 9) == 5, "绝缘上限 5 层")
	check(int(h.insulation) == 5, "绝缘封顶")

# ------------------------------------------------------------
# 拼点结算
# ------------------------------------------------------------

func test_finish_clash_cold_edge_loss() -> void:
	var h := hero()
	ZiWu.finish_clash(h, ZiWu.COLD_EDGE, 1, {}, 3)
	check(int(h.vuln_round) == 4, "冷刃试锋拼输后下回合受伤")
	check(ZiWu.vulnerable_damage(h, 4) == 2, "下回合首段受伤 +2")
	check(ZiWu.vulnerable_damage(h, 5) == 0, "再往后的回合不再受伤加重")
	var h2 := hero()
	ZiWu.finish_clash(h2, ZiWu.COLD_EDGE, 0, {}, 3)
	check(int(h2.vuln_round) == 0, "拼赢不触发易伤")

func test_finish_clash_lone_intercept_win() -> void:
	var h := hero()
	var done := ZiWu.finish_clash(h, ZiWu.LONE_INTERCEPT, 0, {}, 1)
	check(int(done.extra_damage) == 4, "孤影截杀拼赢额外 +4 伤害")
	done = ZiWu.finish_clash(h, ZiWu.LONE_INTERCEPT, 1, {}, 1)
	check(int(done.extra_damage) == 0, "拼败没有额外伤害")

func test_finish_clash_meridian() -> void:
	var h := hero()
	h.insulation = 4
	h.hp = 25
	var clash := {"insulation_snapshot": 4}
	var done := ZiWu.finish_clash(h, ZiWu.MERIDIAN_SLASH, 0, clash, 2)
	check(int(done.extra_damage) == 20, "终符拼赢按消耗的 4 层绝缘追加 20 伤害")
	check(int(done.self_damage) == 5, "终符结算后自扣 5 HP")
	check(int(h.hp) == 20, "剩余生命 20")
	check(int(h.insulation) == 0, "终符消耗全部绝缘")
	check(int(h.no_insulation_round) == 3, "下回合拼点不再产绝缘")

func test_finish_clash_meridian_loss() -> void:
	var h := hero()
	h.insulation = 3
	h.hp = 25
	var done := ZiWu.finish_clash(h, ZiWu.MERIDIAN_SLASH, 1, {"insulation_snapshot": 3}, 2)
	check(int(done.extra_damage) == 0, "终符拼败没有追加伤害")
	check(int(done.self_damage) == 5, "终符拼败同样自扣 5 HP")
	check(int(h.insulation) == 0, "终符拼败同样消耗全部绝缘")

func test_finish_clash_meridian_keeps_one_hp() -> void:
	var h := hero()
	h.hp = 3
	var done := ZiWu.finish_clash(h, ZiWu.MERIDIAN_SLASH, 0, {"insulation_snapshot": 0}, 1)
	check(int(h.hp) == 1, "终符自扣至少保留 1 HP")
	check(int(done.self_damage) == 2, "自扣伤害不超过当前生命")

func test_insulation_blocked_next_round() -> void:
	var h := hero()
	h.is_solo = true
	h.no_insulation_round = 2
	check(ZiWu.insulation_blocked(h, 2), "终符后的当回合无法产绝缘")
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 2) == 0, "被封锁时不产绝缘")
	check(ZiWu.win_clash(h, ZiWu.COLD_EDGE, false, 3) == 1, "下一回合恢复产绝缘")

# ------------------------------------------------------------
# 强化
# ------------------------------------------------------------

func test_enhancement() -> void:
	var h := hero()
	h.insulation = 2
	check(ZiWu.enhancement_error(h, 0, ZiWu.LONE_INTERCEPT).is_empty(), "2 层绝缘可以强化")
	check(ZiWu.enhancement_error(h, 0, ZiWu.COLD_EDGE) == "该技能不可强化", "只有孤影截杀可强化")
	ZiWu.reserve_enhancement(h, 0)
	check(int(h.insulation) == 0 and int(h.enhanced_slot) == 0, "强化消耗 2 层绝缘并占用本回合")
	check(ZiWu.enhancement_error(h, 1, ZiWu.LONE_INTERCEPT) == "本回合已安排一次强化", "每回合只能强化一次")
	check(ZiWu.enhancement_error(h, 0, ZiWu.LONE_INTERCEPT).is_empty(), "同一格重复强化不算冲突")
	ZiWu.unreserve_enhancement(h, 0)
	check(int(h.insulation) == 2 and int(h.enhanced_slot) == -1, "撤销强化退回绝缘")
	h.insulation = 1
	check(not ZiWu.enhancement_error(h, 0, ZiWu.LONE_INTERCEPT).is_empty(), "绝缘不足不能强化")

# ------------------------------------------------------------
# 终符门槛
# ------------------------------------------------------------

func test_ultimate_gate() -> void:
	var h := hero()
	check(not ZiWu.can_use_ultimate(h, 2), "满编且无绝缘时终符不可用")
	check(not ZiWu.ultimate_error(h, 2).is_empty(), "不可用时给出提示")
	h.insulation = 3
	check(ZiWu.can_use_ultimate(h, 2), "3 层绝缘放行终符")
	check(ZiWu.ultimate_error(h, 2).is_empty(), "可用时没有提示")
	h.insulation = 0
	check(ZiWu.can_use_ultimate(h, 1), "存活友军 ≤1 时终符无条件可用")
	check(ZiWu.can_use_ultimate(h, 0), "独行时终符无条件可用")

# ------------------------------------------------------------
# 伤害换算
# ------------------------------------------------------------

func test_strike_damage() -> void:
	# 伤害模型（与 ZiXi 的符卡同款）：
	#   第 1 段 = 基础伤害 + 全局伤害加成 + 该枚正面数 × 每枚正面伤害
	#   第 2 段起 = 该枚正面数 × 每枚正面伤害
	#   牌面写的「满 X」是两段伤害之和。
	var clash := {"damage_bonus": 0}
	var damage := ZiWu.strike_damage(ZiWu.COLD_EDGE, [1, 0], clash)
	check(damage.size() == 2 and int(damage[0]) == 12 and int(damage[1]) == 0, "冷刃试锋伤害")
	damage = ZiWu.strike_damage(ZiWu.COLD_EDGE, [1, 1], clash)
	check(int(damage[0]) == 8 + 4 + 3, "双正面额外 +3 伤害")
	check(int(damage[1]) == 4, "第二段只含每枚正面伤害")
	check(int(damage[0]) + int(damage[1]) == 19, "冷刃试锋双正面总伤害 19")
	damage = ZiWu.strike_damage(ZiWu.BACKSTAB, [1, 1], clash)
	check(int(damage[0]) == 15 and int(damage[1]) == 5, "断缘处决伤害")
	check(int(damage[0]) + int(damage[1]) == 20, "断缘处决伤害满 20")
	damage = ZiWu.strike_damage(ZiWu.LONE_INTERCEPT, [1, 1], clash)
	check(int(damage[0]) == 18 and int(damage[1]) == 6, "孤影截杀伤害")
	check(int(damage[0]) + int(damage[1]) == 24, "孤影截杀伤害满 24")
	damage = ZiWu.strike_damage(ZiWu.MERIDIAN_SLASH, [1, 1], clash)
	check(int(damage[0]) == 23 and int(damage[1]) == 8, "子午绝灭斩伤害")
	check(int(damage[0]) + int(damage[1]) == 31, "子午绝灭斩伤害满 31")
	damage = ZiWu.strike_damage(ZiWu.COLD_EDGE, [0, 0], clash)
	check(int(damage[0]) == 8 and int(damage[1]) == 0, "全反面只有基础伤害")

func test_strike_damage_bonus() -> void:
	var clash := {"damage_bonus": 12}
	var damage := ZiWu.strike_damage(ZiWu.BACKSTAB, [1, 1], clash)
	check(int(damage[0]) == 15 + 12, "全局伤害加成计入首段")
	check(int(damage[1]) == 5, "全局伤害加成不进第二段")

# ------------------------------------------------------------
# 友军处决
# ------------------------------------------------------------

func test_can_execute_ally() -> void:
	check(ZiWu.can_execute_ally(ZiWu.BACKSTAB, true), "断缘处决可以处决友军")
	check(not ZiWu.can_execute_ally(ZiWu.BACKSTAB, false), "对敌不是处决友军")
	check(not ZiWu.can_execute_ally(ZiWu.COLD_EDGE, true), "其他牌不能处决友军")

func test_ally_execute_damage() -> void:
	check(ZiWu.ally_execute_damage({"hp": 17}) == 17, "处决伤害等于目标当前生命")
	check(ZiWu.ally_execute_damage({"hp": 0}) == 0, "目标已退场没有伤害")

func test_on_ally_killed() -> void:
	var h := hero()
	h.hp = 20
	var result := ZiWu.on_ally_killed(h, "织火", ZiWu.BACKSTAB, 2)
	check(int(result.cost_refund) == 3, "每回合首次击倒友军返还 3 cost")
	check(int(result.insulation_gained) == 2, "击倒友军获得 2 层绝缘")
	check(int(result.healed) == 5 and int(h.hp) == 25, "击倒友军恢复 5 HP")
	check(int(result.shield) == 8 and int(h.shield) == 8, "以断缘处决击倒友军获得 8 护盾")
	result = ZiWu.on_ally_killed(h, "灰烬", ZiWu.BACKSTAB, 2)
	check(int(result.cost_refund) == 0, "同一回合第二次击倒不再返还 cost")
	check(int(result.insulation_gained) == 2, "第二次击倒仍有绝缘")
	result = ZiWu.on_ally_killed(h, "织火", ZiWu.BACKSTAB, 2)
	check(int(result.insulation_gained) == 0, "同一个友军不会被重复结算")

func test_on_ally_killed_no_shield_for_other_cards() -> void:
	var h := hero()
	h.hp = 20
	var result := ZiWu.on_ally_killed(h, "织火", ZiWu.COLD_EDGE, 2)
	check(int(result.shield) == 0, "非断缘处决不提供护盾")
	check(int(result.healed) == 5 and int(h.hp) == 25, "仍然恢复生命")

# ------------------------------------------------------------
# 护盾结算
# ------------------------------------------------------------

func test_absorb_carried_shield() -> void:
	var h := hero()
	ZiWu.add_shield(h, 8, 3)
	ZiWu.absorb_carried_shield(h, 3)
	check(int(h.shield_until.get(3, 0)) == 5, "护盾按到期时间消耗")
	# 当前护盾由引擎在 _deal_hit() 里单独扣减，角色只负责跨回合的部分。
	h.shield -= 3
	check(int(h.shield) == 5, "当前护盾同步减少")

# ------------------------------------------------------------
# 界面摘要
# ------------------------------------------------------------

func test_summary() -> void:
	var h := hero()
	h.missing_allies = 2
	h.insulation = 3
	h.is_solo = true
	ZiWu.prepare_round(h, 1, 2, true)
	var text := ZiWu.summary(h)
	check(text.contains("绝缘 3/5"), "摘要显示绝缘层数")
	check(text.contains("拼点 +7"), "摘要显示拼点加成")
	check(text.contains("伤害 +12"), "摘要显示伤害加成")
	check(text.contains("独行"), "摘要显示独行状态")
	check(text.contains("终符可用"), "独行时终符无条件可用")

	var h2 := hero()
	h2.missing_allies = 0
	h2.insulation = 1
	ZiWu.prepare_round(h2, 1, 0, false)
	text = ZiWu.summary(h2)
	check(text.contains("终符差 2 层绝缘"), "满编且绝缘不足时提示终符还差多少层")
	check(text.contains("拼点 +1"), "满编时只按绝缘算拼点加成")

func _run() -> void:
	test_unit_and_cards()
	test_solo_context()
	test_prepare_round()
	test_prepare_round_shield()
	test_begin_clash_bonus()
	test_begin_clash_enhanced_and_next()
	test_begin_clash_backstab_low_hp()
	test_win_clash_solo_gain()
	test_win_clash_not_solo()
	test_win_clash_enhanced_next_clash()
	test_insulation_cap()
	test_finish_clash_cold_edge_loss()
	test_finish_clash_lone_intercept_win()
	test_finish_clash_meridian()
	test_finish_clash_meridian_loss()
	test_finish_clash_meridian_keeps_one_hp()
	test_insulation_blocked_next_round()
	test_enhancement()
	test_ultimate_gate()
	test_strike_damage()
	test_strike_damage_bonus()
	test_can_execute_ally()
	test_ally_execute_damage()
	test_on_ally_killed()
	test_on_ally_killed_no_shield_for_other_cards()
	test_absorb_carried_shield()
	test_summary()
	print("ZIWU checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
