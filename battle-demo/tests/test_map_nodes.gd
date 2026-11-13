extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var m = MapScene.instantiate()
	root.add_child(m)
	await process_frame
	m.position_now = Vector2i(4, 1)
	m.carried_hp = [45, 0, 20]
	m._open_node("camp")
	m._choose(0)
	check(m.carried_hp == [48, 0, 30] and m.cleared.has(Vector2i(4,1)), "camp heal capped and no revive")
	var old_cost: int = m.carried_cost
	m._choose(1)
	check(m.carried_cost == old_cost, "cannot claim twice")
	m.position_now = Vector2i(3,2)
	m.carried_cost = 5
	m._open_node("shop")
	m._choose(0)
	check(m.carried_cost == 5 and not m.cleared.has(m.position_now), "shop funds check")
	m._leave_node()
	check(m.pending.is_empty(), "leave shop")
	m.carried_cost = 10
	m._open_node("shop")
	m._choose(0)
	check(m.carried_cost == 4 and m.carried_hp[1] == 0, "shop once no revive")
	m.position_now = Vector2i(1,2)
	m.carried_hp = [2, 0, 9]
	m._open_node("event")
	m._choose(1)
	check(m.carried_cost == 16 and m.carried_hp == [1,0,5], "event health floor and reward")
	m._restart()
	check(m.carried_cost == 30 and m.carried_hp == [48,42,46] and m.cleared.is_empty(), "restart resets")
	m.position_now = Vector2i(4,2)
	m._start_battle(1)
	await process_frame
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	check(m.carried_cost == 38, "elite victory gives 8")
	m.position_now = Vector2i(2,1)
	m._start_battle(0)
	await process_frame
	m.battle.battle.outcome = "defeat"
	m._return_from_battle()
	check(m.carried_cost == 38 and m.finished and not m.cleared.has(Vector2i(2,1)), "defeat grants no reward")
	print("NODE_TEST failures=", failures)
	quit(1 if failures else 0)
