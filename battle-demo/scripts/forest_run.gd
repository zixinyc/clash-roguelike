class_name ForestRun
extends RefCounted

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")

const RUNES := {
	"rune_feather": {"id": "rune_feather", "name": "轻灵", "desc": "有效费用 −1（最低保底 1 费）"},
	"rune_leech": {"id": "rune_leech", "name": "汲血", "desc": "主技能实损生命 15% 转化为治疗（单次上限 5 HP）"},
	"rune_impact": {"id": "rune_impact", "name": "破势", "desc": "拼点基础点数 +1"},
	"rune_echo": {"id": "rune_echo", "name": "回响", "desc": "单体命中后 25% 几率追加 35% 实损余波（每回合限 1 次）"},
	"rune_overcharge": {"id": "rune_overcharge", "name": "超频", "desc": "行动开始消耗 4/8 护盾，提升 15%/30% 技能伤害"},
}
const FORGE_ENCHANT_COST := 4

var deck_enchants: Dictionary = {}

var map: RefCounted
var party_hp: Array[int] = [48, 42, 46]
var party_max_hp: Array[int] = [48, 42, 46]
var party_names: Array[String] = ["灰烬", "长锋", "织火"]
var reserve_stats: Dictionary = {}
var lineup: Array[int] = [0, 1, 2]
var deck: Array[String] = []
var roster_id: int = 0
var floor_level: int = 1
var floor_cleared: bool = false
var carried_cost: int = 30
var relics: Array[String] = []
var items: Array[String] = []

var position: String = ""
var selected: String = ""
var turn: int = 1
var actions_left: int = 2
var action_budget: int = 2
var fatigue: int = 0
var alert: int = 0
var hidden_turns: int = 0
var intel_fragments: int = 0
var ember_core: bool = false
var in_battle: bool = false
var finished: bool = false
var pending: String = ""
var event_variant: int = 0
var message: String = "沿亮起的林间小径探索，夺取烬核后返回归途石门。"
var current_encounter: int = 0
var version: int = 0

var cleared: Dictionary = {}
var known: Dictionary = {}
var visible: Dictionary = {}
var visited: Dictionary = {}
var known_edges: Dictionary = {}
var travelled: Dictionary = {}
var journal: Array[Dictionary] = []

var patrol_node: String = ""
var patrol_waypoint: int = 0
var patrol_route: Array[String] = []
var patrol_encounter: bool = false
var patrol_return_turn: int = 0
var signals: Array[Dictionary] = []
var signal_counter: int = 0
var observation_expires: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func initialize(map_def: RefCounted, initial_roster: int = 0, initial_relics: Array[String] = [], initial_items: Array[String] = [], seed_val: int = 1337, custom_lineup: Array = [], custom_deck: Array = []) -> void:
	reserve_stats.clear()
	deck_enchants.clear()
	map = map_def
	rng.seed = seed_val
	roster_id = initial_roster
	if not custom_lineup.is_empty():
		_setup_custom_lineup(custom_lineup)
		deck.clear()
		for k in custom_deck:
			deck.append(String(k))
	else:
		_setup_roster(initial_roster)
	relics.assign(initial_relics.duplicate())
	items.assign(initial_items.duplicate())
	
	position = map.start_id
	selected = position
	visited[position] = true
	
	for e in map.edges.values():
		if not e.hidden:
			known_edges[e.id] = true
			
	if not map.patrol_route.is_empty():
		patrol_route.assign(map.patrol_route)
		patrol_node = patrol_route[0]
		
	reveal()
	log_event("小队进入焦黑森林第 %d 层，归途石门已在身后闭锁。" % floor_level)

func has_living_member(members: Array) -> bool:
	for id in members:
		var index := lineup.find(id)
		var hp: int = party_hp[index] if index >= 0 else reserve_stats.get(id, {}).get("hp", 1)
		if hp > 0:
			return true
	return false

func set_lineup_and_deck(new_lineup: Array, new_deck: Array) -> void:
	var roster := DemoBattleRules.create_roster()
	for idx in lineup.size():
		if idx < party_hp.size():
			reserve_stats[lineup[idx]] = {"hp": party_hp[idx], "max_hp": party_max_hp[idx]}
	lineup.clear()
	for id in new_lineup:
		lineup.append(int(id))
	deck.clear()
	for k in new_deck:
		deck.append(String(k))
	party_names.clear()
	party_hp.clear()
	party_max_hp.clear()
	for id in lineup:
		var hero: Dictionary = roster[id]
		party_names.append(hero.name)
		var stats: Dictionary = reserve_stats.get(id, hero)
		party_max_hp.append(int(stats.max_hp))
		party_hp.append(int(stats.hp))
	log_event("队伍整备完成：当前阵容为【%s】，携带 %d 张牌。" % ["、".join(party_names), deck.size()])
	version += 1

func get_active_deck_enchants() -> Dictionary:
	var available := DemoBattleRules.available_cards(lineup)
	var active: Dictionary = {}
	for card_key in deck_enchants:
		if not deck.is_empty() and not deck.has(card_key):
			continue
		if available.has(card_key):
			active[card_key] = deck_enchants[card_key]
	return active

func get_evolution_config() -> Dictionary:
	return {
		"enabled": true,
		"stagger": true,
		"overwhelm": true,
		"deck_enchants": get_active_deck_enchants(),
	}

func can_enchant_card(card_key: String, rune_id: String) -> Dictionary:
	var at_forge: bool = pending == "forge"
	if not at_forge and map != null and map.has_node(position):
		var n = map.get_node(position)
		if n != null and n.kind == ForestMapGraph.NodeKind.FORGE and not cleared.get(position, false):
			at_forge = true
	if not at_forge:
		return {"ok": false, "reason": "当前位置不是未结算的余烬锻台。"}
	if carried_cost < FORGE_ENCHANT_COST:
		return {"ok": false, "reason": "余烬费用不足（需要 %d cost）。" % FORGE_ENCHANT_COST}
	if not RUNES.has(rune_id):
		return {"ok": false, "reason": "未知的符文词条。"}
	var available := DemoBattleRules.available_cards(lineup)
	if not available.has(card_key) and not deck.has(card_key):
		return {"ok": false, "reason": "当前队伍不可用此卡牌。"}
	if deck_enchants.get(card_key, "") == rune_id:
		return {"ok": false, "reason": "该卡牌已雕琢相同的符文。"}
	return {"ok": true, "reason": ""}

func enchant_card(card_key: String, rune_id: String) -> bool:
	var check := can_enchant_card(card_key, rune_id)
	if not check.ok:
		message = check.reason
		return false
	carried_cost -= FORGE_ENCHANT_COST
	var old_rune: String = deck_enchants.get(card_key, "")
	deck_enchants[card_key] = rune_id
	cleared[position] = true
	pending = ""
	var card_name: String = DemoBattleRules.SKILLS.get(card_key, {}).get("name", card_key)
	var rune_name: String = RUNES[rune_id].name
	if old_rune.is_empty():
		log_event("余烬锻台：消耗 %d cost，为【%s】雕琢符文【%s】。" % [FORGE_ENCHANT_COST, card_name, rune_name])
	else:
		var old_name: String = RUNES.get(old_rune, {}).get("name", old_rune)
		log_event("余烬锻台：消耗 %d cost，将【%s】的符文【%s】覆写为【%s】。" % [FORGE_ENCHANT_COST, card_name, old_name, rune_name])
	message = "符卡雕琢完成。可继续向前探索。"
	version += 1
	return true

func _setup_custom_lineup(members: Array) -> void:
	var roster := DemoBattleRules.create_roster()
	lineup.clear()
	party_names.clear()
	party_hp.clear()
	party_max_hp.clear()
	for id in members:
		var hero_id := int(id)
		lineup.append(hero_id)
		var hero: Dictionary = roster[hero_id]
		party_names.append(hero.name)
		party_hp.append(int(hero.hp))
		party_max_hp.append(int(hero.max_hp))

func _setup_roster(roster: int) -> void:
	match roster:
		1: # Touhou: Marisa, Sakuya, Reimu
			lineup = [DemoBattleRules.MARISA_ID, DemoBattleRules.SAKUYA_ID, DemoBattleRules.REIMU_ID]
			party_names = ["雾雨魔理沙", "十六夜咲夜", "博丽灵梦"]
			party_hp = [45, 42, 50]
			party_max_hp = [45, 42, 50]
		2: # ZiXi
			lineup = [DemoBattleRules.ASH_ID, DemoBattleRules.ZIXI_ID, DemoBattleRules.WEAVER_ID]
			party_names = ["灰烬", "ZiXi", "织火"]
			party_hp = [48, 44, 46]
			party_max_hp = [48, 44, 46]
		3: # ZiXingYC
			lineup = [DemoBattleRules.ASH_ID, DemoBattleRules.ZIXINGYC_ID, DemoBattleRules.WEAVER_ID]
			party_names = ["灰烬", "ZiXingYC", "织火"]
			party_hp = [48, 44, 46]
			party_max_hp = [48, 44, 46]
		_: # Default: Ash, Blade, Weaver
			lineup = [DemoBattleRules.ASH_ID, DemoBattleRules.BLADE_ID, DemoBattleRules.WEAVER_ID]
			party_names = ["灰烬", "长锋", "织火"]
			party_hp = [48, 42, 46]
			party_max_hp = [48, 42, 46]

func phase_text() -> String:
	if finished:
		return "探索结束"
	if in_battle:
		return "遭遇战斗"
	if not pending.is_empty():
		return "地点抉择"
	if actions_left == 0:
		return "等待结束回合"
	return "探索行动"

func move_error(to_id: String) -> String:
	if finished or in_battle or not pending.is_empty():
		return "请先处理当前地点或战斗。"
	if not map.has_node(to_id) or not known.has(to_id):
		return "尚未发现该地点。"
	if to_id == position:
		return "当前已在此处。"
	var edge = map.edge_between(position, to_id)
	if edge == null:
		return "没有直接连接的路线。"
	if edge.hidden and not known_edges.has(edge.id):
		return "尚未发现这条隐秘通道。"
	if actions_left < edge.action_cost:
		return "本回合移动力不足（需要 %d 点），请结束回合。" % edge.action_cost
	if intel_fragments < edge.intel_cost:
		return "该捷径通道需要 %d 片情报才能通行。" % edge.intel_cost
	return ""

func can_move(to_id: String) -> bool:
	return move_error(to_id).is_empty()

func click_node(to_id: String) -> bool:
	if not map.has_node(to_id) or not known.has(to_id):
		return false
	selected = to_id
	if to_id == position:
		message = "当前位置：%s" % map.get_node(to_id).name
		version += 1
		return false
	var err := move_error(to_id)
	if not err.is_empty():
		message = err
		version += 1
		return false
	return move(to_id)

func move(to_id: String) -> bool:
	if not can_move(to_id):
		return false
	var edge = map.edge_between(position, to_id)
	var prev_id := position
	actions_left -= edge.action_cost
	intel_fragments -= edge.intel_cost
	travelled[edge.id] = true
	position = to_id
	selected = to_id
	visited[to_id] = true
	fatigue = mini(8, fatigue + edge.action_cost)
	
	if edge.kind == ForestMapGraph.RouteKind.SHORTCUT:
		log_event("通过隐秘捷径，消耗 %d 移动力与 %d 情报。" % [edge.action_cost, edge.intel_cost])
	log_event("从 %s 移动至 %s。" % [map.get_node(prev_id).name, map.get_node(to_id).name])
	
	reveal()
	enter_node()
	_check_patrol_contact()
	version += 1
	return true

func enter_node() -> void:
	var node = map.get_node(position)
	if node == null:
		return
	message = "抵达 %s。" % node.name
	if cleared.has(position) and node.kind != ForestMapGraph.NodeKind.SHOP:
		message += " 该地点已处理，无法重复获取收益。"
		return
		
	match node.kind:
		ForestMapGraph.NodeKind.BATTLE:
			current_encounter = 0 if rng.randf() < 0.6 else 3
			in_battle = true
			message = "遭遇敌袭！准备进入交锋！"
		ForestMapGraph.NodeKind.ELITE:
			current_encounter = 1 if rng.randf() < 0.5 else 4
			in_battle = true
			message = "遭遇森林强敌！强大的威压逼近！"
		ForestMapGraph.NodeKind.CENTER:
			current_encounter = 5
			in_battle = true
			message = "烬心之门在此开启！守卫者【烬心巨像】正在苏醒！"
		ForestMapGraph.NodeKind.SUPPLY:
			carried_cost += 5
			cleared[position] = true
			log_event("拾取遗留补给：+5 cost。")
			message = "找到废林散落的补给物资，获得 5 cost。"
		ForestMapGraph.NodeKind.LOOKOUT:
			intel_fragments += 2
			observation_expires = turn + 2
			cleared[position] = true
			reveal()
			log_event("登上哨塔：情报碎片 +2，侦测视野大范围展开！")
			message = "站在废弃哨塔高处，远方道路尽收眼底。"
		ForestMapGraph.NodeKind.HIDEOUT:
			hidden_turns = 2
			alert = maxi(0, alert - 2)
			cleared[position] = true
			log_event("潜入密林树影：隐蔽 2 回合，警戒度下降。")
			message = "借助茂密林荫隐匿行踪，巡游野兽难以察觉。"
		ForestMapGraph.NodeKind.DANGER:
			alert = mini(5, alert + 1)
			carried_cost += 6
			cleared[position] = true
			log_event("穿越危险地带：警戒度 +1，险境中拾得 6 cost。")
			message = "穿过毒雾与荆棘的危险带，收获丰厚但也惊动了林中掠食者。"
		ForestMapGraph.NodeKind.CAMP:
			pending = "camp"
			message = "安全营地：可以在此生火休整，或在周围搜集物资。"
		ForestMapGraph.NodeKind.SHOP:
			pending = "shop"
			message = "流浪黑商：行商在焦木下摆出货物，可用 cost 交易。"
		ForestMapGraph.NodeKind.SHRINE:
			pending = "shrine"
			message = "古神祭坛：灰烬中隐约有神圣光芒流转。"
		ForestMapGraph.NodeKind.FORGE:
			pending = "forge"
			message = "野外熔炉：尚有余温的风箱与砧台可强化队伍装备。"
		ForestMapGraph.NodeKind.GAMBLE:
			pending = "gamble"
			message = "命运骰局：神秘游民在树洞旁掷出骨骰，邀你对赌。"
		ForestMapGraph.NodeKind.EVENT:
			pending = "event"
			event_variant = rng.randi_range(0, 2)
			message = "林间异象：发现一处未知的古代遗迹。"
		ForestMapGraph.NodeKind.EXIT:
			if cleared.has(position) or ember_core:
				cleared[position] = true
				finished = true
				floor_cleared = true
				message = "第 %d 层关底守卫已被击溃，归途石门已激活！可随时深入下一层！" % floor_level
				log_event("小队抵达归途石门，石阶通往下一层！")
			else:
				current_encounter = 5
				in_battle = true
				message = "抵达第 %d 层关底！守卫者【烬心巨像】现身拦截！" % floor_level
				log_event("遭遇第 %d 层关底首领拦截！进入首领决战！" % floor_level)
		_:
			cleared[position] = true

func apply_choice(choice: int) -> bool:
	if pending.is_empty() or choice < 0 or choice > 2:
		return false
	var ok := false
	match pending:
		"camp":
			if choice == 0: # Rest
				heal_party(10)
				fatigue = maxi(0, fatigue - 3)
				log_event("营地休整：存活队员恢复 10 生命，疲劳 −3。")
				ok = true
			elif choice == 1: # Forage
				carried_cost += 6
				fatigue = maxi(0, fatigue - 1)
				log_event("营地搜集：搜集余烬残火，获得 6 cost。")
				ok = true
		"shop":
			if cleared.has(position):
				return false
			if choice == 0: # Buy Healing
				if carried_cost >= 6:
					carried_cost -= 6
					heal_party(8)
					log_event("购买伤药：−6 cost，存活队员恢复 8 生命。")
					ok = true
			elif choice == 1: # Buy Relic
				if carried_cost >= 12:
					var available_relics := RelicSystem.get_unowned_relics(relics)
					if not available_relics.is_empty():
						carried_cost -= 12
						var picked: String = available_relics[rng.randi() % available_relics.size()]
						relics.append(picked)
						var r_info: Dictionary = RelicSystem.get_relic(picked)
						log_event("购得遗物【%s】：%s" % [r_info.get("name", picked), r_info.get("desc", "")])
						ok = true
			elif choice == 2: # Buy Consumable
				if carried_cost >= 4:
					var item_keys := RelicSystem.CONSUMABLE_DB.keys()
					carried_cost -= 4
					var picked_item: String = item_keys[rng.randi() % item_keys.size()]
					items.append(picked_item)
					var i_info: Dictionary = RelicSystem.get_consumable(picked_item)
					log_event("购买道具【%s】：%s" % [i_info.get("name", picked_item), i_info.get("description", "")])
					ok = true
		"shrine":
			if choice == 0: # Purify
				fatigue = 0
				heal_lowest_hero(12)
				log_event("圣泉洗礼：疲劳完全消除，重伤队员恢复 12 生命。")
				ok = true
			elif choice == 1: # Sacred Blessing
				for i in party_max_hp.size():
					party_max_hp[i] += 4
					if party_hp[i] > 0:
						party_hp[i] += 4
				log_event("古神赐福：全体队员最大生命 +4！")
				ok = true
		"forge":
			if choice == 0: # Temper Armor
				for i in party_max_hp.size():
					party_max_hp[i] += 2
					if party_hp[i] > 0:
						party_hp[i] += 2
				log_event("熔炉淬甲：全体队员最大生命 +2。")
				ok = true
			elif choice == 1: # Craft Catalyst
				if carried_cost >= 3:
					carried_cost -= 3
					items.append("ember_catalyst")
					log_event("熔炼结晶：−3 cost，获得【余烬催化剂】。")
					ok = true
		"gamble":
			if choice == 0: # Roll Dice
				if carried_cost >= 4:
					carried_cost -= 4
					var roll := rng.randf()
					if roll < 0.50:
						carried_cost += 10
						log_event("骰局大胜：获得 10 cost！")
					elif roll < 0.80:
						items.append("weighted_coin")
						log_event("骰局平手：赢下一枚【灌铅硬币】。")
					else:
						log_event("骰局落空：掷骰点数不佳，赌金付之东流。")
					ok = true
			elif choice == 1: # Pass
				log_event("离开骰摊：拒绝了游民的赌局。")
				ok = true
		"event":
			if event_variant == 0:
				if choice == 0:
					carried_cost += 5
					log_event("安全搜寻：在古迹周围拾得 5 cost。")
					ok = true
				elif choice == 1:
					for i in party_hp.size():
						if party_hp[i] > 0:
							party_hp[i] = maxi(1, party_hp[i] - 4)
					carried_cost += 14
					log_event("冒险深入：存活队员各失去 4 生命，夺得 14 cost！")
					ok = true
			elif event_variant == 1:
				if choice == 0:
					if rng.randf() < 0.65:
						carried_cost += 8
						items.append("dense_smoke")
						log_event("营救迷途猎人：获赠 8 cost 与【浓缩烟幕弹】。")
					else:
						for i in party_hp.size():
							if party_hp[i] > 0:
								party_hp[i] = maxi(1, party_hp[i] - 3)
						alert = mini(5, alert + 1)
						log_event("伪装成猎人的陷阱！队员各受到 3 点伤害，警戒度上升。")
					ok = true
				elif choice == 1:
					log_event("谨慎绕开求救声，未触发陷阱。")
					ok = true
			elif event_variant == 2:
				if choice == 0:
					if carried_cost >= 3:
						carried_cost -= 3
						intel_fragments += 3
						log_event("解读远古石刻：−3 cost，获得 3 片情报碎片。")
						ok = true
				elif choice == 1:
					log_event("略过石刻继续行进。")
					ok = true
					
	if ok:
		cleared[position] = true
		if pending == "shop":
			message = "交易完成。可继续整备或离开商店。"
		else:
			pending = ""
			message = "地点抉择完成，可继续向前探索。"
		version += 1
	return ok

func leave_shop() -> bool:
	if pending != "shop":
		return false
	pending = ""
	message = "已暂离黑商，随时可以再次点击进入交易。"
	version += 1
	return true

func end_turn() -> bool:
	if in_battle or finished or not pending.is_empty():
		return false
	var rested: bool = actions_left == action_budget
	turn += 1
	hidden_turns = maxi(0, hidden_turns - 1)
	fatigue = maxi(0, fatigue - (2 if rested else 1))
	alert = maxi(0, alert - (2 if hidden_turns > 0 else (1 if rested else 0)))
	action_budget = 1 if fatigue >= 6 else 2
	actions_left = action_budget
	
	signals = signals.filter(func(s: Dictionary) -> bool: return int(s.get("expires_turn", 0)) >= turn)
	_move_patrol()
	reveal()
	_check_patrol_contact()
	
	if not in_battle:
		var stealth_note := "【隐蔽中】" if hidden_turns > 0 else ""
		log_event("第 %d 回合开始，行动力 %d 点。%s" % [turn, action_budget, stealth_note])
	version += 1
	return true

func _move_patrol() -> void:
	if patrol_node.is_empty() or patrol_route.is_empty() or turn < patrol_return_turn:
		return
	var target_node := patrol_route[(patrol_waypoint + 1) % patrol_route.size()]
	var links: Array = map.get_links(patrol_node).filter(func(e) -> bool: return e.kind != ForestMapGraph.RouteKind.SHORTCUT)
	if links.is_empty():
		return
		
	var best_next: String = ""
	var best_dist: float = 9999.0
	for e in links:
		var other: String = e.other(patrol_node)
		var d: float = map.distance(other, target_node)
		if d < best_dist:
			best_dist = d
			best_next = other
			
	var old_patrol := patrol_node
	if not best_next.is_empty():
		patrol_node = best_next
	if patrol_node == target_node:
		patrol_waypoint = (patrol_waypoint + 1) % patrol_route.size()
		
	_add_signal(old_patrol, "track", "地面留有林中掠食者的新鲜爪痕。", 3)
	_add_signal(patrol_node, "noise", "远处树林传来重物踩踏断枝的声音。", 1)

func _check_patrol_contact() -> void:
	if in_battle or not pending.is_empty() or finished or patrol_node != position or turn < patrol_return_turn:
		return
	if hidden_turns > 0:
		log_event("茂密树冠隐匿了小队，巡游巨兽掠过身边却未曾发觉。")
		return
	alert = 5
	current_encounter = 3
	in_battle = true
	patrol_encounter = true
	message = "巡游恶兽突袭了小队！立刻应战！"
	log_event("遭遇巡游巨兽拦截！进入突袭战斗！")

func _within(start_id: String, radius: int) -> Dictionary:
	var result := {start_id: true}
	var frontier := [start_id]
	for step in radius:
		var next: Array[String] = []
		for n in frontier:
			for e in map.get_links(n):
				if e.kind != ForestMapGraph.RouteKind.SHORTCUT and (not e.hidden or known_edges.has(e.id)):
					var o: String = e.other(n)
					if not result.has(o):
						result[o] = true
						next.append(o)
		frontier = next
	return result

func reveal() -> void:
	visible.clear()
	var radius := 2 if turn <= observation_expires else 1
	var in_range := _within(position, radius)
	for id in in_range:
		visible[id] = true
		known[id] = true
	known[position] = true
	for e in map.get_links(position):
		if e.kind == ForestMapGraph.RouteKind.SHORTCUT and (not e.hidden or known_edges.has(e.id)):
			known[e.other(position)] = true

func _add_signal(node_id: String, kind: String, text: String, duration: int) -> void:
	signal_counter += 1
	signals.append({
		"id": "signal-%d" % signal_counter,
		"node": node_id,
		"kind": kind,
		"text": text,
		"created_turn": turn,
		"expires_turn": turn + duration
	})

func is_patrol_visible() -> bool:
	return not patrol_node.is_empty() and visible.has(patrol_node) and turn >= patrol_return_turn

func heal_party(amount: int) -> void:
	for i in party_hp.size():
		if party_hp[i] > 0:
			party_hp[i] = mini(party_max_hp[i], party_hp[i] + amount)

func heal_lowest_hero(amount: int) -> int:
	var lowest_idx := -1
	var lowest_hp := 9999
	for i in party_hp.size():
		if party_hp[i] > 0 and party_hp[i] < party_max_hp[i] and party_hp[i] < lowest_hp:
			lowest_hp = party_hp[i]
			lowest_idx = i
	if lowest_idx < 0:
		return 0
	var restored := mini(amount, party_max_hp[lowest_idx] - lowest_hp)
	party_hp[lowest_idx] += restored
	return restored

func apply_battle_result(victory: bool, remaining_hp: Array, remaining_cost: int) -> void:
	in_battle = false
	carried_cost = remaining_cost
	for i in mini(party_hp.size(), remaining_hp.size()):
		party_hp[i] = remaining_hp[i]
		
	if victory:
		cleared[position] = true
		var node = map.get_node(position)
		var is_boss: bool = (node != null and (node.kind == ForestMapGraph.NodeKind.CENTER or node.kind == ForestMapGraph.NodeKind.EXIT)) or current_encounter == 5
		var is_elite: bool = (node != null and node.kind == ForestMapGraph.NodeKind.ELITE) or current_encounter in [1, 4]
		
		var reward_cost := 15 if is_boss else (10 if is_elite else 6)
		carried_cost += reward_cost
		log_event("战斗胜利！缴获 %d cost。" % reward_cost)
		if not is_boss and not is_elite:
			heal_party(6)
			log_event("战后休整：存活队员恢复 6 生命。")
		
		# Boss drops Ember Core and sets floor_cleared
		if is_boss:
			floor_cleared = true
			if not ember_core:
				ember_core = true
				log_event("【关键战利品】夺得【烬核】！第 %d 层归途石门已激活！" % floor_level)
				message = "击溃第 %d 层关底守卫！归途石门已完全激活，可随时深入下一层！" % floor_level
			
		# Elite and Boss reward relics
		if is_elite or is_boss:
			var available := RelicSystem.get_unowned_relics(relics)
			if not available.is_empty():
				var picked: String = available[rng.randi() % available.size()]
				relics.append(picked)
				var r_info: Dictionary = RelicSystem.get_relic(picked)
				log_event("强敌战利品：获得遗物【%s】！" % r_info.get("name", picked))
				
		if patrol_encounter:
			patrol_encounter = false
			patrol_return_turn = turn + 3 # Patrol respawns in 3 turns
			log_event("击退巡游巨兽，兽群溃退深林（3 回合内不会出现）。")
	else:
		finished = true
		message = "全军覆没……小队未能走出焦黑森林。"
		log_event("小队在战斗中败北，本次探索以失败告终。")
		
	version += 1

func advance_to_next_floor(new_map: RefCounted, seed_val: int = -1) -> void:
	floor_level += 1
	floor_cleared = false
	ember_core = false
	finished = false
	in_battle = false
	pending = ""
	map = new_map
	if seed_val >= 0:
		rng.seed = seed_val
		
	# Reset floor-specific exploration state
	position = map.start_id
	visited = {position: true}
	cleared = {position: true}
	known = {position: true}
	visible = {position: true}
	known_edges = {}
	signals = []
	turn = 1
	fatigue = 0
	alert = 0
	action_budget = 2
	actions_left = 2
	hidden_turns = 0
	observation_expires = 0
	
	# Patrol setup for new map
	patrol_route = map.patrol_route.duplicate()
	patrol_waypoint = 0
	patrol_node = patrol_route[0] if not patrol_route.is_empty() else ""
	patrol_encounter = false
	patrol_return_turn = 0
	
	reveal()
	log_event("小队深入焦黑森林第 %d 层！更强烈的魔力在迷雾深处翻涌……" % floor_level)
	message = "已进入焦黑森林第 %d 层。沿亮起的小径前行，寻访战前行商与关底石门。" % floor_level
	version += 1

func log_event(text: String) -> void:
	journal.append({"turn": turn, "message": text})
	if journal.size() > 60:
		journal.pop_front()
