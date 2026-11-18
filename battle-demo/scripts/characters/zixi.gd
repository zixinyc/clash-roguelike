extends RefCounted

const ENHANCE_COST := 3
const METAPHYSICS_MAX := 6
const ROUND_GAIN_MAX := 3
const CAUSALITY_MAX := 3
const CENTRAL_LIMIT := "zixi_central_limit"
const CONVERGENCE := "zixi_convergence"
const MARTINGALE := "zixi_martingale"
const ALMOST_SURE := "zixi_almost_sure"
const CARDS := [CENTRAL_LIMIT, CONVERGENCE, MARTINGALE, ALMOST_SURE]

const CENTRAL_LIMIT_CARD := {
	"name": "中心极限定理", "cost": 1, "base": 11, "power": 2, "coins": 2,
	"kind": "attack", "owner": 1, "requires_clash": true, "damage_base": 3, "damage_power": 2,
	"enhance_name": "正态近似", "enhance_bonus": 2,
	"description": "基础伤害 3，每枚正面 +2；拼赢后下次拼点 +1。",
	"enhance_description": "本次拼点 +2；拼赢后攻击伤害 +4。",
}
const CONVERGENCE_CARD := {
	"name": "几乎处处收敛", "cost": 2, "base": 12, "power": 3, "coins": 3,
	"kind": "attack", "owner": 1, "requires_clash": true, "damage_base": 2, "damage_power": 3,
	"enhance_name": "收敛极限",
	"description": "基础伤害 2，每枚正面 +3；拼赢后下次拼点 +2。",
	"enhance_description": "本次技能第一枚反面改为正面；攻击三枚自然正面时，伤害 +3。",
}
const MARTINGALE_CARD := {
	"name": "鞅", "cost": 4, "base": 15, "power": 4, "coins": 1,
	"kind": "guard", "owner": 1, "targeted": true, "requires_clash": true, "no_damage": true,
	"enhance_name": "公平博弈", "enhance_bonus": 3,
	"description": "赢后获得 8 护盾，输后获得 4 护盾；持续至下一回合结束。",
	"enhance_description": "本次拼点 +3；赢后获得 12 护盾，输后额外使下次拼点 +3。",
}
const ALMOST_SURE_CARD := {
	"name": "几乎必然", "cost": 5, "base": 17, "power": 5, "coins": 2,
	"kind": "ultimate", "owner": 1, "requires_clash": true, "damage_base": 5, "damage_power": 4,
	"enhance_name": "概率一事件",
	"description": "基础伤害 5，每枚正面 +4；拼赢后每层因果律额外 +2 伤害。",
	"enhance_description": "拼赢后，轰炸全体 6 + 5 × 因果律（计入本次新层数），随后清空因果律；下回合暂停分差奖励。",
}

static func create_unit() -> Dictionary:
	return {
		"name": "ZiXi", "role": "几乎必然的观测者", "hp": 50, "max_hp": 50,
		"speed_min": 3, "speed_max": 5, "shield": 0, "acted": false,
		"metaphysics": 0, "causality": 0, "round_gain": 0, "enhanced_slot": -1,
		"next_clash": {}, "shield_until": {}, "no_margin_round": 0,
	}

static func prepare_round(hero: Dictionary, turn: int) -> void:
	hero.round_gain = 0
	hero.enhanced_slot = -1
	hero.shield = 0
	for expiry in hero.shield_until.keys():
		if int(expiry) < turn:
			hero.shield_until.erase(expiry)
		else:
			hero.shield += int(hero.shield_until[expiry])

static func enhancement_error(hero: Dictionary, slot_id: int) -> String:
	if hero.enhanced_slot == slot_id:
		return ""
	if hero.enhanced_slot >= 0:
		return "本回合已安排一次强化"
	return "强化需要 3 层超形上学" if hero.metaphysics < ENHANCE_COST else ""

static func unreserve_enhancement(hero: Dictionary, slot_id: int) -> void:
	if hero.enhanced_slot == slot_id:
		hero.metaphysics = mini(METAPHYSICS_MAX, int(hero.metaphysics) + ENHANCE_COST)
		hero.enhanced_slot = -1

static func reserve_enhancement(hero: Dictionary, slot_id: int) -> void:
	hero.metaphysics -= ENHANCE_COST
	hero.enhanced_slot = slot_id

static func begin_clash(hero: Dictionary, slot: Dictionary, skill: Dictionary) -> Dictionary:
	var enhanced: bool = slot.get("enhanced", false)
	var bonus := int(hero.causality)
	for effect in hero.next_clash.values():
		bonus += int(effect)
	hero.next_clash.clear()
	if enhanced:
		bonus += int(skill.get("enhance_bonus", 0))
	return {"enhanced": enhanced, "bonus": bonus, "causality": hero.causality,
		"tail_available": enhanced and slot.key == CONVERGENCE}

static func convert_tail(clash: Dictionary, heads: int, coins: int) -> int:
	if clash.tail_available and heads < coins:
		clash.tail_available = false
		return heads + 1
	return heads

static func win_clash(hero: Dictionary, key: String, margin: int, turn: int) -> int:
	match key:
		CENTRAL_LIMIT: hero.next_clash[CENTRAL_LIMIT] = 1
		CONVERGENCE: hero.next_clash[CONVERGENCE] = 2
	var reward := 2 if margin >= 5 and hero.no_margin_round != turn else 1
	var gained := mini(reward, mini(ROUND_GAIN_MAX - int(hero.round_gain), METAPHYSICS_MAX - int(hero.metaphysics)))
	hero.round_gain += gained
	hero.metaphysics += gained
	return gained

static func add_shield(hero: Dictionary, amount: int, expiry: int) -> void:
	hero.shield_until[expiry] = int(hero.shield_until.get(expiry, 0)) + amount
	hero.shield += amount

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

static func finish_clash(hero: Dictionary, key: String, result: int, enhanced: bool, turn: int) -> Dictionary:
	var shield := 0
	if key == MARTINGALE and result >= 0:
		shield = (12 if enhanced else 8) if result == 0 else 4
		add_shield(hero, shield, turn + 1)
		if result == 1 and enhanced:
			hero.next_clash[MARTINGALE] = 3
	if enhanced:
		hero.causality = mini(CAUSALITY_MAX, int(hero.causality) + 1)
	var blast := 6 + 5 * int(hero.causality) if enhanced and key == ALMOST_SURE and result == 0 else 0
	return {"shield": shield, "blast": blast}
