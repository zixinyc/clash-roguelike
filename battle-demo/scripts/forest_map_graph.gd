class_name ForestMapGraph
extends RefCounted

## 废林探险地图拓扑图数据结构与算法 (转译自 Unity ForestMapDefinition)

enum NodeKind {
	SPAWN,     # 猎林入口
	BATTLE,    # 普通遭遇
	ELITE,     # 精英伏击
	SUPPLY,    # 行囊补给
	EVENT,     # 随机事件
	HIDEOUT,   # 隐蔽树洞 (消耗行动规避巡逻)
	LOOKOUT,   # 瞭望高台 (消耗行动开辟视野)
	DANGER,    # 危险区域 (暴露度与遇险率提升)
	CENTER,    # 烬心祭坛 (核心目标：夺取烬核)
	PASSAGE,   # 特殊通路
	CAMP,      # 旧猎人营火 (休整恢复)
	SHOP,      # 废林行商 (消耗 Cost 购买道具/遗物)
	SHRINE,    # 博丽神龛 (净化与祈福加成)
	FORGE,     # 余烬锻台 (符卡强化与定制)
	GAMBLE,    # 迷雾博弈 (硬币筹码对赌)
	EXIT       # 归途石门 (带烬核撤离)
}

enum RouteKind {
	MAIN,      # 主路线 (平滑暖色小径)
	BRANCH,    # 支线 (次级路径)
	LOOP,      # 环路 (巡逻兽群巡游路径)
	SHORTCUT   # 隐秘捷径 (需情报碎片开启的特殊通道)
}

class MapNode extends RefCounted:
	var id: String
	var name: String
	var kind: int
	var pos: Vector2 # 0.0 ~ 1.0 相对坐标
	var icon: String
	var description: String
	
	func _init(p_id: String, p_name: String, p_kind: int, p_pos: Vector2, p_icon: String = "", p_desc: String = "") -> void:
		id = p_id
		name = p_name
		kind = p_kind
		pos = p_pos
		icon = p_icon
		description = p_desc

class MapEdge extends RefCounted:
	var id: String
	var from_id: String
	var to_id: String
	var kind: int
	var hidden: bool = false
	var action_cost: int = 1
	var intel_cost: int = 0
	var bend: float = 0.0 # 贝塞尔曲线弯曲偏置 (-1.0 ~ 1.0)
	
	func _init(p_id: String, p_from: String, p_to: String, p_kind: int = RouteKind.MAIN, p_bend: float = 0.0) -> void:
		id = p_id
		from_id = p_from
		to_id = p_to
		kind = p_kind
		bend = p_bend
	
	func other(node_id: String) -> String:
		return to_id if from_id == node_id else from_id

var seed_value: int = 73129
var start_id: String = ""
var exit_id: String = ""
var center_id: String = ""
var nodes: Dictionary = {} # id -> MapNode
var edges: Dictionary = {} # id -> MapEdge
var patrol_route: Array[String] = []

func has_node(id: String) -> bool:
	return nodes.has(id)

func edge_between(a: String, b: String) -> MapEdge:
	return find_edge(a, b)

func distance(a: String, b: String, include_shortcuts: bool = true) -> float:
	return float(distance_between(a, b, include_shortcuts))

static func kind_title(kind: int) -> String:
	match kind:
		NodeKind.SPAWN: return "旧入口"
		NodeKind.BATTLE: return "普通遭遇"
		NodeKind.ELITE: return "精英伏击"
		NodeKind.SUPPLY: return "补给行囊"
		NodeKind.EVENT: return "随机事件"
		NodeKind.HIDEOUT: return "隐蔽树洞"
		NodeKind.LOOKOUT: return "断枝高台"
		NodeKind.DANGER: return "毒雾险地"
		NodeKind.CENTER: return "烬心祭坛"
		NodeKind.PASSAGE: return "旧路石阶"
		NodeKind.CAMP: return "余火营地"
		NodeKind.SHOP: return "废林行商"
		NodeKind.SHRINE: return "御灵神龛"
		NodeKind.FORGE: return "余烬锻台"
		NodeKind.GAMBLE: return "迷雾博弈"
		NodeKind.EXIT: return "归途石门"
		_: return "林间地点"

static func kind_icon(kind: int) -> String:
	match kind:
		NodeKind.SPAWN: return "◇"
		NodeKind.BATTLE: return "⚔"
		NodeKind.ELITE: return "✦"
		NodeKind.SUPPLY: return "✚"
		NodeKind.EVENT: return "？"
		NodeKind.HIDEOUT: return "☾"
		NodeKind.LOOKOUT: return "◎"
		NodeKind.DANGER: return "☣"
		NodeKind.CENTER: return "❂"
		NodeKind.PASSAGE: return "≡"
		NodeKind.CAMP: return "▲"
		NodeKind.SHOP: return "◈"
		NodeKind.SHRINE: return "⛩"
		NodeKind.FORGE: return "⚒"
		NodeKind.GAMBLE: return "🎲"
		NodeKind.EXIT: return "⚑"
		_: return "•"

static func kind_key(kind: int) -> String:
	match kind:
		NodeKind.SPAWN: return "spawn"
		NodeKind.BATTLE: return "battle"
		NodeKind.ELITE: return "elite"
		NodeKind.SUPPLY: return "supply"
		NodeKind.EVENT: return "event"
		NodeKind.HIDEOUT: return "hideout"
		NodeKind.LOOKOUT: return "lookout"
		NodeKind.DANGER: return "danger"
		NodeKind.CENTER: return "center"
		NodeKind.PASSAGE: return "passage"
		NodeKind.CAMP: return "camp"
		NodeKind.SHOP: return "shop"
		NodeKind.SHRINE: return "shrine"
		NodeKind.FORGE: return "forge"
		NodeKind.GAMBLE: return "gamble"
		NodeKind.EXIT: return "exit"
		_: return "node"

static func kind_tier(kind: int) -> int:
	match kind:
		NodeKind.CENTER, NodeKind.EXIT:
			return 2
		NodeKind.ELITE, NodeKind.CAMP, NodeKind.SHOP, NodeKind.FORGE, NodeKind.SHRINE, NodeKind.GAMBLE:
			return 1
		_:
			return 0

static func kind_texture_path(kind: int) -> String:
	return "res://art/map/node_%s.png" % kind_key(kind)

static func kind_summary(kind: int) -> String:
	match kind:
		NodeKind.SPAWN: return "阳光穿过林冠洒在石径起点，可在此整备队伍并掷骰出发。"
		NodeKind.BATTLE: return "林间遭遇游荡敌兵。获胜可缴获 6 cost，并在战后休整恢复 6 生命。"
		NodeKind.ELITE: return "强敌镇守的高危据点。击破可缴获 10 cost 并随机获得 1 件遗物。"
		NodeKind.SUPPLY: return "旅人遗落的补给行囊，抵达即可拾取 +5 cost。"
		NodeKind.EVENT: return "林间未知遗迹与偶遇，不同抉择对应稳妥收益或冒险回报。"
		NodeKind.HIDEOUT: return "茂密枝叶掩映的静谧树洞。进入后隐蔽 2 回合且警戒度 −2。"
		NodeKind.LOOKOUT: return "可俯瞰林野的高台。情报 +2，并在 2 回合内大幅扩展探索视野。"
		NodeKind.DANGER: return "荆棘密布的险峻小径。警戒度 +1，但可在险处寻得 +6 cost。"
		NodeKind.CENTER: return "蕴藏余烬核心的古老祭坛。击败守卫【烬心巨像】即可夺取烬核。"
		NodeKind.PASSAGE: return "铺满青苔的古道石阶，通往林野深处的岔路。"
		NodeKind.CAMP: return "温暖安全的林间营火。可选生火休整（+10 HP、疲劳 −3）或搜集余烬（+6 cost）。"
		NodeKind.SHOP: return "行商支起的林间摊位。可购买伤药、遗物、道具，或随时调整配队与卡牌。"
		NodeKind.SHRINE: return "沐浴林光的古老石龛。可选圣泉洗礼（清疲劳并治疗重伤）或全体最大生命 +4。"
		NodeKind.FORGE: return "余温尚存的林野锻台。可淬炼战铠（全体最大生命 +2）或熔铸催化剂。"
		NodeKind.GAMBLE: return "游民摆下的骨骰赌局。消耗 4 cost 下注，有机会赢取 10 cost 或特制铅币。"
		NodeKind.EXIT: return "藤蔓缠绕的归途石拱门。击溃关底守卫【烬心巨像】后即可迈入下一层。"
		_: return "林野中的一处静谧地标。"

static func kind_color(kind: int) -> Color:
	match kind:
		NodeKind.SPAWN: return Color("7ab36b")
		NodeKind.BATTLE: return Color("d45d48")
		NodeKind.ELITE: return Color("c1292e")
		NodeKind.SUPPLY: return Color("4c9f70")
		NodeKind.EVENT: return Color("8d6bc1")
		NodeKind.HIDEOUT: return Color("3f8452")
		NodeKind.LOOKOUT: return Color("2fa4b8")
		NodeKind.DANGER: return Color("9d447b")
		NodeKind.CENTER: return Color("e07a16")
		NodeKind.PASSAGE: return Color("7e9a59")
		NodeKind.CAMP: return Color("d99126")
		NodeKind.SHOP: return Color("2989b5")
		NodeKind.SHRINE: return Color("d95b84")
		NodeKind.FORGE: return Color("d96b1f")
		NodeKind.GAMBLE: return Color("c9981a")
		NodeKind.EXIT: return Color("5a9e3d")
		_: return Color("c99846")

static func route_color(kind: int) -> Color:
	match kind:
		RouteKind.MAIN: return Color("f4dfa6")
		RouteKind.BRANCH: return Color("d7e7c8")
		RouteKind.LOOP: return Color("e9a46c")
		RouteKind.SHORTCUT: return Color("5fe0d4")
		_: return Color("e8dfb8")

static func bezier_points(p0: Vector2, p1: Vector2, bend: float = 0.0, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var mid := (p0 + p1) * 0.5
	var diff := p1 - p0
	var normal := Vector2(-diff.y, diff.x).normalized()
	var ctrl := mid + normal * (bend * diff.length() * 0.25)
	for i in segments + 1:
		var t := float(i) / float(segments)
		var p := (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * ctrl + t * t * p1
		pts.append(p)
	return pts

func add_node(node: MapNode) -> void:
	nodes[node.id] = node
	if start_id.is_empty() and node.kind == NodeKind.SPAWN:
		start_id = node.id
	elif exit_id.is_empty() and node.kind == NodeKind.EXIT:
		exit_id = node.id
	elif center_id.is_empty() and node.kind == NodeKind.CENTER:
		center_id = node.id

func add_edge(edge: MapEdge) -> void:
	edges[edge.id] = edge

func get_node(id: String) -> MapNode:
	return nodes.get(id, null)

func get_edge(id: String) -> MapEdge:
	return edges.get(id, null)

func find_edge(a: String, b: String) -> MapEdge:
	for e in edges.values():
		var edge := e as MapEdge
		if (edge.from_id == a and edge.to_id == b) or (edge.from_id == b and edge.to_id == a):
			return edge
	return null

func get_links(node_id: String) -> Array[MapEdge]:
	var result: Array[MapEdge] = []
	for e in edges.values():
		var edge := e as MapEdge
		if edge.from_id == node_id or edge.to_id == node_id:
			result.append(edge)
	return result

func get_neighbors(node_id: String, include_hidden: bool = false) -> Array[String]:
	var result: Array[String] = []
	for edge in get_links(node_id):
		if not include_hidden and edge.hidden:
			continue
		result.append(edge.other(node_id))
	return result

func distance_between(from_id: String, to_id: String, include_shortcuts: bool = true) -> int:
	if not nodes.has(from_id) or not nodes.has(to_id):
		return 9999
	if from_id == to_id:
		return 0
	var queue: Array[String] = [from_id]
	var dist := {from_id: 0}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == to_id:
			return dist[current]
		for edge in get_links(current):
			if not include_shortcuts and edge.kind == RouteKind.SHORTCUT:
				continue
			var nxt := edge.other(current)
			if not dist.has(nxt):
				dist[nxt] = dist[current] + 1
				queue.append(nxt)
	return 9999
