extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Main = preload("res://main.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for count in range(1, 4):
		var rules := Rules.new()
		rules.start(73129, 0, false, false, Rules.DEFAULT_LINEUP.slice(0, count))
		for round_number in range(1, 5):
			check(rules.hero_slots.size() == 3 * mini(3, count + round_number - 1), "slot growth and limit")
			rules.phase = "finished"
			rules.next_round()

	var ui := Main.instantiate()
	ui.lineup = [Rules.ASH_ID]
	root.add_child(ui)
	ui.sound.enabled = false
	await process_frame
	ui.battle.phase = "finished"
	ui.battle.next_round()
	ui.battle.phase = "finished"
	ui.battle.next_round()
	ui._refresh(ui.battle.snapshot())
	var rules: DemoBattleRules = ui.battle
	check(rules.assign(rules.hand.find("cleave"), 0, 0).is_empty(), "base attack")
	check(rules.assign(rules.hand.find("guard"), 2, -1).is_empty(), "base guard")
	check(not rules.assign(rules.hand.find("nova"), 1, 0).is_empty(), "two actions per group")
	check(not rules.assign(rules.hand.find("cleave"), 3, 0).is_empty(), "extra slots cannot reuse card")
	check(rules.assign(rules.hand.find("ember"), 3, 0).is_empty(), "extra attack")
	ui._slot_selected(true, 6)
	ui._select_card(rules.hand.find("probe"))
	check(ui.selected_slot == 6 and ui.stage.selected_hero == 0, "third row stays attached to solo character")
	ui._aim(6, 3)
	check(rules.hero_slots[6].card == rules.hand.find("probe"), "third row drag arranges card")
	check(ui.stage.slot_position(true, 6).y < ui.stage.slot_position(true, 3).y, "distinct hit boxes")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://test-output/solo-extra-slots.png") == OK, "capture extra slots")
	check(not rules.lock_and_resolve().is_empty() and rules.plays == 4, "base and extra actions lock and resolve")
	ui.queue_free()
	await process_frame

	rules = Rules.new()
	rules.start(73129, 0, false, false, [Rules.SAKUYA_ID])
	rules.heroes[0].world_round = 2
	rules.phase = "finished"
	rules.next_round()
	check(rules.hero_slots.size() == 3 and rules.hero_slots[0].flexible, "time stop keeps three flexible slots")
	rules.phase = "finished"
	rules.next_round()
	check(rules.hero_slots.size() == 9, "slots resume after time stop")
	print("SHORT_TEAM failures=", failures)
	quit(1 if failures else 0)
