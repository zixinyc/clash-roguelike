class_name DemoBattleStage
extends Control

signal unit_selected(allied: bool, index: int)

const GOLD := Color("dfbc80")
const BLUE := Color("8bc8ce")
const RED := Color("e17d70")
const BASE := Vector2(1380, 410)
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

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	face_font = get_theme_font("font")
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Bahnschrift", "Consolas"])

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

func _gui_input(event: InputEvent) -> void:
	if busy or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point: Vector2 = event.position * BASE / size
	for i in POINTS.size():
		if Rect2(POINTS[i] + Vector2(-64, -190), Vector2(128, 260)).has_point(point):
			unit_selected.emit(i < 3, i if i < 3 else i - 3)
			accept_event()
			return

func _draw() -> void:
	var wobble := Vector2(sin(time * 116.0), cos(time * 133.0)) * impact * 5.0
	draw_set_transform(wobble, 0.0, size / BASE)
	_background()
	if state.is_empty():
		return
	if not busy and state.outcome.is_empty():
		var a: Vector2 = POINTS[selected_hero] + Vector2(0, -89)
		var b: Vector2 = POINTS[selected_enemy + 3] + Vector2(0, -89)
		if state.heroes[selected_hero].hp > 0 and state.enemies[selected_enemy].hp > 0:
			for k in range(0, 38):
				var p: Vector2 = a.lerp(b, k / 38.0)
				draw_circle(p, 1.1, Color(0.85, 0.7, 0.44, 0.14))
	for i in POINTS.size():
		var allied := i < 3
		var idx := i if allied else i - 3
		var unit: Dictionary = state.heroes[idx] if allied else state.enemies[idx]
		var selected := idx == selected_hero if allied else idx == selected_enemy
		_actor(i, unit, allied, selected)
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
	draw_rect(Rect2(Vector2.ZERO, BASE), Color("101c26"))
	for i in 22:
		var alpha := 0.02 + i * 0.003
		draw_rect(Rect2(0, i * 14.0, BASE.x, 14), Color(0.31, 0.43, 0.48, alpha))
	draw_circle(Vector2(772, 72), 55, Color(0.7, 0.79, 0.76, 0.045))
	draw_circle(Vector2(772, 72), 33, Color(0.76, 0.81, 0.76, 0.12))
	draw_circle(Vector2(787, 62), 31, Color("14212b"))
	for i in 15:
		var x := i * 112.0 - 80
		var h := 34.0 + fmod(i * 37.0, 78.0)
		draw_rect(Rect2(x, 158 - h, 67, h + 80), Color("14212a"))
		for j in 3:
			draw_rect(Rect2(x + 12 + j * 16, 151 - h, 3, 5), Color(0.8, 0.65, 0.4, 0.17))
	draw_rect(Rect2(0, 162, BASE.x, 92), Color("101b22"))
	for i in 18:
		var x := i * 81.0 - 20
		draw_rect(Rect2(x, 183, 48, 40), Color("26343a"))
		draw_rect(Rect2(x + 3, 186, 42, 34), Color(0.68, 0.53, 0.3, 0.08 + fmod(i * 0.031, 0.08)))
		draw_line(Vector2(x + 24, 185), Vector2(x + 24, 221), Color("14232b"), 2)
	draw_line(Vector2(0, 242), Vector2(BASE.x, 242), Color("3e4849"), 2)
	for x in [74.0, 650.0, 1306.0]:
		draw_rect(Rect2(x - 8, 0, 16, 278), Color("0b151d"))
		draw_rect(Rect2(x - 15, 241, 30, 38), Color("101920"))
		draw_line(Vector2(x, 25), Vector2(x + 136, 0), Color("0a141b"), 11)
		draw_line(Vector2(x, 25), Vector2(x - 136, 0), Color("0a141b"), 11)
	draw_rect(Rect2(0, 0, BASE.x, 8), Color("0b141c"))
	draw_line(Vector2(0, 17), Vector2(BASE.x, 17), Color(0.6, 0.7, 0.7, 0.07))
	for x in [130.0, 568.0, 1210.0]:
		draw_line(Vector2(x, 0), Vector2(x, 47), Color("25333b"), 2)
		_glow(Vector2(x, 54), 28, Color(0.97, 0.72, 0.35, 0.05))
		draw_rect(Rect2(x - 16, 46, 32, 5), Color("ac8a54"))
	_text("07", Vector2(78, 53), 26, Color("667d82"), mono_font)
	_text("NORTH TERMINAL / 北境废站", Vector2(202, 75), 12, Color("5f777e"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 277), Vector2(1380, 277), Vector2(1380, 410), Vector2(0, 410)]), Color("111b23"))
	for i in 13:
		var x := i * 148.0 - 250
		draw_line(Vector2(690 + (x - 690) * 0.55, 277), Vector2(x, 410), Color(0.35, 0.43, 0.47, 0.1))
	for y in [286.0, 310.0, 358.0, 402.0]:
		draw_line(Vector2(0, y), Vector2(1380, y), Color(0.42, 0.5, 0.51, 0.08))
	draw_rect(Rect2(0, 278, 1380, 3), Color("77715b"))
	for i in 40:
		var x := i * 36.0
		draw_rect(Rect2(x, 281, 19, 3), Color(0.81, 0.65, 0.36, 0.2))
	for i in 34:
		var p := Vector2(fposmod(i * 97.3 + time * (3 + i % 3), 1380), 52 + fposmod(i * 43.7 - time * 4, 220))
		draw_circle(p, 0.7 + (i % 2) * 0.4, Color(0.76, 0.82, 0.75, 0.08 + 0.06 * sin(time + i)))
	draw_rect(Rect2(0, 376, BASE.x, 34), Color(0.025, 0.045, 0.06, 0.7))
	_text("TEAM / 小队", Vector2(75, 399), 11, Color("617e86"))
	_text("HOSTILES / 敌方", Vector2(1251, 399), 11, Color("91695f"))
	_text("点击角色或敌人进行选择", Vector2(690, 399), 12, Color("70858c"))

func _actor(id: int, unit: Dictionary, allied: bool, selected: bool) -> void:
	var point: Vector2 = POINTS[id] + motions[id]
	var alive: bool = unit.hp > 0
	var accent: Color = [Color("d5b27a"), Color("8cbfc8"), Color("b8bf94")][id] if allied else RED
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
	var facing := 1.0 if allied else -1.0
	var bob := sin(time * 2.1 + id * 1.5) * 1.5 if alive else 0.0
	var body_color := Color("182831") if allied else Color("28272a")
	var edge := Color("40545b") if allied else Color("65504b")
	if flashes[id] > 0:
		body_color = body_color.lerp(Color("ddd8c6"), flashes[id])
	var body_points := PackedVector2Array([Vector2(-22, -111), Vector2(10, -116), Vector2(28, -87), Vector2(17, -42), Vector2(30, -12), Vector2(-9, -23), Vector2(-31, -7), Vector2(-25, -57), Vector2(-32, -88)])
	for i in body_points.size():
		body_points[i].x *= facing
		body_points[i].y += bob
	var body_tint := Color(body_color, alpha)
	draw_colored_polygon(body_points, body_tint)
	draw_polyline(body_points, Color(edge, alpha), 1.5, true)
	_poly([Vector2(-18, -37), Vector2(-4, -37), Vector2(-5, -3), Vector2(-22, -3)], Color("0c171f"), facing, bob, alpha)
	_poly([Vector2(3, -34), Vector2(16, -36), Vector2(25, -2), Vector2(9, -2)], Color("101b22"), facing, bob, alpha)
	draw_line(Vector2(-22 * facing, -2), Vector2(-2 * facing, -2), Color(edge, alpha), 3, true)
	draw_line(Vector2(9 * facing, -2), Vector2(28 * facing, -2), Color(edge, alpha), 3, true)
	_poly([Vector2(-11, -132), Vector2(9, -135), Vector2(18, -125), Vector2(12, -110), Vector2(-8, -110), Vector2(-16, -119)], Color("a6a59a") if allied else Color("ad9b86"), facing, bob, alpha)
	_poly([Vector2(-18, -133), Vector2(1, -146), Vector2(20, -134), Vector2(18, -124), Vector2(4, -128), Vector2(-9, -122), Vector2(-16, -115)], Color("0c1720") if allied else Color("3a3632"), facing, bob, alpha)
	draw_line(Vector2(8 * facing, -122 + bob), Vector2(15 * facing, -123 + bob), Color(accent, alpha), 2)
	_poly([Vector2(-15, -111), Vector2(12, -110), Vector2(8, -101), Vector2(-17, -99), Vector2(-35, -102), Vector2(-63, -88 + sin(time * 3 + id) * 4), Vector2(-44, -107)], accent.darkened(0.18), facing, bob, alpha)
	_poly([Vector2(-10, -98), Vector2(2, -100), Vector2(11, -67), Vector2(-2, -52)], accent.darkened(0.58), facing, bob, alpha)
	draw_line(Vector2(-5 * facing, -91 + bob), Vector2(-13 * facing, -50), Color(edge, alpha), 1.5)
	draw_line(Vector2(-23 * facing, -53), Vector2(18 * facing, -53), Color(accent.darkened(0.55), alpha), 4)
	_poly([Vector2(15, -102), Vector2(33, -90), Vector2(40, -67), Vector2(30, -60), Vector2(20, -80)], body_color.lightened(0.04), facing, bob, alpha)
	draw_circle(Vector2(35 * facing, -66 + bob), 5, Color(Color("9b9d94"), alpha))
	if id == 1:
		draw_line(Vector2(-7 * facing, -27), Vector2(72 * facing, -160), Color(Color("6c7372"), alpha), 4, true)
		_poly([Vector2(66, -153), Vector2(76, -177), Vector2(77, -153)], Color("c1d5d1"), facing, bob, alpha)
	elif id == 2:
		draw_arc(Vector2(35 * facing, -86), 27, 0.2, 5.8, 18, Color(accent, alpha), 3, true)
		draw_circle(Vector2(35 * facing, -86), 8, Color(accent, alpha * 0.5))
	else:
		draw_line(Vector2(31 * facing, -55), Vector2(53 * facing, -96), Color(Color("a19980"), alpha), 4, true)
		_poly([Vector2(48, -87), Vector2(55, -106), Vector2(82, -143), Vector2(87, -126), Vector2(61, -87)], Color("b7c3bd") if allied else Color("bca088"), facing, bob, alpha)
		draw_line(Vector2(57 * facing, -95), Vector2(81 * facing, -132), Color(Color("e0dfc9"), alpha), 1)
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
		_text("已行动" if acted else "待命", POINTS[id] + Vector2(0, 84), 11, Color("677c81") if acted else BLUE)
	elif alive:
		var intent_color := Color("6e7779") if acted else RED
		_text("行动已消耗" if acted else unit.intent, POINTS[id] + Vector2(0, -201), 14, intent_color)
		if not acted:
			_text("%d—%d   → %s" % [unit.base, unit.base + unit.power * unit.coins, state.heroes[maxi(0, unit.target)].name], POINTS[id] + Vector2(0, -181), 12, Color("b19483"))
			draw_colored_polygon(PackedVector2Array([POINTS[id] + Vector2(-4, -169), POINTS[id] + Vector2(4, -169), POINTS[id] + Vector2(0, -163)]), intent_color)

func draw_ellipse_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

func _poly(points: Array, color: Color, facing: float, bob: float, alpha: float) -> void:
	var array := PackedVector2Array()
	for p in points:
		array.append(Vector2(p.x * facing, p.y + bob))
	draw_colored_polygon(array, Color(color, alpha))

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
