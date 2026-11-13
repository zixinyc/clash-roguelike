extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	var b = Rules.new()
	b.start(42)
	var ev: Array[Dictionary] = []
	b._clash(ev, {"key":"cleave", "unit":0}, {"key":"needle", "unit":0, "target":0})
	check(b.heroes[0].preparation == 1, "win grants preparation")
	ev.clear()
	b._clash(ev, {"key":"exploit", "unit":0}, {"key":"cleave", "unit":0, "target":0})
	check(ev.any(func(e): return e.type == "ability" and "消耗准备" in e.message), "next clash consumes preparation")
	b = Rules.new()
	b.start(42)
	b.heroes[0].hp = 0
	ev.clear()
	b._solo(ev, {"key":"guard", "unit":2, "category":2}, true)
	check(b.heroes[2].shield == 9 and b.heroes[1].shield == 4 and b.heroes[0].shield == 0, "guard aids living allies")
	b = Rules.new()
	b.start(42)
	ev.clear()
	b._clash(ev, {"key":"cleave", "unit":1}, {"key":"nova", "unit":0, "target":1})
	check(ev.any(func(e): return e.type == "ability" and "威力 +2" in e.message), "expensive clash grants power")
	var found_loss := false
	for seed_value in range(100):
		b = Rules.new()
		b.start(seed_value)
		ev.clear()
		b._clash(ev, {"key":"cleave", "unit":1}, {"key":"nova", "unit":0, "target":1})
		if ev.any(func(e): return e.type == "ability" and "损失 2 生命" in e.message):
			found_loss = true
			break
	check(found_loss, "expensive clash failure costs hp")
	print("ROLE_TEST failures=", failures)
	quit(1 if failures else 0)
