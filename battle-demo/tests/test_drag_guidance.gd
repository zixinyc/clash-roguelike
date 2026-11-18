extends SceneTree
const Main = preload("res://main.tscn")
var failures := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		push_error(msg)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ui = Main.instantiate()
	root.add_child(ui)
	await process_frame
	var source = ui.stage.slot_position(true, 0) * ui.stage.size / ui.stage.BASE
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source
	ui.stage._gui_input(press)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(5, 5)
	ui.stage._gui_input(release)
	check("未安排" in ui.log_label.text, "cancelled drag should explain target")
	var first: int = ui.hand_view.visible_indices[0]
	ui._select_card(first)
	ui._slot_selected(true, 3)
	check("重新选择" in ui.log_label.text, "switching hero should explain cleared selection")
	print("DRAG_GUIDANCE failures=", failures)
	quit(1 if failures else 0)
