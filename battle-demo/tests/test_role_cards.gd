extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var b = Rules.new()
	b.start(42)
	check(b.cost == 30 and b.hand.size() == 16, "test cost and nine cards")
	check(b.can_assign(6, 3, 0) != "" and b.can_assign(6, 0, 0) == "", "observe owner")
	check(b.can_assign(7, 0, 0) != "" and b.can_assign(7, 3, 0) == "", "all in owner")
	check(b.can_assign(8, 2, -1) != "" and b.can_assign(8, 8, -1) == "", "cover owner")
	var events: Array[Dictionary] = []
	b._solo(events, {"key":"observe", "unit":0, "category":0, "target":0}, true)
	check(b.heroes[0].preparation == 1, "observe grants preparation")
	b._solo(events, {"key":"cover", "unit":2, "category":2}, true)
	check(b.heroes[0].shield == 6 and b.heroes[1].shield == 6 and b.heroes[2].shield == 9, "cover protects team")
	print("CARD_TEST failures=", failures)
	quit(1 if failures else 0)
