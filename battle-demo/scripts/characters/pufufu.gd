extends RefCounted

# pufufu · 绒毛圣盾
# 防御 / 辅助定位的挨打反击型肉盾奶妈。
# 核心思路：拼点数值极低，不靠拼点赢下敌方主力技能，而是靠跨回合厚盾硬吃伤害，
# 靠受击反伤消耗敌人，靠被动回血与卡牌治疗稳住队友血线。

const FLUFF_MAX := 6              # 【蓬松】层数上限
const ROUND_HIT_FLUFF_MAX := 2    # 每回合受击最多获得几层蓬松
const ROUND_PASSIVE_HEAL_MAX := 2 # 被动②每回合最多触发几次治疗
const BASE_REFLECT := 3           # 被动①基础反伤
const PASSIVE_HEAL_AMT := 3       # 被动②单次治疗量
const ENHANCE_COST := 2           # 强化【厚实壁垒】消耗几层蓬松
const ENHANCE_NAME := "弹力加厚"

# 卡牌键名
const FUZZ_FRICTION := "pufufu_fuzz_friction" # 绒毛摩擦
const SOFT_GUARD := "pufufu_soft_guard"       # 软绵格挡
const STATIC_FUZZ := "pufufu_static_fuzz"     # 静电绒毛
const FUZZ_HEAL := "pufufu_fuzz_heal"         # 绒毛治愈
const FUZZ_COMBO := "pufufu_fuzz_combo"       # 绒毛连击
const FUZZ_BLESS := "pufufu_fuzz_bless"       # 蓬松护佑
const FUZZ_BARRIER := "pufufu_fuzz_barrier"   # 绒毛壁障
const WARM_ECHO := "pufufu_warm_echo"         # 暖绒回响
const THICK_WALL := "pufufu_thick_wall"       # 厚实壁垒
const FLUFF_HUG := "pufufu_fluff_hug"         # 蓬松大拥抱
const ROUND_SHELL := "pufufu_round_shell"
const FUZZ_PADDING := "pufufu_fuzz_padding"
const FLUFF_PROXY := "pufufu_fluff_proxy"
const BOUNCE := "pufufu_bounce"
const FLUFF_LANTERN := "pufufu_fluff_lantern"

const CARDS := [
	FUZZ_FRICTION, SOFT_GUARD, STATIC_FUZZ, FUZZ_HEAL, FUZZ_COMBO,
	FUZZ_BLESS, FUZZ_BARRIER, WARM_ECHO, THICK_WALL, FLUFF_HUG,
	ROUND_SHELL, FUZZ_PADDING, FLUFF_PROXY, BOUNCE, FLUFF_LANTERN,
]

# —— 卡面定义 ——
# 说明：pufufu 的防御 / 大招卡统一带 targeted，作用是能在规划界面指定敌方行动格，
# 从而有机会参与拼点；但不设 requires_clash，因此即使拼不过也能照常打出（按「拼输」结算）。

const FUZZ_FRICTION_CARD := {
	"name": "绒毛摩擦", "cost": 0, "base": 5, "power": 2, "coins": 1,
	"kind": "attack", "targeted": true, "damage_base": 2, "damage_power": 1,
	"tag": "绒毛专属",
	"description": "基础伤害 2，每枚正面 +1；结算后获得 2 层蓬松。",
	"flavor": "蹭一下，绒毛就厚了。",
}
const SOFT_GUARD_CARD := {
	"name": "软绵格挡", "cost": 1, "base": 7, "power": 2, "coins": 2,
	"kind": "guard", "targeted": true, "damage_base": 2, "damage_power": 1,
	"tag": "绒毛专属",
	"description": "基础伤害 2，每枚正面 +1；拼赢获得 10 护盾，拼输获得 7 护盾，并获得 1 层蓬松。护盾持续至本回合结束。",
	"flavor": "软，但挡得住。",
}
const STATIC_FUZZ_CARD := {
	"name": "静电绒毛", "cost": 1, "base": 6, "power": 2, "coins": 2,
	"kind": "attack", "targeted": true, "damage_base": 3, "damage_power": 1,
	"tag": "绒毛专属",
	"description": "基础伤害 3，每枚正面 +1；拼赢额外造成 3 点伤害并获得 1 层蓬松，拼输自身损失 3 点生命但获得 2 层蓬松。",
	"flavor": "毛一炸，疼的是对面。",
}
const FUZZ_HEAL_CARD := {
	"name": "绒毛治愈", "cost": 2, "base": 8, "power": 2, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"tag": "绒毛专属",
	"description": "自身获得 8 护盾；拼赢治疗生命值最低的友军 10 点生命，拼输治疗 6 点生命。护盾持续至本回合结束。",
	"flavor": "蹭一蹭就不疼了。",
}
const FUZZ_COMBO_CARD := {
	"name": "绒毛连击", "cost": 2, "base": 7, "power": 3, "coins": 2,
	"kind": "attack", "targeted": true, "damage_base": 4, "damage_power": 2,
	"tag": "绒毛专属",
	"description": "基础伤害 4，每枚正面 +2；拼赢获得 2 层蓬松，拼输自身损失 2 点生命。",
	"flavor": "连着蹭，越蹭越厚。",
}
const FUZZ_BLESS_CARD := {
	"name": "蓬松护佑", "cost": 2, "base": 8, "power": 2, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"tag": "绒毛专属",
	"description": "生命值最低的存活友军获得 12 点护盾（持续至下一回合结束）；自身获得 5 点护盾，持续至本回合结束。",
	"flavor": "把最软的那层分给你。",
}
const FUZZ_BARRIER_CARD := {
	"name": "绒毛壁障", "cost": 2, "base": 9, "power": 3, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"tag": "绒毛专属",
	"description": "自身获得 16 点护盾（持续至下一回合结束）；拼赢额外获得 6 点护盾并获得 1 层蓬松。",
	"flavor": "一堵会呼吸的墙。",
}
const WARM_ECHO_CARD := {
	"name": "暖绒回响", "cost": 3, "base": 9, "power": 2, "coins": 2,
	"kind": "ultimate", "targeted": true, "no_damage": true, "requires_fluff": 1,
	"tag": "绒毛专属",
	"description": "消耗 1 层蓬松；全体友军恢复 8 点生命；自身获得 10 点护盾，持续至下一回合结束。",
	"flavor": "暖意从绒毛里透出来。",
}
const THICK_WALL_CARD := {
	"name": "厚实壁垒", "cost": 4, "base": 10, "power": 3, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"enhance_name": ENHANCE_NAME, "enhance_bonus": 0,
	"tag": "绒毛专属",
	"description": "拼赢获得 18 护盾，拼输获得 14 护盾；护盾持续至下一回合结束。",
	"enhance_description": "消耗 2 层蓬松：额外获得 8 点护盾，且本回合受击反伤翻倍。",
	"flavor": "把所有的绒，都堆在这面墙上。",
}
const FLUFF_HUG_CARD := {
	"name": "蓬松大拥抱", "cost": 5, "base": 11, "power": 3, "coins": 2,
	"kind": "ultimate", "targeted": true, "no_damage": true,
	"tag": "绒毛专属",
	"description": "消耗全部蓬松。全体友军恢复 5 + 2 × 层数 点生命，并获得 6 + 2 × 层数 点护盾（持续至下一回合结束）；pufufu 自身额外获得 10 点护盾；下回合无法通过受击获得蓬松。",
	"flavor": "把大家一起包起来。",
}


static func create_unit() -> Dictionary:
	return {
		"name": "pufufu", "role": "绒毛圣盾", "hp": 80, "max_hp": 80,
		"speed_min": 2, "speed_max": 4, "shield": 0, "acted": false,
		# 蓬松层数与每回合计数
		"fluff": 0, "round_hit_fluff": 0, "round_passive_heals": 0,
		# 强化与反伤开关
		"enhanced_slot": -1, "double_reflect_round": 0, "no_fluff_round": 0,
		# 跨回合护盾
		"shield_until": {},
		"shell_turn": 0, "proxy_turn": 0, "proxy_target": -1,
	}

const ROUND_SHELL_CARD := {
	"name": "滚圆缩壳", "cost": 0, "base": 6, "power": 2, "coins": 1,
	"kind": "guard", "targeted": true, "no_damage": true,
	"description": "拼赢获得 6 护盾，拼输或单方行动获得 4 护盾；获得 1 层蓬松，本回合下一次受击伤害 −3。",
}
const FUZZ_PADDING_CARD := {
	"name": "绒毛铺垫", "cost": 2, "base": 8, "power": 2, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"description": "拼赢全队回复 4 HP，拼输或单方行动回复 2 HP。至少有 3 层蓬松时，为生命最低的存活队友提供 6 护盾，持续至下一回合结束。",
}
const FLUFF_PROXY_CARD := {
	"name": "蓬松替身", "cost": 3, "base": 9, "power": 2, "coins": 2,
	"kind": "guard", "targeted": true, "no_damage": true,
	"enhance_name": "弹力替身", "enhance_bonus": 0,
	"enhance_cost": ENHANCE_COST, "can_support_ally": true,
	"description": "自身获得 6 护盾；指定队友（未指定时选生命最低的存活队友）获得跨回合护盾，拼赢为 12，拼输或单方行动为 8。",
	"enhance_description": "消耗 2 层蓬松，目标额外获得 6 护盾，且本回合下次遭受攻击时由 pufufu 反伤一次。",
}
const BOUNCE_CARD := {
	"name": "弹跳撞击", "cost": 3, "base": 9, "power": 3, "coins": 2,
	"kind": "attack", "targeted": true, "no_damage": true,
	"shielded_momentum": true,
	"description": "拼赢造成 10 点伤害，拼输或单方行动造成 5 点伤害，另加蓬松层数 × 2。攻击时带护盾且拼赢，恢复自身 5 HP。",
}
const FLUFF_LANTERN_CARD := {
	"name": "绒灯守候", "cost": 1, "base": 7, "power": 2, "coins": 1,
	"kind": "guard", "targeted": true, "no_damage": true,
	"description": "生命最低的存活队友获得 5 护盾，持续至本回合结束；拼赢时该队友再回复 3 HP。",
}


## 回合开始：刷新每回合计数、清理强化预约、按到期回合重建护盾。
static func prepare_round(hero: Dictionary, turn: int) -> void:
	hero.round_hit_fluff = 0
	hero.round_passive_heals = 0
	hero.enhanced_slot = -1
	hero.shield = 0
	for expiry in hero.shield_until.keys():
		if int(expiry) < turn:
			hero.shield_until.erase(expiry)
		else:
			hero.shield += int(hero.shield_until[expiry])


## 护盾写入。expiry = 本回合号表示「持续至本回合结束」，turn + 1 表示「持续至下一回合结束」。
static func add_shield(hero: Dictionary, amount: int, expiry: int) -> void:
	hero.shield_until[expiry] = int(hero.shield_until.get(expiry, 0)) + amount
	hero.shield += amount


## 强化校验：只有【厚实壁垒】可强化，代价是 2 层蓬松，每回合限一次。
static func enhancement_error(hero: Dictionary, slot_id: int, key: String) -> String:
	if key not in [THICK_WALL, FLUFF_PROXY]:
		return "该技能不可强化"
	if int(hero.get("enhanced_slot", -1)) == slot_id:
		return ""
	if int(hero.get("enhanced_slot", -1)) >= 0:
		return "本回合已安排一次强化"
	return "强化需要 %d 层蓬松" % ENHANCE_COST if int(hero.get("fluff", 0)) < ENHANCE_COST else ""


static func reserve_enhancement(hero: Dictionary, slot_id: int) -> void:
	hero.fluff = maxi(0, int(hero.get("fluff", 0)) - ENHANCE_COST)
	hero.enhanced_slot = slot_id


static func unreserve_enhancement(hero: Dictionary, slot_id: int) -> void:
	if int(hero.get("enhanced_slot", -1)) == slot_id:
		hero.fluff = mini(FLUFF_MAX, int(hero.get("fluff", 0)) + ENHANCE_COST)
		hero.enhanced_slot = -1


## 拼点前的准备：目前只记录强化状态，蓬松层数在结算时现算。
static func begin_clash(hero: Dictionary, slot: Dictionary, _skill: Dictionary) -> Dictionary:
	return {
		"enhanced": bool(slot.get("enhanced", false)),
		"bonus": 0,
	}


## 增加蓬松层数。from_hit 为真时受每回合受击上限约束，且会被【蓬松大拥抱】的封禁回合挡住。
static func gain_fluff(hero: Dictionary, amount: int, from_hit: bool = false, turn: int = 0) -> int:
	if from_hit and int(hero.get("no_fluff_round", 0)) == turn:
		return 0
	var cap := FLUFF_MAX - int(hero.get("fluff", 0))
	if from_hit:
		cap = mini(cap, ROUND_HIT_FLUFF_MAX - int(hero.get("round_hit_fluff", 0)))
	var gained := mini(amount, maxi(0, cap))
	if from_hit:
		hero.round_hit_fluff += gained
	hero.fluff = int(hero.get("fluff", 0)) + gained
	return gained


## 被动①【弹力绒盾】+ 被动②【暖绒共鸣】：受击时由战斗规则层调用。
## 返回 {"reflect_damage": int, "ally_heal": int, "fluff_gained": int}
static func on_take_hit(hero: Dictionary, turn: int) -> Dictionary:
	var reflect := reflect_damage(hero, turn)
	var gained := gain_fluff(hero, 1, true, turn)
	var ally_heal := 0
	if int(hero.get("round_passive_heals", 0)) < ROUND_PASSIVE_HEAL_MAX:
		hero.round_passive_heals += 1
		ally_heal = PASSIVE_HEAL_AMT
	return {
		"reflect_damage": reflect,
		"ally_heal": ally_heal,
		"fluff_gained": gained,
	}

static func reflect_damage(hero: Dictionary, turn: int) -> int:
	var reflect := BASE_REFLECT + int(hero.get("fluff", 0))
	return reflect * 2 if int(hero.get("double_reflect_round", 0)) == turn else reflect


## 卡牌结算。result：0 = 拼赢，1 = 拼输或本回合无人与她拼点。
## 返回各效果的数值，由规则层负责真正施加（护盾 / 治疗 / 反伤 / 掉血）。
static func resolve_card(hero: Dictionary, key: String, result: int, turn: int, enhanced: bool) -> Dictionary:
	var won := result == 0
	var layers := int(hero.get("fluff", 0))
	var out := {
		"self_shield": 0, "self_shield_expiry": turn,
		"ally_shield": 0, "ally_shield_expiry": turn + 1,
		"team_shield": 0, "team_shield_expiry": turn + 1,
		"single_heal": 0, "team_heal": 0,
		"fluff_gain": 0, "self_damage": 0, "extra_damage": 0,
		"self_heal": 0, "ally_heal": 0, "proxy": false, "other_only": false,
	}
	match key:
		ROUND_SHELL:
			out.self_shield = (6 if won else 4) + layers
			out.fluff_gain = 1
			hero.shell_turn = turn
		FUZZ_PADDING:
			out.team_heal = 4 if won else 2
			out.ally_shield = 6 if layers >= 3 else 0
			out.other_only = true
		FLUFF_PROXY:
			out.self_shield = 6 + layers
			out.ally_shield = (12 if won else 8) + (6 if enhanced else 0)
			out.other_only = true
			out.proxy = enhanced
		BOUNCE:
			out.extra_damage = (10 if won else 5) + layers * 2
			out.self_heal = 5 if won and hero.shield > 0 else 0
		FLUFF_LANTERN:
			out.ally_shield = 5
			out.ally_shield_expiry = turn
			out.ally_heal = 3 if won else 0
			out.other_only = true
		SOFT_GUARD:
			out.self_shield = (10 if won else 7) + layers
			out.fluff_gain = 1
		FUZZ_HEAL:
			out.self_shield = 8 + layers
			out.single_heal = 10 if won else 6
		THICK_WALL:
			out.self_shield = (18 if won else 14) + layers + (8 if enhanced else 0)
			out.self_shield_expiry = turn + 1
			if enhanced:
				hero.double_reflect_round = turn
		FLUFF_HUG:
			var spent := layers
			hero.fluff = 0
			hero.no_fluff_round = turn + 1
			out.team_heal = 5 + 2 * spent
			out.team_shield = 6 + 2 * spent
			out.team_shield_expiry = turn + 1
			# 自身额外护盾：额外 10 点 + 每层蓬松的 +1；队伍护盾由 team_shield 统一结算
			out.self_shield = 10 + spent
			out.self_shield_expiry = turn + 1
		FUZZ_FRICTION:
			out.fluff_gain = 2
		STATIC_FUZZ:
			if won:
				out.extra_damage = 3
				out.fluff_gain = 1
			else:
				out.self_damage = 3
				out.fluff_gain = 2
		FUZZ_COMBO:
			if won:
				out.fluff_gain = 2
			else:
				out.self_damage = 2
		FUZZ_BLESS:
			out.ally_shield = 12
			out.ally_shield_expiry = turn + 1
			out.self_shield = 5 + layers
		FUZZ_BARRIER:
			out.self_shield = 16 + layers
			out.self_shield_expiry = turn + 1
			if won:
				out.self_shield += 6
				out.fluff_gain = 1
		WARM_ECHO:
			out.team_heal = 8
			out.self_shield = 10 + layers
			out.self_shield_expiry = turn + 1
			out.fluff_gain = -1
	return out


## 手牌区角色简介用的一行摘要。
static func summary(hero: Dictionary) -> String:
	var reflect := BASE_REFLECT + int(hero.get("fluff", 0))
	if int(hero.get("double_reflect_round", 0)) > 0:
		reflect *= 2
	return "蓬松 %d/%d   ·   受击反伤 %d   ·   暖绒共鸣 %d/%d" % [
		int(hero.get("fluff", 0)), FLUFF_MAX, reflect,
		int(hero.get("round_passive_heals", 0)), ROUND_PASSIVE_HEAL_MAX,
	]
