extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var map = MapScene.instantiate()
	root.add_child(map)
	await process_frame
	assert(map.position_now == Vector2i(0,1))
	map._move(Vector2i(3,1))
	assert(map.position_now == Vector2i(0,1))
	map._move(Vector2i(1,1))
	assert(map.visited.has(Vector2i(2,1)))
	map._move(Vector2i(2,1))
	await process_frame
	assert(is_instance_valid(map.battle))
	map.battle.battle.cost = 22
	map.battle.battle.heroes[0].hp = 31
	map.battle.battle.outcome = "victory"
	map._return_from_battle()
	assert(map.carried_cost == 26 and map.carried_hp[0] == 31 and map.cleared.has(Vector2i(2,1)))
	map._move(Vector2i(1,1))
	map._move(Vector2i(2,1))
	assert(not is_instance_valid(map.battle))
	map._move(Vector2i(3,1))
	map._move(Vector2i(4,1))
	map._choose(1)
	map._move(Vector2i(5,1))
	assert(map.finished)
	print("MAP_TEST passed")
	quit()
