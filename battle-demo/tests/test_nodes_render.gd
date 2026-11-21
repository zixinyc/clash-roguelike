extends SceneTree
const MapScene = preload("res://exploration_map.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440, 900)
	var m = MapScene.instantiate()
	root.add_child(m)
	await process_frame

	# 1. Shop modal with 3 card offers + card removal service
	m.run.pending = "shop"
	m._open_modal("shop")
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/nodes-preview.png")

	# 2. Post-battle 3-choose-1 card reward draft modal
	m.run.pending = ""
	m.modal_panel.hide()
	m.run.in_battle = true
	m.run.apply_battle_result(true, m.run.party_hp, m.run.carried_cost)
	m._open_card_reward_modal()
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/card-reward-preview.png")

	# 3. Deck viewer modal
	m.card_reward_panel.hide()
	m._open_deck_viewer(false)
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/deck-viewer-preview.png")

	# 4. Forge Enchant modal
	m.deck_viewer_panel.hide()
	m.run.pending = "forge"
	m.run.carried_cost = 18
	m._open_forge_enchant_modal()
	m._on_forge_card_selected(0)
	m._on_forge_rune_selected("rune_feather")
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/forge-enchant-preview.png")

	m.queue_free()
	await process_frame
	print("NODE_RENDER passed")
	quit()
