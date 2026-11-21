extends "res://scripts/battle_rules.gd"

const DUEL_CARDS := ["cleave", "ember", "needle", "steady", "guard", "nova"]
const HEADS_CHANCE := 0.65

var guest_first_win_paid := false

func start_duel(seed_value: int) -> void:
	rng.seed = seed_value
	heroes.assign(create_roster().slice(0, 2))
	enemies.assign(heroes.duplicate(true))
	for unit in heroes + enemies:
		unit.kind = "duelist"
		unit.spent = false
	configured_hand.assign(DUEL_CARDS)
	_prepare_round()

func _prepare_round() -> void:
	phase = "response"
	plays = 0
	first_win_paid = false
	guest_first_win_paid = false
	hand.assign(configured_hand)
	hero_slots.clear()
	enemy_slots.clear()
	for side in 2:
		var units := heroes if side == 0 else enemies
		var slots := hero_slots if side == 0 else enemy_slots
		for unit in units.size():
			units[unit].shield = 0
			for category in 3:
				slots.append(_make_slot(slots.size(), unit, category, units[unit], side == 0))

func next_round() -> void:
	if phase != "finished":
		return
	enemy_cost += BASE_INCOME
	super.next_round()

func accept_plan(guest: bool, plan: Array) -> String:
	if plan.size() > hero_slots.size():
		return "行动数超出上限"
	# The shared validator treats the acting side as heroes. Only the host swaps lenses.
	if guest:
		_swap_sides()
	var previous: Array[Dictionary] = hero_slots
	hero_slots = previous.duplicate(true)
	var error := _assign_plan(plan)
	if not error.is_empty():
		hero_slots = previous
	if guest:
		_swap_sides()
	return error

func _assign_plan(plan: Array) -> String:
	var used_slots := {}
	for action in plan:
		if not action is Dictionary or not action.get("slot") is int or not action.get("card_key") is String or not action.get("target") is int:
			return "行动格式无效"
		if used_slots.has(action.slot):
			return "行动格重复"
		used_slots[action.slot] = true
		var card := hand.find(action.card_key)
		if card < 0:
			return "这张牌不在携带牌中"
		var error := assign(card, action.slot, action.target)
		if not error.is_empty():
			return error
	return ""

func _swap_sides() -> void:
	var units := heroes
	heroes = enemies
	enemies = units
	var slots := hero_slots
	hero_slots = enemy_slots
	enemy_slots = slots
	var previous_cost := cost
	cost = enemy_cost
	enemy_cost = previous_cost

func snapshot() -> Dictionary:
	var state := super.snapshot()
	state.enemy_cost = enemy_cost
	state.pvp = true
	return state

func lock_and_resolve() -> Array[Dictionary]:
	if phase == "response" and outcome.is_empty():
		for slot in enemy_slots:
			if slot.active:
				enemy_cost -= get_card_cost(slot.key)
	return super.lock_and_resolve()

func _turn_timeline() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for h in hero_slots:
		if not h.active or not h.targeted:
			continue
		for e in enemy_slots:
			if not e.active or not e.targeted:
				continue
			var h_aims: bool = h.target == e.id
			var e_aims: bool = e.target == h.id
			var mutual := h_aims and e_aims
			var intercept: bool = (h_aims and h.speed > e.speed) or (e_aims and e.speed > h.speed)
			if mutual or intercept:
				candidates.append({"hero": h.id, "enemy": e.id, "mutual": mutual, "speed": maxi(h.speed, e.speed), "order": h.id * enemy_slots.size() + e.id})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.mutual != b.mutual:
			return a.mutual
		return a.speed > b.speed if a.speed != b.speed else a.order < b.order)
	var timeline: Array[Dictionary] = []
	var paired_heroes := {}
	var paired_enemies := {}
	for entry in candidates:
		if paired_heroes.has(entry.hero) or paired_enemies.has(entry.enemy):
			continue
		paired_heroes[entry.hero] = true
		paired_enemies[entry.enemy] = true
		entry.order = entry.hero * 2 if turn % 2 == 1 else entry.enemy * 2
		timeline.append(entry)
	for slot in hero_slots:
		if slot.active and not paired_heroes.has(slot.id):
			timeline.append({"speed": slot.speed, "order": slot.id * 2 + int(turn % 2 == 0), "hero": slot.id, "enemy": -1})
	for slot in enemy_slots:
		if slot.active and not paired_enemies.has(slot.id):
			timeline.append({"speed": slot.speed, "order": slot.id * 2 + int(turn % 2 == 1), "hero": -1, "enemy": slot.id})
	return timeline

func _solo(events: Array[Dictionary], slot: Dictionary, allied: bool) -> void:
	var skill: Dictionary = SKILLS[slot.key]
	var units := heroes if allied else enemies
	if not slot.targeted:
		units[slot.unit].shield += GUARD_AMOUNT
		_emit(events, {"type": "guard" if allied else "enemy_guard", "hero": slot.unit, "enemy": slot.unit, "amount": GUARD_AMOUNT})
		return
	var targets := enemy_slots if allied else hero_slots
	var target: int = targets[slot.target].unit
	var opponents := enemies if allied else heroes
	if opponents[target].hp <= 0:
		_emit(events, {"type": "cancelled", "reason": "目标已退场，行动取消"})
		return
	_emit(events, {"type": "paid" if allied else "enemy_turn", "hero": slot.unit, "enemy": slot.unit, "skill": skill.name})
	_attack(events, allied, slot.unit, target, skill.base, skill.power, skill.coins, HEADS_CHANCE, slot.key)

func _clash(events: Array[Dictionary], h: Dictionary, e: Dictionary) -> void:
	var left: Dictionary = SKILLS[h.key]
	var right: Dictionary = SKILLS[e.key]
	var left_bonus := clash_bonus(h.key, heroes[h.unit].character_id, 0)
	var right_bonus := clash_bonus(e.key, enemies[e.unit].character_id, 0)
	var lc: int = left.coins
	var rc: int = right.coins
	var ties := 0
	while lc > 0 and rc > 0:
		if ties >= 100:
			_refund(events, h, true, "stalemate")
			_refund(events, e, false, "stalemate")
			return
		var l := _roll(left.base + left_bonus, left.power, lc, HEADS_CHANCE)
		var r := _roll(right.base + right_bonus, right.power, rc, HEADS_CHANCE)
		var winner := -1
		var old_lc := lc
		var old_rc := rc
		if l.value > r.value:
			winner = 0
			rc -= 1
		elif r.value > l.value:
			winner = 1
			lc -= 1
		ties = ties + 1 if winner == -1 else 0
		_emit(events, {"type": "clash", "hero": h.unit, "enemy": e.unit,
			"left": l.value, "right": r.value, "left_heads": l.heads, "right_heads": r.heads,
			"hero_coins": old_lc, "enemy_coins": old_rc, "hero_remaining": lc, "enemy_remaining": rc,
			"winner": winner, "decider": false})
	var allied := lc > 0
	var losing_units := enemies if allied else heroes
	var loser := e if allied else h
	var winning_skill := left if allied else right
	var winning_slot := h if allied else e
	var loss_bonus := right_bonus if allied else left_bonus
	if loss_bonus > 0:
		losing_units[loser.unit].hp = maxi(0, int(losing_units[loser.unit].hp) - BREAKER_HP_LOSS)
		_emit(events, {"type": "ability", "message": "长锋 · 破阵：拼点失败，损失 %d 生命" % BREAKER_HP_LOSS})
	_refund(events, loser, not allied, "refund")
	if allied and not first_win_paid:
		first_win_paid = true
		cost += 1
	elif not allied and not guest_first_win_paid:
		guest_first_win_paid = true
		enemy_cost += 1
	var winning_units := heroes if allied else enemies
	if winning_units[winning_slot.unit].character_id == ASH_ID:
		winning_units[winning_slot.unit].preparation = 1
	_attack(events, allied, winning_slot.unit, loser.unit, winning_skill.base, winning_skill.power, lc if allied else rc, HEADS_CHANCE, winning_slot.key)

func _refund(events: Array[Dictionary], slot: Dictionary, allied: bool, kind: String) -> void:
	var amount := int(floor(get_card_cost(slot.key) * REFUND_RATE))
	if allied:
		cost += amount
	else:
		enemy_cost += amount
	_emit(events, {"type": kind, "allied": allied, "amount": amount})

static func view_state(state: Dictionary, guest: bool) -> Dictionary:
	var view := state.duplicate(true)
	if guest:
		view.heroes = state.enemies.duplicate(true)
		view.enemies = state.heroes.duplicate(true)
		view.hero_slots = state.enemy_slots.duplicate(true)
		view.enemy_slots = state.hero_slots.duplicate(true)
		view.cost = state.enemy_cost
		view.enemy_cost = state.cost
		view.outcome = _reverse_outcome(state.outcome)
	if state.phase == "response":
		# A planning snapshot starts with blank enemy slots even after one peer locks.
		view.reserved = 0
		for slot in view.hero_slots + view.enemy_slots:
			slot.merge({"active": false, "card": -1, "target": -1, "targeted": false, "key": ""}, true)
	else:
		for slot in view.enemy_slots:
			if slot.active and slot.get("targeted", false):
				slot.target = view.hero_slots[slot.target].unit
	return view

static func view_events(events: Array[Dictionary], guest: bool) -> Array[Dictionary]:
	var view: Array[Dictionary] = []
	for event in events:
		var item := event.duplicate()
		item.snapshot = view_state(event.snapshot, guest)
		if guest:
			if event.has("allied"):
				item.allied = not event.allied
			match event.type:
				"clash":
					for keys in [["hero", "enemy"], ["left", "right"], ["left_heads", "right_heads"], ["hero_coins", "enemy_coins"], ["hero_remaining", "enemy_remaining"]]:
						item[keys[0]] = event[keys[1]]
						item[keys[1]] = event[keys[0]]
					item.winner = 1 - event.winner if event.winner >= 0 else -1
				"guard", "enemy_guard":
					item.type = "enemy_guard" if event.type == "guard" else "guard"
				"paid", "enemy_turn":
					item.type = "enemy_turn" if event.type == "paid" else "paid"
				"outcome":
					item.result = _reverse_outcome(event.result)
		view.append(item)
	return view

static func _reverse_outcome(result: String) -> String:
	match result:
		"victory":
			return "defeat"
		"defeat":
			return "victory"
	return result
