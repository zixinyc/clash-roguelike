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

static func kind_color(kind: int) -> Color:
	match kind:
		NodeKind.SPAWN: return Color("c6d2bc")
		NodeKind.BATTLE: return Color("e07a5f")
		NodeKind.ELITE: return Color("d62828")
		NodeKind.SUPPLY: return Color("81b29a")
		NodeKind.EVENT: return Color("b298dc")
		NodeKind.HIDEOUT: return Color("4f772d")
		NodeKind.LOOKOUT: return Color("64dfdf")
		NodeKind.DANGER: return Color("9d4edd")
		NodeKind.CENTER: return Color("f4a261")
		NodeKind.PASSAGE: return Color("90a955")
		NodeKind.CAMP: return Color("e9c46a")
		NodeKind.SHOP: return Color("48cae4")
		NodeKind.SHRINE: return Color("ff70a6")
		NodeKind.FORGE: return Color("f77f00")
		NodeKind.GAMBLE: return Color("ffd166")
		NodeKind.EXIT: return Color("a7c957")
		_: return Color("e6c38a")

static func route_color(kind: int) -> Color:
	match kind:
		RouteKind.MAIN: return Color("e6c38a")
		RouteKind.BRANCH: return Color("8cbfc8")
		RouteKind.LOOP: return Color("e6a15c")
		RouteKind.SHORTCUT: return Color("64dfdf")
		_: return Color("a8dadc")

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
