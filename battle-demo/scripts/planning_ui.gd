extends Control

signal setup_requested
var lineup: Array = []
var deck: Variant = null
var exploration_run: RefCounted
var setup_button: Button

const Rules = preload("res://scripts/battle_rules.gd")
const Stage = preload("res://scripts/battle_stage.gd")
const RoleHand = preload("res://scripts/role_hand.gd")
const Sound = preload("res://scripts/synth_audio.gd")
var battle := Rules.new()
var stage: DemoBattleStage
var sound: DemoSynthAudio
var header: Label
var clock_label: Label
var hint: Label
var log_label: Label
var hand_view: RoleHand
var ready_button: Button
var cancel_button: Button
var assign_button: Button
var auto_button: Button
var restart_button: Button
var hero_picker: OptionButton
var enemy_picker: OptionButton
var selected_card := -1
var selected_slot := 0
var selected_target := 0
var encounter := 0
var encounter_button: Button
var team_button: Button
var touhou_team := false
var zixi_button: Button
var zixi_team := false
var zixingyc_button: Button
var zixingyc_team := false
var enhance_selected := false
var busy := false
var speed := 1.0
var last_second := -1
var ally_status: Label
var enemy_status: Label
var guide: Label
var item_button: Button
var friendly_button: Button
var friendly_panel: PanelContainer
var friendly_picker: OptionButton
var friendly_detail: Label
var friendly_confirm: Button
var item_popup: PanelContainer
var item_close_button: Button
var item_rows: VBoxContainer
var item_feedback: Label
var forecast_panel: PanelContainer
var forecast_title: Label
var forecast_detail: Label
var forecast_tip: Label

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
	encounter_button = button("", _switch_encounter)
	top.add_child(encounter_button)
	team_button = button("测试阵容", _switch_team)
	top.add_child(team_button)
	zixi_button = button("ZiXi", _switch_zixi)
	top.add_child(zixi_button)
	zixingyc_button = button("ZiXingYC", _switch_zixingyc)
	top.add_child(zixingyc_button)
	if not lineup.is_empty():
		for control in [encounter_button, team_button, zixi_button, zixingyc_button]:
			control.hide()
		setup_button = button("阵容与卡组", func() -> void: setup_requested.emit())
		top.add_child(setup_button)
	restart_button = button("重新开始", new_battle)
	top.add_child(restart_button)
	var fast := button("演出 ×1", func() -> void: speed = 1.0 if speed >= 4.0 else speed * 2.0)
	fast.pressed.connect(func() -> void: fast.text = "演出 ×%d" % int(speed))
	top.add_child(fast)
	_build_item_popup(top)
	var statuses := HBoxContainer.new()
	statuses.add_theme_constant_override("separation", 12)
	column.add_child(statuses)
	ally_status = _status_panel(statuses, Color("80d6df"))
	enemy_status = _status_panel(statuses, Color("ee9b8b"))
	stage = Stage.new()
	stage.custom_minimum_size.y = 280
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.slot_selected.connect(_slot_selected)
	stage.aim_committed.connect(_aim)
	stage.aim_cancelled.connect(func() -> void: log_label.text = "未安排：请将行动格拖到敌方上方的攻／大／防小格，再松开。")
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
	friendly_button = button("攻击队友…", _open_friendly_target)
	friendly_button.add_theme_color_override("font_color", Color("ffafa4"))
	selectors.add_child(friendly_button)
	_build_friendly_panel()
	assign_button = button("安排 →", _assign)
	selectors.add_child(assign_button)
	cancel_button = button("撤销此格", _cancel)
	selectors.add_child(cancel_button)
	forecast_panel = PanelContainer.new()
	var f_style := StyleBoxFlat.new()
	f_style.bg_color = Color(0.06, 0.09, 0.12, 0.94)
	f_style.border_color = Color("415461")
	f_style.set_border_width_all(1)
	f_style.set_corner_radius_all(4)
	f_style.set_content_margin_all(8)
	forecast_panel.add_theme_stylebox_override("panel", f_style)
	forecast_panel.custom_minimum_size = Vector2(0, 52)
	var f_box := VBoxContainer.new()
	f_box.add_theme_constant_override("separation", 2)
	forecast_panel.add_child(f_box)
	forecast_title = label("【战局态势预判】", 15)
	forecast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f_box.add_child(forecast_title)
	forecast_detail = label("", 14)
	forecast_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forecast_detail.add_theme_color_override("font_color", Color("dbe6eb"))
	f_box.add_child(forecast_detail)
	forecast_tip = label("", 12)
	forecast_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forecast_tip.add_theme_color_override("font_color", Color("9eb0b7"))
	f_box.add_child(forecast_tip)
	column.add_child(forecast_panel)
	forecast_panel.hide()
	guide = label("", 15)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_color_override("font_color", Color("e6c888"))
	column.add_child(guide)
	var action_center := CenterContainer.new()
	column.add_child(action_center)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	action_center.add_child(actions)
	auto_button = button("自动安排", _auto_plan)
	auto_button.custom_minimum_size = Vector2(180, 46)
	actions.add_child(auto_button)
	ready_button = button("准备交锋  ·  Enter", _resolve)
	ready_button.custom_minimum_size = Vector2(260, 46)
	var ready_style := StyleBoxFlat.new()
	ready_style.bg_color = Color("d9bb82")
	ready_style.set_content_margin_all(10)
	ready_style.set_corner_radius_all(4)
	ready_button.add_theme_stylebox_override("normal", ready_style)
	ready_button.add_theme_color_override("font_color", Color("15232b"))
	ready_button.add_theme_color_override("font_focus_color", Color("15232b"))
	actions.add_child(ready_button)
	hand_view = RoleHand.new()
	hand_view.hero_selected.connect(func(unit: int) -> void: _slot_selected(true, unit * 3))
	hand_view.group_changed.connect(func() -> void:
		selected_card = -1
		enhance_selected = false
		_refresh(battle.snapshot()))
	hand_view.enhancement_changed.connect(func(enabled: bool) -> void:
		enhance_selected = enabled
		_refresh(battle.snapshot()))
	hand_view.card_selected.connect(_select_card)
	column.add_child(hand_view)
	hint = hand_view.detail
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	log_label = label("", 14)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(log_label)
	sound = Sound.new()
	add_child(sound)
	stage.impact_sound.connect(sound.play_sound)
	new_battle()
	if "--planning-smoke" in OS.get_cmdline_user_args():
		_smoke.call_deferred()

func label(value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	return result

func _status_panel(parent: HBoxContainer, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.85)
	style.border_color = accent
	style.border_width_left = 4
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var text_label := label("", 20)
	text_label.add_theme_color_override("font_color", accent)
	panel.add_child(text_label)
	return text_label

func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	return result

func _switch_encounter() -> void:
	if busy:
		return
	encounter = (encounter + 1) % Rules.ENCOUNTER_NAMES.size()
	new_battle()

func _switch_team() -> void:
	if busy:
		return
	touhou_team = not touhou_team
	zixi_team = false
	zixingyc_team = false
	new_battle()

func _switch_zixi() -> void:
	if busy:
		return
	zixi_team = not zixi_team
	touhou_team = false
	zixingyc_team = false
	new_battle()

func _switch_zixingyc() -> void:
	if busy:
		return
	zixingyc_team = not zixingyc_team
	touhou_team = false
	zixi_team = false
	new_battle()

func _build_item_popup(top: HBoxContainer) -> void:
	item_button = button("道具 0", _open_items)
	item_button.tooltip_text = "在行动规划期间查看和使用消耗道具"
	top.add_child(item_button)
	item_popup = PanelContainer.new()
	item_popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	item_popup.offset_left = -394
	item_popup.offset_right = -18
	item_popup.offset_top = 66
	item_popup.offset_bottom = 66
	item_popup.hide()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("13232d")
	panel.border_color = Color("9bc5c9")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	item_popup.add_theme_stylebox_override("panel", panel)
	add_child(item_popup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	item_popup.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var title := label("消耗道具", 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("a7e1e2"))
	heading.add_child(title)
	item_close_button = button("关闭", _close_items)
	heading.add_child(item_close_button)
	item_rows = VBoxContainer.new()
	item_rows.add_theme_constant_override("separation", 8)
	body.add_child(item_rows)
	item_feedback = label("", 15)
	item_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(item_feedback)

func _open_items() -> void:
	if item_popup.visible:
		_close_items()
		return
	if busy or battle.phase != "response":
		return
	item_feedback.text = "选用道具后立即生效，准备交锋前可以继续安排行动。"
	_refresh_items()
	item_popup.show()
	item_close_button.grab_focus()

func _close_items() -> void:
	item_popup.hide()
	item_button.grab_focus()

func _refresh_items() -> void:
	for child in item_rows.get_children():
		item_rows.remove_child(child)
		child.queue_free()
	if battle.active_items.is_empty():
		item_rows.add_child(label("当前没有消耗道具。可在废林商店购买。", 15))
		return
	var quantities := {}
	for key in battle.active_items:
		quantities[key] = int(quantities.get(key, 0)) + 1
	for key in quantities:
		var info := RelicSystem.get_consumable(key)
		var row := HBoxContainer.new()
		item_rows.add_child(row)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		detail.add_child(label("%s ×%d" % [info.get("name", key), quantities[key]], 16))
		var description := label(info.get("description", ""), 16)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(description)
		var error := battle.item_error(key)
		var use_button := button("使用", _use_battle_item.bind(key))
		use_button.disabled = not error.is_empty()
		use_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(use_button)
		if not error.is_empty():
			detail.add_child(label(error, 13))

func _use_battle_item(key: String) -> void:
	if busy:
		return
	var result := battle.use_item(key)
	item_feedback.text = result.message
	log_label.text = result.message
	_refresh(battle.snapshot())
	_refresh_items()
	item_close_button.grab_focus()

func new_battle() -> void:
	if busy:
		return
	item_popup.hide()
	friendly_panel.hide()
	if exploration_run == null:
		battle.start(73129, encounter, touhou_team, zixi_team, lineup, deck, zixingyc_team, [], [], {"enabled": true})
	else:
		battle.start(randi(), encounter, false, false, lineup, deck, false, exploration_run.relics, exploration_run.items, exploration_run.get_evolution_config())
		battle.cost = exploration_run.carried_cost
		for i in battle.heroes.size():
			battle.heroes[i].hp = exploration_run.party_hp[i]
			battle.heroes[i].max_hp = exploration_run.party_max_hp[i]
		for slot in battle.enemy_slots:
			if slot.active and slot.category != 2:
				slot.target = battle._living_target(slot.target)
	if encounter >= 0 and encounter < Rules.ENCOUNTER_NAMES.size():
		encounter_button.text = "敌组：%s（重开）" % Rules.ENCOUNTER_NAMES[encounter]
	team_button.text = "原阵容" if touhou_team else "测试阵容"
	zixi_button.text = "原阵容" if zixi_team else "ZiXi"
	zixingyc_button.text = "原阵容" if zixingyc_team else "ZiXingYC"
	stage.prepare_portraits(battle.heroes, battle.enemies)
	stage.reset_visuals()
	selected_card = -1
	enhance_selected = false
	selected_slot = 3 if (zixi_team or zixingyc_team) and lineup.is_empty() else 0
	selected_target = 0
	if zixi_team or zixingyc_team:
		for slot in battle.enemy_slots:
			if slot.active and slot.category != 2 and slot.target == 1:
				selected_target = slot.id
				break
	hand_view.show_shared = false
	last_second = -1
	_refresh(battle.snapshot())
	log_label.text = "每组三格可安排两次行动；少人时下一回合补格。"
	if not battle.active_items.is_empty():
		log_label.text += " 消耗品请点右上角「道具」。"
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

func _build_friendly_panel() -> void:
	friendly_panel = PanelContainer.new()
	friendly_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	friendly_panel.offset_left = -498
	friendly_panel.offset_right = -18
	friendly_panel.offset_top = 92
	friendly_panel.offset_bottom = 92
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("22232d")
	skin.border_color = Color("b97070")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(8)
	skin.set_content_margin_all(16)
	friendly_panel.add_theme_stylebox_override("panel", skin)
	add_child(friendly_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	friendly_panel.add_child(body)
	var title := label("攻击队友", 21)
	title.add_theme_color_override("font_color", Color("ffafa4"))
	body.add_child(title)
	friendly_picker = OptionButton.new()
	friendly_picker.item_selected.connect(func(_index: int) -> void: _refresh_friendly_target())
	body.add_child(friendly_picker)
	friendly_detail = label("", 16)
	friendly_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(friendly_detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	actions.add_child(button("返回选敌", _close_friendly_target))
	friendly_confirm = button("确认安排 · 队友可能退场", _confirm_friendly_target)
	friendly_confirm.add_theme_color_override("font_color", Color("ffafa4"))
	friendly_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(friendly_confirm)
	friendly_panel.hide()

func _open_friendly_target() -> void:
	if busy or selected_card < 0 or battle.phase != "response":
		return
	var key: String = battle.hand[selected_card]
	if not Rules.SKILLS[key].get("can_target_ally", false):
		return
	item_popup.hide()
	var source: int = battle.hero_slots[selected_slot].unit
	friendly_picker.clear()
	friendly_picker.add_item("选择一名队友")
	for i in battle.heroes.size():
		var hero: Dictionary = battle.heroes[i]
		if i != source and hero.hp > 0:
			friendly_picker.add_item("%s  ·  %d/%d HP  ·  %d 护盾" % [hero.name, hero.hp, hero.max_hp, hero.shield], i)
	friendly_picker.select(0)
	_refresh_friendly_target()
	friendly_panel.show()
	friendly_picker.grab_focus()

func _refresh_friendly_target() -> void:
	friendly_confirm.disabled = true
	if selected_card < 0 or friendly_picker.selected <= 0:
		friendly_detail.text = "请选择目标。友军行动按速度结算，退场后会失去尚未执行的行动。"
		return
	var target := friendly_picker.get_selected_id()
	var error := battle.can_assign(selected_card, selected_slot, target, false, true)
	if not error.is_empty():
		friendly_detail.text = error
		return
	var key: String = battle.hand[selected_card]
	var execute := Rules.ZiWu.can_execute_ally(key, battle.heroes[target])
	var warning := "当前生命 ≤15。结算时仍满足条件，则无视护盾使其退场。" if execute else "会伤害这名队友，可能使其退场。"
	if key == Rules.ZiWu.BACKSTAB and not execute:
		warning = "生命 ≤15 才会斩杀。结算时高于该阈值，则按普通伤害结算。"
	friendly_detail.text = "%s · %s\n击倒后绝缘 +2、恢复最多 5 HP；每回合首次击倒返 3 cost。%s" % [
		Rules.SKILLS[key].name, warning, " 背刺击倒另得 5 护盾。" if key == Rules.ZiWu.BACKSTAB else "",
	]
	friendly_confirm.disabled = false

func _close_friendly_target() -> void:
	friendly_panel.hide()
	if friendly_button.visible and not friendly_button.disabled:
		friendly_button.grab_focus()

func _confirm_friendly_target() -> void:
	if not friendly_panel.visible or friendly_confirm.disabled or friendly_picker.selected <= 0:
		return
	var target := friendly_picker.get_selected_id()
	var error := battle.assign(selected_card, selected_slot, target, false, true)
	if not error.is_empty():
		_refresh_friendly_target()
		return
	_close_friendly_target()
	_refresh(battle.snapshot())
	log_label.text = "已安排攻击队友 %s。准备交锋前仍可撤销或改回敌方目标。" % battle.heroes[target].name

func _target_guidance(target: int) -> Dictionary:
	if selected_card < 0 or not Rules.targets_enemy(battle.hand[selected_card]):
		return {}
	var hero: Dictionary = battle.hero_slots[selected_slot]
	var enemy: Dictionary = battle.enemy_slots[target]
	var error := battle.can_assign(selected_card, selected_slot, target, enhance_selected)
	if error == "这张牌需要与敌方拼点":
		if not enemy.active:
			error = "敌方行动格未启用，不能拼点"
		elif enemy.category == 2:
			error = "敌方防御格不能与此牌拼点"
		else:
			error = "拦截队友需要速度更高：我方 %d，敌方 %d" % [hero.speed, enemy.speed]
	if not error.is_empty():
		return {"valid": false, "text": error}
	if battle.can_clash(hero, enemy):
		return {"valid": true, "text": "可迎击自身攻击" if enemy.target == hero.unit else "可拦截队友受到的攻击"}
	if not enemy.active:
		return {"valid": true, "text": "空槽 · 可单方面攻击"}
	if enemy.category == 2:
		return {"valid": true, "text": "防御格 · 可单方面攻击"}
	return {"valid": true, "text": "可单方面攻击 · 对方原行动照常"}

func _refresh(state: Dictionary) -> void:
	stage.target_guidance.clear()
	if not busy and state.phase == "response" and selected_card >= 0:
		for target in battle.enemy_slots.size():
			stage.target_guidance.append(_target_guidance(target))
	stage.set_state(state)
	stage.busy = busy
	stage.active_slot = selected_slot
	stage.target_slot = selected_target
	stage.selected_hero = state.hero_slots[selected_slot].unit
	stage.selected_enemy = selected_target / 3
	header.text = "余烬交锋   ROUND %02d   cost %d / 预留 %d" % [state.turn, state.cost, state.reserved]
	_refresh_slot_pickers(state)
	hand_view.refresh(state, stage.selected_hero, selected_card, not busy and state.phase == "response", selected_slot, enhance_selected)
	for control in [ready_button, cancel_button, assign_button, auto_button, hero_picker, enemy_picker]:
		control.disabled = busy or state.phase != "response"
	var selected_key: String = battle.hand[selected_card] if selected_card >= 0 else ""
	friendly_button.visible = not selected_key.is_empty() and Rules.SKILLS[selected_key].get("can_target_ally", false)
	friendly_button.disabled = busy or state.phase != "response" or Rules.ZiWu.living_teammates(battle.heroes, stage.selected_hero) == 0
	friendly_button.tooltip_text = "需要一名存活队友" if friendly_button.disabled else "手动选择友军目标 · 可能使队友退场"
	restart_button.disabled = busy
	encounter_button.disabled = busy
	team_button.disabled = busy
	zixi_button.disabled = busy
	zixingyc_button.disabled = busy
	item_button.text = "道具 %d" % battle.active_items.size()
	item_button.disabled = busy or state.phase != "response"
	item_button.add_theme_color_override("font_color", Color("a7e1e2") if not battle.active_items.is_empty() else Color("d3e0e4"))
	if setup_button != null:
		setup_button.disabled = busy
	ready_button.text = "交锋进行中" if busy else "准备交锋  ·  Enter"
	var count := 0
	for slot in state.hero_slots:
		if slot.active:
			count += 1
	ally_status.text = "我方  ·  规划中    已安排 %d 次行动" % count
	enemy_status.text = "敌方  ·  已锁定    目标公开 / 技能隐藏"
	guide.text = "选牌后：绿色框可安排；灰色框不可用。鼠标停在敌方格可查看原因。"
	if count > 0:
		guide.text = "已安排 %d 次行动 · 可继续选牌或撤销调整；安排完毕点击「准备交锋」" % count
	if state.hero_slots.any(func(slot: Dictionary) -> bool: return slot.get("flexible", false)):
		enemy_status.text = "敌方  ·  时间停止"
		guide.text = "本回合只有咲夜能行动，可以在三个技能槽安排任意类别的牌"
	if busy:
		ally_status.text = "我方  ·  已准备    交锋中"
		enemy_status.text = "敌方  ·  已准备    技能已揭晓"
		guide.text = "双方已锁定，按速度依次交锋，请等待本回合结束。"
	if not state.outcome.is_empty():
		ally_status.text = "我方  ·  胜利" if state.outcome == "victory" else "我方  ·  败北"
		enemy_status.text = "敌方  ·  已击败" if state.outcome == "victory" else "敌方  ·  获胜"
		guide.text = "战斗结束 · 点击右上角「重新开始」再试一次。"
	if state.phase == "response" and not busy:
		_hint()
		_update_forecast()
	elif not state.outcome.is_empty():
		if forecast_panel != null:
			forecast_panel.hide()
		hint.text = "战斗胜利！点击重新开始。" if state.outcome == "victory" else "小队失利。点击重新开始再试。"
	else:
		if forecast_panel != null:
			forecast_panel.hide()
		hint.text = "交锋中，行动按速度结算。"

func _refresh_slot_pickers(state: Dictionary) -> void:
	if hero_picker.item_count != state.hero_slots.size():
		hero_picker.clear()
	if enemy_picker.item_count != state.enemy_slots.size():
		enemy_picker.clear()
	for slot in state.hero_slots:
		var hero: Dictionary = state.heroes[slot.unit]
		var category: String = "技能" if slot.get("flexible", false) else Rules.CATEGORIES[slot.category]
		if slot.has("row"):
			category += " · 增援 %d" % slot.row
		var action: String = " · " + Rules.SKILLS[slot.key].name if slot.active else " · 空"
		if slot.get("enhanced", false):
			action += "（强化）"
		if slot.has("ally_target"):
			action += " → 队友 %s" % state.heroes[slot.ally_target].name
		if slot.get("frozen", false):
			action = " · 停时"
		_set_picker_item(hero_picker, slot.id, "%s(%s) · %s · 速度 %d%s" % [hero.name, hero.role, category, slot.speed, action])
	for slot in state.enemy_slots:
		var detail := "计划隐藏" if state.get("pvp", false) and state.phase == "response" else "待机"
		if slot.active:
			detail = "已启用" if state.phase == "response" else Rules.SKILLS[slot.key].name
			if slot.category != 2:
				detail += " → " + state.heroes[slot.target].name
		_set_picker_item(enemy_picker, slot.id, "%s · %s · 速度 %d · %s" % [state.enemies[slot.unit].name, Rules.CATEGORIES[slot.category], slot.speed, detail])
	hero_picker.select(selected_slot)
	enemy_picker.select(selected_target)

func _set_picker_item(picker: OptionButton, index: int, label: String) -> void:
	if index == picker.item_count:
		picker.add_item(label)
	elif picker.get_item_text(index) != label:
		picker.set_item_text(index, label)

func _hint() -> void:
	var h: Dictionary = battle.hero_slots[selected_slot]
	if battle.heroes[h.unit].hp <= 0:
		hint.text = "该成员已退场。请选择存活队员。"
		return
	if h.get("frozen", false):
		hint.text = "时间停止，本回合只有咲夜可以行动"
		return
	if selected_card < 0:
		hint.text = "选择一张牌查看效果。数字键对应当前手牌的编号。"
		return
	var card := hand_view.cards[selected_card]
	if not Rules.targets_enemy(card.skill_key):
		var error := battle.can_assign(selected_card, selected_slot, selected_target, enhance_selected)
		var detail := card.effect_text() if error.is_empty() else error
		hint.text = "%s · %s" % [card.skill.name, detail]
		return
	var target_info := _target_guidance(selected_target)
	var friendly_hint := "｜可单独选择「攻击队友…」" if friendly_button.visible and not friendly_button.disabled else ""
	if not target_info.valid:
		hint.text = "%s · %s%s" % [card.skill.name, target_info.text, friendly_hint]
		return
	var effect := card.effect_text()
	if enhance_selected:
		effect = "%s · %s" % [card.skill.enhance_name, card.skill.enhance_description]
	elif card.skill_key == Rules.ZiWu.LONE_INTERCEPT:
		var error := Rules.ZiWu.enhancement_error(battle.heroes[h.unit], selected_slot, card.skill_key)
		effect += "｜可选绝影突袭" if error.is_empty() else "｜%s" % error
	hint.text = "%s · %s｜%d 枚硬币，每个正面 +%d｜%s%s%s" % [card.skill.name, effect, card.skill.coins, card.skill.power, target_info.text, _archive_note(), friendly_hint]

# ZiXingYC 的符卡自带整理配方，选牌提示显示配方与当前材料是否充足。
func _archive_note() -> String:
	if selected_card < 0:
		return ""
	var h: Dictionary = battle.hero_slots[selected_slot]
	var hero: Dictionary = battle.heroes[h.unit]
	if not hero.has("memory_log"):
		return ""
	var skill: Dictionary = Rules.SKILLS[battle.hand[selected_card]]
	var note := Rules.ZiXingYC.archive_hint(hero, skill.get("archive_corpus", ""))
	return "｜%s" % note if not note.is_empty() else ""

func _update_forecast() -> void:
	if forecast_panel == null:
		return
	if busy or battle == null or battle.phase != "response":
		forecast_panel.hide()
		return
	if selected_slot < 0 or selected_slot >= battle.hero_slots.size():
		forecast_panel.hide()
		return
	var hero_slot: Dictionary = battle.hero_slots[selected_slot]
	var hero: Dictionary = battle.heroes[hero_slot.unit]
	if hero.hp <= 0:
		forecast_panel.hide()
		return
	if selected_target < 0 or selected_target >= battle.enemy_slots.size():
		forecast_panel.hide()
		return
	var enemy_slot: Dictionary = battle.enemy_slots[selected_target]
	var enemy: Dictionary = battle.enemies[enemy_slot.unit]
	
	var card_key := ""
	if selected_card >= 0 and selected_card < battle.hand.size():
		card_key = battle.hand[selected_card]
	elif hero_slot.active:
		card_key = hero_slot.key
		
	if card_key.is_empty() or not Rules.targets_enemy(card_key):
		forecast_panel.hide()
		return
		
	forecast_panel.show()
	var skill: Dictionary = Rules.SKILLS.get(card_key, {})
	var hero_base: int = skill.get("base", skill.get("power", 0))
	var hero_coins: int = skill.get("coins", 1)
	var hero_coin_val: int = skill.get("power", 2)
	if battle.deck_enchants.get(card_key, "") == "rune_impact":
		hero_base += 1
	var hero_min: int = hero_base
	var hero_max: int = hero_base + hero_coins * hero_coin_val
	var hero_avg: float = float(hero_base) + float(hero_coins * hero_coin_val) * 0.5
	
	var can_clash: bool = battle.can_clash(hero_slot, enemy_slot)
	if can_clash:
		var is_intercept: bool = int(enemy_slot.target) != int(hero_slot.unit)
		var clash_title := "【战术截击】" if is_intercept else "【正面对决】"
		
		var enemy_key: String = enemy_slot.get("key", "")
		var enemy_min: int = 3
		var enemy_max: int = 7
		var enemy_avg: float = 5.0
		var enemy_skill_name: String = "敌方攻击"
		if not enemy_key.is_empty() and Rules.SKILLS.has(enemy_key):
			var eskill: Dictionary = Rules.SKILLS[enemy_key]
			enemy_skill_name = eskill.name
			var e_base: int = eskill.get("base", eskill.get("power", 0))
			enemy_min = e_base
			enemy_max = e_base + eskill.get("coins", 1) * eskill.get("power", 2)
			enemy_avg = float(e_base) + float(eskill.get("coins", 1) * eskill.get("power", 2)) * 0.5
		elif enemy_slot.category == 1:
			enemy_min = 5; enemy_max = 10; enemy_avg = 7.5; enemy_skill_name = "强力技能"
		elif enemy_slot.category == 0:
			enemy_min = 3; enemy_max = 6; enemy_avg = 4.5; enemy_skill_name = "普通攻击"
			
		var diff: float = hero_avg - enemy_avg
		var status_text := ""
		var status_color := Color("8cd68c")
		if hero_min >= enemy_max:
			status_text = "必胜优势"
			status_color = Color("55ff88")
		elif diff >= 2.0:
			status_text = "明显优势"
			status_color = Color("8cd68c")
		elif diff <= -2.0:
			status_text = "极度劣势"
			status_color = Color("ff6666")
		elif hero_max <= enemy_min:
			status_text = "必败绝境"
			status_color = Color("ff3333")
		else:
			status_text = "势均力敌"
			status_color = Color("eedd66")
			
		forecast_title.text = "%s · %s" % [clash_title, status_text]
		forecast_title.add_theme_color_override("font_color", status_color)
		forecast_detail.text = "我方「%s」速%d [%d~%d]  VS  %s「%s」速%d [%d~%d]" % [
			skill.get("name", card_key), hero_slot.speed, hero_min, hero_max,
			enemy.name, enemy_skill_name, enemy_slot.speed, enemy_min, enemy_max
		]
		if is_intercept:
			forecast_tip.text = "我方速度 (%d) > 敌方 (%d)，成功截下原攻向队友的攻击！" % [hero_slot.speed, enemy_slot.speed]
		else:
			forecast_tip.text = "双方互相锁定进行正面拼点，正面硬币多者胜出并造成全额伤害！"
	else:
		if not enemy_slot.active:
			forecast_title.text = "【单向攻击】必定全额命中"
			forecast_title.add_theme_color_override("font_color", Color("77d0ff"))
			forecast_detail.text = "我方「%s」速%d [%d~%d]  →  %s (行动格未启用)" % [
				skill.get("name", card_key), hero_slot.speed, hero_min, hero_max, enemy.name
			]
			forecast_tip.text = "敌方此槽位未安排行动，我方攻击必定直接命中！"
		elif enemy_slot.category == 2:
			forecast_title.text = "【削减护盾】单向破盾打击"
			forecast_title.add_theme_color_override("font_color", Color("88bbee"))
			forecast_detail.text = "我方「%s」速%d [%d~%d]  →  %s (防御格)" % [
				skill.get("name", card_key), hero_slot.speed, hero_min, hero_max, enemy.name
			]
			forecast_tip.text = "敌方采取防御姿态，攻击伤害将优先消耗其护盾。"
		else:
			forecast_title.text = "【错位攻击】无法截击"
			forecast_title.add_theme_color_override("font_color", Color("ffaa55"))
			forecast_detail.text = "我方「%s」速%d  VS  %s「敌方攻击」速%d" % [
				skill.get("name", card_key), hero_slot.speed, enemy.name, enemy_slot.speed
			]
			forecast_tip.text = "我方速度 (%d) ≤ 敌方速度 (%d)，无法截击队友受到的攻击，双方将各自按速度单向结算！" % [hero_slot.speed, enemy_slot.speed]

func _change_slot(index: int) -> void:
	if battle.hero_slots[index].unit != battle.hero_slots[selected_slot].unit:
		hand_view.show_shared = false
		selected_card = -1
	elif selected_card >= 0 and not battle.hero_slots[index].get("flexible", false) and battle.category_for(battle.hand[selected_card]) != battle.hero_slots[index].category:
		selected_card = -1
	if selected_card < 0:
		enhance_selected = false
	selected_slot = index

func _slot_selected(allied: bool, index: int) -> void:
	if busy or battle.phase != "response":
		return
	friendly_panel.hide()
	var had_card := selected_card >= 0
	if allied:
		_change_slot(index)
	else:
		selected_target = index
	_refresh(battle.snapshot())
	if allied and had_card and selected_card < 0:
		log_label.text = "已切换角色或行动格类别，请重新选择该角色可用的牌。"

func _select_card(index: int) -> void:
	if busy or battle.phase != "response" or not hand_view.visible_indices.has(index):
		return
	friendly_panel.hide()
	var slot_now: Dictionary = battle.hero_slots[selected_slot]
	if battle.heroes[slot_now.unit].hp <= 0:
		return
	selected_card = index
	if not battle.hero_slots[selected_slot].get("flexible", false):
		selected_slot += battle.category_for(battle.hand[index]) - int(slot_now.category)
	var slot := battle.hero_slots[selected_slot]
	enhance_selected = slot.card == index and slot.get("enhanced", false)
	sound.play_sound("select")
	_refresh(battle.snapshot())

func _aim(source: int, target: int) -> void:
	_change_slot(source)
	selected_target = target
	if selected_card < 0 and battle.hero_slots[source].active:
		selected_card = battle.hero_slots[source].card
		enhance_selected = battle.hero_slots[source].get("enhanced", false)
		hand_view.show_shared = Rules.card_owner(battle.hand[selected_card]) < 0
	_assign()

func _assign() -> void:
	if busy:
		return
	var error := battle.assign(selected_card, selected_slot, selected_target, enhance_selected)
	_refresh(battle.snapshot())
	log_label.text = "已安排，可撤销或改目标。" if error.is_empty() else error

func _cancel() -> void:
	if busy:
		return
	battle.cancel(selected_slot)
	enhance_selected = false
	_refresh(battle.snapshot())
	log_label.text = "已撤销，预留 cost 已释放。"

func _auto_plan() -> void:
	if busy or battle.phase != "response":
		return
	var covered := {}
	for slot in battle.hero_slots:
		if slot.active and slot.get("targeted", Rules.targets_enemy(slot.key)) and battle.can_clash(slot, battle.enemy_slots[slot.target]):
			covered[slot.target] = true
	var slots: Array[Dictionary] = battle.hero_slots.duplicate()
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _auto_slot_order(a) < _auto_slot_order(b))
	for slot in slots:
		if slot.active:
			continue
		var own_targets: Array[int] = []
		var intercepts: Array[int] = []
		var remaining_targets: Array[int] = []
		for enemy in battle.enemy_slots:
			if battle.enemies[enemy.unit].hp <= 0:
				continue
			if covered.has(enemy.id) or not battle.can_clash(slot, enemy):
				remaining_targets.append(enemy.id)
			elif enemy.target == slot.unit:
				own_targets.append(enemy.id)
			else:
				intercepts.append(enemy.id)
		if battle.heroes[slot.unit].character_id == Rules.ZIWU_ID:
			own_targets.sort_custom(func(a: int, b: int) -> bool: return battle.enemy_slots[a].category > battle.enemy_slots[b].category)
			intercepts.sort_custom(func(a: int, b: int) -> bool: return battle.enemy_slots[a].category > battle.enemy_slots[b].category)
		var targets := own_targets + intercepts + remaining_targets
		for card in _card_order(slot.unit):
			var key: String = battle.hand[card]
			if Rules.targets_enemy(key):
				var hero: Dictionary = battle.heroes[slot.unit]
				var card_targets := targets
				if key == Rules.ZiXingYC.RESIDUAL and not hero.organized_this_round:
					card_targets = targets.filter(func(id: int) -> bool: return not battle.enemy_slots[id].active)
					card_targets += targets.filter(func(id: int) -> bool: return battle.enemy_slots[id].active)
				for target in card_targets:
					var clashes := battle.can_clash(slot, battle.enemy_slots[target])
					if covered.has(target) and (clashes or Rules.SKILLS[key].get("requires_clash", false)):
						continue
					var enhance := false
					if key in Rules.ZiXi.CARDS and clashes:
						var is_finisher := key == Rules.ZiXi.ALMOST_SURE
						var full_causality: bool = hero.causality == Rules.ZiXi.CAUSALITY_MAX
						enhance = is_finisher == full_causality and Rules.ZiXi.enhancement_error(hero, slot.id).is_empty()
					elif key == Rules.ZiWu.LONE_INTERCEPT and clashes:
						enhance = Rules.ZiWu.enhancement_error(hero, slot.id, key).is_empty()
					var error := battle.assign(card, slot.id, target, enhance)
					if enhance and key == Rules.ZiWu.LONE_INTERCEPT and not error.is_empty():
						error = battle.assign(card, slot.id, target)
					if error.is_empty():
						if clashes:
							covered[target] = true
						break
			else:
				battle.assign(card, slot.id, -1)
			if slot.active:
				break
	_refresh(battle.snapshot())
	log_label.text = "已自动安排，仍可修改；点击准备完成开始。"

func _auto_slot_order(slot: Dictionary) -> int:
	var hero: Dictionary = battle.heroes[slot.unit]
	var priority := 2
	if hero.character_id == Rules.ZIXI_ID:
		var finisher: bool = hero.causality == Rules.ZiXi.CAUSALITY_MAX and hero.metaphysics >= Rules.ZiXi.ENHANCE_COST
		if slot.category == (1 if finisher else 0):
			priority = 0
	elif hero.character_id == Rules.ZIXINGYC_ID and slot.category != 1:
		priority = slot.category / 2
	elif hero.character_id == Rules.ZIWU_ID:
		var teammates := Rules.ZiWu.living_teammates(battle.heroes, slot.unit)
		var burst: bool = hero.hp > 5 and Rules.ZiWu.ultimate_error(hero, teammates).is_empty()
		if slot.category == (1 if burst else 0):
			priority = 0
	return priority * battle.hero_slots.size() + slot.id

func _card_order(unit: int) -> Array:
	var hero: Dictionary = battle.heroes[unit]
	var owner_id := int(hero.character_id)
	var order: Array = []
	if owner_id == Rules.ZIXINGYC_ID:
		var preferred := battle.hand.find(Rules.ZiXingYC.preferred_attack(hero))
		if preferred >= 0:
			order.append(preferred)
	elif owner_id == Rules.ZIWU_ID:
		var attack_order := [Rules.ZiWu.BACKSTAB, Rules.ZiWu.LONE_INTERCEPT]
		if hero.insulation >= Rules.ZiWu.ENHANCE_COST:
			attack_order.reverse()
		for key in attack_order:
			var i := battle.hand.find(key)
			if i >= 0:
				order.append(i)
	for card in battle.hand.size():
		if Rules.card_owner(battle.hand[card]) == owner_id and not order.has(card):
			order.append(card)
	for card in battle.hand.size():
		if Rules.card_owner(battle.hand[card]) < 0:
			order.append(card)
	return order

func _resolve() -> void:
	if busy or battle.phase != "response":
		return
	busy = true
	item_popup.hide()
	friendly_panel.hide()
	stage.dragging = -1
	clock_label.text = "双方已准备"
	var events := battle.lock_and_resolve()
	await _play_events(events)
	busy = false
	stage.reset_visuals()
	selected_card = -1
	enhance_selected = false
	if battle.phase == "finished":
		var previous_slots := battle.hero_slots.size()
		battle.next_round()
		if selected_slot >= battle.hero_slots.size():
			selected_slot = 0
		if battle.sakuya_slot >= 0 and battle.hero_slots[battle.sakuya_slot * 3].get("flexible", false):
			selected_slot = battle.sakuya_slot * 3
			hand_view.show_shared = false
		last_second = -1
		log_label.text = "新回合 · cost +%d" % (Rules.BASE_INCOME + battle.extra_income)
		if battle.extra_income > 0:
			log_label.text += "（推理语料额外收入 +%d）" % battle.extra_income
		if battle.hero_slots.size() > previous_slots:
			log_label.text += " · 行动格增至 %d 格" % battle.hero_slots.size()
	_refresh(battle.snapshot())
	if not battle.outcome.is_empty():
		clock_label.text = "战斗结束"
		log_label.text = "胜利" if battle.outcome == "victory" else "失败"
		sound.play_sound(battle.outcome)

func _play_events(events: Array) -> void:
	for event in events:
		_refresh(event.snapshot)
		match event.type:
			"reveal":
				log_label.text = "双方锁定，技能揭晓，按速度结算。"
				await get_tree().create_timer(0.8 / speed).timeout
			"intercept":
				log_label.text = "%s 替队友接走攻击！" % event.snapshot.heroes[event.hero].name
			"clash":
				log_label.text = "拼点 %d : %d ｜ 剩余硬币 %d : %d" % [event.left, event.right, event.hero_remaining, event.enemy_remaining]
			"refund", "stalemate":
				var side := ("我方" if event.allied else "对手") if event.has("allied") else ""
				log_label.text = "%s%s，返还 %d cost" % [side, "僵持" if event.type == "stalemate" else "拼点失败", event.amount]
			"ability":
				log_label.text = event.message
				await get_tree().create_timer(0.8 / speed).timeout
			"cancelled":
				log_label.text = event.reason
			"stagger":
				log_label.text = "【失衡】%s %s！" % [event.name, event.reason]
				await get_tree().create_timer(0.4 / speed).timeout
			"overwhelm":
				log_label.text = "【压制】分差 %d，追加 %d 点压制伤害！" % [event.margin, event.amount]
		await stage.play_event(event, speed)

func _input(event: InputEvent) -> void:
	if friendly_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_friendly_target()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not friendly_panel.get_global_rect().has_point(event.position):
			friendly_panel.hide()
		return
	if item_popup.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_items()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not item_popup.get_global_rect().has_point(event.position) and not item_button.get_global_rect().has_point(event.position):
				item_popup.hide()
		return
	if busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index: int = event.keycode - KEY_1
		if index >= hand_view.visible_indices.size():
			return
		_select_card(hand_view.visible_indices[index])
	elif event.keycode == KEY_SPACE:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and hand_view.is_ancestor_of(focused):
			if not focused is DemoCardView or focused.hand_index != selected_card:
				return
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
	assert(hand_view.visible_indices.size() == 4)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = get_viewport().get_final_transform() * (stage.global_position + stage.POINTS[1] * stage.size / stage.BASE)
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	assert(selected_slot == 3 and hand_view.visible_indices.size() == 3)
	_select_card(battle.hand.find("steady_edge"))
	assert(hand_view.cards[selected_card].bonus == 2 and hint.text.contains("下限更高"))
	await RenderingServer.frame_post_draw
	var review_path := "res://test-output/role-hand-review%s.png" % ("-small" if DisplayServer.window_get_size().x <= 1000 else "")
	get_viewport().get_texture().get_image().save_png(review_path)
	hand_view.group_buttons[1].pressed.emit()
	assert(hand_view.visible_indices.size() == 6)
	var shared_card := battle.hand.find("steady")
	_select_card(shared_card)
	hand_view.cards[shared_card].grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	assert(battle.hero_slots[3].card == shared_card)
	hand_view.hero_buttons[2].pressed.emit()
	assert(selected_slot == 6 and hand_view.visible_indices.size() == 3 and selected_card == -1)
	_select_card(battle.hand.find("light_guard"))
	assert(hint.text.contains("队友各 +8"))
	hand_view.group_buttons[1].pressed.emit()
	assert(hand_view.cards[shared_card].assigned_to == "长锋")
	_select_card(shared_card)
	_assign()
	assert(not battle.hero_slots[6].active and battle.hero_slots[3].active)
	_slot_selected(true, 3)
	_cancel()
	assert(not battle.hero_slots[3].active and battle.reserved_cost() == 0)
	new_battle()
	key.keycode = KEY_1
	Input.parse_input_event(key)
	await get_tree().process_frame
	assert(battle.hand[selected_card] == "probe")
	var source := stage.global_position + stage.slot_position(true, 0) * stage.size / stage.BASE
	var target := stage.global_position + stage.slot_position(false, 0) * stage.size / stage.BASE
	source = get_viewport().get_final_transform() * source
	target = get_viewport().get_final_transform() * target
	press.position = source
	Input.parse_input_event(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
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
	print("PLANNING_UI_PASS role_groups shared_reservation keyboard mouse_drag assign cancel auto resolve timeout outcome restart")
	get_tree().quit()
