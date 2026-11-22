class_name ForestRun
extends RefCounted

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")
const RelicSystem = preload("res://scripts/relic_system.gd")
const DemoBattleRules = preload("res://scripts/battle_rules.gd")
const CardPool = preload("res://scripts/card_pool.gd")

const START_COST := 18
const DICE_MIN := 1
const DICE_MAX := 4
const FATIGUE_PENALTY_THRESHOLD := 6

const MAX_FLOOR := 5
const ENEMY_MODIFIERS := {
	"fortified": {"name": "坚壁", "health": 20, "damage": 5},
	"balanced": {"name": "均势", "health": 12, "damage": 10},
	"ferocious": {"name": "凶袭", "health": 6, "damage": 16},
}

# 命运系统与命运石之门
const DESTINY_MAX := 10
const DESTINY_GATE_REWARD := 2
const DESTINY_HEADS_RATES: Array[float] = [0.45, 0.60, 0.75, 0.90, 1.00]
const DESTINY_UPGRADE_COSTS: Array[int] = [2, 3, 4, 5]
const DESTINY_DROP_EXPLORE := 0.30
const DESTINY_DROP_BATTLE := 0.20
const DESTINY_DROP_ELITE := 0.35
const DESTINY_DROP_BOSS := 0.50

# 战斗演进阶段 3 · 符卡附魔与余烬锻台
const FORGE_ENCHANT_COST := 4
const VALID_RUNES := ["rune_feather", "rune_leech", "rune_impact", "rune_echo", "rune_overcharge"]
const RUNE_META := {
	"rune_feather": {"name": "轻灵", "desc": "有效费用 −1（正费用最低 1）", "cost_mod": -1},
	"rune_leech": {"name": "汲血", "desc": "主技能聚合实扣生命 15% 转化为最低存活队友治疗（上限 5）", "cost_mod": 0},
	"rune_impact": {"name": "破势", "desc": "拼点基础威力 +1", "cost_mod": 0},
	"rune_echo": {"name": "回响", "desc": "普通攻击 25% 概率追加主目标实损 35% 次生伤害", "cost_mod": 0},
	"rune_overcharge": {"name": "超频", "desc": "普通攻击扣至多 8 盾，每完整 4 盾增伤 15%", "cost_mod": 0},
}

const CONTRACTS := {
	"standard": {"name": "标准远征", "desc": "经典林野规则，平衡体验。"},
	"swift_march": {"name": "⚡ 疾风行军", "desc": "每次行动骰步数 +1，但每步额外 +1 疲劳。"},
	"bountiful_woods": {"name": "💎 丰饶林野", "desc": "开局额外携带 +6 cost，并附赠【回响灵摆】。"},
}

const REVIVE_HERO_COST := 10

var contract_id: String = "standard"

var map: RefCounted
var party_hp: Array[int] = [48, 42, 46]
var party_max_hp: Array[int] = [48, 42, 46]
var party_names: Array[String] = ["灰烬", "长锋", "织火"]
var reserve_stats: Dictionary = {}
var lineup: Array[int] = [0, 1, 2]
var deck: Array[String] = []
var card_instances: Array[Dictionary] = [] # [{"uid": "inst_1_1", "key": "guard", "enchant": ""}, ...]
var deck_enchants: Dictionary[String, String] = {} # instance uid -> rune_id
var card_uid_counter: int = 0
var roster_id: int = 0
var floor_level: int = 1
var floor_cleared: bool = false
var won_expedition := false
var enemy_modifiers: Array[String] = []
var carried_cost: int = START_COST
var relics: Array[String] = []
var items: Array[String] = []

var position: String = ""
var selected: String = ""
var turn: int = 1
var dice_rolled: bool = false
var last_dice_raw: int = 0
var last_dice_penalty: int = 0
var actions_left: int = 0
var action_budget: int = 0
var fatigue: int = 0
var alert: int = 0
var hidden_turns: int = 0
var intel_fragments: int = 0
var ember_core: bool = false
var in_battle: bool = false
var finished: bool = false
var pending: String = ""
var event_variant: int = 0
var message: String = "请先掷出行动骰（1d4）决定本回合可行动步数，夺取烬核后返回归途石门。"
var current_encounter: int = 0
var version: int = 0

var cleared: Dictionary = {}
var known: Dictionary = {}
var visible: Dictionary = {}
var visited: Dictionary = {}
var known_cells: Dictionary = {}
var visible_cells: Dictionary = {}
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
var dice_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var card_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var destiny_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var destiny: int = 0
var destiny_tier: int = 0
var destiny_gate_claimed: Dictionary = {}
var destiny_drop_rolled: Dictionary = {}
var destiny_tier_history: Array[Dictionary] = []
var pending_card_rewards: Array[String] = []
var shop_card_offers: Dictionary = {}
var shop_removal_used: Dictionary = {}

func initialize(map_def: RefCounted, initial_roster: int = 0, initial_relics: Array[String] = [], initial_items: Array[String] = [], seed_val: int = 1337, custom_lineup: Array = [], custom_deck: Array = []) -> void:
	reserve_stats.clear()
	map = map_def
	rng.seed = seed_val
	dice_rng.seed = seed_val ^ 0x51A7D1CE
	card_rng.seed = seed_val ^ 0x43415244
	destiny_rng.seed = seed_val ^ 0x44455354
	roster_id = initial_roster
	floor_level = 1
	won_expedition = false
	enemy_modifiers.clear()
	carried_cost = START_COST
	destiny = 0
	destiny_tier = 0
	destiny_gate_claimed.clear()
	destiny_drop_rolled.clear()
	destiny_tier_history.clear()
	turn = 1
	dice_rolled = false
	last_dice_raw = 0
	last_dice_penalty = 0
	action_budget = 0
	actions_left = 0
	fatigue = 0
	alert = 0
	hidden_turns = 0
	intel_fragments = 0
	ember_core = false
	in_battle = false
	finished = false
	floor_cleared = false
	pending = ""
	pending_card_rewards.clear()
	shop_card_offers.clear()
	shop_removal_used.clear()
	cleared.clear()
	known.clear()
	visible.clear()
	visited.clear()
	known_cells.clear()
	visible_cells.clear()
	known_edges.clear()
	travelled.clear()
	journal.clear()
	signals.clear()
	signal_counter = 0
	observation_expires = 0
	patrol_node = ""
	patrol_waypoint = 0
	patrol_route.clear()
	patrol_encounter = false
	patrol_return_turn = 0
	if not custom_lineup.is_empty():
		_setup_custom_lineup(custom_lineup)
		deck.clear()
		if not custom_deck.is_empty():
			for k in custom_deck:
				deck.append(String(k))
		else:
			deck.assign(CardPool.build_starter_deck(lineup))
	else:
		_setup_roster(initial_roster)
		deck.assign(CardPool.build_starter_deck(lineup))
	card_uid_counter = 0
	card_instances.clear()
	deck_enchants.clear()
	for k in deck:
		var uid := _next_card_uid()
		card_instances.append({"uid": uid, "key": String(k), "enchant": ""})
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
	message = "请先掷出行动骰（1d4）决定本回合可行动步数，沿林间小径探索。"
	log_event("小队进入焦黑森林第 %d 层，归途石门已在身后闭锁。请掷出行动骰决定步数。" % floor_level)

func apply_contract(p_contract_id: String) -> void:
	contract_id = p_contract_id if CONTRACTS.has(p_contract_id) else "standard"
	if contract_id == "bountiful_woods":
		carried_cost += 6
		if not items.has("echo_pendulum"):
			items.append("echo_pendulum")
		log_event("远征契约【丰饶林野】生效：开局 +6 cost，并获赠【回响灵摆】。")
	elif contract_id == "swift_march":
		log_event("远征契约【疾风行军】生效：每次行动骰步数 +1，移动疲劳 +1。")

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
	_sync_card_instances()
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
	if not dice_rolled:
		return "等待掷骰"
	if actions_left == 0:
		return "等待结束回合"
	return "探索行动"

func can_roll_action_dice() -> bool:
	return not finished and not in_battle and pending.is_empty() and not dice_rolled

func roll_action_dice(forced_raw: int = -1) -> Dictionary:
	if finished or in_battle or not pending.is_empty():
		return {"ok": false, "reason": "请先处理当前地点或战斗。"}
	if dice_rolled:
		return {"ok": false, "reason": "本回合已掷过行动骰。"}
	var raw: int = forced_raw if (forced_raw >= DICE_MIN and forced_raw <= DICE_MAX) else dice_rng.randi_range(DICE_MIN, DICE_MAX)
	if raw == 1 and RelicSystem.has_relic(relics, "time_hourglass"):
		raw = 2
		log_event("时之沙漏生效：行动骰最低点数由 1 修正为 2。")
	var penalty: int = 1 if fatigue >= FATIGUE_PENALTY_THRESHOLD else 0
	var bonus_step: int = 1 if contract_id == "swift_march" else 0
	var steps: int = maxi(1, raw - penalty + bonus_step)
	last_dice_raw = raw
	last_dice_penalty = penalty
	action_budget = steps
	actions_left = steps
	dice_rolled = true
	if penalty > 0:
		message = "行动骰掷出 %d（高疲劳 −%d），本回合可行动 %d 步。" % [raw, penalty, steps]
		log_event("第 %d 回合掷出行动骰 [%d]（高疲劳 −%d），获得 %d 步行动点。" % [turn, raw, penalty, steps])
	else:
		message = "行动骰掷出 %d，本回合可行动 %d 步。" % [raw, steps]
		log_event("第 %d 回合掷出行动骰 [%d]，获得 %d 步行动点。" % [turn, raw, steps])
	version += 1
	return {"ok": true, "raw": raw, "penalty": penalty, "steps": steps}

func move_error(to_id: String) -> String:
	if finished or in_battle or not pending.is_empty():
		return "请先处理当前地点或战斗。"
	if not dice_rolled:
		return "请先掷出本回合行动骰决定步数。"
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

func cell_move_error(cell: Vector2i) -> String:
	if map == null or not map.is_grid:
		return "当前地图非方格模式。"
	if finished or in_battle or not pending.is_empty():
		return "请先处理当前地点或战斗。"
	if not dice_rolled:
		return "请先掷出本回合行动骰决定步数。"
	if not map.is_in_bounds(cell):
		return "超出地图边界，无法通行。"
	if map.is_obstacle(cell):
		return "树林障碍，无法通行。" if map.obstacle_kind(cell) == "trees" else "水域障碍，无法通行。"
	var target_id: String = map.node_id_at(cell)
	if target_id.is_empty():
		return "该格无法通行。"
	var cur_cell: Vector2i = map.cell_of(position)
	var diff: Vector2i = (cell - cur_cell).abs()
	if diff.x + diff.y == 0:
		return "当前已在此处。"
	if diff.x == 1 and diff.y == 1:
		return "不支持斜向移动，请沿上下左右逐格前行。"
	if diff.x + diff.y > 1:
		return "目标距离过远，请逐格前行。"
	return move_error(target_id)

func can_move_cell(cell: Vector2i) -> bool:
	return cell_move_error(cell).is_empty()

func move_to_cell(cell: Vector2i) -> bool:
	if not can_move_cell(cell):
		return false
	return move(map.node_id_at(cell))

func preview_route_to(to_id: String) -> Dictionary:
	if map == null or not map.has_node(to_id) or not known.has(to_id):
		return {"ok": false, "path": [], "steps": 0, "remaining": actions_left, "can_reach_this_turn": false}
	var path: Array[String] = map.shortest_path(position, to_id, known, false)
	if path.size() <= 1:
		return {"ok": false, "path": path, "steps": 0, "remaining": actions_left, "can_reach_this_turn": false}
	var steps := path.size() - 1
	var rem := actions_left - steps
	return {
		"ok": true,
		"path": path,
		"steps": steps,
		"remaining": rem,
		"can_reach_this_turn": dice_rolled and rem >= 0
	}

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
	var fatigue_gain: int = edge.action_cost + (1 if contract_id == "swift_march" else 0)
	fatigue = mini(8, fatigue + fatigue_gain)
	
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
	if node.kind == ForestMapGraph.NodeKind.PASSAGE:
		cleared[position] = true
		message = "抵达林间空地（%s），可继续向相邻方格行动。" % node.id
		return
	if cleared.has(position) and node.kind != ForestMapGraph.NodeKind.SHOP and node.kind != ForestMapGraph.NodeKind.DESTINY_GATE:
		message += " 该地点已处理，无法重复获取收益。"
		return
		
	match node.kind:
		ForestMapGraph.NodeKind.BATTLE:
			var battle_pool := [0, 3, 6]
			current_encounter = battle_pool[rng.randi() % battle_pool.size()]
			in_battle = true
			message = "遭遇敌袭！准备进入交锋！"
		ForestMapGraph.NodeKind.ELITE:
			var elite_pool := [1, 4, 7]
			current_encounter = elite_pool[rng.randi() % elite_pool.size()]
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
			_try_roll_destiny_drop(position, DESTINY_DROP_EXPLORE, "登上哨塔")
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
			event_variant = rng.randi_range(0, 5)
			message = "林间异象：发现一处未知的古代遗迹。"
		ForestMapGraph.NodeKind.DESTINY_GATE:
			pending = "destiny_gate"
			message = "命运石之门：可领取命运或消耗命运强化全队拼点硬币正面率。"
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
				var camp_heal := 10 + (6 if RelicSystem.has_relic(relics, "trail_rations") else 0)
				if RelicSystem.has_relic(relics, "hakurei_amulet"):
					camp_heal = int(round(camp_heal * 1.5))
				heal_party(camp_heal)
				fatigue = maxi(0, fatigue - 3)
				log_event("营地休整：存活队员恢复 %d 生命，疲劳 −3。" % camp_heal)
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
				var shrine_heal := 18 if RelicSystem.has_relic(relics, "hakurei_amulet") else 12
				heal_lowest_hero(shrine_heal)
				log_event("圣泉洗礼：疲劳完全消除，重伤队员恢复 %d 生命。" % shrine_heal)
				ok = true
			elif choice == 1: # Sacred Blessing
				for i in party_max_hp.size():
					party_max_hp[i] += 4
					if party_hp[i] > 0:
						party_hp[i] += 4
				log_event("古神赐福：全体队员最大生命 +4！")
				ok = true
			if ok:
				_try_roll_destiny_drop(position, DESTINY_DROP_EXPLORE, "神龛祈福")
		"destiny_gate":
			if choice == 0:
				return bool(claim_destiny_gate().get("ok", false))
			elif choice == 1:
				return bool(upgrade_destiny_tier().get("ok", false))
			elif choice == 2:
				return leave_destiny_gate()
			return false
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
			if choice == 0: # Small Bet
				if carried_cost >= 4:
					carried_cost -= 4
					var roll := rng.randf()
					if roll < 0.50:
						carried_cost += 10
						log_event("骰局小胜：赢得 10 cost！")
					elif roll < 0.80:
						items.append("weighted_coin")
						log_event("骰局平手：赢下一枚【特制铅币】。")
					else:
						log_event("骰局落空：掷骰点数不佳，4 cost 付之东流。")
					ok = true
			elif choice == 1: # High Roller Bet
				if carried_cost >= 10:
					carried_cost -= 10
					var roll := rng.randf()
					if roll < 0.40:
						carried_cost += 28
						log_event("豪赌狂胜：通杀全场！狂揽 28 cost！")
					elif roll < 0.70:
						var unowned := RelicSystem.get_unowned_relics(relics)
						if not unowned.is_empty():
							var picked: String = unowned[rng.randi() % unowned.size()]
							relics.append(picked)
							log_event("豪赌赢下彩头：赢得被动遗物【%s】！" % RelicSystem.relic_name(picked))
						else:
							items.append("phoenix_feather")
							log_event("豪赌赢下彩头：赢得珍宝【凤凰尾羽】！")
					else:
						for i in party_hp.size():
							if party_hp[i] > 0:
								party_hp[i] = maxi(1, party_hp[i] - 3)
						fatigue += 1
						log_event("豪赌满盘皆输：−10 cost，全队受到惊吓反噬 −3 生命，疲劳 +1。")
					ok = true
			elif choice == 2: # Blood Roulette
				var any_hurt := false
				for i in party_hp.size():
					if party_hp[i] > 0:
						var loss := maxi(2, int(round(party_hp[i] * 0.20)))
						party_hp[i] = maxi(1, party_hp[i] - loss)
						any_hurt = true
				if any_hurt:
					if rng.randf() < 0.50:
						carried_cost += 12
						var unowned := RelicSystem.get_unowned_relics(relics)
						if not unowned.is_empty():
							var picked: String = unowned[rng.randi() % unowned.size()]
							relics.append(picked)
							log_event("血色轮盘大胜：以血试险，赢取遗物【%s】与 12 cost！" % RelicSystem.relic_name(picked))
						else:
							carried_cost += 8
							log_event("血色轮盘大胜：以血试险，掠取 20 cost！")
					else:
						destiny = mini(DESTINY_MAX, destiny + 2)
						fatigue += 2
						log_event("血色轮盘败北：虽未获利，但险死还生领悟命运（命运 +2，疲劳 +2）。")
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
			elif event_variant == 3: # 迷雾许愿池
				if choice == 0:
					if carried_cost >= 5:
						carried_cost -= 5
						var roll := rng.randf()
						if roll < 0.45:
							var unowned := RelicSystem.get_unowned_relics(relics)
							if not unowned.is_empty():
								var picked: String = unowned[rng.randi() % unowned.size()]
								relics.append(picked)
								log_event("许愿池显灵：捞出一枚古代遗物【%s】！" % RelicSystem.relic_name(picked))
							else:
								carried_cost += 15
								log_event("许愿池显灵：池底金光迸发，获得 15 cost！")
						elif roll < 0.80:
							heal_party(14)
							log_event("圣水涌出：沐浴甘霖，全队存活队员恢复 14 生命！")
						else:
							destiny = mini(DESTINY_MAX, destiny + 3)
							log_event("命运共鸣：池中倒映出星轨，命运 +3！")
						ok = true
				elif choice == 1:
					carried_cost += 12
					alert = mini(5, alert + 2)
					fatigue += 1
					log_event("捞取池底余烬：获得 12 cost，但惊动守卫（警戒度 +2，疲劳 +1）。")
					ok = true
			elif event_variant == 4: # 封印秘宝箱
				if choice == 0:
					if rng.randf() < 0.50:
						carried_cost += 18
						items.append(RelicSystem.roll_random_item(rng))
						log_event("强拆秘箱大获全胜：暴赚 18 cost，并夺得 1 件战术道具！")
					else:
						for i in party_hp.size():
							if party_hp[i] > 0:
								party_hp[i] = maxi(1, party_hp[i] - 6)
						log_event("触发防盗毒弩：开箱失败，全队存活角色受到 6 点毒矢伤害！")
					ok = true
				elif choice == 1:
					if carried_cost >= 4:
						carried_cost -= 4
						carried_cost += 8
						items.append(RelicSystem.roll_random_item(rng))
						log_event("巧手破译：花费 4 cost 稳妥开箱，获得 8 cost 与 1 件战术道具。")
						ok = true
			elif event_variant == 5: # 狂乱先知
				if choice == 0:
					for i in party_hp.size():
						if party_hp[i] > 0:
							party_hp[i] = maxi(1, party_hp[i] - 3)
					destiny = mini(DESTINY_MAX, destiny + 3)
					actions_left += 1
					log_event("献祭鲜血求得启示：全员失去 3 生命，命运 +3，本回合步数 +1！")
					ok = true
				elif choice == 1:
					if carried_cost >= 4:
						carried_cost -= 4
						fatigue = 0
						items.append("clarity_elixir")
						log_event("购买澄明秘药：−4 cost，疲劳完全消除，获得【澄明甘露】！")
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
	message = "已暂离行商，随时可以再次点击进入交易。"
	version += 1
	return true

func get_clash_heads_rate() -> float:
	return DESTINY_HEADS_RATES[clampi(destiny_tier, 0, DESTINY_HEADS_RATES.size() - 1)]

func get_clash_heads_percent() -> int:
	return int(round(get_clash_heads_rate() * 100.0))

func is_destiny_max_tier() -> bool:
	return destiny_tier >= DESTINY_HEADS_RATES.size() - 1

func get_next_destiny_heads_rate() -> float:
	return DESTINY_HEADS_RATES[mini(destiny_tier + 1, DESTINY_HEADS_RATES.size() - 1)]

func get_next_destiny_heads_percent() -> int:
	return int(round(get_next_destiny_heads_rate() * 100.0))

func get_destiny_upgrade_cost() -> int:
	if is_destiny_max_tier():
		return 0
	return DESTINY_UPGRADE_COSTS[destiny_tier]

func _destiny_node_key(node_id: String = "") -> String:
	var nid := position if node_id.is_empty() else node_id
	return "%d:%s" % [floor_level, nid]

func _is_at_destiny_gate() -> bool:
	if pending != "destiny_gate" or map == null:
		return false
	var node = map.get_node(position)
	return node != null and node.kind == ForestMapGraph.NodeKind.DESTINY_GATE

func is_destiny_gate_claimed(node_id: String = "") -> bool:
	return bool(destiny_gate_claimed.get(_destiny_node_key(node_id), false))

func get_destiny_gate_claimable_amount(node_id: String = "") -> int:
	if is_destiny_gate_claimed(node_id):
		return 0
	return clampi(DESTINY_MAX - destiny, 0, DESTINY_GATE_REWARD)

func can_claim_destiny_gate() -> Dictionary:
	if not _is_at_destiny_gate():
		return {"ok": false, "reason": "当前不在命运石之门内。", "amount": 0}
	if is_destiny_gate_claimed(position):
		return {"ok": false, "reason": "本座命运石之门已领取过命运。", "amount": 0}
	if destiny >= DESTINY_MAX:
		return {"ok": false, "reason": "命运已满（%d/%d），请先强化全队腾出空间后再领取。" % [destiny, DESTINY_MAX], "amount": 0}
	var amt := get_destiny_gate_claimable_amount(position)
	return {"ok": true, "reason": "", "amount": amt}

func claim_destiny_gate() -> Dictionary:
	var check_res := can_claim_destiny_gate()
	if not check_res.ok:
		return check_res
	var gained := int(check_res.amount)
	destiny = mini(DESTINY_MAX, destiny + gained)
	destiny_gate_claimed[_destiny_node_key(position)] = true
	cleared[position] = true
	message = "命运石之门：领取 +%d 命运（当前 %d/%d）。" % [gained, destiny, DESTINY_MAX]
	log_event("命运石之门领取：获得 +%d 命运（当前 %d/%d）。" % [gained, destiny, DESTINY_MAX])
	version += 1
	return {"ok": true, "gained": gained, "destiny": destiny}

func can_upgrade_destiny_tier(expected_target_tier: int = -1) -> Dictionary:
	if not _is_at_destiny_gate():
		return {"ok": false, "reason": "当前不在命运石之门内。"}
	if is_destiny_max_tier():
		return {"ok": false, "reason": "全队拼点正面率已满级（100%）。"}
	var next_tier := destiny_tier + 1
	if expected_target_tier >= 0 and expected_target_tier != next_tier:
		return {"ok": false, "reason": "强化档位已变更，请勿重复提交。"}
	var upg_cost := get_destiny_upgrade_cost()
	if destiny < upg_cost:
		return {"ok": false, "reason": "命运不足（需要 %d 点，当前 %d 点）。" % [upg_cost, destiny]}
	return {"ok": true, "reason": "", "cost": upg_cost, "next_tier": next_tier}

func upgrade_destiny_tier(expected_target_tier: int = -1) -> Dictionary:
	var check_res := can_upgrade_destiny_tier(expected_target_tier)
	if not check_res.ok:
		return check_res
	var upg_cost := int(check_res.cost)
	var next_tier := int(check_res.next_tier)
	var prev_tier := destiny_tier
	var prev_pct := get_clash_heads_percent()
	destiny -= upg_cost
	destiny_tier = next_tier
	var new_pct := get_clash_heads_percent()
	destiny_tier_history.append({
		"tier": destiny_tier,
		"rate": get_clash_heads_rate(),
		"percent": new_pct,
		"floor": floor_level,
		"turn": turn,
		"node": position
	})
	message = "命运石之门：消耗 %d 命运，全队拼点正面率 %d%% → %d%%！" % [upg_cost, prev_pct, new_pct]
	log_event("命运石之门强化：消耗 %d 命运，全队拼点正面率 %d%% → %d%%（剩余命运 %d/%d）。" % [upg_cost, prev_pct, new_pct, destiny, DESTINY_MAX])
	version += 1
	return {
		"ok": true,
		"cost": upg_cost,
		"prev_tier": prev_tier,
		"tier": destiny_tier,
		"prev_percent": prev_pct,
		"percent": new_pct,
		"destiny": destiny
	}

func leave_destiny_gate() -> bool:
	if pending != "destiny_gate":
		return false
	pending = ""
	message = "已暂离命运石之门，随时可以再次点击进入。"
	version += 1
	return true

func _try_roll_destiny_drop(node_id: String, chance: float, source_label: String) -> Dictionary:
	var drop_key := _destiny_node_key(node_id)
	if destiny_drop_rolled.has(drop_key):
		return {"rolled": false, "hit": false, "gained": 0, "reason": "already_rolled"}
	destiny_drop_rolled[drop_key] = true
	var roll_val := destiny_rng.randf()
	var hit := chance >= 1.0 or (chance > 0.0 and roll_val < chance)
	if not hit:
		return {"rolled": true, "hit": false, "gained": 0, "roll": roll_val}
	var gained := 0
	if destiny < DESTINY_MAX:
		destiny += 1
		gained = 1
		log_event("命运眷顾（%s）：获得 +1 命运（当前 %d/%d）。" % [source_label, destiny, DESTINY_MAX])
	else:
		log_event("命运眷顾（%s）：命运已满额（%d/%d），溢出部分已舍弃。" % [source_label, destiny, DESTINY_MAX])
	return {"rolled": true, "hit": true, "gained": gained, "roll": roll_val}

func _next_card_uid() -> String:
	card_uid_counter += 1
	return "inst_%d_%d" % [floor_level, card_uid_counter]

func _sync_card_instances() -> void:
	if card_instances.size() != deck.size():
		var new_instances: Array[Dictionary] = []
		for i in deck.size():
			var key := deck[i]
			if i < card_instances.size() and String(card_instances[i].get("key", "")) == key:
				new_instances.append(card_instances[i])
			else:
				var uid := _next_card_uid()
				var enchant := String(deck_enchants.get(uid, ""))
				new_instances.append({"uid": uid, "key": key, "enchant": enchant})
		card_instances = new_instances
	else:
		for i in deck.size():
			card_instances[i]["key"] = deck[i]
			var uid: String = card_instances[i].get("uid", "")
			if not uid.is_empty() and deck_enchants.has(uid):
				card_instances[i]["enchant"] = deck_enchants[uid]

func claim_card_reward(choice_idx: int) -> Dictionary:
	if pending != "card_reward" or pending_card_rewards.is_empty():
		return {"ok": false, "reason": "当前没有待领取的战利品符卡。"}
	if choice_idx < 0 or choice_idx >= pending_card_rewards.size():
		return {"ok": false, "reason": "请选择有效的战利品符卡。"}
	var key: String = pending_card_rewards[choice_idx]
	var check_res: Dictionary = CardPool.can_add_card(deck, key)
	if not check_res.ok:
		return check_res
	var uid := _next_card_uid()
	deck.append(key)
	card_instances.append({"uid": uid, "key": key, "enchant": ""})
	pending_card_rewards.clear()
	pending = ""
	var cname: String = DemoBattleRules.SKILLS[key].name if DemoBattleRules.SKILLS.has(key) else key
	message = "已将【%s】收入牌库（当前 %d/%d 张）。" % [cname, deck.size(), CardPool.MAX_DECK_SIZE]
	log_event("战利品选卡：获得【%s】（%s），当前牌库 %d/%d 张。" % [cname, CardPool.rarity_label(key), deck.size(), CardPool.MAX_DECK_SIZE])
	version += 1
	return {"ok": true, "key": key}

func skip_card_reward() -> Dictionary:
	if pending != "card_reward":
		return {"ok": false, "reason": "当前没有待领取的战利品符卡。"}
	pending_card_rewards.clear()
	pending = ""
	carried_cost += CardPool.SKIP_REWARD_COST
	message = "已跳过选卡，将残余符力折算为 +%d cost。" % CardPool.SKIP_REWARD_COST
	log_event("跳过战利品选卡：获得 +%d cost。" % CardPool.SKIP_REWARD_COST)
	version += 1
	return {"ok": true, "bonus_cost": CardPool.SKIP_REWARD_COST}

func ensure_shop_offers(node_id: String = "") -> Array:
	var sid := position if node_id.is_empty() else node_id
	if shop_card_offers.has(sid):
		return shop_card_offers[sid]
	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = (card_rng.seed ^ absi(sid.hash()) ^ (floor_level * 9973))
	var picks: Array[String] = CardPool.roll_card_choices(lineup, deck, shop_rng, "shop", 3)
	var offers: Array = []
	for key in picks:
		offers.append({"key": key, "price": CardPool.shop_price(key), "sold": false})
	shop_card_offers[sid] = offers
	return offers

func is_shop_removal_used(node_id: String = "") -> bool:
	var sid := position if node_id.is_empty() else node_id
	return bool(shop_removal_used.get(sid, false))

func shop_buy_card(offer_idx: int) -> Dictionary:
	if pending != "shop":
		return {"ok": false, "reason": "当前不在商店界面。"}
	var offers := ensure_shop_offers(position)
	if offer_idx < 0 or offer_idx >= offers.size():
		return {"ok": false, "reason": "无效的符卡货位。"}
	var offer: Dictionary = offers[offer_idx]
	if bool(offer.get("sold", false)):
		return {"ok": false, "reason": "该张符卡已售罄。"}
	var key: String = String(offer.get("key", ""))
	var price: int = int(offer.get("price", 4))
	if carried_cost < price:
		return {"ok": false, "reason": "余烬不足（需要 %d cost）。" % price}
	var cap_check: Dictionary = CardPool.can_add_card(deck, key)
	if not cap_check.ok:
		return cap_check
	var uid := _next_card_uid()
	carried_cost -= price
	deck.append(key)
	card_instances.append({"uid": uid, "key": key, "enchant": ""})
	offer["sold"] = true
	var cname: String = DemoBattleRules.SKILLS[key].name if DemoBattleRules.SKILLS.has(key) else key
	message = "在行商处购得【%s】（−%d cost），当前牌库 %d/%d 张。" % [cname, price, deck.size(), CardPool.MAX_DECK_SIZE]
	log_event("购买符卡【%s】：−%d cost，当前牌库 %d/%d 张。" % [cname, price, deck.size(), CardPool.MAX_DECK_SIZE])
	version += 1
	return {"ok": true, "key": key, "price": price}

func shop_remove_card(deck_idx: int) -> Dictionary:
	if pending != "shop":
		return {"ok": false, "reason": "当前不在商店界面。"}
	if is_shop_removal_used(position):
		return {"ok": false, "reason": "本商店本层已使用过精简删牌服务。"}
	if carried_cost < CardPool.REMOVE_CARD_COST:
		return {"ok": false, "reason": "余烬不足（删牌需要 %d cost）。" % CardPool.REMOVE_CARD_COST}
	var rem_check: Dictionary = CardPool.can_remove_card(deck, deck_idx)
	if not rem_check.ok:
		return rem_check
	var removed_key: String = deck[deck_idx]
	var removed_uid := ""
	if deck_idx < card_instances.size():
		removed_uid = String(card_instances[deck_idx].get("uid", ""))
		card_instances.remove_at(deck_idx)
	if not removed_uid.is_empty() and deck_enchants.has(removed_uid):
		deck_enchants.erase(removed_uid)
	carried_cost -= CardPool.REMOVE_CARD_COST
	deck.remove_at(deck_idx)
	shop_removal_used[position] = true
	var cname: String = DemoBattleRules.SKILLS[removed_key].name if DemoBattleRules.SKILLS.has(removed_key) else removed_key
	message = "已在行商处精简移除【%s】（−%d cost），当前牌库 %d/%d 张。" % [cname, CardPool.REMOVE_CARD_COST, deck.size(), CardPool.MAX_DECK_SIZE]
	log_event("商店精简删牌：移除【%s】（−%d cost），当前牌库 %d/%d 张。" % [cname, CardPool.REMOVE_CARD_COST, deck.size(), CardPool.MAX_DECK_SIZE])
	version += 1
	return {"ok": true, "key": removed_key}

func can_forge_enchant(deck_idx: int, rune_id: String) -> Dictionary:
	if pending != "forge":
		return {"ok": false, "reason": "当前不在林野锻台。"}
	if carried_cost < FORGE_ENCHANT_COST:
		return {"ok": false, "reason": "余烬不足（附魔需要 %d cost）。" % FORGE_ENCHANT_COST}
	if deck_idx < 0 or deck_idx >= deck.size():
		return {"ok": false, "reason": "请选择有效的卡牌。"}
	if not VALID_RUNES.has(rune_id):
		return {"ok": false, "reason": "未知的符文类型：%s" % rune_id}
	var key := deck[deck_idx]
	var avail: Array = DemoBattleRules.available_cards(lineup)
	if not avail.has(key):
		return {"ok": false, "reason": "当前出战队伍无法使用此卡牌进行附魔。"}
	var uid := String(card_instances[deck_idx].get("uid", "")) if deck_idx < card_instances.size() else ""
	var current_rune := String(deck_enchants.get(uid, ""))
	if current_rune == rune_id:
		return {"ok": false, "reason": "该卡牌已拥有【%s】符文，无需重复附魔。" % RUNE_META[rune_id].name}
	return {"ok": true, "reason": ""}

func forge_enchant_card(deck_idx: int, rune_id: String) -> Dictionary:
	var check_res := can_forge_enchant(deck_idx, rune_id)
	if not check_res.ok:
		return check_res
	var key := deck[deck_idx]
	var uid := String(card_instances[deck_idx].get("uid", "")) if deck_idx < card_instances.size() else ""
	if uid.is_empty():
		uid = _next_card_uid()
		if deck_idx < card_instances.size():
			card_instances[deck_idx]["uid"] = uid
	carried_cost -= FORGE_ENCHANT_COST
	deck_enchants[uid] = rune_id
	if deck_idx < card_instances.size():
		card_instances[deck_idx]["enchant"] = rune_id
	cleared[position] = true
	pending = ""
	var cname: String = DemoBattleRules.SKILLS[key].name if DemoBattleRules.SKILLS.has(key) else key
	var rname: String = RUNE_META[rune_id].name
	message = "已在余烬锻台为【%s】附魔【%s】符文（−%d cost）。" % [cname, rname, FORGE_ENCHANT_COST]
	log_event("余烬锻台附魔：为【%s】（实例 %s）镌刻【%s】（−%d cost）。" % [cname, uid, rname, FORGE_ENCHANT_COST])
	version += 1
	return {"ok": true, "uid": uid, "key": key, "rune_id": rune_id, "cost": FORGE_ENCHANT_COST}

func get_card_instance(deck_idx: int) -> Dictionary:
	if deck_idx >= 0 and deck_idx < card_instances.size():
		return card_instances[deck_idx]
	return {}

func get_active_enchants() -> Dictionary:
	return deck_enchants.duplicate()

func end_turn() -> bool:
	if in_battle or finished or not pending.is_empty():
		return false
	var rested: bool = not dice_rolled or actions_left == action_budget
	turn += 1
	hidden_turns = maxi(0, hidden_turns - 1)
	fatigue = maxi(0, fatigue - (2 if rested else 1))
	alert = maxi(0, alert - (2 if hidden_turns > 0 else (1 if rested else 0)))
	dice_rolled = false
	last_dice_raw = 0
	last_dice_penalty = 0
	action_budget = 0
	actions_left = 0
	
	signals = signals.filter(func(s: Dictionary) -> bool: return int(s.get("expires_turn", 0)) >= turn)
	_move_patrol()
	reveal()
	_check_patrol_contact()
	
	if not in_battle:
		var stealth_note := "【隐蔽中】" if hidden_turns > 0 else ""
		var fatigue_note := "（当前高疲劳，本回合骰点 −1，保底 1 步）" if fatigue >= FATIGUE_PENALTY_THRESHOLD else ""
		message = "第 %d 回合开始，请掷出行动骰（1d4）决定本回合步数。%s" % [turn, fatigue_note]
		log_event("第 %d 回合开始，等待掷出行动骰。%s%s" % [turn, stealth_note, fatigue_note])
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
	if map != null and map.is_grid:
		visible_cells.clear()
		for id in visible.keys():
			var c: Vector2i = map.cell_of(id)
			if c.x >= 0 and c.y >= 0:
				visible_cells[c] = true
				known_cells[c] = true
				for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var adj: Vector2i = c + dir
					if map.is_in_bounds(adj) and map.is_obstacle(adj):
						visible_cells[adj] = true
						known_cells[adj] = true

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

func get_revive_cost() -> int:
	var base_cost := REVIVE_HERO_COST
	if RelicSystem.has_relic(relics, "greedy_contract"):
		base_cost = int(ceil(base_cost * 0.7))
	return base_cost

func get_dead_hero_slots() -> Array[int]:
	var dead_slots: Array[int] = []
	for i in party_hp.size():
		if party_hp[i] <= 0:
			dead_slots.append(i)
	return dead_slots

func can_revive_hero(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= party_hp.size():
		return {"ok": false, "reason": "无效的队员槽位"}
	if party_hp[slot_idx] > 0:
		return {"ok": false, "reason": "该队员生命正常，无需复活"}
	var req_cost := get_revive_cost()
	if carried_cost < req_cost:
		return {"ok": false, "reason": "Cost 不足（需要 %d cost）" % req_cost}
	return {"ok": true, "cost": req_cost}

func shop_revive_hero(slot_idx: int) -> Dictionary:
	var check := can_revive_hero(slot_idx)
	if not check.ok:
		return check
	var req_cost: int = int(check.cost)
	carried_cost -= req_cost
	var revived_hp := maxi(1, int(round(float(party_max_hp[slot_idx]) * 0.40)))
	party_hp[slot_idx] = revived_hp
	var h_name: String = party_names[slot_idx] if slot_idx < party_names.size() else "队员"
	if slot_idx < lineup.size():
		var hero_id: int = lineup[slot_idx]
		if reserve_stats.has(hero_id):
			reserve_stats[hero_id]["hp"] = revived_hp
	log_event("回魂仪式：花费 %d cost 复活了队员【%s】，恢复至 %d 生命（40%%）。" % [req_cost, h_name, revived_hp])
	version += 1
	return {"ok": true, "slot": slot_idx, "name": h_name, "hp": revived_hp, "cost": req_cost}

func revive_hero_with_feather(slot_idx: int, hp_ratio: float = 0.30) -> Dictionary:
	if slot_idx < 0 or slot_idx >= party_hp.size():
		return {"ok": false, "reason": "无效的队员槽位"}
	if party_hp[slot_idx] > 0:
		return {"ok": false, "reason": "该队员生命正常"}
	var revived_hp := maxi(1, int(round(float(party_max_hp[slot_idx]) * hp_ratio)))
	party_hp[slot_idx] = revived_hp
	var h_name: String = party_names[slot_idx] if slot_idx < party_names.size() else "队员"
	if slot_idx < lineup.size():
		var hero_id: int = lineup[slot_idx]
		if reserve_stats.has(hero_id):
			reserve_stats[hero_id]["hp"] = revived_hp
	log_event("凤凰涅槃：神奇羽毛唤醒了倒下的【%s】，重获新生（恢复 %d 生命）！" % [h_name, revived_hp])
	version += 1
	return {"ok": true, "slot": slot_idx, "name": h_name, "hp": revived_hp}

func is_boss_battle() -> bool:
	if patrol_encounter:
		return false
	var node = map.get_node(position)
	return current_encounter == 5 or (node != null and node.kind in [ForestMapGraph.NodeKind.CENTER, ForestMapGraph.NodeKind.EXIT])

func is_final_boss_battle() -> bool:
	return in_battle and floor_level == MAX_FLOOR and is_boss_battle()

func get_enemy_modifier_config() -> Dictionary:
	var health := 100
	var damage := 100
	for key in enemy_modifiers:
		health += ENEMY_MODIFIERS[key].health
		damage += ENEMY_MODIFIERS[key].damage
	return {"enemy_health_percent": health, "enemy_damage_percent": damage}

func apply_battle_result(victory: bool, remaining_hp: Array, remaining_cost: int) -> void:
	if finished:
		return
	in_battle = false
	carried_cost = remaining_cost
	for i in mini(party_hp.size(), remaining_hp.size()):
		party_hp[i] = remaining_hp[i]
		
	if victory:
		var was_patrol := patrol_encounter
		if not was_patrol:
			cleared[position] = true
		var node = map.get_node(position)
		var is_boss := is_boss_battle()
		var is_elite: bool = (not was_patrol) and ((node != null and node.kind == ForestMapGraph.NodeKind.ELITE) or current_encounter in [1, 4])
		
		var reward_cost := 15 if is_boss else (10 if is_elite else 6)
		carried_cost += reward_cost
		log_event("战斗胜利！缴获 %d cost。" % reward_cost)
		if not is_boss and not is_elite:
			heal_party(6)
			log_event("战后休整：存活队员恢复 6 生命。")
		
		# Boss drops Ember Core and sets floor_cleared
		if is_boss:
			floor_cleared = true
			if floor_level == MAX_FLOOR:
				won_expedition = true
				finished = true
				pending = ""
				pending_card_rewards.clear()
				message = "第五层首领已击败，远征胜利！"
				log_event(message)
				version += 1
				return
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
		elif not was_patrol:
			var destiny_chance := DESTINY_DROP_BOSS if is_boss else (DESTINY_DROP_ELITE if is_elite else DESTINY_DROP_BATTLE)
			var destiny_source := "击败关底首领" if is_boss else ("击败精英强敌" if is_elite else "普通战斗胜利")
			_try_roll_destiny_drop(position, destiny_chance, destiny_source)

		# Slay-the-Spire post-battle 3-choose-1 card draft
		var reward_tier := "boss" if is_boss else ("elite" if is_elite else "normal")
		var choices: Array[String] = CardPool.roll_card_choices(lineup, deck, card_rng, reward_tier, 3)
		if not choices.is_empty():
			pending_card_rewards = choices
			pending = "card_reward"
			log_event("战利品符卡已就绪：可从 3 张符卡中择一加入牌库，或跳过换取 +%d cost。" % CardPool.SKIP_REWARD_COST)
	else:
		finished = true
		message = "全军覆没……小队未能走出焦黑森林。"
		log_event("小队在战斗中败北，本次探索以失败告终。")
		
	version += 1

func can_advance_to_next_floor(modifier: String) -> bool:
	return floor_cleared and floor_level < MAX_FLOOR and not finished and not in_battle and pending.is_empty() and ENEMY_MODIFIERS.has(modifier)

func advance_to_next_floor(new_map: RefCounted, seed_val: int = -1, modifier: String = "") -> bool:
	if new_map == null or not can_advance_to_next_floor(modifier):
		return false
	enemy_modifiers.append(modifier)
	log_event("敌方强化：%s。" % ENEMY_MODIFIERS[modifier].name)
	floor_level += 1
	floor_cleared = false
	ember_core = false
	finished = false
	in_battle = false
	pending = ""
	map = new_map
	if seed_val >= 0:
		rng.seed = seed_val
		dice_rng.seed = seed_val ^ 0x51A7D1CE
		card_rng.seed = seed_val ^ 0x43415244
		destiny_rng.seed = seed_val ^ 0x44455354
	pending_card_rewards.clear()
	shop_card_offers.clear()
	shop_removal_used.clear()
		
	# Reset floor-specific exploration state
	position = map.start_id
	visited = {position: true}
	cleared = {position: true}
	known = {position: true}
	visible = {position: true}
	known_cells.clear()
	visible_cells.clear()
	known_edges = {}
	signals = []
	turn = 1
	fatigue = 0
	alert = 0
	dice_rolled = false
	last_dice_raw = 0
	last_dice_penalty = 0
	action_budget = 0
	actions_left = 0
	hidden_turns = 0
	observation_expires = 0
	
	# Patrol setup for new map
	patrol_route = map.patrol_route.duplicate()
	patrol_waypoint = 0
	patrol_node = patrol_route[0] if not patrol_route.is_empty() else ""
	patrol_encounter = false
	patrol_return_turn = 0
	
	reveal()
	log_event("小队深入焦黑森林第 %d 层！更强烈的魔力在迷雾深处翻涌……请掷出行动骰决定步数。" % floor_level)
	message = "已进入焦黑森林第 %d 层。请先掷出行动骰（1d4）决定本回合可行动步数。" % floor_level
	version += 1
	return true

func log_event(text: String) -> void:
	journal.append({"turn": turn, "message": text})
	if journal.size() > 60:
		journal.pop_front()
