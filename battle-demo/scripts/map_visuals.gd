class_name ForestMapVisuals
extends RefCounted

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")

## 阳光奇幻风格废林地图表现层工具：配色、氛围光尘、晨雾、古道路径、16类矢量徽章与立体行动骰盘

const WALNUT_DEEP := Color("241b13")
const WALNUT_BG := Color("33261a")
const WALNUT_HOVER := Color("463423")
const WALNUT_BORDER := Color("8c6b3b")
const BRASS_GOLD := Color("d6a447")
const SUN_GOLD := Color("f5c963")
const PARCHMENT := Color("f6edd8")
const PARCHMENT_SOFT := Color("ebe0c5")
const INK_DARK := Color("2b1e12")
const INK_MUTED := Color("634e38")
const CREAM_TEXT := Color("fbf3df")
const EMERALD_LIGHT := Color("6bc275")
const CRIMSON_WARN := Color("cf4036")
const AQUA_INTEL := Color("2fa6b8")

static var _icon_cache: Dictionary = {}

static func floor_theme(floor_level: int) -> Dictionary:
	var idx := (maxi(1, floor_level) - 1) % 3
	match idx:
		0:
			return {
				"name": "晨雾翠林",
				"terrain_modulate": Color(0.98, 0.99, 0.94, 1.0),
				"glaze": Color(0.96, 0.93, 0.78, 0.06),
				"beam_color": Color(1.0, 0.94, 0.70, 0.14),
				"mote_color": Color(1.0, 0.95, 0.64, 0.75),
				"leaf_color": Color(0.56, 0.82, 0.36, 0.68),
				"mist_color": Color(0.96, 0.97, 0.92, 0.44),
				"vignette": Color(0.10, 0.16, 0.09, 0.24)
			}
		1:
			return {
				"name": "金秋枫径",
				"terrain_modulate": Color(1.04, 0.92, 0.78, 1.0),
				"glaze": Color(0.98, 0.76, 0.46, 0.08),
				"beam_color": Color(1.0, 0.84, 0.50, 0.16),
				"mote_color": Color(1.0, 0.86, 0.45, 0.78),
				"leaf_color": Color(0.92, 0.48, 0.22, 0.75),
				"mist_color": Color(0.97, 0.92, 0.82, 0.42),
				"vignette": Color(0.18, 0.11, 0.06, 0.26)
			}
		_:
			return {
				"name": "暮光古原",
				"terrain_modulate": Color(1.02, 0.87, 0.82, 1.0),
				"glaze": Color(0.96, 0.68, 0.54, 0.09),
				"beam_color": Color(1.0, 0.76, 0.54, 0.15),
				"mote_color": Color(1.0, 0.82, 0.55, 0.78),
				"leaf_color": Color(0.94, 0.62, 0.38, 0.72),
				"mist_color": Color(0.95, 0.90, 0.87, 0.42),
				"vignette": Color(0.16, 0.10, 0.10, 0.28)
			}

static func make_box(fill: Color, border: Color, width: int = 1, radius: int = 8, pad_x: int = 10, pad_y: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box

## Tidy 公共视觉主题构造器：统一所有页面为「胡桃木 + 黄铜金 + 羊皮纸」正式版美术体系
static func create_ember_theme(base_font_size: int = 14) -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = base_font_size
	skin.set_stylebox("normal", "Button", make_box(Color("453423"), WALNUT_BORDER, 1, 6, 10, 6))
	skin.set_stylebox("hover", "Button", make_box(Color("59432c"), SUN_GOLD, 1, 6, 10, 6))
	skin.set_stylebox("pressed", "Button", make_box(Color("695034"), SUN_GOLD, 2, 6, 10, 6))
	skin.set_stylebox("disabled", "Button", make_box(Color("2d2218"), Color("54422c"), 1, 6, 10, 6))
	skin.set_color("font_color", "Button", CREAM_TEXT)
	skin.set_color("font_hover_color", "Button", Color("fff8e6"))
	skin.set_color("font_pressed_color", "Button", SUN_GOLD)
	skin.set_color("font_disabled_color", "Button", Color("8f7d64"))
	skin.set_stylebox("normal", "LineEdit", make_box(Color("2a1f16"), WALNUT_BORDER, 1, 6, 10, 6))
	skin.set_stylebox("focus", "LineEdit", make_box(Color("34261b"), SUN_GOLD, 2, 6, 10, 6))
	skin.set_color("font_color", "LineEdit", CREAM_TEXT)
	skin.set_color("font_placeholder_color", "LineEdit", Color("9c8a70"))
	skin.set_color("font_color", "CheckBox", CREAM_TEXT)
	skin.set_color("font_hover_color", "CheckBox", Color("fff8e6"))
	skin.set_color("font_pressed_color", "CheckBox", SUN_GOLD)
	return skin

static func optional_node_texture(kind: int) -> Texture2D:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var path := ForestMapGraph.kind_texture_path(kind)
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[kind] = tex
	return tex

static func draw_sunlit_atmosphere(canvas: Control, rect: Rect2, pulse_time: float, floor_level: int) -> void:
	var theme := floor_theme(floor_level)
	var w := rect.size.x
	var h := rect.size.y

	# 1. Warm glaze to unify terrain contrast for crisp map cartography
	canvas.draw_rect(rect, theme.glaze, true)

	# 2. Gentle diagonal golden sunbeams from top-left canopy
	var beam_col: Color = theme.beam_color
	for i in 4:
		var sway := sin(pulse_time * 0.45 + float(i) * 1.4) * 18.0
		var x0 := -40.0 + float(i) * (w * 0.19) + sway
		var width_top := 42.0 + float(i % 2) * 26.0
		var width_bot := width_top * 2.1
		var reach_y := h * (0.62 + float(i % 2) * 0.16)
		var shift_x := reach_y * 0.62
		var poly := PackedVector2Array([
			Vector2(x0, 0.0),
			Vector2(x0 + width_top, 0.0),
			Vector2(x0 + shift_x + width_bot, reach_y),
			Vector2(x0 + shift_x, reach_y)
		])
		var col := beam_col
		col.a *= 0.72 + 0.28 * sin(pulse_time * 0.7 + float(i) * 1.9)
		canvas.draw_colored_polygon(poly, col)

	# 3. Soft warm framing vignette strips (subtle storybook edge focus)
	var vig: Color = theme.vignette
	var band := 26.0
	for step in 3:
		var t := float(3 - step) / 3.0
		var b := band * (0.45 + 0.55 * t)
		var c := Color(vig.r, vig.g, vig.b, vig.a * t * 0.42)
		canvas.draw_rect(Rect2(0, 0, w, b), c, true)
		canvas.draw_rect(Rect2(0, h - b, w, b), c, true)
		canvas.draw_rect(Rect2(0, 0, b, h), c, true)
		canvas.draw_rect(Rect2(w - b, 0, b, h), c, true)

	# 4. Floating sunlit pollen motes & gentle drifting leaves
	var mote_col: Color = theme.mote_color
	var leaf_col: Color = theme.leaf_color
	for i in 26:
		var fi := float(i)
		var seed_x := fmod(fi * 0.371 + 0.07, 1.0)
		var seed_y := fmod(fi * 0.619 + 0.11, 1.0)
		var drift_x := fmod(seed_x + pulse_time * (0.008 + float(i % 4) * 0.003), 1.0)
		var drift_y := fmod(seed_y - pulse_time * (0.006 + float(i % 3) * 0.002) + 10.0, 1.0)
		var px := drift_x * w + sin(pulse_time * 1.1 + fi * 2.1) * 12.0
		var py := drift_y * h + cos(pulse_time * 0.9 + fi * 1.7) * 8.0
		var twinkle := 0.45 + 0.55 * sin(pulse_time * 2.2 + fi * 1.3)
		if i % 5 == 0:
			var lcol := leaf_col
			lcol.a *= twinkle
			var ang := pulse_time * 0.9 + fi
			var dir := Vector2(cos(ang), sin(ang)) * 4.5
			var perp := Vector2(-dir.y, dir.x) * 0.45
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(px, py) - dir,
				Vector2(px, py) + perp,
				Vector2(px, py) + dir,
				Vector2(px, py) - perp
			]), lcol)
		else:
			var r := 1.6 + float(i % 3) * 0.8
			var mcol := mote_col
			mcol.a *= twinkle
			canvas.draw_circle(Vector2(px, py), r + 2.2, Color(mcol.r, mcol.g, mcol.b, mcol.a * 0.22))
			canvas.draw_circle(Vector2(px, py), r, mcol)

static func draw_morning_mist(canvas: Control, run: RefCounted, w: float, h: float, pulse_time: float, floor_level: int) -> void:
	var mist_base: Color = floor_theme(floor_level).mist_color
	for node in run.map.nodes.values():
		var n := node as ForestMapGraph.MapNode
		if run.known.has(n.id):
			continue
		var pos := Vector2(n.pos.x * w, n.pos.y * h)
		var hval := float(absi(n.id.hash()) % 100) * 0.0628
		var drift := Vector2(sin(pulse_time * 0.55 + hval) * 7.0, cos(pulse_time * 0.42 + hval) * 4.0)
		# Multi-ring feathered morning mist cloud puffs (soft airy edge, no hard circles)
		for puff in [Vector2(-18, 5), Vector2(18, -5), Vector2(0, 0)]:
			var c: Vector2 = pos + drift + puff
			var base_r := 38.0 if puff == Vector2.ZERO else 31.0
			for ring in range(4, 0, -1):
				var frac := float(ring) / 4.0
				var alpha := mist_base.a * (0.14 if ring == 4 else (0.18 if ring == 3 else (0.22 if ring == 2 else 0.28)))
				canvas.draw_circle(c, base_r * frac, Color(mist_base.r, mist_base.g, mist_base.b, alpha))

static func draw_map_edges(canvas: Control, run: RefCounted, w: float, h: float, pulse_time: float, font: Font) -> void:
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
		var points := ForestMapGraph.bezier_points(p0, p1, edge.bend, 22)

		var is_travelled: bool = run.travelled.has(edge.id)
		var touches_current: bool = edge.from_id == run.position or edge.to_id == run.position
		var other_id: String = edge.other(run.position) if touches_current else ""
		var is_reachable_edge: bool = touches_current and run.can_move(other_id)
		var both_hidden: bool = not run.known.has(edge.from_id) and not run.known.has(edge.to_id)
		var any_visible: bool = run.visible.has(edge.from_id) or run.visible.has(edge.to_id)

		if is_travelled:
			canvas.draw_polyline(points, Color(WALNUT_DEEP, 0.72), 7.5, true)
			canvas.draw_polyline(points, Color(BRASS_GOLD, 0.96), 4.2, true)
			canvas.draw_polyline(points, Color(CREAM_TEXT, 0.70), 1.6, true)
		elif is_reachable_edge:
			var from_pos := p0 if edge.from_id == run.position else p1
			var to_pos := p1 if edge.from_id == run.position else p0
			var dir_pts := ForestMapGraph.bezier_points(from_pos, to_pos, edge.bend if edge.from_id == run.position else -edge.bend, 22)
			var glow := 0.72 + 0.28 * sin(pulse_time * 4.5)
			var main_col := AQUA_INTEL.lightened(0.25) if edge.kind == ForestMapGraph.RouteKind.SHORTCUT else SUN_GOLD
			canvas.draw_polyline(dir_pts, Color(WALNUT_DEEP, 0.75), 7.2, true)
			_draw_dashed_polyline(canvas, dir_pts, Color(main_col, 0.95 * glow), 3.6, 10.0, 6.0)
			# Animated flowing light beads along reachable path
			for b in 3:
				var frac := fmod(pulse_time * 0.48 + float(b) / 3.0, 1.0)
				var pt := _sample_polyline(dir_pts, frac)
				canvas.draw_circle(pt, 5.2, Color(main_col, 0.34))
				canvas.draw_circle(pt, 2.8, CREAM_TEXT)
			# Step cost pill near midpoint
			var mid_pt := _sample_polyline(dir_pts, 0.52)
			var badge_txt := "%d步·%d情报" % [edge.action_cost, edge.intel_cost] if edge.intel_cost > 0 else "%d步" % edge.action_cost
			_draw_pill_label(canvas, font, mid_pt + Vector2(0, -10), badge_txt, 11, Color(WALNUT_DEEP, 0.90), main_col, CREAM_TEXT)
		else:
			var base_col: Color = ForestMapGraph.route_color(edge.kind)
			var alpha := 0.16 if both_hidden else (0.80 if any_visible else 0.42)
			var shadow_a := 0.09 if both_hidden else (0.58 if any_visible else 0.28)
			var lw := 2.8 if edge.kind == ForestMapGraph.RouteKind.MAIN else 2.2
			canvas.draw_polyline(points, Color(WALNUT_DEEP, shadow_a), lw + 2.8, true)
			if edge.kind == ForestMapGraph.RouteKind.SHORTCUT:
				_draw_dashed_polyline(canvas, points, Color(AQUA_INTEL.lightened(0.2), alpha), lw, 5.0, 7.0)
			elif edge.kind == ForestMapGraph.RouteKind.LOOP:
				_draw_dashed_polyline(canvas, points, Color(base_col, alpha), lw, 7.0, 6.0)
			else:
				_draw_dashed_polyline(canvas, points, Color(base_col, alpha), lw, 11.0, 5.0)

static func draw_patrol_signals(canvas: Control, run: RefCounted, w: float, h: float, pulse_time: float, font: Font) -> void:
	for sig in run.signals:
		var node_id: String = sig.get("node", "")
		if not run.known.has(node_id):
			continue
		var node = run.map.get_node(node_id)
		if node == null:
			continue
		var pos := Vector2(node.pos.x * w, node.pos.y * h)
		var skind: String = sig.get("kind", "")
		if skind == "noise":
			var phase := fmod(pulse_time * 0.9, 1.0)
			var r1 := 24.0 + phase * 22.0
			var r2 := 24.0 + fmod(phase + 0.5, 1.0) * 22.0
			canvas.draw_arc(pos, r1, 0, TAU, 28, Color(CRIMSON_WARN, (1.0 - phase) * 0.72), 2.2, true)
			canvas.draw_arc(pos, r2, 0, TAU, 28, Color(CRIMSON_WARN, (1.0 - fmod(phase + 0.5, 1.0)) * 0.65), 1.8, true)
			_draw_pill_label(canvas, font, pos + Vector2(0, -34), "响动", 10, Color(WALNUT_DEEP, 0.85), CRIMSON_WARN, Color("ffb8ad"))
		elif skind == "track":
			var badge_pos := pos + Vector2(20, -18)
			canvas.draw_circle(badge_pos, 9.5, Color(WALNUT_DEEP, 0.90))
			canvas.draw_arc(badge_pos, 9.5, 0, TAU, 18, Color("e8833a"), 1.6, true)
			# Three tiny claw slashes
			for c in range(-1, 2):
				var off := Vector2(float(c) * 3.0, 0.0)
				canvas.draw_line(badge_pos + off + Vector2(-2, -4), badge_pos + off + Vector2(2, 4), Color("ff9e5e"), 1.5, true)

static func draw_map_node(canvas: Control, n: ForestMapGraph.MapNode, run: RefCounted, pos: Vector2, is_hovered: bool, pulse_time: float, font: Font) -> void:
	var is_current: bool = n.id == run.position
	var is_visible: bool = run.visible.has(n.id)
	var is_known: bool = run.known.has(n.id)
	var is_reachable: bool = run.can_move(n.id)
	var is_cleared: bool = run.cleared.has(n.id)

	var tier := ForestMapGraph.kind_tier(n.kind)
	var radius := 25.0 if tier == 2 else (21.5 if tier == 1 else 18.5)
	if is_hovered and is_known:
		radius += 2.2

	var accent := ForestMapGraph.kind_color(n.kind)

	# Ground drop shadow for boardgame medallion depth
	canvas.draw_circle(pos + Vector2(0, 4.5), radius + 2.0, Color(0.08, 0.06, 0.03, 0.42))

	# Outer state rings & halos
	if is_current:
		var halo := radius + 8.5 + sin(pulse_time * 3.8) * 2.5
		canvas.draw_circle(pos, halo + 4.0, Color(SUN_GOLD, 0.24))
		canvas.draw_arc(pos, halo, 0, TAU, 36, SUN_GOLD, 2.8, true)
		# Rotating 4-point brass compass ticks around current hero token
		for k in 4:
			var ang := pulse_time * 0.7 + float(k) * (PI * 0.5)
			var p_in := pos + Vector2(cos(ang), sin(ang)) * (halo - 3.0)
			var p_out := pos + Vector2(cos(ang), sin(ang)) * (halo + 5.5)
			canvas.draw_line(p_in, p_out, CREAM_TEXT, 2.2, true)
	elif is_reachable:
		var reach_r := radius + 6.0 + sin(pulse_time * 5.0) * 2.2
		canvas.draw_circle(pos, reach_r + 2.5, Color(SUN_GOLD, 0.22))
		canvas.draw_arc(pos, reach_r, 0, TAU, 32, SUN_GOLD, 2.6, true)
	elif is_hovered and is_known:
		canvas.draw_arc(pos, radius + 4.5, 0, TAU, 28, Color(CREAM_TEXT, 0.85), 2.0, true)

	# Landmark ornate diamond aura for Boss Altar & Stone Gate Exit
	if tier == 2 and is_known:
		var d_r := radius + 4.5
		var diamond := PackedVector2Array([
			pos + Vector2(0, -d_r),
			pos + Vector2(d_r, 0),
			pos + Vector2(0, d_r),
			pos + Vector2(-d_r, 0)
		])
		canvas.draw_colored_polygon(diamond, Color(WALNUT_DEEP, 0.82))
		canvas.draw_polyline(diamond + PackedVector2Array([diamond[0]]), BRASS_GOLD if is_visible else Color(BRASS_GOLD, 0.5), 2.0, true)

	# Medallion base disc
	if not is_known:
		canvas.draw_circle(pos, radius, Color(0.84, 0.87, 0.80, 0.80))
		canvas.draw_arc(pos, radius, 0, TAU, 24, Color(0.45, 0.50, 0.44, 0.88), 2.2, true)
		canvas.draw_arc(pos, radius - 3.5, 0, TAU, 24, Color(0.97, 0.96, 0.90, 0.55), 1.0, true)
		var q_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		canvas.draw_string(font, pos + Vector2(-q_size.x * 0.5, 6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("5a6657"))
		return

	var fill_col := PARCHMENT if is_visible else Color("cfc7b2")
	if is_cleared and not is_current and n.kind != ForestMapGraph.NodeKind.SHOP and n.kind != ForestMapGraph.NodeKind.DESTINY_GATE:
		fill_col = Color("d8d1be")
	if is_current:
		fill_col = Color("fff7e0")

	var rim_col := accent if is_visible else accent.darkened(0.32)
	if is_cleared and not is_current and n.kind != ForestMapGraph.NodeKind.SHOP and n.kind != ForestMapGraph.NodeKind.DESTINY_GATE:
		rim_col = rim_col.lerp(Color("7b7462"), 0.55)

	# Walnut outer shadow rim -> colored ring -> parchment medallion body
	canvas.draw_circle(pos, radius + 1.5, WALNUT_DEEP)
	canvas.draw_circle(pos, radius, rim_col)
	canvas.draw_circle(pos, radius - 3.4, fill_col)
	canvas.draw_arc(pos, radius - 4.6, 0, TAU, 28, Color(rim_col, 0.35), 1.0, true)

	# Emblem (optional PNG icon or crisp handcrafted vector illustration)
	var icon_col := rim_col.darkened(0.22) if is_visible else Color("5f584a")
	if is_current:
		icon_col = Color("a66314")
	var tex := optional_node_texture(n.kind)
	if tex != null:
		var s := (radius - 5.0) * 1.65
		canvas.draw_texture_rect(tex, Rect2(pos - Vector2(s * 0.5, s * 0.5), Vector2(s, s)), false, Color.WHITE if is_visible else Color(0.85, 0.85, 0.85, 0.8))
	else:
		draw_node_emblem(canvas, n.kind, pos, radius * 0.56, icon_col, is_current)

	# Floating golden pointer crest above current position
	if is_current:
		var bob := sin(pulse_time * 4.2) * 3.0
		var tip := pos + Vector2(0, -radius - 8.0 + bob)
		var tri := PackedVector2Array([tip, tip + Vector2(-7, -11), tip + Vector2(7, -11)])
		canvas.draw_colored_polygon(tri, SUN_GOLD)
		canvas.draw_polyline(tri + PackedVector2Array([tip]), WALNUT_DEEP, 1.8, true)

	# Cleared emerald-gold stamp badge
	if is_cleared:
		var stamp := pos + Vector2(radius * 0.72, -radius * 0.72)
		canvas.draw_circle(stamp, 7.5, WALNUT_DEEP)
		canvas.draw_circle(stamp, 6.0, Color("4fa362"))
		canvas.draw_polyline(PackedVector2Array([
			stamp + Vector2(-3.2, 0.2),
			stamp + Vector2(-0.6, 2.8),
			stamp + Vector2(3.4, -2.6)
		]), CREAM_TEXT, 1.8, true)

	# High-contrast nameplate pill underneath node
	var label_y := pos.y + radius + 13.0
	var bg_col := Color(WALNUT_DEEP, 0.88 if is_visible else 0.72)
	var border_col := SUN_GOLD if (is_current or is_reachable) else Color(WALNUT_BORDER, 0.85 if is_visible else 0.45)
	var txt_col := CREAM_TEXT if is_visible else Color("d5ccb8")
	_draw_pill_label(canvas, font, Vector2(pos.x, label_y), n.name, 11, bg_col, border_col, txt_col)

static func draw_patrol_beast(canvas: Control, pos: Vector2, pulse_time: float, font: Font) -> void:
	var halo := 28.0 + sin(pulse_time * 6.0) * 3.5
	canvas.draw_circle(pos, halo, Color(CRIMSON_WARN, 0.16))
	canvas.draw_arc(pos, halo, 0, TAU, 28, CRIMSON_WARN, 2.8, true)
	_draw_pill_label(canvas, font, pos + Vector2(0, -34), "巡游恶兽", 11, Color("5c1414", 0.94), Color("ff786b"), CREAM_TEXT)

static func draw_node_emblem(canvas: Control, kind: int, c: Vector2, r: float, col: Color, is_current: bool = false) -> void:
	if is_current:
		# Radiant adventurer compass star when player is standing here
		var pts := PackedVector2Array()
		for i in 8:
			var ang := float(i) * PI * 0.25 - PI * 0.5
			var rad := r * (1.05 if i % 2 == 0 else 0.42)
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		canvas.draw_colored_polygon(pts, Color("d98a1c"))
		canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), WALNUT_DEEP, 1.4, true)
		canvas.draw_circle(c, r * 0.22, CREAM_TEXT)
		return

	match kind:
		ForestMapGraph.NodeKind.SPAWN:
			# 4-point compass diamond
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.42, 0), c + Vector2(0, r), c + Vector2(-r * 0.42, 0)])
			canvas.draw_colored_polygon(pts, col)
			canvas.draw_line(c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0), col, 2.0, true)
			canvas.draw_circle(c, r * 0.22, PARCHMENT)
		ForestMapGraph.NodeKind.BATTLE:
			# Crossed twin swords
			canvas.draw_line(c + Vector2(-r * 0.72, -r * 0.72), c + Vector2(r * 0.72, r * 0.72), col, 2.6, true)
			canvas.draw_line(c + Vector2(r * 0.72, -r * 0.72), c + Vector2(-r * 0.72, r * 0.72), col, 2.6, true)
			canvas.draw_line(c + Vector2(-r * 0.82, r * 0.35), c + Vector2(-r * 0.25, r * 0.85), col, 2.2, true)
			canvas.draw_line(c + Vector2(r * 0.82, r * 0.35), c + Vector2(r * 0.25, r * 0.85), col, 2.2, true)
		ForestMapGraph.NodeKind.ELITE:
			# Crowned horned skull / elite crest
			var crown := PackedVector2Array([
				c + Vector2(-r * 0.78, r * 0.45),
				c + Vector2(-r * 0.85, -r * 0.55),
				c + Vector2(-r * 0.32, -r * 0.08),
				c + Vector2(0, -r * 0.85),
				c + Vector2(r * 0.32, -r * 0.08),
				c + Vector2(r * 0.85, -r * 0.55),
				c + Vector2(r * 0.78, r * 0.45)
			])
			canvas.draw_colored_polygon(crown, col)
			canvas.draw_line(c + Vector2(-r * 0.72, r * 0.68), c + Vector2(r * 0.72, r * 0.68), col, 2.4, true)
		ForestMapGraph.NodeKind.SUPPLY:
			# Crisp adventurer supply cross + satchel frame
			canvas.draw_rect(Rect2(c - Vector2(r * 0.75, r * 0.68), Vector2(r * 1.5, r * 1.36)), Color(col, 0.20), true)
			canvas.draw_rect(Rect2(c - Vector2(r * 0.75, r * 0.68), Vector2(r * 1.5, r * 1.36)), col, false, 1.8)
			canvas.draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), col, 3.0, true)
			canvas.draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), col, 3.0, true)
		ForestMapGraph.NodeKind.CAMP:
			# Tent silhouette + warm glowing campfire flame
			var tent := PackedVector2Array([c + Vector2(0, -r * 0.82), c + Vector2(r * 0.88, r * 0.68), c + Vector2(-r * 0.88, r * 0.68)])
			canvas.draw_colored_polygon(tent, col)
			var flame := PackedVector2Array([c + Vector2(0, -r * 0.12), c + Vector2(r * 0.34, r * 0.68), c + Vector2(-r * 0.34, r * 0.68)])
			canvas.draw_colored_polygon(flame, Color("ffd166"))
		ForestMapGraph.NodeKind.SHOP:
			# Merchant coin pouch & gleaming coin
			canvas.draw_circle(c + Vector2(0, r * 0.16), r * 0.66, col)
			var top_tie := PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.72), c + Vector2(r * 0.45, -r * 0.72), c + Vector2(r * 0.22, -r * 0.32), c + Vector2(-r * 0.22, -r * 0.32)])
			canvas.draw_colored_polygon(top_tie, col)
			canvas.draw_circle(c + Vector2(0, r * 0.18), r * 0.28, SUN_GOLD)
		ForestMapGraph.NodeKind.SHRINE:
			# Torii gate
			canvas.draw_line(c + Vector2(-r * 0.88, -r * 0.56), c + Vector2(r * 0.88, -r * 0.56), col, 3.0, true)
			canvas.draw_line(c + Vector2(-r * 0.72, -r * 0.18), c + Vector2(r * 0.72, -r * 0.18), col, 2.0, true)
			canvas.draw_line(c + Vector2(-r * 0.48, -r * 0.52), c + Vector2(-r * 0.55, r * 0.78), col, 2.4, true)
			canvas.draw_line(c + Vector2(r * 0.48, -r * 0.52), c + Vector2(r * 0.55, r * 0.78), col, 2.4, true)
		ForestMapGraph.NodeKind.FORGE:
			# Blacksmith anvil + golden spark
			var anvil := PackedVector2Array([
				c + Vector2(-r * 0.86, -r * 0.22),
				c + Vector2(r * 0.82, -r * 0.22),
				c + Vector2(r * 0.48, r * 0.22),
				c + Vector2(r * 0.66, r * 0.68),
				c + Vector2(-r * 0.66, r * 0.68),
				c + Vector2(-r * 0.42, r * 0.18)
			])
			canvas.draw_colored_polygon(anvil, col)
			canvas.draw_circle(c + Vector2(0, -r * 0.58), r * 0.22, SUN_GOLD)
		ForestMapGraph.NodeKind.GAMBLE:
			# Tilted die with 3 pips
			var sq := Rect2(c - Vector2(r * 0.62, r * 0.62), Vector2(r * 1.24, r * 1.24))
			canvas.draw_rect(sq, col, false, 2.2)
			canvas.draw_circle(c + Vector2(-r * 0.28, -r * 0.28), 2.1, col)
			canvas.draw_circle(c, 2.1, col)
			canvas.draw_circle(c + Vector2(r * 0.28, r * 0.28), 2.1, col)
		ForestMapGraph.NodeKind.LOOKOUT:
			# Radiant eye / beacon
			var eye := PackedVector2Array([c + Vector2(-r * 0.85, 0), c + Vector2(0, -r * 0.55), c + Vector2(r * 0.85, 0), c + Vector2(0, r * 0.55)])
			canvas.draw_polyline(eye + PackedVector2Array([eye[0]]), col, 2.2, true)
			canvas.draw_circle(c, r * 0.28, col)
		ForestMapGraph.NodeKind.HIDEOUT:
			# Leaf canopy crescent
			canvas.draw_arc(c + Vector2(r * 0.1, 0), r * 0.65, PI * 0.35, PI * 1.65, 18, col, 3.2, true)
			canvas.draw_circle(c + Vector2(r * 0.32, -r * 0.25), 2.4, col)
		ForestMapGraph.NodeKind.DANGER:
			# Warning triangle + exclamation
			var tri := PackedVector2Array([c + Vector2(0, -r * 0.82), c + Vector2(r * 0.82, r * 0.68), c + Vector2(-r * 0.82, r * 0.68)])
			canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), col, 2.4, true)
			canvas.draw_line(c + Vector2(0, -r * 0.34), c + Vector2(0, r * 0.22), col, 2.4, true)
			canvas.draw_circle(c + Vector2(0, r * 0.46), 1.8, col)
		ForestMapGraph.NodeKind.CENTER:
			# Blazing 8-ray Ember Sun Altar
			for k in 8:
				var ang := float(k) * PI * 0.25
				var l := r * (0.95 if k % 2 == 0 else 0.72)
				canvas.draw_line(c, c + Vector2(cos(ang), sin(ang)) * l, col, 2.2, true)
			canvas.draw_circle(c, r * 0.44, Color("ff9f1c"))
			canvas.draw_circle(c, r * 0.22, CREAM_TEXT)
		ForestMapGraph.NodeKind.EXIT:
			# Grand stone archway gate
			canvas.draw_arc(c + Vector2(0, -r * 0.08), r * 0.65, PI, TAU, 18, col, 3.2, true)
			canvas.draw_line(c + Vector2(-r * 0.65, -r * 0.08), c + Vector2(-r * 0.65, r * 0.75), col, 3.2, true)
			canvas.draw_line(c + Vector2(r * 0.65, -r * 0.08), c + Vector2(r * 0.65, r * 0.75), col, 3.2, true)
			canvas.draw_line(c + Vector2(-r * 0.84, r * 0.75), c + Vector2(r * 0.84, r * 0.75), col, 2.4, true)
			canvas.draw_circle(c + Vector2(0, r * 0.16), r * 0.24, SUN_GOLD)
		ForestMapGraph.NodeKind.EVENT:
			# Ornate scroll + question jewel
			canvas.draw_arc(c + Vector2(0, -r * 0.28), r * 0.36, PI * 0.9, TAU + PI * 0.35, 16, col, 2.6, true)
			canvas.draw_line(c + Vector2(r * 0.14, 0.0), c + Vector2(0, r * 0.28), col, 2.6, true)
			canvas.draw_circle(c + Vector2(0, r * 0.62), 2.2, col)
		ForestMapGraph.NodeKind.DESTINY_GATE:
			# Twin rune stone gate pillars + arched lintel + glowing 4-point destiny diamond star
			canvas.draw_line(c + Vector2(-r * 0.62, -r * 0.35), c + Vector2(-r * 0.62, r * 0.72), col, 2.8, true)
			canvas.draw_line(c + Vector2(r * 0.62, -r * 0.35), c + Vector2(r * 0.62, r * 0.72), col, 2.8, true)
			canvas.draw_arc(c + Vector2(0, -r * 0.22), r * 0.62, PI, TAU, 16, col, 2.6, true)
			canvas.draw_line(c + Vector2(-r * 0.80, r * 0.72), c + Vector2(r * 0.80, r * 0.72), col, 2.2, true)
			var star := PackedVector2Array([
				c + Vector2(0, -r * 0.36),
				c + Vector2(r * 0.30, r * 0.08),
				c + Vector2(0, r * 0.52),
				c + Vector2(-r * 0.30, r * 0.08)
			])
			canvas.draw_colored_polygon(star, SUN_GOLD)
			canvas.draw_polyline(star + PackedVector2Array([star[0]]), col, 1.4, true)
		_:
			# Stone steps (PASSAGE)
			for s in 3:
				var y := r * (0.55 - float(s) * 0.45)
				var w_step := r * (0.78 - float(s) * 0.18)
				canvas.draw_line(c + Vector2(-w_step, y), c + Vector2(w_step, y), col, 2.4, true)

static func draw_dice_tray(canvas: Control, run: RefCounted, is_rolling: bool, anim_face: int, pulse_time: float, font: Font) -> void:
	var rect := canvas.get_rect()
	var w := rect.size.x
	var h := rect.size.y
	if w < 20 or h < 20 or run == null:
		return

	# Warm parchment tray surface with subtle inlaid brass corners
	var inner := Rect2(2, 2, w - 4, h - 4)
	canvas.draw_rect(inner, PARCHMENT, true)
	var border_col := SUN_GOLD if (run.can_roll_action_dice() or is_rolling) else BRASS_GOLD
	canvas.draw_rect(inner, border_col, false, 2.0)
	canvas.draw_rect(Rect2(6, 6, w - 12, h - 12), Color(BRASS_GOLD, 0.38), false, 1.0)

	# Sculpted die center (left-center) + status & step beads (right side)
	var die_center := Vector2(54.0, h * 0.5)
	var die_size := 56.0
	var tilt := 0.0
	var scale_f := 1.0
	if is_rolling:
		tilt = sin(pulse_time * 36.0) * 0.24
		scale_f = 1.0 + absf(sin(pulse_time * 22.0)) * 0.10
	elif run.can_roll_action_dice():
		scale_f = 1.0 + sin(pulse_time * 4.0) * 0.04

	# Radiant golden aura when ready to roll
	if run.can_roll_action_dice() or is_rolling:
		var glow_r := 36.0 + sin(pulse_time * 5.0) * 3.0
		canvas.draw_circle(die_center, glow_r, Color(SUN_GOLD, 0.24))

	# Die shadow
	canvas.draw_circle(die_center + Vector2(2, 5), die_size * 0.50 * scale_f, Color(WALNUT_DEEP, 0.22))

	# Draw tilted rounded-look die polygon
	var hs := die_size * 0.5 * scale_f
	var corners := PackedVector2Array([
		Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(hs, hs), Vector2(-hs, hs)
	])
	var rot_corners := PackedVector2Array()
	for pt in corners:
		rot_corners.append(die_center + pt.rotated(tilt))

	var die_fill := Color("fffaf0") if (run.dice_rolled or is_rolling) else Color("f7e4b4")
	canvas.draw_colored_polygon(rot_corners, die_fill)
	canvas.draw_polyline(rot_corners + PackedVector2Array([rot_corners[0]]), WALNUT_BG, 2.6, true)

	# Inner bevel highlight
	var inner_rot := PackedVector2Array()
	for pt in corners:
		inner_rot.append(die_center + (pt * 0.84).rotated(tilt))
	canvas.draw_polyline(inner_rot + PackedVector2Array([inner_rot[0]]), Color(BRASS_GOLD, 0.65), 1.3, true)

	# Die face pips (1..4) or '?'
	var shown_face: int = anim_face if is_rolling else (int(run.last_dice_raw) if run.dice_rolled else 0)
	if shown_face >= 1 and shown_face <= 4:
		var pip_offs: Array[Vector2] = []
		var d := hs * 0.48
		match shown_face:
			1:
				pip_offs = [Vector2.ZERO]
			2:
				pip_offs = [Vector2(-d, -d), Vector2(d, d)]
			3:
				pip_offs = [Vector2(-d, -d), Vector2.ZERO, Vector2(d, d)]
			4:
				pip_offs = [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]
		var pip_col := CRIMSON_WARN if shown_face == 1 else WALNUT_DEEP
		for po in pip_offs:
			var wp := die_center + po.rotated(tilt)
			canvas.draw_circle(wp, 5.2 * scale_f, pip_col)
			canvas.draw_circle(wp + Vector2(-1.2, -1.2), 1.6 * scale_f, Color(CREAM_TEXT, 0.45))
	else:
		var q_sz := font.get_string_size("1d4", HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		canvas.draw_string(font, die_center + Vector2(-q_sz.x * 0.5, 6.0), "1d4", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, WALNUT_BG)

	# Right-side status readout & golden step beads
	var text_x := 98.0
	var title_txt := ""
	var sub_txt := ""
	if is_rolling:
		title_txt = "行动骰翻滚中……"
		sub_txt = "正在决定第 %d 回合步数" % run.turn
	elif not run.dice_rolled:
		title_txt = "第 %d 回合 · 待掷骰" % run.turn
		sub_txt = "点击此处或按钮掷出 1～4 步"
	else:
		title_txt = "掷出 %d 点 · 剩 %d/%d 步" % [run.last_dice_raw, run.actions_left, run.action_budget]
		if run.last_dice_penalty > 0:
			sub_txt = "高疲劳 −%d（保底 1 步）" % run.last_dice_penalty
		elif run.actions_left == 0:
			sub_txt = "步数已耗尽，请结束回合"
		else:
			sub_txt = "点击亮起节点沿古道前行"

	canvas.draw_string(font, Vector2(text_x, 30.0), title_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK_DARK)
	canvas.draw_string(font, Vector2(text_x, 50.0), sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CRIMSON_WARN if (run.last_dice_penalty > 0 or (not run.dice_rolled and run.fatigue >= ForestRun.FATIGUE_PENALTY_THRESHOLD)) else INK_MUTED)

	# Step beads row
	var bead_y := 74.0
	var total_beads: int = int(run.action_budget) if run.dice_rolled else 4
	for i in total_beads:
		var bx := text_x + 10.0 + float(i) * 24.0
		var active_bead: bool = bool(run.dice_rolled) and i < int(run.actions_left)
		canvas.draw_circle(Vector2(bx, bead_y), 8.2, WALNUT_BG if active_bead else Color(WALNUT_BORDER, 0.35))
		canvas.draw_circle(Vector2(bx, bead_y), 6.2, SUN_GOLD if active_bead else PARCHMENT_SOFT)
		if active_bead:
			canvas.draw_circle(Vector2(bx - 1.8, bead_y - 1.8), 2.0, CREAM_TEXT)

static func _draw_dashed_polyline(canvas: Control, pts: PackedVector2Array, color: Color, width: float, dash_len: float, gap_len: float) -> void:
	if pts.size() < 2:
		return
	var cycle := dash_len + gap_len
	var dist_acc := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.001:
			continue
		var dir := (b - a) / seg_len
		var pos := 0.0
		while pos < seg_len:
			var mod := fmod(dist_acc, cycle)
			if mod < dash_len:
				var take := minf(dash_len - mod, seg_len - pos)
				canvas.draw_line(a + dir * pos, a + dir * (pos + take), color, width, true)
				pos += take
				dist_acc += take
			else:
				var skip := minf(cycle - mod, seg_len - pos)
				pos += skip
				dist_acc += skip

static func _sample_polyline(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var clamped := clampf(t, 0.0, 1.0)
	var fidx := clamped * float(pts.size() - 1)
	var i0 := int(floor(fidx))
	var i1 := mini(pts.size() - 1, i0 + 1)
	return pts[i0].lerp(pts[i1], fidx - float(i0))

static func _draw_pill_label(canvas: Control, font: Font, center: Vector2, text: String, font_size: int, bg: Color, border: Color, text_col: Color) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pw := sz.x + 14.0
	var ph := float(font_size) + 8.0
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	canvas.draw_rect(rect, bg, true)
	canvas.draw_rect(rect, border, false, 1.3)
	canvas.draw_string(font, Vector2(rect.position.x + 7.0, rect.position.y + ph - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

# ==============================================================================
# 9×7 废林方格地图表现层工具（对齐《废林方格地图调研与首层方案》及视觉预览）
# ==============================================================================

static func compute_grid_layout(rect: Rect2, grid_size: Vector2i) -> Dictionary:
	var pad_l := 34.0
	var pad_r := 18.0
	var pad_t := 58.0
	var pad_b := 36.0
	var avail_w := maxf(120.0, rect.size.x - pad_l - pad_r)
	var avail_h := maxf(120.0, rect.size.y - pad_t - pad_b)
	var gap := 4.0
	var cols := maxi(1, grid_size.x)
	var rows := maxi(1, grid_size.y)
	var cw := floorf((avail_w - gap * float(cols - 1)) / float(cols))
	var ch := floorf((avail_h - gap * float(rows - 1)) / float(rows))
	var side := maxf(24.0, minf(cw, ch))
	var total_w := side * float(cols) + gap * float(cols - 1)
	var total_h := side * float(rows) + gap * float(rows - 1)
	var ox := rect.position.x + pad_l + (avail_w - total_w) * 0.5
	var oy := rect.position.y + pad_t + (avail_h - total_h) * 0.5
	return {
		"origin": Vector2(ox, oy),
		"cell_size": Vector2(side, side),
		"gap": gap,
		"board_rect": Rect2(ox - 8.0, oy - 8.0, total_w + 16.0, total_h + 16.0)
	}

static func grid_cell_rect(layout: Dictionary, cell: Vector2i) -> Rect2:
	var origin: Vector2 = layout.origin
	var cs: Vector2 = layout.cell_size
	var gap: float = layout.gap
	return Rect2(origin.x + float(cell.x) * (cs.x + gap), origin.y + float(cell.y) * (cs.y + gap), cs.x, cs.y)

static func grid_cell_center(layout: Dictionary, cell: Vector2i) -> Vector2:
	return grid_cell_rect(layout, cell).get_center()

static func grid_cell_at_point(layout: Dictionary, point: Vector2, grid_size: Vector2i) -> Vector2i:
	var origin: Vector2 = layout.origin
	var cs: Vector2 = layout.cell_size
	var gap: float = layout.gap
	var rel := point - origin
	if rel.x < 0.0 or rel.y < 0.0:
		return Vector2i(-1, -1)
	var step_x := cs.x + gap
	var step_y := cs.y + gap
	var cx := int(floor(rel.x / step_x))
	var cy := int(floor(rel.y / step_y))
	if cx < 0 or cy < 0 or cx >= grid_size.x or cy >= grid_size.y:
		return Vector2i(-1, -1)
	var local_x := rel.x - float(cx) * step_x
	var local_y := rel.y - float(cy) * step_y
	if local_x > cs.x or local_y > cs.y:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

static func _grid_short_label(n: ForestMapGraph.MapNode) -> String:
	match n.kind:
		ForestMapGraph.NodeKind.SPAWN: return "猎林入口"
		ForestMapGraph.NodeKind.BATTLE: return "普通遭遇"
		ForestMapGraph.NodeKind.ELITE: return "精英伏击"
		ForestMapGraph.NodeKind.SUPPLY: return "补给"
		ForestMapGraph.NodeKind.EVENT: return "随机事件"
		ForestMapGraph.NodeKind.HIDEOUT: return "隐蔽树洞"
		ForestMapGraph.NodeKind.LOOKOUT: return "瞭望高台"
		ForestMapGraph.NodeKind.DANGER: return "险地"
		ForestMapGraph.NodeKind.CENTER: return "烬心祭坛"
		ForestMapGraph.NodeKind.CAMP: return "旧猎人营火"
		ForestMapGraph.NodeKind.SHOP: return "战前行商"
		ForestMapGraph.NodeKind.SHRINE: return "御灵神龛"
		ForestMapGraph.NodeKind.FORGE: return "余烬锻台"
		ForestMapGraph.NodeKind.GAMBLE: return "迷雾博弈"
		ForestMapGraph.NodeKind.EXIT: return "归途石门"
		ForestMapGraph.NodeKind.DESTINY_GATE: return "命运石之门"
		_: return ""

static func _draw_tree_obstacle(canvas: Control, r: Rect2, is_visible: bool) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.24
	var col := Color("7ca872") if is_visible else Color("526d4d")
	for off in [Vector2(-s * 0.72, -s * 0.18), Vector2(s * 0.72, s * 0.25)]:
		var p: Vector2 = c + off
		var top_tri := PackedVector2Array([p + Vector2(0, -s * 0.95), p + Vector2(s * 0.58, -s * 0.05), p + Vector2(-s * 0.58, -s * 0.05)])
		var bot_tri := PackedVector2Array([p + Vector2(0, -s * 0.40), p + Vector2(s * 0.72, s * 0.52), p + Vector2(-s * 0.72, s * 0.52)])
		canvas.draw_colored_polygon(top_tri, col)
		canvas.draw_colored_polygon(bot_tri, col)
		canvas.draw_line(p + Vector2(0, s * 0.52), p + Vector2(0, s * 0.85), col.darkened(0.25), 2.0, true)

static func _draw_water_obstacle(canvas: Control, r: Rect2, is_visible: bool) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.26
	var col := Color("84c6d9") if is_visible else Color("507b8a")
	for row_off in [-s * 0.26, s * 0.26]:
		var roff := float(row_off)
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var x := c.x - s + t * (s * 2.0)
			var y := c.y + roff + sin(t * TAU * 1.2) * (s * 0.16)
			pts.append(Vector2(x, y))
		canvas.draw_polyline(pts, col, 2.2, true)

static func draw_grid_map(canvas: Control, run: RefCounted, rect: Rect2, hovered_cell: Vector2i, route_path: Array, pulse_time: float, font: Font) -> void:
	var map := run.map as ForestMapGraph
	if map == null or not map.is_grid:
		return
	var layout := compute_grid_layout(rect, map.grid_size)
	var board_rect: Rect2 = layout.board_rect

	# Soft dark walnut vignette frame around the 9×7 board so grid cells read clearly over sunlit terrain
	canvas.draw_rect(rect, Color(0.09, 0.08, 0.05, 0.44), true)
	canvas.draw_rect(board_rect, Color(WALNUT_DEEP, 0.52), true)
	canvas.draw_rect(board_rect, Color(WALNUT_BORDER, 0.80), false, 1.8)

	var side: float = layout.cell_size.x
	var coord_col := Color("cfc1a3")
	var label_fs := 10 if side < 64.0 else 11

	# Column headers A..I
	for x in map.grid_size.x:
		var ch := String.chr(65 + x)
		var cr := grid_cell_rect(layout, Vector2i(x, 0))
		var sz := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		canvas.draw_string(font, Vector2(cr.get_center().x - sz.x * 0.5, board_rect.position.y - 4.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, coord_col)

	# Row headers 1..7
	for y in map.grid_size.y:
		var num := str(y + 1)
		var cr := grid_cell_rect(layout, Vector2i(0, y))
		var sz := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		canvas.draw_string(font, Vector2(board_rect.position.x - sz.x - 8.0, cr.get_center().y + 4.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, coord_col)

	# Draw every cell
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var cell := Vector2i(x, y)
			var cr := grid_cell_rect(layout, cell)
			var nid := map.node_id_at(cell)
			var node: ForestMapGraph.MapNode = map.get_node(nid) if not nid.is_empty() else null
			var is_obs := map.is_obstacle(cell)
			var is_known: bool = run.known_cells.has(cell) or (not nid.is_empty() and run.known.has(nid))
			var is_visible: bool = run.visible_cells.has(cell) or (not nid.is_empty() and run.visible.has(nid))
			var is_current: bool = not nid.is_empty() and nid == run.position
			var is_reachable: bool = not nid.is_empty() and run.can_move(nid)
			var is_cleared: bool = not nid.is_empty() and run.cleared.has(nid)
			var is_hovered: bool = cell == hovered_cell

			if not is_known:
				# Unexplored dark fog tile
				canvas.draw_rect(cr, Color(0.11, 0.13, 0.12, 0.88), true)
				canvas.draw_rect(cr, Color(0.32, 0.34, 0.29, 0.40) if not is_hovered else Color(CREAM_TEXT, 0.55), false, 1.2)
				var hseed := float((x * 31 + y * 17) % 13)
				canvas.draw_circle(cr.position + Vector2(cr.size.x * 0.28 + hseed * 0.6, cr.size.y * 0.32), 1.1, Color(0.65, 0.68, 0.60, 0.18))
				canvas.draw_circle(cr.position + Vector2(cr.size.x * 0.70 - hseed * 0.5, cr.size.y * 0.68), 1.0, Color(0.65, 0.68, 0.60, 0.15))
				continue

			if is_obs:
				var okind := map.obstacle_kind(cell)
				if okind == "water":
					canvas.draw_rect(cr, Color(0.12, 0.26, 0.34, 0.82) if is_visible else Color(0.09, 0.19, 0.26, 0.88), true)
					canvas.draw_rect(cr, Color("4d8fa8") if is_visible else Color("345a6b"), false, 1.5 if not is_hovered else 2.0)
					_draw_water_obstacle(canvas, cr, is_visible)
				else:
					canvas.draw_rect(cr, Color(0.14, 0.25, 0.15, 0.80) if is_visible else Color(0.10, 0.18, 0.11, 0.88), true)
					canvas.draw_rect(cr, Color("4d7548") if is_visible else Color("344d31"), false, 1.5 if not is_hovered else 2.0)
					_draw_tree_obstacle(canvas, cr, is_visible)
				continue

			# Walkable known cell
			var fill := Color(0.36, 0.33, 0.22, 0.36) if is_visible else Color(0.17, 0.16, 0.13, 0.72)
			var border_col := Color(BRASS_GOLD, 0.58) if is_visible else Color(WALNUT_BORDER, 0.38)
			var border_w := 1.2

			if node != null and node.kind != ForestMapGraph.NodeKind.PASSAGE:
				var kc := ForestMapGraph.kind_color(node.kind)
				fill = fill.lerp(Color(kc.r, kc.g, kc.b, 0.42 if is_visible else 0.26), 0.50)
				border_col = kc.lightened(0.12) if is_visible else kc.darkened(0.30)
				border_w = 1.6

			if is_reachable:
				var glow := 0.20 + 0.08 * sin(pulse_time * 4.6)
				fill = fill.lerp(Color(SUN_GOLD.r, SUN_GOLD.g, SUN_GOLD.b, 0.45), glow + 0.18)
				border_col = SUN_GOLD
				border_w = 2.2
			if is_current:
				fill = Color(SUN_GOLD.r, SUN_GOLD.g, SUN_GOLD.b, 0.34)
				border_col = SUN_GOLD
				border_w = 2.8
			elif is_hovered:
				border_col = CREAM_TEXT
				border_w = 2.2

			canvas.draw_rect(cr, fill, true)
			canvas.draw_rect(cr, border_col, false, border_w)

			# Reachable subtle golden corner dot (matching preview)
			if is_reachable:
				canvas.draw_circle(cr.position + Vector2(cr.size.x - 7.0, cr.size.y - 7.0), 2.8, SUN_GOLD)

			var center := cr.get_center()
			if is_current:
				var icon_r := side * 0.24
				var icon_c := center + Vector2(0, -side * 0.08)
				canvas.draw_circle(icon_c, icon_r + 3.0, Color(SUN_GOLD, 0.26))
				canvas.draw_circle(icon_c, icon_r, WALNUT_DEEP)
				canvas.draw_arc(icon_c, icon_r, 0, TAU, 24, SUN_GOLD, 2.0, true)
				# Bold directional arrow chevron inside party token
				var tri := PackedVector2Array([
					icon_c + Vector2(0, -icon_r * 0.62),
					icon_c + Vector2(icon_r * 0.46, icon_r * 0.48),
					icon_c + Vector2(0, icon_r * 0.18),
					icon_c + Vector2(-icon_r * 0.46, icon_r * 0.48)
				])
				canvas.draw_colored_polygon(tri, CREAM_TEXT)
				var ptxt := "小队"
				var psz := font.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs)
				canvas.draw_string(font, Vector2(center.x - psz.x * 0.5, cr.end.y - 6.0), ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, CREAM_TEXT)
			elif node != null and node.kind != ForestMapGraph.NodeKind.PASSAGE:
				var icon_r := side * 0.22
				var icon_c := center + Vector2(0, -side * 0.10)
				var accent := ForestMapGraph.kind_color(node.kind)
				var disc_border := accent.lightened(0.15) if is_visible else accent.darkened(0.32)
				canvas.draw_circle(icon_c, icon_r, Color(WALNUT_DEEP, 0.90 if is_visible else 0.72))
				canvas.draw_arc(icon_c, icon_r, 0, TAU, 22, disc_border, 1.6, true)
				var emblem_col := CREAM_TEXT if is_visible else Color("bdb39d")
				if node.kind == ForestMapGraph.NodeKind.DESTINY_GATE:
					emblem_col = SUN_GOLD if is_visible else Color("b5954b")
				draw_node_emblem(canvas, node.kind, icon_c, icon_r * 0.68, emblem_col, false)
				var short_lbl := _grid_short_label(node)
				if not short_lbl.is_empty():
					var lsz := font.get_string_size(short_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs)
					var lcol := CREAM_TEXT if is_visible else Color("bfb6a2")
					canvas.draw_string(font, Vector2(center.x - lsz.x * 0.5, cr.end.y - 6.0), short_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, lcol)

			# Cleared green stamp badge on resolved landmark cells
			if is_cleared and node != null and node.kind != ForestMapGraph.NodeKind.PASSAGE and node.kind != ForestMapGraph.NodeKind.SPAWN and node.kind != ForestMapGraph.NodeKind.SHOP and node.kind != ForestMapGraph.NodeKind.DESTINY_GATE:
				var st := cr.position + Vector2(cr.size.x - 9.0, 9.0)
				canvas.draw_circle(st, 6.5, WALNUT_DEEP)
				canvas.draw_circle(st, 5.2, Color("4fa362"))
				canvas.draw_polyline(PackedVector2Array([
					st + Vector2(-2.6, 0.2),
					st + Vector2(-0.5, 2.2),
					st + Vector2(2.8, -2.2)
				]), CREAM_TEXT, 1.5, true)

	# Route preview dashed line when pointing at or clicking a distant known cell
	if route_path.size() >= 2:
		var pts := PackedVector2Array()
		for nid in route_path:
			var c: Vector2i = map.cell_of(String(nid))
			if c.x >= 0:
				pts.append(grid_cell_center(layout, c))
		if pts.size() >= 2:
			var dest_id := String(route_path[route_path.size() - 1])
			var dest_node := map.get_node(dest_id)
			var is_combat_dest := dest_node != null and dest_node.kind in [ForestMapGraph.NodeKind.BATTLE, ForestMapGraph.NodeKind.ELITE, ForestMapGraph.NodeKind.CENTER, ForestMapGraph.NodeKind.EXIT]
			var route_col := Color("f08e67") if is_combat_dest else SUN_GOLD
			canvas.draw_polyline(pts, Color(WALNUT_DEEP, 0.85), 5.8, true)
			_draw_dashed_polyline(canvas, pts, route_col, 3.0, 8.0, 6.0)
			for i in range(1, pts.size()):
				canvas.draw_circle(pts[i], 3.4, route_col)
			var steps := route_path.size() - 1
			var badge_txt := ""
			if run.dice_rolled:
				var rem: int = int(run.actions_left) - steps
				badge_txt = "%d步 · 余%d步" % [steps, rem] if rem >= 0 else "%d步 · 移动力不足" % steps
			else:
				badge_txt = "需 %d 步" % steps
			_draw_pill_label(canvas, font, pts[pts.size() - 1] + Vector2(0, -side * 0.42), badge_txt, 11, Color(WALNUT_DEEP, 0.94), route_col, CREAM_TEXT)

	# Patrol tracks / signals on known cells
	for sig in run.signals:
		var snid: String = sig.get("node", "")
		if not run.known.has(snid):
			continue
		var sc := map.cell_of(snid)
		if sc.x < 0:
			continue
		var sp := grid_cell_center(layout, sc)
		if String(sig.get("kind", "")) == "track":
			var bp := sp + Vector2(side * 0.28, -side * 0.28)
			canvas.draw_circle(bp, 7.0, Color(WALNUT_DEEP, 0.90))
			canvas.draw_arc(bp, 7.0, 0, TAU, 14, Color("e8833a"), 1.3, true)

	# Patrol beast ONLY shown when inside current visibility (run.is_patrol_visible())
	if run.is_patrol_visible():
		var pc := map.cell_of(run.patrol_node)
		if pc.x >= 0:
			draw_patrol_beast(canvas, grid_cell_center(layout, pc), pulse_time, font)

	# Compact legend strip at bottom of grid board
	var leg_y := board_rect.end.y + 18.0
	var leg_x := board_rect.position.x + 6.0
	var legend_items := [
		{"col": Color(SUN_GOLD, 0.72), "border": SUN_GOLD, "txt": "可走 (相邻1步)"},
		{"col": Color(0.24, 0.23, 0.18, 0.85), "border": WALNUT_BORDER, "txt": "已知地形"},
		{"col": Color(0.11, 0.13, 0.12, 0.92), "border": Color("4a4f44"), "txt": "迷雾未探"},
		{"col": Color(0.14, 0.26, 0.15, 0.90), "border": Color("4d7548"), "txt": "障碍不可通"}
	]
	for item in legend_items:
		var sw := Rect2(leg_x, leg_y - 9.0, 11.0, 11.0)
		canvas.draw_rect(sw, item.col, true)
		canvas.draw_rect(sw, item.border, false, 1.2)
		canvas.draw_string(font, Vector2(leg_x + 16.0, leg_y), item.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dfd2b5"))
		leg_x += font.get_string_size(item.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 32.0
