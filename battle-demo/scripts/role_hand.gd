extends PanelContainer

signal hero_selected(unit: int)
signal group_changed
signal card_selected(hand_index: int)
signal enhancement_changed(enabled: bool)

const Rules = preload("res://scripts/battle_rules.gd")
const Card = preload("res://scripts/card_view.gd")
const ROLE_COLORS := [Color("dfbc80"), Color("8bc8ce"), Color("c3d29b")]
const CARD_ORDER := [
	# 灰烬
	"probe", "observe", "exploit", "follow",
	# 长锋
	"steady_edge", "all_in", "shatter",
	# 织火
	"cover", "support_strike", "light_guard",
	# 十六夜咲夜
	"murder_doll", "private_square", "stopwatch", "the_world",
	# 博丽灵梦
	"yin_yang_orb", "fantasy_seal", "demon_seal", "fantasy_nature",
	# ZiXi
	"zixi_central_limit", "zixi_convergence", "zixi_martingale", "zixi_almost_sure",
	# ZiXingYC
	"zixingyc_attention", "zixingyc_residual", "zixingyc_paradox", "zixingyc_yesterday", "zixingyc_ending",
	# 雾雨魔理沙
	"marisa_stars", "marisa_orrery", "marisa_laser", "marisa_spark",
	# 通用
	"needle", "ember", "steady", "cleave", "risk", "guard", "nova"
]

var show_shared := false
var show_all_playable := false
var visible_indices: Array[int] = []
var detail: Label
var role_summary: Label
var enhance_toggle: CheckButton
var hero_buttons: Array[Button] = []
var all_playable_button: Button
var group_buttons: Array[Button] = []
var cards: Array[DemoCardView] = []
var displayed_hand: Array = []
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
	enhance_toggle = CheckButton.new()
	enhance_toggle.text = "强化 · 3 层"
	enhance_toggle.toggled.connect(func(enabled: bool) -> void: enhancement_changed.emit(enabled))
	groups.add_child(enhance_toggle)
	all_playable_button = Button.new()
	all_playable_button.custom_minimum_size.x = 108
	all_playable_button.visible = false
	all_playable_button.pressed.connect(_choose_all_playable)
	groups.add_child(all_playable_button)
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

func _choose_all_playable() -> void:
	if show_all_playable:
		return
	show_all_playable = true
	group_changed.emit()

func _choose_group(shared: bool) -> void:
	if not show_all_playable and shared == show_shared:
		return
	show_all_playable = false
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
	for node in card_row.get_children():
		card_row.remove_child(node)
		node.queue_free()
	displayed_hand = hand.duplicate()
	cards.resize(hand.size())
	var order_indices: Array[int] = []
	for i in hand.size():
		order_indices.append(i)
	order_indices.sort_custom(func(a: int, b: int) -> bool:
		var ra := CARD_ORDER.find(hand[a])
		var rb := CARD_ORDER.find(hand[b])
		if ra < 0:
			ra = 1000 + a
		if rb < 0:
			rb = 1000 + b
		return ra < rb if ra != rb else a < b)
	for i in order_indices:
		var key: String = hand[i]
		var card := Card.new()
		card.skill_key = key
		card.hand_index = i
		card.skill = Rules.SKILLS[key]
		card.pressed.connect(func() -> void: card_selected.emit(i))
		cards[i] = card
		card_row.add_child(card)

func refresh(state: Dictionary, unit: int, selection: int, planning: bool, slot_id: int, enhance: bool) -> void:
	if displayed_hand != state.hand:
		_add_cards(state.hand)
	var assigned := {}
	var enhanced_cards := {}
	var counts := [0, 0, 0]
	var limits := [0, 0, 0]
	for slot in state.hero_slots:
		if slot.category == 0 and not slot.get("frozen", false):
			limits[slot.unit] += Rules.group_action_limit(slot)
		if slot.active:
			assigned[slot.card] = state.heroes[slot.unit].name
			if slot.get("enhanced", false):
				enhanced_cards[slot.card] = true
			counts[slot.unit] += 1
	for i in hero_buttons.size():
		hero_buttons[i].visible = i < state.heroes.size()
		if not hero_buttons[i].visible:
			continue
		var hero: Dictionary = state.heroes[i]
		var first_slot: Dictionary = state.hero_slots[i * 3]
		var limit: int = limits[i]
		var status := "%d/%d" % [counts[i], limit] if hero.hp > 0 else "已退场"
		if first_slot.get("frozen", false) and hero.hp > 0:
			status = "停时"
		hero_buttons[i].text = "%s   ·   %s    %s" % [hero.name, hero.role, status]
		hero_buttons[i].disabled = not planning
		_tab_state(hero_buttons[i], i == unit, ROLE_COLORS[i])
	var hero: Dictionary = state.heroes[unit]
	match int(hero.character_id):
		Rules.ASH_ID:
			role_summary.text = "拼点获胜获得准备 · 当前 %d 层" % hero.preparation
		Rules.BLADE_ID:
			role_summary.text = "高费牌拼点威力 +%d · 失败额外损失 %d 生命" % [Rules.clash_bonus("all_in", Rules.BLADE_ID, 0), Rules.BREAKER_HP_LOSS]
		Rules.WEAVER_ID:
			role_summary.text = "防御行动结算时，为其他存活队友提供护盾"
		Rules.SAKUYA_ID:
			role_summary.text = "无视速度接招 · 每次攻击伤害 +%d" % Rules.Sakuya.damage_bonus(hero, state.turn)
		Rules.REIMU_ID:
			role_summary.text = "对幻想乡本土敌人拼点 +1 · 退治叠满 4 层触发"
			if hero.dream_due > 0:
				role_summary.text = "梦想宝玉 %d/3 · 第 %d 回合结束发动" % [hero.dream_orbs, hero.dream_due]
		Rules.ZIXINGYC_ID:
			role_summary.text = Rules.ZiXingYC.summary(hero)
		Rules.MARISA_ID:
			role_summary.text = "火花 %d/10 · 敌方 cost 偷取与星辰轰炸" % int(hero.get("spark", 0))
	var cycle_on: bool = state.get("deck_cycle_enabled", false)
	all_playable_button.visible = cycle_on
	if not cycle_on:
		show_all_playable = false
	var has_personal: bool = state.hand.any(func(key: String) -> bool: return Rules.card_owner(key) == hero.character_id)
	var has_shared: bool = state.hand.any(func(key: String) -> bool: return Rules.card_owner(key) < 0)
	if not show_all_playable and (not has_personal or not has_shared):
		show_shared = has_shared and not has_personal
	var is_zixi := hero.has("metaphysics")
	enhance_toggle.visible = is_zixi and (show_all_playable or not show_shared)
	var enhancement_error := ""
	if is_zixi:
		role_summary.text = "超形上学 %d/%d   ·   因果律 %d/%d" % [hero.metaphysics, Rules.ZiXi.METAPHYSICS_MAX, hero.causality, Rules.ZiXi.CAUSALITY_MAX]
		enhancement_error = Rules.ZiXi.enhancement_error(hero, slot_id)
		enhance_toggle.disabled = not planning or selection < 0 or hero.hp <= 0 or not enhancement_error.is_empty()
		enhance_toggle.tooltip_text = enhancement_error if not enhancement_error.is_empty() else "消耗 3 层超形上学。本回合可强化一张，结算后因果律 +1，拼胜分差至少 5 时 +2。"
		enhance_toggle.set_pressed_no_signal(enhance)
	role_summary.add_theme_color_override("font_color", ROLE_COLORS[unit])
	detail.add_theme_color_override("font_color", Color("d7e0e1"))
	visible_indices.clear()
	var personal_count := 0
	var shared_count := 0
	for node in card_row.get_children():
		var card := node as DemoCardView
		var i := card.hand_index
		var owner := Rules.card_owner(card.skill_key)
		personal_count += int(owner == hero.character_id)
		shared_count += int(owner < 0)
		if show_all_playable:
			card.visible = owner < 0 or owner == hero.character_id
		else:
			card.visible = owner < 0 if show_shared else owner == hero.character_id
		if not card.visible:
			continue
		visible_indices.append(i)
		card.key_number = visible_indices.size()
		card.selected = i == selection
		card.disabled = not planning or state.heroes[unit].hp <= 0 or state.hero_slots[unit * 3].get("frozen", false)
		card.assigned_to = assigned.get(i, "")
		card.accent = ROLE_COLORS[unit]
		card.bonus = Rules.clash_bonus(card.skill_key, hero.character_id, int(hero.get("preparation", 0)))
		card.ally_shield = Rules.ally_guard_amount(card.skill_key) if hero.character_id == Rules.WEAVER_ID and state.heroes.size() > 1 else 0
		card.enhanced = card.skill.has("enhance_name") and (enhanced_cards.has(i) or (card.selected and enhance))
		card.can_enhance = false
		if is_zixi and card.skill.has("enhance_name") and planning and hero.hp > 0:
			if hero.enhanced_slot < 0:
				card.can_enhance = hero.metaphysics >= Rules.ZiXi.ENHANCE_COST
			else:
				var occupied: Dictionary = state.hero_slots[hero.enhanced_slot]
				card.can_enhance = Rules.SKILLS[occupied.key].kind == card.skill.kind
		card.queue_redraw()
	all_playable_button.text = "本轮可用 %d" % (personal_count + shared_count)
	all_playable_button.disabled = not planning or (personal_count + shared_count) == 0
	_tab_state(all_playable_button, show_all_playable, ROLE_COLORS[unit])
	group_buttons[0].text = "专属 %d" % personal_count
	group_buttons[1].text = "通用 %d" % shared_count
	for i in group_buttons.size():
		group_buttons[i].disabled = not planning or not (has_shared if i == 1 else has_personal)
		_tab_state(group_buttons[i], (not show_all_playable) and bool(i) == show_shared, ROLE_COLORS[unit])
