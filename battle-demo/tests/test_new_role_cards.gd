extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
class Wins extends "res://scripts/battle_rules.gd":
	func _roll(base: int, _power: int, _coins: int, chance: float) -> Dictionary:
		return {"value": base + (100 if chance > 0.5 else 0), "heads": 0}
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var b = Wins.new()
	b.start()
	for i in [12, 13]:
		check(b.can_assign(i, 0, 0) != "", "long blade exclusive")
	for i in [14, 15]:
		check(b.can_assign(i, 0, 0) != "", "support exclusive")
	var events: Array[Dictionary] = []
	b.heroes[0].hp = 0
	b._solo(events, {"key":"light_guard", "unit":2, "category":2}, true)
	check(b.heroes[1].shield == 8 and b.heroes[0].shield == 0, "light guard living allies")
	b.start()
	events.clear()
	b._clash(events, {"key":"support_strike", "unit":2}, {"key":"ember", "unit":0, "target":2})
	check(b.heroes[0].shield == 4 and b.heroes[1].shield == 4, "support strike grants shields")
	print("NEW_CARDS failures=", failures)
	quit(1 if failures else 0)
