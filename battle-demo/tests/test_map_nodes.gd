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
	check(m.carried_cost == ForestRun.START_COST and m.carried_cost == 18 and m.carried_hp == [48,42,46] and m.cleared.is_empty(), "restart resets")
	check(not m.roll_dice_button.disabled and not m.run.dice_rolled, "roll dice button enabled at start of turn")
	var rolled: Dictionary = m.roll_dice_instant(3)
	check(rolled.get("ok", false) and m.run.actions_left == 3 and m.roll_dice_button.disabled, "rolling dice enables steps and disables button for current turn")
	m.position_now = Vector2i(4,2)
	m._start_battle(1)
	await process_frame
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	check(m.carried_cost == 26, "elite victory gives 8")
	m.position_now = Vector2i(2,1)
	m._start_battle(0)
	await process_frame
	m.battle.battle.outcome = "defeat"
	m._return_from_battle()
	check(m.carried_cost == 26 and m.finished and not m.cleared.has(Vector2i(2,1)), "defeat grants no reward")
	m._restart()
	await _test_shop_lineup(m)
	m._restart()
	m.run.carried_cost = 14
	m.run.party_hp.assign([22, 0, 45])
	m.run.party_max_hp[0] = 52
	m.run.in_battle = true
	m.run.current_encounter = 0
	m._start_battle(0)
	await process_frame
	check(m.battle.battle.cost == 14 and m.battle.battle.heroes[0].max_hp == 52, "graph battle uses current run cost and max HP")
	check(not m.battle.restart_button.visible, "map battle hides standalone restart")
	check(m.battle.item_button.text == "道具 2", "combat toolbar shows run inventory count")
	m.battle.item_button.pressed.emit()
	check(m.battle.item_popup.visible and m.battle.item_rows.get_child_count() == 2, "combat toolbar opens the inventory")
	var smoke: Button = m.battle.item_rows.get_child(1).get_child(1)
	check(not smoke.disabled, "smoke is usable in planning")
	smoke.pressed.emit()
	check(m.battle.item_button.text == "道具 1" and "8 护盾" in m.battle.item_feedback.text, "item usage refreshes count and shows feedback")
	check(m.battle.battle.heroes[0].shield >= 8 and m.battle.battle.heroes[1].shield == 0, "smoke protects living heroes only")
	m.battle.item_popup.hide()
	m.battle.battle.cost = 10
	m.battle.battle.outcome = "victory"
	m._return_from_battle()
	check(m.run.carried_cost == 16 and m.run.party_hp == [28, 0, 46], "graph battle applies its own reward and six HP rest once")
	check(not m.run.items.has("dense_smoke"), "consumed item stays spent on the map")
	m.run.in_battle = true
	m.run.current_encounter = 5
	m._start_battle(5)
	check(m.battle.battle.enemies[0].kind == "colossus" and m.battle.stage.state.enemies.size() == 1, "map-only boss initializes and refreshes its battle scene")
	m.queue_free()
	await process_frame
	print("NODE_TEST failures=", failures)
	quit(1 if failures else 0)

func _test_shop_lineup(m) -> void:
	check(m.opening_lineup_button.visible, "opening lineup button appears at the start")
	m.opening_lineup_button.pressed.emit()
	check(m.lineup_modal_panel.visible and m.end_turn_button.disabled, "opening lineup editor holds map actions")
	m.lineup_close_btn.pressed.emit()
	m.run.turn = 2
	m._refresh_ui()
	m._open_lineup_modal()
	check(not m.opening_lineup_button.visible and not m.lineup_modal_panel.visible, "lineup is locked away from the opening or a shop")
	for node in m.run.map.nodes.values():
		if node.kind == ForestMapGraph.NodeKind.SHOP:
			m.run.position = node.id
			m.run.known[node.id] = true
			break
	m.run.party_hp[1] = 17
	m.run.party_max_hp[1] = 49
	await process_frame
	var shop = m.run.map.get_node(m.run.position)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = shop.pos * m.map_canvas.size
	m._on_map_canvas_input(click)
	check(m.modal_panel.visible and m.modal_shop_lineup_btn.visible, "clicking the current shop opens its lineup entry")
	var cost: int = m.run.carried_cost
	var count: int = m.run.items.size()
	m.modal_btn_3.pressed.emit()
	check(m.modal_panel.visible and m.run.carried_cost == cost - 4 and m.run.items.size() == count + 1, "buying a consumable keeps the shop open")
	m.modal_shop_lineup_btn.pressed.emit()
	check(m.lineup_modal_panel.visible and not m.modal_panel.visible, "shop lineup button opens the editor")
	m.lineup_role_buttons[DemoBattleRules.BLADE_ID].toggled.emit(false)
	m.lineup_role_buttons[DemoBattleRules.ZIXI_ID].toggled.emit(true)
	var card: CheckBox = m.lineup_card_container.get_child(1)
	card.toggled.emit(false)
	m.lineup_save_btn.pressed.emit()
	check(m.run.lineup.has(DemoBattleRules.ZIXI_ID) and not m.run.deck.has(DemoBattleRules.BASE_CARDS[0]), "saving applies the chosen lineup and deck")
	check(m.modal_panel.visible and not m.lineup_modal_panel.visible, "saving restores the shop panel")
	m.modal_leave_btn.pressed.emit()
	m._on_map_canvas_input(click)
	check(m.modal_panel.visible and m.modal_btn_3.disabled, "spent shop can be reopened for lineup editing")
	m.modal_shop_lineup_btn.pressed.emit()
	m.lineup_role_buttons[DemoBattleRules.ZIXI_ID].toggled.emit(false)
	m.lineup_role_buttons[DemoBattleRules.BLADE_ID].toggled.emit(true)
	m.lineup_save_btn.pressed.emit()
	var slot: int = m.run.lineup.find(DemoBattleRules.BLADE_ID)
	check(slot >= 0 and m.run.party_hp[slot] == 17 and m.run.party_max_hp[slot] == 49, "a returning hero retains HP and max HP")
	m.run.party_hp[slot] = 0
	m.modal_shop_lineup_btn.pressed.emit()
	m.lineup_role_buttons[DemoBattleRules.ASH_ID].toggled.emit(false)
	m.lineup_role_buttons[DemoBattleRules.WEAVER_ID].toggled.emit(false)
	check(m.lineup_save_btn.disabled, "an all-knocked-out lineup cannot be saved")
