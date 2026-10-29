extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
var checks := 0
var failures := 0

class Ties extends "res://scripts/battle_rules.gd":
	func _roll(_base: int, _power: int, _coins: int, _chance: float) -> Dictionary:
		return {"value": 5, "heads": 0}

class Lose extends "res://scripts/battle_rules.gd":
	func _roll(_base: int, _power: int, _coins: int, chance: float) -> Dictionary:
		return {"value": 0 if chance > 0.5 else 99, "heads": 0}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func only_attack(b: DemoBattleRules) -> void:
	for slot in b.enemy_slots:
		slot.active = slot.id == 0
	b.enemy_slots[0].target = 0
	b.enemy_slots[0].speed = 4

func _run() -> void:
	var b := Rules.new()
	b.start()
	var before := b.snapshot()
	check(b.remaining == 180.0, "180 second response")
	check(b.assign(-1, 0, 0) != "", "invalid card rejected")
	check(b.assign(0, 0, 99) != "", "invalid target rejected")
	check(b.assign(0, 1, 0) != "", "category mismatch rejected")
	check(b.snapshot() == before, "invalid choices cannot mutate state")
	check(b.assign(0, 0, 0) == "", "first action")
	check(b.cost == 12 and b.reserved_cost() == 3, "reservation does not spend")
	check(b.assign(0, 3, 0) != "", "same card cannot be used twice")
	check(b.assign(5, 1, 0) == "", "second action by same hero")
	check(b.assign(4, 2, -1) != "", "third action rejected")
	b.cancel(1)
	check(b.reserved_cost() == 3, "cancel releases reservation")
	check(b.assign(4, 2, -1) == "", "defense after cancellation")
	check(b.assign(1, 0, 3) == "" and b.reserved_cost() == 3, "replace card and target atomically")
	b.cost = 3
	var stable := b.snapshot()
	check(b.assign(5, 4, 0) != "" and b.snapshot() == stable, "budget cannot be exceeded")
	for slot in b.snapshot().enemy_slots:
		check(not slot.has("key") and not slot.has("card"), "hidden enemy skills absent from public snapshot")
	var speed_state := b.hero_slots.duplicate(true)
	b.cancel(0)
	check(b.hero_slots[0].speed == speed_state[0].speed, "cancel cannot reroll speed")
	check(not b.tick(179.0) and b.tick(1.0), "timeout at 180 seconds")
	var events := b.lock_and_resolve()
	check(events[0].type == "reveal" and events[0].snapshot.enemy_slots[0].has("key"), "reveal only on lock")
	check(b.assign(0, 0, 0) != "" and b.lock_and_resolve().is_empty(), "lock prevents repeat spending")
	var old_cost := b.cost
	b.next_round()
	check(b.turn == 2 and b.cost == old_cost + 3 and b.remaining == 180, "next round income and timer")
	for seed_value in 40:
		var a := Rules.new()
		var c := Rules.new()
		a.start(seed_value)
		c.start(seed_value)
		check(a.snapshot() == c.snapshot(), "seed reproducibility")
		for slot in a.hero_slots:
			var unit: Dictionary = a.heroes[slot.unit]
			check(slot.speed >= unit.speed_min and slot.speed <= unit.speed_max, "hero characteristic speed bounds")
		for slot in a.enemy_slots:
			var unit: Dictionary = a.enemies[slot.unit]
			check(slot.speed >= unit.speed_min and slot.speed <= unit.speed_max, "enemy speed bounds")
		a.assign(0, 0, 0)
		c.assign(0, 0, 0)
		check(a.lock_and_resolve() == c.lock_and_resolve(), "same seed and choices same complete event stream")
	for fast in [false, true]:
		b.start()
		only_attack(b)
		b.hero_slots[3].speed = 5 if fast else 4
		b.assign(0, 3, 0)
		events = b.lock_and_resolve()
		check(events.any(func(e: Dictionary) -> bool: return e.type == "intercept") == fast, "intercept requires strictly greater speed")
	b.start()
	only_attack(b)
	b.hero_slots[0].speed = 1
	b.assign(0, 0, 0)
	events = b.lock_and_resolve()
	check(events.any(func(e: Dictionary) -> bool: return e.type == "engage"), "original target can clash even slower")
	b.start()
	only_attack(b)
	b.hero_slots[0].speed = 5
	b.hero_slots[3].speed = 7
	b.assign(0, 0, 0)
	b.assign(1, 3, 0)
	events = b.lock_and_resolve()
	var intercepts := events.filter(func(e: Dictionary) -> bool: return e.type == "intercept")
	check(intercepts.size() == 1 and intercepts[0].hero == 1, "fastest claimant wins one interception")
	var loser := Lose.new()
	loser.start()
	only_attack(loser)
	loser.assign(0, 0, 0)
	events = loser.lock_and_resolve()
	check(events.filter(func(e: Dictionary) -> bool: return e.type == "refund").size() == 1 and loser.cost == 10, "only one half refund after full lost clash")
	var tied := Ties.new()
	tied.start()
	only_attack(tied)
	tied.assign(0, 0, 0)
	events = tied.lock_and_resolve()
	check(events.filter(func(e: Dictionary) -> bool: return e.type == "clash").size() == 100, "ties reroll without random winner")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "stalemate") and not events.any(func(e: Dictionary) -> bool: return e.type == "strike"), "stall safeguard deals no damage")
	check(tied.cost == 10, "stalemate partial refund")
	b.start()
	for unit in b.heroes:
		unit.hp = 0
	b.heroes[0].hp = 1
	b.enemy_slots[0].target = 0
	for i in 5:
		b.lock_and_resolve()
		if not b.outcome.is_empty():
			break
		b.next_round()
	check(b.outcome == "defeat", "defeat terminal state")
	b.start()
	for unit in b.enemies:
		unit.hp = 1
	for slot in b.enemy_slots:
		slot.active = false
	b.assign(0, 0, 0)
	b.assign(1, 3, 3)
	b.lock_and_resolve()
	check(b.outcome == "victory", "victory terminal state")
	b.start()
	check(b.outcome == "" and b.turn == 1 and b.cost == 12, "reset")
	print("PLANNING_RULES checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
