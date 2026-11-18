extends Control

const BattleScene = preload("res://main.tscn")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")

signal exploration_finished

var initial_lineup: Array = []
var initial_deck: Array = []

const GOLD := Color("e6c38a")
const PANEL_BG := Color("111a21")
const PANEL_BORDER := Color("2c3e47")

# Legacy Grid & Node Compatibility
const MAP_SIZE := Vector2i(6, 4)
const BATTLES := {Vector2i(2, 1): 0, Vector2i(4, 2): 1}
const GOAL := Vector2i(5, 1)
const NODES := {
	Vector2i(1, 0): "supply", Vector2i(3, 0): "event", Vector2i(5, 0): "elite",
	Vector2i(4, 1): "camp", Vector2i(1, 2): "event", Vector2i(3, 2): "shop",
	Vector2i(2, 3): "treasure", Vector2i(4, 3): "battle"
}
const MAX_HP := [48, 42, 46]

var position_now := Vector2i(0, 1)
var visited := {}
var cleared := {}
var carried_cost: int = 30
var carried_hp := [48, 42, 46]
var finished := false
var pending: String = ""

# Compatibility aliases
var node_panel: PanelContainer
var node_text: Label
var choice_a: Button
var choice_b: Button
var leave_button: Button

var run: ForestRun
var battle: Control
var return_button: Button

# UI Nodes
var map_canvas: Control
var hud_team_container: HBoxContainer
var hero_hp_labels: Array[Label] = []
var hero_hp_bars: Array[ProgressBar] = []
var cost_label: Label
var actions_label: Label
var fatigue_label: Label
var alert_label: Label
var intel_label: Label
var core_badge: Label
var relics_container: HBoxContainer
var items_container: HBoxContainer
var log_label: Label
var end_turn_button: Button
var restart_button: Button
var lineup_button: Button

# Modal Interaction Panel
var modal_panel: PanelContainer
var modal_title: Label
var modal_desc: Label
var modal_btn_1: Button
var modal_btn_2: Button
var modal_btn_3: Button
var modal_shop_lineup_btn: Button
var modal_leave_btn: Button

# Item Detail Modal
var item_detail_panel: PanelContainer
var item_detail_title: Label
var item_detail_type: Label
var item_detail_desc: Label
var item_detail_use_btn: Button
var item_detail_close_btn: Button

# Next Floor Modal
var next_floor_panel: PanelContainer
var next_floor_title: Label
var next_floor_desc: Label
var next_floor_advance_btn: Button
var next_floor_stay_btn: Button

# Lineup Configuration Modal
var lineup_modal_panel: PanelContainer
var lineup_modal_title: Label
var lineup_role_buttons: Array[Button] = []
var lineup_card_container: VBoxContainer
var lineup_summary_label: Label
var lineup_save_btn: Button
var lineup_close_btn: Button
var edit_members: Array = []
var edit_omitted: Dictionary = {}

var floor_badge: Label

# Hovered / selected state
var hovered_node_id: String = ""
var pulse_time: float = 0.0
var selected_lineup: int = 0

func _ready() -> void:
	_setup_theme()
	_setup_layout()
	_start_new_run()

func _setup_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 14
	skin.set_stylebox("normal", "Button", _box(Color("1b272f"), Color("3d515a"), 1, 6, 6))
	skin.set_stylebox("hover", "Button", _box(Color("263742"), GOLD, 1, 6, 6))
	skin.set_stylebox("pressed", "Button", _box(Color("364b57"), GOLD, 1, 6, 6))
	skin.set_stylebox("disabled", "Button", _box(Color("131c22"), Color("25333a"), 1, 6, 6))
	theme = skin

func _setup_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("091015")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	if ResourceLoader.exists("res://art/forest-terrain.png"):
		var terrain := TextureRect.new()
		terrain.texture = load("res://art/forest-terrain.png")
		terrain.modulate = Color(0.35, 0.42, 0.44, 0.35)
		terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(terrain)
		
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.offset_left = 16
	main_vbox.offset_right = -16
	main_vbox.offset_top = 10
	main_vbox.offset_bottom = -10
	add_child(main_vbox)
	
	# Top HUD
	var top_hud := _build_top_hud()
	main_vbox.add_child(top_hud)
	
	# Map Canvas Area
	var map_frame := PanelContainer.new()
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.10, 0.13, 0.85), PANEL_BORDER, 1, 8, 4))
	main_vbox.add_child(map_frame)
	
	map_canvas = Control.new()
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.draw.connect(_on_map_canvas_draw)
	map_canvas.gui_input.connect(_on_map_canvas_input)
	map_frame.add_child(map_canvas)
	
	# Bottom Status & Log Bar
	var bottom_bar := _build_bottom_bar()
	main_vbox.add_child(bottom_bar)
	
	# Modal Interaction Panel
	_build_modal_panel()
	_build_item_detail_modal()
	_build_next_floor_modal()
	_build_lineup_modal()
	
	# Battle Return Button
	return_button = Button.new()
	return_button.text = "返回林地探索"
	return_button.visible = false
	return_button.add_theme_font_size_override("font_size", 16)
	return_button.add_theme_color_override("font_color", GOLD)
	return_button.pressed.connect(_return_from_battle)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	return_button.offset_left = -160
	return_button.offset_right = -20
	return_button.offset_top = 16
	return_button.offset_bottom = 54
	add_child(return_button)

func _build_top_hud() -> PanelContainer:
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 1, 8, 8))
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hud.add_child(hbox)
	
	# Floor Level Badge
	floor_badge = Label.new()
	floor_badge.text = "🚩 第 1 层"
	floor_badge.add_theme_font_size_override("font_size", 15)
	floor_badge.add_theme_color_override("font_color", GOLD)
	hbox.add_child(floor_badge)
	
	hbox.add_child(VSeparator.new())
	
	# Team Lineup HP Chips
	hud_team_container = HBoxContainer.new()
	hud_team_container.add_theme_constant_override("separation", 8)
	hbox.add_child(hud_team_container)
	
	hbox.add_child(VSeparator.new())
	
	# Metrics
	var metrics_box := HBoxContainer.new()
	metrics_box.add_theme_constant_override("separation", 12)
	hbox.add_child(metrics_box)
	
	cost_label = Label.new()
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", GOLD)
	metrics_box.add_child(cost_label)
	
	actions_label = Label.new()
	actions_label.add_theme_font_size_override("font_size", 14)
	actions_label.add_theme_color_override("font_color", Color("81b29a"))
	metrics_box.add_child(actions_label)
	
	fatigue_label = Label.new()
	fatigue_label.add_theme_font_size_override("font_size", 13)
	metrics_box.add_child(fatigue_label)
	
	alert_label = Label.new()
	alert_label.add_theme_font_size_override("font_size", 13)
	metrics_box.add_child(alert_label)
	
	intel_label = Label.new()
	intel_label.add_theme_font_size_override("font_size", 13)
	intel_label.add_theme_color_override("font_color", Color("64dfdf"))
	metrics_box.add_child(intel_label)
	
	core_badge = Label.new()
	core_badge.text = "🔥 烬核"
	core_badge.add_theme_font_size_override("font_size", 14)
	core_badge.add_theme_color_override("font_color", Color("ff7b00"))
	core_badge.visible = false
	metrics_box.add_child(core_badge)
	
	hbox.add_child(VSeparator.new())
	
	# Relics & Items Trays
	var trays_box := HBoxContainer.new()
	trays_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trays_box.add_theme_constant_override("separation", 14)
	hbox.add_child(trays_box)
	
	var relic_label := Label.new()
	relic_label.text = "遗物:"
	relic_label.add_theme_color_override("font_color", Color("90a955"))
	trays_box.add_child(relic_label)
	
	relics_container = HBoxContainer.new()
	relics_container.add_theme_constant_override("separation", 6)
	trays_box.add_child(relics_container)
	
	var item_label := Label.new()
	item_label.text = "道具:"
	item_label.add_theme_color_override("font_color", Color("e07a5f"))
	trays_box.add_child(item_label)
	
	items_container = HBoxContainer.new()
	items_container.add_theme_constant_override("separation", 6)
	trays_box.add_child(items_container)
	
	# Right buttons
	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(90, 32)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	hbox.add_child(end_turn_button)
	
	var exit_explore_btn := Button.new()
	exit_explore_btn.text = "退出探索"
	exit_explore_btn.pressed.connect(func() -> void:
		exploration_finished.emit()
		queue_free())
	hbox.add_child(exit_explore_btn)
	
	return hud

func _build_bottom_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 1, 6, 8))
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	bar.add_child(hbox)
	
	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", Color("cad2c5"))
	log_label.text = "沿亮起的林间小径探索，夺取烬核后返回归途石门。"
	hbox.add_child(log_label)
	
	var config_btn := Button.new()
	config_btn.text = "👥 调整配队与卡牌"
	config_btn.pressed.connect(_open_lineup_modal)
	hbox.add_child(config_btn)
	
	lineup_button = Button.new()
	lineup_button.text = "预设: 灰烬小队"
	lineup_button.pressed.connect(_toggle_lineup)
	hbox.add_child(lineup_button)
	
	restart_button = Button.new()
	restart_button.text = "重新生成地图"
	restart_button.pressed.connect(_start_new_run)
	hbox.add_child(restart_button)
	
	return bar

func _build_modal_panel() -> void:
	modal_panel = PanelContainer.new()
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_panel.offset_left = -280
	modal_panel.offset_right = 280
	modal_panel.offset_top = -140
	modal_panel.offset_bottom = 140
	modal_panel.add_theme_stylebox_override("panel", _box(Color("101b22"), GOLD, 2, 10, 16))
	add_child(modal_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	modal_panel.add_child(vbox)
	
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 18)
	modal_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(modal_title)
	
	modal_desc = Label.new()
	modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_desc.add_theme_font_size_override("font_size", 14)
	modal_desc.add_theme_color_override("font_color", Color("d8e2dc"))
	vbox.add_child(modal_desc)
	
	vbox.add_child(HSeparator.new())
	
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_box)
	
	modal_btn_1 = Button.new()
	modal_btn_1.pressed.connect(_on_modal_choice.bind(0))
	btn_box.add_child(modal_btn_1)
	
	modal_btn_2 = Button.new()
	modal_btn_2.pressed.connect(_on_modal_choice.bind(1))
	btn_box.add_child(modal_btn_2)
	
	modal_btn_3 = Button.new()
	modal_btn_3.pressed.connect(_on_modal_choice.bind(2))
	btn_box.add_child(modal_btn_3)
	
	modal_shop_lineup_btn = Button.new()
	modal_shop_lineup_btn.text = "👥 【整备】调整配队与卡牌"
	modal_shop_lineup_btn.pressed.connect(_open_lineup_modal)
	modal_shop_lineup_btn.visible = false
	btn_box.add_child(modal_shop_lineup_btn)
	
	modal_leave_btn = Button.new()
	modal_leave_btn.text = "稍后再来"
	modal_leave_btn.pressed.connect(_on_modal_leave)
	btn_box.add_child(modal_leave_btn)
	
	modal_panel.visible = false
	
	# Compatibility aliases
	node_panel = modal_panel
	node_text = modal_desc
	choice_a = modal_btn_1
	choice_b = modal_btn_2
	leave_button = modal_leave_btn

func _build_item_detail_modal() -> void:
	item_detail_panel = PanelContainer.new()
	item_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	item_detail_panel.offset_left = -210
	item_detail_panel.offset_right = 210
	item_detail_panel.offset_top = -130
	item_detail_panel.offset_bottom = 130
	item_detail_panel.add_theme_stylebox_override("panel", _box(Color("0f1a21"), GOLD, 2, 8, 14))
	add_child(item_detail_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	item_detail_panel.add_child(vbox)
	
	item_detail_title = Label.new()
	item_detail_title.add_theme_font_size_override("font_size", 17)
	item_detail_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(item_detail_title)
	
	item_detail_type = Label.new()
	item_detail_type.add_theme_font_size_override("font_size", 12)
	item_detail_type.add_theme_color_override("font_color", Color("81b29a"))
	vbox.add_child(item_detail_type)
	
	vbox.add_child(HSeparator.new())
	
	item_detail_desc = Label.new()
	item_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_detail_desc.add_theme_font_size_override("font_size", 13)
	item_detail_desc.add_theme_color_override("font_color", Color("cad2c5"))
	item_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(item_detail_desc)
	
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_box)
	
	item_detail_use_btn = Button.new()
	item_detail_use_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_box.add_child(item_detail_use_btn)
	
	item_detail_close_btn = Button.new()
	item_detail_close_btn.text = "关闭"
	item_detail_close_btn.custom_minimum_size = Vector2(80, 32)
	item_detail_close_btn.pressed.connect(func() -> void: item_detail_panel.visible = false)
	btn_box.add_child(item_detail_close_btn)
	
	item_detail_panel.visible = false

func _build_next_floor_modal() -> void:
	next_floor_panel = PanelContainer.new()
	next_floor_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	next_floor_panel.offset_left = -260
	next_floor_panel.offset_right = 260
	next_floor_panel.offset_top = -130
	next_floor_panel.offset_bottom = 130
	next_floor_panel.add_theme_stylebox_override("panel", _box(Color("0f1a21"), GOLD, 2, 8, 16))
	add_child(next_floor_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	next_floor_panel.add_child(vbox)
	
	next_floor_title = Label.new()
	next_floor_title.text = "🌟 关底首领击破！"
	next_floor_title.add_theme_font_size_override("font_size", 18)
	next_floor_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(next_floor_title)
	
	next_floor_desc = Label.new()
	next_floor_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_floor_desc.add_theme_font_size_override("font_size", 13)
	next_floor_desc.add_theme_color_override("font_color", Color("cad2c5"))
	vbox.add_child(next_floor_desc)
	
	vbox.add_child(HSeparator.new())
	
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_box)
	
	next_floor_advance_btn = Button.new()
	next_floor_advance_btn.text = "🌲 深入下一层"
	next_floor_advance_btn.pressed.connect(_on_advance_next_floor_pressed)
	btn_box.add_child(next_floor_advance_btn)
	
	next_floor_stay_btn = Button.new()
	next_floor_stay_btn.text = "暂留本层 (可在石门前整备)"
	next_floor_stay_btn.pressed.connect(func() -> void: next_floor_panel.visible = false)
	btn_box.add_child(next_floor_stay_btn)
	
	next_floor_panel.visible = false

func _build_lineup_modal() -> void:
	lineup_modal_panel = PanelContainer.new()
	lineup_modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lineup_modal_panel.offset_left = -380
	lineup_modal_panel.offset_right = 380
	lineup_modal_panel.offset_top = -250
	lineup_modal_panel.offset_bottom = 250
	lineup_modal_panel.add_theme_stylebox_override("panel", _box(Color("0e181f"), GOLD, 2, 10, 14))
	add_child(lineup_modal_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	lineup_modal_panel.add_child(vbox)
	
	lineup_modal_title = Label.new()
	lineup_modal_title.text = "👥 队伍阵容与携带卡牌配置"
	lineup_modal_title.add_theme_font_size_override("font_size", 18)
	lineup_modal_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(lineup_modal_title)
	
	var sub := Label.new()
	sub.text = "选择 1～3 名出战队员（保留各队员当前生命），并勾选本场携带的技能符卡。"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color("cad2c5"))
	vbox.add_child(sub)
	
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)
	
	# Left: Heroes
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.add_theme_stylebox_override("panel", _box(Color("132029"), PANEL_BORDER, 1, 6, 8))
	columns.add_child(left_panel)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_vbox)
	
	var left_title := Label.new()
	left_title.text = "出战队员 (1~3人)"
	left_title.add_theme_font_size_override("font_size", 14)
	left_title.add_theme_color_override("font_color", Color("81b29a"))
	left_vbox.add_child(left_title)
	
	var roles_grid := GridContainer.new()
	roles_grid.columns = 2
	roles_grid.add_theme_constant_override("h_separation", 6)
	roles_grid.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(roles_grid)
	
	var roster := DemoBattleRules.create_roster()
	lineup_role_buttons.clear()
	for id in roster.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(130, 48)
		btn.text = "%s\n%s" % [roster[id].name, roster[id].role]
		var pressed_box := _box(Color("28454d"), GOLD, 2, 5, 4)
		btn.add_theme_stylebox_override("pressed", pressed_box)
		btn.toggled.connect(_on_lineup_member_toggled.bind(id))
		roles_grid.add_child(btn)
		lineup_role_buttons.append(btn)
		
	# Right: Cards
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _box(Color("132029"), PANEL_BORDER, 1, 6, 8))
	columns.add_child(right_panel)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)
	
	var right_title := Label.new()
	right_title.text = "携带技能符卡"
	right_title.add_theme_font_size_override("font_size", 14)
	right_title.add_theme_color_override("font_color", Color("e07a5f"))
	right_vbox.add_child(right_title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)
	
	lineup_card_container = VBoxContainer.new()
	lineup_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lineup_card_container.add_theme_constant_override("separation", 4)
	scroll.add_child(lineup_card_container)
	
	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	
	lineup_summary_label = Label.new()
	lineup_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lineup_summary_label.add_theme_color_override("font_color", GOLD)
	footer.add_child(lineup_summary_label)
	
	lineup_save_btn = Button.new()
	lineup_save_btn.text = "保存并应用配置"
	lineup_save_btn.custom_minimum_size = Vector2(130, 36)
	lineup_save_btn.pressed.connect(_on_lineup_save_pressed)
	footer.add_child(lineup_save_btn)
	
	lineup_close_btn = Button.new()
	lineup_close_btn.text = "取消"
	lineup_close_btn.custom_minimum_size = Vector2(80, 36)
	lineup_close_btn.pressed.connect(func() -> void: lineup_modal_panel.visible = false)
	footer.add_child(lineup_close_btn)
	
	lineup_modal_panel.visible = false

func _show_item_detail(item_id: String, item_idx: int) -> void:
	var info: Dictionary = RelicSystem.get_consumable(item_id)
	item_detail_title.text = "%s %s" % [info.get("icon", "✦"), info.get("name", item_id)]
	item_detail_type.text = "【战术消耗品】"
	item_detail_desc.text = info.get("description", "")
	
	if item_id == "field_poultice":
		item_detail_use_btn.visible = true
		item_detail_use_btn.text = "【立即在探索中使用】(恢复重伤队员 12 生命)"
		var callables = item_detail_use_btn.pressed.get_connections()
		for c in callables:
			item_detail_use_btn.pressed.disconnect(c.callable)
		item_detail_use_btn.pressed.connect(_use_item_in_exploration.bind(item_id, item_idx))
	else:
		item_detail_use_btn.visible = false
		item_detail_desc.text += "\n\n💡 提示：该道具为战斗消耗品，进入战斗后在行动规划界面手牌区点击使用。"
	item_detail_panel.visible = true

func _show_relic_detail(relic_id: String) -> void:
	var info: Dictionary = RelicSystem.get_relic(relic_id)
	item_detail_title.text = "%s %s" % [info.get("icon", "✧"), info.get("name", relic_id)]
	item_detail_type.text = "【被动遗物】稀有度: %s" % info.get("rarity", "common")
	item_detail_desc.text = "%s\n\n✨ 全局被动常驻生效（可在所有遭遇与战斗中发挥效力）。" % info.get("description", "")
	item_detail_use_btn.visible = false
	item_detail_panel.visible = true

func _use_item_in_exploration(item_id: String, item_idx: int) -> void:
	if run == null:
		return
	if item_id == "field_poultice":
		run.heal_lowest_hero(12)
		if item_idx >= 0 and item_idx < run.items.size():
			run.items.remove_at(item_idx)
		for i in run.party_hp.size():
			if i < carried_hp.size():
				carried_hp[i] = run.party_hp[i]
		run.log_event("在探索中使用了【战地敷药】，队伍重伤队员恢复 12 点生命！")
		item_detail_panel.visible = false
		_refresh_ui()

func _show_next_floor_modal() -> void:
	if run == null:
		return
	next_floor_title.text = "🌟 第 %d 层突破！" % run.floor_level
	next_floor_desc.text = "关底守卫【烬心巨像】已被击溃，归途石门上的远古符文已完全激活！\n石阶向下延伸，更深处迷雾翻涌，前路将更为险峻。"
	next_floor_advance_btn.text = "🌲 深入下一层 (进入第 %d 层)" % (run.floor_level + 1)
	next_floor_panel.visible = true

func _on_advance_next_floor_pressed() -> void:
	if run == null:
		return
	var new_seed := int(Time.get_unix_time_from_system() * 1000) ^ randi()
	var new_map: ForestMapGraph = ForestRandomGenerator.generate(new_seed)
	run.advance_to_next_floor(new_map, new_seed)
	carried_hp.clear()
	for hp in run.party_hp:
		carried_hp.append(hp)
	carried_cost = run.carried_cost
	next_floor_panel.visible = false
	_rebuild_team_hud()
	_refresh_ui()

func _open_lineup_modal() -> void:
	if run == null or is_instance_valid(battle):
		return
	edit_members = run.lineup.duplicate()
	edit_omitted.clear()
	if not run.deck.is_empty():
		var avail := DemoBattleRules.available_cards(edit_members)
		for c in avail:
			if not run.deck.has(c):
				edit_omitted[c] = true
	_refresh_lineup_modal()
	lineup_modal_panel.visible = true

func _on_lineup_member_toggled(enabled: bool, id: int) -> void:
	if enabled and edit_members.size() < 3:
		if not edit_members.has(id):
			edit_members.append(id)
	elif not enabled:
		edit_members.erase(id)
	_refresh_lineup_modal()

func _refresh_lineup_modal() -> void:
	var roster := DemoBattleRules.create_roster()
	for id in lineup_role_buttons.size():
		var selected := edit_members.has(id)
		lineup_role_buttons[id].set_pressed_no_signal(selected)
		lineup_role_buttons[id].text = "%s%s\n%s" % [roster[id].name, "  ✓" if selected else "", roster[id].role]
		lineup_role_buttons[id].disabled = not selected and edit_members.size() >= 3
		
	for child in lineup_card_container.get_children():
		child.queue_free()
		
	var available := DemoBattleRules.available_cards(edit_members)
	for owner in [-1] + edit_members:
		var sec_lbl := Label.new()
		sec_lbl.text = "── 全队通用 ──" if owner == -1 else "── %s 专属 ──" % roster[owner].name
		sec_lbl.add_theme_font_size_override("font_size", 12)
		sec_lbl.add_theme_color_override("font_color", Color("90a955") if owner == -1 else Color("64dfdf"))
		lineup_card_container.add_child(sec_lbl)
		for key in available:
			if DemoBattleRules.card_owner(key) != owner:
				continue
			var skill: Dictionary = DemoBattleRules.SKILLS[key]
			var cb := CheckBox.new()
			cb.text = "%s  (%d cost)" % [skill.get("name", key), skill.get("cost", 0)]
			cb.tooltip_text = skill.get("description", "")
			cb.button_pressed = not edit_omitted.has(key)
			cb.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					edit_omitted.erase(key)
				else:
					edit_omitted[key] = true
				_update_lineup_modal_summary())
			lineup_card_container.add_child(cb)
			
	_update_lineup_modal_summary()

func _update_lineup_modal_summary() -> void:
	var selected_cards := DemoBattleRules.available_cards(edit_members).filter(func(k: String) -> bool: return not edit_omitted.has(k))
	var count := selected_cards.size()
	lineup_save_btn.disabled = edit_members.is_empty() or count == 0
	if lineup_save_btn.disabled:
		lineup_summary_label.text = "请选择出战角色 (1~3人)" if edit_members.is_empty() else "请至少勾选一张卡牌"
	else:
		lineup_summary_label.text = "出战 %d 人  ·  携带 %d 张牌" % [edit_members.size(), count]

func _on_lineup_save_pressed() -> void:
	if edit_members.is_empty():
		return
	var selected_cards := DemoBattleRules.available_cards(edit_members).filter(func(k: String) -> bool: return not edit_omitted.has(k))
	run.set_lineup_and_deck(edit_members, selected_cards)
	carried_hp.clear()
	for hp in run.party_hp:
		carried_hp.append(hp)
	lineup_modal_panel.visible = false
	_rebuild_team_hud()
	_refresh_ui()

func _start_new_run() -> void:
	if is_instance_valid(battle):
		battle.queue_free()
		battle = null
	return_button.visible = false
	
	var seed_val := int(Time.get_unix_time_from_system() * 1000) ^ randi()
	var map: ForestMapGraph = ForestRandomGenerator.generate(seed_val)
	run = ForestRun.new()
	if not initial_lineup.is_empty():
		run.initialize(map, 0, ["mercury_die"], ["field_poultice", "dense_smoke"], seed_val, initial_lineup, initial_deck)
	else:
		run.initialize(map, selected_lineup, ["mercury_die"], ["field_poultice", "dense_smoke"], seed_val)
	
	carried_hp.clear()
	for hp in run.party_hp:
		carried_hp.append(hp)
	carried_cost = run.carried_cost
	
	_rebuild_team_hud()
	_refresh_ui()

func _toggle_lineup() -> void:
	selected_lineup = (selected_lineup + 1) % 4
	var titles := ["灰烬小队", "东方组 (魔理沙/咲夜/灵梦)", "ZiXi 超形上组", "ZiXingYC 记忆组"]
	lineup_button.text = "阵容: %s" % titles[selected_lineup]
	_start_new_run()

func _rebuild_team_hud() -> void:
	for child in hud_team_container.get_children():
		child.queue_free()
	hero_hp_labels.clear()
	hero_hp_bars.clear()
	
	var hero_colors := [Color("d5b27a"), Color("8cbfc8"), Color("b8bf94")]
	for i in run.party_names.size():
		var chip := VBoxContainer.new()
		chip.custom_minimum_size = Vector2(100, 36)
		chip.add_theme_constant_override("separation", 2)
		hud_team_container.add_child(chip)
		
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", hero_colors[i % hero_colors.size()])
		chip.add_child(lbl)
		hero_hp_labels.append(lbl)
		
		var bar := ProgressBar.new()
		bar.max_value = run.party_max_hp[i]
		bar.value = run.party_hp[i]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		bar.add_theme_stylebox_override("background", _box(Color("1b272f"), Color.TRANSPARENT, 0, 2))
		bar.add_theme_stylebox_override("fill", _box(hero_colors[i % hero_colors.size()], Color.TRANSPARENT, 0, 2))
		chip.add_child(bar)
		hero_hp_bars.append(bar)

func _process(delta: float) -> void:
	pulse_time += delta
	if is_instance_valid(map_canvas):
		map_canvas.queue_redraw()
	if is_instance_valid(battle) and not battle.busy and not battle.battle.outcome.is_empty():
		return_button.visible = true

func _on_map_canvas_draw() -> void:
	if run == null or run.map == null:
		return
	var rect := map_canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y
	if w <= 10 or h <= 10:
		return
		
	# 1. Draw Edges
	for e in run.map.edges.values():
		var edge := e as ForestMapGraph.MapEdge
		var u_node = run.map.get_node(edge.from_id)
		var v_node = run.map.get_node(edge.to_id)
		if u_node == null or v_node == null:
			continue
			
		var known_edge: bool = not edge.hidden or run.known_edges.has(edge.id)
		if not known_edge and not run.known.has(edge.from_id) and not run.known.has(edge.to_id):
			continue
			
		var p0 := Vector2(u_node.pos.x * w, u_node.pos.y * h)
		var p1 := Vector2(v_node.pos.x * w, v_node.pos.y * h)
		var points := ForestMapGraph.bezier_points(p0, p1, edge.bend, 12)
		
		var edge_color: Color = ForestMapGraph.route_color(edge.kind)
		var is_travelled: bool = run.travelled.has(edge.id)
		if is_travelled:
			edge_color = GOLD
			edge_color.a = 0.9
		elif not run.visible.has(edge.from_id) and not run.visible.has(edge.to_id):
			edge_color.a = 0.2
		else:
			edge_color.a = 0.6
			
		var line_w := 3.5 if is_travelled else (2.0 if edge.kind == ForestMapGraph.RouteKind.MAIN else 1.5)
		for idx in points.size() - 1:
			map_canvas.draw_line(points[idx], points[idx + 1], edge_color, line_w, true)
			
	# 2. Draw Nodes
	for node in run.map.nodes.values():
		var n := node as ForestMapGraph.MapNode
		var pos := Vector2(n.pos.x * w, n.pos.y * h)
		var is_current: bool = n.id == run.position
		var is_visible: bool = run.visible.has(n.id)
		var is_known: bool = run.known.has(n.id)
		var is_reachable: bool = run.can_move(n.id)
		var is_cleared: bool = run.cleared.has(n.id)
		var is_hovered: bool = n.id == hovered_node_id
		
		var kind_col: Color = ForestMapGraph.kind_color(n.kind)
		var base_radius := 18.0
		
		if is_current:
			var halo_r := base_radius + 6.0 + sin(pulse_time * 4.0) * 2.5
			map_canvas.draw_circle(pos, halo_r, Color(GOLD, 0.25))
			map_canvas.draw_arc(pos, halo_r, 0, TAU, 24, GOLD, 2.0, true)
		elif is_reachable:
			var reach_r := base_radius + 4.0 + sin(pulse_time * 5.0) * 2.0
			map_canvas.draw_arc(pos, reach_r, 0, TAU, 24, Color(GOLD, 0.7), 2.0, true)
			
		# Shading & body
		var body_col := Color("14222a")
		if not is_known:
			body_col = Color("0d1419")
			kind_col = Color("3a4c53")
		elif not is_visible:
			body_col = Color("121d23")
			kind_col.a = 0.5
			
		if is_hovered and is_known:
			body_col = body_col.lightened(0.2)
			
		map_canvas.draw_circle(pos, base_radius, body_col)
		map_canvas.draw_arc(pos, base_radius, 0, TAU, 24, kind_col, 2.0, true)
		
		# Icon & Badge
		var icon_str: String = n.icon if is_known else "？"
		if is_current:
			icon_str = "◆"
		var font := get_theme_default_font()
		var font_size := 14
		var str_size := font.get_string_size(icon_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		map_canvas.draw_string(font, pos + Vector2(-str_size.x * 0.5, font_size * 0.35), icon_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, GOLD if is_current else (kind_col if is_known else Color("4f636b")))
		
		# Name Label
		if is_known:
			var title_str: String = n.name
			if is_cleared:
				title_str += " ✓"
			var name_size := font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
			map_canvas.draw_string(font, pos + Vector2(-name_size.x * 0.5, base_radius + 14), title_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("cad2c5") if is_visible else Color("6c757d"))
			
	# 3. Draw Patrol Beast Marker
	if run.is_patrol_visible():
		var p_node = run.map.get_node(run.patrol_node)
		if p_node != null:
			var p_pos := Vector2(p_node.pos.x * w, p_node.pos.y * h)
			var beast_halo := 24.0 + sin(pulse_time * 6.0) * 3.0
			map_canvas.draw_arc(p_pos, beast_halo, 0, TAU, 24, Color("d62828"), 2.5, true)
			var font := get_theme_default_font()
			map_canvas.draw_string(font, p_pos + Vector2(-8, -26), "🐺 巡游恶兽", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("ff6b6b"))

func _on_map_canvas_input(event: InputEvent) -> void:
	if run == null or run.map == null:
		return
	var rect := map_canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var found: String = ""
		for node in run.map.nodes.values():
			var n := node as ForestMapGraph.MapNode
			var pos := Vector2(n.pos.x * w, n.pos.y * h)
			if mouse_pos.distance_to(pos) <= 22.0:
				found = n.id
				break
		if found != hovered_node_id:
			hovered_node_id = found
			if not hovered_node_id.is_empty() and run.known.has(hovered_node_id):
				var h_node = run.map.get_node(hovered_node_id)
				var err := run.move_error(hovered_node_id)
				map_canvas.tooltip_text = "%s (%s)\n%s" % [h_node.name, ForestMapGraph.kind_title(h_node.kind), "可前往" if err.is_empty() else err]
			else:
				map_canvas.tooltip_text = ""
			map_canvas.queue_redraw()
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		for node in run.map.nodes.values():
			var n := node as ForestMapGraph.MapNode
			var pos := Vector2(n.pos.x * w, n.pos.y * h)
			if click_pos.distance_to(pos) <= 22.0:
				_handle_node_clicked(n.id)
				break

func _handle_node_clicked(node_id: String) -> void:
	if is_instance_valid(battle) or modal_panel.visible or (is_instance_valid(lineup_modal_panel) and lineup_modal_panel.visible) or (is_instance_valid(next_floor_panel) and next_floor_panel.visible):
		return
	if node_id == run.position:
		var n = run.map.get_node(node_id)
		if n and n.kind == ForestMapGraph.NodeKind.EXIT and run.floor_cleared:
			_show_next_floor_modal()
			return
		log_label.text = "当前位置：%s（%s）" % [n.name, ForestMapGraph.kind_title(n.kind)]
		return
		
	var can := run.can_move(node_id)
	if not can:
		log_label.text = run.move_error(node_id)
		return
		
	var success := run.move(node_id)
	if success:
		_refresh_ui()
		if run.in_battle:
			_start_battle(run.current_encounter)
		elif not run.pending.is_empty():
			_open_modal(run.pending)
		elif run.floor_cleared:
			_show_next_floor_modal()

func _open_modal(kind: String) -> void:
	modal_panel.visible = true
	modal_btn_1.visible = true
	modal_btn_2.visible = true
	modal_btn_3.visible = false
	modal_shop_lineup_btn.visible = false
	modal_leave_btn.visible = true
	modal_btn_1.disabled = false
	modal_btn_2.disabled = false
	modal_btn_3.disabled = false
	
	match kind:
		"camp":
			var curr_node = run.map.get_node(run.position) if (run and run.map) else null
			var is_pre_boss_camp: bool = (curr_node != null and curr_node.name.begins_with("战前"))
			modal_title.text = "▲ 战前营地" if is_pre_boss_camp else "▲ 余火营地"
			modal_desc.text = "在石门前的静谧树阴下生起营火。你可以休整包扎伤口，或调整队伍阵容与符卡配置。" if is_pre_boss_camp else "在寂静的焦木树下升起营火。你可以休整包扎伤口，或在周边搜集可用余烬。"
			modal_btn_1.text = "生火休整：存活队员恢复 10 生命，疲劳 −3"
			modal_btn_2.text = "搜集余烬：获得 6 cost，疲劳 −1"
			modal_shop_lineup_btn.visible = true
			modal_shop_lineup_btn.text = "👥 【整备】调整配队与卡牌"
			modal_leave_btn.text = "不作休整直接离开"
		"shop":
			var curr_node = run.map.get_node(run.position) if (run and run.map) else null
			var is_pre_boss: bool = (curr_node != null and curr_node.name.begins_with("战前"))
			modal_title.text = "◈ 战前行商" if is_pre_boss else "◈ 废林流浪黑商"
			modal_desc.text = "驼背行商在石门前的枯树旁摊开油布，陈列着各地的奇物。首领决战在即，请务必整备妥当！" if is_pre_boss else "驼背行商在枯树旁摊开破旧油布，陈列着来自各地的稀有奇物。"
			modal_btn_1.text = "购买特效伤药（6 cost）：存活队员恢复 8 生命"
			modal_btn_1.disabled = run.carried_cost < 6
			modal_btn_2.text = "购买神秘通用遗物（12 cost）：获取 1 件被动遗物"
			modal_btn_2.disabled = run.carried_cost < 12
			modal_btn_3.visible = true
			modal_btn_3.text = "购买战术消耗品（4 cost）：获取 1 件战斗道具"
			modal_btn_3.disabled = run.carried_cost < 4
			modal_shop_lineup_btn.visible = true
			modal_shop_lineup_btn.text = "👥 【整备】调整配队与卡牌"
			modal_leave_btn.text = "离开摊位（稍后仍可返回）"
		"shrine":
			modal_title.text = "⛩ 御灵神龛"
			modal_desc.text = "古老的灰烬石龛泛起柔和的辉光，远古守护者的呢喃在耳畔回荡。"
			modal_btn_1.text = "圣泉洗礼：疲劳度归零，重伤队员恢复 12 生命"
			modal_btn_2.text = "古神赐福：全体队员最大生命上限 +4"
			modal_leave_btn.text = "默默致意并离开"
		"forge":
			modal_title.text = "⚒ 余烬锻台"
			modal_desc.text = "废林深处竟然有一座依然保持热度的黑铁熔炉，炉锤在等待使用。"
			modal_btn_1.text = "淬炼战铠：全体队员最大生命上限 +2"
			modal_btn_2.text = "熔铸催化剂（3 cost）：获得【余烬催化剂】"
			modal_btn_2.disabled = run.carried_cost < 3
			modal_leave_btn.text = "离开锻台"
		"gamble":
			modal_title.text = "🎲 迷雾博弈"
			modal_desc.text = "神情诡异的流浪者正在摇晃骨骰，露出神秘的笑容。"
			modal_btn_1.text = "下注一试（4 cost）：50% 获得 10 cost，30% 赢下特制铅币"
			modal_btn_1.disabled = run.carried_cost < 4
			modal_btn_2.text = "拒绝诱惑直接离开"
			modal_leave_btn.visible = false
		"event":
			modal_title.text = "？ 遗迹异象"
			match run.event_variant:
				0:
					modal_desc.text = "发现一处布满焦痕的古代石穴，隐约传来微弱的能量共鸣。"
					modal_btn_1.text = "稳妥搜寻：获得 5 cost"
					modal_btn_2.text = "冒险深入：存活队员各失去 4 生命，掠夺 14 cost"
				1:
					modal_desc.text = "树根深处传来微弱呼救声，似乎是落入捕兽陷阱的游侠。"
					modal_btn_1.text = "上前营救：可能获赠 8 cost 与烟雾弹，但也可能是致命陷阱"
					modal_btn_2.text = "谨慎绕行：不冒任何风险离开"
				_:
					modal_desc.text = "一块半掩埋在泥土中的残破石碑，铭刻着废林过去的密道地图。"
					modal_btn_1.text = "消耗 3 cost 仔细拓印：获得 3 片情报碎片"
					modal_btn_1.disabled = run.carried_cost < 3
					modal_btn_2.text = "置之不理"
			modal_leave_btn.visible = false

func _on_modal_choice(choice_idx: int) -> void:
	if run == null:
		return
	var ok := run.apply_choice(choice_idx)
	if ok:
		modal_panel.visible = false
		_refresh_ui()

func _on_modal_leave() -> void:
	if run == null:
		return
	if run.pending == "shop":
		run.leave_shop()
	else:
		run.pending = ""
		run.cleared[run.position] = true
	modal_panel.visible = false
	_refresh_ui()

func _on_end_turn_pressed() -> void:
	if run == null or is_instance_valid(battle) or modal_panel.visible:
		return
	run.end_turn()
	_refresh_ui()
	if run.in_battle:
		_start_battle(run.current_encounter)

func _refresh_ui() -> void:
	if run == null:
		return
	if is_instance_valid(floor_badge):
		floor_badge.text = "🚩 第 %d 层" % run.floor_level
	cost_label.text = "🪙 %d cost" % run.carried_cost
	var actions_dots := ""
	for i in run.action_budget:
		actions_dots += "●" if i < run.actions_left else "○"
	actions_label.text = "行动力 [%s]" % actions_dots
	
	fatigue_label.text = "疲劳: %d/8" % run.fatigue
	fatigue_label.add_theme_color_override("font_color", Color("e63946") if run.fatigue >= 6 else (Color("ffd166") if run.fatigue >= 4 else Color("cad2c5")))
	
	alert_label.text = "警戒: %d/5" % run.alert
	alert_label.add_theme_color_override("font_color", Color("e63946") if run.alert >= 4 else Color("cad2c5"))
	
	intel_label.text = "📜 %d 情报" % run.intel_fragments
	core_badge.visible = run.ember_core
	
	log_label.text = run.message
	end_turn_button.disabled = run.finished or run.in_battle or not run.pending.is_empty()
	
	for i in run.party_hp.size():
		if i < hero_hp_labels.size() and i < hero_hp_bars.size():
			hero_hp_labels[i].text = "%s  %d/%d" % [run.party_names[i], run.party_hp[i], run.party_max_hp[i]]
			hero_hp_bars[i].max_value = run.party_max_hp[i]
			hero_hp_bars[i].value = run.party_hp[i]
		
	# Refresh Relics Shelf
	for child in relics_container.get_children():
		child.queue_free()
	for r_id in run.relics:
		var r_data: Dictionary = RelicSystem.get_relic(r_id)
		var btn := Button.new()
		btn.text = r_data.get("icon", "✧")
		btn.tooltip_text = "【%s】(点击查看详细)\n%s" % [r_data.get("name", r_id), r_data.get("description", "")]
		btn.custom_minimum_size = Vector2(28, 28)
		btn.pressed.connect(_show_relic_detail.bind(r_id))
		relics_container.add_child(btn)
		
	# Refresh Items Shelf
	for child in items_container.get_children():
		child.queue_free()
	for idx in run.items.size():
		var i_id: String = run.items[idx]
		var i_data: Dictionary = RelicSystem.get_consumable(i_id)
		var btn := Button.new()
		btn.text = i_data.get("icon", "✦")
		btn.tooltip_text = "【%s】(点击查看详情/使用)\n%s" % [i_data.get("name", i_id), i_data.get("description", "")]
		btn.custom_minimum_size = Vector2(28, 28)
		btn.pressed.connect(_show_item_detail.bind(i_id, idx))
		items_container.add_child(btn)
		
	map_canvas.queue_redraw()

func _start_battle(encounter: int) -> void:
	battle = BattleScene.instantiate()
	battle.encounter = encounter
	battle.lineup = run.lineup.duplicate()
	battle.deck = run.deck.duplicate() if not run.deck.is_empty() else null
	if run.in_battle:
		battle.exploration_run = run
	add_child(battle)
	if battle.exploration_run == null:
		battle.battle.cost = carried_cost
		for i in mini(carried_hp.size(), battle.battle.heroes.size()):
			battle.battle.heroes[i].hp = carried_hp[i]
		battle._refresh(battle.battle.snapshot())
	for control in [battle.encounter_button, battle.team_button, battle.zixi_button, battle.zixingyc_button, battle.restart_button, battle.setup_button]:
		if control != null:
			control.hide()
	return_button.visible = false
	move_child(return_button, get_child_count() - 1)

func _return_from_battle() -> void:
	if not is_instance_valid(battle) or battle.busy or battle.battle.outcome.is_empty():
		return
	var outcome: String = battle.battle.outcome
	var victory: bool = outcome == "victory"
	var surviving_hp: Array[int] = []
	for h in battle.battle.heroes:
		surviving_hp.append(int(h.hp))
	var final_cost: int = battle.battle.cost
	var enc: int = battle.encounter
	var graph_battle: bool = battle.exploration_run != null
	if graph_battle:
		run.items.assign(battle.battle.active_items)
	
	battle.queue_free()
	battle = null
	return_button.visible = false
	if graph_battle:
		run.apply_battle_result(victory, surviving_hp, final_cost)
		carried_cost = run.carried_cost
		carried_hp.assign(run.party_hp)
		_refresh_ui()
		if run.floor_cleared:
			_show_next_floor_modal()
		return

	carried_cost = final_cost
	for i in carried_hp.size():
		if i < surviving_hp.size():
			carried_hp[i] = surviving_hp[i]
	if victory:
		cleared[position_now] = true
		var is_elite: bool = int(BATTLES.get(position_now, -1)) == 1 or NODES.get(position_now, "") == "elite" or enc in [1, 4]
		carried_cost += 8 if is_elite else 4
	else:
		finished = true
		
	_refresh_ui()

# Legacy Grid & Event Compatibility
func _open_node(kind: String) -> void:
	pending = kind
	_open_modal(kind)

func _choose(choice: int) -> void:
	if pending.is_empty() or choice < 0 or choice > 2:
		return
	if pending == "shop":
		if choice != 0 or carried_cost < 6:
			return
		carried_cost -= 6
		_legacy_heal(8)
	elif pending == "camp":
		if choice == 0:
			_legacy_heal(10)
		else:
			carried_cost += 5
	elif pending == "event":
		if choice == 0:
			carried_cost += 5
		else:
			for i in carried_hp.size():
				if carried_hp[i] > 0:
					carried_hp[i] = maxi(1, carried_hp[i] - 4)
			carried_cost += 12
	cleared[position_now] = true
	pending = ""
	if is_instance_valid(modal_panel):
		modal_panel.visible = false
	if run:
		run.carried_cost = carried_cost
		for i in carried_hp.size():
			if i < run.party_hp.size():
				run.party_hp[i] = carried_hp[i]
	_refresh_ui()

func _legacy_heal(amount: int) -> void:
	for i in carried_hp.size():
		if carried_hp[i] > 0:
			carried_hp[i] = mini(MAX_HP[i], carried_hp[i] + amount)

func _leave_node() -> void:
	if pending != "shop":
		return
	pending = ""
	if is_instance_valid(modal_panel):
		modal_panel.visible = false

func _restart() -> void:
	position_now = Vector2i(0, 1)
	visited.clear()
	cleared.clear()
	carried_cost = 30
	carried_hp = [48, 42, 46]
	finished = false
	pending = ""
	_start_new_run()

func _move(p: Vector2i) -> void:
	if finished or not pending.is_empty() or is_instance_valid(battle) or absi(p.x - position_now.x) + absi(p.y - position_now.y) != 1 or p.x < 0 or p.x >= MAP_SIZE.x or p.y < 0 or p.y >= MAP_SIZE.y:
		return
	position_now = p
	visited[position_now] = true
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = position_now + d
		if neighbor.x >= 0 and neighbor.x < MAP_SIZE.x and neighbor.y >= 0 and neighbor.y < MAP_SIZE.y:
			visited[neighbor] = true
	if BATTLES.has(p) and not cleared.has(p):
		_start_battle(int(BATTLES[p]))
	elif p == GOAL:
		finished = true
	elif NODES.has(p) and not cleared.has(p):
		var kind: String = NODES[p]
		if kind == "battle" or kind == "elite":
			_start_battle(1 if kind == "elite" else 0)
		elif kind == "treasure" or kind == "supply":
			carried_cost += 8 if kind == "treasure" else 4
			cleared[p] = true
		else:
			_open_node(kind)
	_refresh_ui()

func _box(fill: Color, border: Color, width: int = 1, radius: int = 0, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box
