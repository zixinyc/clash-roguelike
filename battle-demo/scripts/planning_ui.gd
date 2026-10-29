extends Control

const Rules = preload("res://scripts/battle_rules.gd")
const Stage = preload("res://scripts/battle_stage.gd")
const Card = preload("res://scripts/card_view.gd")
const Sound = preload("res://scripts/synth_audio.gd")
var battle := Rules.new()
var stage: DemoBattleStage
var sound: DemoSynthAudio
var header: Label
var clock_label: Label
var hint: Label
var log_label: Label
var hand_row: HBoxContainer
var ready_button: Button
var cancel_button: Button
var assign_button: Button
var auto_button: Button
var restart_button: Button
var hero_picker: OptionButton
var enemy_picker: OptionButton
var cards: Array[DemoCardView] = []
var selected_card := -1
var selected_slot := 0
var selected_target := 0
var busy := false
var speed := 2.0
var last_second := -1

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 16
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1b2c36")
	box.border_color = Color("58717c")
	box.set_border_width_all(1)
	box.set_content_margin_all(9)
	skin.set_stylebox("normal", "Button", box)
	theme = skin
	var bg := ColorRect.new()
	bg.color = Color("0c1720")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	header = label("余烬交锋 / 行动规划", 23)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	clock_label = label("180 秒", 24)
	top.add_child(clock_label)
	restart_button = button("重新开始", new_battle)
	top.add_child(restart_button)
	var fast := button("演出 ×2", func() -> void: speed = 4.0 if speed == 2.0 else 2.0)
	fast.pressed.connect(func() -> void: fast.text = "演出 ×%d" % int(speed))
	top.add_child(fast)
	stage = Stage.new()
	stage.custom_minimum_size.y = 340
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.slot_selected.connect(_slot_selected)
	stage.aim_committed.connect(_aim)
	stage.unit_selected.connect(func(allied: bool, index: int) -> void: _slot_selected(allied, index * 3))
	column.add_child(stage)
	var selectors := HBoxContainer.new()
	column.add_child(selectors)
	hero_picker = OptionButton.new()
	hero_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_picker.item_selected.connect(func(index: int) -> void: _slot_selected(true, index))
	selectors.add_child(hero_picker)
	enemy_picker = OptionButton.new()
	enemy_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_picker.item_selected.connect(func(index: int) -> void: _slot_selected(false, index))
	selectors.add_child(enemy_picker)
	assign_button = button("安排 →", _assign)
	selectors.add_child(assign_button)
	cancel_button = button("撤销此格", _cancel)
	selectors.add_child(cancel_button)
	hint = label("", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 42
	column.add_child(hint)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	column.add_child(hand_row)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	log_label = label("", 14)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(log_label)
	auto_button = button("自动安排", _auto_plan)
	bottom.add_child(auto_button)
	ready_button = button("准备完成 · 开始交锋", _resolve)
	bottom.add_child(ready_button)
	sound = Sound.new()
	add_child(sound)
	new_battle()
	if "--planning-smoke" in OS.get_cmdline_user_args():
		_smoke.call_deferred()

func label(value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	return result

func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	return result

func new_battle() -> void:
	if busy:
		return
	battle.start()
	stage.reset_visuals()
	selected_card = -1
	selected_slot = 0
	selected_target = 0
	last_second = -1
	_refresh(battle.snapshot())
	log_label.text = "敌方已安排好。每人最多两次行动；同速不能替队友接招。"
	ready_button.grab_focus()

func _process(delta: float) -> void:
	if busy or battle.phase != "response":
		return
	var expired := battle.tick(delta)
	var seconds := int(ceil(battle.remaining))
	if seconds != last_second:
		last_second = seconds
		clock_label.text = "%03d 秒" % seconds
	if expired:
		_resolve()

func _refresh(state: Dictionary) -> void:
	stage.set_state(state)
	stage.busy = busy
	stage.active_slot = selected_slot
	stage.target_slot = selected_target
	stage.selected_hero = selected_slot / 3
	stage.selected_enemy = selected_target / 3
	header.text = "余烬交锋   ROUND %02d   cost %d / 预留 %d" % [state.turn, state.cost, state.reserved]
	hero_picker.clear()
	enemy_picker.clear()
	for slot in state.hero_slots:
		hero_picker.add_item("%s · %s · 速度 %d%s" % [state.heroes[slot.unit].name, Rules.CATEGORIES[slot.category], slot.speed, " · " + Rules.SKILLS[slot.key].name if slot.active else " · 空"])
	for slot in state.enemy_slots:
		var detail := "待机"
		if slot.active:
			detail = "已启用" if state.phase == "response" else Rules.SKILLS[slot.key].name
			if slot.category != 2:
				detail += " → " + state.heroes[slot.target].name
		enemy_picker.add_item("%s · %s · 速度 %d · %s" % [state.enemies[slot.unit].name, Rules.CATEGORIES[slot.category], slot.speed, detail])
	hero_picker.select(selected_slot)
	enemy_picker.select(selected_target)
	if cards.is_empty():
		for i in state.hand.size():
			var card := Card.new()
			card.skill = Rules.SKILLS[state.hand[i]]
			card.key_number = i + 1
			card.pressed.connect(_select_card.bind(i))
			hand_row.add_child(card)
			cards.append(card)
	for i in cards.size():
		cards[i].selected = i == selected_card
		cards[i].disabled = busy or state.phase != "response"
		cards[i].modulate.a = 0.45 if state.hero_slots.any(func(s: Dictionary) -> bool: return s.active and s.card == i) else 1.0
		cards[i].queue_redraw()
	for control in [ready_button, cancel_button, assign_button, auto_button, hero_picker, enemy_picker]:
		control.disabled = busy or state.phase != "response"
	restart_button.disabled = busy
	ready_button.text = "我方已准备 · 结算中" if busy else "准备完成 · 开始交锋"
	if state.phase == "response":
		_hint()
	elif not state.outcome.is_empty():
		hint.text = "战斗胜利！点击重新开始。" if state.outcome == "victory" else "小队失利。点击重新开始再试。"

func _hint() -> void:
	var h: Dictionary = battle.hero_slots[selected_slot]
	var e: Dictionary = battle.enemy_slots[selected_target]
	var response := "单方面攻击"
	if e.active and e.category != 2:
		response = "迎击自身受到的攻击" if e.target == h.unit else ("速度更高，可替队友接招" if h.speed > e.speed else "速度不足以接招，双方各自攻击")
	hint.text = "敌方已锁定 · 我方规划中｜%s\n选牌后拖动我方格到敌方格，或点击两格后按「安排」；1–6 选牌，空格安排，Enter 准备。" % response
	if selected_card >= 0:
		hint.text = "%s → %s｜%s\n%s" % [battle.heroes[h.unit].name, Rules.SKILLS[battle.hand[selected_card]].name, response, battle.can_assign(selected_card, selected_slot, selected_target)]

func _slot_selected(allied: bool, index: int) -> void:
	if busy or battle.phase != "response":
		return
	if allied:
		selected_slot = index
	else:
		selected_target = index
	_refresh(battle.snapshot())

func _select_card(index: int) -> void:
	if busy or battle.phase != "response":
		return
	selected_card = index
	selected_slot = (selected_slot / 3) * 3 + battle.category_for(battle.hand[index])
	sound.play_sound("select")
	_refresh(battle.snapshot())

func _aim(source: int, target: int) -> void:
	selected_slot = source
	selected_target = target
	if selected_card < 0 and battle.hero_slots[source].active:
		selected_card = battle.hero_slots[source].card
	_assign()

func _assign() -> void:
	if busy:
		return
	var error := battle.assign(selected_card, selected_slot, selected_target)
	_refresh(battle.snapshot())
	log_label.text = "已安排，可撤销或改目标。" if error.is_empty() else error

func _cancel() -> void:
	if busy:
		return
	battle.cancel(selected_slot)
	_refresh(battle.snapshot())
	log_label.text = "已撤销，预留 cost 已释放。"

func _auto_plan() -> void:
	if busy or battle.phase != "response":
		return
	for slot in battle.hero_slots:
		if slot.active:
			continue
		for card in battle.hand.size():
			var target := 0
			for enemy in battle.enemy_slots:
				if battle.enemies[enemy.unit].hp > 0 and enemy.active and enemy.category != 2:
					target = enemy.id
					if enemy.target == slot.unit:
						break
			if battle.assign(card, slot.id, target).is_empty():
				break
	_refresh(battle.snapshot())
	log_label.text = "已自动安排，仍可修改；点击准备完成开始。"

func _resolve() -> void:
	if busy or battle.phase != "response":
		return
	busy = true
	stage.dragging = -1
	clock_label.text = "双方已准备"
	var events := battle.lock_and_resolve()
	for event in events:
		_refresh(event.snapshot)
		match event.type:
			"reveal":
				log_label.text = "双方锁定，技能揭晓，按速度结算。"
				await get_tree().create_timer(0.8 / speed).timeout
			"intercept":
				log_label.text = "%s 替队友接走攻击！" % battle.heroes[event.hero].name
			"clash":
				sound.play_sound("clash")
				log_label.text = "拼点 %d : %d ｜ 剩余硬币 %d : %d" % [event.left, event.right, event.hero_remaining, event.enemy_remaining]
			"strike":
				sound.play_sound("strike")
			"refund", "stalemate":
				log_label.text = "%s，返还 %d cost" % ["僵持" if event.type == "stalemate" else "拼点失败", event.amount]
			"cancelled":
				log_label.text = event.reason
		await stage.play_event(event, speed)
	busy = false
	stage.reset_visuals()
	selected_card = -1
	if battle.phase == "finished":
		battle.next_round()
		last_second = -1
		log_label.text = "下一回合：敌方已重新安排，速度重新生成，cost +3。"
	_refresh(battle.snapshot())
	if not battle.outcome.is_empty():
		clock_label.text = "战斗结束"
		log_label.text = "胜利" if battle.outcome == "victory" else "失败"
		sound.play_sound(battle.outcome)

func _input(event: InputEvent) -> void:
	if busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6:
		_select_card(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		_assign()
	elif event.keycode == KEY_ENTER:
		_resolve()
	elif event.keycode == KEY_DELETE:
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func _smoke() -> void:
	sound.enabled = false
	DirAccess.make_dir_recursive_absolute("res://test-output")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/planning-ready.png")
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	var source := stage.global_position + stage.slot_position(true, 0) * stage.size / stage.BASE
	var target := stage.global_position + stage.slot_position(false, 0) * stage.size / stage.BASE
	source = get_viewport().get_final_transform() * source
	target = get_viewport().get_final_transform() * target
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source
	Input.parse_input_event(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target
	Input.parse_input_event(release)
	await get_tree().process_frame
	assert(battle.hero_slots[0].active)
	_cancel()
	assert(not battle.hero_slots[0].active)
	_auto_plan()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/planning-arrows.png")
	speed = 50.0
	await _resolve()
	assert(battle.turn == 2 or not battle.outcome.is_empty())
	if battle.outcome.is_empty():
		battle.remaining = 0.01
		await get_tree().create_timer(0.05).timeout
		while busy:
			await get_tree().process_frame
		assert(battle.turn == 3 or not battle.outcome.is_empty())
	for i in 15:
		if not battle.outcome.is_empty():
			break
		_auto_plan()
		await _resolve()
	assert(not battle.outcome.is_empty())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/planning-result.png")
	new_battle()
	assert(battle.turn == 1 and battle.phase == "response")
	print("PLANNING_UI_PASS keyboard mouse_drag assign cancel auto resolve timeout outcome restart")
	get_tree().quit()
