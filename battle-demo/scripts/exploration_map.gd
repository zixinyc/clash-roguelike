extends Control

const BattleScene = preload("res://main.tscn")
const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const ForestRandomGenerator = preload("res://scripts/forest_random_generator.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const MapVisuals = preload("res://scripts/map_visuals.gd")
const CardPool = preload("res://scripts/card_pool.gd")
const TeamSynergy = preload("res://scripts/team_synergy.gd")
const VictoryView = preload("res://scripts/forest_victory_view.gd")

signal exploration_finished

var initial_lineup: Array = []
var initial_deck: Array = []
var initial_contract: String = "standard"
var initial_seed: int = -1

const GOLD := MapVisuals.SUN_GOLD
const PANEL_BG := MapVisuals.WALNUT_BG
const PANEL_BORDER := MapVisuals.WALNUT_BORDER

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
var carried_cost: int = ForestRun.START_COST
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

# Core Visual & HUD Nodes
var terrain_rect: TextureRect
var map_canvas: Control
var dice_tray_canvas: Control
var inspect_icon_canvas: Control
var inspect_title_label: Label
var inspect_kind_label: Label
var inspect_status_label: Label
var inspect_desc_label: Label
var journal_label: Label

var hud_team_container: HBoxContainer
var hero_hp_labels: Array[Label] = []
var hero_hp_bars: Array[ProgressBar] = []
var cost_label: Label
var actions_label: Label
var fatigue_label: Label
var alert_label: Label
var intel_label: Label
var destiny_label: Label
var destiny_pill: PanelContainer
var destiny_side_label: Label
var core_badge: Label
var relics_container: HBoxContainer
var items_container: HBoxContainer
var log_label: Label
var roll_dice_button: Button
var end_turn_button: Button
var deck_viewer_button: Button
var restart_button: Button
var opening_lineup_button: Button

# Modal Interaction Panel
var modal_panel: PanelContainer
var modal_title: Label
var modal_desc: Label
var modal_btn_1: Button
var modal_btn_2: Button
var modal_btn_3: Button
var shop_revive_section: VBoxContainer
var shop_revive_buttons: Array[Button] = []
var shop_cards_section: VBoxContainer
var shop_card_buttons: Array[Button] = []
var shop_remove_card_btn: Button
var modal_shop_lineup_btn: Button
var modal_leave_btn: Button

# Destiny Gate Modal Section (matching 命运交互预览)
var destiny_gate_section: VBoxContainer
var destiny_modal_balance_a: Label
var destiny_modal_balance_b: Label
var destiny_claim_title_lbl: Label
var destiny_claim_sub_lbl: Label
var destiny_claim_btn: Button
var destiny_upgrade_rate_lbl: Label
var destiny_upgrade_btn: Button
var destiny_preview_rate_lbl: Label
var destiny_preview_sub_lbl: Label
var destiny_gate_feedback: Label
var destiny_expected_next_tier: int = -1

# Post-Battle 3-Choose-1 Card Reward Modal
var card_reward_panel: PanelContainer
var card_reward_subtitle: Label
var card_reward_container: HBoxContainer
var card_reward_feedback: Label
var card_reward_skip_btn: Button

# Deck Viewer & Shop Card Removal Modal
var deck_viewer_panel: PanelContainer
var deck_viewer_title: Label
var deck_viewer_subtitle: Label
var deck_viewer_grid: GridContainer
var deck_viewer_feedback: Label
var deck_viewer_close_btn: Button
var deck_viewer_remove_mode: bool = false

# Forge Enchant Modal
var forge_enchant_panel: PanelContainer
var forge_enchant_title: Label
var forge_enchant_subtitle: Label
var forge_enchant_close_btn: Button
var forge_card_scroll_box: VBoxContainer
var forge_rune_container: VBoxContainer
var forge_enchant_confirm_btn: Button
var forge_enchant_feedback: Label
var forge_selected_card_idx: int = -1
var forge_selected_rune_id: String = ""
var forge_card_buttons: Array[Button] = []
var forge_rune_buttons: Array[Button] = []

# Item Detail Modal
var item_detail_panel: PanelContainer
var item_detail_art: TextureRect
var item_detail_title: Label
var item_detail_type: Label
var item_detail_desc: Label
var item_detail_use_btn: Button
var item_detail_close_btn: Button

# Next Floor Modal
var next_floor_panel: PanelContainer
var next_floor_shade: ColorRect
var enemy_modifier_buttons := {}
var selected_enemy_modifier := ""
var victory_view: VictoryView
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

const DICE_GLYPHS := ["1", "2", "3", "4"]

# Hovered / selected state
var hovered_node_id: String = ""
var hovered_cell: Vector2i = Vector2i(-1, -1)
var route_target_id: String = ""
var route_preview_path: Array[String] = []
var pulse_time: float = 0.0
var next_map_redraw := 0.0
var is_rolling_dice: bool = false
var dice_anim_elapsed: float = 0.0
var dice_anim_duration: float = 0.42
var dice_anim_step_accum: float = 0.0
var dice_anim_face: int = 1
var dice_prompt_flash: float = 0.0

func _ready() -> void:
	_setup_theme()
	_setup_layout()
	_start_new_run()

func _setup_theme() -> void:
	theme = MapVisuals.create_ember_theme(14)

func _setup_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("241b13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 10)
	root_hbox.offset_left = 10
	root_hbox.offset_right = -10
	root_hbox.offset_top = 10
	root_hbox.offset_bottom = -10
	add_child(root_hbox)

	# === LEFT: Sunlit Forest Map Column (~74% width) ===
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	root_hbox.add_child(left_col)

	left_col.add_child(_build_party_top_bar())

	# Sunlit Map Frame
	var map_frame := PanelContainer.new()
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("1c2419"), MapVisuals.BRASS_GOLD, 2, 10, 2, 2))
	left_col.add_child(map_frame)

	var map_clip := Control.new()
	map_clip.clip_contents = true
	map_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_child(map_clip)

	terrain_rect = TextureRect.new()
	terrain_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	terrain_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terrain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_clip.add_child(terrain_rect)
	_apply_floor_terrain_texture(1)

	map_canvas = Control.new()
	map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_canvas.draw.connect(_on_map_canvas_draw)
	map_canvas.resized.connect(_sync_grid_node_positions)
	map_canvas.gui_input.connect(_on_map_canvas_input)
	map_clip.add_child(map_canvas)

	left_col.add_child(_build_bottom_bar())

	# === RIGHT: Warm Expedition Journal Sidebar ===
	root_hbox.add_child(_build_right_sidebar())

	# Modals
	_build_modal_panel()
	_build_card_reward_modal()
	_build_deck_viewer_modal()
	_build_forge_enchant_modal()
	_build_item_detail_modal()
	_build_next_floor_modal()
	_build_lineup_modal()

	# Battle Return Button
	return_button = Button.new()
	return_button.text = "返回林地探索"
	return_button.visible = false
	return_button.add_theme_font_size_override("font_size", 16)
	return_button.add_theme_color_override("font_color", GOLD)
	return_button.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("3c2b1b"), GOLD, 2, 8, 12, 6))
	return_button.pressed.connect(_return_from_battle)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	return_button.offset_left = -168
	return_button.offset_right = -20
	return_button.offset_top = 16
	return_button.offset_bottom = 56
	add_child(return_button)

func _apply_floor_terrain_texture(floor_level: int) -> void:
	if not is_instance_valid(terrain_rect):
		return
	var floor_png := "res://art/map/terrain_floor_%d.png" % floor_level
	var floor_jpg := "res://art/map/terrain_floor_%d.jpg" % floor_level
	var tex_path := ""
	if ResourceLoader.exists(floor_png):
		tex_path = floor_png
	elif ResourceLoader.exists(floor_jpg):
		tex_path = floor_jpg
	elif ResourceLoader.exists("res://art/forest-terrain-sunlit.jpg"):
		tex_path = "res://art/forest-terrain-sunlit.jpg"
	elif ResourceLoader.exists("res://art/forest-terrain-sunlit.png"):
		tex_path = "res://art/forest-terrain-sunlit.png"
	elif ResourceLoader.exists("res://art/forest-terrain.png"):
		tex_path = "res://art/forest-terrain.png"
	if not tex_path.is_empty():
		terrain_rect.texture = load(tex_path)
	var ftheme := MapVisuals.floor_theme(floor_level)
	terrain_rect.modulate = ftheme.terrain_modulate

func _build_party_top_bar() -> PanelContainer:
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.WALNUT_BORDER, 1, 8, 12, 6))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hud.add_child(hbox)

	var team_title := Label.new()
	team_title.text = "小队"
	team_title.add_theme_font_size_override("font_size", 13)
	team_title.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	hbox.add_child(team_title)

	hud_team_container = HBoxContainer.new()
	hud_team_container.add_theme_constant_override("separation", 10)
	hbox.add_child(hud_team_container)

	hbox.add_child(VSeparator.new())

	var trays_scroll := ScrollContainer.new()
	trays_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trays_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	trays_scroll.follow_focus = true
	hbox.add_child(trays_scroll)

	var trays_box := HBoxContainer.new()
	trays_box.add_theme_constant_override("separation", 10)
	trays_scroll.add_child(trays_box)

	var relic_label := Label.new()
	relic_label.text = "遗物:"
	relic_label.add_theme_font_size_override("font_size", 13)
	relic_label.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT)
	trays_box.add_child(relic_label)

	relics_container = HBoxContainer.new()
	relics_container.add_theme_constant_override("separation", 5)
	trays_box.add_child(relics_container)

	var item_label := Label.new()
	item_label.text = "道具:"
	item_label.add_theme_font_size_override("font_size", 13)
	item_label.add_theme_color_override("font_color", Color("f2a272"))
	trays_box.add_child(item_label)

	items_container = HBoxContainer.new()
	items_container.add_theme_constant_override("separation", 5)
	trays_box.add_child(items_container)
	theme.set_type_variation("ItemShelfButton", "Button")
	theme.set_stylebox("normal", "ItemShelfButton", MapVisuals.make_box(MapVisuals.WALNUT_DEEP, MapVisuals.WALNUT_BORDER, 1, 6, 3, 2))
	theme.set_stylebox("hover", "ItemShelfButton", MapVisuals.make_box(Color("59432c"), GOLD, 1, 6, 3, 2))
	theme.set_stylebox("pressed", "ItemShelfButton", MapVisuals.make_box(Color("695034"), GOLD, 2, 6, 3, 2))
	theme.set_constant("icon_max_width", "ItemShelfButton", 27)

	destiny_pill = PanelContainer.new()
	destiny_pill.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("291f15"), MapVisuals.BRASS_GOLD, 1, 10, 10, 3))
	hbox.add_child(destiny_pill)

	destiny_label = Label.new()
	destiny_label.text = "◆ 命运 0/10 · 正面率 45%"
	destiny_label.add_theme_font_size_override("font_size", 13)
	destiny_label.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	destiny_pill.add_child(destiny_label)

	return hud

func _build_right_sidebar() -> PanelContainer:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(296, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.BRASS_GOLD, 2, 10, 12, 10))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	sidebar.add_child(vbox)

	# 1. Floor Header & Resource Summary
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	floor_badge = Label.new()
	floor_badge.text = "🚩 第 1 层 · 晨雾翠林"
	floor_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floor_badge.add_theme_font_size_override("font_size", 15)
	floor_badge.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	header_row.add_child(floor_badge)

	core_badge = Label.new()
	core_badge.text = "🔥 烬核"
	core_badge.add_theme_font_size_override("font_size", 13)
	core_badge.add_theme_color_override("font_color", Color("ff9f1c"))
	core_badge.visible = false
	header_row.add_child(core_badge)

	var res_panel := PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("271d14"), MapVisuals.WALNUT_BORDER, 1, 7, 10, 6))
	vbox.add_child(res_panel)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 4)
	res_panel.add_child(res_vbox)

	var top_res := HBoxContainer.new()
	top_res.add_theme_constant_override("separation", 10)
	res_vbox.add_child(top_res)

	cost_label = Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	top_res.add_child(cost_label)

	actions_label = Label.new()
	actions_label.add_theme_font_size_override("font_size", 13)
	actions_label.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT)
	top_res.add_child(actions_label)

	var sub_res := HBoxContainer.new()
	sub_res.add_theme_constant_override("separation", 12)
	res_vbox.add_child(sub_res)

	fatigue_label = Label.new()
	fatigue_label.add_theme_font_size_override("font_size", 12)
	sub_res.add_child(fatigue_label)

	alert_label = Label.new()
	alert_label.add_theme_font_size_override("font_size", 12)
	sub_res.add_child(alert_label)

	intel_label = Label.new()
	intel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	intel_label.add_theme_font_size_override("font_size", 12)
	intel_label.add_theme_color_override("font_color", Color("6fd8e6"))
	sub_res.add_child(intel_label)

	destiny_side_label = Label.new()
	destiny_side_label.text = "◆ 命运 0/10  ·  我方拼点正面率 45%"
	destiny_side_label.add_theme_font_size_override("font_size", 12)
	destiny_side_label.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	res_vbox.add_child(destiny_side_label)

	# 2. Sculpted 1d4 Action Dice Tray + Primary Turn Controls
	dice_tray_canvas = Control.new()
	dice_tray_canvas.custom_minimum_size = Vector2(0, 94)
	dice_tray_canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	dice_tray_canvas.draw.connect(_on_dice_tray_draw)
	dice_tray_canvas.gui_input.connect(_on_dice_tray_input)
	vbox.add_child(dice_tray_canvas)

	var turn_btns := HBoxContainer.new()
	turn_btns.add_theme_constant_override("separation", 8)
	vbox.add_child(turn_btns)

	roll_dice_button = Button.new()
	roll_dice_button.text = "🎲 掷行动骰 (1d4)"
	roll_dice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_dice_button.custom_minimum_size = Vector2(0, 36)
	roll_dice_button.pressed.connect(_on_roll_dice_pressed)
	turn_btns.add_child(roll_dice_button)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(88, 36)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	turn_btns.add_child(end_turn_button)

	# 3. Warm Parchment Location Inspection Card
	var inspect_panel := PanelContainer.new()
	inspect_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD, 2, 8, 10, 8))
	vbox.add_child(inspect_panel)

	var inspect_vbox := VBoxContainer.new()
	inspect_vbox.add_theme_constant_override("separation", 5)
	inspect_panel.add_child(inspect_vbox)

	var inspect_head := HBoxContainer.new()
	inspect_head.add_theme_constant_override("separation", 8)
	inspect_vbox.add_child(inspect_head)

	inspect_icon_canvas = Control.new()
	inspect_icon_canvas.custom_minimum_size = Vector2(42, 42)
	inspect_icon_canvas.draw.connect(_on_inspect_icon_draw)
	inspect_head.add_child(inspect_icon_canvas)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	inspect_head.add_child(title_stack)

	inspect_title_label = Label.new()
	inspect_title_label.add_theme_font_size_override("font_size", 15)
	inspect_title_label.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	title_stack.add_child(inspect_title_label)

	inspect_kind_label = Label.new()
	inspect_kind_label.add_theme_font_size_override("font_size", 12)
	inspect_kind_label.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
	title_stack.add_child(inspect_kind_label)

	inspect_status_label = Label.new()
	inspect_status_label.add_theme_font_size_override("font_size", 12)
	inspect_status_label.add_theme_color_override("font_color", Color("336e3b"))
	inspect_vbox.add_child(inspect_status_label)

	inspect_desc_label = Label.new()
	inspect_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_desc_label.custom_minimum_size = Vector2(0, 44)
	inspect_desc_label.add_theme_font_size_override("font_size", 12)
	inspect_desc_label.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	inspect_vbox.add_child(inspect_desc_label)

	# 4. Compact Expedition Journal Feed
	var journal_panel := PanelContainer.new()
	journal_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("271d14"), MapVisuals.WALNUT_BORDER, 1, 7, 9, 7))
	vbox.add_child(journal_panel)

	var j_vbox := VBoxContainer.new()
	j_vbox.add_theme_constant_override("separation", 4)
	journal_panel.add_child(j_vbox)

	var j_title := Label.new()
	j_title.text = "📖 探险手记"
	j_title.add_theme_font_size_override("font_size", 12)
	j_title.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	j_vbox.add_child(j_title)

	journal_label = Label.new()
	journal_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_label.clip_text = true
	journal_label.add_theme_font_size_override("font_size", 11)
	journal_label.add_theme_color_override("font_color", Color("dfd2b5"))
	j_vbox.add_child(journal_label)

	# 5. Sidebar Footer Utility Actions
	deck_viewer_button = Button.new()
	deck_viewer_button.text = "🃏 牌库 (8/20)"
	deck_viewer_button.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	deck_viewer_button.pressed.connect(func() -> void: _open_deck_viewer(false))
	vbox.add_child(deck_viewer_button)

	opening_lineup_button = Button.new()
	opening_lineup_button.text = "👥 开局配队与卡牌"
	opening_lineup_button.pressed.connect(_open_lineup_modal)
	vbox.add_child(opening_lineup_button)

	var footer_btns := HBoxContainer.new()
	footer_btns.add_theme_constant_override("separation", 8)
	vbox.add_child(footer_btns)

	restart_button = Button.new()
	restart_button.text = "重开探索"
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_start_new_run)
	footer_btns.add_child(restart_button)

	var exit_explore_btn := Button.new()
	exit_explore_btn.text = "退出探索"
	exit_explore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_explore_btn.pressed.connect(func() -> void:
		exploration_finished.emit()
		queue_free())
	footer_btns.add_child(exit_explore_btn)

	return sidebar

func _build_bottom_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.WALNUT_BORDER, 1, 7, 12, 6))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	bar.add_child(hbox)

	var tag := Label.new()
	tag.text = "☀"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	hbox.add_child(tag)

	log_label = Label.new()
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	log_label.text = "请先掷出行动骰（1d4）决定本回合可行动步数，沿林间小径探索。"
	hbox.add_child(log_label)

	return bar

func _build_modal_panel() -> void:
	modal_panel = PanelContainer.new()
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_panel.offset_left = -320
	modal_panel.offset_right = 320
	modal_panel.offset_top = -230
	modal_panel.offset_bottom = 230
	modal_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("2d2217"), MapVisuals.SUN_GOLD, 2, 10, 18, 16))
	add_child(modal_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	modal_panel.add_child(vbox)

	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 18)
	modal_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(modal_title)

	modal_desc = Label.new()
	modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_desc.add_theme_font_size_override("font_size", 13)
	modal_desc.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
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

	# Shop Teammate Revival Section (shown only in shop when party members are knocked out)
	shop_revive_section = VBoxContainer.new()
	shop_revive_section.add_theme_constant_override("separation", 6)
	shop_revive_section.visible = false
	btn_box.add_child(shop_revive_section)

	# Shop Card Shelf & Card Removal Section (shown only in shop)
	shop_cards_section = VBoxContainer.new()
	shop_cards_section.add_theme_constant_override("separation", 6)
	shop_cards_section.visible = false
	btn_box.add_child(shop_cards_section)

	var shop_card_hdr := Label.new()
	shop_card_hdr.text = "── 符卡货架（独立交易，不占物资额度） ──"
	shop_card_hdr.add_theme_font_size_override("font_size", 12)
	shop_card_hdr.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	shop_cards_section.add_child(shop_card_hdr)

	var offers_row := HBoxContainer.new()
	offers_row.add_theme_constant_override("separation", 6)
	shop_cards_section.add_child(offers_row)

	shop_card_buttons.clear()
	for i in 3:
		var cbtn := Button.new()
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.custom_minimum_size = Vector2(0, 56)
		cbtn.pressed.connect(_on_shop_buy_card.bind(i))
		offers_row.add_child(cbtn)
		shop_card_buttons.append(cbtn)

	shop_remove_card_btn = Button.new()
	shop_remove_card_btn.text = "✂ 精简牌库 · 移除 1 张符卡（5 cost）"
	shop_remove_card_btn.add_theme_color_override("font_color", Color("ffb5a7"))
	shop_remove_card_btn.pressed.connect(_on_shop_remove_card_pressed)
	shop_cards_section.add_child(shop_remove_card_btn)

	modal_shop_lineup_btn = Button.new()
	modal_shop_lineup_btn.text = "整备队伍 · 调整配队与卡牌"
	modal_shop_lineup_btn.add_theme_color_override("font_color", GOLD)
	modal_shop_lineup_btn.pressed.connect(_open_lineup_modal)
	modal_shop_lineup_btn.visible = false
	btn_box.add_child(modal_shop_lineup_btn)

	_build_destiny_gate_section(btn_box)

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

func _build_destiny_gate_section(parent: VBoxContainer) -> void:
	destiny_gate_section = VBoxContainer.new()
	destiny_gate_section.add_theme_constant_override("separation", 8)
	destiny_gate_section.visible = false
	parent.add_child(destiny_gate_section)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	destiny_gate_section.add_child(cards_row)

	# Left Card: 节点交互 (领取命运 + 强化全队)
	var left_card := PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("241b13"), MapVisuals.WALNUT_BORDER, 1, 10, 12, 10))
	cards_row.add_child(left_card)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left_card.add_child(lv)

	var lh := HBoxContainer.new()
	lv.add_child(lh)

	var lt := Label.new()
	lt.text = "节点交互"
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.add_theme_font_size_override("font_size", 15)
	lt.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	lh.add_child(lt)

	var bal_pill_a := PanelContainer.new()
	bal_pill_a.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("1c150f"), MapVisuals.BRASS_GOLD, 1, 10, 8, 2))
	lh.add_child(bal_pill_a)
	destiny_modal_balance_a = Label.new()
	destiny_modal_balance_a.text = "◆ 命运 0/10"
	destiny_modal_balance_a.add_theme_font_size_override("font_size", 12)
	destiny_modal_balance_a.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	bal_pill_a.add_child(destiny_modal_balance_a)

	lv.add_child(HSeparator.new())

	# Claim Subcard (Parchment)
	var claim_box := PanelContainer.new()
	claim_box.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD, 1, 8, 12, 10))
	lv.add_child(claim_box)

	var claim_h := HBoxContainer.new()
	claim_h.add_theme_constant_override("separation", 8)
	claim_box.add_child(claim_h)

	var claim_text_v := VBoxContainer.new()
	claim_text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_text_v.add_theme_constant_override("separation", 2)
	claim_h.add_child(claim_text_v)

	destiny_claim_title_lbl = Label.new()
	destiny_claim_title_lbl.text = "领取命运 +2"
	destiny_claim_title_lbl.add_theme_font_size_override("font_size", 16)
	destiny_claim_title_lbl.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	claim_text_v.add_child(destiny_claim_title_lbl)

	destiny_claim_sub_lbl = Label.new()
	destiny_claim_sub_lbl.text = "每座门可领取一次"
	destiny_claim_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destiny_claim_sub_lbl.add_theme_font_size_override("font_size", 11)
	destiny_claim_sub_lbl.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
	claim_text_v.add_child(destiny_claim_sub_lbl)

	destiny_claim_btn = Button.new()
	destiny_claim_btn.text = "领取 +2"
	destiny_claim_btn.custom_minimum_size = Vector2(96, 36)
	destiny_claim_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	destiny_claim_btn.pressed.connect(_on_destiny_claim_pressed)
	claim_h.add_child(destiny_claim_btn)

	# Upgrade Subcard (Dark Walnut + Brass Gold)
	var upg_box := PanelContainer.new()
	upg_box.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("1c140d"), MapVisuals.BRASS_GOLD, 1, 8, 12, 10))
	lv.add_child(upg_box)

	var upg_h := HBoxContainer.new()
	upg_h.add_theme_constant_override("separation", 8)
	upg_box.add_child(upg_h)

	var upg_text_v := VBoxContainer.new()
	upg_text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_text_v.add_theme_constant_override("separation", 2)
	upg_h.add_child(upg_text_v)

	var upg_title := Label.new()
	upg_title.text = "强化全队"
	upg_title.add_theme_font_size_override("font_size", 16)
	upg_title.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	upg_text_v.add_child(upg_title)

	var upg_cap := Label.new()
	upg_cap.text = "拼点正面率"
	upg_cap.add_theme_font_size_override("font_size", 11)
	upg_cap.add_theme_color_override("font_color", Color("b8a88c"))
	upg_text_v.add_child(upg_cap)

	destiny_upgrade_rate_lbl = Label.new()
	destiny_upgrade_rate_lbl.text = "45% → 60%"
	destiny_upgrade_rate_lbl.add_theme_font_size_override("font_size", 15)
	destiny_upgrade_rate_lbl.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	upg_text_v.add_child(destiny_upgrade_rate_lbl)

	destiny_upgrade_btn = Button.new()
	destiny_upgrade_btn.text = "花费 2 命运"
	destiny_upgrade_btn.custom_minimum_size = Vector2(110, 40)
	destiny_upgrade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	destiny_upgrade_btn.pressed.connect(_on_destiny_upgrade_pressed)
	upg_h.add_child(destiny_upgrade_btn)

	# Right Card: 下场战斗 (当前正面率预览)
	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("241b13"), MapVisuals.WALNUT_BORDER, 1, 10, 12, 10))
	cards_row.add_child(right_card)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right_card.add_child(rv)

	var rh := HBoxContainer.new()
	rv.add_child(rh)

	var rt := Label.new()
	rt.text = "下场战斗"
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("font_size", 15)
	rt.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	rh.add_child(rt)

	var bal_pill_b := PanelContainer.new()
	bal_pill_b.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("1c150f"), MapVisuals.BRASS_GOLD, 1, 10, 8, 2))
	rh.add_child(bal_pill_b)
	destiny_modal_balance_b = Label.new()
	destiny_modal_balance_b.text = "◆ 命运 0/10"
	destiny_modal_balance_b.add_theme_font_size_override("font_size", 12)
	destiny_modal_balance_b.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
	bal_pill_b.add_child(destiny_modal_balance_b)

	rv.add_child(HSeparator.new())

	var prev_box := PanelContainer.new()
	prev_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev_box.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD, 1, 8, 14, 12))
	rv.add_child(prev_box)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	prev_box.add_child(pv)

	var p_cap := Label.new()
	p_cap.text = "我方拼点硬币正面率"
	p_cap.add_theme_font_size_override("font_size", 13)
	p_cap.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
	pv.add_child(p_cap)

	var rate_row := HBoxContainer.new()
	pv.add_child(rate_row)

	destiny_preview_rate_lbl = Label.new()
	destiny_preview_rate_lbl.text = "45%"
	destiny_preview_rate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destiny_preview_rate_lbl.add_theme_font_size_override("font_size", 32)
	destiny_preview_rate_lbl.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	rate_row.add_child(destiny_preview_rate_lbl)

	var max_lbl := Label.new()
	max_lbl.text = "满级 100%"
	max_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	max_lbl.add_theme_font_size_override("font_size", 12)
	max_lbl.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
	rate_row.add_child(max_lbl)

	pv.add_child(HSeparator.new())

	var p_note1 := Label.new()
	p_note1.text = "全队参与拼点的技能均生效"
	p_note1.add_theme_font_size_override("font_size", 13)
	p_note1.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	pv.add_child(p_note1)

	destiny_preview_sub_lbl = Label.new()
	destiny_preview_sub_lbl.text = "强化跨战斗、跨层与换队员保留"
	destiny_preview_sub_lbl.add_theme_font_size_override("font_size", 11)
	destiny_preview_sub_lbl.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
	pv.add_child(destiny_preview_sub_lbl)

	destiny_gate_feedback = Label.new()
	destiny_gate_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destiny_gate_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destiny_gate_feedback.add_theme_font_size_override("font_size", 12)
	destiny_gate_feedback.add_theme_color_override("font_color", Color("f0d999"))
	destiny_gate_section.add_child(destiny_gate_feedback)

func _build_card_reward_modal() -> void:
	card_reward_panel = PanelContainer.new()
	card_reward_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card_reward_panel.offset_left = -410
	card_reward_panel.offset_right = 410
	card_reward_panel.offset_top = -225
	card_reward_panel.offset_bottom = 225
	card_reward_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("2b2016"), MapVisuals.SUN_GOLD, 2, 12, 20, 16))
	add_child(card_reward_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card_reward_panel.add_child(vbox)

	var title := Label.new()
	title.text = "✨ 战利品符卡 · 三选一"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	card_reward_subtitle = Label.new()
	card_reward_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_reward_subtitle.add_theme_font_size_override("font_size", 13)
	card_reward_subtitle.add_theme_color_override("font_color", Color("dfd2b5"))
	vbox.add_child(card_reward_subtitle)

	card_reward_container = HBoxContainer.new()
	card_reward_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_reward_container.add_theme_constant_override("separation", 12)
	vbox.add_child(card_reward_container)

	card_reward_feedback = Label.new()
	card_reward_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_reward_feedback.add_theme_font_size_override("font_size", 13)
	card_reward_feedback.add_theme_color_override("font_color", Color("ff8c7a"))
	vbox.add_child(card_reward_feedback)

	var footer := CenterContainer.new()
	vbox.add_child(footer)

	card_reward_skip_btn = Button.new()
	card_reward_skip_btn.text = "跳过选卡（折算 +%d cost）" % CardPool.SKIP_REWARD_COST
	card_reward_skip_btn.custom_minimum_size = Vector2(240, 38)
	card_reward_skip_btn.pressed.connect(_on_skip_card_reward_pressed)
	footer.add_child(card_reward_skip_btn)

	card_reward_panel.visible = false

func _build_deck_viewer_modal() -> void:
	deck_viewer_panel = PanelContainer.new()
	deck_viewer_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	deck_viewer_panel.offset_left = -410
	deck_viewer_panel.offset_right = 410
	deck_viewer_panel.offset_top = -255
	deck_viewer_panel.offset_bottom = 255
	deck_viewer_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("2b2016"), MapVisuals.SUN_GOLD, 2, 12, 18, 16))
	add_child(deck_viewer_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	deck_viewer_panel.add_child(vbox)

	var head := HBoxContainer.new()
	vbox.add_child(head)

	deck_viewer_title = Label.new()
	deck_viewer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_viewer_title.add_theme_font_size_override("font_size", 19)
	deck_viewer_title.add_theme_color_override("font_color", GOLD)
	head.add_child(deck_viewer_title)

	deck_viewer_close_btn = Button.new()
	deck_viewer_close_btn.text = "关闭"
	deck_viewer_close_btn.custom_minimum_size = Vector2(84, 34)
	deck_viewer_close_btn.pressed.connect(_close_deck_viewer)
	head.add_child(deck_viewer_close_btn)

	deck_viewer_subtitle = Label.new()
	deck_viewer_subtitle.add_theme_font_size_override("font_size", 13)
	deck_viewer_subtitle.add_theme_color_override("font_color", Color("dfd2b5"))
	vbox.add_child(deck_viewer_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	deck_viewer_grid = GridContainer.new()
	deck_viewer_grid.columns = 3
	deck_viewer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_viewer_grid.add_theme_constant_override("h_separation", 8)
	deck_viewer_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(deck_viewer_grid)

	deck_viewer_feedback = Label.new()
	deck_viewer_feedback.add_theme_font_size_override("font_size", 13)
	deck_viewer_feedback.add_theme_color_override("font_color", Color("ff8c7a"))
	vbox.add_child(deck_viewer_feedback)

	deck_viewer_panel.visible = false

func _build_forge_enchant_modal() -> void:
	forge_enchant_panel = PanelContainer.new()
	forge_enchant_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	forge_enchant_panel.offset_left = -440
	forge_enchant_panel.offset_right = 440
	forge_enchant_panel.offset_top = -260
	forge_enchant_panel.offset_bottom = 260
	forge_enchant_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("261c14"), MapVisuals.SUN_GOLD, 2, 12, 18, 16))
	add_child(forge_enchant_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	forge_enchant_panel.add_child(root_v)

	var head := HBoxContainer.new()
	root_v.add_child(head)

	forge_enchant_title = Label.new()
	forge_enchant_title.text = "⚒ 林野锻台 · 符卡附魔"
	forge_enchant_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_enchant_title.add_theme_font_size_override("font_size", 19)
	forge_enchant_title.add_theme_color_override("font_color", GOLD)
	head.add_child(forge_enchant_title)

	forge_enchant_close_btn = Button.new()
	forge_enchant_close_btn.text = "返回锻台"
	forge_enchant_close_btn.custom_minimum_size = Vector2(88, 34)
	forge_enchant_close_btn.pressed.connect(_close_forge_enchant)
	head.add_child(forge_enchant_close_btn)

	forge_enchant_subtitle = Label.new()
	forge_enchant_subtitle.text = "消耗 4 cost 为一张出战符卡镌刻强力符文；覆盖旧符文无退款，附魔随卡牌跨层继承。"
	forge_enchant_subtitle.add_theme_font_size_override("font_size", 13)
	forge_enchant_subtitle.add_theme_color_override("font_color", Color("dfd2b5"))
	root_v.add_child(forge_enchant_subtitle)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root_v.add_child(cols)

	# Left col: Card list
	var left_v := VBoxContainer.new()
	left_v.custom_minimum_size.x = 410
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 6)
	cols.add_child(left_v)

	var card_header := Label.new()
	card_header.text = "第一步：选择牌库中的出战符卡"
	card_header.add_theme_font_size_override("font_size", 13)
	card_header.add_theme_color_override("font_color", MapVisuals.BRASS_GOLD)
	left_v.add_child(card_header)

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(card_scroll)

	forge_card_scroll_box = VBoxContainer.new()
	forge_card_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_card_scroll_box.add_theme_constant_override("separation", 6)
	card_scroll.add_child(forge_card_scroll_box)

	# Right col: Rune choices
	var right_v := VBoxContainer.new()
	right_v.custom_minimum_size.x = 410
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 6)
	cols.add_child(right_v)

	var rune_header := Label.new()
	rune_header.text = "第二步：选择要镌刻的符文（5 选 1）"
	rune_header.add_theme_font_size_override("font_size", 13)
	rune_header.add_theme_color_override("font_color", MapVisuals.BRASS_GOLD)
	right_v.add_child(rune_header)

	var rune_scroll := ScrollContainer.new()
	rune_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rune_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_v.add_child(rune_scroll)

	forge_rune_container = VBoxContainer.new()
	forge_rune_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_rune_container.add_theme_constant_override("separation", 6)
	rune_scroll.add_child(forge_rune_container)

	# Feedback & confirm button
	forge_enchant_feedback = Label.new()
	forge_enchant_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forge_enchant_feedback.add_theme_font_size_override("font_size", 13)
	forge_enchant_feedback.add_theme_color_override("font_color", Color("f0d999"))
	root_v.add_child(forge_enchant_feedback)

	var foot := CenterContainer.new()
	root_v.add_child(foot)

	forge_enchant_confirm_btn = Button.new()
	forge_enchant_confirm_btn.text = "确认镌刻符文附魔（−4 cost）"
	forge_enchant_confirm_btn.custom_minimum_size = Vector2(280, 36)
	forge_enchant_confirm_btn.pressed.connect(_on_confirm_forge_enchant)
	foot.add_child(forge_enchant_confirm_btn)

	forge_enchant_panel.visible = false

func _build_item_detail_modal() -> void:
	item_detail_panel = PanelContainer.new()
	item_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	item_detail_panel.offset_left = -215
	item_detail_panel.offset_right = 215
	item_detail_panel.offset_top = -135
	item_detail_panel.offset_bottom = 135
	item_detail_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("2d2217"), MapVisuals.SUN_GOLD, 2, 10, 16, 14))
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
	item_detail_type.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT)
	vbox.add_child(item_detail_type)

	vbox.add_child(HSeparator.new())

	var detail_body := HBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 14)
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(detail_body)
	item_detail_art = TextureRect.new()
	item_detail_art.custom_minimum_size = Vector2(116, 116)
	item_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_body.add_child(item_detail_art)

	item_detail_desc = Label.new()
	item_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_detail_desc.add_theme_font_size_override("font_size", 13)
	item_detail_desc.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	item_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_detail_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_body.add_child(item_detail_desc)

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
	next_floor_shade = ColorRect.new()
	next_floor_shade.color = Color(0.08, 0.06, 0.04, 0.65)
	next_floor_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	next_floor_shade.hide()
	add_child(next_floor_shade)

	next_floor_panel = PanelContainer.new()
	next_floor_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	next_floor_panel.offset_left = -420
	next_floor_panel.offset_right = 420
	next_floor_panel.offset_top = -175
	next_floor_panel.offset_bottom = 175
	next_floor_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.SUN_GOLD, 2, 12, 26, 22))
	add_child(next_floor_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	next_floor_panel.add_child(column)

	next_floor_title = Label.new()
	next_floor_title.add_theme_font_size_override("font_size", 28)
	next_floor_title.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	column.add_child(next_floor_title)

	next_floor_desc = Label.new()
	next_floor_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_floor_desc.add_theme_color_override("font_color", MapVisuals.CREAM_TEXT)
	column.add_child(next_floor_desc)
	column.add_child(HSeparator.new())

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	column.add_child(choices)
	var group := ButtonGroup.new()
	for key in ForestRun.ENEMY_MODIFIERS:
		var modifier: Dictionary = ForestRun.ENEMY_MODIFIERS[key]
		var card := Button.new()
		card.text = "%s\n最大生命 +%d%%\n攻击伤害 +%d%%" % [modifier.name, modifier.health, modifier.damage]
		card.custom_minimum_size.y = 120
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.button_group = group
		card.add_theme_stylebox_override("normal", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.BRASS_GOLD))
		card.add_theme_stylebox_override("pressed", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.SUN_GOLD, 3))
		card.add_theme_stylebox_override("hover", MapVisuals.make_box(MapVisuals.PARCHMENT_SOFT, MapVisuals.SUN_GOLD))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			card.add_theme_color_override(color_name, MapVisuals.INK_DARK)
		card.pressed.connect(_select_enemy_modifier.bind(key))
		choices.add_child(card)
		enemy_modifier_buttons[key] = card

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	next_floor_stay_btn = Button.new()
	next_floor_stay_btn.text = "暂留本层"
	next_floor_stay_btn.pressed.connect(_close_next_floor_modal)
	actions.add_child(next_floor_stay_btn)
	next_floor_advance_btn = Button.new()
	next_floor_advance_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(MapVisuals.SUN_GOLD, MapVisuals.BRASS_GOLD))
	next_floor_advance_btn.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	next_floor_advance_btn.pressed.connect(_on_advance_next_floor_pressed)
	actions.add_child(next_floor_advance_btn)
	next_floor_panel.hide()

func _build_lineup_modal() -> void:
	lineup_modal_panel = PanelContainer.new()
	lineup_modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lineup_modal_panel.offset_left = -380
	lineup_modal_panel.offset_right = 380
	lineup_modal_panel.offset_top = -250
	lineup_modal_panel.offset_bottom = 250
	lineup_modal_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("2b2016"), MapVisuals.SUN_GOLD, 2, 10, 16, 14))
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
	sub.add_theme_color_override("font_color", Color("dfd2b5"))
	vbox.add_child(sub)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	# Left: Heroes
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("36281b"), MapVisuals.WALNUT_BORDER, 1, 7, 10, 8))
	columns.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_vbox)

	var left_title := Label.new()
	left_title.text = "出战队员 (1~3人)"
	left_title.add_theme_font_size_override("font_size", 14)
	left_title.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT)
	left_vbox.add_child(left_title)

	var roles_scroll := ScrollContainer.new()
	roles_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(roles_scroll)

	var roles_grid := GridContainer.new()
	roles_grid.columns = 2
	roles_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roles_grid.add_theme_constant_override("h_separation", 6)
	roles_grid.add_theme_constant_override("v_separation", 6)
	roles_scroll.add_child(roles_grid)

	var roster := DemoBattleRules.create_roster()
	lineup_role_buttons.clear()
	for id in roster.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(130, 48)
		btn.text = "%s\n%s" % [roster[id].name, roster[id].role]
		var pressed_box := MapVisuals.make_box(Color("5c4428"), GOLD, 2, 5, 6, 4)
		btn.add_theme_stylebox_override("pressed", pressed_box)
		btn.toggled.connect(_on_lineup_member_toggled.bind(id))
		roles_grid.add_child(btn)
		lineup_role_buttons.append(btn)

	# Right: Cards
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("36281b"), MapVisuals.WALNUT_BORDER, 1, 7, 10, 8))
	columns.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)

	var right_title := Label.new()
	right_title.text = "携带技能符卡"
	right_title.add_theme_font_size_override("font_size", 14)
	right_title.add_theme_color_override("font_color", Color("f2a272"))
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
	lineup_close_btn.pressed.connect(_close_lineup_modal)
	footer.add_child(lineup_close_btn)

	lineup_modal_panel.visible = false

func _open_card_reward_modal() -> void:
	if run == null or run.pending != "card_reward" or run.pending_card_rewards.is_empty():
		return
	card_reward_feedback.text = ""
	card_reward_subtitle.text = "请选择 1 张符卡加入牌库（当前 %d / %d 张），或跳过换取 +%d cost。" % [run.deck.size(), CardPool.MAX_DECK_SIZE, CardPool.SKIP_REWARD_COST]
	for child in card_reward_container.get_children():
		card_reward_container.remove_child(child)
		child.queue_free()

	for idx in run.pending_card_rewards.size():
		var key: String = run.pending_card_rewards[idx]
		var skill: Dictionary = DemoBattleRules.SKILLS.get(key, {})
		var r_col: Color = CardPool.rarity_color(key)
		var r_lbl: String = CardPool.rarity_label(key)
		var cur_copies := CardPool.count_copies(run.deck, key)
		var copy_lim := CardPool.copy_limit(key)
		var cap_res: Dictionary = CardPool.can_add_card(run.deck, key)

		var card_panel := PanelContainer.new()
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_panel.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, r_col, 2, 10, 12, 12))
		card_reward_container.add_child(card_panel)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 6)
		card_panel.add_child(cvbox)

		var top_row := HBoxContainer.new()
		cvbox.add_child(top_row)

		var rar_tag := Label.new()
		rar_tag.text = "【%s】" % r_lbl
		rar_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rar_tag.add_theme_font_size_override("font_size", 12)
		rar_tag.add_theme_color_override("font_color", r_col.darkened(0.28))
		top_row.add_child(rar_tag)

		var cost_tag := Label.new()
		cost_tag.text = "%d cost" % int(skill.get("cost", 0))
		cost_tag.add_theme_font_size_override("font_size", 13)
		cost_tag.add_theme_color_override("font_color", Color("8a5e1d"))
		top_row.add_child(cost_tag)

		var name_lbl := Label.new()
		name_lbl.text = String(skill.get("name", key))
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", MapVisuals.INK_DARK)
		cvbox.add_child(name_lbl)

		var owner_lbl := Label.new()
		owner_lbl.text = "%s · 持有 %d/%d" % [CardPool.card_owner_label(key), cur_copies, copy_lim]
		owner_lbl.add_theme_font_size_override("font_size", 12)
		owner_lbl.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
		cvbox.add_child(owner_lbl)

		cvbox.add_child(HSeparator.new())

		var desc_lbl := Label.new()
		desc_lbl.text = CardPool.card_summary_text(key)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", MapVisuals.INK_DARK)
		cvbox.add_child(desc_lbl)

		var pick_btn := Button.new()
		pick_btn.text = "收入牌库" if cap_res.ok else "已达上限"
		pick_btn.disabled = not cap_res.ok
		pick_btn.tooltip_text = "" if cap_res.ok else String(cap_res.reason)
		pick_btn.custom_minimum_size = Vector2(0, 36)
		if cap_res.ok:
			pick_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("7d551a"), GOLD, 2, 6, 8, 6))
		pick_btn.pressed.connect(_on_claim_card_reward.bind(idx))
		cvbox.add_child(pick_btn)

	modal_panel.hide()
	deck_viewer_panel.hide()
	item_detail_panel.hide()
	card_reward_panel.visible = true
	_refresh_dice_ui()

func _on_claim_card_reward(choice_idx: int) -> void:
	if run == null:
		return
	var res: Dictionary = run.claim_card_reward(choice_idx)
	if not res.get("ok", false):
		card_reward_feedback.text = String(res.get("reason", "无法领取该卡牌"))
		return
	carried_cost = run.carried_cost
	card_reward_panel.hide()
	_refresh_ui()
	if run.floor_cleared:
		_show_next_floor_modal()

func _on_skip_card_reward_pressed() -> void:
	if run == null:
		return
	var res: Dictionary = run.skip_card_reward()
	if not res.get("ok", false):
		return
	carried_cost = run.carried_cost
	card_reward_panel.hide()
	_refresh_ui()
	if run.floor_cleared:
		_show_next_floor_modal()

func _open_deck_viewer(remove_mode: bool = false) -> void:
	if run == null or is_instance_valid(battle):
		return
	deck_viewer_remove_mode = remove_mode
	deck_viewer_feedback.text = ""
	if remove_mode:
		deck_viewer_title.text = "✂ 精简牌库 · 选择 1 张永久移除（%d cost）" % CardPool.REMOVE_CARD_COST
		deck_viewer_subtitle.text = "当前牌库 %d / %d 张（最少保留 %d 张）。点击任意卡牌即支付 %d cost 将其移除。" % [run.deck.size(), CardPool.MAX_DECK_SIZE, CardPool.MIN_DECK_SIZE, CardPool.REMOVE_CARD_COST]
		modal_panel.hide()
	else:
		deck_viewer_title.text = "🃏 当前收集牌库（%d / %d 张）" % [run.deck.size(), CardPool.MAX_DECK_SIZE]
		deck_viewer_subtitle.text = "同名上限：普通 %d 张 · 罕见 %d 张 · 稀有 %d 张。战斗胜利可三选一扩充，行商可购卡或删牌。" % [
			CardPool.RARITY_META[CardPool.RARITY_COMMON].copy_limit,
			CardPool.RARITY_META[CardPool.RARITY_UNCOMMON].copy_limit,
			CardPool.RARITY_META[CardPool.RARITY_RARE].copy_limit,
		]

	for child in deck_viewer_grid.get_children():
		deck_viewer_grid.remove_child(child)
		child.queue_free()

	for idx in run.deck.size():
		var key: String = run.deck[idx]
		var skill: Dictionary = DemoBattleRules.SKILLS.get(key, {})
		var r_col: Color = CardPool.rarity_color(key)
		var card_box := PanelContainer.new()
		card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_box.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.PARCHMENT, r_col, 2, 8, 9, 8))
		deck_viewer_grid.add_child(card_box)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card_box.add_child(vb)

		var hrow := HBoxContainer.new()
		vb.add_child(hrow)

		var n_lbl := Label.new()
		n_lbl.text = "%s" % String(skill.get("name", key))
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.add_theme_font_size_override("font_size", 14)
		n_lbl.add_theme_color_override("font_color", MapVisuals.INK_DARK)
		hrow.add_child(n_lbl)

		var c_lbl := Label.new()
		c_lbl.text = "%d费" % int(skill.get("cost", 0))
		c_lbl.add_theme_font_size_override("font_size", 12)
		c_lbl.add_theme_color_override("font_color", Color("8a5e1d"))
		hrow.add_child(c_lbl)

		var meta_lbl := Label.new()
		meta_lbl.text = "%s · %s" % [CardPool.rarity_label(key), CardPool.card_owner_label(key)]
		meta_lbl.add_theme_font_size_override("font_size", 11)
		meta_lbl.add_theme_color_override("font_color", r_col.darkened(0.30))
		vb.add_child(meta_lbl)

		var inst: Dictionary = run.get_card_instance(idx) if run else {}
		var enchant_id: String = String(inst.get("enchant", ""))
		if not enchant_id.is_empty() and ForestRun.RUNE_META.has(enchant_id):
			var rune_info: Dictionary = ForestRun.RUNE_META[enchant_id]
			var ench_lbl := Label.new()
			ench_lbl.text = "✦ 符文【%s】%s" % [rune_info.name, rune_info.desc]
			ench_lbl.add_theme_font_size_override("font_size", 11)
			ench_lbl.add_theme_color_override("font_color", Color("7b2cbf"))
			vb.add_child(ench_lbl)

		var d_lbl := Label.new()
		d_lbl.text = CardPool.card_summary_text(key)
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", MapVisuals.INK_MUTED)
		vb.add_child(d_lbl)

		if remove_mode:
			var rbtn := Button.new()
			rbtn.text = "移除此卡（−%d cost）" % CardPool.REMOVE_CARD_COST
			var can_rem: Dictionary = CardPool.can_remove_card(run.deck, idx)
			rbtn.disabled = not can_rem.ok or run.carried_cost < CardPool.REMOVE_CARD_COST or run.is_shop_removal_used()
			rbtn.pressed.connect(_on_confirm_remove_card.bind(idx))
			vb.add_child(rbtn)

	deck_viewer_panel.visible = true
	_refresh_dice_ui()

func _close_deck_viewer() -> void:
	var was_remove := deck_viewer_remove_mode
	deck_viewer_remove_mode = false
	deck_viewer_panel.hide()
	if was_remove and run != null and run.pending == "shop":
		_open_modal("shop")
	_refresh_ui()

func _on_confirm_remove_card(deck_idx: int) -> void:
	if run == null:
		return
	var res: Dictionary = run.shop_remove_card(deck_idx)
	if not res.get("ok", false):
		deck_viewer_feedback.text = String(res.get("reason", "无法移除该卡牌"))
		return
	carried_cost = run.carried_cost
	deck_viewer_remove_mode = false
	deck_viewer_panel.hide()
	if run.pending == "shop":
		_open_modal("shop")
	_refresh_ui()

func _on_shop_buy_card(offer_idx: int) -> void:
	if run == null:
		return
	var res: Dictionary = run.shop_buy_card(offer_idx)
	if res.get("ok", false):
		carried_cost = run.carried_cost
		_open_modal("shop")
		_refresh_ui()
	else:
		modal_desc.text = String(res.get("reason", "无法购买该卡牌"))

func _on_shop_remove_card_pressed() -> void:
	if run == null or run.pending != "shop":
		return
	_open_deck_viewer(true)

func _open_forge_enchant_modal() -> void:
	if run == null:
		return
	forge_selected_card_idx = -1
	forge_selected_rune_id = ""
	_refresh_forge_enchant_ui()
	forge_enchant_panel.visible = true

func _close_forge_enchant() -> void:
	forge_enchant_panel.hide()
	if run != null and run.pending == "forge":
		_open_modal("forge")

func _refresh_forge_enchant_ui() -> void:
	for child in forge_card_scroll_box.get_children():
		forge_card_scroll_box.remove_child(child)
		child.queue_free()
	for child in forge_rune_container.get_children():
		forge_rune_container.remove_child(child)
		child.queue_free()

	forge_card_buttons.clear()
	forge_rune_buttons.clear()

	var avail_cards: Array = DemoBattleRules.available_cards(run.lineup)
	for idx in run.deck.size():
		var key: String = run.deck[idx]
		var skill: Dictionary = DemoBattleRules.SKILLS.get(key, {})
		var cname: String = String(skill.get("name", key))
		var r_label: String = CardPool.rarity_label(key)
		var r_col: Color = CardPool.rarity_color(key)
		var owner_lbl: String = CardPool.card_owner_label(key)
		var inst: Dictionary = run.get_card_instance(idx)
		var current_rune: String = String(inst.get("enchant", ""))
		var rune_badge: String = "【%s】" % ForestRun.RUNE_META[current_rune].name if ForestRun.RUNE_META.has(current_rune) else "【未附魔】"

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 42
		btn.text = "%d. %s (%d费·%s·%s)  %s" % [idx + 1, cname, int(skill.get("cost", 0)), r_label, owner_lbl, rune_badge]
		btn.disabled = not avail_cards.has(key)
		var is_selected: bool = idx == forge_selected_card_idx
		var box := MapVisuals.make_box(Color("38291b") if is_selected else Color("1e1610"), MapVisuals.SUN_GOLD if is_selected else r_col, 2 if is_selected else 1, 6, 8, 6)
		btn.add_theme_stylebox_override("normal", box)
		btn.pressed.connect(_on_forge_card_selected.bind(idx))
		forge_card_scroll_box.add_child(btn)
		forge_card_buttons.append(btn)

	for rune_id in ForestRun.VALID_RUNES:
		var rmeta: Dictionary = ForestRun.RUNE_META[rune_id]
		var rbtn := Button.new()
		rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rbtn.custom_minimum_size.y = 44
		rbtn.text = "【%s】%s" % [rmeta.name, rmeta.desc]
		var is_selected: bool = rune_id == forge_selected_rune_id
		var box := MapVisuals.make_box(Color("3b253b") if is_selected else Color("1f1320"), Color("c77dff") if is_selected else Color("5a3d60"), 2 if is_selected else 1, 6, 8, 6)
		rbtn.add_theme_stylebox_override("normal", box)
		rbtn.pressed.connect(_on_forge_rune_selected.bind(rune_id))
		forge_rune_container.add_child(rbtn)
		forge_rune_buttons.append(rbtn)

	_update_forge_confirm_state()

func _on_forge_card_selected(idx: int) -> void:
	forge_selected_card_idx = idx
	_refresh_forge_enchant_ui()

func _on_forge_rune_selected(rune_id: String) -> void:
	forge_selected_rune_id = rune_id
	_refresh_forge_enchant_ui()

func _update_forge_confirm_state() -> void:
	var can_enchant := false
	if forge_selected_card_idx >= 0 and not forge_selected_rune_id.is_empty():
		var check_res := run.can_forge_enchant(forge_selected_card_idx, forge_selected_rune_id)
		if check_res.ok:
			can_enchant = true
			var key: String = run.deck[forge_selected_card_idx]
			var cname: String = DemoBattleRules.SKILLS[key].name if DemoBattleRules.SKILLS.has(key) else key
			var rmeta: Dictionary = ForestRun.RUNE_META[forge_selected_rune_id]
			forge_enchant_feedback.text = "将为【%s】附魔【%s】符文：%s（消耗 %d cost，当前结余 %d cost）。" % [cname, rmeta.name, rmeta.desc, ForestRun.FORGE_ENCHANT_COST, run.carried_cost]
			forge_enchant_feedback.add_theme_color_override("font_color", Color("b8f2e6"))
		else:
			forge_enchant_feedback.text = check_res.reason
			forge_enchant_feedback.add_theme_color_override("font_color", Color("ff8c7a"))
	elif forge_selected_card_idx < 0:
		forge_enchant_feedback.text = "请在左侧选择一张出战符卡。"
		forge_enchant_feedback.add_theme_color_override("font_color", Color("dfd2b5"))
	else:
		forge_enchant_feedback.text = "请在右侧选择要镌刻的符文效果。"
		forge_enchant_feedback.add_theme_color_override("font_color", Color("dfd2b5"))

	forge_enchant_confirm_btn.disabled = not can_enchant or run.carried_cost < ForestRun.FORGE_ENCHANT_COST

func _on_confirm_forge_enchant() -> void:
	if run == null:
		return
	var res := run.forge_enchant_card(forge_selected_card_idx, forge_selected_rune_id)
	if res.ok:
		forge_enchant_panel.hide()
		_refresh_ui()
	else:
		forge_enchant_feedback.text = res.reason
		forge_enchant_feedback.add_theme_color_override("font_color", Color("ff8c7a"))

func _show_item_detail(item_id: String, item_idx: int) -> void:
	var info: Dictionary = RelicSystem.get_consumable(item_id)
	item_detail_art.texture = RelicSystem.get_item_art(item_id)
	item_detail_art.visible = item_detail_art.texture != null
	item_detail_title.text = info.get("name", item_id)
	item_detail_type.text = "【战术消耗品】"
	item_detail_desc.text = info.get("description", "")

	if item_id in ["field_poultice", "echo_pendulum", "phoenix_feather", "clarity_elixir", "gambler_die"]:
		item_detail_use_btn.visible = true
		match item_id:
			"field_poultice":
				item_detail_use_btn.text = "使用野战膏药（恢复 12 生命）"
			"echo_pendulum":
				item_detail_use_btn.text = "使用回响灵摆（疲劳 -2 · +3 Cost）"
			"phoenix_feather":
				item_detail_use_btn.text = "使用凤凰尾羽（复活队员 / 恢复 16 生命）"
			"clarity_elixir":
				item_detail_use_btn.text = "使用澄明甘露（疲劳归零 · +4 Cost）"
			"gambler_die":
				item_detail_use_btn.text = "投掷命运秘骰（单数 +6 Cost · 双数 +2 命运）"
		var callables = item_detail_use_btn.pressed.get_connections()
		for c in callables:
			item_detail_use_btn.pressed.disconnect(c.callable)
		item_detail_use_btn.pressed.connect(_use_item_in_exploration.bind(item_id, item_idx))
	else:
		item_detail_use_btn.visible = false
		item_detail_desc.text += "\n\n进入战斗后，在右上角点「道具」，再点对应道具的「使用」。"
	item_detail_panel.visible = true

func _show_relic_detail(relic_id: String) -> void:
	var info: Dictionary = RelicSystem.get_relic(relic_id)
	item_detail_art.texture = null
	item_detail_art.hide()
	item_detail_title.text = "%s %s" % [info.get("icon", "✧"), info.get("name", relic_id)]
	item_detail_type.text = "【被动遗物】稀有度: %s" % info.get("rarity", "common")
	item_detail_desc.text = "%s\n\n✨ 全局被动常驻生效（可在所有遭遇与战斗中发挥效力）。" % info.get("description", "")
	item_detail_use_btn.visible = false
	item_detail_panel.visible = true

func _use_item_in_exploration(item_id: String, item_idx: int) -> void:
	if run == null or item_idx < 0 or item_idx >= run.items.size() or run.items[item_idx] != item_id:
		return
	if item_id == "field_poultice":
		var restored := run.heal_lowest_hero(12)
		if restored == 0:
			item_detail_desc.text = "存活队员的生命已满。"
			return
		run.items.remove_at(item_idx)
		for i in run.party_hp.size():
			if i < carried_hp.size():
				carried_hp[i] = run.party_hp[i]
		run.log_event("使用野战膏药，恢复 %d 生命。" % restored)
		item_detail_panel.visible = false
		_refresh_ui()
	elif item_id == "echo_pendulum":
		run.items.remove_at(item_idx)
		run.fatigue = maxi(0, run.fatigue - 2)
		run.carried_cost += 3
		carried_cost = run.carried_cost
		run.log_event("使用回响灵摆：疲劳 −2，获得 3 cost。")
		item_detail_panel.visible = false
		_refresh_ui()
	elif item_id == "phoenix_feather":
		var dead := run.get_dead_hero_slots()
		run.items.remove_at(item_idx)
		if not dead.is_empty():
			run.revive_hero_with_feather(dead[0], 0.30)
		else:
			run.heal_lowest_hero(16)
			run.log_event("使用凤凰尾羽：圣光沐浴，伤势最重队员恢复 16 生命。")
		for i in run.party_hp.size():
			if i < carried_hp.size():
				carried_hp[i] = run.party_hp[i]
		item_detail_panel.visible = false
		_refresh_ui()
	elif item_id == "clarity_elixir":
		run.items.remove_at(item_idx)
		run.fatigue = 0
		run.carried_cost += 4
		carried_cost = run.carried_cost
		run.log_event("使用澄明甘露：疲劳完全消除，获得 4 cost。")
		item_detail_panel.visible = false
		_refresh_ui()
	elif item_id == "gambler_die":
		run.items.remove_at(item_idx)
		var d := (randi() % 6) + 1
		if d % 2 == 1:
			run.carried_cost += 6
			carried_cost = run.carried_cost
			run.log_event("掷出命运秘骰【%d 点 · 奇数】：探险收获 6 cost！" % d)
		else:
			run.destiny = mini(ForestRun.DESTINY_MAX, run.destiny + 2)
			run.log_event("掷出命运秘骰【%d 点 · 偶数】：命运指针跳动，命运 +2！" % d)
		item_detail_panel.visible = false
		_refresh_ui()

func _on_shop_revive_pressed(slot_idx: int) -> void:
	if run == null:
		return
	var res := run.shop_revive_hero(slot_idx)
	if res.get("ok", false):
		carried_cost = run.carried_cost
		for i in run.party_hp.size():
			if i < carried_hp.size():
				carried_hp[i] = run.party_hp[i]
		_open_modal("shop")
		_refresh_ui()

func shop_revive_hero(slot_idx: int) -> Dictionary:
	if run == null:
		return {"ok": false}
	var res := run.shop_revive_hero(slot_idx)
	if res.get("ok", false):
		carried_cost = run.carried_cost
		for i in run.party_hp.size():
			if i < carried_hp.size():
				carried_hp[i] = run.party_hp[i]
		_refresh_ui()
	return res

func _show_next_floor_modal() -> void:
	if run == null or not run.floor_cleared or run.finished or run.floor_level >= ForestRun.MAX_FLOOR:
		return
	selected_enemy_modifier = ""
	for card in enemy_modifier_buttons.values():
		card.set_pressed_no_signal(false)
	next_floor_title.text = "第 %d 层已突破" % run.floor_level
	next_floor_desc.text = "选择一项敌方强化，才能进入第 %d 层。强化会叠加到之后每一场探索战斗。" % (run.floor_level + 1)
	next_floor_advance_btn.text = "确认 · 进入第 %d 层" % (run.floor_level + 1)
	next_floor_advance_btn.disabled = true
	next_floor_shade.show()
	next_floor_panel.show()
	enemy_modifier_buttons.values()[0].grab_focus()

func _close_next_floor_modal() -> void:
	next_floor_panel.hide()
	next_floor_shade.hide()

func _select_enemy_modifier(key: String) -> void:
	if next_floor_panel.visible and run != null and run.can_advance_to_next_floor(key):
		selected_enemy_modifier = key
		next_floor_advance_btn.disabled = false

func _on_advance_next_floor_pressed() -> void:
	if run == null or not run.can_advance_to_next_floor(selected_enemy_modifier):
		return
	var new_seed := int(Time.get_unix_time_from_system() * 1000) ^ randi()
	var new_map: ForestMapGraph = ForestRandomGenerator.generate_grid(new_seed, run.floor_level + 1)
	if not run.advance_to_next_floor(new_map, new_seed, selected_enemy_modifier):
		return
	selected_enemy_modifier = ""
	is_rolling_dice = false
	dice_anim_elapsed = 0.0
	dice_prompt_flash = 0.0
	hovered_node_id = ""
	hovered_cell = Vector2i(-1, -1)
	route_target_id = ""
	route_preview_path.clear()
	carried_hp.assign(run.party_hp)
	carried_cost = run.carried_cost
	_close_next_floor_modal()
	_apply_floor_terrain_texture(run.floor_level)
	_rebuild_team_hud()
	_refresh_ui()

func _show_expedition_victory() -> void:
	if is_instance_valid(victory_view):
		return
	victory_view = VictoryView.new()
	victory_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_view.cleared_floors = run.floor_level
	victory_view.total_floors = ForestRun.MAX_FLOOR
	victory_view.modifier_count = run.enemy_modifiers.size()
	victory_view.menu_requested.connect(_return_from_victory)
	add_child(victory_view)

func _return_from_victory() -> void:
	if exploration_finished.get_connections().is_empty():
		get_tree().change_scene_to_file("res://battle_setup.tscn")
	else:
		exploration_finished.emit()

func _at_run_start() -> bool:
	return run != null and run.floor_level == 1 and run.turn == 1 and run.position == run.map.start_id and run.travelled.is_empty() and run.pending.is_empty() and not run.finished

func _can_edit_lineup() -> bool:
	return run != null and not is_instance_valid(battle) and not run.in_battle and (_at_run_start() or run.pending == "shop")

func _collected_cards_for_members(members: Array) -> Array[String]:
	var pool: Array[String] = []
	var available: Array = DemoBattleRules.available_cards(members)
	for k in run.deck:
		var key := String(k)
		if available.has(key):
			pool.append(key)
	for id in members:
		var hero_id := int(id)
		var starters: Array = CardPool.HERO_STARTER_CARDS.get(hero_id, [])
		for c in starters:
			var starter := String(c)
			if not starter.is_empty() and available.has(starter) and not pool.has(starter):
				pool.append(starter)
	return pool

func _open_lineup_modal() -> void:
	if is_rolling_dice or not _can_edit_lineup():
		return
	edit_members = run.lineup.duplicate()
	edit_omitted.clear()
	_refresh_lineup_modal()
	modal_panel.hide()
	item_detail_panel.hide()
	deck_viewer_panel.hide()
	lineup_modal_panel.visible = true
	roll_dice_button.disabled = true
	end_turn_button.disabled = true

func _close_lineup_modal() -> void:
	lineup_modal_panel.hide()
	if run != null and run.pending == "shop":
		_open_modal("shop")
	_refresh_ui()

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
		lineup_card_container.remove_child(child)
		child.queue_free()

	var collected := _collected_cards_for_members(edit_members)
	var unique_keys: Array[String] = []
	for k in collected:
		if not unique_keys.has(k):
			unique_keys.append(k)
	for owner in [-1] + edit_members:
		var owner_keys := unique_keys.filter(func(k: String) -> bool: return DemoBattleRules.card_owner(k) == owner)
		if owner_keys.is_empty():
			continue
		var sec_lbl := Label.new()
		sec_lbl.text = "── 全队通用 ──" if owner == -1 else "── %s 专属 ──" % roster[owner].name
		sec_lbl.add_theme_font_size_override("font_size", 12)
		sec_lbl.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT if owner == -1 else Color("7ed9e6"))
		lineup_card_container.add_child(sec_lbl)
		for key in owner_keys:
			var skill: Dictionary = DemoBattleRules.SKILLS[key]
			var copies := CardPool.count_copies(collected, key)
			var cb := CheckBox.new()
			var qty_txt := " ×%d" % copies if copies > 1 else ""
			cb.text = "%s%s  (%d cost · %s)" % [skill.get("name", key), qty_txt, skill.get("cost", 0), CardPool.rarity_label(key)]
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

func _selected_lineup_deck() -> Array[String]:
	var result: Array[String] = []
	for k in _collected_cards_for_members(edit_members):
		if not edit_omitted.has(k):
			result.append(k)
	return result

func _update_lineup_modal_summary() -> void:
	var selected_cards := _selected_lineup_deck()
	var count := selected_cards.size()
	var has_living_member := run.has_living_member(edit_members)
	lineup_save_btn.disabled = not has_living_member or count == 0
	if not has_living_member:
		lineup_summary_label.text = "请至少选择一名存活的出战队员"
	elif count == 0:
		lineup_summary_label.text = "请至少勾选一张已收集卡牌"
	else:
		lineup_summary_label.text = "出战 %d 人  ·  已收集牌库 %d/%d 张" % [edit_members.size(), count, CardPool.MAX_DECK_SIZE]

func _on_lineup_save_pressed() -> void:
	if not _can_edit_lineup() or not run.has_living_member(edit_members):
		return
	var selected_cards := _selected_lineup_deck()
	if selected_cards.is_empty():
		return
	run.set_lineup_and_deck(edit_members, selected_cards)
	carried_hp.clear()
	for hp in run.party_hp:
		carried_hp.append(hp)
	_rebuild_team_hud()
	_close_lineup_modal()

func _start_new_run() -> void:
	_close_next_floor_modal()
	if is_instance_valid(victory_view):
		victory_view.queue_free()
		victory_view = null
	if is_instance_valid(battle):
		battle.queue_free()
		battle = null
	is_rolling_dice = false
	dice_anim_elapsed = 0.0
	dice_prompt_flash = 0.0
	hovered_node_id = ""
	hovered_cell = Vector2i(-1, -1)
	route_target_id = ""
	route_preview_path.clear()
	return_button.visible = false
	lineup_modal_panel.hide()
	modal_panel.hide()
	card_reward_panel.hide()
	deck_viewer_panel.hide()
	deck_viewer_remove_mode = false
	if is_instance_valid(destiny_gate_feedback):
		destiny_gate_feedback.text = ""

	var seed_val := initial_seed if initial_seed >= 0 else (int(Time.get_unix_time_from_system() * 1000) ^ randi())
	var map: ForestMapGraph = ForestRandomGenerator.generate_floor1_grid(seed_val)
	run = ForestRun.new()
	if not initial_lineup.is_empty():
		run.initialize(map, 0, ["mercury_die"], ["field_poultice", "dense_smoke"], seed_val, initial_lineup, initial_deck)
	else:
		run.initialize(map, 0, ["mercury_die"], ["field_poultice", "dense_smoke"], seed_val)
	if initial_contract != "standard":
		run.apply_contract(initial_contract)

	carried_hp.clear()
	for hp in run.party_hp:
		carried_hp.append(hp)
	carried_cost = run.carried_cost
	_apply_floor_terrain_texture(run.floor_level)

	_rebuild_team_hud()
	_refresh_ui()

func _rebuild_team_hud() -> void:
	for child in hud_team_container.get_children():
		child.queue_free()
	hero_hp_labels.clear()
	hero_hp_bars.clear()

	var hero_colors := [Color("f0bd65"), Color("78cad2"), Color("99d17b")]
	for i in run.party_names.size():
		var chip := VBoxContainer.new()
		chip.custom_minimum_size = Vector2(96, 30)
		chip.add_theme_constant_override("separation", 3)
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
		bar.add_theme_stylebox_override("background", MapVisuals.make_box(Color("1e160f"), Color.TRANSPARENT, 0, 3, 0, 0))
		bar.add_theme_stylebox_override("fill", MapVisuals.make_box(hero_colors[i % hero_colors.size()], Color.TRANSPARENT, 0, 3, 0, 0))
		chip.add_child(bar)
		hero_hp_bars.append(bar)
	var syn_text := TeamSynergy.compact_badges(run.lineup)
	if not syn_text.is_empty():
		var syn_pill := PanelContainer.new()
		syn_pill.add_theme_stylebox_override("panel", MapVisuals.make_box(Color("3b2c1d"), MapVisuals.BRASS_GOLD, 1, 6, 8, 3))
		syn_pill.tooltip_text = TeamSynergy.summary_line(run.lineup)
		var syn_lbl := Label.new()
		syn_lbl.text = syn_text
		syn_lbl.add_theme_font_size_override("font_size", 11)
		syn_lbl.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
		syn_pill.add_child(syn_lbl)
		hud_team_container.add_child(syn_pill)

func _process(delta: float) -> void:
	if is_instance_valid(victory_view):
		return
	if is_instance_valid(battle):
		return_button.visible = not battle.busy and not battle.battle.outcome.is_empty()
		return
	if not is_visible_in_tree():
		return
	pulse_time += delta
	if dice_prompt_flash > 0.0:
		dice_prompt_flash = maxf(0.0, dice_prompt_flash - delta * 2.0)
	if is_rolling_dice:
		dice_anim_elapsed += delta
		dice_anim_step_accum += delta
		if dice_anim_step_accum >= 0.06:
			dice_anim_step_accum = 0.0
			dice_anim_face = (dice_anim_face % ForestRun.DICE_MAX) + 1
			_refresh_dice_ui()
		if dice_anim_elapsed >= dice_anim_duration:
			is_rolling_dice = false
			dice_anim_elapsed = 0.0
			dice_anim_step_accum = 0.0
			if run != null and run.can_roll_action_dice():
				run.roll_action_dice()
			_refresh_ui()
	var redraw_ambient := pulse_time >= next_map_redraw
	if redraw_ambient:
		next_map_redraw = pulse_time + 1.0 / 20.0
		map_canvas.queue_redraw()
	if is_rolling_dice or (redraw_ambient and run != null and run.can_roll_action_dice()):
		dice_tray_canvas.queue_redraw()

func _inspected_node() -> ForestMapGraph.MapNode:
	if run == null or run.map == null:
		return null
	if not hovered_node_id.is_empty() and run.known.has(hovered_node_id):
		return run.map.get_node(hovered_node_id)
	if not route_target_id.is_empty() and run.known.has(route_target_id):
		return run.map.get_node(route_target_id)
	return run.map.get_node(run.position)

func _on_inspect_icon_draw() -> void:
	var n := _inspected_node()
	if n == null:
		return
	var c := inspect_icon_canvas.size * 0.5
	var accent := ForestMapGraph.kind_color(n.kind)
	inspect_icon_canvas.draw_circle(c, 19.0, MapVisuals.WALNUT_DEEP)
	inspect_icon_canvas.draw_circle(c, 17.5, accent)
	inspect_icon_canvas.draw_circle(c, 14.5, Color("fffaf0"))
	MapVisuals.draw_node_emblem(inspect_icon_canvas, n.kind, c, 10.5, accent.darkened(0.2), false)

func _on_dice_tray_draw() -> void:
	if run == null:
		return
	MapVisuals.draw_dice_tray(dice_tray_canvas, run, is_rolling_dice, dice_anim_face, pulse_time, get_theme_default_font())

func _on_dice_tray_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_roll_dice_pressed()

func _sync_grid_node_positions() -> void:
	if run == null or run.map == null or not run.map.is_grid or not is_instance_valid(map_canvas):
		return
	var rect := map_canvas.get_rect()
	if rect.size.x <= 10.0 or rect.size.y <= 10.0:
		return
	var layout := MapVisuals.compute_grid_layout(rect, run.map.grid_size)
	for node in run.map.nodes.values():
		var n := node as ForestMapGraph.MapNode
		if n.cell.x >= 0 and n.cell.y >= 0:
			var center := MapVisuals.grid_cell_center(layout, n.cell)
			n.pos = Vector2(center.x / rect.size.x, center.y / rect.size.y)

func _on_map_canvas_draw() -> void:
	if run == null or run.map == null:
		return
	var rect := map_canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y
	if w <= 10 or h <= 10:
		return
	var font := get_theme_default_font()

	# 1. Sunlit morning atmosphere (sunbeams, framing vignette, pollen & leaves)
	MapVisuals.draw_sunlit_atmosphere(map_canvas, rect, pulse_time, run.floor_level)

	if run.map.is_grid:
		var active_route: Array = []
		if not hovered_node_id.is_empty() and hovered_node_id != run.position and run.known.has(hovered_node_id):
			var h_route := run.preview_route_to(hovered_node_id)
			if h_route.ok and int(h_route.steps) >= 2:
				active_route = h_route.path
		if active_route.is_empty() and not route_target_id.is_empty() and route_target_id != run.position and run.known.has(route_target_id):
			var r_info := run.preview_route_to(route_target_id)
			if r_info.ok and int(r_info.steps) >= 1:
				active_route = r_info.path
		MapVisuals.draw_grid_map(map_canvas, run, rect, hovered_cell, active_route, pulse_time, font)
	else:
		# 2. Soft airy cream-white morning mist clouds over unexplored nodes
		MapVisuals.draw_morning_mist(map_canvas, run, w, h, pulse_time, run.floor_level)

		# 3. High-contrast cartographic trails & animated footsteps
		MapVisuals.draw_map_edges(map_canvas, run, w, h, pulse_time, font)

		# 4. Patrol tracks & noise ripple signals
		MapVisuals.draw_patrol_signals(map_canvas, run, w, h, pulse_time, font)

		# 5. Medallion nodes (draw unknown first, known/current on top for clean layering)
		var ordered_nodes: Array = []
		for node in run.map.nodes.values():
			ordered_nodes.append(node)
		ordered_nodes.sort_custom(func(a, b) -> bool:
			var pa := 2 if a.id == run.position else (1 if run.known.has(a.id) else 0)
			var pb := 2 if b.id == run.position else (1 if run.known.has(b.id) else 0)
			return pa < pb)
		for node in ordered_nodes:
			var n := node as ForestMapGraph.MapNode
			var pos := Vector2(n.pos.x * w, n.pos.y * h)
			MapVisuals.draw_map_node(map_canvas, n, run, pos, n.id == hovered_node_id, pulse_time, font)

		# 6. Patrol beast marker when inside sight
		if run.is_patrol_visible():
			var p_node = run.map.get_node(run.patrol_node)
			if p_node != null:
				var p_pos := Vector2(p_node.pos.x * w, p_node.pos.y * h)
				MapVisuals.draw_patrol_beast(map_canvas, p_pos, pulse_time, font)

	# 7. Compact sunlit dice prompt pill at top of map when unrolled or rolling
	if not is_instance_valid(battle) and (is_rolling_dice or run.can_roll_action_dice()):
		var banner_text := ""
		if is_rolling_dice:
			banner_text = "🎲 行动骰翻滚中  [ %s ]" % DICE_GLYPHS[clampi(dice_anim_face - 1, 0, DICE_GLYPHS.size() - 1)]
		else:
			var penalty_hint := "（高疲劳 −1，保底 1 步）" if run.fatigue >= ForestRun.FATIGUE_PENALTY_THRESHOLD else ""
			banner_text = "🎲 第 %d 回合：点击右侧行动骰盘掷出本回合步数%s" % [run.turn, penalty_hint]
		var banner_size := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		var pill_w := banner_size.x + 32.0
		var pill_h := 26.0 if run.map.is_grid else 30.0
		var pill_y := 6.0 if run.map.is_grid else 10.0
		var pill_rect := Rect2((w - pill_w) * 0.5, pill_y, pill_w, pill_h)
		var border_col := MapVisuals.SUN_GOLD.lerp(Color("ff7b00"), dice_prompt_flash)
		map_canvas.draw_rect(pill_rect, Color(MapVisuals.WALNUT_DEEP, 0.88), true)
		map_canvas.draw_rect(pill_rect, border_col, false, 2.0)
		map_canvas.draw_string(font, Vector2(pill_rect.position.x + 16.0, pill_rect.position.y + (18.0 if run.map.is_grid else 20.0)), banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MapVisuals.CREAM_TEXT)

func _on_map_canvas_input(event: InputEvent) -> void:
	if run == null or run.map == null:
		return
	var rect := map_canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y

	if run.map.is_grid:
		var layout := MapVisuals.compute_grid_layout(rect, run.map.grid_size)
		if event is InputEventMouseMotion:
			var cell := MapVisuals.grid_cell_at_point(layout, event.position, run.map.grid_size)
			var found_id := ""
			if cell.x >= 0:
				var nid: String = run.map.node_id_at(cell)
				if not nid.is_empty() and run.known.has(nid):
					found_id = nid
			if cell != hovered_cell or found_id != hovered_node_id:
				hovered_cell = cell
				hovered_node_id = found_id
				if cell.x >= 0:
					var clbl := ForestMapGraph.cell_label(cell)
					var is_known_c: bool = run.known_cells.has(cell) or (not found_id.is_empty() and run.known.has(found_id))
					if not is_known_c:
						map_canvas.tooltip_text = "%s（迷雾未探索）" % clbl
					elif run.map.is_obstacle(cell):
						map_canvas.tooltip_text = "%s（%s）" % [clbl, "树林障碍 · 不可通行" if run.map.obstacle_kind(cell) == "trees" else "水域障碍 · 不可通行"]
					elif not found_id.is_empty():
						var h_node = run.map.get_node(found_id)
						var tip_line := ""
						if found_id == run.position:
							if h_node.kind == ForestMapGraph.NodeKind.SHOP and not run.finished:
								tip_line = "点击打开商店，可调整配队与卡牌。"
							elif h_node.kind == ForestMapGraph.NodeKind.DESTINY_GATE and not run.finished:
								tip_line = "点击打开命运石之门，可领取命运或强化全队。"
							else:
								tip_line = "当前所在位置"
						elif run.can_move(found_id):
							tip_line = "可前往（点击消耗 1 步）"
						else:
							var r_info := run.preview_route_to(found_id)
							if r_info.ok and int(r_info.steps) >= 2:
								tip_line = "路线 %d 步%s（点击查看路线，需逐格前行）" % [int(r_info.steps), (" · 抵达后余 %d 步" % int(r_info.remaining)) if r_info.can_reach_this_turn else ""]
							else:
								tip_line = run.cell_move_error(cell)
						map_canvas.tooltip_text = "%s · %s (%s)\n%s" % [clbl, h_node.name, ForestMapGraph.kind_title(h_node.kind), tip_line]
				else:
					map_canvas.tooltip_text = ""
				_refresh_inspection_card()
				map_canvas.queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var click_pos: Vector2 = event.position
			var cell := MapVisuals.grid_cell_at_point(layout, click_pos, run.map.grid_size)
			if cell.x >= 0:
				_handle_grid_cell_clicked(cell)
			else:
				# Legacy normalized-pos click fallback (for tests clicking node.pos * map_canvas.size)
				for node in run.map.nodes.values():
					var n := node as ForestMapGraph.MapNode
					var pos := Vector2(n.pos.x * w, n.pos.y * h)
					if click_pos.distance_to(pos) <= 34.0:
						_handle_grid_cell_clicked(n.cell)
						break
		return

	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var found: String = ""
		for node in run.map.nodes.values():
			var n := node as ForestMapGraph.MapNode
			var pos := Vector2(n.pos.x * w, n.pos.y * h)
			if mouse_pos.distance_to(pos) <= 26.0:
				found = n.id
				break
		if found != hovered_node_id:
			hovered_node_id = found
			if not hovered_node_id.is_empty() and run.known.has(hovered_node_id):
				var h_node = run.map.get_node(hovered_node_id)
				var err := run.move_error(hovered_node_id)
				if hovered_node_id == run.position and h_node.kind == ForestMapGraph.NodeKind.SHOP and not run.finished:
					err = "点击打开商店，可调整配队与卡牌。"
				elif hovered_node_id == run.position and h_node.kind == ForestMapGraph.NodeKind.DESTINY_GATE and not run.finished:
					err = "点击打开命运石之门，可领取命运或强化全队。"
				map_canvas.tooltip_text = "%s (%s)\n%s" % [h_node.name, ForestMapGraph.kind_title(h_node.kind), "可前往" if err.is_empty() else err]
			else:
				map_canvas.tooltip_text = ""
			_refresh_inspection_card()
			map_canvas.queue_redraw()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		for node in run.map.nodes.values():
			var n := node as ForestMapGraph.MapNode
			var pos := Vector2(n.pos.x * w, n.pos.y * h)
			if click_pos.distance_to(pos) <= 26.0:
				_handle_node_clicked(n.id)
				break

func _any_modal_open() -> bool:
	return modal_panel.visible or (is_instance_valid(lineup_modal_panel) and lineup_modal_panel.visible) or (is_instance_valid(next_floor_panel) and next_floor_panel.visible) or (is_instance_valid(card_reward_panel) and card_reward_panel.visible) or (is_instance_valid(deck_viewer_panel) and deck_viewer_panel.visible)

func _handle_grid_cell_clicked(cell: Vector2i) -> void:
	if is_rolling_dice or is_instance_valid(battle) or _any_modal_open():
		return
	if run == null or run.map == null or not run.map.is_grid:
		return
	if not run.map.is_in_bounds(cell):
		return
	var clbl := ForestMapGraph.cell_label(cell)
	var nid: String = run.map.node_id_at(cell)
	var is_known_cell: bool = run.known_cells.has(cell) or (not nid.is_empty() and run.known.has(nid))
	if not is_known_cell:
		route_target_id = ""
		route_preview_path.clear()
		log_label.text = "%s 为未探索迷雾区域，请先向相邻格推进侦察。" % clbl
		map_canvas.queue_redraw()
		return
	if run.map.is_obstacle(cell):
		route_target_id = ""
		route_preview_path.clear()
		log_label.text = "%s：%s" % [clbl, "树林障碍，无法通行。" if run.map.obstacle_kind(cell) == "trees" else "水域障碍，无法通行。"]
		map_canvas.queue_redraw()
		return
	if nid.is_empty():
		return
	if nid == run.position:
		route_target_id = ""
		route_preview_path.clear()
		_handle_node_clicked(nid)
		return
	# Adjacent orthogonal cell -> attempt 1-step move
	if run.map.edge_between(run.position, nid) != null:
		route_target_id = ""
		route_preview_path.clear()
		_handle_node_clicked(nid)
		return
	# Distant known cell (or diagonal) -> show route & step count without moving or spending actions
	var r_info := run.preview_route_to(nid)
	if r_info.ok:
		route_target_id = nid
		route_preview_path.assign(r_info.path)
		var dest_node = run.map.get_node(nid)
		var steps := int(r_info.steps)
		var cur_cell: Vector2i = run.map.cell_of(run.position)
		var diff: Vector2i = (cell - cur_cell).abs()
		var diag_note := "不支持斜走，" if (diff.x == 1 and diff.y == 1) else ""
		if run.dice_rolled:
			if r_info.can_reach_this_turn:
				log_label.text = "路线预览 → %s（%s）：%s需 %d 步，抵达后余 %d 步（请逐格点击相邻格前行）。" % [dest_node.name, clbl, diag_note, steps, int(r_info.remaining)]
			else:
				log_label.text = "路线预览 → %s（%s）：%s需 %d 步，当前仅剩 %d 步移动力（请逐格前行）。" % [dest_node.name, clbl, diag_note, steps, run.actions_left]
		else:
			log_label.text = "路线预览 → %s（%s）：%s需 %d 步，请先掷出行动骰再逐格前行。" % [dest_node.name, clbl, diag_note, steps]
	else:
		route_target_id = ""
		route_preview_path.clear()
		log_label.text = run.cell_move_error(cell)
	_refresh_inspection_card()
	_sync_grid_node_positions()
	map_canvas.queue_redraw()

func _handle_node_clicked(node_id: String) -> void:
	if is_rolling_dice or is_instance_valid(battle) or _any_modal_open():
		return
	if node_id == run.position:
		var n = run.map.get_node(node_id)
		if n and n.kind == ForestMapGraph.NodeKind.SHOP and not run.finished:
			run.enter_node()
			_refresh_ui()
			_open_modal("shop")
			return
		if n and n.kind == ForestMapGraph.NodeKind.DESTINY_GATE and not run.finished:
			run.enter_node()
			_refresh_ui()
			_open_modal("destiny_gate")
			return
		if n and n.kind == ForestMapGraph.NodeKind.EXIT and run.floor_cleared:
			_show_next_floor_modal()
			return
		log_label.text = "当前位置：%s（%s）" % [n.name, ForestMapGraph.kind_title(n.kind)]
		return

	var can := run.can_move(node_id)
	if not can:
		if not run.dice_rolled:
			dice_prompt_flash = 1.0
		log_label.text = run.move_error(node_id)
		return

	var success := run.move(node_id)
	if success:
		route_target_id = ""
		route_preview_path.clear()
		_refresh_ui()
		if run.in_battle:
			_start_battle(run.current_encounter)
		elif not run.pending.is_empty():
			_open_modal(run.pending)
		elif run.floor_cleared:
			_show_next_floor_modal()

func _open_modal(kind: String) -> void:
	modal_panel.visible = true
	modal_panel.offset_left = -360 if kind == "destiny_gate" else -320
	modal_panel.offset_right = 360 if kind == "destiny_gate" else 320
	modal_panel.offset_top = -245 if kind == "destiny_gate" else -230
	modal_panel.offset_bottom = 245 if kind == "destiny_gate" else 230
	modal_btn_1.visible = true
	modal_btn_2.visible = true
	modal_btn_3.visible = false
	shop_cards_section.visible = false
	if is_instance_valid(shop_revive_section):
		shop_revive_section.visible = false
	if is_instance_valid(destiny_gate_section):
		destiny_gate_section.visible = false
	modal_shop_lineup_btn.visible = false
	modal_leave_btn.visible = true
	modal_btn_1.disabled = false
	modal_btn_2.disabled = false
	modal_btn_3.disabled = false

	match kind:
		"camp":
			var curr_node = run.map.get_node(run.position) if (run and run.map) else null
			var is_pre_boss_camp: bool = (curr_node != null and curr_node.name.begins_with("战前"))
			modal_title.text = "▲ 战前营地" if is_pre_boss_camp else "▲ 林间营火"
			modal_desc.text = "在营地休整包扎伤口，或在周边搜集余烬。"
			modal_btn_1.text = "生火休整：存活队员恢复 10 生命，疲劳 −3"
			modal_btn_2.text = "搜集余烬：获得 6 cost，疲劳 −1"
			modal_leave_btn.text = "不作休整直接离开"
		"shop":
			var curr_node = run.map.get_node(run.position) if (run and run.map) else null
			var is_pre_boss: bool = (curr_node != null and curr_node.name.begins_with("战前"))
			modal_title.text = "◈ 战前行商" if is_pre_boss else "◈ 林间行商"
			var traded: bool = run.cleared.has(run.position)
			modal_desc.text = "物资区已完成交易，仍可购买符卡、精简删牌或调整配队。" if traded else "可采购物资、选购符卡或付费精简牌库（每张符卡限购一次，删牌限一次）。"
			modal_btn_1.text = "购买特效伤药（6 cost）：存活队员恢复 8 生命"
			modal_btn_1.disabled = traded or run.carried_cost < 6
			modal_btn_2.text = "购买神秘通用遗物（12 cost）：获取 1 件被动遗物"
			modal_btn_2.disabled = traded or run.carried_cost < 12 or RelicSystem.get_unowned_relics(run.relics).is_empty()
			modal_btn_3.visible = true
			modal_btn_3.text = "购买战术消耗品（4 cost）：获取 1 件战斗道具"
			modal_btn_3.disabled = traded or run.carried_cost < 4
			shop_cards_section.visible = true
			var offers := run.ensure_shop_offers(run.position)
			for i in shop_card_buttons.size():
				var cbtn := shop_card_buttons[i]
				if i >= offers.size():
					cbtn.visible = false
					continue
				cbtn.visible = true
				var offer: Dictionary = offers[i]
				var key: String = String(offer.get("key", ""))
				var price: int = int(offer.get("price", 4))
				var sold: bool = bool(offer.get("sold", false))
				var skill: Dictionary = DemoBattleRules.SKILLS.get(key, {})
				var cap_ok: Dictionary = CardPool.can_add_card(run.deck, key)
				if sold:
					cbtn.text = "%s\n已售罄" % String(skill.get("name", key))
					cbtn.disabled = true
				else:
					cbtn.text = "[%s] %s\n%s · %d cost" % [CardPool.rarity_label(key), String(skill.get("name", key)), CardPool.card_owner_label(key), price]
					cbtn.disabled = run.carried_cost < price or not cap_ok.ok
				cbtn.tooltip_text = CardPool.card_summary_text(key) + ("" if cap_ok.ok else ("\n" + String(cap_ok.reason)))
			var rem_used := run.is_shop_removal_used(run.position)
			var too_small := run.deck.size() <= CardPool.MIN_DECK_SIZE
			shop_remove_card_btn.text = "✂ 精简牌库（本商店已使用）" if rem_used else ("✂ 精简牌库 · 移除 1 张符卡（%d cost · 当前 %d 张）" % [CardPool.REMOVE_CARD_COST, run.deck.size()])
			shop_remove_card_btn.disabled = rem_used or too_small or run.carried_cost < CardPool.REMOVE_CARD_COST

			# Teammate Revival Section (shown when teammates are knocked out)
			for b in shop_revive_buttons:
				if is_instance_valid(b):
					b.queue_free()
			shop_revive_buttons.clear()
			var dead_slots := run.get_dead_hero_slots()
			if dead_slots.is_empty():
				shop_revive_section.visible = false
			else:
				shop_revive_section.visible = true
				var rev_cost := run.get_revive_cost()
				for slot_idx in dead_slots:
					var h_name: String = run.party_names[slot_idx] if slot_idx < run.party_names.size() else "队员"
					var rev_hp := maxi(1, int(round(float(run.party_max_hp[slot_idx]) * 0.40)))
					var rev_btn := Button.new()
					rev_btn.text = "⚚ 回魂仪式 · 复活【%s】（%d cost · 恢复至 %d 生命）" % [h_name, rev_cost, rev_hp]
					rev_btn.add_theme_color_override("font_color", Color("ffd166"))
					rev_btn.disabled = run.carried_cost < rev_cost
					rev_btn.pressed.connect(_on_shop_revive_pressed.bind(slot_idx))
					shop_revive_section.add_child(rev_btn)
					shop_revive_buttons.append(rev_btn)

			modal_shop_lineup_btn.visible = true
			modal_leave_btn.text = "离开摊位（稍后仍可返回）"
		"shrine":
			modal_title.text = "⛩ 御灵神龛"
			modal_desc.text = "林光洒落在古老石龛上，柔和的祝福气息在周围流转。"
			modal_btn_1.text = "圣泉洗礼：疲劳度归零，重伤队员恢复 12 生命"
			modal_btn_2.text = "古神赐福：全体队员最大生命上限 +4"
			modal_leave_btn.text = "默默致意并离开"
		"forge":
			modal_title.text = "⚒ 林野锻台"
			modal_desc.text = "石径旁依然保留着一座余温未散的铁砧熔炉，炉锤正在等待使用。"
			modal_btn_1.text = "淬炼战铠：全体队员最大生命上限 +2"
			modal_btn_2.text = "熔铸催化剂（3 cost）：获得【余烬催化剂】"
			modal_btn_2.disabled = run.carried_cost < 3
			modal_btn_3.visible = true
			modal_btn_3.text = "符卡附魔（4 cost）：为当前队伍符卡镌刻强力符文"
			modal_btn_3.disabled = run.carried_cost < 4
			modal_leave_btn.text = "离开锻台"
		"gamble":
			modal_title.text = "🎲 迷雾庄台 · 命运博弈"
			modal_desc.text = "神秘游民摇晃着雕花骨骰，桌面上堆满古老金币与筹码，邀你入局。"
			modal_btn_1.text = "小注怡情（4 cost）：50% 赢 10 cost，30% 赢特制铅币"
			modal_btn_1.disabled = run.carried_cost < 4
			modal_btn_2.text = "豪掷千金（10 cost）：40% 爆赚 28 cost，30% 赢稀有遗物/高级道具，30% 反噬"
			modal_btn_2.disabled = run.carried_cost < 10
			modal_btn_3.visible = true
			modal_btn_3.text = "血色轮盘（以血为注 · 0 cost）：全员扣除 20% 生命，50% 赢遗物与 12 cost"
			modal_leave_btn.visible = true
			modal_leave_btn.text = "理智收手，离开庄台"
		"event":
			modal_title.text = "？ 林间异象与古代遗迹"
			match run.event_variant:
				0:
					modal_desc.text = "发现一处爬满藤蔓的古代石穴，隐约传来微弱的能量共鸣。"
					modal_btn_1.text = "稳妥搜寻：获得 5 cost"
					modal_btn_2.text = "冒险深入：存活队员各失去 4 生命，掠夺 14 cost"
				1:
					modal_desc.text = "树根深处传来微弱呼救声，似乎是落入捕兽陷阱的游侠。"
					modal_btn_1.text = "上前营救：可能获赠 8 cost 与烟雾弹，但也可能是陷阱"
					modal_btn_2.text = "谨慎绕行：不冒任何风险离开"
				2:
					modal_desc.text = "一块半掩埋在青苔中的残破石碑，铭刻着林野古道的密道地图。"
					modal_btn_1.text = "消耗 3 cost 仔细拓印：获得 3 片情报碎片"
					modal_btn_1.disabled = run.carried_cost < 3
					modal_btn_2.text = "置之不理"
				3:
					modal_desc.text = "林雾深处显现出一座静谧的古泉水池，池水微泛金光，水底沉睡着无数岁月前的投赠物。"
					modal_btn_1.text = "投币许愿（5 cost）：45% 捞起古代遗物，35% 全体恢复 14 生命，20% 命运 +3"
					modal_btn_1.disabled = run.carried_cost < 5
					modal_btn_2.text = "强捞池底余烬：掠夺 12 cost，但惊动守卫（警戒 +2，疲劳 +1）"
				4:
					modal_desc.text = "一具半掩在断壁残垣中的黑色精钢宝箱，锁孔周围雕刻着剧毒暗弩的威慑符文。"
					modal_btn_1.text = "暴力强拆：50% 爆出 18 cost 与高级道具，50% 机关爆炸全员受 6 毒矢伤害"
					modal_btn_2.text = "巧手破译（4 cost）：稳妥开箱，获得 8 cost 与 1 件战术道具"
					modal_btn_2.disabled = run.carried_cost < 4
				_:
					modal_desc.text = "一位身披残破星纹斗篷的白发狂乱先知盘坐于枯树桩上，双目盲白却直视你的灵魂。"
					modal_btn_1.text = "献祭鲜血求得启示：全员失去 3 生命，命运 +3，本回合步数 +1"
					modal_btn_2.text = "购买澄明秘药（4 cost）：疲劳完全消除，获得【澄明甘露】"
					modal_btn_2.disabled = run.carried_cost < 4
			modal_leave_btn.visible = true
			modal_leave_btn.text = "不作交互直接离开"
		"destiny_gate":
			var cur_pct: int = run.get_clash_heads_percent()
			var next_pct: int = run.get_next_destiny_heads_percent()
			var upg_cost: int = run.get_destiny_upgrade_cost()
			var is_max: bool = run.is_destiny_max_tier()
			var claimed: bool = run.is_destiny_gate_claimed(run.position)
			var claimable: int = run.get_destiny_gate_claimable_amount(run.position)
			var is_full: bool = run.destiny >= ForestRun.DESTINY_MAX
			destiny_expected_next_tier = -1 if is_max else (run.destiny_tier + 1)

			modal_title.text = "❖ 命运石之门  ·  全队拼点强化"
			if is_max:
				modal_desc.text = "当前命运 %d/%d ｜ 我方拼点正面率 %d%%（已满级，自然拼点硬币必出正面）。" % [run.destiny, ForestRun.DESTINY_MAX, cur_pct]
			else:
				modal_desc.text = "当前命运 %d/%d ｜ 我方拼点正面率 %d%% → 下一档 %d%%（花费 %d 命运）。可先领取再升级，或连续升档。" % [run.destiny, ForestRun.DESTINY_MAX, cur_pct, next_pct, upg_cost]

			# Hide default stacked choice buttons visually since destiny_gate_section provides the rich two-column UI,
			# while keeping modal_btn_1/modal_btn_2 state synced for keyboard/test compatibility.
			modal_btn_1.visible = false
			modal_btn_2.visible = false
			if is_instance_valid(destiny_gate_section):
				destiny_gate_section.visible = true
				var bal_txt := "◆ 命运 %d/%d" % [run.destiny, ForestRun.DESTINY_MAX]
				destiny_modal_balance_a.text = bal_txt
				destiny_modal_balance_b.text = bal_txt
				destiny_preview_rate_lbl.text = "%d%%" % cur_pct
				if claimed:
					destiny_claim_title_lbl.text = "领取命运 +2"
					destiny_claim_sub_lbl.text = "本座命运石之门已领取"
					destiny_claim_btn.text = "已领取"
					destiny_claim_btn.disabled = true
					destiny_claim_btn.add_theme_stylebox_override("disabled", MapVisuals.make_box(Color("dfd4bd"), Color("9e8a6b"), 1, 8, 8, 4))
				elif is_full:
					destiny_claim_title_lbl.text = "领取命运 +2"
					destiny_claim_sub_lbl.text = "命运已满（10/10），请先强化全队腾出空间"
					destiny_claim_btn.text = "已满额"
					destiny_claim_btn.disabled = true
					destiny_claim_btn.add_theme_stylebox_override("disabled", MapVisuals.make_box(Color("dfd4bd"), Color("9e8a6b"), 1, 8, 8, 4))
				elif claimable == 1:
					destiny_claim_title_lbl.text = "领取命运 +1"
					destiny_claim_sub_lbl.text = "只剩 1 个空位，本次只会获得 1 点（或先强化再领 +2）"
					destiny_claim_btn.text = "领取 +1"
					destiny_claim_btn.disabled = false
					destiny_claim_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("8a5e1d"), MapVisuals.SUN_GOLD, 2, 8, 8, 4))
				else:
					destiny_claim_title_lbl.text = "领取命运 +2"
					destiny_claim_sub_lbl.text = "每座门可领取一次"
					destiny_claim_btn.text = "领取 +2"
					destiny_claim_btn.disabled = false
					destiny_claim_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("8a5e1d"), MapVisuals.SUN_GOLD, 2, 8, 8, 4))

				if is_max:
					destiny_upgrade_rate_lbl.text = "100%（已满级）"
					destiny_upgrade_btn.text = "已满级"
					destiny_upgrade_btn.disabled = true
					destiny_upgrade_btn.remove_theme_stylebox_override("normal")
				else:
					destiny_upgrade_rate_lbl.text = "%d%% → %d%%" % [cur_pct, next_pct]
					destiny_upgrade_btn.text = "花费 %d 命运" % upg_cost
					destiny_upgrade_btn.disabled = run.destiny < upg_cost
					if not destiny_upgrade_btn.disabled:
						destiny_upgrade_btn.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("c99634"), MapVisuals.SUN_GOLD, 2, 8, 10, 6))
						destiny_upgrade_btn.add_theme_color_override("font_color", MapVisuals.INK_DARK)
					else:
						destiny_upgrade_btn.remove_theme_stylebox_override("normal")
						destiny_upgrade_btn.add_theme_color_override("font_color", Color("8f7d64"))

			modal_btn_1.text = destiny_claim_btn.text if is_instance_valid(destiny_claim_btn) else "领取命运"
			modal_btn_1.disabled = destiny_claim_btn.disabled if is_instance_valid(destiny_claim_btn) else true
			modal_btn_2.text = ("已满级" if is_max else ("强化全队 %d%% → %d%%（花费 %d 命运）" % [cur_pct, next_pct, upg_cost]))
			modal_btn_2.disabled = destiny_upgrade_btn.disabled if is_instance_valid(destiny_upgrade_btn) else true
			modal_leave_btn.text = "离开命运石之门（稍后仍可返回）"

func _on_destiny_claim_pressed() -> void:
	if run == null or run.pending != "destiny_gate":
		return
	var res := run.claim_destiny_gate()
	if is_instance_valid(destiny_gate_feedback):
		if res.get("ok", false):
			destiny_gate_feedback.text = "已领取 +%d 命运（当前 %d/%d）。" % [int(res.get("gained", 0)), run.destiny, ForestRun.DESTINY_MAX]
			destiny_gate_feedback.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT)
		else:
			destiny_gate_feedback.text = String(res.get("reason", "当前无法领取命运。"))
			destiny_gate_feedback.add_theme_color_override("font_color", Color("ff8c7a"))
	_open_modal("destiny_gate")
	_refresh_ui()

func _on_destiny_upgrade_pressed() -> void:
	if run == null or run.pending != "destiny_gate":
		return
	var res := run.upgrade_destiny_tier(destiny_expected_next_tier)
	if is_instance_valid(destiny_gate_feedback):
		if res.get("ok", false):
			destiny_gate_feedback.text = "强化成功！我方拼点正面率 %d%% → %d%%（消耗 %d 命运）。" % [int(res.get("prev_percent", 0)), int(res.get("percent", 0)), int(res.get("cost", 0))]
			destiny_gate_feedback.add_theme_color_override("font_color", MapVisuals.SUN_GOLD)
		else:
			destiny_gate_feedback.text = String(res.get("reason", "当前无法强化全队。"))
			destiny_gate_feedback.add_theme_color_override("font_color", Color("ff8c7a"))
	_open_modal("destiny_gate")
	_refresh_ui()

func _on_modal_choice(choice_idx: int) -> void:
	if run == null:
		return
	if run.pending == "forge" and choice_idx == 2:
		modal_panel.hide()
		_open_forge_enchant_modal()
		return
	if run.pending == "destiny_gate":
		if choice_idx == 0:
			_on_destiny_claim_pressed()
		elif choice_idx == 1:
			_on_destiny_upgrade_pressed()
		return
	var ok := run.apply_choice(choice_idx)
	if ok:
		if run.pending == "shop":
			_open_modal("shop")
		else:
			modal_panel.hide()
		_refresh_ui()

func _on_modal_leave() -> void:
	if run == null:
		return
	if run.pending == "shop":
		run.leave_shop()
	elif run.pending == "destiny_gate":
		run.leave_destiny_gate()
		if is_instance_valid(destiny_gate_feedback):
			destiny_gate_feedback.text = ""
	else:
		run.pending = ""
		run.cleared[run.position] = true
	modal_panel.visible = false
	_refresh_ui()

func _on_roll_dice_pressed() -> void:
	if run == null or is_rolling_dice or is_instance_valid(battle) or _any_modal_open():
		return
	if not run.can_roll_action_dice():
		return
	is_rolling_dice = true
	dice_anim_elapsed = 0.0
	dice_anim_step_accum = 0.0
	dice_anim_face = (dice_anim_face % ForestRun.DICE_MAX) + 1
	log_label.text = "正在掷出第 %d 回合行动骰（1d4）……" % run.turn
	_refresh_dice_ui()

func roll_dice_instant(forced_raw: int = -1) -> Dictionary:
	is_rolling_dice = false
	dice_anim_elapsed = 0.0
	dice_anim_step_accum = 0.0
	if run == null:
		return {"ok": false, "reason": "探险尚未初始化。"}
	var result := run.roll_action_dice(forced_raw)
	_refresh_ui()
	return result

func _on_end_turn_pressed() -> void:
	if run == null or is_rolling_dice or is_instance_valid(battle) or _any_modal_open():
		return
	run.end_turn()
	route_target_id = ""
	route_preview_path.clear()
	_refresh_ui()
	if run.in_battle:
		_start_battle(run.current_encounter)

func _refresh_dice_ui() -> void:
	if run == null:
		return
	var ui_locked := is_instance_valid(battle) or _any_modal_open()
	if is_rolling_dice:
		var glyph: String = DICE_GLYPHS[clampi(dice_anim_face - 1, 0, DICE_GLYPHS.size() - 1)]
		actions_label.text = "掷骰 [%s]" % glyph
		actions_label.add_theme_color_override("font_color", GOLD)
		roll_dice_button.text = "🎲 掷骰中 %s" % glyph
		roll_dice_button.disabled = true
		roll_dice_button.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("664920"), GOLD, 2, 6, 10, 6))
		end_turn_button.disabled = true
		return
	if not run.dice_rolled:
		actions_label.text = "步数 [待掷骰]"
		actions_label.add_theme_color_override("font_color", GOLD)
		roll_dice_button.text = "🎲 掷行动骰 (1d4)"
		roll_dice_button.disabled = ui_locked or not run.can_roll_action_dice()
		var fatigue_tip := "\n当前疲劳 %d ≥ 6：掷出点数 −1（保底 1 步）" % run.fatigue if run.fatigue >= ForestRun.FATIGUE_PENALTY_THRESHOLD else ""
		roll_dice_button.tooltip_text = "掷出 1d4 决定本回合可移动步数（1～4 步）。%s" % fatigue_tip
		if not roll_dice_button.disabled:
			roll_dice_button.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("8a5e1d"), GOLD, 2, 6, 10, 6))
		else:
			roll_dice_button.remove_theme_stylebox_override("normal")
	else:
		var actions_dots := ""
		for i in run.action_budget:
			actions_dots += "●" if i < run.actions_left else "○"
		var penalty_tag := " (-1)" if run.last_dice_penalty > 0 else ""
		actions_label.text = "步数 [%s] %d/%d%s" % [actions_dots, run.actions_left, run.action_budget, penalty_tag]
		actions_label.add_theme_color_override("font_color", MapVisuals.EMERALD_LIGHT if run.actions_left > 0 else Color("b8a88c"))
		var rolled_glyph: String = DICE_GLYPHS[clampi(run.last_dice_raw - 1, 0, DICE_GLYPHS.size() - 1)]
		roll_dice_button.text = "🎲 本回合 %s 点 (%d步)" % [rolled_glyph, run.action_budget]
		roll_dice_button.disabled = true
		roll_dice_button.remove_theme_stylebox_override("normal")
		roll_dice_button.tooltip_text = "第 %d 回合掷出 %d%s，共 %d 步。" % [run.turn, run.last_dice_raw, ("（高疲劳 −%d）" % run.last_dice_penalty) if run.last_dice_penalty > 0 else "", run.action_budget]
	end_turn_button.disabled = ui_locked or run.finished or run.in_battle or not run.pending.is_empty()
	if not end_turn_button.disabled and run.dice_rolled and run.actions_left == 0:
		end_turn_button.add_theme_stylebox_override("normal", MapVisuals.make_box(Color("8a5e1d"), GOLD, 2, 6, 10, 6))
	else:
		end_turn_button.remove_theme_stylebox_override("normal")
	if is_instance_valid(dice_tray_canvas):
		dice_tray_canvas.queue_redraw()

func _refresh_inspection_card() -> void:
	if run != null and run.map != null and run.map.is_grid and hovered_cell.x >= 0 and run.map.is_obstacle(hovered_cell) and run.known_cells.has(hovered_cell):
		if is_instance_valid(inspect_title_label):
			var obs_is_trees: bool = String(run.map.obstacle_kind(hovered_cell)) == "trees"
			inspect_title_label.text = "%s · %s" % [ForestMapGraph.cell_label(hovered_cell), "密林障碍" if obs_is_trees else "深水河道"]
			inspect_kind_label.text = "不可通行地形"
			inspect_status_label.text = "• 需绕行相邻可通行方格"
			inspect_status_label.add_theme_color_override("font_color", Color("9c3c31"))
			inspect_desc_label.text = "茂密的焦木树林阻挡去路，无法直接穿过。" if obs_is_trees else "湍急的林间河道阻断通行，需沿桥梁或浅滩绕行。"
		return
	var n := _inspected_node()
	if n == null or not is_instance_valid(inspect_title_label):
		return
	inspect_title_label.text = ("%s · %s" % [ForestMapGraph.cell_label(n.cell), n.name]) if (run.map.is_grid and n.cell.x >= 0) else n.name
	var tag := ForestMapGraph.kind_title(n.kind)
	if run.cleared.has(n.id) and n.kind != ForestMapGraph.NodeKind.PASSAGE and n.kind != ForestMapGraph.NodeKind.SPAWN:
		tag += " · 已探索"
	inspect_kind_label.text = tag

	if n.id == run.position:
		if n.kind == ForestMapGraph.NodeKind.SHOP and not run.finished:
			inspect_status_label.text = "📍 当前所在（点击节点可再次进入商店）"
		elif n.kind == ForestMapGraph.NodeKind.DESTINY_GATE and not run.finished:
			inspect_status_label.text = "📍 当前所在（点击节点可再次进入命运石之门）"
		elif n.kind == ForestMapGraph.NodeKind.EXIT and run.floor_cleared:
			inspect_status_label.text = "📍 当前所在（点击节点可深入下一层）"
		else:
			inspect_status_label.text = "📍 小队当前所在位置"
		inspect_status_label.add_theme_color_override("font_color", Color("8a5e1d"))
	else:
		var err := run.move_error(n.id)
		if err.is_empty():
			var edge = run.map.edge_between(run.position, n.id)
			var step_cost: int = edge.action_cost if edge != null else 1
			inspect_status_label.text = "✦ 可直接前往（消耗 %d 步）" % step_cost
			inspect_status_label.add_theme_color_override("font_color", Color("2c7a3b"))
		elif run.map.is_grid:
			var r_info := run.preview_route_to(n.id)
			if r_info.ok and int(r_info.steps) >= 2:
				if run.dice_rolled and r_info.can_reach_this_turn:
					inspect_status_label.text = "🧭 路线：%d 步（抵达后余 %d 步，逐格前行）" % [int(r_info.steps), int(r_info.remaining)]
					inspect_status_label.add_theme_color_override("font_color", Color("2c7a3b"))
				else:
					inspect_status_label.text = "🧭 路线：%d 步（%s）" % [int(r_info.steps), "本回合移动力不足" if run.dice_rolled else "请先掷骰"]
					inspect_status_label.add_theme_color_override("font_color", Color("8a5e1d"))
			else:
				inspect_status_label.text = "• %s" % err
				inspect_status_label.add_theme_color_override("font_color", Color("9c3c31"))
		else:
			inspect_status_label.text = "• %s" % err
			inspect_status_label.add_theme_color_override("font_color", Color("9c3c31"))

	var desc: String = n.description if not n.description.is_empty() else ForestMapGraph.kind_summary(n.kind)
	inspect_desc_label.text = desc
	if is_instance_valid(inspect_icon_canvas):
		inspect_icon_canvas.queue_redraw()

func _refresh_ui() -> void:
	if run == null:
		return
	var ftheme := MapVisuals.floor_theme(run.floor_level)
	if is_instance_valid(floor_badge):
		floor_badge.text = "🚩 第 %d 层 · %s" % [run.floor_level, ftheme.name]
	cost_label.text = "🪙 %d cost" % run.carried_cost
	_refresh_dice_ui()

	fatigue_label.text = "疲劳 %d/8" % run.fatigue
	fatigue_label.add_theme_color_override("font_color", Color("ff6b5e") if run.fatigue >= 6 else (Color("f5c963") if run.fatigue >= 4 else Color("dfd2b5")))

	alert_label.text = "警戒 %d/5" % run.alert
	alert_label.add_theme_color_override("font_color", Color("ff6b5e") if run.alert >= 4 else Color("dfd2b5"))

	intel_label.text = "📜 %d 情报" % run.intel_fragments
	var heads_pct: int = run.get_clash_heads_percent()
	if is_instance_valid(destiny_label):
		destiny_label.text = "◆ 命运 %d/%d · 正面率 %d%%" % [run.destiny, ForestRun.DESTINY_MAX, heads_pct]
	if is_instance_valid(destiny_pill):
		destiny_pill.tooltip_text = "全队共享命运点数（上限 %d 点，跨层保留）。\n当前我方拼点硬币自然正面率：%d%%\n在【命运石之门】可领取命运并强化全队正面率（45%% → 60%% → 75%% → 90%% → 100%%）。" % [ForestRun.DESTINY_MAX, heads_pct]
	if is_instance_valid(destiny_side_label):
		destiny_side_label.text = "◆ 命运 %d/%d  ·  我方拼点正面率 %d%%" % [run.destiny, ForestRun.DESTINY_MAX, heads_pct]
	core_badge.visible = run.ember_core

	log_label.text = run.message
	opening_lineup_button.visible = _at_run_start()
	if is_instance_valid(deck_viewer_button):
		deck_viewer_button.text = "🃏 牌库 (%d/%d)" % [run.deck.size(), CardPool.MAX_DECK_SIZE]
		deck_viewer_button.disabled = is_instance_valid(battle) or (is_instance_valid(card_reward_panel) and card_reward_panel.visible)

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
		items_container.remove_child(child)
		child.queue_free()
	for idx in run.items.size():
		var i_id: String = run.items[idx]
		var i_data: Dictionary = RelicSystem.get_consumable(i_id)
		var btn := Button.new()
		btn.theme_type_variation = &"ItemShelfButton"
		btn.icon = RelicSystem.get_item_art(i_id)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		if btn.icon == null:
			btn.text = i_data.get("icon", "✦")
		btn.tooltip_text = "【%s】(点击查看详情/使用)\n%s" % [i_data.get("name", i_id), i_data.get("description", "")]
		btn.custom_minimum_size = Vector2(34, 32)
		btn.pressed.connect(_show_item_detail.bind(i_id, idx))
		items_container.add_child(btn)

	# Refresh Journal Feed (latest 4 entries)
	if is_instance_valid(journal_label):
		var lines: PackedStringArray = []
		var start_idx := maxi(0, run.journal.size() - 4)
		for idx in range(run.journal.size() - 1, start_idx - 1, -1):
			var entry: Dictionary = run.journal[idx]
			lines.append("[T%d] %s" % [int(entry.get("turn", 1)), String(entry.get("message", ""))])
		journal_label.text = "\n".join(lines)

	_refresh_inspection_card()
	_sync_grid_node_positions()
	map_canvas.queue_redraw()

func _start_battle(encounter: int) -> void:
	battle = BattleScene.instantiate()
	battle.encounter = encounter
	battle.lineup = run.lineup.duplicate()
	battle.deck = run.deck.duplicate() if not run.deck.is_empty() else null
	if run.in_battle:
		battle.exploration_run = run
		battle.battle_finished.connect(_on_exploration_battle_finished)
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

func _on_exploration_battle_finished() -> void:
	if run.is_final_boss_battle() and battle.battle.outcome == "victory":
		_return_from_battle.call_deferred()

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
		if run.won_expedition:
			_show_expedition_victory()
		elif run.pending == "card_reward" and not run.pending_card_rewards.is_empty():
			_open_card_reward_modal()
		elif run.floor_cleared:
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
	carried_cost = ForestRun.START_COST
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
	return MapVisuals.make_box(fill, border, width, radius, padding, padding)
