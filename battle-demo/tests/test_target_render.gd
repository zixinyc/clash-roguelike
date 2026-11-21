extends SceneTree
const Main = preload("res://main.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440, 900)
	var ui = Main.instantiate()
	root.add_child(ui)
	await process_frame
	# Assign 1 card to Ash and select a card on Blade so preview shows both filled slots + live guidance tags
	ui._select_card(ui.battle.hand.find("observe"))
	ui._slot_selected(false, 0)
	ui._assign()
	ui._slot_selected(true, 3)
	ui.hand_view.group_buttons[1].pressed.emit()
	ui._select_card(ui.battle.hand.find("ember"))
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/target-guidance.png")

	# Compact 1000x650 viewport check
	root.size = Vector2i(1000, 650)
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/target-guidance-1000.png")

	ui.queue_free()
	await process_frame

	# Stage 4 Slay-the-Spire deck-cycle battle preview (10-card starter deck, 6-card draw, Draw/Discard buttons + 本轮可用)
	root.size = Vector2i(1440, 900)
	var CardPool = preload("res://scripts/card_pool.gd")
	var Rules = preload("res://scripts/battle_rules.gd")
	var ui2 = Main.instantiate()
	ui2.lineup = Rules.DEFAULT_LINEUP.duplicate()
	ui2.deck = CardPool.build_starter_deck(Rules.DEFAULT_LINEUP)
	ui2.use_deck_cycle = true
	root.add_child(ui2)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/stage4-deck-cycle.png")

	ui2.queue_free()
	await process_frame
	print("TARGET_RENDER passed")
	quit()
