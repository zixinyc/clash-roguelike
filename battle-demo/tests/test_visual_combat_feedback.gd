extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Stage = preload("res://scripts/battle_stage.gd")
const Main = preload("res://main.tscn")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	await process_frame

	# 1. Test Weakness Info Helper
	var w_slash := stage._weakness_info("斩击")
	check(w_slash.label == "斩" and w_slash.color == Color("e26d5c"), "Weakness slash produces [斩] with warm coral color")
	var w_pierce := stage._weakness_info("突刺")
	check(w_pierce.label == "刺" and w_pierce.color == Color("48cae4"), "Weakness pierce produces [刺] with cyan color")
	var w_strike := stage._weakness_info("重击")
	check(w_strike.label == "重" and w_strike.color == Color("f4a261"), "Weakness strike produces [重] with gold-bronze color")

	# 2. Test Rect Perimeter Helper for Streaming Light Border
	var test_rect := Rect2(0, 0, 100, 50)
	var pt_top := stage._point_on_rect(test_rect, 50.0)
	check(pt_top == Vector2(50, 0), "Point on top edge matches distance")
	var pt_right := stage._point_on_rect(test_rect, 125.0)
	check(pt_right == Vector2(100, 25), "Point on right edge matches distance")
	var pt_bottom := stage._point_on_rect(test_rect, 200.0)
	check(pt_bottom == Vector2(50, 50), "Point on bottom edge matches distance")
	var pt_left := stage._point_on_rect(test_rect, 275.0)
	check(pt_left == Vector2(0, 25), "Point on left edge matches distance")

	# 3. Test Shatter Stagger & Screen Shake
	stage.screen_shake = 0.0
	stage.impact = 0.0
	stage.state = {
		"heroes": [{"name": "灰烬", "hp": 40, "max_hp": 40, "shield": 0, "acted": false}],
		"enemies": [{"name": "斥候", "hp": 10, "max_hp": 30, "shield": 0, "spent": false, "weakness": "斩击", "fracture": 3, "is_shattered": true}],
		"hero_slots": [],
		"enemy_slots": [],
		"phase": "execution"
	}
	await stage.play_event({"type": "shatter_stagger", "target": 0}, 4.0)
	check(stage.screen_shake > 1.0, "Shatter stagger event triggers screen shake trauma > 1.0")
	check(stage.impact > 1.0, "Shatter stagger event triggers impact wobble > 1.0")
	check(stage.floaters.any(func(f: Dictionary) -> bool: return f.text.contains("碎甲大失衡")), "Shatter stagger event creates explosion floater")

	# 4. Test Fracture Hit Event
	await stage.play_event({"type": "fracture_hit", "target": 0, "fracture": 2, "tag": "斩击"}, 4.0)
	check(stage.floaters.any(func(f: Dictionary) -> bool: return f.text.contains("弱点破损 2/3")), "Fracture hit event creates fracture floater")

	# 5. Test Momentum Break Event & Screen Shake
	stage.screen_shake = 0.0
	await stage.play_event({"type": "momentum_break", "momentum": 0, "hero": 0, "target": 0}, 4.0)
	check(stage.screen_shake > 0.8, "Momentum break triggers screen shake")
	check(stage.floaters.any(func(f: Dictionary) -> bool: return f.text.contains("势能中断")), "Momentum break creates floater with break notice")

	# 6. Test Momentum Gain Event
	await stage.play_event({"type": "momentum_gain", "momentum": 2, "hero": 0, "target": 0}, 4.0)
	check(stage.floaters.any(func(f: Dictionary) -> bool: return f.text.contains("势能 ×2")), "Momentum gain creates momentum floater")

	stage.queue_free()
	await process_frame

	# 7. Test Main UI and Planning HUD Feedback
	var ui = Main.instantiate()
	ui.lineup = [Rules.MINGHE_ID, Rules.ASH_ID, Rules.BLADE_ID]
	root.add_child(ui)
	ui.sound.enabled = false
	await process_frame

	# Check Momentum HUD labels across tiers
	var snap: Dictionary = ui.battle.snapshot()
	snap.round_momentum = 1
	ui._refresh(snap)
	check(ui.momentum_panel.is_visible_in_tree() and ui.momentum_label.text.contains("势能 ×1") and ui.momentum_label.text.contains("势能起"), "Tier 1 momentum HUD displays '势能起 · 拼点+1'")

	snap.round_momentum = 2
	ui._refresh(snap)
	check(ui.momentum_panel.is_visible_in_tree() and ui.momentum_label.text.contains("势能 ×2") and ui.momentum_label.text.contains("势如破竹"), "Tier 2 momentum HUD displays '势如破竹 · 拼点+1 震击+3'")

	snap.round_momentum = 3
	ui._refresh(snap)
	check(ui.momentum_panel.is_visible_in_tree() and ui.momentum_label.text.contains("势能 ×3") and ui.momentum_label.text.contains("势不可挡"), "Tier 3 momentum HUD displays '势不可挡 · 拼点+2 贯穿+6'")

	# Check Shared Support Drop handler
	ui.stage.shared_support_dropped.emit(ui.battle.hand.find(Rules.Minghe.CONCERTO))
	check(ui.battle.shared_support_slot.active and ui.battle.shared_support_slot.key == Rules.Minghe.CONCERTO, "Dropping support card schedules into shared support slot")

	# Check Click Cancel on Stage
	ui.stage.shared_support_clicked.emit()
	check(not ui.battle.shared_support_slot.active, "Clicking active shared support slot cancels it")

	# Check minghe in cooldown state
	var minghe_hero: Dictionary = ui.battle.heroes[0]
	minghe_hero.no_rhythm_round = ui.battle.turn
	ui._refresh(ui.battle.snapshot())
	check(int(minghe_hero.no_rhythm_round) == int(ui.battle.turn), "Minghe marked in rhythm cooldown round")

	await create_timer(0.1).timeout
	ui.queue_free()
	await process_frame

	print("VISUAL_COMBAT_FEEDBACK checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
