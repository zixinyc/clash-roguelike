class_name DemoBattleRules
extends RefCounted

const MAX_PLAYS := 6
const BASE_INCOME := 3
const REFUND_RATE := 0.5
const SKILLS := {
	"cleave": {"name": "断轨", "cost": 3, "base": 5, "power": 4, "coins": 2, "kind": "attack", "tag": "重击", "description": "高威力 · 两枚硬币", "flavor": "将退路，一并斩断。"},
	"ember": {"name": "余烬斩", "cost": 2, "base": 4, "power": 3, "coins": 2, "kind": "attack", "tag": "斩击", "description": "均衡威力 · 两枚硬币", "flavor": "火熄灭前，再向前一步。"},
	"needle": {"name": "穿隙", "cost": 1, "base": 3, "power": 2, "coins": 2, "kind": "attack", "tag": "突刺", "description": "低费用 · 两枚硬币", "flavor": "裂隙，往往只需一瞬。"},
	"steady": {"name": "定锋", "cost": 2, "base": 7, "power": 1, "coins": 2, "kind": "attack", "tag": "稳势", "description": "稳定威力 · 两枚硬币", "flavor": "让摇摆的，只剩敌人。"},
	"guard": {"name": "守夜", "cost": 1, "base": 0, "power": 0, "coins": 0, "kind": "guard", "tag": "防御", "description": "获得 9 护盾 · 持续本回合", "flavor": "总有人，要守住最后一盏灯。"},
	"nova": {"name": "破晓", "cost": 4, "base": 6, "power": 4, "coins": 3, "kind": "ultimate", "tag": "大招", "description": "三枚硬币 · 爆发", "flavor": "以余火，换黎明。"},
	"risk": {"name": "孤注", "cost": 2, "base": 2, "power": 4, "coins": 3, "kind": "attack", "tag": "搏命", "description": "波动威力 · 三枚硬币", "flavor": "把最后的余温，押上。"}
}

const CATEGORIES := ["进攻", "大招", "防御"]
const RESPONSE_SECONDS := 180.0
var rng := RandomNumberGenerator.new()
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var hand: Array[String] = []
var hero_slots: Array[Dictionary] = []
var enemy_slots: Array[Dictionary] = []
var cost := 12
var turn := 1
var plays := 0
var first_win_paid := false
var outcome := ""
var phase := "response"
var remaining := RESPONSE_SECONDS

func start(seed_value: int = 73129) -> void:
	rng.seed = seed_value
	heroes = [
		{"name": "灰烬", "role": "前锋", "hp": 48, "max_hp": 48, "shield": 0, "acted": false, "speed_min": 3, "speed_max": 6},
		{"name": "长锋", "role": "游刃", "hp": 42, "max_hp": 42, "shield": 0, "acted": false, "speed_min": 5, "speed_max": 8},
		{"name": "织火", "role": "守望", "hp": 46, "max_hp": 46, "shield": 0, "acted": false, "speed_min": 2, "speed_max": 5}
	]
	enemies = [
		{"name": "锈刃巡卫", "hp": 65, "max_hp": 65, "shield": 0, "spent": false, "speed_min": 2, "speed_max": 5},
		{"name": "失序哨兵", "hp": 58, "max_hp": 58, "shield": 0, "spent": false, "speed_min": 4, "speed_max": 7}
	]
	cost = 12
	turn = 1
	outcome = ""
	_prepare_round()

func _prepare_round() -> void:
	phase = "response"
	remaining = RESPONSE_SECONDS
	plays = 0
	first_win_paid = false
	hand.assign(["cleave", "ember", "needle", "steady", "guard", "nova"])
	hero_slots.clear()
	enemy_slots.clear()
	for side in 2:
		var units: Array[Dictionary] = heroes if side == 0 else enemies
		var slots: Array[Dictionary] = hero_slots if side == 0 else enemy_slots
		for u in units.size():
			units[u].shield = 0
			if side == 0:
				units[u].acted = false
			else:
				units[u].spent = false
			for category in 3:
				var slot := {"id": slots.size(), "unit": u, "category": category, "speed": rng.randi_range(units[u].speed_min, units[u].speed_max), "active": false, "card": -1, "target": -1, "key": "", "done": false}
				if side == 1 and units[u].hp > 0:
					var second := 1 if (turn + u) % 2 == 0 else 2
					slot.active = category == 0 or category == second
					if slot.active:
						slot.key = ["ember", "nova", "guard"][category]
						slot.target = _living_target((turn + u + category - 1) % heroes.size()) if category != 2 else u
				slots.append(slot)

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
	return {"heroes": heroes.duplicate(true), "enemies": enemies.duplicate(true), "hand": hand.duplicate(), "hero_slots": hero_slots.duplicate(true), "enemy_slots": public_enemies, "cost": cost, "reserved": reserved_cost() if phase == "response" else 0, "turn": turn, "plays": plays, "outcome": outcome, "phase": phase}

func category_for(key: String) -> int:
	return 2 if SKILLS[key].kind == "guard" else (1 if SKILLS[key].kind == "ultimate" else 0)

func can_assign(card: int, slot_id: int, target: int) -> String:
	if phase != "response" or not outcome.is_empty():
		return "当前不能修改行动"
	if card < 0 or card >= hand.size() or slot_id < 0 or slot_id >= hero_slots.size():
		return "请选择手牌与我方行动格"
	var slot: Dictionary = hero_slots[slot_id]
	if heroes[slot.unit].hp <= 0:
		return "该成员已退场"
	if category_for(hand[card]) != slot.category:
		return "卡牌类别与行动格不符"
	var count := 0
	for other in hero_slots:
		if other.id == slot_id or not other.active:
			continue
		if other.card == card:
			return "这张牌已经安排，请先撤销原行动"
		if other.unit == slot.unit:
			count += 1
	if count >= 2:
		return "每位成员最多安排两次行动"
	var old_cost := int(SKILLS[slot.key].cost) if slot.active else 0
	if reserved_cost() - old_cost + int(SKILLS[hand[card]].cost) > cost:
		return "可用 cost 不足，请先撤销其他行动"
	if slot.category != 2:
		if target < 0 or target >= enemy_slots.size() or enemies[enemy_slots[target].unit].hp <= 0:
			return "请选择敌方行动格"
	return ""

func assign(card: int, slot_id: int, target: int) -> String:
	var error := can_assign(card, slot_id, target)
	if not error.is_empty():
		return error
	var slot: Dictionary = hero_slots[slot_id]
	slot.active = true
	slot.card = card
	slot.key = hand[card]
	slot.target = target if slot.category != 2 else slot.unit
	return ""

func cancel(slot_id: int) -> void:
	if phase != "response" or slot_id < 0 or slot_id >= hero_slots.size():
		return
	hero_slots[slot_id].active = false
	hero_slots[slot_id].card = -1
	hero_slots[slot_id].key = ""
	hero_slots[slot_id].target = -1

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
	for slot in hero_slots:
		if slot.active:
			cost -= int(SKILLS[slot.key].cost)
			plays += 1
	_emit(events, {"type": "reveal"})
	var pairs := {}
	for enemy in enemy_slots:
		if not enemy.active or enemy.category == 2:
			continue
		var candidates: Array[Dictionary] = []
		for hero in hero_slots:
			if hero.active and hero.category != 2 and hero.target == enemy.id:
				if hero.unit == enemy.target or hero.speed > enemy.speed:
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
			timeline.append({"speed": maxi(slot.speed, hero_slots[h].speed) if h >= 0 else slot.speed, "order": 9 + slot.id, "hero": h, "enemy": slot.id})
	timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.speed > b.speed if a.speed != b.speed else a.order < b.order)
	for entry in timeline:
		if not outcome.is_empty():
			break
		var h: Dictionary = hero_slots[entry.hero] if entry.hero >= 0 else {}
		var e: Dictionary = enemy_slots[entry.enemy] if entry.enemy >= 0 else {}
		var h_alive: bool = not h.is_empty() and heroes[h.unit].hp > 0
		var e_alive: bool = not e.is_empty() and enemies[e.unit].hp > 0
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
	cost += BASE_INCOME
	_prepare_round()

func _solo(events: Array[Dictionary], slot: Dictionary, allied: bool) -> void:
	var skill: Dictionary = SKILLS[slot.key]
	var units: Array[Dictionary] = heroes if allied else enemies
	if slot.category == 2:
		units[slot.unit].shield += 9
		_emit(events, {"type": "guard" if allied else "enemy_guard", "hero": slot.unit, "enemy": slot.unit, "amount": 9})
		return
	var target: int = enemy_slots[slot.target].unit if allied else slot.target
	var victims: Array[Dictionary] = enemies if allied else heroes
	if victims[target].hp <= 0:
		_emit(events, {"type": "cancelled", "reason": "目标已退场，行动取消"})
		return
	_emit(events, {"type": "paid", "hero": slot.unit, "skill": skill.name, "paid": 0} if allied else {"type": "enemy_turn", "enemy": slot.unit, "hero": target})
	_attack(events, allied, slot.unit, target, skill.base, skill.power, skill.coins, 0.65 if allied else 0.5)

func _clash(events: Array[Dictionary], h: Dictionary, e: Dictionary) -> void:
	var left_skill: Dictionary = SKILLS[h.key]
	var right_skill: Dictionary = SKILLS[e.key]
	var lc := int(left_skill.coins)
	var rc := int(right_skill.coins)
	var ties := 0
	_emit(events, {"type": "intercept" if h.unit != e.target else "engage", "hero": h.unit, "enemy": e.unit})
	while lc > 0 and rc > 0:
		var left_min := maxi(0, int(left_skill.base) + mini(0, int(left_skill.power) * lc))
		var left_max := maxi(0, int(left_skill.base) + maxi(0, int(left_skill.power) * lc))
		var right_min := maxi(0, int(right_skill.base) + mini(0, int(right_skill.power) * rc))
		var right_max := maxi(0, int(right_skill.base) + maxi(0, int(right_skill.power) * rc))
		if (left_min == left_max and right_min == right_max and left_min == right_min) or ties >= 100:
			var refund := int(floor(left_skill.cost * REFUND_RATE))
			cost += refund
			_emit(events, {"type": "stalemate", "amount": refund})
			return
		var left := _roll(left_skill.base, left_skill.power, lc, 0.65)
		var right := _roll(right_skill.base, right_skill.power, rc, 0.5)
		var winner := -1 if left.value == right.value else (0 if left.value > right.value else 1)
		var old_lc := lc
		var old_rc := rc
		if winner == 0:
			rc -= 1
		elif winner == 1:
			lc -= 1
		ties = ties + 1 if winner == -1 else 0
		_emit(events, {"type": "clash", "hero": h.unit, "enemy": e.unit, "left": left.value, "right": right.value, "left_heads": left.heads, "right_heads": right.heads, "hero_coins": old_lc, "enemy_coins": old_rc, "hero_remaining": lc, "enemy_remaining": rc, "winner": winner, "decider": false})
	if lc > 0:
		if not first_win_paid:
			first_win_paid = true
			cost += 1
			_emit(events, {"type": "reward", "amount": 1, "hero": h.unit})
		_attack(events, true, h.unit, e.unit, left_skill.base, left_skill.power, lc, 0.65)
	else:
		var refund := int(floor(left_skill.cost * REFUND_RATE))
		cost += refund
		_emit(events, {"type": "refund", "amount": refund, "hero": h.unit})
		_attack(events, false, e.unit, h.unit, right_skill.base, right_skill.power, rc, 0.5)

func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
	var heads := 0
	for i in coins:
		if rng.randf() < chance:
			heads += 1
	return {"value": maxi(0, base + power * heads), "heads": heads}

func _attack(events: Array[Dictionary], allied: bool, source: int, target: int, base: int, power: int, coins: int, chance: float) -> void:
	var victims: Array[Dictionary] = enemies if allied else heroes
	var running := base
	for i in coins:
		if victims[target].hp <= 0:
			break
		if rng.randf() < chance:
			running += power
		var blocked := mini(int(victims[target].shield), running)
		victims[target].shield -= blocked
		var damage := maxi(0, running - blocked)
		victims[target].hp = maxi(0, int(victims[target].hp) - damage)
		_emit(events, {"type": "strike", "allied": allied, "source": source, "target": target, "damage": damage, "blocked": blocked, "hit": i + 1, "total": coins})

func _living_target(preferred: int) -> int:
	if preferred >= 0 and preferred < heroes.size() and heroes[preferred].hp > 0:
		return preferred
	for i in heroes.size():
		if heroes[i].hp > 0:
			return i
	return -1

func _check_outcome(events: Array[Dictionary]) -> void:
	var alive_enemies := enemies.any(func(unit: Dictionary) -> bool: return unit.hp > 0)
	var alive_heroes := heroes.any(func(unit: Dictionary) -> bool: return unit.hp > 0)
	if not alive_enemies:
		outcome = "victory"
	elif not alive_heroes:
		outcome = "defeat"
	if not outcome.is_empty():
		_emit(events, {"type": "outcome", "result": outcome})

func _emit(events: Array[Dictionary], event: Dictionary) -> void:
	event["snapshot"] = snapshot()
	events.append(event)
