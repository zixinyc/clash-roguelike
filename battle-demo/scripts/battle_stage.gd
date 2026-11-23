class_name DemoBattleStage
extends Control

signal unit_selected(allied: bool, index: int)
signal slot_selected(allied: bool, index: int)
signal aim_committed(source: int, target: int)
signal aim_cancelled
signal quick_assign_requested(allied: bool, slot_id: int)
signal slot_cancel_requested(slot_id: int)
signal impact_sound(kind: String)
signal shared_support_clicked
signal shared_support_dropped(slot_id: int)

const Rules = preload("res://scripts/battle_rules.gd")
const SHARED_SUPPORT_RECT := Rect2(595, 302, 190, 68)

var active_slot := 0
var target_slot := 0
var dragging := -1
var pressed_slot_side := -1
var pressed_slot_id := -1
var hovered_slot_side := -1
var hovered_slot_id := -1
var pointer := Vector2.ZERO
var screen_shake := 0.0
var target_guidance: Array[Dictionary] = []
var hero_guidance: Array[Dictionary] = []

const GOLD := Color("f0c66d")
const BLUE := Color("76d1da")
const RED := Color("eb7b6c")
const SLOT_COLORS := [Color("e27a68"), Color("eab95c"), Color("6bc5d2")]
const VALID_TARGET := Color("7be08f")
const INTERCEPT_TARGET := Color("62dff0")
const SOLO_TARGET := Color("f5d278")
const SLOT_SIZE := Vector2(54, 48)
const BASE := Vector2(1380, 410)
const HERO_SPRITES := [Rect2(96, 18, 315, 480), Rect2(570, 4, 402, 494), Rect2(1082, 26, 306, 472)]
const ENEMY_SPRITES := {
	"scout": Rect2(92, 550, 359, 458),
	"warden": Rect2(561, 513, 381, 497),
	"elite": Rect2(1043, 504, 414, 508),
}
const POINTS := [Vector2(176, 294), Vector2(356, 294), Vector2(536, 294), Vector2(932, 294), Vector2(1148, 294)]

var state: Dictionary = {}
var selected_hero := 0
var selected_enemy := 0
var busy := false
var time := 0.0
var next_idle_redraw := 0.0
var motions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var flashes: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var impact := 0.0
var sparks := 0.0
var contact_position := Vector2.ZERO
var holding_impact := false
var overlay: Dictionary = {}
var banner := ""
var floaters: Array[Dictionary] = []
var face_font: Font
var mono_font: Font
var station_texture: Texture2D
var actors_texture: Texture2D
var priest_texture: Texture2D
var zixi_texture: Texture2D
var zixingyc_texture: Texture2D
var impact_texture: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	face_font = get_theme_font("font")
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Bahnschrift", "Consolas"])
	station_texture = _optional_texture("res://art/battle-forest-sunlit.jpg")
	if station_texture == null:
		station_texture = _optional_texture("res://art/battle-forest-sunlit.png")
	if station_texture == null:
		station_texture = _optional_texture("res://art/rain-station.png")
	actors_texture = _optional_texture("res://art/battle-actors.png")
	priest_texture = _optional_texture("res://art/grave-priest.png")
	zixi_texture = _optional_texture("res://art/zixi.png")
	zixingyc_texture = _optional_texture("res://art/zixingyc-placeholder.png")
	impact_texture = _optional_texture("res://art/battle-impact.png")

func _optional_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func set_state(value: Dictionary) -> void:
	state = value
	queue_redraw()

func reset_visuals() -> void:
	motions.assign([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	flashes.assign([0.0, 0.0, 0.0, 0.0, 0.0])
	overlay.clear()
	floaters.clear()
	banner = ""
	impact = 0.0
	screen_shake = 0.0
	sparks = 0.0
	holding_impact = false
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	screen_shake = maxf(0.0, screen_shake - delta * 3.8)
	if not holding_impact:
		impact = maxf(0.0, impact - delta * 3.5)
		sparks = maxf(0.0, sparks - delta * 2.0)
		for i in flashes.size():
			flashes[i] = maxf(0.0, flashes[i] - delta * 3.5)
		if not floaters.is_empty():
			for item in floaters:
				item.age += delta
			floaters = floaters.filter(func(item: Dictionary) -> bool: return item.age < 1.5)
	if busy or holding_impact or dragging >= 0 or screen_shake > 0.0 or time >= next_idle_redraw:
		next_idle_redraw = time + 1.0 / 24.0
		queue_redraw()

func _actor_position(id: int) -> Vector2:
	var count: int = state.get("heroes", []).size()
	if id < 3 and count < 3:
		return POINTS[1] + Vector2((id - (count - 1) / 2.0) * 180.0, 0)
	return POINTS[id]

func slot_position(allied: bool, index: int) -> Vector2:
	if allied:
		var slot: Dictionary = state.hero_slots[index]
		return _actor_position(slot.unit) + Vector2((slot.category - 1) * 57.0, -198.0 - slot.get("row", 0) * 58.0)
	return _actor_position(index / 3 + 3) + Vector2((index % 3 - 1) * 57.0, -198.0)

func _slot_rect(allied: bool, index: int) -> Rect2:
	return Rect2(slot_position(allied, index) - SLOT_SIZE * 0.5, SLOT_SIZE)

func _gui_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseMotion:
		pointer = event.position * BASE / size
		queue_redraw()
		tooltip_text = ""
		hovered_slot_side = -1
		hovered_slot_id = -1
		if SHARED_SUPPORT_RECT.has_point(pointer):
			var support: Dictionary = state.get("shared_support_slot", {})
			if support.get("active", false):
				tooltip_text = "全队共有辅助槽（已安排 %s）：先于普通行动结算。点击或右键可撤销。" % Rules.SKILLS[support.key].name
			else:
				tooltip_text = "全队共有辅助槽：拖入或选中辅助类牌后点击，先于普通行动结算。"
			return
		for side in 2:
			var slots: Array = state.get("hero_slots" if side == 0 else "enemy_slots", [])
			for slot in slots:
				if _slot_rect(side == 0, slot.id).has_point(pointer):
					hovered_slot_side = side
					hovered_slot_id = slot.id
					if side == 1 and slot.id < target_guidance.size():
						tooltip_text = target_guidance[slot.id].get("text", "")
					elif side == 0 and slot.id < hero_guidance.size():
						tooltip_text = hero_guidance[slot.id].get("tooltip", "")
					return
		return

	if not event is InputEventMouseButton:
		return
	var point: Vector2 = event.position * BASE / size
	queue_redraw()

	# Right click on an active hero slot or shared support -> quick cancel
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if SHARED_SUPPORT_RECT.has_point(point):
			var support: Dictionary = state.get("shared_support_slot", {})
			if support.get("active", false):
				slot_cancel_requested.emit(-2)
			accept_event()
			return
		for slot in state.get("hero_slots", []):
			if _slot_rect(true, slot.id).has_point(point):
				if slot.active:
					slot_cancel_requested.emit(slot.id)
				accept_event()
				return
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if SHARED_SUPPORT_RECT.has_point(point):
		if event.pressed:
			shared_support_clicked.emit()
		else:
			if dragging >= 0:
				shared_support_dropped.emit(dragging)
			else:
				shared_support_clicked.emit()
			dragging = -1
			pressed_slot_side = -1
			pressed_slot_id = -1
		accept_event()
		return

	for side in 2:
		var slots: Array = state.get("hero_slots" if side == 0 else "enemy_slots", [])
		for slot in slots:
			if _slot_rect(side == 0, slot.id).has_point(point):
				if event.pressed:
					pressed_slot_side = side
					pressed_slot_id = slot.id
					slot_selected.emit(side == 0, slot.id)
					if side == 0:
						dragging = slot.id
						pointer = point
				else:
					if side == 1 and dragging >= 0:
						aim_committed.emit(dragging, slot.id)
					elif side == 1 and pressed_slot_side == 1 and pressed_slot_id == slot.id:
						if slot.id < target_guidance.size() and target_guidance[slot.id].get("valid", false):
							quick_assign_requested.emit(false, slot.id)
					elif side == 0 and pressed_slot_side == 0 and pressed_slot_id == slot.id:
						if slot.id < hero_guidance.size() and hero_guidance[slot.id].get("valid", false) and hero_guidance[slot.id].get("is_guard", false):
							quick_assign_requested.emit(true, slot.id)
					dragging = -1
					pressed_slot_side = -1
					pressed_slot_id = -1
				accept_event()
				return

	if not event.pressed:
		if dragging >= 0:
			aim_cancelled.emit()
		dragging = -1
		pressed_slot_side = -1
		pressed_slot_id = -1
		return

	for i in POINTS.size():
		var allied := i < 3
		var idx := i if allied else i - 3
		if idx >= state.get("heroes" if allied else "enemies", []).size():
			continue
		if Rect2(_actor_position(i) + Vector2(-58, -152), Vector2(116, 240)).has_point(point):
			unit_selected.emit(allied, idx)
			accept_event()
			return

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var local_pos := at_position * BASE / size
	return data is Dictionary and data.get("type", "") == "card" and SHARED_SUPPORT_RECT.has_point(local_pos)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var local_pos := at_position * BASE / size
	if SHARED_SUPPORT_RECT.has_point(local_pos):
		shared_support_dropped.emit(int(data.get("index", -1)))

func _arrow(a: Vector2, b: Vector2, color: Color, bend: float, thickness: float = 4.0, animated: bool = false) -> void:
	var points := PackedVector2Array()
	var mid := (a + b) * 0.5 + Vector2(0, bend)
	for i in 25:
		var t := i / 24.0
		points.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(points, Color(0.05, 0.04, 0.03, color.a * 0.85), thickness + 3.2, true)
	draw_polyline(points, color, thickness, true)
	if animated and color.a > 0.5:
		for k in 2:
			var frac := fmod(time * 0.72 + float(k) * 0.5, 1.0)
			var idx := clampi(int(frac * 24.0), 0, 24)
			var pt := points[idx]
			draw_circle(pt, 4.5, Color(color, 0.40))
			draw_circle(pt, 2.5, Color("fff8e6", color.a))
	var direction := (b - points[23]).normalized()
	var head_size := 18.0 + thickness * 0.6
	draw_colored_polygon(PackedVector2Array([b, b - direction.rotated(0.45) * head_size, b - direction.rotated(-0.45) * head_size]), color)

func _short_skill_name(key: String) -> String:
	if not Rules.SKILLS.has(key):
		return key
	var full: String = String(Rules.SKILLS[key].get("name", key))
	if full.length() <= 3:
		return full
	return full.substr(0, 3)

func _planning_overlay() -> void:
	if not state.has("hero_slots"):
		return

	var has_focus := dragging >= 0 or hovered_slot_side >= 0
	var focus_enemy_id := hovered_slot_id if hovered_slot_side == 1 else -1
	var focus_hero_id := dragging if dragging >= 0 else (hovered_slot_id if hovered_slot_side == 0 else -1)

	# 1. Enemy intention arrows (with smart focus highlight & de-clutter)
	var warned_heroes := {}
	for slot in state.enemy_slots:
		if slot.active and slot.category != 2 and not slot.done:
			var related := false
			if focus_enemy_id == slot.id:
				related = true
			elif focus_hero_id >= 0 and focus_hero_id < state.hero_slots.size():
				var h_focus: Dictionary = state.hero_slots[focus_hero_id]
				if h_focus.unit == slot.target or (h_focus.active and h_focus.get("target", -1) == slot.id):
					related = true
			var opacity := 0.14 if busy else (0.95 if related else (0.20 if has_focus else 0.52))
			var thick := 5.0 if related else 3.2
			if related and not busy:
				warned_heroes[slot.target] = true
			_arrow(slot_position(false, slot.id), _actor_position(slot.target) + Vector2(0, -142), Color(RED, opacity), -58.0 - slot.id * 4.5, thick, related and not busy)

	# Subtle crimson danger ring under hero targeted by focused enemy
	for hero_idx in warned_heroes.keys():
		var hp := _actor_position(hero_idx)
		var r := 52.0 + sin(time * 6.0) * 3.0
		draw_arc(hp + Vector2(0, 2), r, 0, TAU, 32, Color(RED, 0.72), 2.5, true)

	# 2. Hero planned arrows
	for slot in state.hero_slots:
		if slot.active and not slot.done and slot.has("ally_target"):
			_arrow(slot_position(true, slot.id), _actor_position(slot.ally_target) + Vector2(0, -142), Color(RED, 0.7), -52.0)
		elif slot.active and slot.get("targeted", slot.category != 2) and not slot.done:
			var related: bool = focus_hero_id == slot.id or focus_enemy_id == int(slot.target)
			var opacity := 0.16 if busy else (0.96 if related else (0.26 if has_focus else 0.76))
			var thick := 5.0 if related else 3.8
			_arrow(slot_position(true, slot.id), slot_position(false, slot.target), Color(BLUE, opacity), 58.0 + slot.id * 3.5, thick, related and not busy)

	# 3. Per-group hero action quota pills (e.g. ●○ 1/2)
	var group_counts := {}
	var group_limits := {}
	var group_anchors := {}
	for slot in state.hero_slots:
		var gkey := "%d_%d" % [slot.unit, slot.get("row", 0)]
		if not group_counts.has(gkey):
			group_counts[gkey] = 0
			group_limits[gkey] = Rules.group_action_limit(slot)
		if slot.active:
			group_counts[gkey] += 1
		if slot.category == 1:
			group_anchors[gkey] = slot_position(true, slot.id) + Vector2(0, -37.0)
	for gkey in group_anchors.keys():
		var anchor: Vector2 = group_anchors[gkey]
		var used: int = int(group_counts[gkey])
		var lim: int = int(group_limits[gkey])
		var dots := ""
		for d in lim:
			dots += "●" if d < used else "○"
		var txt := "%s 已满" % dots if used >= lim else "%s %d/%d" % [dots, used, lim]
		var pill_col := Color(0.18, 0.14, 0.08, 0.90) if used >= lim else Color(0.10, 0.14, 0.12, 0.84)
		var b_col := GOLD if used >= lim else Color("89a693")
		_draw_pill(anchor, txt, 11, pill_col, b_col, GOLD if used >= lim else Color("e9f0e6"))

	# 4. Action Slots (both sides)
	for side in 2:
		var slots: Array = state.hero_slots if side == 0 else state.enemy_slots
		for slot in slots:
			_draw_action_slot(side == 0, slot)

	# 5. Live Drag Arrow & Real-Time Verdict Capsule
	if dragging >= 0:
		var snap_pos := pointer
		var verdict := {}
		if hovered_slot_side == 1 and hovered_slot_id >= 0:
			snap_pos = slot_position(false, hovered_slot_id)
			if hovered_slot_id < target_guidance.size():
				verdict = target_guidance[hovered_slot_id]
		var drag_col := GOLD
		if not verdict.is_empty():
			if not verdict.get("valid", false):
				drag_col = RED
			elif verdict.get("kind", "") == "intercept":
				drag_col = INTERCEPT_TARGET
			elif verdict.get("kind", "") == "engage":
				drag_col = VALID_TARGET
		_arrow(slot_position(true, dragging), snap_pos, drag_col, 34.0, 4.8, true)
		if not verdict.is_empty():
			var tip_text: String = verdict.get("detail", verdict.get("text", ""))
			if not tip_text.is_empty():
				var cap_pos := Vector2(clampf(snap_pos.x, 150.0, BASE.x - 150.0), maxf(24.0, snap_pos.y - 46.0))
				var cap_border := drag_col
				var cap_bg := Color(0.11, 0.09, 0.07, 0.95)
				_draw_pill(cap_pos, tip_text, 12, cap_bg, cap_border, Color("fff8e8"))

func _draw_action_slot(allied: bool, slot: Dictionary) -> void:
	var pos := slot_position(allied, slot.id)
	var rect := Rect2(pos - SLOT_SIZE * 0.5, SLOT_SIZE)
	var accent: Color = SLOT_COLORS[slot.category]
	var chosen: bool = slot.id == (active_slot if allied else target_slot)
	var is_hovered: bool = hovered_slot_side == (0 if allied else 1) and hovered_slot_id == slot.id

	var h_guide: Dictionary = hero_guidance[slot.id] if (allied and slot.id < hero_guidance.size()) else {}
	var t_guide: Dictionary = target_guidance[slot.id] if ((not allied) and slot.id < target_guidance.size()) else {}
	var hero_ready_highlight: bool = allied and h_guide.get("valid", false) and not busy
	var group_full: bool = allied and h_guide.get("group_full", false) and not slot.active

	# Soft drop shadow
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.02, 0.03, 0.02, 0.55), true)

	# Outer pulse halo for valid guided targets / ready hero slots
	if hero_ready_highlight:
		var pulse := 0.55 + 0.45 * sin(time * 6.0)
		var glow_col := BLUE if h_guide.get("is_guard", false) else GOLD
		draw_rect(rect.grow(3.5), Color(glow_col, 0.28 * pulse), true)
		draw_rect(rect.grow(3.5), Color(glow_col, 0.85 * pulse), false, 2.2)
	elif not allied and not t_guide.is_empty() and t_guide.get("valid", false) and not busy:
		var pulse := 0.55 + 0.45 * sin(time * 5.5)
		var t_col := _target_kind_color(t_guide.get("kind", "solo"))
		draw_rect(rect.grow(3.0), Color(t_col, 0.24 * pulse), true)

	# Slot body background
	var body_fill := Color(0.11, 0.14, 0.13, 0.90)
	if slot.active:
		body_fill = accent.darkened(0.58)
		body_fill.a = 0.95
	elif group_full or slot.get("frozen", false):
		body_fill = Color(0.10, 0.11, 0.12, 0.72)
	elif is_hovered:
		body_fill = Color(0.18, 0.22, 0.19, 0.94)
	draw_rect(rect, body_fill, true)

	# Top category header bar (15px tall)
	var header_rect := Rect2(rect.position, Vector2(rect.size.x, 16.0))
	var header_col := accent.darkened(0.22 if slot.active else 0.55)
	if group_full:
		header_col = Color("394043")
	draw_rect(header_rect, header_col, true)

	# Border styling
	var border := GOLD if chosen else (accent if slot.active else accent.darkened(0.35))
	var border_width := 2.4 if (chosen or is_hovered) else 1.4
	if not allied and not t_guide.is_empty():
		if t_guide.get("valid", false):
			border = _target_kind_color(t_guide.get("kind", "solo"))
			border_width = 3.0 if is_hovered else 2.4
		else:
			border = Color("5f686a")
			border_width = 1.2
	elif hero_ready_highlight:
		border = BLUE if h_guide.get("is_guard", false) else GOLD
		border_width = 2.6
	draw_rect(rect, border, false, border_width)

	# Header text: Left = Category glyph, Right = Speed number badge
	var kind_char: String = "技" if slot.get("flexible", false) else ["攻", "大", "防"][slot.category]
	if slot.get("frozen", false):
		kind_char = "停"
	_text(kind_char, rect.position + Vector2(13.0, 12.0), 11, Color("fff8eb") if (slot.active or hero_ready_highlight) else Color("c9d3cf"))
	var spd_rect := Rect2(rect.position + Vector2(28.0, 2.0), Vector2(23.0, 12.0))
	draw_rect(spd_rect, Color(0.08, 0.09, 0.08, 0.80), true)
	_text(str(slot.speed), spd_rect.get_center() + Vector2(0, 4.0), 11, GOLD, mono_font)

	# Center body content
	if allied:
		if slot.active:
			var cname := _short_skill_name(slot.key)
			if slot.get("enhanced", false):
				cname = "★" + cname
			_text(cname, rect.position + Vector2(rect.size.x * 0.5, 31.0), 11, Color("fff8e8"))
			var skill_cost := int(Rules.SKILLS[slot.key].get("cost", 0)) if Rules.SKILLS.has(slot.key) else 0
			_text("%d费" % skill_cost, rect.position + Vector2(rect.size.x * 0.5, 43.0), 10, GOLD)
		elif slot.get("frozen", false):
			_text("停时", rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("8da3ab"))
		elif group_full:
			_text("已满", rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("7f8b8e"))
		elif hero_ready_highlight:
			var prompt := "点此防" if h_guide.get("is_guard", false) else ("当前槽" if chosen else "可安排")
			_text(prompt, rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, BLUE if h_guide.get("is_guard", false) else GOLD)
		else:
			_text("空", rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("8fa19a"))
		# Clear golden downward pointer above the currently active hero slot when planning
		if chosen and not busy and state.get("phase", "") == "response":
			var tip := Vector2(pos.x, rect.position.y - 3.0 + sin(time * 5.0) * 1.8)
			var tri := PackedVector2Array([tip, tip + Vector2(-5.5, -7.0), tip + Vector2(5.5, -7.0)])
			draw_colored_polygon(tri, GOLD)
	else:
		if slot.active:
			if state.get("phase", "") == "response":
				_text("已锁", rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("ffd9cf"))
			else:
				_text(_short_skill_name(slot.get("key", "")), rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("fff3e2"))
		else:
			_text("待机", rect.position + Vector2(rect.size.x * 0.5, 36.0), 11, Color("99aba3") if t_guide.get("valid", false) else Color("6e7b79"))

	# Enemy target relation micro-badge right below enemy slot (迎击 / 拦截 / 单打 / 不可)
	if not allied and not t_guide.is_empty() and not busy:
		var tag: String = t_guide.get("tag", "")
		if not tag.is_empty():
			var is_valid: bool = t_guide.get("valid", false)
			var t_col := _target_kind_color(t_guide.get("kind", "solo")) if is_valid else Color("6d7678")
			var bg := Color(0.08, 0.11, 0.09, 0.92) if is_valid else Color(0.11, 0.12, 0.13, 0.80)
			_draw_pill(pos + Vector2(0, SLOT_SIZE.y * 0.5 + 11.0), tag, 10, bg, t_col, t_col if is_valid else Color("98a2a5"))

func _target_kind_color(kind: String) -> Color:
	match kind:
		"engage": return VALID_TARGET
		"intercept": return INTERCEPT_TARGET
		"flank": return Color("ff9f43")
		"solo": return SOLO_TARGET
		_: return Color("6d7678")

func _draw_pill(center: Vector2, text: String, font_size: int, bg: Color, border: Color, text_col: Color) -> void:
	if face_font == null:
		return
	var width := face_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pw := width + 12.0
	var ph := float(font_size) + 6.0
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	draw_rect(rect, bg, true)
	draw_rect(rect, border, false, 1.3)
	draw_string(face_font, Vector2(rect.position.x + 6.0, rect.position.y + ph - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

func _draw() -> void:
	var total_shake := impact * 5.0 + screen_shake * 12.0
	var wobble := Vector2(sin(time * 120.0), cos(time * 140.0)) * total_shake
	draw_set_transform(wobble, 0.0, size / BASE)
	_background()
	if state.is_empty():
		return
	for i in POINTS.size():
		var allied := i < 3
		var idx := i if allied else i - 3
		if idx >= (state.heroes.size() if allied else state.enemies.size()):
			continue
		var unit: Dictionary = state.heroes[idx] if allied else state.enemies[idx]
		var selected := idx == selected_hero if allied else idx == selected_enemy
		_actor(i, unit, allied, selected)
	_draw_shared_support_slot()
	_planning_overlay()
	_draw_overlay()
	_draw_momentum_hud()
	for item in floaters:
		var p: Vector2 = item.position + Vector2(0, -item.age * 36.0)
		var color: Color = item.color
		color.a *= clampf((1.5 - item.age) * 2.0, 0.0, 1.0)
		_text(item.text, p, int(item.get("size", 29)), color, mono_font)
	if not banner.is_empty():
		_draw_pill(Vector2(690, 32), banner, 16, Color(0.11, 0.09, 0.07, 0.90), GOLD, GOLD)
	draw_set_transform(Vector2.ZERO)

func _background() -> void:
	if station_texture != null:
		draw_texture_rect(station_texture, Rect2(Vector2.ZERO, BASE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, BASE), Color("2a3a2c"))
		draw_rect(Rect2(0, 292, BASE.x, 118), Color("222d22"))
		draw_line(Vector2(0, 292), Vector2(BASE.x, 292), Color("8ea67c"), 2)
	# Subtle feathered upper sky scrim so action slots & clash arrows read with crystal clarity
	draw_rect(Rect2(0, 0, BASE.x, 68), Color(0.06, 0.09, 0.07, 0.34))
	draw_rect(Rect2(0, 68, BASE.x, 54), Color(0.06, 0.09, 0.07, 0.16))
	# Gentle sunlit pollen dust motes floating in the clearing
	for i in 14:
		var fi := float(i)
		var px := fmod(fi * 0.193 + time * (0.012 + float(i % 3) * 0.004), 1.0) * BASE.x
		var py := (0.14 + fmod(fi * 0.317, 0.62)) * BASE.y + sin(time * 1.4 + fi * 1.7) * 8.0
		var a := 0.25 + 0.35 * sin(time * 2.3 + fi * 1.5)
		draw_circle(Vector2(px, py), 2.2, Color(1.0, 0.95, 0.66, a))
	# Bottom warm stage caption strip
	draw_rect(Rect2(0, 378, BASE.x, 32), Color(0.11, 0.09, 0.07, 0.80))
	draw_line(Vector2(0, 378), Vector2(BASE.x, 378), Color(GOLD, 0.35), 1.0)
	_text("晨曦林野 · 交锋", Vector2(96, 399), 13, GOLD)
	_text("选牌后可直接点击高亮敌方槽，或从我方槽拖向敌方槽；右键我方槽可快速撤销", Vector2(705, 399), 13, Color("efe3c8"))

func _actor(id: int, unit: Dictionary, allied: bool, selected: bool) -> void:
	var point: Vector2 = _actor_position(id) + motions[id]
	var alive: bool = unit.hp > 0
	var accent: Color = [Color("f0c66d"), Color("76d1da"), Color("9cd685")][id] if allied else RED
	if not allied:
		match unit.get("kind", ""):
			"scout": accent = Color("e0a470")
			"warden": accent = Color("d0c8b8")
			"priest": accent = Color("88d6cb")
			"elite": accent = Color("e09e54")
			"phantom": accent = Color("a48fd6")
			"lich": accent = Color("76b5c5")
			"marauder": accent = Color("d9534f")
			"wyvern": accent = Color("e67e22")
	var alpha := 1.0 if alive else 0.24
	var acted: bool = unit.acted if allied else unit.spent
	if acted and alive and not busy:
		alpha = 0.72
	var shadow := Color(0.05, 0.06, 0.04, 0.56)
	draw_set_transform(point * size / BASE, 0, size / BASE)
	draw_ellipse_shadow(Vector2.ZERO, Vector2(52, 10), shadow)
	if selected and alive:
		draw_arc(Vector2(0, 2), 52, PI * 0.02, PI * 0.98, 28, Color(accent, 0.75), 2.4, true)
		draw_arc(Vector2(0, 2), 52, PI * 1.05, PI * 1.95, 28, Color(accent, 0.35), 1.2, true)
		_glow(Vector2(0, -74), 88, Color(accent, 0.035))
	var character_id := int(unit.get("character_id", -1))
	var region: Rect2 = HERO_SPRITES[character_id] if character_id in [0, 1, 2] else ENEMY_SPRITES.get(unit.get("kind", ""), Rect2())
	var sprite_height := 162.0 if allied else (170.0 if unit.get("kind", "") in ["elite", "warden"] else 158.0)
	var bob := sin(time * 2.1 + id * 1.5) * 1.2 if alive else 0.0
	var texture := actors_texture
	if allied and unit.has("metaphysics"):
		texture = zixi_texture
		if texture != null:
			region = Rect2(Vector2.ZERO, texture.get_size())
	if allied and unit.has("memory_log"):
		texture = zixingyc_texture
		if texture != null:
			region = Rect2(Vector2.ZERO, texture.get_size())
	if allied and character_id in [3, 4]:
		texture = null
	if not allied and unit.get("kind", "") == "priest":
		texture = priest_texture
		region = Rect2(Vector2(35, 12), Vector2(1165, 1244))
	if texture != null and region.size.y > 0:
		var sprite_width := sprite_height * region.size.x / region.size.y
		var ink := Color.WHITE.lerp(Color(1.45, 1.39, 1.32), flashes[id])
		ink.a = alpha
		var sprite_rect := Rect2(-sprite_width * 0.5, -sprite_height + bob + 2, sprite_width, sprite_height)
		draw_texture_rect_region(texture, sprite_rect, region, ink)
	else:
		_draw_placeholder_actor(accent, alpha, bob, flashes[id])
	if unit.shield > 0 and alive:
		draw_arc(Vector2(0, -71), 76, -PI * 0.7, PI * 0.7, 32, Color(BLUE, 0.78), 2.4, true)
		_draw_pill(Vector2(0, -158), "护盾 %d" % unit.shield, 12, Color(0.08, 0.14, 0.16, 0.88), BLUE, BLUE)
	draw_set_transform(Vector2.ZERO, 0, size / BASE)

	# High-contrast walnut nameplate card beneath actor so text pops over sunlit stone & grass
	var plate := Rect2(_actor_position(id) + Vector2(-58, 12), Vector2(116, 62))
	draw_rect(plate, Color(0.11, 0.09, 0.07, 0.82), true)
	draw_rect(plate, Color(accent, 0.65 if selected else 0.30), false, 1.4)
	_text(unit.name, _actor_position(id) + Vector2(0, 30), 15, Color(accent, alpha))
	var hp_rect := Rect2(_actor_position(id) + Vector2(-46, 38), Vector2(92, 5))
	draw_rect(hp_rect, Color("2a231c"))
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * maxf(unit.hp, 0) / unit.max_hp, 5)), Color(accent, alpha))
	_text("%02d / %02d" % [unit.hp, unit.max_hp], _actor_position(id) + Vector2(0, 56), 11, Color("efe4cc"), mono_font)
	if not allied and alive and unit.has("exorcism"):
		var status := "退治 %d/4" % unit.exorcism
		if unit.exorcism_active:
			status += " · 已引爆"
		if unit.seal_active:
			status += " · 封魔"
		_text(status, _actor_position(id) + Vector2(0, 70), 10, RED)
	elif allied:
		_text("已行动" if acted else "规划中", _actor_position(id) + Vector2(0, 70), 10, Color("999f98") if acted else BLUE)
		if alive and (unit.get("name", "") == "minghe" or unit.has("rhythm") or unit.get("character_id", -1) == Rules.MINGHE_ID):
			_draw_minghe_rhythm_badge(id, unit)
	elif alive:
		_draw_pill(_actor_position(id) + Vector2(0, -234), "已锁定 · 技能隐藏" if state.get("phase", "") == "response" else "行动已揭晓", 11, Color(0.16, 0.09, 0.08, 0.88), Color(RED, 0.75), Color("ffcdc6"))
	if not allied and alive:
		if not String(unit.get("weakness", "")).is_empty():
			_draw_enemy_weakness_and_fracture(id, unit)
		if unit.get("is_shattered", false):
			_draw_enemy_shattered_state(id, unit)

func _draw_placeholder_actor(accent: Color, alpha: float, bob: float, flash: float) -> void:
	var outline := Color(accent.lerp(Color.WHITE, flash), alpha)
	var cloak := PackedVector2Array([Vector2(-21, -112 + bob), Vector2(21, -112 + bob), Vector2(35, -18), Vector2(-35, -18), Vector2(-21, -112 + bob)])
	draw_colored_polygon(cloak, Color(outline.darkened(0.67), alpha))
	draw_polyline(cloak, outline, 2, true)
	draw_circle(Vector2(0, -129 + bob), 17, outline, true, -1, true)
	draw_line(Vector2(-15, -18), Vector2(-21, -2), outline, 6, true)
	draw_line(Vector2(15, -18), Vector2(21, -2), outline, 6, true)

func draw_ellipse_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _glow(center: Vector2, radius: float, color: Color) -> void:
	for i in range(6, 0, -1):
		draw_circle(center, radius * i / 6.0, Color(color, color.a * (7 - i) / 6.0))

func _text(value: String, center: Vector2, font_size: int, color: Color, font_override: Font = null) -> void:
	var used_font := face_font if font_override == null else font_override
	if used_font == null:
		return
	var width := used_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(used_font, center - Vector2(width / 2.0, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_overlay() -> void:
	if not overlay.is_empty():
		draw_rect(Rect2(524, 41, 332, 121), Color(0.08, 0.07, 0.05, 0.94))
		draw_rect(Rect2(524, 41, 332, 121), Color(GOLD, 0.8), false, 1.5)
		_text("CLASH / 拼点", Vector2(690, 66), 13, GOLD)
		_text(str(overlay.left), Vector2(600, 118), 44, BLUE, mono_font)
		_text("×", Vector2(690, 113), 24, Color("c4b9a4"))
		_text(str(overlay.right), Vector2(780, 118), 44, RED, mono_font)
		for side in 2:
			var count: int = overlay.hero_coins if side == 0 else overlay.enemy_coins
			var heads: int = overlay.left_heads if side == 0 else overlay.right_heads
			var center_x := 600.0 if side == 0 else 780.0
			for i in count:
				var p := Vector2(center_x + (i - (count - 1) / 2.0) * 17, 142)
				draw_circle(p, 4.0, GOLD if i < heads else Color("4a453c"))
	if sparks > 0:
		var center := contact_position
		if impact_texture != null:
			var extent := Vector2(176, 176) * (1.2 - sparks * 0.2)
			draw_texture_rect(impact_texture, Rect2(center - extent / 2.0, extent), false, Color(1, 1, 1, sparks))
		for i in 18:
			var angle := i * TAU / 18.0 + 0.17
			var length := (25.0 + (i % 5) * 14) * (1.3 - sparks * 0.4)
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(center + dir * 6, center + dir * length, Color(GOLD, sparks), 1.5 if i % 2 else 2.6, true)
		draw_line(center - Vector2(90, 40) * sparks, center + Vector2(90, 40) * sparks, Color(0.97, 0.89, 0.69, sparks), 3.5, true)

func _set_motion(value: Vector2, id: int) -> void:
	motions[id] = value

func _move_pair(a: int, b: int, offset_a: Vector2, offset_b: Vector2, duration: float) -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_motion.bind(a), motions[a], offset_a, duration)
	tween.tween_method(_set_motion.bind(b), motions[b], offset_b, duration)
	await tween.finished

func _contact(at: Vector2, strength: float, sound_kind: String, hold: float) -> void:
	contact_position = at
	impact_sound.emit(sound_kind)
	sparks = strength
	impact = strength
	holding_impact = true
	queue_redraw()
	await get_tree().create_timer(hold).timeout
	holding_impact = false

func play_event(event: Dictionary, speed: float) -> void:
	var duration := 1.0 / speed
	match event.type:
		"paid":
			banner = "%s  /  %s" % [state.heroes[event.hero].name, event.skill]
			await get_tree().create_timer(0.16 * duration).timeout
		"clash":
			var hero_id: int = event.hero
			var enemy_id: int = event.enemy + 3
			var decisive: bool = event.hero_remaining == 0 or event.enemy_remaining == 0
			overlay = event
			await _move_pair(hero_id, enemy_id, Vector2(-12, 0), Vector2(12, 0), 0.12 * duration)
			await _move_pair(hero_id, enemy_id, Vector2(620, 294) - _actor_position(hero_id), Vector2(766, 294) - _actor_position(enemy_id), 0.16 * duration)
			await _contact(Vector2(690, 200), 1.0 if decisive else 0.65, "strike" if decisive else "clash", (0.30 if decisive else 0.18) * duration)
			await get_tree().create_timer(0.20 * duration).timeout
			var result_text := "平局 · 再次交锋"
			if event.decider:
				result_text = "连续平局 · 决胜判定"
			elif event.winner == 0:
				result_text = "拼点获胜 · 敌方破币"
			elif event.winner == 1:
				result_text = "拼点失利 · 我方破币"
			floaters.append({"text": result_text, "position": Vector2(690, 238), "age": 0.0, "color": GOLD if event.winner == 0 else RED, "size": 18})
			await _move_pair(hero_id, enemy_id, Vector2.ZERO, Vector2.ZERO, 0.19 * duration)
			await get_tree().create_timer(0.12 * duration).timeout
			overlay.clear()
		"strike":
			var attacker: int = event.source if event.allied or event.get("friendly", false) else event.source + 3
			var victim: int = event.target + 3 if event.allied else event.target
			var direction := 1.0 if _actor_position(victim).x >= _actor_position(attacker).x else -1.0
			var travel: Vector2 = _actor_position(victim) - _actor_position(attacker) - Vector2(92 * direction, 0)
			await _move_pair(attacker, victim, Vector2(-14 * direction, 0), Vector2.ZERO, 0.10 * duration)
			await _move_pair(attacker, victim, travel, Vector2.ZERO, 0.15 * duration)
			flashes[victim] = 1.0
			floaters.append({"text": "−%d" % event.damage, "position": _actor_position(victim) + Vector2((event.hit - 1) * 18 - 12, -152 - (event.hit - 1) * 19), "age": 0.0, "color": RED if not event.allied else GOLD, "size": 33})
			await _contact(_actor_position(victim) + Vector2(0, -82), 1.0, "strike", (0.28 if event.hit == event.total else 0.17) * duration)
			await _move_pair(attacker, victim, Vector2.ZERO, Vector2(26 * direction, 0), 0.13 * duration)
			await _move_pair(attacker, victim, Vector2.ZERO, Vector2.ZERO, 0.11 * duration)
		"guard":
			flashes[event.hero] = 0.5
			floaters.append({"text": "+%d 护盾" % event.amount, "position": _actor_position(event.hero) + Vector2(0, -150), "age": 0.0, "color": BLUE, "size": 22})
			await get_tree().create_timer(0.4 * duration).timeout
		"stagger":
			var unit_id: int = event.unit if event.allied else event.unit + 3
			floaters.append({"text": "BREAK 失衡!", "position": _actor_position(unit_id) + Vector2(0, -170), "age": 0.0, "color": RED if event.allied else GOLD, "size": 24})
			await get_tree().create_timer(0.20 * duration).timeout
		"unopposed":
			floaters.append({"text": "单方夹击 +%d" % int(event.get("bonus", 2)), "position": _actor_position(event.hero) + Vector2(0, -165), "age": 0.0, "color": Color("ff9f43"), "size": 20})
			await get_tree().create_timer(0.16 * duration).timeout
		"overwhelm":
			var victim: int = event.target + 3 if event.allied else event.target
			flashes[victim] = 0.8
			floaters.append({"text": "压制 −%d" % event.damage, "position": _actor_position(victim) + Vector2(28, -195), "age": 0.0, "color": GOLD if event.allied else RED, "size": 22})
			await get_tree().create_timer(0.22 * duration).timeout
		"enemy_guard":
			flashes[event.enemy + 3] = 0.5
			floaters.append({"text": "+%d 护盾" % event.amount, "position": _actor_position(event.enemy + 3) + Vector2(0, -150), "age": 0.0, "color": BLUE, "size": 22})
			await get_tree().create_timer(0.4 * duration).timeout
		"momentum_gain":
			var m: int = int(event.momentum)
			var text_col := Color("f0ebd8") if m == 1 else (Color("ffd700") if m == 2 else Color("ff7043"))
			floaters.append({"text": "⚡ 势能 ×%d！" % m, "position": Vector2(690, 160), "age": 0.0, "color": text_col, "size": 24})
			await get_tree().create_timer(0.20 * duration).timeout
		"momentum_break":
			screen_shake = 1.3
			impact = 1.4
			impact_sound.emit("break")
			floaters.append({"text": "💔 势能中断！", "position": Vector2(690, 160), "age": 0.0, "color": RED, "size": 28})
			await get_tree().create_timer(0.35 * duration).timeout
		"shatter_stagger":
			var victim: int = event.target + 3
			flashes[victim] = 1.5
			screen_shake = 2.0
			impact = 2.2
			sparks = 2.0
			contact_position = _actor_position(victim) + Vector2(0, -90)
			impact_sound.emit("break")
			floaters.append({"text": "💥 碎甲大失衡！", "position": _actor_position(victim) + Vector2(0, -185), "age": 0.0, "color": Color("ff3b30"), "size": 30})
			await get_tree().create_timer(0.40 * duration).timeout
		"fracture_hit":
			var victim: int = event.target + 3
			flashes[victim] = 0.8
			var f_val: int = int(event.fracture)
			floaters.append({"text": "弱点破损 %d/3" % f_val, "position": _actor_position(victim) + Vector2(0, -135), "age": 0.0, "color": Color("f59e42"), "size": 22})
			await get_tree().create_timer(0.18 * duration).timeout
		"outcome":
			banner = "胜利" if event.result == "victory" else "败北"
			await get_tree().create_timer(0.6 * duration).timeout

func _weakness_info(weakness: String) -> Dictionary:
	var label := "斩"
	var col := Color("e26d5c")
	if weakness.contains("刺"):
		label = "刺"
		col = Color("48cae4")
	elif weakness.contains("重"):
		label = "重"
		col = Color("f4a261")
	return {"label": label, "color": col}

func _draw_enemy_weakness_and_fracture(id: int, unit: Dictionary) -> void:
	var w_info := _weakness_info(String(unit.get("weakness", "")))
	var pos := _actor_position(id) + Vector2(0, 85)
	var badge_rect := Rect2(pos + Vector2(-54, -10), Vector2(108, 20))
	draw_rect(badge_rect, Color(0.10, 0.08, 0.07, 0.90), true)
	draw_rect(badge_rect, Color("5c4d3e"), false, 1.1)
	
	# Weakness tag box on the left: e.g. [斩] / [刺] / [重]
	var tag_rect := Rect2(badge_rect.position + Vector2(4, 2), Vector2(26, 16))
	draw_rect(tag_rect, w_info.color.darkened(0.65), true)
	draw_rect(tag_rect, w_info.color, false, 1.2)
	_text(w_info.label, tag_rect.get_center() + Vector2(0, 4.0), 10, w_info.color)
	
	# Fracture progress meter: 3 dots (○ ○ ○ / ● ● ○ / ● ● ●)
	var fracture: int = clampi(int(unit.get("fracture", 0)), 0, 3)
	var dot_start_x := badge_rect.position.x + 46.0
	for d in 3:
		var dot_center := Vector2(dot_start_x + d * 18.0, pos.y)
		if d < fracture:
			draw_circle(dot_center, 5.0, Color(0.95, 0.25, 0.15, 0.35))
			draw_circle(dot_center, 3.6, Color("e63946"))
			draw_circle(dot_center, 1.8, Color("ffb703"))
		else:
			draw_circle(dot_center, 3.2, Color(0.16, 0.14, 0.12, 0.90))
			draw_arc(dot_center, 3.4, 0, TAU, 16, Color("7a6857"), 1.2, true)

func _draw_enemy_shattered_state(id: int, _unit: Dictionary) -> void:
	var head_pos := _actor_position(id) + Vector2(0, -204.0)
	var pulse := 0.75 + 0.25 * sin(time * 7.5)
	var border_col := Color("ff3b30").lerp(Color("ffcc00"), pulse)
	
	# 1. Pulsing head banner: 【💥 碎甲大失衡】
	var banner_w := 132.0
	var banner_h := 34.0
	var banner_rect := Rect2(head_pos.x - banner_w * 0.5, head_pos.y - banner_h * 0.5, banner_w, banner_h)
	
	draw_rect(banner_rect.grow(4.0), Color("ff3b30", 0.30 * pulse), true)
	draw_rect(banner_rect, Color(0.18, 0.05, 0.04, 0.95), true)
	draw_rect(banner_rect, border_col, false, 2.0)
	
	_text("💥 碎甲大失衡", head_pos + Vector2(0, -2.0), 12, border_col)
	_text("易伤 +50% · 速度锁1", head_pos + Vector2(0, 11.0), 10, Color("ffe082"))
	
	# 2. Pulsing fractured shards (脉冲碎光): rotating and pulsing gold & crimson shards
	var shard_origin := _actor_position(id) + Vector2(0, -78.0)
	for s in 8:
		var angle := s * TAU / 8.0 + time * 2.8
		var dist := 60.0 + sin(time * 6.5 + s * 1.4) * 12.0
		var sp := shard_origin + Vector2(cos(angle) * dist, sin(angle) * dist * 0.72)
		var shard_alpha := 0.50 + 0.45 * sin(time * 8.0 + s)
		var sc := Color("ff3b30" if s % 2 == 0 else "ffd700", shard_alpha)
		var sz := 4.5
		var shard_poly := PackedVector2Array([
			sp + Vector2(0, -sz * 1.4),
			sp + Vector2(sz, 0),
			sp + Vector2(0, sz * 1.4),
			sp + Vector2(-sz, 0)
		])
		draw_colored_polygon(shard_poly, sc)

func _draw_minghe_rhythm_badge(id: int, unit: Dictionary) -> void:
	var plate_pos := _actor_position(id)
	var badge_pos := plate_pos + Vector2(58 + 48, 43)
	var is_cooldown := int(unit.get("no_rhythm_round", 0)) == int(state.get("turn", 1))
	
	if is_cooldown:
		# 灰色冷光: 🚫 调谐冷却
		var bw := 92.0
		var bh := 24.0
		var brect := Rect2(badge_pos.x - bw * 0.5, badge_pos.y - bh * 0.5, bw, bh)
		draw_rect(brect.grow(2.5), Color(0.35, 0.45, 0.55, 0.22), true)
		draw_rect(brect, Color(0.12, 0.14, 0.17, 0.94), true)
		draw_rect(brect, Color("708a96"), false, 1.4)
		_text("🚫 调谐冷却", badge_pos + Vector2(0, 4.0), 11, Color("b8cdd6"))
	else:
		# 青金渐变色: 🎶 律动 ×N
		var rhythm := clampi(int(unit.get("rhythm", 0)), 0, 5)
		var bw := 96.0
		var bh := 28.0
		var brect := Rect2(badge_pos.x - bw * 0.5, badge_pos.y - bh * 0.5, bw, bh)
		
		var halo_col := Color("5de2d3").lerp(Color("f5c963"), float(rhythm) / 5.0)
		draw_rect(brect.grow(2.5), Color(halo_col, 0.22), true)
		draw_rect(brect, Color(0.08, 0.13, 0.12, 0.94), true)
		
		draw_line(brect.position, brect.position + Vector2(bw, 0), Color("5de2d3"), 1.6)
		draw_line(brect.position, brect.position + Vector2(0, bh), Color("5de2d3"), 1.6)
		draw_line(brect.position + Vector2(bw, 0), brect.position + Vector2(bw, bh), Color("f5c963"), 1.6)
		draw_line(brect.position + Vector2(0, bh), brect.position + Vector2(bw, bh), Color("f5c963"), 1.6)
		
		var text_col := Color("7cf5d8").lerp(Color("fde68a"), float(rhythm) / 5.0)
		_text("🎶 律动 ×%d" % rhythm, badge_pos + Vector2(0, -1.0), 11, text_col)
		
		var pip_start_x := brect.position.x + 16.0
		for b in 5:
			var pip_center := Vector2(pip_start_x + b * 16.0, badge_pos.y + 8.5)
			if b < rhythm:
				draw_circle(pip_center, 2.5, Color("5de2d3").lerp(Color("f5c963"), float(b) / 4.0))
			else:
				draw_circle(pip_center, 1.8, Color(0.24, 0.28, 0.28, 0.70))

func _draw_momentum_hud() -> void:
	var m: int = int(state.get("round_momentum", 0))
	if overlay.has("momentum"):
		m = int(overlay.momentum)
	if m <= 0:
		return
	var center := Vector2(690, 24)
	var title := "势能 ×%d" % m
	var desc := "势能起 · 拼点+1"
	var text_col := Color("fdfbf7")
	var border_col := Color("f0ebd8")
	var bg_col := Color(0.12, 0.11, 0.09, 0.94)
	
	match m:
		1:
			desc = "势能起 · 拼点+1"
			border_col = Color("f0ebd8")
			text_col = Color("fffdf5")
		2:
			desc = "势如破竹 · 拼点+1 震击+3"
			border_col = Color("ffd700")
			text_col = Color("fff59d")
			bg_col = Color(0.18, 0.14, 0.06, 0.96)
		_:
			title = "势能 ×%d MAX" % m
			desc = "势不可挡 · 拼点+2 贯穿+6"
			border_col = Color("ff4d22").lerp(Color("ffc83b"), 0.5 + 0.5 * sin(time * 7.0))
			text_col = Color("ffe082")
			bg_col = Color(0.22, 0.08, 0.06, 0.96)
	
	var full_text := "⚡ %s ｜ %s" % [title, desc]
	var tw := face_font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x if face_font else 220.0
	var pw := tw + 24.0
	var ph := 26.0
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	
	if m == 1:
		draw_rect(rect.grow(3.0), Color("f0ebd8", 0.20 * (0.8 + 0.2 * sin(time * 3.5))), true)
	elif m == 2:
		var p2 := 0.7 + 0.3 * sin(time * 6.0)
		draw_rect(rect.grow(4.5), Color("ffd700", 0.40 * p2), true)
		draw_rect(rect.grow(2.0), Color("fff176", 0.50 * p2), false, 1.2)
	else:
		var p3 := 0.7 + 0.3 * sin(time * 8.0)
		draw_rect(rect.grow(5.5), Color("ff3b10", 0.42 * p3), true)
		for st in 4:
			var t_pos := fmod(time * 1.8 + st * 0.25, 1.0)
			var pt := rect.position + Vector2(rect.size.x * t_pos, 0 if st % 2 == 0 else rect.size.y)
			draw_circle(pt, 3.5, Color("ffeb3b", 0.85))
	
	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 1.8)
	_text(full_text, center + Vector2(0, 4.5), 13, text_col)

func _point_on_rect(rect: Rect2, dist: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var p := fposmod(dist, 2.0 * (w + h))
	if p < w:
		return rect.position + Vector2(p, 0)
	p -= w
	if p < h:
		return rect.position + Vector2(w, p)
	p -= h
	if p < w:
		return rect.position + Vector2(w - p, h)
	p -= w
	return rect.position + Vector2(0, h - p)

func _draw_shared_support_slot() -> void:
	if not overlay.is_empty():
		return
	var rect: Rect2 = SHARED_SUPPORT_RECT
	var is_hovered: bool = rect.has_point(pointer)
	var support: Dictionary = state.get("shared_support_slot", {})
	var is_active: bool = support.get("active", false)
	
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0.04, 0.05, 0.03, 0.55), true)
	
	var parch_col: Color = Color("fffaf0") if is_hovered else Color("f6edd8")
	draw_rect(rect, parch_col, true)
	draw_rect(rect.grow(-3.5), Color("dfd2b5"), false, 1.0)
	
	var border_base := Color("d6a447")
	draw_rect(rect, border_base, false, 2.0)
	
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var flow_t := fmod(time * 0.9, 1.0)
	for k in 2:
		var dist := fmod(flow_t * perimeter + float(k) * (perimeter * 0.5), perimeter)
		var pt := _point_on_rect(rect, dist)
		draw_circle(pt, 4.2, Color("fff2a8", 0.95))
		draw_circle(pt, 2.2, Color.WHITE)
	
	if is_active:
		var sname: String = String(Rules.SKILLS[support.key].name) if Rules.SKILLS.has(support.key) else String(support.key)
		_text("【全队辅助】", Vector2(690, 320), 11, Color("8a561c"))
		_text("★ " + sname, Vector2(690, 338), 14, Color("2a1c12"))
		var hname: String = state.heroes[support.hero].name if support.hero >= 0 and support.hero < state.heroes.size() else ""
		var tname: String = state.heroes[support.support_target].name if support.get("support_target", -1) >= 0 and support.support_target < state.heroes.size() else ""
		var line := "%s 出牌" % hname
		if not tname.is_empty():
			line += " → " + tname
		_text(line, Vector2(690, 355), 10, Color("574332"))
	else:
		_text("【全队辅助槽】", Vector2(690, 326), 13, Color("2d2116"))
		_text("拖入或点击辅助牌放入", Vector2(690, 348), 11, Color("6b5442"))
		if is_hovered:
			draw_rect(rect.grow(3.0), Color("d6a447", 0.4), false, 2.0)
