extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
var checks := 0

class AlwaysTie extends "res://scripts/battle_rules.gd":
	func _roll(_base: int, _power: int, _coins: int, _chance: float) -> Dictionary:
		return {"value": 5, "heads": 0}

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAILED: " + message)
		quit(1)
		assert(condition, message)

func _run() -> void:
	_test_invalid_actions()
	_test_refund_once()
	_test_guard_and_turn()
	_test_rewards_and_unopposed()
	_test_determinism()
	_test_tie_limit()
	_test_outcomes()
	print("RULE_TESTS_PASSED checks=", checks)
	quit(0)

func _test_invalid_actions() -> void:
	var battle := Rules.new()
	battle.start()
	var before := battle.snapshot()
	_check(battle.play(-1, 0, 0).is_empty(), "invalid card rejected")
	_check(battle.play(0, -1, 0).is_empty(), "invalid actor rejected")
	_check(battle.play(0, 0, 99).is_empty(), "invalid target rejected")
	_check(battle.snapshot() == before, "invalid actions do not mutate state")
	battle.cost = 0
	_check(battle.play(0, 0, 0).is_empty(), "insufficient wallet rejected")
	battle.cost = 9
	battle.plays = 3
	_check(battle.play(0, 0, 0).is_empty(), "turn action cap enforced")
	battle.plays = 0
	battle.heroes[0].acted = true
	_check(battle.play(0, 0, 0).is_empty(), "each actor only acts once in prototype")

func _test_refund_once() -> void:
	var battle := Rules.new()
	battle.start(1)
	battle.enemies[0].base = 100
	battle.enemies[0].power = 0
	battle.enemies[0].coins = 1
	var events := battle.play(0, 0, 0)
	var refunds := events.filter(func(e: Dictionary) -> bool: return e.type == "refund")
	_check(refunds.size() == 1, "one refund for a lost complete clash")
	_check(refunds[0].amount == 1, "paid three refunds floor half")
	_check(battle.cost == 7, "wallet deducts three and refunds one")
	_check(battle.plays == 1 and battle.heroes[0].acted, "refund does not restore action")
	_check(events.filter(func(e: Dictionary) -> bool: return e.type == "clash").size() == 2, "one coin broken per losing clash")
	_check(battle.heroes[0].hp == 0, "lethal retaliation clamps hp at zero")
	_check(events[0].snapshot.heroes[0].hp == 36, "event snapshots are independent of final state")

func _test_guard_and_turn() -> void:
	var battle := Rules.new()
	battle.start(23)
	var events := battle.play(4, 0, -1)
	_check(events.size() == 2 and battle.heroes[0].shield == 9, "guard needs no enemy target")
	_check(battle.cost == 8, "guard pays from shared wallet")
	var next := battle.end_turn()
	_check(next.any(func(e: Dictionary) -> bool: return e.type == "strike" and e.blocked > 0), "guard absorbs enemy damage")
	_check(battle.turn == 2 and battle.cost == 11, "next turn adds income without resetting wallet")
	_check(battle.hand.size() == 5 and battle.plays == 0, "next turn refreshes hand and actions")
	_check(battle.heroes.all(func(u: Dictionary) -> bool: return not u.acted and u.shield == 0), "guard expires and actors reset")
	_check(battle.enemies.all(func(u: Dictionary) -> bool: return not u.spent), "enemy intents refresh")

func _test_rewards_and_unopposed() -> void:
	var battle := Rules.new()
	battle.start(3)
	for enemy in battle.enemies:
		enemy.base = 0
		enemy.power = 0
		enemy.hp = 500
		enemy.max_hp = 500
	var first := battle.play(0, 0, 0)
	var second := battle.play(0, 1, 1)
	_check(first.filter(func(e: Dictionary) -> bool: return e.type == "reward").size() == 1, "first clash win gets reward")
	_check(second.filter(func(e: Dictionary) -> bool: return e.type == "reward").is_empty(), "second win gets no repeated reward")
	var third := battle.play(0, 2, 0)
	_check(third.any(func(e: Dictionary) -> bool: return e.type == "unopposed"), "spent enemy cannot clash twice")
	_check(not third.any(func(e: Dictionary) -> bool: return e.type == "clash" or e.type == "reward"), "unopposed hits grant no clash reward")
	_check(battle.plays == 3, "three successful actions consume turn allowance")

func _test_determinism() -> void:
	for value in range(1, 61):
		var first := Rules.new()
		var second := Rules.new()
		first.start(value)
		second.start(value)
		_check(first.play(0, 0, 0) == second.play(0, 0, 0), "same seed produces same complete clash log")
		_check(first.end_turn() == second.end_turn(), "same seed produces same enemy turn and draw")
		_check(first.snapshot() == second.snapshot(), "identical final state independent of visual playback")

func _test_outcomes() -> void:
	var defeated := Rules.new()
	defeated.start(10)
	for hero in defeated.heroes:
		hero.hp = 1
	for enemy in defeated.enemies:
		enemy.base = 100
	defeated.end_turn()
	if defeated.outcome.is_empty():
		defeated.end_turn()
	_check(defeated.outcome == "defeat", "all heroes dead ends battle")
	_check(defeated.end_turn().is_empty(), "ended battle cannot advance")
	var victorious := Rules.new()
	victorious.start(3)
	victorious.enemies[0].hp = 1
	victorious.enemies[0].spent = true
	victorious.enemies[1].hp = 0
	var events := victorious.play(0, 0, 0)
	_check(victorious.outcome == "victory", "last enemy death wins battle")
	_check(events[-1].type == "outcome", "victory event follows strike")
	_check(victorious.play(0, 1, 0).is_empty(), "no action after victory")
	victorious.start()
	_check(victorious.outcome.is_empty() and victorious.cost == 9 and victorious.turn == 1, "restart clears outcome and restores initial state")

func _test_tie_limit() -> void:
	var battle := AlwaysTie.new()
	battle.start(5)
	var events := battle.play(0, 0, 0)
	var clashes := events.filter(func(e: Dictionary) -> bool: return e.type == "clash")
	_check(clashes.size() <= 9, "perpetual ties terminate within coin destruction bound")
	_check(clashes.any(func(e: Dictionary) -> bool: return e.decider), "tie limit invokes an explicit decider event")
	_check(clashes[-1].hero_remaining == 0 or clashes[-1].enemy_remaining == 0, "tiebreak reaches a definite winner")
