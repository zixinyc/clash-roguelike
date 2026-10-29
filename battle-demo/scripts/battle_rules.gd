class_name DemoBattleRules
extends RefCounted

const MAX_PLAYS := 3
const BASE_INCOME := 3
const REFUND_RATE := 0.5
const SKILLS := {
	"cleave": {"name": "断轨", "cost": 3, "base": 5, "power": 4, "coins": 2, "kind": "attack", "tag": "重击", "description": "高威力 · 两枚硬币", "flavor": "将退路，一并斩断。"},
	"ember": {"name": "余烬斩", "cost": 2, "base": 4, "power": 3, "coins": 2, "kind": "attack", "tag": "斩击", "description": "均衡威力 · 两枚硬币", "flavor": "火熄灭前，再向前一步。"},
	"needle": {"name": "穿隙", "cost": 1, "base": 3, "power": 2, "coins": 2, "kind": "attack", "tag": "突刺", "description": "低费用 · 两枚硬币", "flavor": "裂隙，往往只需一瞬。"},
	"steady": {"name": "定锋", "cost": 2, "base": 7, "power": 1, "coins": 2, "kind": "attack", "tag": "稳势", "description": "稳定威力 · 两枚硬币", "flavor": "让摇摆的，只剩敌人。"},
	"guard": {"name": "守夜", "cost": 1, "base": 0, "power": 0, "coins": 0, "kind": "guard", "tag": "防御", "description": "获得 9 护盾 · 持续本回合", "flavor": "总有人，要守住最后一盏灯。"},
	"risk": {"name": "孤注", "cost": 2, "base": 2, "power": 4, "coins": 3, "kind": "attack", "tag": "搏命", "description": "波动威力 · 三枚硬币", "flavor": "把最后的余温，押上。"}
}

var rng := RandomNumberGenerator.new()
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var hand: Array[String] = []
var cost := 9
var turn := 1
var plays := 0
var first_win_paid := false
var outcome := ""

func start(seed_value: int = 73129) -> void:
	rng.seed = seed_value
	heroes = [
		{"name": "灰烬", "role": "前锋", "hp": 36, "max_hp": 36, "shield": 0, "acted": false},
		{"name": "长锋", "role": "游刃", "hp": 32, "max_hp": 32, "shield": 0, "acted": false},
		{"name": "织火", "role": "守望", "hp": 34, "max_hp": 34, "shield": 0, "acted": false}
	]
	enemies = [
		{"name": "锈刃巡卫", "role": "重刃", "hp": 38, "max_hp": 38, "shield": 0, "spent": false, "base": 4, "power": 3, "coins": 2, "intent": "锈蚀挥砍", "target": 0},
		{"name": "失序哨兵", "role": "刺刃", "hp": 32, "max_hp": 32, "shield": 0, "spent": false, "base": 3, "power": 3, "coins": 2, "intent": "贯穿指令", "target": 1}
	]
	hand.assign(["cleave", "ember", "needle", "steady", "guard"])
	cost = 9
	turn = 1
	plays = 0
	first_win_paid = false
	outcome = ""

func snapshot() -> Dictionary:
	return {"heroes": heroes.duplicate(true), "enemies": enemies.duplicate(true), "hand": hand.duplicate(), "cost": cost, "turn": turn, "plays": plays, "outcome": outcome}

func can_play(card_index: int, hero_index: int, enemy_index: int) -> String:
	if not outcome.is_empty():
		return "战斗已经结束"
	if card_index < 0 or card_index >= hand.size():
		return "先选择一张手牌"
	if hero_index < 0 or hero_index >= heroes.size() or heroes[hero_index].hp <= 0:
		return "请选择仍在场的小队成员"
	if heroes[hero_index].acted:
		return "这位成员本回合已经行动，换一位成员吧"
	if plays >= MAX_PLAYS:
		return "本回合已打出 3 张牌，请结束回合"
	var skill: Dictionary = SKILLS[hand[card_index]]
	if cost < int(skill.cost):
		return "cost 不足，可以结束回合获得基础收入"
	if skill.kind == "attack" and (enemy_index < 0 or enemy_index >= enemies.size() or enemies[enemy_index].hp <= 0):
		return "请选择仍在场的敌人"
	return ""

func play(card_index: int, hero_index: int, enemy_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not can_play(card_index, hero_index, enemy_index).is_empty():
		return events
	var key: String = hand[card_index]
	var skill: Dictionary = SKILLS[key]
	var paid := int(skill.cost)
	cost -= paid
	plays += 1
	heroes[hero_index].acted = true
	hand.remove_at(card_index)
	_emit(events, {"type": "paid", "hero": hero_index, "skill": skill.name, "paid": paid})
	if skill.kind == "guard":
		heroes[hero_index].shield += 9
		_emit(events, {"type": "guard", "hero": hero_index, "amount": 9})
		return events
	var hero_coins := int(skill.coins)
	if not enemies[enemy_index].spent:
		enemies[enemy_index].spent = true
		var enemy_coins := int(enemies[enemy_index].coins)
		var ties := 0
		while hero_coins > 0 and enemy_coins > 0:
			var left := _roll(int(skill.base), int(skill.power), hero_coins, 0.65)
			var right := _roll(int(enemies[enemy_index].base), int(enemies[enemy_index].power), enemy_coins, 0.5)
			var winner := 0 if left.value > right.value else 1
			var tied: bool = left.value == right.value
			var decider := false
			if tied:
				ties += 1
				if ties >= 3:
					winner = rng.randi_range(0, 1)
					decider = true
					ties = 0
				else:
					winner = -1
			else:
				ties = 0
			var old_hero := hero_coins
			var old_enemy := enemy_coins
			if winner == 0:
				enemy_coins -= 1
			elif winner == 1:
				hero_coins -= 1
			_emit(events, {"type": "clash", "hero": hero_index, "enemy": enemy_index, "left": left.value, "right": right.value, "left_heads": left.heads, "right_heads": right.heads, "hero_coins": old_hero, "enemy_coins": old_enemy, "hero_remaining": hero_coins, "enemy_remaining": enemy_coins, "winner": winner, "decider": decider})
		if hero_coins > 0:
			if not first_win_paid:
				cost += 1
				first_win_paid = true
				_emit(events, {"type": "reward", "amount": 1, "hero": hero_index})
			_attack(events, true, hero_index, enemy_index, int(skill.base), int(skill.power), hero_coins, 0.65)
		else:
			var refund := int(floor(paid * REFUND_RATE))
			cost += refund
			_emit(events, {"type": "refund", "amount": refund, "paid": paid, "hero": hero_index})
			_attack(events, false, enemy_index, hero_index, int(enemies[enemy_index].base), int(enemies[enemy_index].power), enemy_coins, 0.5)
	else:
		_emit(events, {"type": "unopposed", "hero": hero_index, "enemy": enemy_index})
		_attack(events, true, hero_index, enemy_index, int(skill.base), int(skill.power), hero_coins, 0.65)
	_check_outcome(events)
	return events

func end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not outcome.is_empty():
		return events
	for i in enemies.size():
		if enemies[i].hp <= 0 or enemies[i].spent:
			continue
		var target := _living_target(int(enemies[i].target))
		if target < 0:
			break
		enemies[i].spent = true
		_emit(events, {"type": "enemy_turn", "enemy": i, "hero": target})
		_attack(events, false, i, target, int(enemies[i].base), int(enemies[i].power), int(enemies[i].coins), 0.5)
		_check_outcome(events)
		if not outcome.is_empty():
			return events
	turn += 1
	plays = 0
	first_win_paid = false
	cost += BASE_INCOME
	for hero in heroes:
		hero.acted = false
		hero.shield = 0
	for i in enemies.size():
		enemies[i].spent = false
		enemies[i].target = _living_target((turn + i - 1) % heroes.size())
	var keys: Array = SKILLS.keys()
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value: Variant = keys[i]
		keys[i] = keys[j]
		keys[j] = value
	hand.clear()
	for i in 5:
		hand.append(str(keys[i]))
	_emit(events, {"type": "new_turn", "amount": BASE_INCOME})
	return events

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
