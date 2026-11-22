extends SceneTree

const ForestRun = preload("res://scripts/forest_run.gd")
const Generator = preload("res://scripts/forest_random_generator.gd")
const Graph = preload("res://scripts/forest_map_graph.gd")
const Rules = preload("res://scripts/battle_rules.gd")
const MODIFIERS := ["fortified", "balanced", "ferocious", "fortified"]

var checks := 0
var failures := 0
var returned_to_menu := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map_view := (load("res://exploration_map.tscn") as PackedScene).instantiate()
	root.add_child(map_view)
	var run: ForestRun = map_view.run
	_check(run.get_enemy_modifier_config() == {"enemy_health_percent": 100, "enemy_damage_percent": 100}, "Floor 1 starts without enemy bonuses")
	_check(not run.advance_to_next_floor(Generator.generate_grid(10, 2), 10, "fortified"), "Uncleared floor cannot advance")
	for floor in range(1, ForestRun.MAX_FLOOR):
		_enter_boss(run)
		_check(run.in_battle and run.is_boss_battle(), "Floor %d actually enters a boss battle" % floor)
		run.apply_battle_result(true, run.party_hp, run.carried_cost)
		_check(run.floor_cleared and not run.finished, "Floor %d is clear without ending the expedition" % floor)
		var next := Generator.generate_grid(20 + floor, floor + 1)
		if run.pending == "card_reward":
			_check(not run.advance_to_next_floor(next, 20 + floor, MODIFIERS[floor - 1]), "Pending reward blocks advancement")
			run.skip_card_reward()
		_check(not run.advance_to_next_floor(next, 20 + floor), "No debuff choice means no advance")
		_check(not run.advance_to_next_floor(next, 20 + floor, "invalid"), "Unknown modifier is rejected")
		_check(run.advance_to_next_floor(next, 20 + floor, MODIFIERS[floor - 1]), "Selected modifier unlocks exactly one floor")
		_check(run.floor_level == floor + 1 and run.enemy_modifiers.size() == floor, "One modifier recorded for each transition")
	_check(run.get_enemy_modifier_config() == {"enemy_health_percent": 158, "enemy_damage_percent": 136}, "Four choices stack additively on base stats")
	_test_battle_scaling(run.get_enemy_modifier_config())

	run.current_encounter = 0
	run.in_battle = true
	run.apply_battle_result(true, run.party_hp, run.carried_cost)
	_check(not run.finished and not run.won_expedition, "A floor-five ordinary victory continues the run")
	if run.pending == "card_reward":
		run.skip_card_reward()

	run.current_encounter = 3
	run.in_battle = true
	run.patrol_encounter = true
	run.apply_battle_result(true, run.party_hp, run.carried_cost)
	_check(not run.finished and not run.won_expedition, "A floor-five patrol victory continues the run")
	if run.pending == "card_reward":
		run.skip_card_reward()

	var losing := ForestRun.new()
	losing.initialize(Generator.generate_grid(51, 5))
	losing.floor_level = 5
	_enter_boss(losing)
	losing.apply_battle_result(false, [0, 0, 0], 0)
	_check(losing.finished and not losing.won_expedition, "Floor-five boss defeat cannot show the victory screen")

	_enter_boss(run)
	map_view._start_battle(run.current_encounter)
	var battle_view: Control = map_view.battle
	battle_view.sound.enabled = false
	battle_view.speed = 4.0
	_check(battle_view.battle.enemies[0].max_hp == 332 and battle_view.battle.enemy_damage_percent == 136, "Real floor-five boss receives run modifiers")
	# Bring the boss to its final hit to exercise the normal lock, resolve and animation callback.
	battle_view.battle.enemies[0].hp = 1
	for slot in battle_view.battle.enemy_slots:
		slot.active = false
	_check(_assign_last_hit(battle_view.battle), "Final hit is arranged through the real rule validator")
	await battle_view._resolve()
	await process_frame
	await process_frame
	_check(run.won_expedition and run.finished and run.floor_level == 5, "Real battle controller ends the expedition after victory")
	_check(not is_instance_valid(map_view.battle) and is_instance_valid(map_view.victory_view), "Victory view opens automatically after playback")
	_check(run.pending.is_empty() and not map_view.next_floor_panel.visible and not map_view.card_reward_panel.visible, "Final boss skips all progression modals")
	_check(not run.advance_to_next_floor(Generator.generate_grid(52, 6), 52, "fortified"), "Floor six cannot be entered")
	if is_instance_valid(map_view.victory_view):
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/expedition-victory.png")
		map_view.exploration_finished.connect(func() -> void: returned_to_menu = true)
		map_view.victory_view.find_child("ReturnToMenu", true, false).pressed.emit()
		_check(returned_to_menu, "Victory button requests the normal menu return")
	run.initialize(Generator.generate_floor1_grid(53))
	_check(run.floor_level == 1 and run.enemy_modifiers.is_empty() and not run.finished and not run.won_expedition, "Restart resets expedition state")
	map_view.queue_free()
	await process_frame
	print("EXPEDITION_VICTORY checks=%d failures=%d" % [checks, failures])
	quit(int(failures > 0))

func _enter_boss(run: ForestRun) -> void:
	for node in run.map.nodes.values():
		if node.kind == Graph.NodeKind.CENTER:
			run.position = node.id
			run.enter_node()
			return
	run.position = run.map.exit_id
	run.enter_node()

func _test_battle_scaling(config: Dictionary) -> void:
	for encounter in [0, 1, 3, 4, 5]:
		var plain := Rules.new()
		var scaled := Rules.new()
		plain.start(1, encounter)
		scaled.start(1, encounter, false, false, [], null, false, [], [], config)
		for idx in plain.enemies.size():
			var expected := ceili(float(plain.enemies[idx].max_hp * 158) / 100.0)
			_check(scaled.enemies[idx].hp == expected and scaled.enemies[idx].max_hp == expected, "Encounter %d boosts each enemy's starting and max HP" % encounter)
		scaled.heroes[0].shield = 3
		var events: Array[Dictionary] = []
		scaled._deal_hit(events, false, 0, 0, 10, 1, 1)
		_check(events[0].damage == 11 and events[0].blocked == 3, "Enemy hit scales before the shield absorbs damage")
		scaled._deal_hit(events, true, 0, 0, 10, 1, 1)
		_check(events.back().damage == 10, "Ally hits do not inherit enemy damage modifiers")
		scaled.start(1, encounter)
		_check(scaled.enemies[0].max_hp == plain.enemies[0].max_hp and scaled.enemy_damage_percent == 100, "Standalone battle resets difficulty to defaults")

func _assign_last_hit(rules: Rules) -> bool:
	for card in rules.hand.size():
		if not Rules.targets_enemy(rules.hand[card]):
			continue
		for slot in rules.hero_slots:
			if rules.assign(card, slot.id, 0).is_empty():
				return true
	return false

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
