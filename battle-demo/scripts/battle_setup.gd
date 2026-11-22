extends Control

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")
const MapVisuals = preload("res://scripts/map_visuals.gd")
const CardPool = preload("res://scripts/card_pool.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const TeamSynergy = preload("res://scripts/team_synergy.gd")

# ── 自动化测试与主流程必保字段 ──
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
var clear_lineup_btn: Button

# ── 新版统一视觉与模式切换节点 ──
var atmosphere_canvas: Control
var pulse_time: float = 0.0
var next_atmosphere_redraw := 0.0
var mode_single_btn: Button
var mode_multi_btn: Button
var single_view: HBoxContainer
var multi_view: HBoxContainer
var subtab_explore_btn: Button
var subtab_skirmish_btn: Button
var explore_pane: VBoxContainer
var skirmish_pane: VBoxContainer
var guide_banner: Label
var synergy_label: Label
var starter_preview_box: VBoxContainer
var contract_picker: OptionButton
var contract_desc_label: Label
var contract_keys: Array[String] = ["standard", "swift_march", "bountiful_woods"]

# ── 联机模式控件 ──
var seed_code_input: LineEdit
var seed_launch_btn: Button

var _current_top_mode := "single"
var _current_single_subtab := "explore"

func _ready() -> void:
	if "--planning-smoke" in OS.get_cmdline_user_args():
		add_child(BattleScene.instantiate())
		return
	theme = MapVisuals.create_ember_theme(15)
	_build_sunlit_backdrop()
	_build_main_shell()
	_switch_top_mode("single")
	_switch_single_subtab("explore")
	_refresh_lineup()
	if not role_buttons.is_empty():
		role_buttons[0].grab_focus()

func _process(delta: float) -> void:
	if page == null or not page.is_visible_in_tree():
		return
	pulse_time += delta
	if pulse_time >= next_atmosphere_redraw:
		next_atmosphere_redraw = pulse_time + 1.0 / 15.0
		atmosphere_canvas.queue_redraw()

func _build_sunlit_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = MapVisuals.WALNUT_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var terrain := TextureRect.new()
	terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://art/forest-terrain-sunlit.jpg"):
		terrain.texture = load("res://art/forest-terrain-sunlit.jpg")
	elif ResourceLoader.exists("res://art/battle-forest-sunlit.jpg"):
		terrain.texture = load("res://art/battle-forest-sunlit.jpg")
	terrain.modulate = Color(0.84, 0.80, 0.72, 1.0)
	add_child(terrain)

	var tint := ColorRect.new()
	tint.color = Color(0.11, 0.08, 0.05, 0.48)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	atmosphere_canvas = Control.new()
	atmosphere_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere_canvas.draw.connect(_on_atmosphere_draw)
	add_child(atmosphere_canvas)

func _on_atmosphere_draw() -> void:
	var rect := atmosphere_canvas.get_rect()
	if rect.size.x > 10.0 and rect.size.y > 10.0:
		MapVisuals.draw_sunlit_atmosphere(atmosphere_canvas, rect, pulse_time, 1)

func _build_main_shell() -> void:
	page = MarginContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 28)
	page.add_theme_constant_override("margin_right", 28)
	page.add_theme_constant_override("margin_top", 20)
	page.add_theme_constant_override("margin_bottom", 20)
	add_child(page)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 14)
	page.add_child(root_col)

	root_col.add_child(_build_header_bar())
	root_col.add_child(_build_guidance_strip())

	# 主内容容器（单机 / 联机互斥展示，杜绝按钮堆砌）
	var content_stack := Control.new()
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.add_child(content_stack)

	single_view = _build_singleplayer_view()
	single_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_stack.add_child(single_view)
	clear_lineup_btn.owner = self

	multi_view = _build_multiplayer_view()
	multi_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	multi_view.visible = false
	content_stack.add_child(multi_view)

func _build_header_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_BG, 0.94), MapVisuals.BRASS_GOLD, 2, 10, 18, 12))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	bar.add_child(hbox)

	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 2)
	hbox.add_child(brand)

	var title := _label("🔥 余烬交锋  ·  CLASH ROGUELIKE", 26, MapVisuals.SUN_GOLD)
	brand.add_child(title)
	var subtitle := _label("晨曦废林拼点构筑远征  ·  全 10 名出战角色已就绪", 13, Color("dfd2b5"))
	brand.add_child(subtitle)

	var mode_pill := PanelContainer.new()
	mode_pill.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_DEEP, MapVisuals.WALNUT_BORDER, 1, 8, 5, 5))
	hbox.add_child(mode_pill)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	mode_pill.add_child(mode_row)

	mode_single_btn = Button.new()
	mode_single_btn.text = "🧭 单机模式"
	mode_single_btn.custom_minimum_size = Vector2(142, 40)
	mode_single_btn.pressed.connect(_switch_top_mode.bind("single"))
	mode_row.add_child(mode_single_btn)

	mode_multi_btn = Button.new()
	mode_multi_btn.text = "🌐 联机模式"
	mode_multi_btn.custom_minimum_size = Vector2(142, 40)
	mode_multi_btn.pressed.connect(_switch_top_mode.bind("multi"))
	mode_row.add_child(mode_multi_btn)

	return bar

func _build_guidance_strip() -> PanelContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_DEEP, 0.88), MapVisuals.WALNUT_BORDER, 1, 8, 14, 7))
	guide_banner = _label("", 14, MapVisuals.CREAM_TEXT)
	guide_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strip.add_child(guide_banner)
	return strip

func _build_singleplayer_view() -> HBoxContainer:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)

	# ── 左栏：远征小队集结（10 名角色 + 实时羁绊共鸣）──
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.08
	left_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_BG, 0.93), MapVisuals.BRASS_GOLD, 2, 10, 16, 14))
	cols.add_child(left_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left_panel.add_child(left)

	var left_head := HBoxContainer.new()
	left.add_child(left_head)
	var roster_title := _label("① 集结出战小队（点选 1～3 人）", 18, MapVisuals.SUN_GOLD)
	roster_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_head.add_child(roster_title)

	clear_lineup_btn = Button.new()
	clear_lineup_btn.name = "ClearLineup"
	clear_lineup_btn.unique_name_in_owner = true
	clear_lineup_btn.text = "清空配队"
	clear_lineup_btn.custom_minimum_size = Vector2(92, 30)
	clear_lineup_btn.pressed.connect(func() -> void:
		members.clear()
		_refresh_lineup())
	left_head.add_child(clear_lineup_btn)

	var roles_scroll := ScrollContainer.new()
	roles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(roles_scroll)

	var roles := GridContainer.new()
	roles.columns = 2
	roles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roles.add_theme_constant_override("h_separation", 10)
	roles.add_theme_constant_override("v_separation", 10)
	roles_scroll.add_child(roles)

	role_buttons.clear()
	for id in roster.size():
		var hero: Dictionary = roster[id]
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.custom_minimum_size = Vector2(0, 68)
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("3b2c1e"), MapVisuals.WALNUT_BORDER, 1, 7, 12, 8))
		toggle.add_theme_stylebox_override("hover", MapVisuals.make_box(Color("4e3b27"), MapVisuals.BRASS_GOLD, 1, 7, 12, 8))
		toggle.add_theme_stylebox_override("pressed", MapVisuals.make_box(Color("5f4627"), MapVisuals.SUN_GOLD, 2, 7, 12, 8))
		toggle.add_theme_stylebox_override("disabled", MapVisuals.make_box(Color("271d14"), Color("4a3a27"), 1, 7, 12, 8))
		toggle.tooltip_text = "%s（%s）\n生命 %d · 速度 %d~%d" % [hero.name, hero.role, int(hero.hp), int(hero.speed_min), int(hero.speed_max)]
		toggle.toggled.connect(_toggle_member.bind(id))
		role_buttons.append(toggle)
		roles.add_child(toggle)

	# 实时队伍羁绊共鸣卡片
	var syn_box := PanelContainer.new()
	syn_box.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_DEEP, MapVisuals.BRASS_GOLD, 1, 8, 12, 8))
	left.add_child(syn_box)

	var syn_col := VBoxContainer.new()
	syn_col.add_theme_constant_override("separation", 3)
	syn_box.add_child(syn_col)
	syn_col.add_child(_label("✨ 当前队伍羁绊共鸣", 13, MapVisuals.SUN_GOLD))
	synergy_label = _label("", 13, Color("d8efc9"))
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	syn_col.add_child(synergy_label)

	summary = _label("", 13, Color("dfd2b5"))
	left.add_child(summary)

	# ── 右栏：出征方式（林地探索 vs 自由交锋，消除重复配队与多余按钮）──
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.96
	right_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_BG, 0.93), MapVisuals.BRASS_GOLD, 2, 10, 16, 14))
	cols.add_child(right_panel)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right_panel.add_child(right)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	right.add_child(tab_row)

	subtab_explore_btn = Button.new()
	subtab_explore_btn.text = "🌲 林地探索（肉鸽主模式）"
	subtab_explore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtab_explore_btn.custom_minimum_size.y = 38
	subtab_explore_btn.pressed.connect(_switch_single_subtab.bind("explore"))
	tab_row.add_child(subtab_explore_btn)

	subtab_skirmish_btn = Button.new()
	subtab_skirmish_btn.text = "⚔️ 自由交锋（单场 / 木桩）"
	subtab_skirmish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtab_skirmish_btn.custom_minimum_size.y = 38
	subtab_skirmish_btn.pressed.connect(_switch_single_subtab.bind("skirmish"))
	tab_row.add_child(subtab_skirmish_btn)

	var pane_holder := Control.new()
	pane_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(pane_holder)

	explore_pane = _build_explore_pane()
	explore_pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane_holder.add_child(explore_pane)

	skirmish_pane = _build_skirmish_pane()
	skirmish_pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pane_holder.add_child(skirmish_pane)

	return cols

func _build_explore_pane() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# 羊皮纸《远征简报》——视觉与林野手记 100% 统一
	var parchment := PanelContainer.new()
	parchment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parchment.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD, 2, 10, 16, 14))
	vbox.add_child(parchment)

	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 10)
	parchment.add_child(pcol)

	pcol.add_child(_label("📜 林野远征简报", 19, MapVisuals.INK_DARK))
	var intro := _label("采用尖塔式构筑循环：系统将根据你选择的队员自动配好初始牌库，沿途通过战斗三选一、行商删牌与余烬锻台附魔不断壮大卡组，无需在开局重复勾选卡牌。", 13, MapVisuals.INK_MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(intro)

	pcol.add_child(HSeparator.new())
	pcol.add_child(_label("🃏 自动生成的初始招牌牌库预览", 14, MapVisuals.INK_DARK))

	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pcol.add_child(preview_scroll)

	starter_preview_box = VBoxContainer.new()
	starter_preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	starter_preview_box.add_theme_constant_override("separation", 5)
	preview_scroll.add_child(starter_preview_box)

	pcol.add_child(HSeparator.new())

	var gear_lbl := _label("🎒 随行初始补给：🪙 水银骰子（遗物）  ·  🩹 野战膏药  ·  💨 浓缩烟雾弹", 13, MapVisuals.INK_DARK)
	gear_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(gear_lbl)

	# 可选远征契约词条
	var contract_row := HBoxContainer.new()
	contract_row.add_theme_constant_override("separation", 10)
	vbox.add_child(contract_row)
	contract_row.add_child(_label("远征契约：", 14, MapVisuals.SUN_GOLD))

	contract_picker = OptionButton.new()
	contract_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ck in contract_keys:
		contract_picker.add_item(String(ForestRun.CONTRACTS[ck].name))
	contract_picker.item_selected.connect(_on_contract_changed)
	contract_row.add_child(contract_picker)

	contract_desc_label = _label(String(ForestRun.CONTRACTS["standard"].desc), 13, Color("dfd2b5"))
	contract_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(contract_desc_label)

	launch_explore = Button.new()
	launch_explore.text = "🌲 开启林地探索"
	launch_explore.custom_minimum_size = Vector2(0, 50)
	launch_explore.add_theme_font_size_override("font_size", 18)
	launch_explore.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("7c531b"), MapVisuals.SUN_GOLD, 2, 8, 16, 10))
	launch_explore.add_theme_stylebox_override("hover", MapVisuals.make_box(Color("996824"), Color("fff0b8"), 2, 8, 16, 10))
	launch_explore.add_theme_stylebox_override("pressed", MapVisuals.make_box(Color("634012"), MapVisuals.SUN_GOLD, 2, 8, 16, 10))
	launch_explore.pressed.connect(_start_exploration)
	vbox.add_child(launch_explore)

	return vbox

func _build_skirmish_pane() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var cfg_row := HBoxContainer.new()
	cfg_row.add_theme_constant_override("separation", 10)
	vbox.add_child(cfg_row)
	cfg_row.add_child(_label("对手遭遇：", 14, MapVisuals.SUN_GOLD))
	enemy_picker = OptionButton.new()
	enemy_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for encounter_name in Rules.ENCOUNTER_NAMES:
		enemy_picker.add_item(encounter_name)
	cfg_row.add_child(enemy_picker)

	deck_cycle_checkbox = CheckBox.new()
	deck_cycle_checkbox.text = "启用尖塔抽弃牌堆循环（每回合抽 %d 张）" % Rules.DEFAULT_DRAW_COUNT
	deck_cycle_checkbox.button_pressed = false
	vbox.add_child(deck_cycle_checkbox)

	var card_frame := PanelContainer.new()
	card_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_frame.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_DEEP, MapVisuals.WALNUT_BORDER, 1, 8, 12, 10))
	vbox.add_child(card_frame)

	var card_col := VBoxContainer.new()
	card_col.add_theme_constant_override("separation", 6)
	card_frame.add_child(card_col)
	card_col.add_child(_label("自定义携带符卡（供单场演练与木桩测试）", 14, Color("f2a272")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	card_col.add_child(scroll)

	card_list = VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 4)
	scroll.add_child(card_list)

	launch = Button.new()
	launch.text = "⚔️ 开始自由交锋"
	launch.custom_minimum_size = Vector2(0, 48)
	launch.add_theme_font_size_override("font_size", 17)
	launch.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("6b451c"), MapVisuals.SUN_GOLD, 2, 8, 16, 10))
	launch.add_theme_stylebox_override("hover", MapVisuals.make_box(Color("855824"), Color("fff0b8"), 2, 8, 16, 10))
	launch.pressed.connect(_start_battle)
	vbox.add_child(launch)

	return vbox

func _build_multiplayer_view() -> HBoxContainer:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)

	# ── 左卡：同种子林野共斗 / 竞速挑战（当前立即可玩）──
	var seed_panel := PanelContainer.new()
	seed_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_BG, 0.94), MapVisuals.BRASS_GOLD, 2, 10, 20, 18))
	cols.add_child(seed_panel)

	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 12)
	seed_panel.add_child(scol)

	scol.add_child(_label("🌲 同种子林野共斗 / 竞速挑战（当前可用）", 20, MapVisuals.SUN_GOLD))
	var seed_intro := _label("与好友约定同一个「余烬种子码」，双方即可进入完全一致的随机森林地图（相同节点路线、商店与事件），同步比拼通关回合数！", 13, Color("dfd2b5"))
	seed_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scol.add_child(seed_intro)

	var seed_card := PanelContainer.new()
	seed_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seed_card.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD, 1, 8, 16, 14))
	scol.add_child(seed_card)

	var scard_col := VBoxContainer.new()
	scard_col.add_theme_constant_override("separation", 10)
	seed_card.add_child(scard_col)
	scard_col.add_child(_label("🔑 同步远征种子码（输入相同编码即可同图）", 14, MapVisuals.INK_DARK))

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	scard_col.add_child(seed_row)

	seed_code_input = LineEdit.new()
	seed_code_input.text = "EMBER-2026"
	seed_code_input.placeholder_text = "输入任意字母/数字种子码"
	seed_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_code_input)

	var roll_seed_btn := Button.new()
	roll_seed_btn.text = "🎲 换一个"
	roll_seed_btn.pressed.connect(func() -> void:
		seed_code_input.text = "EMBER-%04d" % (randi() % 9000 + 1000))
	seed_row.add_child(roll_seed_btn)

	var tip := _label("提示：同种子远征会沿用你在【单机模式】中选好的出战小队与远征契约词条。", 13, MapVisuals.INK_MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scard_col.add_child(tip)

	seed_launch_btn = Button.new()
	seed_launch_btn.text = "🌲 按当前种子码开启同步远征"
	seed_launch_btn.custom_minimum_size.y = 48
	seed_launch_btn.add_theme_font_size_override("font_size", 16)
	seed_launch_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("7c531b"), MapVisuals.SUN_GOLD, 2, 8, 16, 10))
	seed_launch_btn.add_theme_stylebox_override("hover", MapVisuals.make_box(Color("996824"), Color("fff0b8"), 2, 8, 16, 10))
	seed_launch_btn.pressed.connect(_start_seeded_exploration)
	scol.add_child(seed_launch_btn)

	# ── 右卡：好友实时联机对战（下一阶段开放，保持版面干净无多余按钮）──
	var pvp_panel := PanelContainer.new()
	pvp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color(MapVisuals.WALNUT_BG, 0.94), MapVisuals.WALNUT_BORDER, 2, 10, 20, 18))
	cols.add_child(pvp_panel)

	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 12)
	pvp_panel.add_child(pcol)

	pcol.add_child(_label("⚔️ 好友实时拼点对战（规划中）", 20, MapVisuals.BRASS_GOLD))
	var pvp_card := PanelContainer.new()
	pvp_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pvp_card.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT_SOFT, MapVisuals.WALNUT_BORDER, 1, 8, 16, 14))
	pcol.add_child(pvp_card)

	var pvp_desc := _label("双人实时局域网 / 房间联机对战模块将在单机版本验收完成后正式开放。\n\n• 双方暗置行动规划、同时锁定揭晓\n• 局域网建房 / IP 直连\n\n当前请优先体验【单机模式】的林地探索、全部 10 名角色与队伍羁绊共鸣！", 14, MapVisuals.INK_DARK)
	pvp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_card.add_child(pvp_desc)

	var back_single_btn := Button.new()
	back_single_btn.text = "🧭 返回单机模式"
	back_single_btn.custom_minimum_size.y = 44
	back_single_btn.pressed.connect(_switch_top_mode.bind("single"))
	pcol.add_child(back_single_btn)

	return cols

func _label(value: String, font_size: int, color: Color = MapVisuals.CREAM_TEXT) -> Label:
	var entry := Label.new()
	entry.text = value
	entry.add_theme_font_size_override("font_size", font_size)
	entry.add_theme_color_override("font_color", color)
	return entry

func _style_tab_button(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("6b4c24"), MapVisuals.SUN_GOLD, 2, 6, 12, 6))
		btn.add_theme_color_override("font_color", Color("fff6db"))
	else:
		btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("342619"), MapVisuals.WALNUT_BORDER, 1, 6, 12, 6))
		btn.add_theme_color_override("font_color", Color("c9b898"))

func _switch_top_mode(mode: String) -> void:
	_current_top_mode = mode
	single_view.visible = (mode == "single")
	multi_view.visible = (mode == "multi")
	_style_tab_button(mode_single_btn, mode == "single")
	_style_tab_button(mode_multi_btn, mode == "multi")
	_update_guidance_text()

func _switch_single_subtab(tab: String) -> void:
	_current_single_subtab = tab
	explore_pane.visible = (tab == "explore")
	skirmish_pane.visible = (tab == "skirmish")
	_style_tab_button(subtab_explore_btn, tab == "explore")
	_style_tab_button(subtab_skirmish_btn, tab == "skirmish")
	_update_guidance_text()

func _update_guidance_text() -> void:
	if _current_top_mode == "multi":
		guide_banner.text = "🌐 联机引导：左侧支持「输入相同种子码」与好友同步挑战同一张随机森林地图；右侧双人实时联机对战将在单机验收后开放。"
		return
	if members.is_empty():
		guide_banner.text = "⚠️ 请先在左侧点选 1～3 名出战角色（已收录灰烬、东方嘉宾、ZiXi、ZiXingYC、pufufu 与 ZiWu 等全部 10 名角色）。"
	elif _current_single_subtab == "explore":
		guide_banner.text = "🧭 新手引导：① 左侧点选 1～3 名出战队员（下方实时预览羁绊） → ② 直接点右下角「开启林地探索」即可用初始牌库出发！"
	else:
		guide_banner.text = "⚔️ 自由交锋引导：可自由挑选敌组（含高血量木桩）并勾选任意已解锁符卡，点击右下角「开始自由交锋」立即进场演练。"

func _on_contract_changed(idx: int) -> void:
	if idx >= 0 and idx < contract_keys.size():
		var ck := contract_keys[idx]
		contract_desc_label.text = String(ForestRun.CONTRACTS[ck].desc)

func _selected_contract() -> String:
	if is_instance_valid(contract_picker) and contract_picker.selected >= 0 and contract_picker.selected < contract_keys.size():
		return contract_keys[contract_picker.selected]
	return "standard"

func _toggle_member(enabled: bool, id: int) -> void:
	if enabled and members.size() < 3:
		if not members.has(id):
			members.append(id)
	elif not enabled:
		members.erase(id)
	_refresh_lineup()

func _refresh_lineup() -> void:
	for id in role_buttons.size():
		var hero: Dictionary = roster[id]
		var selected := members.has(id)
		role_buttons[id].set_pressed_no_signal(selected)
		role_buttons[id].text = "%s%s\n%s  ·  HP %d · 速 %d~%d" % [
			hero.name,
			"  ✓" if selected else "",
			hero.role,
			int(hero.hp),
			int(hero.speed_min),
			int(hero.speed_max),
		]
		role_buttons[id].disabled = not selected and members.size() >= 3

	# 刷新自由交锋自定义卡牌勾选区
	for child in card_list.get_children():
		card_list.remove_child(child)
		child.queue_free()
	var available := Rules.available_cards(members)
	for owner in [-1] + members:
		var header_lbl := _label("── 全队通用 ──" if owner == -1 else "── %s 专属 ──" % roster[owner].name, 13, MapVisuals.SUN_GOLD)
		card_list.add_child(header_lbl)
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

	# 刷新林地探索羊皮纸初始牌库预览（只读、零冗余勾选）
	if is_instance_valid(starter_preview_box):
		for child in starter_preview_box.get_children():
			starter_preview_box.remove_child(child)
			child.queue_free()
		if members.is_empty():
			starter_preview_box.add_child(_label("请先在左侧选择至少 1 名角色。", 13, MapVisuals.INK_MUTED))
		else:
			var starter_deck := CardPool.build_starter_deck(members)
			var counts := {}
			var order: Array[String] = []
			for k in starter_deck:
				if not counts.has(k):
					order.append(k)
					counts[k] = 0
				counts[k] += 1
			for k in order:
				var sk: Dictionary = Rules.SKILLS.get(k, {})
				var qty: int = counts[k]
				var owner_tag := CardPool.card_owner_label(k)
				var row_lbl := _label("• 【%s】%s  (%d费 · %s)" % [
					String(sk.get("name", k)),
					" ×%d" % qty if qty > 1 else "",
					int(sk.get("cost", 0)),
					owner_tag,
				], 13, MapVisuals.INK_DARK)
				starter_preview_box.add_child(row_lbl)

	if is_instance_valid(synergy_label):
		synergy_label.text = TeamSynergy.summary_line(members)

	_update_summary()
	_update_guidance_text()

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
		launch_explore.disabled = members.is_empty()
	if is_instance_valid(seed_launch_btn):
		seed_launch_btn.disabled = members.is_empty()
	if members.is_empty():
		summary.text = "请选择 1～3 名出战角色。"
	else:
		var starter_cnt := CardPool.build_starter_deck(members).size()
		summary.text = "已选 %d / 3 人  ·  探索初始牌库 %d 张  ·  自由演练勾选 %d 张" % [members.size(), starter_cnt, count]

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

func _start_exploration(custom_seed: int = -1) -> void:
	if members.is_empty() or is_instance_valid(active_battle):
		return
	var explore_scene = load("res://exploration_map.tscn").instantiate()
	explore_scene.initial_lineup = members.duplicate()
	explore_scene.initial_deck = []
	explore_scene.initial_contract = _selected_contract()
	explore_scene.initial_seed = custom_seed
	page.hide()
	add_child(explore_scene)
	active_battle = explore_scene
	if explore_scene.has_signal("exploration_finished"):
		explore_scene.connect("exploration_finished", _return_to_setup)

func _start_seeded_exploration() -> void:
	var raw_code := seed_code_input.text.strip_edges()
	var seed_val := absi(raw_code.hash()) if not raw_code.is_empty() else 2026
	_start_exploration(seed_val)

func _return_to_setup() -> void:
	if is_instance_valid(active_battle):
		remove_child(active_battle)
		active_battle.queue_free()
		active_battle = null
	page.show()
	if _current_top_mode == "single" and _current_single_subtab == "explore" and is_instance_valid(launch_explore):
		launch_explore.grab_focus()
	elif is_instance_valid(launch):
		launch.grab_focus()
