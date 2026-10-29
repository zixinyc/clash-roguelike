extends Control

const Rules = preload("res://scripts/battle_rules.gd")
const Stage = preload("res://scripts/battle_stage.gd")
const Card = preload("res://scripts/card_view.gd")
const Sound = preload("res://scripts/synth_audio.gd")
const GOLD := Color("dfbd83")
const MUTED := Color("82959e")
const PALE := Color("e7e9e3")
const CYAN := Color("94c4ca")

var battle := Rules.new()
var stage: DemoBattleStage
var sound: DemoSynthAudio
var displayed: Dictionary = {}
var selected_card := -1
var selected_hero := 0
var selected_enemy := 0
var busy := false
var speed := 1.0
var demo_running := false
var seed_value := 73129
var hand_signature := ""
var hand_row: HBoxContainer
var hero_buttons: Array[Button] = []
var enemy_buttons: Array[Button] = []
var cards: Array[DemoCardView] = []
var cost_label: Label
var turn_label: Label
var plays_label: Label
var status_label: Label
var preview_title: Label
var preview_body: Label
var log_label: RichTextLabel
var play_button: Button
var end_button: Button
var demo_button: Button
var speed_button: Button
var restart_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var rules_dialog: AcceptDialog
var log_lines: Array[String] = []

func _ready() -> void:
	_build_theme()
	_build_ui()
	sound = Sound.new()
	add_child(sound)
	new_battle()
	if "--visual-smoke" in OS.get_cmdline_user_args():
		_visual_smoke.call_deferred()

func _build_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 15
	ui_theme.set_color("font_color", "Label", PALE)
	ui_theme.set_color("font_color", "Button", PALE)
	ui_theme.set_color("font_hover_color", "Button", Color("f2ddb8"))
	ui_theme.set_color("font_focus_color", "Button", Color("f2ddb8"))
	ui_theme.set_color("font_disabled_color", "Button", Color("526873"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("192630"), Color("35474f"), 5))
	ui_theme.set_stylebox("hover", "Button", _style(Color("263740"), Color("ac9267"), 5))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("3b3b32"), GOLD, 5))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("111c24"), Color("24333b"), 5))
	ui_theme.set_stylebox("focus", "Button", _outline(GOLD))
	ui_theme.set_stylebox("panel", "AcceptDialog", _style(Color("13222b"), GOLD, 8, 24))
	ui_theme.set_color("font_color", "RichTextLabel", MUTED)
	theme = ui_theme

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b141c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)
	_build_header(column)
	var stage_panel := PanelContainer.new()
	stage_panel.add_theme_stylebox_override("panel", _style(Color("12202a"), Color("3c4c51"), 4, 1))
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.custom_minimum_size.y = 310
	column.add_child(stage_panel)
	stage = Stage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.unit_selected.connect(_on_stage_unit)
	stage_panel.add_child(stage)
	_build_selection_row(column)
	_build_hand_area(column)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var footer_left := _label("原型测试值 · 每人行动一次 / 每回合最多 3 张 / 失败退 50% 向下取整", 11, Color("69818b"))
	footer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_left)
	footer.add_child(_label("1–5 选牌  ·  Q/E 选人  ·  A/D 选敌  ·  空格出牌  ·  Enter 结束回合", 11, Color("69818b")))
	_build_result()
	rules_dialog = AcceptDialog.new()
	rules_dialog.title = "战斗演示 · 操作与规则"
	rules_dialog.dialog_text = "目标：击败两名敌人。每位成员每回合可出一张牌，全队最多三张。\n\n1. 点击我方角色与敌人，再选择手牌。\n2. 点击「出牌 · 拼点」或按空格。也可点击「演示一回合」自动操作。\n3. 双方掷出所有剩余硬币，威力低的一方破坏一枚硬币，再次比拼。\n4. 最终胜方按剩余硬币攻击；失败牌按实付 cost 返还 50%，向下取整。\n5. 首次拼点获胜每回合奖励 1 cost；结束回合获得 3 cost，重新抽 5 张。\n6. 未被拼点消耗的敌人行动，会在回合结束时攻击。护盾吸收伤害。\n\n这是一场本地演示。三人共用手牌、一次行动、数值与平局处理均为测试配置。\n连续三次平局后使用随机决胜，避免无限僵持。加速不改变规则结果。"
	rules_dialog.min_size = Vector2i(690, 390)
	add_child(rules_dialog)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 70
	row.add_theme_constant_override("separation", 22)
	parent.add_child(row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	row.add_child(title_box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 15)
	title_box.add_child(title_row)
	title_row.add_child(_label("余烬交锋", 29, Color("ead9b8")))
	var prototype := _label("SINGLE BATTLE / 单场演示", 11, CYAN)
	prototype.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(prototype)
	title_box.add_child(_label("CLASH ROGUELIKE    /    北境废站 · 接敌", 11, MUTED))
	turn_label = _label("ROUND 01", 18, PALE)
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(turn_label)
	row.add_child(_separator())
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 9)
	row.add_child(wallet)
	var wallet_name := _label("◈  cost", 15, GOLD)
	wallet_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(wallet_name)
	cost_label = _label("09", 31, GOLD)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(cost_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	row.add_child(buttons)
	speed_button = _button("演出 ×1", _cycle_speed, Vector2(84, 38))
	buttons.add_child(speed_button)
	var help_button := _button("规则 ?", func() -> void: rules_dialog.popup_centered(), Vector2(75, 38))
	buttons.add_child(help_button)
	restart_button = _button("重开", new_battle, Vector2(64, 38))
	restart_button.tooltip_text = "以相同种子重新开始，便于比较不同的出牌选择"
	buttons.add_child(restart_button)

func _build_selection_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var caption := _label("出战", 12, MUTED)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	for i in 3:
		var button := _button(["灰烬", "长锋", "织火"][i], _select_hero.bind(i), Vector2(106, 38))
		button.tooltip_text = "选择出战成员；每位成员每回合行动一次"
		hero_buttons.append(button)
		row.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	plays_label = _label("行动 0 / 3", 13, GOLD)
	plays_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(plays_label)
	row.add_child(_separator())
	var target_caption := _label("目标", 12, MUTED)
	target_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(target_caption)
	for i in 2:
		var button := _button(["锈刃巡卫", "失序哨兵"][i], _select_enemy.bind(i), Vector2(119, 38))
		enemy_buttons.append(button)
		row.add_child(button)

func _build_hand_area(parent: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	parent.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	body.add_child(left)
	var heading := HBoxContainer.new()
	left.add_child(heading)
	heading.add_child(_label("HAND / 手牌", 12, GOLD))
	status_label = _label("选择一张手牌，安排下一次交锋", 12, MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(status_label)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 11)
	left.add_child(hand_row)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 277
	right.add_theme_constant_override("separation", 7)
	body.add_child(right)
	preview_title = _label("下一次交锋", 17, GOLD)
	right.add_child(preview_title)
	preview_body = _label("选牌后查看威力与消耗", 12, MUTED)
	preview_body.custom_minimum_size.y = 61
	right.add_child(preview_body)
	play_button = _button("出牌 · 拼点   →", _play_selected, Vector2(277, 44))
	play_button.add_theme_stylebox_override("normal", _style(Color("d2b27b"), Color("dfbf88"), 4))
	play_button.add_theme_stylebox_override("hover", _style(Color("ead09e"), Color("f2d6a3"), 4))
	play_button.add_theme_color_override("font_color", Color("17212a"))
	play_button.add_theme_color_override("font_hover_color", Color("17212a"))
	right.add_child(play_button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)
	end_button = _button("结束回合", _end_turn, Vector2(130, 36))
	end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_button.tooltip_text = "敌方执行尚未消耗的行动，然后获得 3 cost 并重新抽牌"
	actions.add_child(end_button)
	demo_button = _button("演示一回合", _auto_round, Vector2(130, 36))
	demo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(demo_button)
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(277, 63)
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_stylebox_override("normal", _style(Color("0b151d"), Color("23333d"), 3, 7))
	right.add_child(log_label)

func _build_result() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(490, 265)
	result_panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.09, 0.12, 0.98), GOLD, 7, 30))
	result_panel.visible = false
	center.add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	result_panel.add_child(box)
	result_title = _label("VICTORY / 战斗胜利", 26, GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_body = _label("", 15, PALE)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_body)
	var retry := _button("再来一场", new_battle, Vector2(0, 45))
	box.add_child(retry)
	box.add_child(_label("测试原型 · 在下一次交锋中尝试不同选择", 12, MUTED))

func new_battle() -> void:
	if busy:
		return
	battle.start(seed_value)
	selected_card = -1
	selected_hero = 0
	selected_enemy = 0
	demo_running = false
	result_panel.hide()
	stage.reset_visuals()
	log_lines.clear()
	_log("抵达北境废站。敌方行动已公开。")
	_refresh(battle.snapshot())
	status_label.text = "先选角色与目标，再选择一张手牌"
	demo_button.grab_focus()

func _refresh(snapshot: Dictionary) -> void:
	displayed = snapshot
	var locked := busy or demo_running
	stage.set_state(snapshot)
	stage.selected_hero = selected_hero
	stage.selected_enemy = selected_enemy
	stage.busy = locked
	cost_label.text = "%02d" % snapshot.cost
	turn_label.text = "ROUND %02d" % snapshot.turn
	plays_label.text = "行动 %d / 3" % snapshot.plays
	for i in hero_buttons.size():
		var unit: Dictionary = snapshot.heroes[i]
		hero_buttons[i].text = "%s%s" % [unit.name, " · 已行动" if unit.acted else ""]
		hero_buttons[i].disabled = locked or unit.hp <= 0
		hero_buttons[i].add_theme_color_override("font_color", GOLD if i == selected_hero else PALE)
		if i == selected_hero:
			hero_buttons[i].add_theme_stylebox_override("normal", _style(Color("29323a"), GOLD, 4))
		else:
			hero_buttons[i].remove_theme_stylebox_override("normal")
	for i in enemy_buttons.size():
		enemy_buttons[i].disabled = locked or snapshot.enemies[i].hp <= 0
		enemy_buttons[i].add_theme_color_override("font_color", Color("e2917e") if i == selected_enemy else PALE)
	var next_signature: String = "|".join(snapshot.hand)
	if next_signature != hand_signature or (cards.is_empty() and not snapshot.hand.is_empty()):
		hand_signature = next_signature
		for child in hand_row.get_children():
			hand_row.remove_child(child)
			child.queue_free()
		cards.clear()
		for i in snapshot.hand.size():
			var card := Card.new()
			card.skill = Rules.SKILLS[snapshot.hand[i]]
			card.key_number = i + 1
			card.pressed.connect(_select_card.bind(i))
			hand_row.add_child(card)
			cards.append(card)
		for i in range(snapshot.hand.size(), 5):
			var empty_slot := Control.new()
			empty_slot.custom_minimum_size = Vector2(142, 222)
			empty_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hand_row.add_child(empty_slot)
	for i in cards.size():
		cards[i].selected = i == selected_card
		cards[i].disabled = locked or not snapshot.outcome.is_empty()
		cards[i].queue_redraw()
	play_button.disabled = locked or not snapshot.outcome.is_empty() or selected_card < 0
	end_button.disabled = locked or not snapshot.outcome.is_empty()
	demo_button.disabled = busy or demo_running or not snapshot.outcome.is_empty()
	restart_button.disabled = locked
	_update_preview()

func _update_preview() -> void:
	if selected_card < 0 or selected_card >= displayed.hand.size():
		preview_title.text = "下一次交锋"
		preview_body.text = "选择手牌，查看威力范围\n角色与目标可在战场上直接点击"
		return
	var skill: Dictionary = Rules.SKILLS[displayed.hand[selected_card]]
	preview_title.text = "%s · %s" % [displayed.heroes[selected_hero].name, skill.name]
	if skill.kind == "guard":
		preview_body.text = "支付 %d cost → 获得 9 护盾\n护盾持续至本回合结束" % skill.cost
		play_button.text = "出牌 · 防御   →"
	else:
		var target: Dictionary = displayed.enemies[selected_enemy]
		preview_body.text = "威力 %d—%d  对抗  %d—%d\n消耗 %d cost · 失败返还 %d" % [skill.base, skill.base + skill.power * skill.coins, target.base, target.base + target.power * target.coins, skill.cost, int(floor(skill.cost * 0.5))]
		if target.spent:
			preview_body.text = "敌方行动已消耗 → 单方面攻击\n支付 %d cost · 按 %d 枚硬币攻击" % [skill.cost, skill.coins]
		play_button.text = "出牌 · 攻击   →" if target.spent else "出牌 · 拼点   →"
	if not busy and not demo_running:
		play_button.disabled = not battle.can_play(selected_card, selected_hero, selected_enemy).is_empty()

func _select_card(index: int) -> void:
	if busy or not battle.outcome.is_empty() or index >= battle.hand.size():
		return
	selected_card = index
	sound.play_sound("select")
	_refresh(battle.snapshot())
	var error := battle.can_play(selected_card, selected_hero, selected_enemy)
	status_label.text = "空格或点击出牌，开始这次交锋" if error.is_empty() else error

func _select_hero(index: int) -> void:
	if busy or battle.heroes[index].hp <= 0:
		return
	selected_hero = index
	sound.play_sound("select")
	_refresh(battle.snapshot())
	status_label.text = "这位成员已行动，请换一位成员" if battle.heroes[index].acted else "已选择 %s" % battle.heroes[index].name

func _select_enemy(index: int) -> void:
	if busy or battle.enemies[index].hp <= 0:
		return
	selected_enemy = index
	sound.play_sound("select")
	_refresh(battle.snapshot())

func _on_stage_unit(allied: bool, index: int) -> void:
	if allied:
		_select_hero(index)
	else:
		_select_enemy(index)

func _play_selected() -> void:
	if busy or not battle.outcome.is_empty():
		return
	var error := battle.can_play(selected_card, selected_hero, selected_enemy)
	if not error.is_empty():
		status_label.text = error
		return
	var events := battle.play(selected_card, selected_hero, selected_enemy)
	selected_card = -1
	await _play_events(events)
	_select_next_units()
	_refresh(battle.snapshot())

func _end_turn() -> void:
	if busy or not battle.outcome.is_empty():
		return
	selected_card = -1
	await _play_events(battle.end_turn())
	_select_next_units()
	_refresh(battle.snapshot())

func _play_events(events: Array[Dictionary]) -> void:
	busy = true
	for event in events:
		_refresh(event.snapshot)
		_event_message(event)
		await stage.play_event(event, speed)
	busy = false
	stage.busy = false
	stage.banner = ""
	status_label.text = "继续选择手牌，或结束回合补充 cost"
	if battle.plays >= Rules.MAX_PLAYS:
		status_label.text = "三次行动已完成，结束回合进入下一轮"
	if not battle.outcome.is_empty():
		_show_result()

func _event_message(event: Dictionary) -> void:
	match event.type:
		"paid":
			_log("%s 使用 %s，支付 %d cost" % [displayed.heroes[event.hero].name, event.skill, event.paid])
		"clash":
			sound.play_sound("clash")
			status_label.text = "拼点 %d : %d  ·  剩余硬币 %d : %d" % [event.left, event.right, event.hero_remaining, event.enemy_remaining]
			if event.decider:
				_log("连续平局，触发决胜判定")
		"strike":
			sound.play_sound("strike")
			var victim: Dictionary = displayed.enemies[event.target] if event.allied else displayed.heroes[event.target]
			_log("%s 受到 %d 伤害%s" % [victim.name, event.damage, "（护盾抵挡 %d）" % event.blocked if event.blocked > 0 else ""])
		"guard":
			sound.play_sound("guard")
			_log("%s 获得 9 护盾" % displayed.heroes[event.hero].name)
		"refund":
			_log("拼点失败，返还 %d cost" % event.amount)
		"reward":
			_log("本回合首次拼点获胜，cost +1")
		"new_turn":
			_log("第 %d 回合开始，cost +3，抽取 5 张牌" % displayed.turn)
		"unopposed":
			_log("敌方行动已消耗，执行单方面攻击")

func _select_next_units() -> void:
	for i in battle.heroes.size():
		if battle.heroes[i].hp > 0 and not battle.heroes[i].acted:
			selected_hero = i
			break
	if battle.enemies[selected_enemy].hp <= 0:
		for i in battle.enemies.size():
			if battle.enemies[i].hp > 0:
				selected_enemy = i
				break

func _auto_round() -> void:
	if busy or demo_running or not battle.outcome.is_empty():
		return
	demo_running = true
	while battle.plays < Rules.MAX_PLAYS and battle.outcome.is_empty():
		_select_next_units()
		var choice := -1
		var best := -1.0
		for i in battle.hand.size():
			var skill: Dictionary = Rules.SKILLS[battle.hand[i]]
			if not battle.can_play(i, selected_hero, selected_enemy).is_empty():
				continue
			var value: float = skill.base + skill.power * skill.coins * 0.65 if skill.kind == "attack" else 1.0
			if value > best:
				best = value
				choice = i
		if choice < 0:
			break
		selected_card = choice
		_refresh(battle.snapshot())
		await get_tree().create_timer(0.3 / speed).timeout
		await _play_selected()
	if battle.outcome.is_empty():
		await _end_turn()
	demo_running = false
	_refresh(battle.snapshot())

func _show_result() -> void:
	stage.reset_visuals()
	var won := battle.outcome == "victory"
	result_title.text = "VICTORY / 战斗胜利" if won else "DEFEAT / 小队失利"
	result_title.add_theme_color_override("font_color", GOLD if won else Color("d58b7c"))
	result_body.text = "在第 %d 回合结束交锋\n剩余 cost：%d\n\n再试一次，比较不同的出牌选择。" % [battle.turn, battle.cost]
	result_panel.show()
	sound.play_sound("victory" if won else "defeat")
	result_panel.get_child(0).get_child(2).grab_focus()

func _log(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 30:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)

func _cycle_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	speed_button.text = "演出 ×%d" % int(speed)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or rules_dialog.visible:
		return
	if busy or demo_running:
		return
	if result_panel.visible and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		new_battle()
		get_viewport().set_input_as_handled()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_select_card(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		_play_selected()
	elif event.keycode == KEY_ENTER:
		_end_turn()
	elif event.keycode == KEY_Q or event.keycode == KEY_E:
		var step := 1 if event.keycode == KEY_E else -1
		for i in 3:
			var next := posmod(selected_hero + step * (i + 1), 3)
			if battle.heroes[next].hp > 0:
				_select_hero(next)
				break
	elif event.keycode == KEY_A or event.keycode == KEY_D:
		var next := 1 - selected_enemy
		if battle.enemies[next].hp > 0:
			_select_enemy(next)
	elif event.keycode == KEY_R:
		new_battle()
	else:
		return
	get_viewport().set_input_as_handled()

func _label(value: String, font_size: int = 15, color: Color = PALE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, callback: Callable, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = minimum
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _separator() -> VSeparator:
	var separator := VSeparator.new()
	separator.add_theme_stylebox_override("separator", _style(Color("35464f"), Color("35464f"), 0, 0))
	separator.custom_minimum_size = Vector2(1, 32)
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return separator

func _style(fill: Color, border: Color, radius: int = 4, padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _outline(color: Color) -> StyleBoxFlat:
	var style := _style(Color.TRANSPARENT, color, 4, 0)
	style.draw_center = false
	style.set_border_width_all(2)
	return style

func _visual_smoke() -> void:
	sound.enabled = false
	var output := ProjectSettings.globalize_path("res://test-output")
	if "--compact" in OS.get_cmdline_user_args():
		output = output.path_join("1000x650")
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("01-battle-ready.png"))
	_send_test_key(KEY_E)
	await get_tree().process_frame
	assert(selected_hero == 1, "keyboard actor selection")
	_send_test_key(KEY_Q)
	_send_test_key(KEY_D)
	await get_tree().process_frame
	assert(selected_hero == 0 and selected_enemy == 1, "keyboard actor and target switching")
	_send_test_key(KEY_A)
	_send_test_key(KEY_1)
	await get_tree().process_frame
	assert(selected_card == 0 and not play_button.disabled, "card selection enables play")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("02-card-selected.png"))
	_send_test_key(KEY_SPACE)
	await get_tree().process_frame
	assert(busy and not demo_running, "space plays selected card without triggering focused demo button")
	var captured_clash := false
	while busy:
		if not captured_clash and not stage.overlay.is_empty() and stage.sparks > 0.4:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("03-clash.png"))
			captured_clash = true
		await get_tree().process_frame
	assert(battle.plays == 1 and battle.hand.size() == 4 and captured_clash, "actual keyboard play and clash animation")
	speed = 12.0
	while battle.outcome.is_empty() and battle.turn < 12:
		await _auto_round()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("04-result.png"))
	assert(battle.outcome == "victory" and result_panel.visible, "victory dialog")
	var won_turn := battle.turn
	new_battle()
	assert(battle.turn == 1 and battle.cost == 9 and not result_panel.visible, "restart after victory")
	for hero in battle.heroes:
		hero.hp = 1
	for enemy in battle.enemies:
		enemy.base = 100
	await _end_turn()
	if battle.outcome.is_empty():
		await _end_turn()
	assert(battle.outcome == "defeat" and result_panel.visible, "defeat dialog")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("05-defeat.png"))
	new_battle()
	assert(battle.outcome.is_empty() and not result_panel.visible, "restart after defeat")
	print("VISUAL_SMOKE_COMPLETE victory_turn=", won_turn, " keyboard=passed defeat=passed restart=passed")
	get_tree().quit()

func _send_test_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
