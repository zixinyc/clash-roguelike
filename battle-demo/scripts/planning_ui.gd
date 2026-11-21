extends Control

signal setup_requested
var lineup: Array = []
var deck: Variant = null
var exploration_run: RefCounted
var use_deck_cycle := false
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
var item_popup: PanelContainer
var item_close_button: Button
var item_rows: VBoxContainer
var item_feedback: Label
var draw_pile_button: Button
var discard_pile_button: Button
var pile_popup: PanelContainer
var pile_title: Label
var pile_rows: VBoxContainer
var pile_close_button: Button
var pile_mode := ""

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 16
	var box := StyleBoxFlat.new()
	box.bg_color = Color("28342b")
	box.border_color = Color("7b8a6b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(9)
	skin.set_stylebox("normal", "Button", box)
	theme = skin
	var bg := ColorRect.new()
	bg.color = Color("161f19")
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
	_build_pile_popup(top)
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
	stage.aim_cancelled.connect(func() -> void: log_label.text = "未安排：请将行动格拖到敌方上方的攻／大／防小格，或直接点击高亮敌方槽。")
	stage.quick_assign_requested.connect(_quick_assign)
	stage.slot_cancel_requested.connect(_quick_cancel)
	stage.unit_selected.connect(_on_unit_selected)
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

func _build_pile_popup(top: HBoxContainer) -> void:
	draw_pile_button = button("📚 抽牌 0", _open_pile.bind("draw"))
	draw_pile_button.tooltip_text = "查看当前抽牌堆中的卡牌（乱序展示，不透露下一张抽牌顺序）"
	draw_pile_button.visible = false
	top.add_child(draw_pile_button)

	discard_pile_button = button("♻ 弃牌 0", _open_pile.bind("discard"))
	discard_pile_button.tooltip_text = "查看当前弃牌堆中的卡牌（抽牌堆抽空后将自动洗回）"
	discard_pile_button.visible = false
	top.add_child(discard_pile_button)

	pile_popup = PanelContainer.new()
	pile_popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pile_popup.offset_left = -430
	pile_popup.offset_right = -18
	pile_popup.offset_top = 66
	pile_popup.offset_bottom = 440
	pile_popup.hide()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("241d15")
	panel.border_color = Color("e0b35e")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	pile_popup.add_theme_stylebox_override("panel", panel)
	add_child(pile_popup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	pile_popup.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	pile_title = label("牌堆", 18)
	pile_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_title.add_theme_color_override("font_color", Color("f0c66d"))
	heading.add_child(pile_title)
	pile_close_button = button("关闭", _close_pile)
	heading.add_child(pile_close_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	pile_rows = VBoxContainer.new()
	pile_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(pile_rows)

func _open_pile(mode: String) -> void:
	if pile_popup.visible and pile_mode == mode:
		_close_pile()
		return
	item_popup.hide()
	pile_mode = mode
	for child in pile_rows.get_children():
		pile_rows.remove_child(child)
		child.queue_free()
	var source_pile: Array = battle.draw_pile if mode == "draw" else battle.discard_pile
	pile_title.text = "📚 抽牌堆（%d 张 · 按卡名排序）" % source_pile.size() if mode == "draw" else "♻ 弃牌堆（%d 张）" % source_pile.size()
	if source_pile.is_empty():
		pile_rows.add_child(label("当前为空。", 14))
	else:
		var counts := {}
		for inst in source_pile:
			var k: String = String(inst.get("key", ""))
			counts[k] = int(counts.get(k, 0)) + 1
		var sorted_keys: Array = counts.keys()
		sorted_keys.sort()
		for k in sorted_keys:
			var s: Dictionary = Rules.SKILLS.get(k, {})
			var qty := int(counts[k])
			var qty_str := " ×%d" % qty if qty > 1 else ""
			var row_lbl := label("• %s%s（%d cost）— %s" % [String(s.get("name", k)), qty_str, int(s.get("cost", 0)), String(s.get("description", ""))], 14)
			row_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pile_rows.add_child(row_lbl)
	pile_popup.show()
	move_child(pile_popup, get_child_count() - 1)
	pile_close_button.grab_focus()

func _close_pile() -> void:
	pile_popup.hide()
	pile_mode = ""

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
	if is_instance_valid(pile_popup):
		pile_popup.hide()
	var enable_cycle: bool = use_deck_cycle or exploration_run != null
	var stage3_combat_cfg := {
		"flex_attack_in_ultimate": true,
		"unopposed_bonus": true,
		"deck_cycle": enable_cycle,
		"draw_count": Rules.DEFAULT_DRAW_COUNT,
		"card_instances": exploration_run.card_instances.duplicate(true) if exploration_run != null else [],
		"deck_enchants": exploration_run.deck_enchants.duplicate() if exploration_run != null else {},
	}
	if exploration_run == null:
		battle.start(73129, encounter, touhou_team, zixi_team, lineup, deck, zixingyc_team, [], [], stage3_combat_cfg)
	else:
		battle.start(randi(), encounter, false, false, lineup, deck, false, exploration_run.relics, exploration_run.items, stage3_combat_cfg)
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
	hand_view.show_all_playable = battle.deck_cycle_enabled
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
		return {"valid": false, "kind": "invalid", "tag": "不可", "text": error, "detail": "✖ " + error}
	if battle.can_clash(hero, enemy):
		var holder_id := battle.predicted_clash_hero(target, selected_slot)
		if holder_id >= 0:
			var holder: Dictionary = battle.hero_slots[holder_id]
			var holder_wins: bool = holder.speed > hero.speed or (holder.speed == hero.speed and holder.id < hero.id)
			var holder_name: String = battle.heroes[holder.unit].name
			if holder_wins:
				var bonus_txt := " (+%d伤)" % Rules.UNOPPOSED_BONUS if battle.unopposed_bonus_enabled else ""
				return {
					"valid": true,
					"kind": "flank",
					"tag": "夹击",
					"text": "%s已接下拼点 · 可单方面夹击%s" % [holder_name, bonus_txt],
					"detail": "⚡ 单方面夹击%s · %s已接下拼点，本击无阻" % [bonus_txt, holder_name]
				}
			return {
				"valid": true,
				"kind": "intercept" if enemy.target != hero.unit else "engage",
				"tag": "接管",
				"text": "速度更高 · 接管%s的拼点（对方转夹击）" % holder_name,
				"detail": "⚡ 接管拼点 · 我方速 %d > %s速 %d，原队友转单方面夹击" % [hero.speed, holder_name, holder.speed]
			}
		if enemy.target == hero.unit:
			return {
				"valid": true,
				"kind": "engage",
				"tag": "迎击",
				"text": "可迎击自身攻击",
				"detail": "⚔ 迎击拼点 · 我方速 %d vs 敌方速 %d" % [hero.speed, enemy.speed]
			}
		var ally_name: String = battle.heroes[enemy.target].name if enemy.target >= 0 and enemy.target < battle.heroes.size() else "队友"
		return {
			"valid": true,
			"kind": "intercept",
			"tag": "拦截",
			"text": "可拦截队友受到的攻击",
			"detail": "⚡ 高速拦截 · 速 %d > %d · 替%s接招" % [hero.speed, enemy.speed, ally_name]
		}
	var solo_bonus := " (+%d伤)" % Rules.UNOPPOSED_BONUS if battle.unopposed_bonus_enabled else ""
	if not enemy.active:
		return {"valid": true, "kind": "solo", "tag": "单打", "text": "空槽 · 可单方面攻击%s" % solo_bonus, "detail": "🗡 空槽 · 单方面攻击%s" % solo_bonus}
	if enemy.category == 2:
		return {"valid": true, "kind": "solo", "tag": "单打", "text": "防御格 · 可单方面攻击%s" % solo_bonus, "detail": "🗡 防御格 · 单方面攻击%s" % solo_bonus}
	return {"valid": true, "kind": "solo", "tag": "单打", "text": "可单方面攻击%s · 对方原行动照常" % solo_bonus, "detail": "🗡 单方面攻击%s · 对方原行动照常" % solo_bonus}

func _hero_slot_guidance(slot_id: int) -> Dictionary:
	var slot: Dictionary = battle.hero_slots[slot_id]
	var used := 0
	for other in battle.hero_slots:
		if other.active and other.unit == slot.unit and other.get("row", 0) == slot.get("row", 0):
			used += 1
	var lim := Rules.group_action_limit(slot)
	var group_full: bool = used >= lim and not slot.active
	var info := {"valid": false, "is_guard": false, "group_full": group_full, "tooltip": ""}
	if slot.active:
		var sname: String = Rules.SKILLS[slot.key].name if Rules.SKILLS.has(slot.key) else slot.key
		info.tooltip = "已安排【%s】· 右键此格可快速撤销" % sname
	elif group_full:
		info.tooltip = "本组行动格已排满 %d 次，可右键撤销其他已排格" % lim
	if busy or battle.phase != "response" or selected_card < 0 or selected_card >= battle.hand.size():
		return info
	var key: String = battle.hand[selected_card]
	var is_guard := not Rules.targets_enemy(key)
	info.is_guard = is_guard
	if is_guard:
		var err := battle.can_assign(selected_card, slot_id, -1, enhance_selected)
		if err.is_empty():
			info.valid = true
			info.tooltip = "点击此格直接安排防御【%s】" % Rules.SKILLS[key].name
		elif info.tooltip.is_empty():
			info.tooltip = err
	else:
		# Check if any enemy slot is valid for this hero slot + selected card
		var any_ok := false
		for e_slot in battle.enemy_slots:
			if battle.can_assign(selected_card, slot_id, e_slot.id, enhance_selected).is_empty():
				any_ok = true
				break
		if any_ok:
			info.valid = true
			info.tooltip = "可从此格拖向敌方高亮格，或直接点击高亮敌方格安排【%s】" % Rules.SKILLS[key].name
	return info

func _refresh(state: Dictionary) -> void:
	stage.target_guidance.clear()
	stage.hero_guidance.clear()
	for h_idx in battle.hero_slots.size():
		stage.hero_guidance.append(_hero_slot_guidance(h_idx))
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
	hero_picker.clear()
	enemy_picker.clear()
	for slot in state.hero_slots:
		var category: String = "技能" if slot.get("flexible", false) else Rules.CATEGORIES[slot.category]
		if slot.has("row"):
			category += " · 增援 %d" % slot.row
		var action: String = " · " + Rules.SKILLS[slot.key].name if slot.active else " · 空"
		if slot.get("enhanced", false):
			action += "（强化）"
		if slot.get("frozen", false):
			action = " · 停时"
		hero_picker.add_item("%s(%s) · %s · 速度 %d%s" % [state.heroes[slot.unit].name, state.heroes[slot.unit].role, category, slot.speed, action])
	for slot in state.enemy_slots:
		var detail := "待机"
		if slot.active:
			detail = "已启用" if state.phase == "response" else Rules.SKILLS[slot.key].name
			if slot.category != 2:
				detail += " → " + state.heroes[slot.target].name
		enemy_picker.add_item("%s · %s · 速度 %d · %s" % [state.enemies[slot.unit].name, Rules.CATEGORIES[slot.category], slot.speed, detail])
	hero_picker.select(selected_slot)
	enemy_picker.select(selected_target)
	hand_view.refresh(state, stage.selected_hero, selected_card, not busy and state.phase == "response", selected_slot, enhance_selected)
	for control in [ready_button, cancel_button, assign_button, auto_button, hero_picker, enemy_picker]:
		control.disabled = busy or state.phase != "response"
	restart_button.disabled = busy
	encounter_button.disabled = busy
	team_button.disabled = busy
	zixi_button.disabled = busy
	zixingyc_button.disabled = busy
	item_button.text = "道具 %d" % battle.active_items.size()
	item_button.disabled = busy or state.phase != "response"
	item_button.add_theme_color_override("font_color", Color("a7e1e2") if not battle.active_items.is_empty() else Color("d3e0e4"))
	if is_instance_valid(draw_pile_button) and is_instance_valid(discard_pile_button):
		var show_piles: bool = state.get("deck_cycle_enabled", false)
		draw_pile_button.visible = show_piles
		discard_pile_button.visible = show_piles
		draw_pile_button.text = "📚 抽牌 %d" % int(state.get("draw_count", 0))
		discard_pile_button.text = "♻ 弃牌 %d" % int(state.get("discard_count", 0))
		draw_pile_button.disabled = busy
		discard_pile_button.disabled = busy
	if setup_button != null:
		setup_button.disabled = busy
	ready_button.text = "交锋进行中" if busy else "准备交锋  ·  Enter"
	var count := 0
	for slot in state.hero_slots:
		if slot.active:
			count += 1
	ally_status.text = "我方  ·  规划中    已安排 %d 次行动" % count
	enemy_status.text = "敌方  ·  已锁定    目标公开 / 技能隐藏"
	if selected_card >= 0 and selected_card < battle.hand.size():
		var sel_key: String = battle.hand[selected_card]
		var sel_name: String = Rules.SKILLS[sel_key].name
		if not Rules.targets_enemy(sel_key):
			guide.text = "① 已选【%s】 → ② 直接点击上方亮起的蓝色「防」槽安排（右键可撤销） → ③ 准备交锋" % sel_name
		else:
			guide.text = "① 已选【%s】 → ② 直接点击带「迎击/拦截/单打」标的敌方槽，或从亮起我方槽拖过去 → ③ 准备交锋" % sel_name
	elif count > 0:
		guide.text = "已安排 %d 次行动 · 可继续选牌或右键我方槽撤销；安排完毕点击「准备交锋」" % count
	else:
		guide.text = "① 从下方选择手牌 → ② 点击高亮目标槽或从我方槽拖向敌方槽 → ③ 准备交锋"
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
	elif not state.outcome.is_empty():
		hint.text = "战斗胜利！点击重新开始。" if state.outcome == "victory" else "小队失利。点击重新开始再试。"
	else:
		hint.text = "交锋中，行动按速度结算。"

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
	if not target_info.valid:
		hint.text = "%s · %s" % [card.skill.name, target_info.text]
		return
	var effect := card.effect_text()
	if enhance_selected:
		effect = "%s · %s" % [card.skill.enhance_name, card.skill.enhance_description]
	hint.text = "%s · %s｜%d 枚硬币，每个正面 +%d｜%s%s" % [card.skill.name, effect, card.skill.coins, card.skill.power, target_info.text, _archive_note()]

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

func _change_slot(index: int) -> void:
	if battle.hero_slots[index].unit != battle.hero_slots[selected_slot].unit:
		hand_view.show_shared = false
		selected_card = -1
	elif selected_card >= 0 and not battle.slot_accepts_category(battle.hero_slots[index], battle.hand[selected_card]):
		selected_card = -1
	if selected_card < 0:
		enhance_selected = false
	selected_slot = index

func _on_unit_selected(allied: bool, index: int) -> void:
	if allied:
		_slot_selected(true, index * 3)
		return
	if selected_card >= 0 and selected_card < battle.hand.size() and Rules.targets_enemy(battle.hand[selected_card]):
		var best_slot := index * 3
		var best_rank := -1
		for offset in 3:
			var sid := index * 3 + offset
			if sid >= battle.enemy_slots.size():
				continue
			var g := _target_guidance(sid)
			if not g.get("valid", false):
				continue
			var rank := 4 if g.get("kind", "") == "engage" else (3 if g.get("kind", "") == "flank" else (2 if g.get("kind", "") == "solo" else 1))
			if rank > best_rank:
				best_rank = rank
				best_slot = sid
		_slot_selected(false, best_slot)
		return
	_slot_selected(false, index * 3)

func _slot_selected(allied: bool, index: int) -> void:
	if busy or battle.phase != "response":
		return
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
	var slot_now: Dictionary = battle.hero_slots[selected_slot]
	if battle.heroes[slot_now.unit].hp <= 0:
		return
	selected_card = index
	var key: String = battle.hand[index]
	if not battle.hero_slots[selected_slot].get("flexible", false):
		var want_cat := battle.category_for(key)
		var base_id := selected_slot - int(slot_now.category)
		if want_cat == 0 and battle.flex_attack_in_ultimate:
			# Keep current slot if already on open 攻 or 大, else pick open 攻 first, then open 大!
			if battle.slot_accepts_category(slot_now, key) and not slot_now.active:
				pass
			elif not battle.hero_slots[base_id].active:
				selected_slot = base_id
			elif not battle.hero_slots[base_id + 1].active:
				selected_slot = base_id + 1
			else:
				selected_slot = base_id
		else:
			selected_slot = base_id + want_cat
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

func _quick_assign(allied: bool, slot_id: int) -> void:
	if busy or battle.phase != "response" or selected_card < 0:
		return
	if allied:
		selected_slot = slot_id
	else:
		selected_target = slot_id
	_assign()

func _quick_cancel(slot_id: int) -> void:
	if busy or battle.phase != "response":
		return
	selected_slot = slot_id
	_cancel()

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
		if slot.active and Rules.targets_enemy(slot.key) and battle.can_clash(slot, battle.enemy_slots[slot.target]):
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
		var targets := own_targets + intercepts + remaining_targets
		for card in _card_order(slot.unit, int(slot.category)):
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
					if battle.assign(card, slot.id, target, enhance).is_empty():
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
	else:
		# 大招格优化：若持有可用大招牌，优先规划大招格，防止普通攻击占用或费用被耗尽
		if int(slot.category) == 1:
			var has_ultimate := false
			for card_idx in battle.hand.size():
				var key: String = battle.hand[card_idx]
				if battle.category_for(key) == 1:
					var owner := Rules.card_owner(key)
					if owner < 0 or owner == hero.character_id:
						has_ultimate = true
						break
			if has_ultimate:
				priority = 0
	return priority * battle.hero_slots.size() + slot.id

func _card_order(unit: int, slot_category: int = -1) -> Array:
	var hero: Dictionary = battle.heroes[unit]
	var owner_id := int(hero.character_id)
	var order: Array = []
	if owner_id == Rules.ZIXINGYC_ID:
		var preferred := battle.hand.find(Rules.ZiXingYC.preferred_attack(hero))
		if preferred >= 0:
			order.append(preferred)
	
	if slot_category >= 0:
		# 1. 本角色专属且类别完全契合的牌
		for card in battle.hand.size():
			var key: String = battle.hand[card]
			if Rules.card_owner(key) == owner_id and battle.category_for(key) == slot_category and not order.has(card):
				order.append(card)
		# 2. 通用且类别完全契合的牌
		for card in battle.hand.size():
			var key: String = battle.hand[card]
			if Rules.card_owner(key) < 0 and battle.category_for(key) == slot_category and not order.has(card):
				order.append(card)
		# 3. 大招格兼放攻击牌时的保底攻击填充（专属攻 -> 通用攻）
		if slot_category == 1 and battle.flex_attack_in_ultimate:
			for card in battle.hand.size():
				var key: String = battle.hand[card]
				if Rules.card_owner(key) == owner_id and battle.category_for(key) == 0 and not order.has(card):
					order.append(card)
			for card in battle.hand.size():
				var key: String = battle.hand[card]
				if Rules.card_owner(key) < 0 and battle.category_for(key) == 0 and not order.has(card):
					order.append(card)

	for card in battle.hand.size():
		if Rules.card_owner(battle.hand[card]) == owner_id and not order.has(card):
			order.append(card)
	for card in battle.hand.size():
		if Rules.card_owner(battle.hand[card]) < 0 and not order.has(card):
			order.append(card)
	return order

func _resolve() -> void:
	if busy or battle.phase != "response":
		return
	busy = true
	item_popup.hide()
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
				log_label.text = "拼点 %d : %d ｜ 剩余硬币 %d : %d" % [event.left, event.right, event.hero_remaining, event.enemy_remaining]
			"refund", "stalemate":
				log_label.text = "%s，返还 %d cost" % ["僵持" if event.type == "stalemate" else "拼点失败", event.amount]
			"ability":
				log_label.text = event.message
				await get_tree().create_timer(0.8 / speed).timeout
			"unopposed":
				log_label.text = event.message
			"cancelled":
				log_label.text = event.reason
			"stagger":
				log_label.text = "【失衡】%s %s！" % [event.name, event.reason]
				await get_tree().create_timer(0.4 / speed).timeout
			"overwhelm":
				log_label.text = "【压制】分差 %d，追加 %d 点压制伤害！" % [event.margin, event.amount]
		await stage.play_event(event, speed)
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

func _input(event: InputEvent) -> void:
	if is_instance_valid(pile_popup) and pile_popup.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_pile()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not pile_popup.get_global_rect().has_point(event.position) and not draw_pile_button.get_global_rect().has_point(event.position) and not discard_pile_button.get_global_rect().has_point(event.position):
				_close_pile()
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
