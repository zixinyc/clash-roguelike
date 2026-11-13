extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.add_child(MapScene.instantiate())
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/map-preview.png")
	print("MAP_RENDER passed")
	quit()
