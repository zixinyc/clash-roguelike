extends Control

const MapVisuals = preload("res://scripts/map_visuals.gd")

signal menu_requested

var cleared_floors: int
var total_floors: int
var modifier_count: int

func _ready() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art := "res://art/battle-forest-sunlit.jpg"
	if ResourceLoader.exists(art):
		background.texture = load(art)
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.14, 0.10, 0.07, 0.30) if background.texture else MapVisuals.WALNUT_DEEP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 580
	panel.add_theme_stylebox_override("panel", MapVisuals.make_box(MapVisuals.WALNUT_BG, MapVisuals.BRASS_GOLD, 2, 16, 48, 36))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	column.add_child(_label("远征胜利", 50, MapVisuals.CREAM_TEXT))
	column.add_child(_label("第五层首领已击败", 22, MapVisuals.SUN_GOLD))
	column.add_child(HSeparator.new())
	column.add_child(_label("通关层数  %d / %d       累计敌方强化  %d 项" % [cleared_floors, total_floors, modifier_count], 18, MapVisuals.CREAM_TEXT))

	var menu := Button.new()
	menu.name = "ReturnToMenu"
	menu.text = "返回主菜单"
	menu.custom_minimum_size = Vector2(230, 48)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_stylebox_override("normal", MapVisuals.make_box(MapVisuals.SUN_GOLD, MapVisuals.BRASS_GOLD))
	menu.add_theme_stylebox_override("hover", MapVisuals.make_box(MapVisuals.PARCHMENT, MapVisuals.SUN_GOLD))
	menu.add_theme_color_override("font_color", MapVisuals.INK_DARK)
	menu.add_theme_color_override("font_hover_color", MapVisuals.INK_DARK)
	menu.add_theme_color_override("font_focus_color", MapVisuals.INK_DARK)
	menu.add_theme_color_override("font_pressed_color", MapVisuals.INK_DARK)
	menu.add_theme_font_size_override("font_size", 18)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(menu)
	menu.grab_focus()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
