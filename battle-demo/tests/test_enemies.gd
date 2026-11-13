extends SceneTree
const Rules = preload("res://scripts/battle_rules.gd")
var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var b = Rules.new()
	var ev: Array[Dictionary] = []
	b.start(42, 0)
	check(b.enemies[0].kind == "scout" and b.enemies[1].kind == "warden", "first enemy pair")
	b.heroes[0].preparation = 1
	b._attack(ev, false, 0, 0, 5, 0, 1, 0.5)
	check(b.heroes[0].preparation == 0, "scout removes preparation on damage")
	ev.clear()
	b._solo(ev, {"key":"guard", "unit":1, "category":2}, false)
	check(b.enemies[1].shield == 14, "warden guard")
	b.start(42, 1)
	check(b.enemies[0].kind == "priest" and b.enemies[1].kind == "elite", "second enemy pair")
	ev.clear()
	b._solo(ev, {"key":"guard", "unit":0, "category":2}, false)
	check(b.enemies[1].shield == 6, "priest shields living ally")
	b.enemies[1].hp = 0
	b.enemies[1].shield = 0
	b._solo(ev, {"key":"guard", "unit":0, "category":2}, false)
	check(b.enemies[1].shield == 0, "priest does not shield dead ally")
	print("ENEMY_TEST failures=", failures)
	quit(1 if failures else 0)
