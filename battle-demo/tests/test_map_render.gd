extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440, 900)
	var m = MapScene.instantiate()
	root.add_child(m)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/map-preview-unrolled.png")

	# Roll 3 steps and inspect a reachable neighbor so the render preview shows full sunlit cartography
	m.roll_dice_instant(3)
	var links: Array = m.run.map.get_links(m.run.position)
	if not links.is_empty():
		m.hovered_node_id = links[0].other(m.run.position)
		m._refresh_inspection_card()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/map-preview.png")

	# Compact 1000x650 viewport readability check
	root.size = Vector2i(1000, 650)
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/map-preview-1000.png")

	m.queue_free()
	await process_frame
	print("MAP_RENDER passed")
	quit()
