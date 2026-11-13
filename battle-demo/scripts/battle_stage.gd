class_name DemoBattleStage
extends Control

signal unit_selected(allied: bool, index: int)
signal slot_selected(allied: bool, index: int)
signal aim_committed(source: int, target: int)
var active_slot := 0
var target_slot := 0
var dragging := -1
var pointer := Vector2.ZERO

const GOLD := Color("dfbc80")
const BLUE := Color("8bc8ce")
const RED := Color("e17d70")
const BASE := Vector2(1380, 410)
const HERO_SPRITES := [Rect2(96, 18, 315, 480), Rect2(570, 4, 402, 494), Rect2(1082, 26, 306, 472)]
const ENEMY_SPRITES := {
	"scout": Rect2(92, 550, 359, 458),
	"warden": Rect2(561, 513, 381, 497),
	"elite": Rect2(1043, 504, 414, 508),
}
const POINTS := [Vector2(228, 282), Vector2(369, 282), Vector2(510, 282), Vector2(951, 282), Vector2(1126, 282)]

var state: Dictionary = {}
var selected_hero := 0
var selected_enemy := 0
var busy := false
var time := 0.0
var motions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var flashes: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var impact := 0.0
var sparks := 0.0
var overlay: Dictionary = {}
var banner := ""
var floaters: Array[Dictionary] = []
var face_font: Font
var mono_font: Font
var station_texture: Texture2D
var actors_texture: Texture2D
var priest_texture: Texture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	face_font = get_theme_font("font")
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Bahnschrift", "Consolas"])
	station_texture = _optional_texture("res://art/rain-station.png")
	actors_texture = _optional_texture("res://art/battle-actors.png")
	priest_texture = _optional_texture("res://art/grave-priest.png")

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
	sparks = 0.0

func _process(delta: float) -> void:
	time += delta
	impact = maxf(0.0, impact - delta * 3.5)
	sparks = maxf(0.0, sparks - delta * 2.0)
	for i in flashes.size():
		flashes[i] = maxf(0.0, flashes[i] - delta * 3.5)
	for item in floaters:
		item.age += delta
	floaters = floaters.filter(func(item: Dictionary) -> bool: return item.age < 1.5)
	queue_redraw()

func slot_position(allied: bool, index: int) -> Vector2:
	var id := index / 3 if allied else index / 3 + 3
	return POINTS[id] + Vector2((index % 3 - 1) * 43, -190)

func _gui_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseMotion:
		pointer = event.position * BASE / size
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = event.position * BASE / size
	for side in 2:
		var slots: Array = state.get("hero_slots" if side == 0 else "enemy_slots", [])
		for slot in slots:
			if Rect2(slot_position(side == 0, slot.id) - Vector2(20, 17), Vector2(40, 34)).has_point(point):
				if event.pressed:
					slot_selected.emit(side == 0, slot.id)
					if side == 0:
						dragging = slot.id
						pointer = point
				elif side == 1 and dragging >= 0:
					aim_committed.emit(dragging, slot.id)
				if not event.pressed:
					dragging = -1
				accept_event()
				return
	if not event.pressed:
		dragging = -1
		return
	for i in POINTS.size():
		if Rect2(POINTS[i] + Vector2(-55, -150), Vector2(110, 240)).has_point(point):
			unit_selected.emit(i < 3, i if i < 3 else i - 3)
			accept_event()
			return

func _arrow(a: Vector2, b: Vector2, color: Color, bend: float) -> void:
	var points := PackedVector2Array()
	var mid := (a + b) * 0.5 + Vector2(0, bend)
	for i in 25:
		var t := i / 24.0
		points.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(points, color, 2.0, true)
	var direction := (b - points[23]).normalized()
	draw_colored_polygon(PackedVector2Array([b, b - direction.rotated(0.45) * 12, b - direction.rotated(-0.45) * 12]), color)

func _planning_overlay() -> void:
	if not state.has("hero_slots"):
		return
	var opacity := 0.18 if busy else 0.7
	for slot in state.enemy_slots:
		if slot.active and slot.category != 2 and not slot.done:
			_arrow(slot_position(false, slot.id), POINTS[slot.target] + Vector2(0, -145), Color(RED, opacity), -65.0 - slot.id * 5)
	for slot in state.hero_slots:
		if slot.active and slot.category != 2 and not slot.done:
			_arrow(slot_position(true, slot.id), slot_position(false, slot.target), Color(BLUE, opacity), 65.0 + slot.id * 4)
	for side in 2:
		var slots: Array = state.hero_slots if side == 0 else state.enemy_slots
		for slot in slots:
			var pos := slot_position(side == 0, slot.id)
			var accent := BLUE if side == 0 else RED
			var chosen: bool = slot.id == (active_slot if side == 0 else target_slot)
			draw_rect(Rect2(pos - Vector2(20, 17), Vector2(40, 34)), accent.darkened(0.35) if slot.active else Color("15222b"))
			draw_rect(Rect2(pos - Vector2(20, 17), Vector2(40, 34)), GOLD if chosen else accent.darkened(0.55), false, 2 if chosen else 1)
			_text(["攻", "大", "防"][slot.category], pos + Vector2(0, -2), 11, Color("f4e8d5") if slot.active else Color("697c85"))
			_text(str(slot.speed), pos + Vector2(0, 12), 12, GOLD)
	if dragging >= 0:
		_arrow(slot_position(true, dragging), pointer, GOLD, 35)

func _draw() -> void:
	var wobble := Vector2(sin(time * 116.0), cos(time * 133.0)) * impact * 5.0
	draw_set_transform(wobble, 0.0, size / BASE)
	_background()
	if state.is_empty():
		return
	for i in POINTS.size():
		var allied := i < 3
		var idx := i if allied else i - 3
		var unit: Dictionary = state.heroes[idx] if allied else state.enemies[idx]
		var selected := idx == selected_hero if allied else idx == selected_enemy
		_actor(i, unit, allied, selected)
	_planning_overlay()
	_draw_overlay()
	for item in floaters:
		var p: Vector2 = item.position + Vector2(0, -item.age * 36.0)
		var color: Color = item.color
		color.a *= clampf((1.5 - item.age) * 2.0, 0.0, 1.0)
		_text(item.text, p, int(item.get("size", 29)), color, mono_font)
	if not banner.is_empty():
		_text(banner, Vector2(690, 37), 18, GOLD)
	draw_set_transform(Vector2.ZERO)

func _background() -> void:
	if station_texture != null:
		draw_texture_rect(station_texture, Rect2(Vector2.ZERO, BASE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, BASE), Color("182630"))
		draw_rect(Rect2(0, 282, BASE.x, 128), Color("111b23"))
		draw_line(Vector2(0, 282), Vector2(BASE.x, 282), Color("52605e"), 2)
	draw_rect(Rect2(0, 0, BASE.x, 115), Color(0.025, 0.045, 0.06, 0.32))
	draw_rect(Rect2(0, 292, BASE.x, 84), Color(0.025, 0.045, 0.06, 0.50))
	draw_rect(Rect2(0, 376, BASE.x, 34), Color(0.025, 0.045, 0.06, 0.81))
	_text("北境废站", Vector2(89, 398), 13, Color("c2a77d"))
	_text("选择角色和手牌，拖动行动格接招", Vector2(690, 398), 13, Color("b0bdc1"))


func _actor(id: int, unit: Dictionary, allied: bool, selected: bool) -> void:
	var point: Vector2 = POINTS[id] + motions[id]
	var alive: bool = unit.hp > 0
	var accent: Color = [Color("d5b27a"), Color("8cbfc8"), Color("b8bf94")][id] if allied else RED
	if not allied:
		match unit.get("kind", ""):
			"scout": accent = Color("cd9a6f")
			"warden": accent = Color("b5b0a3")
			"priest": accent = Color("88c7bd")
			"elite": accent = Color("c38e4f")
	var alpha := 1.0 if alive else 0.24
	var acted: bool = unit.acted if allied else unit.spent
	if acted and alive and not busy:
		alpha = 0.68
	var shadow := Color(0.01, 0.02, 0.03, 0.7)
	draw_set_transform(point * size / BASE, 0, size / BASE)
	draw_ellipse_shadow(Vector2.ZERO, Vector2(49, 9), shadow)
	if selected and alive:
		draw_arc(Vector2(0, 2), 49, PI * 0.02, PI * 0.98, 28, Color(accent, 0.5), 2, true)
		draw_arc(Vector2(0, 2), 49, PI * 1.05, PI * 1.95, 28, Color(accent, 0.25), 1, true)
		_glow(Vector2(0, -74), 91, Color(accent, 0.025))
	var region: Rect2 = HERO_SPRITES[id] if allied else ENEMY_SPRITES.get(unit.kind, Rect2())
	var sprite_height := 168.0 if allied else (177.0 if unit.kind in ["elite", "warden"] else 164.0)
	var bob := sin(time * 2.1 + id * 1.5) * 1.2 if alive else 0.0
	var texture := actors_texture
	if not allied and unit.kind == "priest":
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
		draw_arc(Vector2(0, -71), 78, -PI * 0.7, PI * 0.7, 32, Color(BLUE, 0.65), 2, true)
		_text("护盾 %d" % unit.shield, Vector2(0, -162), 13, BLUE)
	draw_set_transform(Vector2.ZERO, 0, size / BASE)
	var name_pos: Vector2 = POINTS[id] + Vector2(0, 31)
	_text(unit.name, name_pos, 17, Color(accent, alpha))
	var hp_rect := Rect2(POINTS[id] + Vector2(-47, 42), Vector2(94, 4))
	draw_rect(hp_rect, Color("27343a"))
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * maxf(unit.hp, 0) / unit.max_hp, 4)), Color(accent, alpha))
	_text("%02d / %02d" % [unit.hp, unit.max_hp], POINTS[id] + Vector2(0, 64), 12, Color("8b999b"), mono_font)
	if allied:
		_text("已行动" if acted else "规划中", POINTS[id] + Vector2(0, 84), 11, Color("677c81") if acted else BLUE)
	elif alive:
		_text("已锁定 · 技能隐藏" if state.get("phase", "") == "response" else "行动已揭晓", POINTS[id] + Vector2(0, -220), 12, RED)

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
		draw_rect(Rect2(524, 41, 332, 121), Color(0.025, 0.04, 0.05, 0.94))
		draw_line(Vector2(524, 41), Vector2(856, 41), Color(GOLD, 0.75), 1)
		_text("CLASH / 拼点", Vector2(690, 66), 13, GOLD)
		_text(str(overlay.left), Vector2(600, 118), 44, BLUE, mono_font)
		_text("×", Vector2(690, 113), 24, Color("9e998a"))
		_text(str(overlay.right), Vector2(780, 118), 44, RED, mono_font)
		for side in 2:
			var count: int = overlay.hero_coins if side == 0 else overlay.enemy_coins
			var heads: int = overlay.left_heads if side == 0 else overlay.right_heads
			var center_x := 600.0 if side == 0 else 780.0
			for i in count:
				var p := Vector2(center_x + (i - (count - 1) / 2.0) * 17, 142)
				draw_circle(p, 4.0, GOLD if i < heads else Color("3e4c51"))
	if sparks > 0:
		var center := Vector2(690, 190)
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

func play_event(event: Dictionary, speed: float) -> void:
	var duration := 1.0 / speed
	match event.type:
		"paid":
			banner = "%s  /  %s" % [state.heroes[event.hero].name, event.skill]
			await get_tree().create_timer(0.16 * duration).timeout
		"clash":
			var hero_id: int = event.hero
			var enemy_id: int = event.enemy + 3
			overlay = event
			await _move_pair(hero_id, enemy_id, Vector2(620, 282) - POINTS[hero_id], Vector2(766, 282) - POINTS[enemy_id], 0.16 * duration)
			sparks = 1.0
			impact = 0.65
			await get_tree().create_timer(0.20 * duration).timeout
			var result_text := "平局 · 再次交锋"
			if event.decider:
				result_text = "连续平局 · 决胜判定"
			elif event.winner == 0:
				result_text = "拼点获胜 · 敌方破币"
			elif event.winner == 1:
				result_text = "拼点失利 · 我方破币"
			floaters.append({"text": result_text, "position": Vector2(690, 230), "age": 0.0, "color": GOLD if event.winner == 0 else RED, "size": 18})
			await _move_pair(hero_id, enemy_id, Vector2.ZERO, Vector2.ZERO, 0.19 * duration)
			await get_tree().create_timer(0.12 * duration).timeout
			overlay.clear()
		"strike":
			var attacker: int = event.source if event.allied else event.source + 3
			var victim: int = event.target + 3 if event.allied else event.target
			var direction := 1.0 if event.allied else -1.0
			var travel: Vector2 = POINTS[victim] - POINTS[attacker] - Vector2(92 * direction, 0)
			await _move_pair(attacker, victim, travel, Vector2.ZERO, 0.15 * duration)
			impact = 1.0
			flashes[victim] = 1.0
			floaters.append({"text": "−%d" % event.damage, "position": POINTS[victim] + Vector2((event.hit - 1) * 18 - 12, -152 - (event.hit - 1) * 19), "age": 0.0, "color": RED if not event.allied else GOLD, "size": 33})
			await get_tree().create_timer(0.09 * duration).timeout
			await _move_pair(attacker, victim, Vector2.ZERO, Vector2(17 * direction, 0), 0.13 * duration)
			await _move_pair(attacker, victim, Vector2.ZERO, Vector2.ZERO, 0.11 * duration)
		"guard":
			flashes[event.hero] = 0.5
			floaters.append({"text": "+9 护盾", "position": POINTS[event.hero] + Vector2(0, -150), "age": 0.0, "color": BLUE, "size": 22})
			await get_tree().create_timer(0.4 * duration).timeout
		"refund", "reward":
			await get_tree().create_timer(0.2 * duration).timeout
		"enemy_turn":
			banner = "%s  /  敌方行动" % state.enemies[event.enemy].name
			await get_tree().create_timer(0.3 * duration).timeout
		"unopposed":
			banner = "敌方行动已消耗  /  单方面攻击"
			await get_tree().create_timer(0.25 * duration).timeout
		"new_turn":
			banner = "ROUND %02d  /  cost +3" % state.turn
			await get_tree().create_timer(0.6 * duration).timeout
		"outcome":
			await get_tree().create_timer(0.35 * duration).timeout
