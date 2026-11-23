extends RefCounted

# ============================================================
# ZiWu · 绝缘独行客
# ============================================================
# 角色定位：一名不擅长与人并肩的独行者。队友越少，她拼点越猛、伤害越高；
# 每次处决或击杀友军都会换来绝缘层数，代价是队伍人数不断减少。
#
# 四张符卡：
#   冷刃试锋   低费进攻，拼输后下回合受伤加重
#   断缘处决   中费进攻，可指向友军并无视血量与护盾直接处决
#   孤影截杀   高费进攻，可消耗绝缘强化
#   子午绝灭斩 终符，消耗全部绝缘换爆发，结算后自损生命
#
# ------------------------------------------------------------
# 与主引擎的接线约定（整合方按此接线即可）
# ------------------------------------------------------------
# 完整版接线清单见 docs/任务记录/ZiWu角色接线说明.md
# 1) 回合准备 —— battle_rules._prepare_round() 每回合开始调用：
#        var ctx := ZiWu.round_context(heroes, unit)
#        ZiWu.prepare_round(hero, turn, ctx.missing_allies, ctx.is_solo)
#    round_context 返回 {"missing_allies": int, "is_solo": bool}：
#        missing_allies = 满编 3 人时缺少的存活友军数（0～2），每少 1 人拼点 +2、伤害 +3
#        is_solo       = 场上没有任何存活友军
#
# 2) 拼点 —— battle_rules._clash()：
#        开拼： var clash := ZiWu.begin_clash(hero, hero_slot, left_skill, enemy_dict)
#              left_skill.base += clash.bonus
#        拼赢： var gained := ZiWu.win_clash(hero, h.key, bool(h.get("enhanced", false)), turn)
#        结算： var done := ZiWu.finish_clash(hero, h.key, result, clash, turn)
#    result 的约定与 ZiXi.finish_clash 相同：0 = 拼赢，1 = 拼败，-1 = 平局。
#    finish_clash 返回的 extra_damage 是结算后的追加伤害，需要在主伤害之后补一发。
#
# 3) 强化 —— can_assign 的强化校验，assign / cancel 的预留与退回：
#        ZiWu.enhancement_error(hero, slot_id, key)
#        ZiWu.reserve_enhancement(hero, slot_id)
#        ZiWu.unreserve_enhancement(hero, slot_id)
#    只有【孤影截杀】可以强化，消耗 2 层绝缘，本回合只能安排一次。
#
# 4) 终符门槛 —— can_assign 里：
#        ZiWu.can_use_ultimate(hero, alive_allies)
#        ZiWu.ultimate_error(hero, alive_allies)      # 提示文案
#
# 5) 友军处决 —— 断缘处决的牌面 can_target_ally = true，安排到友军时走友军分支：
#        ZiWu.can_execute_ally(key, true)             # 只有断缘处决可处决友军
#        ZiWu.ally_execute_damage(victim)             # 无视血量与护盾，伤害等于目标当前生命
#        ZiWu.on_ally_killed(hero, ally_id, key, turn) # 被动【断缘祭刃】
#
# 6) 伤害结算 —— 与 ZiXi 一样由引擎逐枚硬币掷点，再调用本文件换算每次命中的伤害：
#        var heads := []                                  # 每枚硬币掷出的正面数
#        var damage := ZiWu.strike_damage(key, heads, clash)
#        for i in damage.size(): _deal_hit(..., damage[i], i + 1, damage.size())
#
# 7) 额外被动 —— 引擎在 _deal_hit() 结算敌方伤害时：
#        hit += ZiWu.vulnerable_damage(hero, turn)        # 冷刃试锋拼输后下回合首段受伤 +2
# ------------------------------------------------------------

const ENHANCE_COST := 2            # 孤影截杀强化消耗 2 层绝缘
const INSULATION_MAX := 5          # 绝缘层数上限
const ROUND_CLASH_GAIN_MAX := 1    # 单走状态下每回合通过拼点最多获得 1 层绝缘
const MAX_TEAM_SIZE := 3           # 阵容最多 3 人
const ULTIMATE_INSULATION := 3     # 终符放行所需绝缘层数
const ULTIMATE_ALIVE_ALLIES := 1   # 存活友军 ≤ 该值时终符无条件放行

const MISSING_CLASH_BONUS := 2     # 每缺少 1 名友军，拼点 +2
const MISSING_DAMAGE_BONUS := 3    # 每缺少 1 名友军，伤害 +3
const INSULATION_CLASH_BONUS := 1  # 每层绝缘，拼点 +1
const INSULATION_DAMAGE_BONUS := 2 # 每层绝缘，伤害 +2

const COLD_EDGE_DOUBLE_HEADS := 3       # 冷刃试锋双正面额外伤害
const LONE_INTERCEPT_WIN_BONUS := 4     # 孤影截杀拼赢额外伤害
const VULNERABLE_DAMAGE := 2            # 冷刃试锋拼输后下回合受伤加成
const NEXT_CLASH_BONUS := 3             # 绝影突袭拼赢后下次拼点加成
const MERIDIAN_SPENT_DAMAGE := 5        # 终符每层消耗绝缘追加的伤害
const MERIDIAN_SELF_DAMAGE := 5         # 终符结算后自扣生命
const ALLY_INSULATION := 2              # 断缘祭刃击倒友军后获得的绝缘
const ALLY_HEAL := 5                    # 断缘祭刃击倒友军后恢复的生命
const ALLY_SHIELD := 8                  # 断缘祭刃以断缘处决击倒友军获得的护盾
const ALLY_COST_REFUND := 3             # 断缘祭刃每回合首次击倒友军返还的 Cost

const COLD_EDGE := "ziwu_cold_edge"
const BACKSTAB := "ziwu_backstab"
const LONE_INTERCEPT := "ziwu_lone_intercept"
const MERIDIAN_SLASH := "ziwu_meridian_slash"
const AFTERIMAGE := "ziwu_afterimage"
const BLOOD_PACT := "ziwu_blood_pact"
const LONE_BREAK := "ziwu_lone_break"
const SHADOW_CHASE := "ziwu_shadow_chase"
const FROST_TURN := "ziwu_frost_turn"
const EXPANSION_CARDS := [AFTERIMAGE, BLOOD_PACT, LONE_BREAK, SHADOW_CHASE, FROST_TURN]
const CARDS := [COLD_EDGE, BACKSTAB, LONE_INTERCEPT, MERIDIAN_SLASH] + EXPANSION_CARDS

const AFTERIMAGE_CARD := {
	"name": "残影步", "cost": 0, "base": 14, "power": 3, "coins": 1,
	"kind": "attack", "requires_clash": true, "damage_base": 4, "damage_power": 4, "shielded_momentum": true,
	"description": "满伤 8。独行时拼点 +2。拼赢获得 1 层绝缘并返还 1 Cost，每回合限一次。",
}
const BLOOD_PACT_CARD := {
	"name": "血契借刃", "cost": 2, "base": 16, "power": 3, "coins": 2,
	"kind": "attack", "requires_clash": true, "can_target_ally": true,
	"damage_base": 6, "damage_power": 6, "shielded_momentum": true,
	"description": "对敌满伤 18。对友无需拼点，造成 6 点普通伤害，自身获得 6 护盾和 1 层绝缘。击倒友军时触发断缘祭刃。",
}
const LONE_BREAK_CARD := {
	"name": "独行破阵", "cost": 3, "base": 18, "power": 4, "coins": 2,
	"kind": "attack", "requires_clash": true, "damage_base": 10, "damage_power": 6, "shielded_momentum": true,
	"enhance_name": "独行破阵·强化", "enhance_bonus": 3, "enhance_cost": 1,
	"description": "满伤 22。独行拼胜额外造成 6 点伤害，并获得 5 点护盾。",
	"enhance_description": "消耗 1 层绝缘，本次拼点 +3，拼赢使目标下回合拼点 −2。",
}
const SHADOW_CHASE_CARD := {
	"name": "影袭追命", "cost": 3, "base": 17, "power": 5, "coins": 2,
	"kind": "attack", "requires_clash": true, "damage_base": 9, "damage_power": 6, "shielded_momentum": true,
	"description": "满伤 21。目标生命 ≤50% 时额外造成 6 点伤害；本回合已有单位阵亡时费用 −1、拼点 +2。",
}
const FROST_TURN_CARD := {
	"name": "霜隙回身", "cost": 2, "base": 13, "power": 3, "coins": 2,
	"kind": "attack", "requires_clash": true, "damage_base": 5, "damage_power": 3, "shielded_momentum": true,
	"description": "满伤 11。拼胜获得 4 点护盾，独行时改为 7 点，持续至下回合结束。",
}

const COLD_EDGE_CARD := {
	"name": "冷刃试锋", "cost": 1, "base": 15, "power": 3, "coins": 2,
	"kind": "attack", "owner": 1, "requires_clash": true, "can_target_ally": false,
	"damage_base": 8, "damage_power": 4,
	"description": "基础伤害 8，每枚正面 +4（满 16）；双正面额外 +3 伤害；拼输下回合受伤 +2。",
}
const BACKSTAB_CARD := {
	"name": "断缘处决", "cost": 2, "base": 16, "power": 4, "coins": 2,
	"kind": "attack", "owner": 1, "requires_clash": true, "can_target_ally": true,
	"damage_base": 10, "damage_power": 5,
	"description": "对敌：基础伤害 10，每枚正面 +5（满 20）；目标血量 ≤50% 时拼点 +3。对友：无需拼点，无视血量与护盾直接处决，触发【断缘祭刃】并获得 8 护盾。",
}
const LONE_INTERCEPT_CARD := {
	"name": "孤影截杀", "cost": 4, "base": 19, "power": 5, "coins": 2,
	"kind": "attack", "owner": 1, "requires_clash": true, "can_target_ally": false,
	"damage_base": 12, "damage_power": 6,
	"enhance_name": "绝影突袭", "enhance_bonus": 4,
	"description": "基础伤害 12，每枚正面 +6（满 24）；拼赢额外 +4 伤害。",
	"enhance_description": "消耗 2 层绝缘：本次拼点 +4；拼赢后下次拼点 +3。",
}
const MERIDIAN_SLASH_CARD := {
	"name": "子午绝灭斩", "cost": 5, "base": 22, "power": 6, "coins": 2,
	"kind": "ultimate", "owner": 1, "requires_clash": true, "can_target_ally": false,
	"damage_base": 15, "damage_power": 8,
	"description": "需存活友军 ≤1 或持有 ≥3 层绝缘。基础伤害 15，每枚正面 +8（满 31）；消耗全部绝缘，每层额外 +5 伤害；结算后自扣 5 HP 且下回合无法通过拼点获绝缘。",
}

# ------------------------------------------------------------
# 角色状态
# ------------------------------------------------------------

static func create_unit() -> Dictionary:
	return {
		"name": "ZiWu", "role": "绝缘独行客", "hp": 25, "max_hp": 25,
		"speed_min": 6, "speed_max": 10, "shield": 0, "acted": false,
		"insulation": 0, "round_clash_gain": 0, "enhanced_slot": -1,
		"next_clash": {}, "shield_until": {},
		"missing_allies": 0, "is_solo": false, "extra_cards": 0,
		"ally_cost_refunded": false, "killed_allies": {},
		"vuln_round": 0, "no_insulation_round": 0,
		"afterimage_paid": false,
	}

static func card(key: String) -> Dictionary:
	match key:
		COLD_EDGE:
			return COLD_EDGE_CARD
		BACKSTAB:
			return BACKSTAB_CARD
		LONE_INTERCEPT:
			return LONE_INTERCEPT_CARD
		MERIDIAN_SLASH:
			return MERIDIAN_SLASH_CARD
		AFTERIMAGE:
			return AFTERIMAGE_CARD
		BLOOD_PACT:
			return BLOOD_PACT_CARD
		LONE_BREAK:
			return LONE_BREAK_CARD
		SHADOW_CHASE:
			return SHADOW_CHASE_CARD
		FROST_TURN:
			return FROST_TURN_CARD
	return {}

static func card_name(key: String) -> String:
	var info := card(key)
	return String(info.get("name", key))

# ------------------------------------------------------------
# 阵容与回合上下文
# ------------------------------------------------------------

static func living_teammates(heroes: Array, unit: int) -> int:
	var alive := 0
	for i in heroes.size():
		if i != unit and int(heroes[i].get("hp", 0)) > 0:
			alive += 1
	return alive

# 满编 3 人时缺少的存活友军数：独行（没有存活友军）为 2 人。
static func missing_allies(heroes: Array, unit: int) -> int:
	return maxi(0, MAX_TEAM_SIZE - 1 - living_teammates(heroes, unit))

static func is_solo(heroes: Array, unit: int) -> bool:
	return living_teammates(heroes, unit) == 0

# 引擎在 _prepare_round() 里用这个取本回合的独行上下文。
static func round_context(heroes: Array, unit: int) -> Dictionary:
	var missing := missing_allies(heroes, unit)
	return {"missing_allies": missing, "is_solo": missing >= MAX_TEAM_SIZE - 1}

# 每回合开始重置：拼点产绝缘额度、强化次数、友军击倒返还额度，并重算护盾。
static func prepare_round(hero: Dictionary, turn: int, missing_allies_count: int = 0, solo: bool = false) -> void:
	hero.round_clash_gain = 0
	hero.enhanced_slot = -1
	hero.ally_cost_refunded = false
	hero.afterimage_paid = false
	hero.missing_allies = missing_allies_count
	hero.is_solo = solo
	hero.extra_cards = 1 if solo else 0
	hero.shield = 0
	for expiry in hero.shield_until.keys():
		if int(expiry) < turn:
			hero.shield_until.erase(expiry)
		else:
			hero.shield += int(hero.shield_until[expiry])

# ------------------------------------------------------------
# 强化
# ------------------------------------------------------------

static func enhancement_error(hero: Dictionary, slot_id: int, key: String) -> String:
	if key not in [LONE_INTERCEPT, LONE_BREAK]:
		return "该技能不可强化"
	if hero.enhanced_slot == slot_id:
		var replace_price := int(card(key).get("enhance_cost", ENHANCE_COST))
		return "强化需要 %d 层绝缘" % replace_price if int(hero.insulation) + int(hero.get("enhancement_paid", ENHANCE_COST)) < replace_price else ""
	if hero.enhanced_slot >= 0:
		return "本回合已安排一次强化"
	var price := int(card(key).get("enhance_cost", ENHANCE_COST))
	return "强化需要 %d 层绝缘" % price if int(hero.insulation) < price else ""

static func reserve_enhancement(hero: Dictionary, slot_id: int, key: String = LONE_INTERCEPT) -> void:
	hero.enhancement_paid = int(card(key).get("enhance_cost", ENHANCE_COST))
	hero.insulation -= int(hero.enhancement_paid)
	hero.enhanced_slot = slot_id

static func unreserve_enhancement(hero: Dictionary, slot_id: int) -> void:
	if hero.enhanced_slot == slot_id:
		hero.insulation = mini(INSULATION_MAX, int(hero.insulation) + int(hero.get("enhancement_paid", ENHANCE_COST)))
		hero.enhanced_slot = -1

# ------------------------------------------------------------
# 终符门槛
# ------------------------------------------------------------

static func can_use_ultimate(hero: Dictionary, alive_allies: int) -> bool:
	return alive_allies <= ULTIMATE_ALIVE_ALLIES or int(hero.insulation) >= ULTIMATE_INSULATION

static func ultimate_error(hero: Dictionary, alive_allies: int) -> String:
	if can_use_ultimate(hero, alive_allies):
		return ""
	if alive_allies > ULTIMATE_ALIVE_ALLIES:
		return "终符需存活友军 ≤1，或持有 %d 层绝缘（当前 %d 层）" % [ULTIMATE_INSULATION, int(hero.insulation)]
	return "终符需持有 %d 层绝缘（当前 %d 层）" % [ULTIMATE_INSULATION, int(hero.insulation)]

# ------------------------------------------------------------
# 拼点
# ------------------------------------------------------------

# 拼点开始：每少 1 名友军拼点 +2、伤害 +3；每层绝缘拼点 +1、伤害 +2。
static func begin_clash(hero: Dictionary, slot: Dictionary, skill: Dictionary, target: Dictionary = {}, round_death: bool = false) -> Dictionary:
	var enhanced: bool = slot.get("enhanced", false)
	var bonus := int(hero.missing_allies) * MISSING_CLASH_BONUS + int(hero.insulation) * INSULATION_CLASH_BONUS
	for effect in hero.next_clash.values():
		bonus += int(effect)
	hero.next_clash.clear()
	if enhanced:
		bonus += int(skill.get("enhance_bonus", 0))
	if slot.key == AFTERIMAGE and hero.is_solo:
		bonus += 2
	if slot.key == SHADOW_CHASE and round_death:
		bonus += 2
	if slot.key == BACKSTAB and not target.is_empty():
		if float(target.get("hp", 1)) <= float(target.get("max_hp", 1)) * 0.5:
			bonus += 3
	return {
		"enhanced": enhanced,
		"bonus": bonus,
		"insulation_snapshot": int(hero.insulation),
		"damage_bonus": int(hero.missing_allies) * MISSING_DAMAGE_BONUS + int(hero.insulation) * INSULATION_DAMAGE_BONUS,
		"target_low": not target.is_empty() and int(target.hp) * 2 <= int(target.max_hp),
	}

# 拼赢：绝影突袭预备下次拼点；单走时通过拼点产绝缘（每回合最多 1 层）。
static func win_clash(hero: Dictionary, key: String, enhanced: bool, turn: int) -> int:
	if key == LONE_INTERCEPT and enhanced:
		hero.next_clash[LONE_INTERCEPT] = NEXT_CLASH_BONUS
	if hero.is_solo and not insulation_blocked(hero, turn):
		return gain_insulation(hero, 1, true)
	return 0

# 拼点结算：result 0 = 拼赢，1 = 拼败，-1 = 平局。
static func finish_clash(hero: Dictionary, key: String, result: int, clash: Dictionary, turn: int) -> Dictionary:
	var extra_damage := 0
	var self_damage := 0
	var shield := 0
	var cost_refund := 0
	var insulation_gained := 0
	var weaken := 0

	if result == 0:
		if key == AFTERIMAGE and not hero.afterimage_paid:
			hero.afterimage_paid = true
			cost_refund = 1
			if not insulation_blocked(hero, turn):
				insulation_gained = gain_insulation(hero, 1, bool(hero.is_solo))
		elif key == LONE_BREAK:
			if hero.is_solo:
				extra_damage = 6
				shield = 5
				add_shield(hero, shield, turn)
			if clash.get("enhanced", false):
				weaken = 2
		elif key == SHADOW_CHASE and clash.get("target_low", false):
			extra_damage = 6
		elif key == FROST_TURN:
			shield = 7 if hero.is_solo else 4
			add_shield(hero, shield, turn + 1)

	if key == COLD_EDGE and result == 1:
		hero.vuln_round = turn + 1

	if key == LONE_INTERCEPT and result == 0:
		extra_damage = LONE_INTERCEPT_WIN_BONUS

	if key == MERIDIAN_SLASH:
		var spent := int(clash.get("insulation_snapshot", 0))
		hero.insulation = 0
		if result == 0:
			extra_damage = spent * MERIDIAN_SPENT_DAMAGE
		self_damage = maxi(0, int(hero.hp) - maxi(1, int(hero.hp) - MERIDIAN_SELF_DAMAGE))
		hero.hp -= self_damage
		hero.no_insulation_round = turn + 1

	return {
		"extra_damage": extra_damage,
		"self_damage": self_damage,
		"shield": shield, "cost_refund": cost_refund,
		"insulation_gained": insulation_gained, "weaken": weaken,
	}

# 绝缘层数。from_clash 为真时受每回合 1 层的拼点额度限制。
static func gain_insulation(hero: Dictionary, amount: int, from_clash: bool = false) -> int:
	var cap := INSULATION_MAX - int(hero.insulation)
	if from_clash:
		cap = mini(cap, ROUND_CLASH_GAIN_MAX - int(hero.round_clash_gain))
	var gained := mini(amount, maxi(0, cap))
	if from_clash:
		hero.round_clash_gain += gained
	hero.insulation += gained
	return gained

# 下一次拼点的额外威力（绝影突袭拼赢后预备）。
static func next_clash_bonus(hero: Dictionary) -> int:
	var total := 0
	for effect in hero.next_clash.values():
		total += int(effect)
	return total

# 终符自损后，下回合无法通过拼点获得绝缘。
static func insulation_blocked(hero: Dictionary, turn: int) -> bool:
	return int(hero.no_insulation_round) == turn

# ------------------------------------------------------------
# 伤害
# ------------------------------------------------------------

# 逐枚硬币掷点后换算每次命中的伤害。
# heads_list 是每枚硬币掷出的正面数；首个命中含基础伤害与全局伤害加成，其余只含每枚正面伤害。
static func strike_damage(key: String, heads_list: Array, clash: Dictionary = {}) -> Array:
	var info := card(key)
	if info.is_empty():
		return []
	var coins := int(info.get("coins", 0))
	if key in EXPANSION_CARDS:
		coins = mini(coins, heads_list.size())
	var power := int(info.get("damage_power", 0))
	var damage: Array[int] = []
	for i in coins:
		var heads := int(heads_list[i]) if i < heads_list.size() else 0
		damage.append(heads * power)
	if damage.is_empty():
		return damage
	damage[0] += int(info.get("damage_base", 0)) + int(clash.get("damage_bonus", 0))
	if key == COLD_EDGE and coins > 0 and _all_heads(heads_list, coins):
		damage[0] += COLD_EDGE_DOUBLE_HEADS
	return damage

static func _all_heads(heads_list: Array, coins: int) -> bool:
	for i in coins:
		if i >= heads_list.size() or int(heads_list[i]) <= 0:
			return false
	return true

# 冷刃试锋拼输后，下回合每次受击的首段伤害 +2。
static func vulnerable_damage(hero: Dictionary, turn: int) -> int:
	return VULNERABLE_DAMAGE if int(hero.get("vuln_round", 0)) == turn else 0

# ------------------------------------------------------------
# 友军处决
# ------------------------------------------------------------

# 无条件处决友军判定：只要断缘处决指向友军即直接斩杀。
static func can_execute_ally(key: String, is_ally: bool) -> bool:
	return is_ally and key == BACKSTAB

# 断缘处决对友：无视血量与护盾直接处决，伤害等于目标当前生命。
static func ally_execute_damage(victim: Dictionary) -> int:
	return int(victim.get("hp", 0))

# 被动【断缘祭刃】：处决或击杀友军后触发。
static func on_ally_killed(hero: Dictionary, ally_id: String, key: String, turn: int) -> Dictionary:
	if hero.killed_allies.has(ally_id):
		return {"cost_refund": 0, "insulation_gained": 0, "healed": 0, "shield": 0}
	hero.killed_allies[ally_id] = true

	var cost_refund := 0
	if not hero.ally_cost_refunded:
		hero.ally_cost_refunded = true
		cost_refund = ALLY_COST_REFUND

	var gained := gain_insulation(hero, ALLY_INSULATION, false)
	var old_hp := int(hero.hp)
	hero.hp = mini(int(hero.max_hp), old_hp + ALLY_HEAL)
	var healed := int(hero.hp) - old_hp

	var shield := 0
	if key == BACKSTAB:
		shield = ALLY_SHIELD
		add_shield(hero, shield, turn) # 本回合获得护盾

	return {"cost_refund": cost_refund, "insulation_gained": gained, "healed": healed, "shield": shield}

# ------------------------------------------------------------
# 护盾
# ------------------------------------------------------------

static func add_shield(hero: Dictionary, amount: int, expiry: int) -> void:
	hero.shield_until[expiry] = int(hero.shield_until.get(expiry, 0)) + amount
	hero.shield += amount

# 护盾按到期时间先后消耗，跨回合保留的部分不计入本回合护盾。
static func absorb_carried_shield(hero: Dictionary, blocked: int) -> void:
	var carried := 0
	for shield in hero.shield_until.values():
		carried += int(shield)
	var remaining := blocked - (int(hero.shield) - carried)
	var expiries: Array = hero.shield_until.keys()
	expiries.sort()
	for expiry in expiries:
		if remaining <= 0:
			break
		var consumed := mini(remaining, int(hero.shield_until[expiry]))
		remaining -= consumed
		hero.shield_until[expiry] -= consumed
		if hero.shield_until[expiry] == 0:
			hero.shield_until.erase(expiry)

# ------------------------------------------------------------
# 界面摘要
# ------------------------------------------------------------

static func summary(hero: Dictionary) -> String:
	var layers := int(hero.get("insulation", 0))
	var missing := int(hero.get("missing_allies", 0))
	var alive_allies := maxi(0, MAX_TEAM_SIZE - 1 - missing)
	var clash_bonus := missing * MISSING_CLASH_BONUS + layers * INSULATION_CLASH_BONUS
	var damage_bonus := missing * MISSING_DAMAGE_BONUS + layers * INSULATION_DAMAGE_BONUS
	var gain := "击倒友军：绝缘 +%d、恢复 %d HP、返还 %d cost" % [ALLY_INSULATION, ALLY_HEAL, ALLY_COST_REFUND]
	if bool(hero.get("is_solo", false)):
		gain = "独行：拼赢 +%d 层绝缘（每回合 1 层）" % ROUND_CLASH_GAIN_MAX
	var ending := "终符可用" if ultimate_error(hero, alive_allies).is_empty() else "终符差 %d 层绝缘" % maxi(0, ULTIMATE_INSULATION - layers)
	return "绝缘 %d/%d  ·  拼点 +%d  ·  伤害 +%d  ｜  %s  ｜  %s" % [
		layers, INSULATION_MAX, clash_bonus, damage_bonus, gain, ending,
	]
