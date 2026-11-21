extends "res://scripts/battle_rules.gd"

# Compatible with the planning view. This model stores a private draft only.
var authoritative_view := {}

func load_view(state: Dictionary) -> void:
	authoritative_view = state.duplicate(true)
	heroes.assign(state.heroes)
	enemies.assign(state.enemies)
	hero_slots.assign(authoritative_view.hero_slots)
	enemy_slots.assign(authoritative_view.enemy_slots)
	hand.assign(state.hand)
	cost = state.cost
	turn = state.turn
	phase = state.phase
	outcome = state.outcome

func snapshot() -> Dictionary:
	var state := authoritative_view.duplicate()
	state.hero_slots = hero_slots.duplicate(true)
	state.reserved = reserved_cost() if phase == "response" else 0
	return state

func can_assign(card: int, slot_id: int, target: int, _enhanced: bool = false, _friendly: bool = false) -> String:
	if phase != "response" or card < 0 or card >= hand.size() or slot_id < 0 or slot_id >= hero_slots.size():
		return "请选择牌和行动格"
	var slot: Dictionary = hero_slots[slot_id]
	if heroes[slot.unit].hp <= 0:
		return "队员已退场"
	var key := hand[card]
	if not slot.get("flexible", false) and category_for(key) != slot.category:
		return "卡牌类别与行动格不符"
	var existing_slot_cost := 0
	var count := 0
	for other in hero_slots:
		if other.id == slot_id or not other.active:
			continue
		if other.card == card:
			existing_slot_cost = get_card_cost(other.key)
			continue
		if other.unit == slot.unit and other.get("row", 0) == slot.get("row", 0):
			count += 1
	if count >= group_action_limit(slot):
		return "这组行动格已安排满 %d 次" % group_action_limit(slot)
	var old_cost := get_card_cost(slot.key) if slot.active else 0
	var needed := reserved_cost() - old_cost - existing_slot_cost + get_card_cost(key)
	if needed > cost:
		return "可用 cost 不足，请先撤销其他行动"
	if targets_enemy(key) and (target < 0 or target >= enemy_slots.size() or enemies[enemy_slots[target].unit].hp <= 0):
		return "请选择对方存活队员的行动格"
	return ""

func assign(card: int, slot_id: int, target: int, _enhanced: bool = false, _friendly: bool = false) -> String:
	var error := can_assign(card, slot_id, target)
	if not error.is_empty():
		return error
	# Moving a card to another slot is a draft edit. The host checks the final plan.
	for slot in hero_slots:
		if slot.active and slot.card == card and slot.id != slot_id:
			cancel(slot.id)
	var slot := hero_slots[slot_id]
	slot.active = true
	slot.card = card
	slot.key = hand[card]
	slot.targeted = targets_enemy(slot.key)
	slot.target = target if slot.targeted else slot.unit
	return ""

func cancel(slot_id: int) -> void:
	if phase == "response" and slot_id >= 0 and slot_id < hero_slots.size():
		hero_slots[slot_id].merge({"active": false, "card": -1, "key": "", "targeted": false, "target": -1}, true)

func plan() -> Array:
	var actions := []
	for slot in hero_slots:
		if slot.active:
			actions.append({"slot": slot.id, "card_key": slot.key, "target": slot.target})
	return actions
