extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var m = MapScene.instantiate()
	root.add_child(m)
	m._open_node("event")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/nodes-preview.png")
	print("NODE_RENDER passed")
	quit()
