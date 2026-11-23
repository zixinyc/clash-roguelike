extends RefCounted

const RHYTHM_MAX := 5
const ECHO_LIMIT := 2
const TUNING := "minghe_tuning"
const PRELUDE := "minghe_prelude"
const INFUSION := "minghe_infusion"
const CRANE := "minghe_crane"
const CONCERTO := "minghe_concerto"
const RALLY := "minghe_rally"
const HARMONY := "minghe_harmony"
const OMNI := "minghe_omni"
const CARDS := [TUNING, PRELUDE, INFUSION, CRANE, CONCERTO, RALLY, HARMONY, OMNI]
const LEGACY_PRELUDE := "minghe_opening"
const LEGACY_HARMONY := "minghe_resonance"
const LEGACY_OMNI := "minghe_finale"
const CARD_ALIASES := {LEGACY_PRELUDE: PRELUDE, LEGACY_HARMONY: HARMONY, LEGACY_OMNI: OMNI}

const TUNING_CARD := {"name": "调音息声", "cost": 0, "base": 9, "power": 2, "coins": 1, "kind": "support", "targeted": true, "no_damage": true, "description": "结算获得 1 律动；拼胜另返 1 cost。"}
const OPENING_CARD := {"can_support_ally": true, "name": "清音起手", "cost": 1, "base": 10, "power": 2, "coins": 2, "kind": "support", "targeted": true, "no_damage": true, "description": "拼胜使队友下次拼点 +2，自身 +1 律动；拼败使队友下次拼点 +1。"}
const INFUSION_CARD := {"can_support_ally": true, "name": "灵韵灌注", "cost": 2, "base": 11, "power": 2, "coins": 2, "kind": "support", "targeted": true, "no_damage": true, "description": "队友下次攻击 +5 伤害；拼胜返 2 cost，否则返 1 cost。"}
const CRANE_CARD := {"shielded_momentum": true, "name": "鹤唳惊弦", "cost": 2, "base": 12, "power": 2, "coins": 2, "kind": "attack", "damage_base": 6, "damage_power": 3, "description": "满伤 12。拼胜使敌人下回合拼点 −2，最快队友下次拼点 +1；拼败使敌人下回合拼点 −1。"}
const CONCERTO_CARD := {"can_support_ally": true, "name": "清商协奏", "cost": 3, "base": 12, "power": 3, "coins": 2, "kind": "support", "enhance_cost": 1, "enhance_name": "清商变奏", "enhance_description": "消耗 1 律动，队友改为本回合所有拼点 +2，自身回 1 cost。", "description": "队友下次拼点 +3，获得 8 盾。"}
const RALLY_CARD := {"shielded_momentum": true, "can_support_ally": true, "name": "破阵激昂", "cost": 3, "base": 13, "power": 2, "coins": 2, "kind": "attack", "damage_base": 5, "damage_power": 3, "description": "满伤 11。队友下次攻击 +6 伤害；该队友本回合下一次拼胜返 1 cost，上限每回合一次。"}
const RESONANCE_CARD := {"name": "和鸣共震", "cost": 4, "base": 13, "power": 3, "coins": 2, "kind": "support", "enhance_cost": 2, "enhance_name": "共震变奏", "enhance_description": "消耗 2 律动，全队下次拼点提升至 +4，且下次攻击 +4。", "description": "全队下次拼点 +2，获得 6 盾。"}
const FINALE_CARD := {"name": "万象同频", "cost": 5, "base": 15, "power": 3, "coins": 2, "kind": "ultimate", "targeted": false, "no_damage": true, "description": "消耗全部律动，全队下次拼点 +(2+层数)，下次攻击 +(3+2×层数)，返 2 cost；下回合禁止获得律动。"}

const PRELUDE_CARD := OPENING_CARD   # 需求命名的符卡常量：与实际定义指向同一份牌面
const HARMONY_CARD := RESONANCE_CARD
const OMNI_CARD := FINALE_CARD

static func create_unit() -> Dictionary:
	return {"name": "minghe", "role": "先声司律", "hp": 45, "max_hp": 45, "speed_min": 5, "speed_max": 7, "shield": 0, "acted": false, "rhythm": 0, "rhythm_buff_count": 0, "no_rhythm_round": 0, "rhythm_passive_turn": 0, "rhythm_passive_uses": 0, "enhanced_slot": -1, "rhythm_reserved": 0}

static func canonical_key(key: String) -> String:
	return CARD_ALIASES.get(key, key)

static func owns_card(key: String) -> bool:
	return canonical_key(key) in CARDS

static func find_fastest_ally(heroes: Array[Dictionary], source: int) -> int:
	var best := -1
	var best_speed := -1
	for i in heroes.size():
		if i == source or heroes[i].hp <= 0:
			continue
		var speed := int(heroes[i].get("round_speed", heroes[i].speed_max))
		if speed > best_speed:
			best = i
			best_speed = speed
	return best

static func clash_bonus(hero: Dictionary) -> int:
	return int(hero.rhythm)

static func gain(hero: Dictionary, turn: int) -> void:
	gain_rhythm(hero, 1, turn)


## 是否还能获得律动：终结技之后的禁获回合，或层数已达上限时都不行。
static func can_gain_rhythm(unit: Dictionary, turn: int) -> bool:
	if int(unit.get("no_rhythm_round", 0)) == turn:
		return false
	return int(unit.get("rhythm", 0)) < RHYTHM_MAX


## 获得律动层数，返回实际获得量（受 5 层上限与禁获回合约束）。
static func gain_rhythm(unit: Dictionary, amount: int, turn: int) -> int:
	if amount <= 0 or not can_gain_rhythm(unit, turn):
		return 0
	var before := int(unit.get("rhythm", 0))
	unit.rhythm = mini(RHYTHM_MAX, before + amount)
	return int(unit.rhythm) - before


## 回合准备：重置本回合被动②计数，并清理已经过期的跨回合护盾。
static func prepare_round(unit: Dictionary, turn: int) -> void:
	unit.rhythm_buff_count = 0
	unit.rhythm_passive_uses = 0
	unit.rhythm_passive_turn = turn
	var carried: Dictionary = unit.get("shield_until", {})
	unit.shield = 0
	for expiry in carried.keys():
		if int(expiry) < turn:
			carried.erase(expiry)
		else:
			unit.shield = int(unit.shield) + int(carried[expiry])

static func consume_rhythm(hero: Dictionary, amount: int) -> int:
	var current := int(hero.rhythm)
	var spent := current if amount < 0 else mini(current, amount)
	hero.rhythm -= spent
	return spent

static func check_passive_echo(hero: Dictionary, turn: int) -> bool:
	if int(hero.rhythm_passive_turn) != turn:
		hero.rhythm_passive_turn = turn
		hero.rhythm_passive_uses = 0
	if int(hero.rhythm_passive_uses) >= ECHO_LIMIT:
		return false
	hero.rhythm_passive_uses += 1
	hero.rhythm_buff_count = int(hero.rhythm_passive_uses)
	return true

static func enhance_cost(key: String) -> int:
	return 1 if canonical_key(key) == CONCERTO else 2

static func enhancement_error(hero: Dictionary, slot_id: int, key: String) -> String:
	if hero.enhanced_slot >= 0 and hero.enhanced_slot != slot_id:
		return "本回合已安排一次律动强化"
	if int(hero.rhythm) + int(hero.rhythm_reserved) < enhance_cost(key):
		return "强化需要 %d 层律动" % enhance_cost(key)
	return ""

static func reserve(hero: Dictionary, slot_id: int, key: String) -> void:
	hero.rhythm_reserved = enhance_cost(key)
	hero.rhythm -= hero.rhythm_reserved
	hero.enhanced_slot = slot_id

static func release(hero: Dictionary) -> void:
	hero.rhythm = mini(RHYTHM_MAX, int(hero.rhythm) + int(hero.rhythm_reserved))
	hero.rhythm_reserved = 0
	hero.enhanced_slot = -1

static func summary(hero: Dictionary, turn: int) -> String:
	return "律动 %d/5 · 自身拼点 +%d · %s" % [hero.rhythm, hero.rhythm, "本回合不能获得律动" if turn == int(hero.no_rhythm_round) else "援助队友可追加伤害并积累律动"]
