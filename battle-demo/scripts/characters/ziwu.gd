extends RefCounted

const INSULATION_MAX := 5
const ENHANCE_COST := 2
const ULTIMATE_INSULATION := 3
const EXECUTE_HP := 15

const COLD_EDGE := "ziwu_cold_edge"
const BACKSTAB := "ziwu_backstab"
const LONE_INTERCEPT := "ziwu_lone_intercept"
const MERIDIAN_SLASH := "ziwu_meridian_slash"
const CARDS := [COLD_EDGE, BACKSTAB, LONE_INTERCEPT, MERIDIAN_SLASH]

const COLD_EDGE_CARD := {
	"name": "冷刃试锋", "cost": 1, "base": 7, "power": 2, "coins": 2,
	"kind": "attack", "requires_clash": true, "can_target_ally": true,
	"damage_base": 5, "damage_power": 2,
	"description": "伤害 5，每枚正面 +2，双正面再 +2。攻击队友伤害翻倍。拼败后，下回合每次受到敌人攻击时首段伤害 +2。",
}
const BACKSTAB_CARD := {
	"name": "背刺·清算", "cost": 2, "base": 8, "power": 2, "coins": 3,
	"kind": "attack", "requires_clash": true, "can_target_ally": true,
	"damage_base": 5, "damage_power": 3,
	"description": "伤害 5，每枚正面 +3。目标半血及以下时拼点 +2。目标为友军且生命 ≤15 时无视护盾使其退场；用此牌击倒队友得 5 护盾。",
}
const LONE_INTERCEPT_CARD := {
	"name": "孤影截杀", "cost": 4, "base": 10, "power": 3, "coins": 2,
	"kind": "attack", "requires_clash": true,
	"damage_base": 7, "damage_power": 4,
	"enhance_name": "绝影突袭", "enhance_bonus": 3,
	"description": "伤害 7，每枚正面 +4，拼胜额外 +2。",
	"enhance_description": "消耗 2 层绝缘，本次拼点 +3，拼胜后下一次拼点 +2。",
}
const MERIDIAN_SLASH_CARD := {
	"name": "子午绝灭斩", "cost": 5, "base": 11, "power": 4, "coins": 2,
	"kind": "ultimate", "requires_clash": true,
	"damage_base": 10, "damage_power": 5,
	"description": "需存活队友 ≤1 或绝缘 ≥3。伤害 10，每枚正面 +5，每消耗 1 层绝缘再 +2。拼点结算后扣 5 HP（至少留 1），下回合拼胜不产绝缘。",
}

static func create_unit() -> Dictionary:
	return {
		"name": "ZiWu", "role": "绝缘独行客", "hp": 25, "max_hp": 25,
		"speed_min": 7, "speed_max": 11, "shield": 0, "acted": false,
		"insulation": 0, "clash_gain_used": false, "enhanced_slot": -1,
		"next_clash_bonus": 0, "ally_refund_used": false,
		"vulnerable_turn": 0, "blocked_gain_turn": 0,
	}

static func prepare_round(hero: Dictionary) -> void:
	hero.clash_gain_used = false
	hero.enhanced_slot = -1
	hero.ally_refund_used = false

static func living_teammates(heroes: Array, unit: int) -> int:
	var alive := 0
	for i in heroes.size():
		if i != unit and heroes[i].hp > 0:
			alive += 1
	return alive

static func clash_bonus(hero: Dictionary, teammates: int) -> int:
	return maxi(0, 2 - teammates) + int(hero.insulation) / 2

static func damage_bonus(hero: Dictionary, teammates: int) -> int:
	return maxi(0, 2 - teammates) + int(hero.insulation)

static func ultimate_error(hero: Dictionary, teammates: int) -> String:
	if teammates <= 1 or int(hero.insulation) >= ULTIMATE_INSULATION:
		return ""
	return "终符还差 %d 层绝缘，或需存活队友不超过 1 名" % (ULTIMATE_INSULATION - int(hero.insulation))

static func enhancement_error(hero: Dictionary, slot: int, key: String) -> String:
	if key != LONE_INTERCEPT:
		return "只有孤影截杀可以强化"
	if hero.enhanced_slot == slot:
		return ""
	if hero.enhanced_slot >= 0:
		return "本回合已安排一次强化"
	return "强化还差 %d 层绝缘" % (ENHANCE_COST - int(hero.insulation)) if hero.insulation < ENHANCE_COST else ""

static func reserve_enhancement(hero: Dictionary, slot: int) -> void:
	hero.insulation -= ENHANCE_COST
	hero.enhanced_slot = slot

static func unreserve_enhancement(hero: Dictionary, slot: int) -> void:
	if hero.enhanced_slot == slot:
		add_insulation(hero, ENHANCE_COST)
		hero.enhanced_slot = -1

static func add_insulation(hero: Dictionary, amount: int) -> int:
	var gained := mini(amount, INSULATION_MAX - int(hero.insulation))
	hero.insulation += gained
	return gained

static func on_clash_win(hero: Dictionary, teammates: int, turn: int) -> int:
	if teammates > 0 or hero.clash_gain_used or hero.blocked_gain_turn == turn:
		return 0
	hero.clash_gain_used = true
	return add_insulation(hero, 1)

static func can_execute_ally(key: String, target: Dictionary) -> bool:
	return key == BACKSTAB and target.hp <= EXECUTE_HP

static func summary(hero: Dictionary, teammates: int, turn: int) -> String:
	var gain := "击倒队友 +2 · 独行首场拼胜 +1"
	if teammates == 0 and hero.blocked_gain_turn == turn:
		gain = "本回合拼胜不产绝缘"
	var ending := "终符可用" if ultimate_error(hero, teammates).is_empty() else "终符差 %d 层" % (ULTIMATE_INSULATION - int(hero.insulation))
	return "绝缘 %d/%d  ·  拼点 +%d  ·  伤害 +%d  ｜  %s  ｜  %s" % [hero.insulation, INSULATION_MAX, clash_bonus(hero, teammates), damage_bonus(hero, teammates), gain, ending]
