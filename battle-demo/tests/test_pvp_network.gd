extends SceneTree

var host := false
var port := 7000
var network: Node
var setup: Control
var lobby: Control
var result_count := 0
var rejected := 0
var did_finish := false
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	host = "--host" in args
	if not host and not "--guest" in args:
		push_error("Use -- --host or -- --guest")
		quit(2)
		return
	for arg in args:
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	root.title = "余烬交锋 PvP 验收 · " + ("房主" if host else "来宾")
	create_timer(60).timeout.connect(func() -> void: _check(false, "timed out"))
	network = root.get_node("NetworkManager")
	setup = load("res://battle_setup.tscn").instantiate()
	root.add_child(setup)
	for button in setup.find_children("*", "Button", true, false):
		if button.text == "好友对战":
			button.pressed.emit()
			break
	if not is_instance_valid(setup.active_battle):
		_check(false, "normal setup screen opens the PvP lobby")
		return
	lobby = setup.active_battle
	network.round_opened.connect(_round_opened)
	network.round_resolved.connect(_round_resolved)
	network.plan_rejected.connect(func(_error: String) -> void: rejected += 1)
	network.session_closed.connect(_session_closed)
	lobby._port.value = port
	if host:
		lobby._host.pressed.emit()
	else:
		lobby._join.pressed.emit()

func _round_opened(state: Dictionary) -> void:
	var turn: int = state.turn
	var view: Control = lobby._battle
	view.speed = 4.0 if host else 2.0
	view.sound.enabled = false
	_check(state.phase == "response" and not view.busy, "round %d is editable" % turn)
	_check(_opponent_hidden(view.battle.enemy_slots), "empty public opponent slots")
	_check((network._rules != null) == host, "only host has authoritative rules")
	if turn <= 2:
		await _plan_private_round(turn, view)
	else:
		if host:
			var source := _living_slot(view.battle.heroes, 1)
			var target := _living_slot(view.battle.enemies, 0)
			view._slot_selected(true, source)
			view._slot_selected(false, target)
			view._select_card(view.battle.hand.find("nova"))
			view.assign_button.pressed.emit()
			_check(view.battle.hero_slots[source].active, "can attack a surviving opponent")
		view.ready_button.pressed.emit()

func _plan_private_round(turn: int, view: Control) -> void:
	if turn == 1:
		network.submit_plan(turn, [{"slot": 3, "card_key": "needle", "target": 0}, {"slot": 1, "card_key": "not_in_deck", "target": 0}])
		var timeout := create_timer(5)
		while rejected == 0 and timeout.time_left > 0:
			await process_frame
		_check(rejected == 1 and not view.own_locked, "host rejected invalid card without locking")
	view._slot_selected(true, 0)
	view._slot_selected(false, 0)
	view._select_card(view.battle.hand.find("cleave" if host else "steady"))
	view.assign_button.pressed.emit()
	_check(view.battle.hero_slots[0].active and view.battle.reserved_cost() > 0, "can arrange a private card")
	view.cancel_button.pressed.emit()
	_check(not view.battle.hero_slots[0].active and view.battle.reserved_cost() == 0, "can undo a private card")
	view.assign_button.pressed.emit()
	if turn == 2:
		view._select_card(view.battle.hand.find("guard"))
		view.assign_button.pressed.emit()
		_check(view.battle.hero_slots[2].active, "can include a guard in the same plan")
	_check(_opponent_hidden(view.battle.enemy_slots), "drafts remain private")
	if not host:
		var timeout := create_timer(5)
		while not view.opponent_locked and timeout.time_left > 0:
			await process_frame
		_check(view.opponent_locked and not view.own_locked, "receive only the opponent lock flag")
		_check(_opponent_hidden(view.battle.enemy_slots), "opponent locked but specific card remains hidden")
		await create_timer(0.55).timeout
		_check(result_count < turn and view.battle.turn == turn, "cannot resolve with only one player locked")
		if not host and turn == 1 and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/pvp-guest.png")
	view.ready_button.pressed.emit()
	if host:
		_check(view.own_locked and view.busy and result_count < turn, "first lock waits and freezes local edits")

func _round_resolved(state: Dictionary, events: Array) -> void:
	result_count += 1
	_check(result_count == state.turn, "each round resolves once")
	_check(not events.is_empty() and events[0].type == "reveal", "reveal occurs after receiving both plans")
	if state.turn <= 2:
		_check(events.any(func(event: Dictionary) -> bool: return event.type == "clash"), "mutual attacks produce clash events")
		for slots in [events[0].snapshot.hero_slots, events[0].snapshot.enemy_slots]:
			_check(slots.filter(func(slot: Dictionary) -> bool: return slot.active).size() == state.turn, "rejected plan left no actions behind")
	if state.turn == 2:
		_check(events.any(func(event: Dictionary) -> bool: return event.type == "guard"), "plays own guard")
		_check(events.any(func(event: Dictionary) -> bool: return event.type == "enemy_guard"), "plays opponent guard")
	var host_hp: Array = (state.heroes if host else state.enemies).map(func(unit: Dictionary) -> int: return unit.hp)
	var guest_hp: Array = (state.enemies if host else state.heroes).map(func(unit: Dictionary) -> int: return unit.hp)
	var host_cost: int = state.cost if host else state.enemy_cost
	var guest_cost: int = state.enemy_cost if host else state.cost
	var winner := ""
	if not state.outcome.is_empty():
		winner = "host" if (state.outcome == "victory") == host else "guest"
	var exchanges := []
	for event in events:
		if event.type == "clash":
			var h := ["left", "left_heads", "hero_remaining"] if host else ["right", "right_heads", "enemy_remaining"]
			var g := ["right", "right_heads", "enemy_remaining"] if host else ["left", "left_heads", "hero_remaining"]
			exchanges.append([event[h[0]], event[g[0]], event[h[1]], event[g[1]], event[h[2]], event[g[2]]])
	print("PVP_RESULT " + JSON.stringify({"turn": state.turn, "host_hp": host_hp, "guest_hp": guest_hp, "host_cost": host_cost, "guest_cost": guest_cost, "winner": winner, "events": events.size(), "exchanges": exchanges}))
	if winner.is_empty():
		return
	_check(result_count >= 2, "played at least two rounds")
	var view: Control = lobby._battle
	while is_instance_valid(view) and view.battle.outcome.is_empty():
		await process_frame
	did_finish = true
	if not host:
		await create_timer(0.5).timeout
		network.leave_game()
		await create_timer(0.2).timeout
		_finish()

func _session_closed(_message: String) -> void:
	if host:
		_check(did_finish, "guest disconnected after the outcome played")
		_check(lobby._form.visible and lobby._battle == null, "return to lobby after disconnect")
		_finish()

func _opponent_hidden(slots: Array) -> bool:
	return slots.all(func(slot: Dictionary) -> bool: return not slot.active and slot.key.is_empty() and slot.card == -1 and slot.target == -1)

func _living_slot(units: Array, category: int) -> int:
	for i in units.size():
		if units[i].hp > 0:
			return i * 3 + category
	return -1

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("PVP_FAIL " + message)
		failed = true
		quit(1)

func _finish() -> void:
	if not failed:
		print("PVP_PASS " + ("host" if host else "guest"))
		quit()
