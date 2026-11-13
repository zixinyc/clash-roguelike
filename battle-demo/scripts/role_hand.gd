extends PanelContainer

signal hero_selected(unit: int)
signal group_changed
signal card_selected(hand_index: int)

const Rules = preload("res://scripts/battle_rules.gd")
const Card = preload("res://scripts/card_view.gd")
const ROLE_COLORS := [Color("dfbc80"), Color("8bc8ce"), Color("c3d29b")]
const CARD_ORDER := ["probe", "observe", "exploit", "follow", "steady_edge", "all_in", "shatter",
	"cover", "light_guard", "support_strike", "steady", "ember", "needle", "cleave", "guard", "nova"]

var show_shared := false
var visible_indices: Array[int] = []
var detail: Label
var role_summary: Label
var hero_buttons: Array[Button] = []
var group_buttons: Array[Button] = []
var cards: Array[DemoCardView] = []
var card_row: HBoxContainer

func _ready() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("121e27")
	panel.border_color = Color("354751")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(9)
	add_theme_stylebox_override("panel", panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	add_child(body)
	var crew := HBoxContainer.new()
	body.add_child(crew)
	for unit in ROLE_COLORS.size():
		var tab := Button.new()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void: hero_selected.emit(unit))
		crew.add_child(tab)
		hero_buttons.append(tab)
	var groups := HBoxContainer.new()
	body.add_child(groups)
	role_summary = Label.new()
	role_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	groups.add_child(role_summary)
	for shared in [false, true]:
		var tab := Button.new()
		tab.custom_minimum_size.x = 102
		tab.pressed.connect(_choose_group.bind(shared))
		groups.add_child(tab)
		group_buttons.append(tab)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	body.add_child(card_row)
	detail = Label.new()
	detail.add_theme_font_size_override("font_size", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 25
	body.add_child(detail)

func _choose_group(shared: bool) -> void:
	if shared == show_shared:
		return
	show_shared = shared
	group_changed.emit()

func _tab_state(tab: Button, active: bool, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("21323c").lerp(accent, 0.12) if active else Color("16232c")
	style.border_color = accent if active else Color("354751")
	style.set_border_width_all(1)
	style.border_width_bottom = 3 if active else 1
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	tab.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.08)
	tab.add_theme_stylebox_override("hover", hover)

func _add_cards(hand: Array) -> void:
	cards.resize(hand.size())
	var keys := CARD_ORDER.duplicate()
	for key in hand:
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var i := hand.find(key)
		if i < 0:
			continue
		var card := Card.new()
		card.skill_key = key
		card.hand_index = i
		card.skill = Rules.SKILLS[key]
		card.pressed.connect(func() -> void: card_selected.emit(i))
		cards[i] = card
		card_row.add_child(card)

func refresh(state: Dictionary, unit: int, selection: int, planning: bool) -> void:
	if cards.is_empty():
		_add_cards(state.hand)
	var assigned := {}
	var counts := [0, 0, 0]
	for slot in state.hero_slots:
		if slot.active:
			assigned[slot.card] = state.heroes[slot.unit].name
			counts[slot.unit] += 1
	for i in hero_buttons.size():
		var hero: Dictionary = state.heroes[i]
		var status := "%d/2" % counts[i] if hero.hp > 0 else "已退场"
		hero_buttons[i].text = "%s   ·   %s    %s" % [hero.name, hero.role, status]
		hero_buttons[i].disabled = not planning
		_tab_state(hero_buttons[i], i == unit, ROLE_COLORS[i])
	var roles := ["拼点获胜获得准备 · 当前 %d 层" % state.heroes[0].preparation,
		"高费牌拼点威力 +%d · 失败额外损失 %d 生命" % [Rules.clash_bonus("all_in", 1, 0), Rules.BREAKER_HP_LOSS],
		"防御行动结算时，为其他存活队友提供护盾"]
	role_summary.text = roles[unit]
	role_summary.add_theme_color_override("font_color", ROLE_COLORS[unit])
	detail.add_theme_color_override("font_color", Color("d7e0e1"))
	visible_indices.clear()
	var personal_count := 0
	var shared_count := 0
	for node in card_row.get_children():
		var card := node as DemoCardView
		var i := card.hand_index
		var owner := int(card.skill.get("owner", -1))
		personal_count += int(owner == unit)
		shared_count += int(owner < 0)
		card.visible = owner < 0 if show_shared else owner == unit
		if not card.visible:
			continue
		visible_indices.append(i)
		card.key_number = visible_indices.size()
		card.selected = i == selection
		card.disabled = not planning or state.heroes[unit].hp <= 0
		card.assigned_to = assigned.get(i, "")
		card.accent = ROLE_COLORS[unit]
		card.bonus = Rules.clash_bonus(card.skill_key, unit, state.heroes[0].preparation)
		card.ally_shield = Rules.ally_guard_amount(card.skill_key) if unit == 2 else 0
		card.queue_redraw()
	group_buttons[0].text = "专属 %d" % personal_count
	group_buttons[1].text = "通用 %d" % shared_count
	for i in group_buttons.size():
		group_buttons[i].disabled = not planning
		_tab_state(group_buttons[i], bool(i) == show_shared, ROLE_COLORS[unit])
