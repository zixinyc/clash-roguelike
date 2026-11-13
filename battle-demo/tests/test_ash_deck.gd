extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
class Wins extends "res://scripts/battle_rules.gd":
	func _roll(base: int, _power: int, _coins: int, chance: float) -> Dictionary:
		return {"value": base + (100 if chance > 0.5 else 0), "heads": 0}
class Loses extends "res://scripts/battle_rules.gd":
	func _roll(base: int, _power: int, _coins: int, chance: float) -> Dictionary:
		return {"value": base + (100 if chance < 0.6 else 0), "heads": 0}
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var b = Wins.new()
	b.start(42)
	var events: Array[Dictionary] = []
	for i in [6, 9, 10, 11]:
		check(b.can_assign(i, 3, 0) != "" and b.can_assign(i, 0, 0) == "", "exclusive card")
	b.heroes[0].preparation = 1
	b._clash(events, {"key":"exploit", "unit":0}, {"key":"ember", "unit":0, "target":0})
	check(events.any(func(e): return e.type == "ability" and "消耗准备" in e.message), "exploit consumes prep")
	check(events.any(func(e): return e.type == "clash" and e.left == 110), "exploit adds 4 power")
	b.start(42)
	events.clear()
	b._clash(events, {"key":"follow", "unit":0}, {"key":"ember", "unit":0, "target":0})
	check(events.any(func(e): return e.type == "ability" and "追加 4" in e.message), "follow wins and triggers")
	var loser = Loses.new()
	loser.start(42)
	events.clear()
	loser._clash(events, {"key":"follow", "unit":0}, {"key":"ember", "unit":0, "target":0})
	check(not events.any(func(e): return e.type == "ability" and "追加 4" in e.message), "follow fails without pursuit")
	print("ASH_DECK failures=", failures)
	quit(1 if failures else 0)
