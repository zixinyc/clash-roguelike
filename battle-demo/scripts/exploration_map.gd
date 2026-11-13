extends Control

const BattleScene = preload("res://main.tscn")
const MAP_SIZE := Vector2i(6, 4)
const BATTLES := {Vector2i(2, 1): 0, Vector2i(4, 2): 1}
const GOAL := Vector2i(5, 1)
const NODES := {
	Vector2i(1, 0): "supply", Vector2i(3, 0): "event", Vector2i(5, 0): "elite",
	Vector2i(4, 1): "camp", Vector2i(1, 2): "event", Vector2i(3, 2): "shop",
	Vector2i(2, 3): "treasure", Vector2i(4, 3): "battle"
}
const NODE_NAMES := {"supply": "补给", "event": "事件", "elite": "精英", "camp": "营地", "shop": "商店", "treasure": "宝藏", "battle": "战斗"}
const NODE_ICONS := {"supply": "✚", "event": "？", "elite": "✦", "camp": "▲", "shop": "◈", "treasure": "✧", "battle": "⚔", "exit": "◇", "party": "◆"}
const NODE_COLORS := {"supply": Color("b4c795"), "event": Color("d2b3dd"), "elite": Color("ff9e88"), "camp": Color("e6b978"), "shop": Color("9fced6"), "treasure": Color("f5d994"), "battle": Color("e7aa96"), "exit": Color("dcebd1"), "party": Color("ffe1a3")}
const GOLD := Color("e6c38a")
const MAX_HP := [48, 42, 46]
const HERO_NAMES := ["灰烬", "长锋", "织火"]
const HERO_COLORS := [Color("d5b27a"), Color("8cbfc8"), Color("b8bf94")]
var position_now := Vector2i(0, 1)
var visited := {}
var cleared := {}
var carried_cost := 30
var carried_hp := [48, 42, 46]
var battle: Control
var header: Label
var hint: Label
var grid: GridContainer
var health_labels: Array[Label] = []
var health_bars: Array[ProgressBar] = []
var tile_styles: Dictionary
var return_button: Button
var finished := false
var pending := ""
var node_panel: PanelContainer
var node_text: Label
var choice_a: Button
var choice_b: Button
var leave_button: Button

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 18
	skin.set_stylebox("normal", "Button", _box(Color("1d2b32"), Color("516067"), 1, 6, 8))
	skin.set_stylebox("hover", "Button", _box(Color("293941"), GOLD, 1, 6, 8))
	skin.set_stylebox("pressed", "Button", _box(Color("38484d"), GOLD, 1, 6, 8))
	skin.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, GOLD, 2, 6))
	skin.set_stylebox("disabled", "Button", _box(Color("18232b"), Color("39484d"), 1, 6, 8))
	theme = skin
	var bg := ColorRect.new()
	bg.color = Color("0c151c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.add_theme_stylebox_override("panel", _box(Color("122127"), Color("5b625b"), 1, 8, 6))
	root.add_child(map_frame)
	var terrain := TextureRect.new()
	if ResourceLoader.exists("res://art/forest-terrain.png"):
		terrain.texture = load("res://art/forest-terrain.png")
	terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(terrain)
	grid = GridContainer.new()
	grid.columns = MAP_SIZE.x
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	map_frame.add_child(grid)
	tile_styles = {
		"fog": _box(Color(0.035, 0.075, 0.105, 0.88), Color(0.32, 0.42, 0.45, 0.14), 1),
		"seen": _box(Color(0.035, 0.07, 0.085, 0.20), Color(0.46, 0.54, 0.49, 0.25), 1),
		"near": _box(Color(0.17, 0.14, 0.10, 0.25), Color(GOLD, 0.75), 2),
		"hover": _box(Color(0.29, 0.22, 0.12, 0.44), GOLD, 3),
		"party": _box(Color(0.22, 0.16, 0.07, 0.26), GOLD, 2),
	}
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var p := Vector2i(x, y)
			var tile := Button.new()
			tile.custom_minimum_size = Vector2(84, 64)
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tile.add_theme_color_override("font_outline_color", Color("0a1319"))
			tile.add_theme_constant_override("outline_size", 8)
			tile.pressed.connect(_move.bind(p))
			grid.add_child(tile)
	var journal := PanelContainer.new()
	journal.custom_minimum_size.x = 306
	journal.add_theme_stylebox_override("panel", _box(Color("121e26"), Color("3a4c53"), 1, 8, 20))
	root.add_child(journal)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 14)
	journal.add_child(details)
	var title := Label.new()
	title.text = "废林探索"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GOLD)
	details.add_child(title)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 27)
	details.add_child(header)
	details.add_child(HSeparator.new())
	for i in HERO_NAMES.size():
		var health := Label.new()
		health.add_theme_color_override("font_color", HERO_COLORS[i])
		details.add_child(health)
		health_labels.append(health)
		var bar := ProgressBar.new()
		bar.max_value = MAX_HP[i]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.add_theme_stylebox_override("background", _box(Color("25343a"), Color.TRANSPARENT, 0, 3))
		bar.add_theme_stylebox_override("fill", _box(HERO_COLORS[i], Color.TRANSPARENT, 0, 3))
		details.add_child(bar)
		health_bars.append(bar)
	details.add_child(HSeparator.new())
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color("bfd0d0"))
	details.add_child(hint)
	var restart := Button.new()
	restart.text = "重新探索"
	restart.pressed.connect(_restart)
	details.add_child(restart)
	return_button = Button.new()
	return_button.text = "返回地图"
	return_button.visible = false
	return_button.pressed.connect(_return_from_battle)
	add_child(return_button)
	return_button.position = Vector2(30, 12)
	node_panel = PanelContainer.new()
	node_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node_panel.offset_left = -300
	node_panel.offset_right = 300
	node_panel.offset_top = -125
	node_panel.offset_bottom = 125
	node_panel.add_theme_stylebox_override("panel", _box(Color("142029"), GOLD, 2, 8, 22))
	add_child(node_panel)
	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	node_panel.add_child(panel_content)
	node_text = Label.new()
	node_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_content.add_child(node_text)
	choice_a = Button.new()
	choice_a.pressed.connect(_choose.bind(0))
	panel_content.add_child(choice_a)
	choice_b = Button.new()
	choice_b.pressed.connect(_choose.bind(1))
	panel_content.add_child(choice_b)
	leave_button = Button.new()
	leave_button.text = "离开，稍后再来"
	leave_button.pressed.connect(_leave_node)
	panel_content.add_child(leave_button)
	node_panel.visible = false
	_reveal()
	_refresh()

func _box(fill: Color, border: Color, width: int, radius: int = 0, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box

func _reveal() -> void:
	visited[position_now] = true
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var p: Vector2i = position_now + d
		if p.x >= 0 and p.x < MAP_SIZE.x and p.y >= 0 and p.y < MAP_SIZE.y:
			visited[p] = true

func _refresh() -> void:
	header.text = "%d cost" % carried_cost
	for i in carried_hp.size():
		health_labels[i].text = "%s    %d / %d" % [HERO_NAMES[i], carried_hp[i], MAX_HP[i]]
		health_bars[i].value = carried_hp[i]
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var p := Vector2i(x, y)
			var tile: Button = grid.get_child(y * MAP_SIZE.x + x)
			var adjacent := absi(p.x - position_now.x) + absi(p.y - position_now.y) == 1
			tile.disabled = finished or not pending.is_empty() or not adjacent
			var kind := ""
			var style := "seen"
			if p == position_now:
				kind = "party"
				style = "party"
			elif not visited.has(p):
				style = "fog"
			elif BATTLES.has(p) and not cleared.has(p):
				kind = "elite" if BATTLES[p] == 1 else "battle"
			elif p == GOAL:
				kind = "exit"
			elif NODES.has(p) and not cleared.has(p):
				kind = NODES[p]
			var title: String = NODE_NAMES.get(kind, "小队" if kind == "party" else "出口")
			tile.text = "%s\n%s" % [NODE_ICONS[kind], title] if not kind.is_empty() else ""
			tile.tooltip_text = title if not kind.is_empty() else ("未探索" if style == "fog" else "空地")
			var accent: Color = NODE_COLORS.get(kind, GOLD)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
				tile.add_theme_color_override(state, accent)
			tile.add_theme_stylebox_override("disabled", tile_styles[style])
			tile.add_theme_stylebox_override("normal", tile_styles["near"])
			tile.add_theme_stylebox_override("hover", tile_styles["hover"])
			tile.add_theme_stylebox_override("pressed", tile_styles["hover"])
	hint.text = "已抵达出口。" if finished else "点击金色描边的相邻格移动。\n进入敌人格会触发战斗。"

func _move(p: Vector2i) -> void:
	if finished or not pending.is_empty() or is_instance_valid(battle) or absi(p.x - position_now.x) + absi(p.y - position_now.y) != 1 or p.x < 0 or p.x >= MAP_SIZE.x or p.y < 0 or p.y >= MAP_SIZE.y:
		return
	position_now = p
	_reveal()
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
			_refresh()
			hint.text = "发现%s：获得 %d cost。" % [NODE_NAMES[kind], 8 if kind == "treasure" else 4]
			return
		else:
			_open_node(kind)
	_refresh()

func _open_node(kind: String) -> void:
	pending = kind
	node_panel.visible = true
	leave_button.visible = kind == "shop"
	choice_b.visible = kind != "shop"
	if kind == "camp":
		node_text.text = "营地：选择一项补给。治疗不会复活倒下的队员。"
		choice_a.text = "全队恢复 10 生命"
		choice_b.text = "获得 5 cost"
	elif kind == "event":
		node_text.text = "废林遗迹：选择稳妥搜寻，或以生命换取更多资源。"
		choice_a.text = "安全搜寻：获得 5 cost"
		choice_b.text = "冒险搜寻：存活队员各失去 4 生命（至少保留 1），获得 12 cost"
	else:
		node_text.text = "商店：花费 6 cost，让存活队员各恢复 8 生命。"
		choice_a.text = "购买治疗（6 cost）" if carried_cost >= 6 else "cost 不足（需要 6）"
	choice_a.disabled = kind == "shop" and carried_cost < 6

func _heal(amount: int) -> void:
	for i in carried_hp.size():
		if carried_hp[i] > 0:
			carried_hp[i] = mini(MAX_HP[i], carried_hp[i] + amount)

func _choose(choice: int) -> void:
	if pending.is_empty() or choice < 0 or choice > 1:
		return
	if pending == "shop":
		if choice != 0 or carried_cost < 6:
			return
		carried_cost -= 6
		_heal(8)
	elif pending == "camp":
		if choice == 0:
			_heal(10)
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
	else:
		return
	cleared[position_now] = true
	pending = ""
	node_panel.visible = false
	_refresh()
	hint.text = "地点已完成，继续探索。"

func _leave_node() -> void:
	if pending != "shop":
		return
	pending = ""
	node_panel.visible = false
	_refresh()
	hint.text = "已离开商店，之后可再次进入。"

func _start_battle(encounter: int) -> void:
	battle = BattleScene.instantiate()
	add_child(battle)
	battle.encounter = encounter
	battle.new_battle()
	battle.battle.cost = carried_cost
	for i in carried_hp.size():
		battle.battle.heroes[i].hp = carried_hp[i]
	for slot in battle.battle.enemy_slots:
		if slot.active and slot.category != 2:
			slot.target = battle.battle._living_target(slot.target)
	battle._refresh(battle.battle.snapshot())
	battle.encounter_button.visible = false
	battle.restart_button.visible = false
	return_button.visible = false
	move_child(return_button, get_child_count() - 1)

func _process(_delta: float) -> void:
	if is_instance_valid(battle) and not battle.busy and not battle.battle.outcome.is_empty():
		return_button.visible = true

func _return_from_battle() -> void:
	if not is_instance_valid(battle) or battle.busy or battle.battle.outcome.is_empty():
		return
	carried_cost = battle.battle.cost
	for i in carried_hp.size():
		carried_hp[i] = battle.battle.heroes[i].hp
	if battle.battle.outcome == "victory":
		cleared[position_now] = true
		var is_elite: bool = int(BATTLES.get(position_now, -1)) == 1 or NODES.get(position_now, "") == "elite"
		carried_cost += 8 if is_elite else 4
	else:
		finished = true
	battle.queue_free()
	battle = null
	return_button.visible = false
	_refresh()
	if finished and carried_hp.all(func(h): return h <= 0):
		hint.text = "小队战败，本次探索结束。点击重新探索再试。"

func _restart() -> void:
	if is_instance_valid(battle):
		return
	position_now = Vector2i(0, 1)
	visited.clear()
	cleared.clear()
	carried_cost = 30
	carried_hp = [48, 42, 46]
	finished = false
	pending = ""
	node_panel.visible = false
	_reveal()
	_refresh()
