class_name DemoCardView
extends Button

var skill: Dictionary = {}
var key_number := 1
var selected := false
var hovered := false
var chinese_font: Font
var number_font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(142, 222)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chinese_font = get_theme_font("font")
	number_font = SystemFont.new()
	number_font.font_names = PackedStringArray(["Bahnschrift", "Consolas"])
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	tooltip_text = "%s｜%s\n费用 %d cost\n%s\n%s" % [skill.name, skill.tag, skill.cost, skill.description, skill.flavor]

func _draw() -> void:
	if skill.is_empty() or chinese_font == null:
		return
	var accent := Color("95c3c6") if skill.kind == "guard" else Color("d9b77c")
	var active := selected or hovered or has_focus()
	var tint := Color("1c2a31") if active else Color("131e27")
	var opacity := 0.40 if disabled else 1.0
	var rect := Rect2(Vector2(1, 5), size - Vector2(2, 10))
	draw_style_box(_box(tint, accent if selected else Color("37464d"), 2 if selected else 1), rect)
	draw_rect(Rect2(2, 6, size.x - 4, 3), Color(accent, opacity if selected else opacity * 0.25))
	draw_circle(Vector2(25, 30), 15, Color("29353b"))
	_text(str(skill.cost), Vector2(25, 37), 23, Color(accent, opacity), number_font)
	_text(skill.tag, Vector2(size.x - 31, 34), 12, Color("98a4a4", opacity))
	_text(skill.name, Vector2(size.x / 2.0, 73), 23, Color("e9e6dc", opacity))
	draw_line(Vector2(18, 87), Vector2(size.x - 18, 87), Color(accent, opacity * 0.2), 1)
	var center := Vector2(size.x / 2.0, 121)
	if skill.kind == "guard":
		var shape := PackedVector2Array([center + Vector2(0, -26), center + Vector2(25, -13), center + Vector2(19, 15), center + Vector2(0, 30), center + Vector2(-19, 15), center + Vector2(-25, -13), center + Vector2(0, -26)])
		draw_polyline(shape, Color(accent, opacity * 0.75), 2, true)
		draw_line(center + Vector2(0, -16), center + Vector2(0, 18), Color(accent, opacity * 0.4), 1)
	else:
		var shape := PackedVector2Array([center + Vector2(-21, 25), center + Vector2(9, -18), center + Vector2(26, -31), center + Vector2(20, -8), center + Vector2(-14, 31)])
		draw_colored_polygon(shape, Color(accent, opacity * 0.65))
		draw_line(center + Vector2(-29, 10), center + Vector2(-4, 27), Color(accent, opacity), 2, true)
		for i in int(skill.coins):
			draw_circle(center + Vector2(-26 + i * 10, -22), 2.4, Color(accent, opacity * 0.5))
	if skill.kind == "guard":
		_text("护盾 +9", Vector2(size.x / 2.0, 177), 17, Color(accent, opacity))
	else:
		_text("%d — %d" % [skill.base, skill.base + skill.power * skill.coins], Vector2(size.x / 2.0, 177), 22, Color(accent, opacity), number_font)
		_text("%d 枚硬币  /  正面 +%d" % [skill.coins, skill.power], Vector2(size.x / 2.0, 198), 11, Color("9ca9a9", opacity))
	_text(str(key_number), Vector2(size.x - 16, size.y - 15), 10, Color("6d838a"), number_font)
	if selected:
		_text("已选择", Vector2(33, size.y - 15), 10, accent)

func _text(value: String, center: Vector2, font_size: int, color: Color, font_override: Font = null) -> void:
	var used_font := chinese_font if font_override == null else font_override
	var width := used_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(used_font, center - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 6
	return style
