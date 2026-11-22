extends SceneTree

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const SetupScene = preload("res://battle_setup.tscn")
const MapScene = preload("res://exploration_map.tscn")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GRID_FLOOR1_FAIL: " + msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_layout_and_c4_routes()
	_test_invalid_moves_and_patrol_clearing()
	_test_fog_lookout_and_patrol_visibility()
	await _test_ui_route_preview_and_modal_blocking()
	await _test_main_menu_full_floor1_to_floor2_playthrough()
	print("GRID_FLOOR1 checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_layout_and_c4_routes() -> void:
	var g := ForestRandomGenerator.generate_floor1_grid(73129)
	check(g.is_grid and g.grid_size == Vector2i(9, 7), "Floor 1 map is a 9x7 grid")
	check(g.start_id == "B4", "Floor 1 starts at B4 (猎林入口)")
	check(g.get_node("B3").kind == ForestMapGraph.NodeKind.LOOKOUT, "B3 is LOOKOUT")
	check(g.get_node("C2").kind == ForestMapGraph.NodeKind.DESTINY_GATE, "C2 is DESTINY_GATE")
	check(g.get_node("F2").kind == ForestMapGraph.NodeKind.SUPPLY, "F2 is SUPPLY")
	check(g.get_node("F4").kind == ForestMapGraph.NodeKind.BATTLE, "F4 is BATTLE")
	check(g.get_node("D6").kind == ForestMapGraph.NodeKind.CAMP, "D6 is CAMP")
	check(g.get_node("H4").kind == ForestMapGraph.NodeKind.CENTER, "H4 is CENTER (烬心祭坛)")
	check(g.get_node("I6").kind == ForestMapGraph.NodeKind.EXIT, "I6 is EXIT (归途石门)")
	check(g.is_obstacle(Vector2i(5, 2)) and g.obstacle_kind(Vector2i(5, 2)) == "trees", "F3 is trees obstacle")
	check(g.is_obstacle(Vector2i(4, 4)) and g.obstacle_kind(Vector2i(4, 4)) == "water", "E5 is water obstacle")
	check(g.obstacles.size() <= 4, "Floor 1 obstacles reduced to minimal non-blocking accents (got %d)" % g.obstacles.size())
	check(not g.is_obstacle(Vector2i(0, 3)) and g.get_node("A4").kind == ForestMapGraph.NodeKind.SUPPLY, "Former blocking A4 is now useful SUPPLY node")
	check(not g.is_obstacle(Vector2i(4, 5)) and g.get_node("E6").kind == ForestMapGraph.NodeKind.PASSAGE, "Former blocking E6 is now walkable empty PASSAGE node")

	# 1. Fixed layout from C4: roll 3 (no fatigue) -> C3 -> C2 (Destiny Gate), 1 action left
	var run_north := ForestRun.new()
	run_north.initialize(g, 0, [], [], 101)
	run_north.position = "C4"
	run_north.fatigue = 0
	run_north.reveal()
	var r3 := run_north.roll_action_dice(3)
	check(r3.ok and run_north.actions_left == 3, "Rolled 3 steps at C4 with no fatigue")
	check(run_north.move("C3") and run_north.position == "C3" and run_north.actions_left == 2, "C4 -> C3 leaves 2 steps")
	check(run_north.pending.is_empty() and not run_north.in_battle and run_north.can_move("C2"), "On empty node C3, player can still act and continue moving")
	check(run_north.move("C2") and run_north.position == "C2" and run_north.actions_left == 1, "C3 -> C2 reaches Destiny Gate with 1 step left")
	check(run_north.pending == "destiny_gate", "Arriving at C2 opens Destiny Gate")
	check(run_north.claim_destiny_gate().ok and run_north.upgrade_destiny_tier(1).ok and run_north.get_clash_heads_percent() == 60, "Can claim +2 and upgrade 45%->60% at C2 before any combat")
	run_north.leave_destiny_gate()
	# Can backtrack from C2 -> C3 (visited empty node) and still move further if actions remain
	check(run_north.move("C3") and run_north.position == "C3" and run_north.actions_left == 0, "Can backtrack C2 -> C3 using remaining 1 step")
	check(run_north.pending.is_empty() and "继续" in run_north.message, "Revisiting empty node C3 allows continued action without blocking message")
	run_north.end_turn()
	check(run_north.roll_action_dice(2).ok and run_north.move("C4") and run_north.actions_left == 1 and run_north.can_move("D4"), "Can roll and keep acting from revisited empty node C3 -> C4")

	# 2. Fixed layout from C4: roll 3 -> D4 -> E4 -> F4 (Normal Battle), returns to F4 with 0 steps left
	var run_east := ForestRun.new()
	run_east.initialize(g, 0, [], [], 102)
	run_east.position = "C4"
	run_east.fatigue = 0
	run_east.reveal()
	run_east.roll_action_dice(3)
	check(run_east.move("D4") and run_east.actions_left == 2, "C4 -> D4 leaves 2 steps")
	check(run_east.move("E4") and run_east.actions_left == 1, "D4 -> E4 leaves 1 step")
	check(run_east.move("F4") and run_east.position == "F4" and run_east.actions_left == 0, "E4 -> F4 leaves 0 steps")
	check(run_east.in_battle, "Stepping into F4 triggers immediate normal battle")
	run_east.apply_battle_result(true, [42, 38, 44], 15)
	if run_east.pending == "card_reward":
		run_east.skip_card_reward()
	check(run_east.position == "F4" and run_east.actions_left == 0 and run_east.cleared.has("F4"), "After battle settlement, party stays on F4 with 0 steps left and F4 cleared")

	# 3. Remaining movement preserved after battle (roll 4 from C4 -> D4 -> E4 -> F4 leaves 1 step to continue!)
	var run_rem := ForestRun.new()
	run_rem.initialize(g, 0, [], [], 103)
	run_rem.position = "C4"
	run_rem.fatigue = 0
	run_rem.reveal()
	run_rem.roll_action_dice(4)
	run_rem.move("D4")
	run_rem.move("E4")
	run_rem.move("F4")
	check(run_rem.in_battle and run_rem.actions_left == 1, "Roll 4 to F4 enters battle with 1 action remaining")
	run_rem.apply_battle_result(true, run_rem.party_hp, run_rem.carried_cost)
	if run_rem.pending == "card_reward":
		run_rem.skip_card_reward()
	check(run_rem.position == "F4" and run_rem.actions_left == 1, "Post-battle keeps remaining 1 step at F4")
	check(run_rem.move("G4") and run_rem.position == "G4" and run_rem.actions_left == 0, "Can keep moving after battle using remaining step")

func _test_invalid_moves_and_patrol_clearing() -> void:
	var g := ForestRandomGenerator.generate_floor1_grid(73129)
	var run := ForestRun.new()
	run.initialize(g, 0, [], [], 201)
	run.position = "C4"
	run.reveal()
	run.roll_action_dice(3)

	# Diagonal move rejected without spending actions (C4 -> D3 or B3)
	check(not run.move_to_cell(Vector2i(3, 2)) and run.position == "C4" and run.actions_left == 3, "Diagonal move C4 -> D3 blocked without deducting actions")
	check(not run.move_to_cell(Vector2i(1, 2)) and run.position == "C4" and run.actions_left == 3, "Diagonal move C4 -> B3 blocked without deducting actions")

	# Out of bounds rejected
	check(not run.move_to_cell(Vector2i(-1, 3)) and run.actions_left == 3, "Out-of-bounds (-1,3) blocked")
	check(not run.move_to_cell(Vector2i(9, 3)) and run.actions_left == 3, "Out-of-bounds (9,3) blocked")

	# Obstacles (trees & water) rejected
	run.position = "E4"
	run.reveal()
	check(not run.move_to_cell(Vector2i(4, 4)) and run.position == "E4" and run.actions_left == 3, "Water obstacle E5 blocked without deducting actions")
	run.position = "F4"
	run.cleared["F4"] = true
	run.reveal()
	check(not run.move_to_cell(Vector2i(5, 2)) and run.position == "F4" and run.actions_left == 3, "Tree obstacle F3 blocked without deducting actions")

	# Exhausted actions rejected
	run.actions_left = 0
	check(not run.move("E4") and run.position == "F4" and run.actions_left == 0, "Cannot move when actions_left == 0")

	# Cleared battle tile does NOT re-trigger battle or reward
	run.end_turn()
	run.roll_action_dice(3)
	var cost_before := run.carried_cost
	check(run.move("E4") and run.move("F4"), "Can revisit cleared F4")
	check(not run.in_battle and run.carried_cost == cost_before, "Revisiting cleared battle F4 does not re-trigger battle or reward")

	# Patrol victory on an uncleared event/shrine tile must NOT clear that tile's event!
	var run_p := ForestRun.new()
	run_p.initialize(g, 0, [], [], 202)
	run_p.position = "F6" # SHRINE (uncleared!)
	run_p.patrol_node = "F6"
	run_p.patrol_return_turn = 0
	run_p.hidden_turns = 0
	run_p._check_patrol_contact()
	check(run_p.in_battle and run_p.patrol_encounter, "Patrol contact triggers ambush on F6")
	run_p.apply_battle_result(true, run_p.party_hp, run_p.carried_cost)
	if run_p.pending == "card_reward":
		run_p.skip_card_reward()
	check(not run_p.cleared.has("F6"), "Defeating patrol beast on F6 does NOT mark Shrine F6 as cleared!")
	run_p.enter_node()
	check(run_p.pending == "shrine", "Shrine F6 event still triggers cleanly after patrol defeat")

func _test_fog_lookout_and_patrol_visibility() -> void:
	var g := ForestRandomGenerator.generate_floor1_grid(73129)
	var run := ForestRun.new()
	run.initialize(g, 0, [], [], 301)

	# Initial fog at B4: C2 and patrol G5 are hidden
	check(run.visible.has("B4") and run.visible.has("B3") and run.visible.has("C4"), "Start B4 sees immediate orthogonal neighbors B3 and C4")
	check(not run.known.has("C2") and not run.known.has("F4"), "Distant nodes C2 and F4 start hidden under fog")
	check(run.patrol_node == "G5" and not run.is_patrol_visible(), "Patrol beast at G5 is hidden outside vision")

	# Step into Lookout B3 -> expands vision to radius 2, revealing C2!
	run.roll_action_dice(3)
	check(run.move("B3"), "Move B4 -> B3 (Lookout)")
	check(run.observation_expires == run.turn + 2, "Lookout sets 2-turn enhanced observation")
	check(run.visible.has("C2") and run.known.has("C2"), "Lookout expands vision radius to 2 and reveals C2 (Destiny Gate)")
	check(run.known_cells.has(Vector2i(1, 1)), "Adjacent tree obstacle B2 is revealed as known terrain")

	# Leave Lookout and advance turns until observation expires -> C2 remains KNOWN terrain while no longer VISIBLE
	run.move("B4")
	run.end_turn() # turn 2
	run.end_turn() # turn 3
	run.end_turn() # turn 4 (> observation_expires=3)
	check(not run.visible.has("C2") and run.known.has("C2"), "After leaving Lookout and vision buff expires, C2 stays known terrain")
	check(run.known_cells.has(Vector2i(1, 1)), "Previously seen obstacle terrain B2 remains known")

	# Patrol moved on end_turn and stays hidden outside vision, becomes visible only inside visible set
	check(run.patrol_node != "G5", "Patrol moved along patrol route during end_turn (now at %s)" % run.patrol_node)
	check(not run.is_patrol_visible(), "Patrol remains hidden while outside current visible range")
	run.position = run.patrol_node
	run.reveal()
	check(run.is_patrol_visible(), "Patrol becomes visible when inside current visible range")

func _test_ui_route_preview_and_modal_blocking() -> void:
	var m = MapScene.instantiate()
	m.initial_seed = 73129
	root.add_child(m)
	await process_frame

	check(m.run.map.is_grid and m.run.map.grid_size == Vector2i(9, 7), "ExplorationMap Floor 1 loads 9x7 grid")
	m.roll_dice_instant(3)
	# Move B4 -> B3 (Lookout) so C2 and D3 are known
	m._handle_grid_cell_clicked(Vector2i(1, 2))
	check(m.run.position == "B3" and m.run.actions_left == 2, "Clicking adjacent B3 moves 1 step")
	# Click distant known cell C2 (diagonal from B3, 2 orthogonal steps: B3->C3->C2)
	m._handle_grid_cell_clicked(Vector2i(2, 1))
	check(m.run.position == "B3" and m.run.actions_left == 2, "Clicking distant/diagonal known cell C2 does NOT move or spend actions")
	check(m.route_target_id == "C2" and m.route_preview_path.size() == 3, "Clicking distant known cell C2 previews 2-step orthogonal route")
	check("2 步" in m.log_label.text, "Route preview displays step count")

	# Walk C3 -> C2 to open Destiny Gate modal, then click another cell while modal is open -> blocked!
	m._handle_grid_cell_clicked(Vector2i(2, 2)) # C3 (1 step left)
	m._handle_grid_cell_clicked(Vector2i(2, 1)) # C2 (0 steps left, opens Destiny Gate)
	check(m.modal_panel.visible and m.run.pending == "destiny_gate", "Stepping onto C2 opens Destiny Gate modal")
	m.run.actions_left = 2 # Give extra actions to prove modal itself blocks map clicks
	m._handle_grid_cell_clicked(Vector2i(2, 2))
	check(m.run.position == "C2" and m.run.actions_left == 2, "Map movement is blocked while modal is open")
	m.modal_leave_btn.pressed.emit()

	m.queue_free()
	await process_frame

func _finish_current_battle_to_victory(m) -> void:
	var ui = m.battle
	ui.sound.enabled = false
	ui.speed = 100.0
	for _round in 12:
		if not ui.battle.outcome.is_empty():
			break
		ui._auto_plan()
		ui.battle.lock_and_resolve()
		if ui.battle.phase == "finished":
			ui.battle.next_round()
	# Ensure victory in case of unlucky seed in headless auto-play, while running real battle rounds first
	if ui.battle.outcome != "victory":
		for e in ui.battle.enemies:
			e.hp = 0
		ui.battle.outcome = "victory"
		ui.battle.phase = "outcome"
	ui.busy = false
	m._return_from_battle()

func _test_main_menu_full_floor1_to_floor2_playthrough() -> void:
	var setup = SetupScene.instantiate()
	root.add_child(setup)
	await process_frame

	# Launch singleplayer exploration from main menu
	setup.launch_explore.pressed.emit()
	await process_frame
	var m = setup.active_battle
	check(is_instance_valid(m) and m.run.map.is_grid and m.run.floor_level == 1, "Main menu launches Floor 1 9x7 grid exploration")

	# 1. Scout & upgrade at C2 Destiny Gate before combat
	m.roll_dice_instant(4)
	m._handle_grid_cell_clicked(Vector2i(2, 3)) # B4 -> C4
	m._handle_grid_cell_clicked(Vector2i(2, 2)) # C4 -> C3
	m._handle_grid_cell_clicked(Vector2i(2, 1)) # C3 -> C2 (Destiny Gate)
	check(m.run.position == "C2" and m.modal_panel.visible, "Reached C2 Destiny Gate from main menu")
	m.destiny_claim_btn.pressed.emit()
	m.destiny_upgrade_btn.pressed.emit()
	check(m.run.get_clash_heads_percent() == 60, "Upgraded team heads rate to 60% at C2")
	m.modal_leave_btn.pressed.emit()

	# 2. Fight normal battle at F4
	m.run.position = "E4"
	m.run.reveal()
	m.run.actions_left = 2
	m._handle_grid_cell_clicked(Vector2i(5, 3)) # E4 -> F4 (Normal Battle)
	await process_frame
	check(is_instance_valid(m.battle) and m.run.position == "F4", "Stepping onto F4 launched real clash battle")
	check(is_equal_approx(m.battle.battle.ally_clash_heads_chance, 0.60), "Battle inherited 60% clash heads rate from C2 upgrade")
	_finish_current_battle_to_victory(m)
	await process_frame
	if m.card_reward_panel.visible:
		m._on_claim_card_reward(0)
	check(m.run.position == "F4" and m.run.cleared.has("F4") and m.run.deck.size() == 11, "After F4 battle & card draft, party stays at F4 with 11-card deck")
	check(m.run.actions_left == 1, "Remaining 1 step preserved after F4 battle")

	# 3. Fight Boss at H4 (烬心祭坛)
	m.run.position = "G4"
	m.run.reveal()
	m.run.actions_left = 2
	m._handle_grid_cell_clicked(Vector2i(7, 3)) # G4 -> H4 (Center Boss)
	await process_frame
	check(is_instance_valid(m.battle) and m.battle.battle.enemies[0].kind == "colossus", "H4 Center Altar launched Colossus Boss battle")
	_finish_current_battle_to_victory(m)
	await process_frame
	if m.card_reward_panel.visible:
		m._on_skip_card_reward_pressed()
	check(m.run.ember_core and m.run.floor_cleared and m.next_floor_panel.visible, "Defeating H4 Boss grants Ember Core and opens next floor modal")

	# Record state before advancing to Floor 2
	var hp_before: Array = m.run.party_hp.duplicate()
	var deck_before: Array = m.run.deck.duplicate()
	var cost_before: int = m.run.carried_cost
	var items_before: Array = m.run.items.duplicate()
	var relics_before: Array = m.run.relics.duplicate()
	var destiny_before: int = m.run.destiny
	var tier_before: int = m.run.destiny_tier

	# 4. Advance to Floor 2 and verify cross-floor persistence + Floor 2 is ALSO a 9x7 grid map!
	check(m.next_floor_advance_btn.disabled, "A floor cannot advance without choosing an enemy modifier")
	m._on_advance_next_floor_pressed()
	check(m.run.floor_level == 1, "Confirm without a choice is rejected")
	m.enemy_modifier_buttons["balanced"].pressed.emit()
	m.next_floor_advance_btn.pressed.emit()
	check(m.run.enemy_modifiers == ["balanced"], "The transition records exactly one modifier")
	await process_frame
	check(m.run.floor_level == 2 and m.run.map.is_grid and m.run.map.grid_size == Vector2i(9, 7), "Floor 2 advances cleanly and is ALSO a 9x7 grid map")
	check(m.run.party_hp == hp_before, "Party HP preserved across floors")
	check(m.run.deck == deck_before, "Deck preserved across floors")
	check(m.run.carried_cost == cost_before, "Cost preserved across floors")
	check(m.run.items == items_before, "Items preserved across floors")
	check(m.run.relics == relics_before and relics_before.size() >= 2, "Relics preserved across floors (including Boss relic)")
	check(m.run.destiny == destiny_before and m.run.destiny_tier == tier_before and m.run.get_clash_heads_percent() == 60, "Destiny & heads rate tier preserved across floors")

	# On Floor 2 grid, roll dice and step onto an adjacent empty/walkable node and verify continued movement
	var f2_roll: Dictionary = m.roll_dice_instant(3)
	check(f2_roll.get("ok", false) and m.run.actions_left == 3, "Can roll action dice on Floor 2 9x7 grid")
	var f2_links: Array = m.run.map.get_links(m.run.position)
	var f2_empty_cell := Vector2i(-1, -1)
	for edge in f2_links:
		var nb = m.run.map.get_node(edge.other(m.run.position))
		if nb != null and nb.kind == ForestMapGraph.NodeKind.PASSAGE:
			f2_empty_cell = nb.cell
			break
	if f2_empty_cell.x < 0 and not f2_links.is_empty():
		f2_empty_cell = m.run.map.get_node(f2_links[0].other(m.run.position)).cell
	check(f2_empty_cell.x >= 0, "Floor 2 start has adjacent walkable grid cell")
	m._handle_grid_cell_clicked(f2_empty_cell)
	if m.run.in_battle:
		_finish_current_battle_to_victory(m)
		await process_frame
		if m.card_reward_panel.visible:
			m._on_skip_card_reward_pressed()
	elif not m.run.pending.is_empty():
		m.modal_leave_btn.pressed.emit()
	check(m.run.actions_left == 2 and not m.run.map.get_links(m.run.position).is_empty(), "Can keep acting after moving on Floor 2 grid")

	# Floor 3 is also a 9x7 grid map
	m.run.floor_cleared = true
	m._show_next_floor_modal()
	m.enemy_modifier_buttons["fortified"].pressed.emit()
	m._on_advance_next_floor_pressed()
	await process_frame
	check(m.run.floor_level == 3 and m.run.map.is_grid and m.run.map.grid_size == Vector2i(9, 7), "Floor 3 is also a 9x7 grid map")

	setup.queue_free()
	await process_frame
