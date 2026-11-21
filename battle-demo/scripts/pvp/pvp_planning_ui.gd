extends "res://scripts/planning_ui.gd"

const Draft = preload("res://scripts/pvp/pvp_draft.gd")
var initial_state: Dictionary
var own_locked := false
var opponent_locked := false

func _ready() -> void:
	battle = Draft.new()
	lineup = [Rules.ASH_ID, Rules.BLADE_ID]
	super._ready()
	auto_button.hide()
	item_button.hide()
	restart_button.hide()
	setup_button.text = "退出房间"
	setup_requested.connect(func() -> void: NetworkManager.leave_game())
	NetworkManager.ready_changed.connect(_on_ready_changed)
	NetworkManager.plan_rejected.connect(_on_plan_rejected)
	NetworkManager.round_resolved.connect(_on_round_resolved)

func new_battle() -> void:
	open_round(initial_state)

func open_round(state: Dictionary) -> void:
	battle.load_view(state)
	own_locked = false
	opponent_locked = false
	busy = false
	selected_card = -1
	selected_slot = 0
	for slot in battle.hero_slots:
		if battle.heroes[slot.unit].hp > 0:
			selected_slot = slot.id
			break
	selected_target = 0
	for slot in battle.enemy_slots:
		if battle.enemies[slot.unit].hp > 0:
			selected_target = slot.id
			break
	enhance_selected = false
	hand_view.show_shared = true
	stage.prepare_portraits(battle.heroes, battle.enemies)
	stage.reset_visuals()
	_refresh(battle.snapshot())
	log_label.text = "双方各自规划。锁定前可以撤销，具体技能在双方锁定后揭晓。"

func _process(_delta: float) -> void:
	pass

func _target_guidance(target: int) -> Dictionary:
	if selected_card < 0 or not Rules.targets_enemy(battle.hand[selected_card]):
		return {}
	var error: String = battle.can_assign(selected_card, selected_slot, target)
	return {"valid": error.is_empty(), "text": "可选目标 · 对方计划隐藏" if error.is_empty() else error}

func _update_forecast() -> void:
	if forecast_panel == null:
		return
	if busy or battle == null or battle.phase != "response":
		forecast_panel.hide()
		return
	if selected_slot < 0 or selected_slot >= battle.hero_slots.size() or selected_target < 0 or selected_target >= battle.enemy_slots.size():
		forecast_panel.hide()
		return
	var hero_slot: Dictionary = battle.hero_slots[selected_slot]
	var hero: Dictionary = battle.heroes[hero_slot.unit]
	var enemy_slot: Dictionary = battle.enemy_slots[selected_target]
	var enemy: Dictionary = battle.enemies[enemy_slot.unit]
	if hero.hp <= 0 or enemy.hp <= 0:
		forecast_panel.hide()
		return
	var card_key := ""
	if selected_card >= 0 and selected_card < battle.hand.size():
		card_key = battle.hand[selected_card]
	elif hero_slot.active:
		card_key = hero_slot.key
	if card_key.is_empty() or not Rules.targets_enemy(card_key):
		forecast_panel.hide()
		return
	var skill: Dictionary = Rules.SKILLS.get(card_key, {})
	var hero_base: int = skill.get("base", skill.get("power", 0))
	var hero_coins: int = skill.get("coins", 1)
	var hero_coin_val: int = skill.get("power", 2)
	var hero_min := hero_base
	var hero_max := hero_base + hero_coins * hero_coin_val
	forecast_panel.show()
	forecast_title.text = "【好友对战 · 对方计划隐藏】"
	forecast_title.add_theme_color_override("font_color", Color("80d6df"))
	forecast_detail.text = "我方「%s」速%d [%d~%d]  →  %s · %s格 速%d" % [
		skill.get("name", card_key), hero_slot.speed, hero_min, hero_max,
		enemy.name, Rules.CATEGORIES[enemy_slot.category], enemy_slot.speed,
	]
	if enemy_slot.category == 2:
		forecast_tip.text = "对方防御格若启用将提供护盾；攻击可削减其护盾或直接命中。"
	elif hero_slot.speed > enemy_slot.speed:
		forecast_tip.text = "我方速度 (%d) > 对方 (%d)：若对方启用该攻击格，双方互瞄或单向瞄准均可拼点。" % [hero_slot.speed, enemy_slot.speed]
	else:
		forecast_tip.text = "我方速度 (%d) ≤ 对方 (%d)：仅当对方也瞄准此格时拼点，否则按速度各自结算。" % [hero_slot.speed, enemy_slot.speed]

func _refresh(state: Dictionary) -> void:
	super._refresh(state)
	setup_button.disabled = false
	header.text = "好友对战  ROUND %02d  我方 %d Cost · 预留 %d  /  对方 %d Cost" % [state.turn, state.cost, state.reserved, state.enemy_cost]
	if state.phase == "response":
		clock_label.text = "等待对手" if busy else "行动规划"
		ready_button.text = "已锁定，等待对手" if own_locked else ("提交中…" if busy else "锁定行动  ·  Enter")
		ally_status.text = "我方 · 已锁定" if own_locked else "我方 · 已安排 %d 次行动" % battle.plan().size()
		enemy_status.text = "对手 · 已锁定 / 技能隐藏" if opponent_locked else "对手 · 规划中 / 技能隐藏"
		guide.text = "锁定前可以选牌、安排和撤销。等双方锁定后揭晓。" if not busy else "等待对手锁定行动。"
	elif not state.outcome.is_empty():
		clock_label.text = "战斗结束"
		ready_button.text = "对战结束"
		guide.text = "对战结束 · 可退出房间后再开一局。"
		hint.text = "对战胜利" if state.outcome == "victory" else "对战失利"

func _resolve() -> void:
	if busy or battle.phase != "response":
		return
	busy = true
	stage.dragging = -1
	_refresh(battle.snapshot())
	NetworkManager.submit_plan(battle.turn, battle.plan())

func _on_ready_changed(own_ready: bool, opponent_ready: bool) -> void:
	own_locked = own_ready
	opponent_locked = opponent_ready
	_refresh(battle.snapshot())
	if own_ready:
		log_label.text = "行动已锁定，等待双方揭晓。"

func _on_plan_rejected(message: String) -> void:
	busy = false
	_refresh(battle.snapshot())
	log_label.text = "房主未接受计划：%s。请调整后再锁定。" % message

func _on_round_resolved(state: Dictionary, events: Array) -> void:
	busy = true
	selected_card = -1
	enhance_selected = false
	clock_label.text = "交锋中"
	await _play_events(events)
	if not is_inside_tree():
		return
	battle.load_view(state)
	busy = battle.phase == "finished"
	stage.reset_visuals()
	_refresh(battle.snapshot())
	if battle.phase == "finished":
		clock_label.text = "等待下一回合"
		log_label.text = "本回合结算完毕，等待双方演出结束。"
		NetworkManager.playback_finished(battle.turn)
	else:
		log_label.text = "胜利" if battle.outcome == "victory" else "失败"
		sound.play_sound(battle.outcome)
