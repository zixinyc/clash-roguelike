extends SceneTree
const Main = preload("res://main.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ui = Main.instantiate()
	root.add_child(ui)
	await process_frame
	ui._switch_zixi()
	ui._select_card(ui.battle.hand.find("zixi_central_limit"))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/target-guidance.png")
	print("TARGET_RENDER passed")
	quit()
