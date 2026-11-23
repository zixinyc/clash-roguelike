extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Main = preload("res://main.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ui = Main.instantiate()
	ui.lineup = [Rules.MINGHE_ID, Rules.ZIWU_ID, Rules.PUFUFU_ID]
	root.add_child(ui)
	ui.sound.enabled = false
	await process_frame
	var failures := 0
	if not ui.support_slot_button.is_visible_in_tree() or ui.support_slot_button.text != "共有辅助槽 · 空":
		push_error("The empty support slot must be visible before choosing a card")
		failures += 1
	ui.support_slot_button.pressed.emit()
	if not ui.log_label.text.contains("先选择一张防御或辅助牌") or ui.battle.shared_support_slot.active:
		push_error("Clicking the empty slot must explain how to place a support card")
		failures += 1
	ui._select_card(ui.battle.hand.find(Rules.Minghe.CONCERTO))
	ui.ally_target_picker.select(2)
	ui.ally_target_picker.item_selected.emit(2)
	ui.support_slot_button.pressed.emit()
	if ui.battle.shared_support_slot.get("support_target") != 2:
		push_error("Shared support must retain the UI's chosen recipient")
		failures += 1
	if ui.support_slot_button.text != "共有辅助槽 · 清商协奏":
		push_error("The shared slot must display its assigned card")
		failures += 1
	ui.support_slot_button.pressed.emit()
	if ui.battle.shared_support_slot.active:
		push_error("Shared support must be cancellable from the toolbar")
		failures += 1
	ui._slot_selected(true, 3)
	ui._select_card(ui.battle.hand.find(Rules.ZiWu.BLOOD_PACT))
	ui.ally_target_picker.select(1)
	ui.ally_target_picker.item_selected.emit(1)
	if not ui.ally_target_dialog.visible or ui.battle.hero_slots[ui.selected_slot].active:
		push_error("Friendly actions must wait for confirmation")
		failures += 1
	ui.ally_target_dialog.confirmed.emit()
	if ui.battle.hero_slots[ui.selected_slot].get("ally_target") != 0:
		push_error("Friendly confirmation must schedule the selected ally")
		failures += 1
	ui.ally_target_dialog.hide()
	var rules: DemoBattleRules = ui.battle
	var target := rules.enemies[0]
	var starting_hp := int(target.hp)
	target.shield = 15
	target.shield_until = {1: 5, 2: 10}
	rules.round_momentum = 2
	var events: Array[Dictionary] = []
	rules._deal_hit(events, true, 1, 0, 3, 1, 1, false, Rules.ZiWu.AFTERIMAGE)
	if target.hp != starting_hp or target.shield != 8 or target.shield_until != {2: 8}:
		push_error("Expansion damage and momentum must hit shields in expiry order")
		failures += 1
	await create_timer(0.2).timeout
	ui.queue_free()
	await process_frame
	print("EXPANSION_UI failures=", failures)
	quit(1 if failures else 0)
