extends Control

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")

var members: Array = Rules.DEFAULT_LINEUP.duplicate()
var omitted := {}
var roster := Rules.create_roster()
var role_buttons: Array[Button] = []
var card_list: VBoxContainer
var enemy_picker: OptionButton
var launch: Button
var launch_explore: Button
var deck_cycle_checkbox: CheckBox
var summary: Label
var page: MarginContainer
var active_battle: Control

func _ready() -> void:
	if "--planning-smoke" in OS.get_cmdline_user_args():
		add_child(BattleScene.instantiate())
		return
	var skin := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	skin.default_font = font
	skin.default_font_size = 17
	theme = skin

	page = MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 24)
	add_child(page)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
	body.add_child(_label("阵容与卡组", 30))
	body.add_child(_label("选择 1～3 名队员，再勾选本场携带的牌。", 17))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var left := _panel(columns)
	left.add_child(_label("出战角色", 21))
	var roles := GridContainer.new()
	roles.columns = 2
	roles.add_theme_constant_override("h_separation", 8)
	roles.add_theme_constant_override("v_separation", 8)
	left.add_child(roles)
	for id in roster.size():
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.text = "%s\n%s" % [roster[id].name, roster[id].role]
		toggle.custom_minimum_size.y = 64
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = Color("28454d")
		selected_style.border_color = Color("8bc8ce")
		selected_style.set_border_width_all(2)
		selected_style.set_corner_radius_all(5)
		toggle.add_theme_stylebox_override("pressed", selected_style)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.toggled.connect(_toggle_member.bind(id))
		role_buttons.append(toggle)
		roles.add_child(toggle)
	var clear := Button.new()
	clear.name = "ClearLineup"
	clear.unique_name_in_owner = true
	clear.text = "清空配队"
	clear.pressed.connect(func() -> void:
		members.clear()
		_refresh_lineup())
	left.add_child(clear)
	clear.owner = self
	left.add_child(_label("敌人组合", 21))
	enemy_picker = OptionButton.new()
	for encounter_name in Rules.ENCOUNTER_NAMES:
		enemy_picker.add_item(encounter_name)
	left.add_child(enemy_picker)
	deck_cycle_checkbox = CheckBox.new()
	deck_cycle_checkbox.text = "启用尖塔抽弃牌堆循环（每回合抽 %d 张）" % Rules.DEFAULT_DRAW_COUNT
	deck_cycle_checkbox.button_pressed = false
	left.add_child(deck_cycle_checkbox)

	var right := _panel(columns)
	right.add_child(_label("携带卡牌", 21))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right.add_child(scroll)
	card_list = VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list)

	var footer := HBoxContainer.new()
	body.add_child(footer)
	summary = _label("", 17)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(summary)
	launch = Button.new()
	launch.text = "开始战斗"
	launch.custom_minimum_size = Vector2(130, 42)
	launch.pressed.connect(_start_battle)
	footer.add_child(launch)
	
	launch_explore = Button.new()
	launch_explore.text = "🌲 开启林地探索"
	launch_explore.custom_minimum_size = Vector2(160, 42)
	launch_explore.pressed.connect(_start_exploration)
	footer.add_child(launch_explore)
	_refresh_lineup()
	role_buttons[0].grab_focus()

func _label(value: String, font_size: int) -> Label:
	var entry := Label.new()
	entry.text = value
	entry.add_theme_font_size_override("font_size", font_size)
	return entry

func _panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14232d")
	style.border_color = Color("52696e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content

func _toggle_member(enabled: bool, id: int) -> void:
	if enabled and members.size() < 3:
		members.append(id)
	elif not enabled:
		members.erase(id)
	_refresh_lineup()

func _refresh_lineup() -> void:
	for id in role_buttons.size():
		var selected := members.has(id)
		role_buttons[id].set_pressed_no_signal(selected)
		role_buttons[id].text = "%s%s\n%s" % [roster[id].name, "  ✓" if selected else "", roster[id].role]
		role_buttons[id].disabled = not selected and members.size() >= 3
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	var available := Rules.available_cards(members)
	for owner in [-1] + members:
		card_list.add_child(_label("全队通用" if owner == -1 else roster[owner].name + "专属", 17))
		for key in available:
			if Rules.card_owner(key) != owner:
				continue
			var skill: Dictionary = Rules.SKILLS[key]
			var option := CheckBox.new()
			option.text = "%s   ·   %d cost" % [skill.name, skill.cost]
			option.tooltip_text = skill.description
			option.button_pressed = not omitted.has(key)
			option.toggled.connect(_toggle_card.bind(key))
			card_list.add_child(option)
	_update_summary()

func _toggle_card(enabled: bool, key: String) -> void:
	if enabled:
		omitted.erase(key)
	else:
		omitted[key] = true
	_update_summary()

func _selected_cards() -> Array:
	return Rules.available_cards(members).filter(func(key: String) -> bool: return not omitted.has(key))

func _update_summary() -> void:
	var count := _selected_cards().size()
	launch.disabled = members.is_empty() or count == 0
	if is_instance_valid(launch_explore):
		launch_explore.disabled = launch.disabled
	if launch.disabled:
		summary.text = "请选择出战角色。" if members.is_empty() else "请至少携带一张牌。"
	else:
		summary.text = "出战 %d 人  ·  携带 %d 张牌" % [members.size(), count]

func _start_battle() -> void:
	if launch.disabled or is_instance_valid(active_battle):
		return
	active_battle = BattleScene.instantiate()
	active_battle.lineup = members.duplicate()
	active_battle.deck = _selected_cards()
	active_battle.encounter = enemy_picker.selected
	if is_instance_valid(deck_cycle_checkbox):
		active_battle.use_deck_cycle = deck_cycle_checkbox.button_pressed
	active_battle.setup_requested.connect(_return_to_setup)
	page.hide()
	add_child(active_battle)

func _start_exploration() -> void:
	if launch.disabled or is_instance_valid(active_battle):
		return
	var explore_scene = load("res://exploration_map.tscn").instantiate()
	explore_scene.initial_lineup = members.duplicate()
	# 探索模式使用杀戮尖塔 10 张初始基础卡组，通过战后三选一与商店逐步收集构筑
	explore_scene.initial_deck = []
	page.hide()
	add_child(explore_scene)
	active_battle = explore_scene
	if explore_scene.has_signal("exploration_finished"):
		explore_scene.connect("exploration_finished", _return_to_setup)

func _return_to_setup() -> void:
	remove_child(active_battle)
	active_battle.queue_free()
	active_battle = null
	page.show()
	launch.grab_focus()
