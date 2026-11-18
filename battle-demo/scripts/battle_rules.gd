class_name DemoBattleRules
extends RefCounted

const Sakuya = preload("res://scripts/characters/izayoi_sakuya.gd")
const Reimu = preload("res://scripts/characters/hakurei_reimu.gd")
const ZiXi = preload("res://scripts/characters/zixi.gd")
const ZiXingYC = preload("res://scripts/characters/zixingyc.gd")
const Marisa = preload("res://scripts/characters/kirisame_marisa.gd")

const MAX_SLOT_GROUPS := 3
const ACTIONS_PER_GROUP := 2
const BASE_INCOME := 8
const START_COST := 30
const REFUND_RATE := 0.5
const GUARD_AMOUNT := 9
const BREAKER_HP_LOSS := 2
const ENCOUNTER_NAMES := ["裂影斥候 / 守墓盾卫", "缚咒祭司 / 鸣钟行刑者", "高血量沙包"]
const TRAINING_ENCOUNTER := 2
const TRAINING_HP := 99999
const SKILLS := {
	"cleave": {"name": "断轨", "cost": 3, "base": 5, "power": 4, "coins": 2, "kind": "attack", "tag": "重击", "description": "高威力 · 两枚硬币", "flavor": "将退路，一并斩断。"},
	"ember": {"name": "余烬斩", "cost": 2, "base": 4, "power": 3, "coins": 2, "kind": "attack", "tag": "斩击", "description": "均衡威力 · 两枚硬币", "flavor": "火熄灭前，再向前一步。"},
	"needle": {"name": "穿隙", "cost": 1, "base": 3, "power": 2, "coins": 2, "kind": "attack", "tag": "突刺", "description": "低费用 · 两枚硬币", "flavor": "裂隙，往往只需一瞬。"},
	"steady": {"name": "定锋", "cost": 2, "base": 7, "power": 1, "coins": 2, "kind": "attack", "tag": "稳势", "description": "稳定威力 · 两枚硬币", "flavor": "让摇摆的，只剩敌人。"},
	"guard": {"name": "守夜", "cost": 1, "base": 0, "power": 0, "coins": 0, "kind": "guard", "tag": "防御", "description": "获得 9 护盾 · 持续本回合", "flavor": "总有人，要守住最后一盏灯。"},
	"nova": {"name": "破晓", "cost": 4, "base": 6, "power": 4, "coins": 3, "kind": "ultimate", "tag": "大招", "description": "三枚硬币 · 爆发", "flavor": "以余火，换黎明。"},
	"observe": {"name": "观察", "cost": 2, "base": 5, "power": 2, "coins": 2, "kind": "attack", "tag": "灰烬专属", "owner": 0, "description": "行动结束获得 1 层准备", "flavor": "等待破绽。"},
	"probe": {"name": "试探", "cost": 1, "base": 5, "power": 2, "coins": 2, "kind": "attack", "tag": "灰烬专属", "owner": 0, "description": "拼点获胜获得 1 层准备", "flavor": "试出敌人的节奏。"},
	"exploit": {"name": "捕捉破绽", "cost": 3, "base": 6, "power": 3, "coins": 2, "kind": "attack", "tag": "灰烬专属", "owner": 0, "description": "拼点时消耗准备，拼点威力 +4", "flavor": "此刻，就是破绽。"},
	"follow": {"name": "余势追击", "cost": 3, "base": 5, "power": 3, "coins": 2, "kind": "attack", "tag": "灰烬专属", "owner": 0, "description": "拼点获胜并攻击后，追加 4 点攻击", "flavor": "不要放过机会。"},
	"steady_edge": {"name": "稳斩", "cost": 3, "base": 9, "power": 1, "coins": 2, "kind": "attack", "tag": "长锋专属", "owner": 1, "description": "稳定拼点；触发长锋高费被动", "flavor": "稳住，再挥剑。"},
	"shatter": {"name": "裂甲强袭", "cost": 4, "base": 5, "power": 4, "coins": 3, "kind": "ultimate", "tag": "长锋专属", "owner": 1, "description": "三枚硬币；触发长锋高费被动", "flavor": "全力破阵。"},
	"light_guard": {"name": "守护之光", "cost": 3, "base": 0, "power": 0, "coins": 0, "kind": "guard", "tag": "织火专属", "owner": 2, "description": "自身获得9护盾；其他存活队友各获得8护盾", "flavor": "光护住同伴。"},
	"support_strike": {"name": "援火冲击", "cost": 2, "base": 5, "power": 2, "coins": 2, "kind": "attack", "tag": "织火专属", "owner": 2, "description": "拼点获胜后，其他存活队友各获得4护盾", "flavor": "以攻守护。"},
	"all_in": {"name": "破阵", "cost": 3, "base": 7, "power": 4, "coins": 2, "kind": "attack", "tag": "长锋专属", "owner": 1, "description": "高威力；触发破阵者被动", "flavor": "赌上这一击。"},
	"cover": {"name": "护阵", "cost": 2, "base": 0, "power": 0, "coins": 0, "kind": "guard", "tag": "织火专属", "owner": 2, "description": "自身获得 9 护盾；其他存活队友获得 6 护盾", "flavor": "火光护住同伴。"},
	"risk": {"name": "孤注", "cost": 2, "base": 2, "power": 4, "coins": 3, "kind": "attack", "tag": "搏命", "description": "波动威力 · 三枚硬币", "flavor": "把最后的余温，押上。"},
	"murder_doll": Sakuya.MURDER_DOLL,
	"stopwatch": Sakuya.STOPWATCH,
	"private_square": Sakuya.PRIVATE_SQUARE,
	"the_world": Sakuya.THE_WORLD,
	"yin_yang_orb": Reimu.YIN_YANG_ORB,
	"fantasy_seal": Reimu.FANTASY_SEAL,
	"demon_seal": Reimu.DEMON_SEAL,
	"fantasy_nature": Reimu.FANTASY_NATURE,
	"zixi_central_limit": ZiXi.CENTRAL_LIMIT_CARD,
	"zixi_convergence": ZiXi.CONVERGENCE_CARD,
	"zixi_martingale": ZiXi.MARTINGALE_CARD,
	"zixi_almost_sure": ZiXi.ALMOST_SURE_CARD,
	"zixingyc_attention": ZiXingYC.ATTENTION_CARD,
	"zixingyc_residual": ZiXingYC.RESIDUAL_CARD,
	"zixingyc_paradox": ZiXingYC.PARADOX_CARD,
	"zixingyc_yesterday": ZiXingYC.YESTERDAY_CARD,
	"zixingyc_ending": ZiXingYC.ENDING_CARD,
	"marisa_stars": Marisa.MARISA_STARS,
	"marisa_laser": Marisa.MARISA_LASER,
	"marisa_orrery": Marisa.MARISA_ORRERY,
	"marisa_spark": Marisa.MARISA_SPARK,
	"training_tap": {"name": "练习迎击", "cost": 0, "base": 1, "power": 0, "coins": 1, "kind": "attack", "no_damage": true},
}

const CATEGORIES := ["进攻", "大招", "防御"]
const RESPONSE_SECONDS := 180.0
var rng := RandomNumberGenerator.new()
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var hand: Array[String] = []
var hero_slots: Array[Dictionary] = []
var enemy_slots: Array[Dictionary] = []
var cost := START_COST
var turn := 1
var plays := 0
var first_win_paid := false
var outcome := ""
var phase := "response"
var remaining := RESPONSE_SECONDS
var touhou_team := false
var sakuya_slot := -1
var reimu_slot := -1
var marisa_slot := -1
var enemy_cost := START_COST
var configured_hand: Array[String] = []
var extra_income := 0
var active_relics: Array[String] = []
var active_items: Array[String] = []
var guaranteed_heads := false
var stagger_enabled := false
var overwhelm_enabled := false
var evolution_config := {}

func has_relic(key: String) -> bool:
	return active_relics.has(key)

func item_error(item_key: String) -> String:
	if phase != "response" or not outcome.is_empty():
		return "规划阶段才可使用道具"
	if not active_items.has(item_key) or RelicSystem.get_consumable(item_key).is_empty():
		return "未持有该道具"
	if item_key == "weighted_coin" and guaranteed_heads:
		return "已有一枚特制铅币等待生效"
	if item_key == "field_poultice" and _healing_target() < 0:
		return "存活队员的生命已满"
	return ""

func _healing_target() -> int:
	var target := -1
	for i in heroes.size():
		var hp: int = heroes[i].hp
		if hp > 0 and hp < heroes[i].max_hp and (target < 0 or hp < heroes[target].hp):
			target = i
	return target

func use_item(item_key: String) -> Dictionary:
	var error := item_error(item_key)
	if not error.is_empty():
		return {"ok": false, "message": error}
	active_items.erase(item_key)
	match item_key:
		"ember_catalyst":
			cost += 5
			return {"ok": true, "message": "使用了余烬催化剂：获得 5 cost！"}
		"dense_smoke":
			for h in heroes:
				if h.hp > 0:
					h.shield += 8
			return {"ok": true, "message": "使用了浓缩烟幕弹：全体存活队员获得 8 护盾！"}
		"weighted_coin":
			guaranteed_heads = true
			return {"ok": true, "message": "使用了特制铅币：下一次我方掷币全部为正面。"}
		"field_poultice":
			var hero := heroes[_healing_target()]
			var healed := mini(12, int(hero.max_hp) - int(hero.hp))
			hero.hp += healed
			return {"ok": true, "message": "使用了野战膏药：%s 恢复 %d 生命。" % [hero.name, healed]}
	return {"ok": true, "message": "道具使用成功"}

enum { ASH_ID, BLADE_ID, WEAVER_ID, SAKUYA_ID, REIMU_ID, ZIXI_ID, ZIXINGYC_ID, MARISA_ID }
const DEFAULT_LINEUP := [ASH_ID, BLADE_ID, WEAVER_ID]
const TOUHOU_LINEUP := [MARISA_ID, SAKUYA_ID, REIMU_ID]
const ZIXI_LINEUP := [ASH_ID, ZIXI_ID, WEAVER_ID]
const ZIXINGYC_LINEUP := [ASH_ID, ZIXINGYC_ID, WEAVER_ID]
const BASE_CARDS := ["cleave", "ember", "needle", "steady", "guard", "nova", "observe", "all_in", "cover", "probe", "exploit", "follow", "steady_edge", "shatter", "light_guard", "support_strike"]

static func _init_unit_stagger_state(unit: Dictionary) -> Dictionary:
	if not unit.has("is_staggered"):
		unit["is_staggered"] = false
	if not unit.has("stagger_immune_turns"):
		unit["stagger_immune_turns"] = 0
	if not unit.has("stagger_threshold_triggered"):
		unit["stagger_threshold_triggered"] = false
	if not unit.has("consecutive_clash_loss"):
		unit["consecutive_clash_loss"] = 0
	return unit

static func create_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = [
		{"name": "灰烬", "role": "蓄势者", "preparation": 0, "hp": 48, "max_hp": 48, "shield": 0, "acted": false, "speed_min": 3, "speed_max": 6},
		{"name": "长锋", "role": "破阵者", "hp": 42, "max_hp": 42, "shield": 0, "acted": false, "speed_min": 5, "speed_max": 8},
		{"name": "织火", "role": "援护者", "hp": 46, "max_hp": 46, "shield": 0, "acted": false, "speed_min": 2, "speed_max": 5},
		Sakuya.create_unit(), Reimu.create_unit(), ZiXi.create_unit(), ZiXingYC.create_unit(),
		Marisa.create_unit(),
	]
	for id in roster.size():
		roster[id].character_id = id
		_init_unit_stagger_state(roster[id])
	return roster

static func card_owner(key: String) -> int:
	if key in Sakuya.CARDS:
		return SAKUYA_ID
	if key in Reimu.CARDS:
		return REIMU_ID
	if key in ZiXi.CARDS:
		return ZIXI_ID
	if key in ZiXingYC.CARDS:
		return ZIXINGYC_ID
	if key in Marisa.CARDS:
		return MARISA_ID
	return int(SKILLS[key].get("owner", -1))

static func available_cards(members: Array) -> Array:
	var cards := BASE_CARDS + Sakuya.CARDS + Reimu.CARDS + ZiXi.CARDS + ZiXingYC.CARDS + Marisa.CARDS
	return cards.filter(func(key: String) -> bool: return card_owner(key) < 0 or members.has(card_owner(key)))


func start(seed_value: int = 73129, encounter: int = 0, use_touhou_team: bool = false, use_zixi_team: bool = false, lineup: Array = [], deck: Variant = null, use_zixingyc_team: bool = false, relics: Array = [], items: Array = [], p_evolution_config: Dictionary = {}) -> void:
	rng.seed = seed_value
	evolution_config = p_evolution_config.duplicate(true)
	stagger_enabled = bool(evolution_config.get("enabled", false)) or bool(evolution_config.get("stagger", false))
	overwhelm_enabled = bool(evolution_config.get("enabled", false)) or bool(evolution_config.get("overwhelm", false))
	var members: Array = lineup if not lineup.is_empty() else (ZIXINGYC_LINEUP if use_zixingyc_team else (ZIXI_LINEUP if use_zixi_team else (TOUHOU_LINEUP if use_touhou_team else DEFAULT_LINEUP)))
	var roster := create_roster()
	heroes.clear()
	for id in members:
		heroes.append(roster[id])
	sakuya_slot = members.find(SAKUYA_ID)
	reimu_slot = members.find(REIMU_ID)
	marisa_slot = members.find(MARISA_ID)
	touhou_team = sakuya_slot >= 0 and reimu_slot >= 0
	enemy_cost = START_COST
	active_relics.assign(relics)
	active_items.assign(items)
	guaranteed_heads = false
	var available := available_cards(members)
	configured_hand.assign(available if deck == null else available.filter(func(key: String) -> bool: return deck.has(key)))
	enemies.assign([
		{"name": "裂影斥候", "kind": "scout", "hp": 58, "max_hp": 58, "shield": 0, "spent": false, "speed_min": 4, "speed_max": 7},
		{"name": "守墓盾卫", "kind": "warden", "hp": 65, "max_hp": 65, "shield": 0, "spent": false, "speed_min": 2, "speed_max": 5}
	])
	if encounter == 1:
		enemies.assign([
			{"name": "缚咒祭司", "kind": "priest", "hp": 52, "max_hp": 52, "shield": 0, "spent": false, "speed_min": 3, "speed_max": 6},
			{"name": "鸣钟行刑者", "kind": "elite", "hp": 95, "max_hp": 95, "shield": 0, "spent": false, "speed_min": 2, "speed_max": 5}
		])
	elif encounter == TRAINING_ENCOUNTER:
		enemies.assign([
			{"name": "高血量沙包", "kind": "training_dummy", "hp": TRAINING_HP, "max_hp": TRAINING_HP, "shield": 0, "spent": false, "speed_min": 1, "speed_max": 1},
		])
	elif encounter == 3:
		enemies.assign([
			{"name": "迷雾潜伏犬", "kind": "beast", "hp": 50, "max_hp": 50, "shield": 0, "spent": false, "speed_min": 5, "speed_max": 8},
			{"name": "腐殖毒蛛", "kind": "spider", "hp": 62, "max_hp": 62, "shield": 0, "spent": false, "speed_min": 3, "speed_max": 5}
		])
	elif encounter == 4:
		enemies.assign([
			{"name": "鸦天狗斥候", "kind": "tengu", "hp": 55, "max_hp": 55, "shield": 0, "spent": false, "speed_min": 7, "speed_max": 10},
			{"name": "狂暴黑熊", "kind": "bear", "hp": 110, "max_hp": 110, "shield": 0, "spent": false, "speed_min": 2, "speed_max": 4}
		])
	elif encounter == 5:
		enemies.assign([
			{"name": "烬心巨像 · 赫斯提斯", "kind": "colossus", "hp": 210, "max_hp": 210, "shield": 0, "spent": false, "speed_min": 3, "speed_max": 6}
		])
	for e in enemies:
		_init_unit_stagger_state(e)
	cost = START_COST
	extra_income = 0
	turn = 1
	outcome = ""
	_prepare_round()

func enable_evolution(stagger: bool = true, overwhelm: bool = true) -> void:
	stagger_enabled = stagger
	overwhelm_enabled = overwhelm
	evolution_config["stagger"] = stagger
	evolution_config["overwhelm"] = overwhelm

func _prepare_round() -> void:
	phase = "response"
	remaining = RESPONSE_SECONDS
	plays = 0
	first_win_paid = false
	hand.assign(configured_hand)
	var stopped := false
	if sakuya_slot >= 0:
		var sakuya := heroes[sakuya_slot]
		Sakuya.prepare_round(sakuya, turn)
		stopped = sakuya.hp > 0 and turn == sakuya.world_round
	if reimu_slot >= 0:
		for enemy in enemies:
			Reimu.prepare_enemy_round(enemy)
	if marisa_slot >= 0:
		Marisa.prepare_round(heroes[marisa_slot], turn)
	hero_slots.clear()
	enemy_slots.clear()
	for side in 2:
		var units: Array[Dictionary] = heroes if side == 0 else enemies
		var slots: Array[Dictionary] = hero_slots if side == 0 else enemy_slots
		if side == 1:
			_add_short_team_slots(stopped)
		for u in units.size():
			if units[u].has("shield_until"):
				ZiXi.prepare_round(units[u], turn)
			else:
				units[u].shield = 0
			if side == 0 and turn == 1 and has_relic("warden_bell"):
				units[u].shield += 5
			if units[u].has("memory_log"):
				ZiXingYC.prepare_round(units[u])
			if side == 0:
				units[u].acted = false
			else:
				units[u].spent = false
			for category in 3:
				var slot := _make_slot(slots.size(), u, category, units[u], side == 0)
				if side == 0 and stopped:
					slot.frozen = u != sakuya_slot
					slot.flexible = u == sakuya_slot
				if side == 1 and units[u].hp > 0 and not stopped:
					var boss: bool = units[u].kind == "colossus"
					var second := 1 if boss or (turn + u) % 2 == 0 else 2
					var training: bool = units[u].kind == "training_dummy"
					slot.active = category == 0 or (not training and category == second)
					if slot.active:
						slot.key = ["ember", "nova", "guard"][category]
						if training:
							slot.key = "training_tap"
						elif boss and category == 1 and turn % 2 == 1:
							slot.key = "ember"
						elif category == 0 and units[u].kind == "scout":
							slot.key = "needle"
						elif category == 0 and units[u].kind == "elite":
							slot.key = "cleave"
						slot.target = _living_target((turn + u + category - 1) % heroes.size()) if category != 2 else u
				slots.append(slot)

func _make_slot(id: int, unit: int, category: int, actor: Dictionary, allied: bool) -> Dictionary:
	var speed := rng.randi_range(actor.speed_min, actor.speed_max)
	if sakuya_slot >= 0:
		speed = maxi(1, speed + Sakuya.speed_modifier(heroes[sakuya_slot], allied, int(unit == sakuya_slot)))
	return {"id": id, "unit": unit, "category": category, "speed": speed, "active": false, "card": -1, "target": -1, "key": "", "done": false}

func _add_short_team_slots(stopped: bool) -> void:
	if stopped:
		return
	var groups := mini(MAX_SLOT_GROUPS - heroes.size(), turn - 1)
	var unit := _living_target(0)
	if unit < 0:
		return
	for row in range(1, groups + 1):
		for category in 3:
			var slot := _make_slot(hero_slots.size(), unit, category, heroes[unit], true)
			slot.row = row
			hero_slots.append(slot)

static func group_action_limit(slot: Dictionary) -> int:
	return 2 if slot.get("flexible", false) else ACTIONS_PER_GROUP

func reserved_cost() -> int:
	var total := 0
	for slot in hero_slots:
		if slot.active:
			total += int(SKILLS[slot.key].cost)
	return total

func snapshot() -> Dictionary:
	var public_enemies := enemy_slots.duplicate(true)
	if phase == "response":
		for slot in public_enemies:
			slot.erase("key")
			slot.erase("card")
	return {"heroes": heroes.duplicate(true), "enemies": enemies.duplicate(true), "hand": hand.duplicate(), "hero_slots": hero_slots.duplicate(true), "enemy_slots": public_enemies, "cost": cost, "reserved": reserved_cost() if phase == "response" else 0, "turn": turn, "plays": plays, "outcome": outcome, "phase": phase, "touhou_team": touhou_team, "extra_income": extra_income, "stagger_enabled": stagger_enabled, "overwhelm_enabled": overwhelm_enabled}

func category_for(key: String) -> int:
	return 2 if SKILLS[key].kind == "guard" else (1 if SKILLS[key].kind == "ultimate" else 0)

static func clash_bonus(key: String, unit: int, preparation: int) -> int:
	if key == "exploit" and preparation > 0:
		return 4
	return 2 if unit == BLADE_ID and SKILLS[key].cost >= 3 else 0

static func ally_guard_amount(key: String) -> int:
	return 8 if key == "light_guard" else (6 if key == "cover" else 4)

static func targets_enemy(key: String) -> bool:
	return SKILLS[key].kind != "guard" or SKILLS[key].get("targeted", false)

func can_clash(hero: Dictionary, enemy: Dictionary) -> bool:
	return enemy.active and enemy.category != 2 and (hero.unit == enemy.target or hero.speed > enemy.speed or heroes[hero.unit].get("ignores_intercept_speed", false))

func can_assign(card: int, slot_id: int, target: int, enhanced: bool = false) -> String:
	if phase != "response" or not outcome.is_empty():
		return "当前不能修改行动"
	if card < 0 or card >= hand.size() or slot_id < 0 or slot_id >= hero_slots.size():
		return "请选择手牌与我方行动格"
	var slot: Dictionary = hero_slots[slot_id]
	if heroes[slot.unit].hp <= 0:
		return "该成员已退场"
	if slot.get("frozen", false):
		return "时间停止，本回合只有咲夜可以行动"
	var key := hand[card]
	var skill: Dictionary = SKILLS[key]
	var owner := card_owner(key)
	if owner >= 0 and owner != heroes[slot.unit].character_id:
		return "这张牌只能由%s使用" % create_roster()[owner].name
	var flexible: bool = slot.get("flexible", false)
	if not flexible and category_for(key) != slot.category:
		return "卡牌类别与行动格不符"
	if key == "the_world" and heroes[slot.unit].world_used:
		return "咲夜的世界本场已经使用"
	if key == "fantasy_nature" and heroes[slot.unit].dream_due > 0:
		return "梦想天生已经开始蓄能"
	if key == ZiXingYC.ENDING:
		var ending_error := ZiXingYC.ending_error(heroes[slot.unit])
		if not ending_error.is_empty():
			return ending_error
	var count := 0
	for other in hero_slots:
		if other.id == slot_id or not other.active:
			continue
		if other.card == card and not slot.get("flexible", false):
			return "这张牌已经安排，请先撤销原行动"
		if other.unit == slot.unit and other.get("row", 0) == slot.get("row", 0):
			count += 1
	if count >= group_action_limit(slot):
		return "这组行动格已安排满 %d 次" % group_action_limit(slot)
	var old_cost := int(SKILLS[slot.key].cost) if slot.active else 0
	var needed := reserved_cost() - old_cost + int(SKILLS[hand[card]].cost)
	if needed > cost:
		if heroes[slot.unit].character_id == MARISA_ID:
			var missing := needed - cost
			if heroes[slot.unit].hp <= missing * 5:
				return "可用 cost 不足，魔理沙生命不足以借费"
			var enemy_active_cost := 0
			for e_slot in enemy_slots:
				if e_slot.active:
					enemy_active_cost += int(SKILLS[e_slot.key].cost)
			var unspent_enemy := maxi(0, enemy_cost - enemy_active_cost)
			if missing > unspent_enemy:
				return "可用 cost 不足，敌方 cost 不足"
		else:
			return "可用 cost 不足，请先撤销其他行动"
	if targets_enemy(key):
		if target < 0 or target >= enemy_slots.size() or enemies[enemy_slots[target].unit].hp <= 0:
			return "请选择敌方行动格"
		if skill.get("requires_clash", false) and not can_clash(slot, enemy_slots[target]):
			return "这张牌需要与敌方拼点"
	if enhanced:
		if not heroes[slot.unit].has("metaphysics") or not skill.has("enhance_name"):
			return "这张牌不能强化"
		return ZiXi.enhancement_error(heroes[slot.unit], slot_id)
	return ""

func assign(card: int, slot_id: int, target: int, enhanced: bool = false) -> String:
	var error := can_assign(card, slot_id, target, enhanced)
	if not error.is_empty():
		return error
	var slot: Dictionary = hero_slots[slot_id]
	if slot.get("enhanced", false):
		ZiXi.unreserve_enhancement(heroes[slot.unit], slot_id)
		slot.erase("enhanced")
	if enhanced:
		ZiXi.reserve_enhancement(heroes[slot.unit], slot_id)
		slot.enhanced = true
	slot.active = true
	slot.card = card
	slot.key = hand[card]
	slot.targeted = targets_enemy(slot.key)
	slot.target = target if slot.targeted else slot.unit
	return ""

func cancel(slot_id: int) -> void:
	if phase != "response" or slot_id < 0 or slot_id >= hero_slots.size():
		return
	var slot: Dictionary = hero_slots[slot_id]
	if slot.get("enhanced", false):
		ZiXi.unreserve_enhancement(heroes[slot.unit], slot_id)
		slot.erase("enhanced")
	hero_slots[slot_id].active = false
	hero_slots[slot_id].card = -1
	hero_slots[slot_id].key = ""
	hero_slots[slot_id].target = -1
	hero_slots[slot_id].erase("targeted")

func tick(delta: float) -> bool:
	if phase != "response":
		return false
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	return remaining <= 0.0

func lock_and_resolve() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if phase != "response" or not outcome.is_empty():
		return events
	phase = "resolve"
	if touhou_team:
		for e_slot in enemy_slots:
			if e_slot.active:
				enemy_cost -= int(SKILLS[e_slot.key].cost)
	var needed := reserved_cost()
	if needed > cost and marisa_slot >= 0 and heroes[marisa_slot].character_id == MARISA_ID:
		var missing := needed - cost
		if missing > 0:
			heroes[marisa_slot].hp -= missing * 5
			enemy_cost -= missing
			cost += missing
			_emit(events, {"type": "ability", "message": "魔理沙用 %d 生命偷取 %d 敌方cost" % [missing * 5, missing]})
	for slot in hero_slots:
		if slot.active:
			cost -= int(SKILLS[slot.key].cost)
			plays += 1
			if slot.key == "the_world":
				heroes[slot.unit].world_used = true
	_emit(events, {"type": "reveal"})
	var pairs := {}
	for enemy in enemy_slots:
		if not enemy.active or enemy.category == 2:
			continue
		var candidates: Array[Dictionary] = []
		for hero in hero_slots:
			if hero.active and targets_enemy(hero.key) and hero.target == enemy.id and can_clash(hero, enemy):
				candidates.append(hero)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.speed > b.speed if a.speed != b.speed else a.id < b.id)
		if not candidates.is_empty():
			pairs[enemy.id] = candidates[0].id
	var timeline: Array[Dictionary] = []
	for slot in hero_slots:
		if slot.active and not pairs.values().has(slot.id):
			timeline.append({"speed": slot.speed, "order": slot.id, "hero": slot.id, "enemy": -1})
	for slot in enemy_slots:
		if slot.active:
			var h := int(pairs.get(slot.id, -1))
			timeline.append({"speed": maxi(slot.speed, hero_slots[h].speed) if h >= 0 else slot.speed, "order": hero_slots.size() + slot.id, "hero": h, "enemy": slot.id})
	timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.speed > b.speed if a.speed != b.speed else a.order < b.order)
	for entry in timeline:
		if not outcome.is_empty():
			break
		var h: Dictionary = hero_slots[entry.hero] if entry.hero >= 0 else {}
		var e: Dictionary = enemy_slots[entry.enemy] if entry.enemy >= 0 else {}
		var h_alive: bool = not h.is_empty() and h.get("active", false) and not h.get("cancelled", false) and heroes[h.unit].hp > 0
		var e_alive: bool = not e.is_empty() and e.get("active", false) and not e.get("cancelled", false) and enemies[e.unit].hp > 0
		if h_alive and e_alive:
			_clash(events, h, e)
		else:
			if h_alive:
				_solo(events, h, true)
			if e_alive:
				_solo(events, e, false)
		if not h.is_empty():
			h.done = true
		if not e.is_empty():
			e.done = true
		_check_outcome(events)
	if outcome.is_empty() and reimu_slot >= 0 and heroes[reimu_slot].hp > 0 and heroes[reimu_slot].dream_due == turn:
		_detonate_dream(events)
		_check_outcome(events)
	if outcome.is_empty():
		phase = "finished"
		_emit(events, {"type": "round_end"})
	else:
		phase = "outcome"
	return events

func next_round() -> void:
	if phase != "finished":
		return
	turn += 1
	var income: int = 10 if has_relic("everburning_tinder") else BASE_INCOME
	cost += income
	if touhou_team:
		enemy_cost += BASE_INCOME
	extra_income = 0
	for hero in heroes:
		if hero.has("memory_log") and int(hero.hp) > 0:
			extra_income = ZiXingYC.reasoning_income(hero)
			break
	if extra_income > 0:
		cost += extra_income
	if stagger_enabled:
		_process_stagger_wake_up()
	_prepare_round()

func _solo(events: Array[Dictionary], slot: Dictionary, allied: bool) -> void:
	var skill: Dictionary = SKILLS[slot.key]
	var units: Array[Dictionary] = heroes if allied else enemies
	if allied and (skill.has("enhance_name") or (units[slot.unit].character_id == ZIXINGYC_ID and skill.get("requires_clash", false))):
		_emit(events, {"type": "cancelled", "reason": "%s需要拼点，行动取消" % skill.name})
		return
	if not targets_enemy(slot.key):
		if allied and marisa_slot >= 0 and slot.unit == marisa_slot and slot.key == Marisa.ORRERY:
			var hero := heroes[slot.unit]
			hero.orrery_until = turn + 1
			hero.orrery_active = true
			var sp := Marisa.add_spark(hero, 1)
			_emit(events, {"type": "ability", "message": "天球仪：本回合及下回合每次受击减伤 5，火花 %d / 10" % sp})
			return
		var guard_amount := GUARD_AMOUNT
		if not allied:
			match units[slot.unit].kind:
				"warden":
					guard_amount = 14
				"bear":
					guard_amount = 12
				"colossus":
					guard_amount = 18
				"spider":
					guard_amount = 10
				"beast":
					guard_amount = 8
		units[slot.unit].shield += guard_amount
		if not allied and units[slot.unit].kind == "priest":
			for i in enemies.size():
				if i != slot.unit and enemies[i].hp > 0:
					enemies[i].shield += 6
			_emit(events, {"type": "ability", "message": "缚咒祭司：为其他存活敌人提供 6 护盾"})
		if allied and units[slot.unit].character_id == WEAVER_ID and heroes.size() > 1:
			var support_shield := ally_guard_amount(slot.key)
			for i in heroes.size():
				if i != slot.unit and heroes[i].hp > 0:
					heroes[i].shield += support_shield
			_emit(events, {"type": "ability", "message": "织火 · 援护：其他存活队友获得 %d 护盾" % support_shield})
		_emit(events, {"type": "guard" if allied else "enemy_guard", "hero": slot.unit, "enemy": slot.unit, "amount": guard_amount})
		return
	var target: int = enemy_slots[slot.target].unit if allied else slot.target
	var victims: Array[Dictionary] = enemies if allied else heroes
	if victims[target].hp <= 0:
		_emit(events, {"type": "cancelled", "reason": "目标已退场，行动取消"})
		return
	if not allied and skill.get("no_damage", false):
		return
	var victim_pre_hp: int = victims[target].hp
	var marisa_pre_hps := {}
	if allied and marisa_slot >= 0 and slot.unit == marisa_slot:
		for i in enemies.size():
			marisa_pre_hps[i] = enemies[i].hp
	_emit(events, {"type": "paid", "hero": slot.unit, "skill": skill.name, "paid": 0} if allied else {"type": "enemy_turn", "enemy": slot.unit, "hero": target})
	if allied:
		var hero := heroes[slot.unit]
		if hero.has("memory_log") and skill.has("damage_base"):
			_zixingyc_strike(events, slot, target, int(skill.coins), {})
		elif marisa_slot >= 0 and slot.unit == marisa_slot:
			_attack_marisa(events, slot, target, int(skill.coins), false)
		else:
			_resolve_hero_skill(events, slot, target, skill.coins)
		if hero.has("memory_log") and not skill.get("no_damage", false):
			for i in (2 if slot.key == ZiXingYC.RESIDUAL else 1):
				var observation := ZiXingYC.write_memory(hero, ZiXingYC.OBSERVATION)
				if observation >= 0:
					_emit_zixingyc_memory(events, ZiXingYC.OBSERVATION, observation)
		if slot.key != ZiXingYC.PARADOX:
			_zixingyc_archive(events, hero, skill.get("archive_corpus", ""))
	else:
		_attack(events, false, slot.unit, target, skill.base, skill.power, skill.coins, 0.5)
	if allied and slot.key == "observe":
		heroes[slot.unit].preparation = 1
		_emit(events, {"type": "ability", "message": "灰烬 · 观察：获得 1 层准备"})
	if allied and marisa_slot >= 0 and slot.unit == marisa_slot:
		for id in marisa_pre_hps.keys():
			_check_stagger_after_action(events, enemies[id], false, marisa_pre_hps[id])
	else:
		_check_stagger_after_action(events, victims[target], not allied, victim_pre_hp)

func _clash(events: Array[Dictionary], h: Dictionary, e: Dictionary) -> void:
	var left_skill: Dictionary = SKILLS[h.key].duplicate()
	var hero := heroes[h.unit]
	var bonus := clash_bonus(h.key, hero.character_id, int(hero.get("preparation", 0)))
	var breaker: bool = hero.character_id == BLADE_ID and bonus > 0
	left_skill.base += bonus
	if h.key == "exploit" and bonus > 0:
		hero.preparation = 0
		_emit(events, {"type": "ability", "message": "灰烬 · 捕捉破绽：消耗准备，本次拼点威力 +%d" % bonus})
	if breaker:
		_emit(events, {"type": "ability", "message": "长锋 · 破阵：本次拼点威力 +%d，失败损失 %d 生命" % [bonus, BREAKER_HP_LOSS]})
	var right_skill: Dictionary = SKILLS[e.key]
	var right_base := int(right_skill.base)
	var zixi_clash := {}
	if heroes[h.unit].has("metaphysics"):
		zixi_clash = ZiXi.begin_clash(heroes[h.unit], h, left_skill)
		left_skill.base += int(zixi_clash.bonus)
		right_base -= int(zixi_clash.causality)
	if sakuya_slot >= 0:
		left_skill.base += Sakuya.stopwatch_bonus(heroes[sakuya_slot], h.get("speed", 0), e.get("speed", 0))
	if reimu_slot >= 0:
		if h.unit == reimu_slot:
			left_skill.base += Reimu.clash_bonus(enemies[e.unit])
		right_base -= Reimu.enemy_clash_penalty(enemies[e.unit])
	if marisa_slot >= 0 and h.unit == marisa_slot:
		var reimu_alive: bool = reimu_slot >= 0 and int(heroes[reimu_slot].hp) > 0
		left_skill.base += Marisa.clash_bonus(heroes[marisa_slot], reimu_alive, left_skill.kind)
	var zxy_clash := {}
	if hero.has("memory_log"):
		zxy_clash = ZiXingYC.begin_clash(hero, h.key, enemies[e.unit], int(right_skill.base), right_base)
		left_skill.base -= int(zxy_clash.overload)
		right_base -= int(zxy_clash.retrieval)
		if bool(zxy_clash.mark_consumed):
			right_base -= ZiXingYC.PARADOX_WEAKEN
	var lc := int(left_skill.coins)
	var rc := int(right_skill.coins)
	var ties := 0
	var margin := 0
	var decisive_left_val := 0
	var decisive_right_val := 0
	if has_relic("adversity_blade") and int(e.get("speed", 0)) > int(h.get("speed", 0)):
		left_skill.base += 2
		_emit(events, {"type": "ability", "message": "逆境断刃：目标速度高于自身，拼点基础威力 +2"})
	_emit(events, {"type": "intercept" if h.unit != e.target else "engage", "hero": h.unit, "enemy": e.unit})
	while lc > 0 and rc > 0:
		var left_min := maxi(0, int(left_skill.base) + mini(0, int(left_skill.power) * lc))
		var left_max := maxi(0, int(left_skill.base) + maxi(0, int(left_skill.power) * lc))
		var right_min := maxi(0, right_base + mini(0, int(right_skill.power) * rc))
		var right_max := maxi(0, right_base + maxi(0, int(right_skill.power) * rc))
		if (left_min == left_max and right_min == right_max and left_min == right_min) or ties >= 100:
			var refund := int(floor(left_skill.cost * REFUND_RATE))
			cost += refund
			_emit(events, {"type": "stalemate", "amount": refund})
			if h.key == "observe" and hero.hp > 0:
				hero.preparation = 1
				_emit(events, {"type": "ability", "message": "灰烬 · 观察：获得 1 层准备"})
			if not zixi_clash.is_empty():
				_finish_zixi_clash(events, h, -1, zixi_clash)
			if h.key == ZiXingYC.ATTENTION:
				_zixingyc_archive(events, hero, left_skill.archive_corpus)
			return
		var left := _roll(left_skill.base, left_skill.power, lc, 0.65)
		if zixi_clash.get("tail_available", false):
			var old_heads := int(left.heads)
			left.heads = ZiXi.convert_tail(zixi_clash, old_heads, lc)
			left.value += (int(left.heads) - old_heads) * int(left_skill.power)
		var right := _roll(right_base, right_skill.power, rc, 0.5)
		margin = int(left.value) - int(right.value)
		var winner := -1 if left.value == right.value else (0 if left.value > right.value else 1)
		if winner == -1 and has_relic("weight_of_balance"):
			winner = 0
			_emit(events, {"type": "ability", "message": "天平之重：拼点平局判定为获胜"})
		var old_lc := lc
		var old_rc := rc
		if winner == 0:
			rc -= 1
		elif winner == 1:
			lc -= 1
		ties = ties + 1 if winner == -1 else 0
		var is_decisive := (lc == 0 or rc == 0) and winner != -1
		if is_decisive:
			decisive_left_val = int(left.value)
			decisive_right_val = int(right.value)
		_emit(events, {"type": "clash", "hero": h.unit, "enemy": e.unit, "left": left.value, "right": right.value, "left_heads": left.heads, "right_heads": right.heads, "hero_coins": old_lc, "enemy_coins": old_rc, "hero_remaining": lc, "enemy_remaining": rc, "winner": winner, "decider": is_decisive})

	var hero_pre_hp: int = heroes[h.unit].hp
	var enemy_pre_hp: int = enemies[e.unit].hp
	var marisa_pre_hps := {}
	if marisa_slot >= 0 and h.unit == marisa_slot:
		for i in enemies.size():
			marisa_pre_hps[i] = enemies[i].hp

	var can_overwhelm := false
	var overwhelm_margin := 0
	var overwhelm_amount := 0
	if overwhelm_enabled:
		var winner_skill: Dictionary = left_skill if lc > 0 else right_skill
		var winner_is_hero: bool = lc > 0
		var is_training: bool = enemies[e.unit].get("kind", "") == "training_dummy"
		var is_pure_guard: bool = winner_skill.get("kind", "") == "guard"
		var is_no_damage: bool = winner_skill.get("no_damage", false)
		if not is_training and not is_pure_guard and not is_no_damage:
			var D: int = (decisive_left_val - decisive_right_val) if winner_is_hero else (decisive_right_val - decisive_left_val)
			if D >= 6:
				can_overwhelm = true
				overwhelm_margin = D
				overwhelm_amount = mini(3, D / 3)

	if lc > 0:
		heroes[h.unit].consecutive_clash_loss = 0
		enemies[e.unit].consecutive_clash_loss = int(enemies[e.unit].get("consecutive_clash_loss", 0)) + 1
		if not zxy_clash.is_empty():
			var zxy_win := ZiXingYC.on_clash_win(hero, h.key)
			_emit_zixingyc_memories(events, zxy_win)
			if int(zxy_win.shield) > 0:
				hero.shield += int(zxy_win.shield)
				_emit(events, {"type": "guard", "hero": h.unit, "amount": int(zxy_win.shield)})
			if int(zxy_win.ending) > 0:
				_emit(events, {"type": "ability", "message": "ZiXingYC · 记忆的终点不存在：对存活敌人造成 %d 点伤害" % int(zxy_win.ending)})
				for target in enemies.size():
					if enemies[target].hp > 0:
						_deal_hit(events, true, h.unit, target, int(zxy_win.ending), 1, 1)
		if not zixi_clash.is_empty():
			_emit_metaphysics(events, ZiXi.win_clash(hero, h.key, margin, turn))
		if h.unit == reimu_slot:
			for message in Reimu.release_on_win(hero, enemies, h.key, e.unit, turn):
				_emit(events, {"type": "ability", "message": message})
		if marisa_slot >= 0 and h.unit == marisa_slot:
			if h.key == Marisa.STARS:
				var sp := Marisa.add_spark(hero, 1)
				_emit(events, {"type": "ability", "message": "火花 %d / 10" % sp})
		if hero.character_id == ASH_ID:
			hero.preparation = 1
			_emit(events, {"type": "ability", "message": "灰烬 · 蓄势：获得 1 层准备"})
		if h.key == "support_strike" and heroes.size() > 1:
			for i in heroes.size():
				if i != h.unit and heroes[i].hp > 0:
					heroes[i].shield += 4
			_emit(events, {"type": "ability", "message": "织火 · 援火冲击：其他存活队友获得4护盾"})
		if not first_win_paid:
			first_win_paid = true
			cost += 1
			_emit(events, {"type": "reward", "amount": 1, "hero": h.unit})
		if marisa_slot >= 0 and h.unit == marisa_slot:
			_attack_marisa(events, h, e.unit, lc, true)
		elif left_skill.has("damage_base"):
			if not zxy_clash.is_empty():
				_zixingyc_strike(events, h, e.unit, lc, zxy_clash)
			else:
				_attack_with_zixi_spell(events, h, e.unit, lc, zixi_clash)
		else:
			_resolve_hero_skill(events, h, e.unit, lc)
		if h.key == ZiXingYC.PARADOX:
			if enemies[e.unit].hp > 0:
				var association := ZiXingYC.apply_paradox(hero, enemies[e.unit])
				_emit(events, {"type": "ability", "message": "ZiXingYC · 自指悖论：目标下次与你拼点 −%d" % ZiXingYC.PARADOX_WEAKEN})
				if association >= 0:
					_emit_zixingyc_memory(events, ZiXingYC.ASSOCIATION, association)
				_zixingyc_archive(events, hero, left_skill.archive_corpus)
		else:
			_zixingyc_archive(events, hero, left_skill.get("archive_corpus", ""))
		if h.key == "follow" and enemies[e.unit].hp > 0:
			_emit(events, {"type": "ability", "message": "灰烬 · 余势追击：追加 4 点攻击"})
			_attack(events, true, h.unit, e.unit, 4, 0, 1, 0.65)
		if can_overwhelm and enemies[e.unit].hp > 0 and overwhelm_amount > 0:
			var target_dict: Dictionary = enemies[e.unit]
			var blocked := mini(int(target_dict.shield), overwhelm_amount)
			target_dict.shield -= blocked
			var ov_damage := maxi(0, overwhelm_amount - blocked)
			target_dict.hp = maxi(0, int(target_dict.hp) - ov_damage)
			_emit(events, {
				"type": "overwhelm",
				"allied": true,
				"source": h.unit,
				"target": e.unit,
				"margin": overwhelm_margin,
				"amount": overwhelm_amount,
				"damage": ov_damage,
				"blocked": blocked
			})
		if marisa_slot >= 0 and h.unit == marisa_slot:
			for id in marisa_pre_hps.keys():
				_check_stagger_after_action(events, enemies[id], false, marisa_pre_hps[id])
		else:
			_check_stagger_after_action(events, enemies[e.unit], false, enemy_pre_hp)
		_check_stagger_after_action(events, heroes[h.unit], true, hero_pre_hp)
	else:
		enemies[e.unit].consecutive_clash_loss = 0
		heroes[h.unit].consecutive_clash_loss = int(heroes[h.unit].get("consecutive_clash_loss", 0)) + 1
		if breaker:
			hero.hp = maxi(0, int(hero.hp) - BREAKER_HP_LOSS)
			_emit(events, {"type": "ability", "message": "长锋 · 破阵：拼点失败，损失 %d 生命" % BREAKER_HP_LOSS})
		var refund := int(floor(left_skill.cost * REFUND_RATE))
		cost += refund
		_emit(events, {"type": "refund", "amount": refund, "hero": h.unit})
		var scale := 1.0
		if not zxy_clash.is_empty():
			var zxy_loss := ZiXingYC.on_clash_loss(hero, h.key)
			_emit_zixingyc_memories(events, zxy_loss)
			scale = float(zxy_clash.reduction)
			if scale < 1.0:
				_emit(events, {"type": "ability", "message": "ZiXingYC · 被删除的昨天：本次拼败伤害降低 %d%%" % int(round((1.0 - scale) * 100.0))})
		if not right_skill.get("no_damage", false):
			_attack(events, false, e.unit, h.unit, right_skill.base, right_skill.power, rc, 0.5, "", scale)
		if can_overwhelm and heroes[h.unit].hp > 0 and overwhelm_amount > 0:
			var target_dict: Dictionary = heroes[h.unit]
			var blocked := mini(int(target_dict.shield), overwhelm_amount)
			target_dict.shield -= blocked
			var ov_damage := maxi(0, overwhelm_amount - blocked)
			target_dict.hp = maxi(0, int(target_dict.hp) - ov_damage)
			_emit(events, {
				"type": "overwhelm",
				"allied": false,
				"source": e.unit,
				"target": h.unit,
				"margin": overwhelm_margin,
				"amount": overwhelm_amount,
				"damage": ov_damage,
				"blocked": blocked
			})
		_check_stagger_after_action(events, heroes[h.unit], true, hero_pre_hp)
		_check_stagger_after_action(events, enemies[e.unit], false, enemy_pre_hp)
		if not zixi_clash.is_empty() and hero.hp > 0:
			_emit_metaphysics(events, ZiXi.gain_metaphysics(hero, 1))
		if h.key in [ZiXingYC.ATTENTION, ZiXingYC.RESIDUAL]:
			_zixingyc_archive(events, hero, left_skill.archive_corpus)
	if not zixi_clash.is_empty() and heroes[h.unit].hp > 0:
		_finish_zixi_clash(events, h, 0 if lc > 0 else 1, zixi_clash, margin)
	if h.key == "observe" and hero.hp > 0:
		hero.preparation = 1
		_emit(events, {"type": "ability", "message": "灰烬 · 观察：获得 1 层准备"})

func _emit_metaphysics(events: Array[Dictionary], gained: int) -> void:
	if gained > 0:
		_emit(events, {"type": "ability", "message": "ZiXi：超形上学 +%d" % gained})

func _attack_with_zixi_spell(events: Array[Dictionary], slot: Dictionary, target: int, coins: int, clash: Dictionary) -> void:
	var skill: Dictionary = SKILLS[slot.key]
	var damage: Array[int] = []
	var natural_heads := 0
	for i in coins:
		var roll := _roll(0, 0, 1, 0.65)
		var heads := int(roll.heads)
		natural_heads += heads
		damage.append(ZiXi.convert_tail(clash, heads, 1) * int(skill.damage_power))
	damage[0] += int(skill.damage_base)
	if slot.key == ZiXi.ALMOST_SURE:
		damage[0] += 2 * int(clash.causality)
	if clash.enhanced:
		if slot.key == ZiXi.CENTRAL_LIMIT:
			damage[0] += 4
		if slot.key == ZiXi.CONVERGENCE and natural_heads == int(skill.coins):
			damage[0] += 3
	for i in damage.size():
		if enemies[target].hp <= 0:
			break
		_deal_hit(events, true, slot.unit, target, damage[i], i + 1, coins)

# ZiXingYC 的三张进攻：基础伤害用剩余硬币单独掷算，生成语料每份 +1（上限 +5）。
func _zixingyc_strike(events: Array[Dictionary], slot: Dictionary, target: int, coins: int, clash: Dictionary) -> void:
	var skill: Dictionary = SKILLS[slot.key]
	var hero := heroes[slot.unit]
	var extra := ZiXingYC.generation_bonus(hero)
	if slot.key == ZiXingYC.RESIDUAL:
		extra += ZiXingYC.residual_bonus(hero)
	if slot.key == ZiXingYC.PARADOX and bool(clash.get("weakened", false)):
		extra += ZiXingYC.PARADOX_BONUS
	var damage: Array[int] = []
	for i in maxi(1, coins):
		var roll := _roll(0, 0, 1, 0.65)
		damage.append(int(roll.heads) * int(skill.damage_power))
	damage[0] += int(skill.damage_base) + extra
	for i in damage.size():
		if enemies[target].hp <= 0:
			break
		_deal_hit(events, true, slot.unit, target, damage[i], i + 1, damage.size())

# 符卡结算后自动整理：每回合至多一次成功整理，材料不足时保持原状态。
func _zixingyc_archive(events: Array[Dictionary], hero: Dictionary, recipe: String) -> void:
	if recipe.is_empty() or hero.hp <= 0:
		return
	var picked := ZiXingYC.archive(hero, recipe)
	if not picked.is_empty():
		_emit(events, {"type": "ability", "message": "ZiXingYC · 整理%s语料 +1（整理 %s）" % [ZiXingYC.corpus_name(recipe), ", ".join(_memory_names(picked))]})

func _memory_names(picked: Array) -> Array:
	var names: Array = []
	for memory in picked:
		names.append("%s #%d" % [ZiXingYC.memory_name(String(memory.type)), int(memory.id)])
	return names

func _emit_zixingyc_memories(events: Array[Dictionary], result: Dictionary) -> void:
	for memory in result.get("written", []):
		_emit_zixingyc_memory(events, memory.type, memory.id)

func _emit_zixingyc_memory(events: Array[Dictionary], kind: String, id: int) -> void:
	_emit(events, {"type": "ability", "message": "ZiXingYC · 记忆：写入%s #%d" % [ZiXingYC.memory_name(kind), id]})

func _finish_zixi_clash(events: Array[Dictionary], slot: Dictionary, result: int, clash: Dictionary, margin: int = 0) -> void:
	var hero := heroes[slot.unit]
	var finished := ZiXi.finish_clash(hero, slot.key, result, clash.enhanced, turn, margin)
	if finished.shield > 0:
		_emit(events, {"type": "guard", "hero": slot.unit, "amount": finished.shield})
	if clash.enhanced:
		_emit(events, {"type": "ability", "message": "%s：因果律 %d/%d" % [SKILLS[slot.key].enhance_name, hero.causality, ZiXi.CAUSALITY_MAX]})
	if finished.blast > 0:
		_emit(events, {"type": "ability", "message": "概率一事件：对敌方全体造成 %d 点伤害" % finished.blast})
		for target in enemies.size():
			if enemies[target].hp > 0:
				_deal_hit(events, true, slot.unit, target, finished.blast, 1, 1)
		hero.causality = 0
		hero.no_margin_round = turn + 1
		_emit(events, {"type": "ability", "message": "因果律已清空，下回合暂停分差奖励"})

func _resolve_hero_skill(events: Array[Dictionary], slot: Dictionary, target: int, coins: int) -> void:
	if slot.unit == sakuya_slot:
		var message := Sakuya.release(heroes[sakuya_slot], slot.key, turn)
		if not message.is_empty():
			_emit(events, {"type": "ability", "message": message})
			return
	var skill: Dictionary = SKILLS[slot.key]
	if not skill.get("no_damage", false):
		_attack(events, true, slot.unit, target, skill.base, skill.power, coins, 0.65, slot.key)

func _detonate_dream(events: Array[Dictionary]) -> void:
	var hero := heroes[reimu_slot]
	_emit(events, {"type": "ability", "message": "梦想天生发动"})
	for target in enemies.size():
		var damage := Reimu.dream_damage(hero, enemies[target])
		if enemies[target].hp > 0 and damage > 0:
			_deal_hit(events, true, reimu_slot, target, damage, 1, 1)
	hero.hp = 0
	hero.dream_due = 0
	hero.dream_orbs = 0
	_emit(events, {"type": "ability", "message": "博丽灵梦因梦想天生退场"})

func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
	var heads := 0
	var forced := guaranteed_heads
	if forced:
		guaranteed_heads = false
	for i in coins:
		if forced or rng.randf() < chance:
			heads += 1
	var actual_power := power + (1 if has_relic("mercury_die") else 0)
	return {"value": maxi(0, base + actual_power * heads), "heads": heads}

func _attack(events: Array[Dictionary], allied: bool, source: int, target: int, base: int, power: int, coins: int, chance: float, key: String = "", scale: float = 1.0) -> void:
	var victims: Array[Dictionary] = enemies if allied else heroes
	var fixed_damage: bool = not key.is_empty() and SKILLS[key].get("fixed_damage", false)
	var marks_left := Reimu.exorcism_limit(key) if allied else 0
	var running := base
	for i in coins:
		if victims[target].hp <= 0:
			break
		if fixed_damage:
			running = power + (base if i == 0 else 0)
		elif rng.randf() < chance:
			running += power
		var hit := running
		if scale != 1.0:
			hit = int(floor(hit * scale))
		if allied and i == 0:
			if source == sakuya_slot:
				hit += Sakuya.damage_bonus(heroes[source], turn)
			elif heroes[source].character_id == ZIXINGYC_ID:
				hit += ZiXingYC.generation_bonus(heroes[source])
		elif not allied and enemies[source].get("exorcism_active", false):
			hit = hit / 2
		var damage := _deal_hit(events, allied, source, target, hit, i + 1, coins)
		if marks_left > 0 and damage > 0 and victims[target].hp > 0:
			marks_left -= 1
			var message := Reimu.add_exorcism(victims[target])
			if not message.is_empty():
				_emit(events, {"type": "ability", "message": message})

func _attack_marisa(events: Array[Dictionary], slot: Dictionary, target: int, coins: int, won: bool) -> void:
	var hero := heroes[slot.unit]
	var skill: Dictionary = SKILLS[slot.key]
	if slot.key == Marisa.ORRERY:
		hero.orrery_until = turn + 1
		hero.orrery_active = true
		var sp := Marisa.add_spark(hero, 1)
		_emit(events, {"type": "ability", "message": "天球仪：本回合及下回合每次受击减伤 5，火花 %d / 10" % sp})
		return
	var targets: Array[int] = [target]
	if slot.key == Marisa.LASER or slot.key == Marisa.SPARK:
		for i in enemies.size():
			if i != target and enemies[i].hp > 0:
				targets.append(i)
				if slot.key == Marisa.LASER and targets.size() >= 3:
					break
	var sparks: int = int(hero.get("spark", 0))
	var reimu_alive: bool = reimu_slot >= 0 and int(heroes[reimu_slot].hp) > 0
	var bonus: int = Marisa.damage_bonus(hero, reimu_alive)
	if slot.key == Marisa.SPARK:
		hero.spark = 0
		_emit(events, {"type": "ability", "message": "极限火花：消耗 %d 层火花" % sparks})
	var hit_targets := {}
	var accumulated := 0
	for step_idx in coins:
		var roll := _roll(0, 1, 1, 0.65)
		if roll.heads > 0 or roll.value > 0:
			accumulated += int(skill.get("damage_power", 0))
		for id in targets:
			if enemies[id].hp <= 0:
				continue
			var raw: int = 10 * sparks if slot.key == Marisa.SPARK else int(skill.damage_base) + accumulated - (4 if slot.key == Marisa.LASER else 0)
			if step_idx == 0 and (slot.key != Marisa.SPARK or sparks > 0):
				raw += bonus
			var damage := _deal_hit(events, true, slot.unit, id, maxi(0, raw), step_idx + 1, coins)
			if damage > 0:
				hit_targets[id] = true
	if won and slot.key == Marisa.LASER and not hit_targets.is_empty():
		var sp := Marisa.add_spark(hero, hit_targets.size())
		_emit(events, {"type": "ability", "message": "非指向性激光命中 %d 人：火花 %d / 10" % [hit_targets.size(), sp]})

func _deal_hit(events: Array[Dictionary], allied: bool, source: int, target: int, hit: int, index: int, total: int) -> int:
	var victim := (enemies if allied else heroes)[target]
	if not allied and target == marisa_slot and victim.get("orrery_active", false):
		hit = maxi(0, hit - 5)
	var stagger_extra := 0
	if stagger_enabled and victim.get("is_staggered", false):
		stagger_extra = int(floor(hit * 0.2))
		hit += stagger_extra
	var blocked := mini(int(victim.shield), hit)
	if blocked > 0 and victim.has("shield_until"):
		ZiXi.absorb_carried_shield(victim, blocked)
	victim.shield -= blocked
	var damage := maxi(0, hit - blocked)
	victim.hp = maxi(0, int(victim.hp) - damage)
	if allied and has_relic("piercing_cone") and blocked > 0 and victim.hp > 0:
		var pierce: int = mini(3, int(victim.hp))
		victim.hp = maxi(0, int(victim.hp) - pierce)
		_emit(events, {"type": "ability", "message": "穿刺圆锥：穿透护盾直接造成 %d 点伤害" % pierce})
	if allied and damage > 0 and victim.hp == 0 and has_relic("leech_shard"):
		for h in heroes:
			if h.hp > 0:
				h.hp = mini(int(h.max_hp), int(h.hp) + 3)
		_emit(events, {"type": "ability", "message": "汲血结晶：击败敌人，存活队员恢复 3 点生命"})
	if not allied and target == reimu_slot and victim.hp == 0:
		victim.dream_due = 0
		victim.dream_orbs = 0
	if not allied and damage > 0 and enemies[source].kind == "scout" and int(victim.get("preparation", 0)) > 0:
		victim.preparation = 0
		_emit(events, {"type": "ability", "message": "裂影斥候：命中移除了灰烬的准备"})
	var strike_evt: Dictionary = {"type": "strike", "allied": allied, "source": source, "target": target, "damage": damage, "blocked": blocked, "hit": index, "total": total}
	if stagger_extra > 0:
		strike_evt["stagger_bonus"] = stagger_extra
	_emit(events, strike_evt)
	return damage

func _check_stagger_after_action(events: Array[Dictionary], unit: Dictionary, allied: bool, pre_hp: int) -> bool:
	if not stagger_enabled:
		return false
	if unit.hp <= 0 or unit.get("is_staggered", false) or int(unit.get("stagger_immune_turns", 0)) > 0:
		return false
	var trigger_bloodline := false
	if not unit.get("stagger_threshold_triggered", false):
		if pre_hp * 2 >= int(unit.max_hp) and int(unit.hp) * 2 < int(unit.max_hp):
			trigger_bloodline = true
			unit.stagger_threshold_triggered = true
	var trigger_clash := int(unit.get("consecutive_clash_loss", 0)) >= 2
	if trigger_bloodline or trigger_clash:
		unit.is_staggered = true
		unit.consecutive_clash_loss = 0
		var reason := "生命跌破 50%" if trigger_bloodline and not trigger_clash else ("连续两次拼败" if trigger_clash and not trigger_bloodline else "跌破血线且连续拼败")
		var u_idx := heroes.find(unit) if allied else enemies.find(unit)
		_emit(events, {
			"type": "stagger",
			"allied": allied,
			"unit": u_idx,
			"name": unit.get("name", ""),
			"reason": reason
		})
		_extinguish_remaining_slots(events, unit, allied)
		return true
	return false

func _extinguish_remaining_slots(events: Array[Dictionary], unit: Dictionary, allied: bool) -> void:
	var unit_index := heroes.find(unit) if allied else enemies.find(unit)
	if unit_index < 0:
		return
	var slots: Array[Dictionary] = hero_slots if allied else enemy_slots
	for slot in slots:
		if slot.unit == unit_index and slot.active and not slot.get("done", false) and not slot.get("cancelled", false):
			slot.cancelled = true
			slot.active = false
			if allied:
				var key: String = slot.key
				var refund := int(SKILLS[key].cost) if SKILLS.has(key) else 0
				cost += refund
				if slot.get("enhanced", false):
					ZiXi.unreserve_enhancement(heroes[slot.unit], slot.id)
					slot.erase("enhanced")
				_emit(events, {
					"type": "cancelled",
					"hero": slot.unit,
					"slot": slot.id,
					"key": key,
					"reason": "失衡中断行动",
					"refund": refund
				})
			else:
				var key: String = slot.key
				_emit(events, {
					"type": "cancelled",
					"enemy": slot.unit,
					"slot": slot.id,
					"key": key,
					"reason": "失衡中断行动"
				})

func _process_stagger_wake_up() -> void:
	for unit in heroes:
		if unit.get("is_staggered", false):
			unit.is_staggered = false
			unit.stagger_immune_turns = 1
		elif int(unit.get("stagger_immune_turns", 0)) > 0:
			unit.stagger_immune_turns = maxi(0, int(unit.stagger_immune_turns) - 1)
		unit.consecutive_clash_loss = 0
	for unit in enemies:
		if unit.get("is_staggered", false):
			unit.is_staggered = false
			unit.stagger_immune_turns = 1
		elif int(unit.get("stagger_immune_turns", 0)) > 0:
			unit.stagger_immune_turns = maxi(0, int(unit.stagger_immune_turns) - 1)
		unit.consecutive_clash_loss = 0

func _living_target(preferred: int) -> int:
	if preferred >= 0 and preferred < heroes.size() and heroes[preferred].hp > 0:
		return preferred
	for i in heroes.size():
		if heroes[i].hp > 0:
			return i
	return -1

func _check_outcome(events: Array[Dictionary]) -> void:
	if not outcome.is_empty():
		return
	var alive_enemies := enemies.any(func(unit: Dictionary) -> bool: return unit.hp > 0)
	var alive_heroes := heroes.any(func(unit: Dictionary) -> bool: return unit.hp > 0)
	if not alive_enemies:
		outcome = "victory"
		if has_relic("ember_pouch"):
			cost += 4
			_emit(events, {"type": "reward", "amount": 4, "message": "余烬小袋：胜利额外获得 4 cost"})
	elif not alive_heroes:
		outcome = "defeat"
	if not outcome.is_empty():
		_emit(events, {"type": "outcome", "result": outcome})

func _emit(events: Array[Dictionary], event: Dictionary) -> void:
	event["snapshot"] = snapshot()
	events.append(event)
