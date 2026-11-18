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

func new_battle() -> void:
	if busy:
		return
	if exploration_run == null:
		battle.start(73129, encounter, touhou_team, zixi_team, lineup, deck, zixingyc_team)
	else:
		battle.start(randi(), encounter, false, false, lineup, deck, false, exploration_run.relics, exploration_run.items)
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
	last_second = -1
	_refresh(battle.snapshot())
	log_label.text = "每组三格可安排两次行动；少人时下一回合补格。"
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
	elif selected_card >= 0 and not battle.hero_slots[index].get("flexible", false) and battle.category_for(battle.hand[selected_card]) != battle.hero_slots[index].category:
		selected_card = -1
	if selected_card < 0:
		enhance_selected = false
	selected_slot = index

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
	return priority * battle.hero_slots.size() + slot.id

func _card_order(unit: int) -> Array:
	var hero: Dictionary = battle.heroes[unit]
	var owner_id := int(hero.character_id)
	var order: Array = []
	if owner_id == Rules.ZIXINGYC_ID:
		var preferred := battle.hand.find(Rules.ZiXingYC.preferred_attack(hero))
		if preferred >= 0:
			order.append(preferred)
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
			"cancelled":
				log_label.text = event.reason
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
