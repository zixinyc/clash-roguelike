class_name DemoCardView
extends Button

const Rules = preload("res://scripts/battle_rules.gd")
const USE_HINTS := {
	"probe": "低费接招", "observe": "积累准备", "exploit": "消耗准备强化拼点",
	"follow": "拼赢后追加攻击", "steady_edge": "同费下限更高", "all_in": "同费上限更高",
	"shatter": "三枚硬币 · 爆发",
	"support_strike": "拼赢后给队友护盾", "steady": "同费下限更高", "ember": "同费上限更高",
	"needle": "低费进攻", "cleave": "高威力进攻", "guard": "低费防御", "nova": "三枚硬币 · 爆发"
}

var skill: Dictionary = {}
var skill_key := ""
var hand_index := -1
var key_number := 1
var selected := false
var hovered := false
var assigned_to := ""
var accent := Color("dfbc80")
var bonus := 0
var ally_shield := 0
var chinese_font: Font
var number_font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(130, 133)
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
	tooltip_text = "%s · %d cost\n%s" % [skill.name, skill.cost, skill.description]

func effect_text() -> String:
	if skill.kind == "guard":
		var effect := "行动结算时，自身 +%d 护盾" % Rules.GUARD_AMOUNT
		if ally_shield > 0:
			effect += "，其他存活队友各 +%d" % ally_shield
		return effect
	match skill_key:
		"steady": return "和「余烬斩」同费，拼点下限更高"
		"ember": return "和「定锋」同费，拼点上限更高"
		"steady_edge": return "和「破阵」同费，拼点下限更高"
		"all_in": return "和「稳斩」同费，拼点上限更高"
		"exploit":
			return "消耗 1 层准备，拼点威力 +%d" % bonus if bonus > 0 else "获得准备后，下次用它拼点可强化威力"
	return skill.description

func _draw() -> void:
	if skill.is_empty() or chinese_font == null:
		return
	var active := selected or has_focus()
	var tint := Color("192832").lerp(accent, 0.10) if selected else Color("16242e")
	if hovered:
		tint = tint.lightened(0.06)
	var ink := Color("f2eee3") if not disabled else Color("a3b1b4")
	var muted := Color("a8bac0") if not disabled else Color("86989d")
	var bright := accent if not disabled else accent.lerp(muted, 0.65)
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = bright if active else Color("354751")
	style.set_border_width_all(1)
	style.border_width_top = 3 if active else 1
	style.set_corner_radius_all(6)
	draw_style_box(style, rect)
	var kind_label := "防御" if skill.kind == "guard" else ("大招" if skill.kind == "ultimate" else "进攻")
	_text("%d cost" % skill.cost, Vector2(10, 23), 17, bright, number_font)
	_right(kind_label, Vector2(size.x - 10, 23), 13, muted)
	_text(skill.name, Vector2(10, 48), 19, ink)
	if skill.kind == "guard":
		_text("+%d" % Rules.GUARD_AMOUNT, Vector2(10, 76), 23, bright, number_font)
		_text("自身护盾", Vector2(61, 75), 12, muted)
	else:
		var base := int(skill.base) + bonus
		var values := "%d–%d" % [base, base + int(skill.power) * int(skill.coins)]
		var value_width := number_font.get_string_size(values, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		_text(values, Vector2(10, 76), 23, bright, number_font)
		_text("拼点威力", Vector2(17 + value_width, 75), 12, muted)
	var usage: String = USE_HINTS.get(skill_key, skill.description)
	if skill.kind == "guard" and ally_shield > 0:
		usage = "队友各 +%d 护盾" % ally_shield
	_text(usage, Vector2(10, 100), 13, ink)
	if not assigned_to.is_empty():
		_text("已安排 · %s" % assigned_to, Vector2(10, 122), 12, muted)
	_right(str(key_number), Vector2(size.x - 10, 122), 13, muted, number_font)

func _text(value: String, origin: Vector2, font_size: int, color: Color, font: Font = null) -> void:
	var used_font := chinese_font if font == null else font
	draw_string(used_font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _right(value: String, origin: Vector2, font_size: int, color: Color, font: Font = null) -> void:
	var used_font := chinese_font if font == null else font
	var width := used_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, origin - Vector2(width, 0), font_size, color, used_font)
