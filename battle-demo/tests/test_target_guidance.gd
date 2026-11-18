extends SceneTree
const Main = preload("res://main.tscn")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ui = Main.instantiate()
	root.add_child(ui)
	ui.sound.enabled = false
	await process_frame
	ui._switch_zixi()
	var index: int = ui.battle.hand.find("zixi_central_limit")
	ui._select_card(index)
	var h: Dictionary = ui.battle.hero_slots[3]
	var e: Dictionary = ui.battle.enemy_slots[0]
	h.speed = 4
	e.active = true
	e.category = 0
	e.target = h.unit
	e.speed = 7
	check(ui._target_guidance(0).valid, "own target can clash while slower")
	e.target = 0
	e.speed = 4
	var g: Dictionary = ui._target_guidance(0)
	check(not g.valid and "速度更高" in g.text, "equal speed intercept rejected with explanation")
	e.speed = 3
	check(ui._target_guidance(0).valid, "faster intercept")
	e.active = false
	g = ui._target_guidance(0)
	check(not g.valid and "未启用" in g.text, "inactive explanation")
	e.active = true
	e.category = 2
	g = ui._target_guidance(0)
	check(not g.valid and "防御" in g.text, "defense explanation")
	e.category = 0
	ui.battle.cost = 0
	g = ui._target_guidance(0)
	check(not g.valid and "cost" in g.text, "cost rejection")
	ui.battle.cost = 30
	ui._refresh(ui.battle.snapshot())
	check(ui.stage.target_guidance.size() == ui.battle.enemy_slots.size(), "stage gets target guidance")
	var hover := InputEventMouseMotion.new()
	hover.position = ui.stage.slot_position(false, 0) * ui.stage.size / ui.stage.BASE
	ui.stage._gui_input(hover)
	check(not ui.stage.tooltip_text.is_empty(), "hover exposes target reason")
	ui.hand_view.group_buttons[1].pressed.emit()
	ui._select_card(ui.battle.hand.find("needle"))
	e.active = false
	e.speed = 9
	h.speed = 3
	ui._slot_selected(false, 0)
	g = ui._target_guidance(0)
	check(g.valid and "空槽" in g.text and g.text in ui.hint.text, "slow attack gets the same valid idle target in the stage and hand")
	ui._assign()
	check(ui.battle.hero_slots[3].active and ui.battle.hero_slots[3].target == 0, "the slow attack is placed on the idle target")
	ui.queue_free()
	await process_frame
	print("TARGET_GUIDANCE failures=", failures)
	quit(1 if failures else 0)
