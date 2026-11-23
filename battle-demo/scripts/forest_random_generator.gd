class_name ForestRandomGenerator
extends RefCounted

const ForestMapGraph = preload("res://scripts/forest_map_graph.gd")

## 废林随机多分支地图生成器 (对应 Unity ForestRandomGenerator 扩展)

const PREFIXES := ["焦木", "迷雾", "余烬", "残月", "古树", "断剑", "幽光"]
const SUFFIXES := {
	ForestMapGraph.NodeKind.SPAWN: "入口",
	ForestMapGraph.NodeKind.BATTLE: "伏击地",
	ForestMapGraph.NodeKind.ELITE: "追猎者驻地",
	ForestMapGraph.NodeKind.SUPPLY: "行囊遗落点",
	ForestMapGraph.NodeKind.EVENT: "残碑遗迹",
	ForestMapGraph.NodeKind.HIDEOUT: "静谧树洞",
	ForestMapGraph.NodeKind.LOOKOUT: "断枝高台",
	ForestMapGraph.NodeKind.DANGER: "毒沼险地",
	ForestMapGraph.NodeKind.CENTER: "烬心祭坛",
	ForestMapGraph.NodeKind.PASSAGE: "林间空地",
	ForestMapGraph.NodeKind.CAMP: "猎人余火",
	ForestMapGraph.NodeKind.SHOP: "行商营地",
	ForestMapGraph.NodeKind.SHRINE: "御灵神龛",
	ForestMapGraph.NodeKind.FORGE: "余烬锻台",
	ForestMapGraph.NodeKind.GAMBLE: "迷雾庄台",
	ForestMapGraph.NodeKind.EXIT: "归途石门",
	ForestMapGraph.NodeKind.DESTINY_GATE: "命运石之门",
}

static func generate_map(seed_val: int = -1) -> ForestMapGraph:
	return generate(seed_val)

## 手工布置的第 1 层 9×7 废林方格地图（列 A~I = 0..8，行 1~7 = 0..6）
## 精简挡路障碍（仅保留 4 处非阻断地形点缀），将原挡路格替换为有用节点与可自由行动的空节点。
static func generate_floor1_grid(seed_val: int = 73129) -> ForestMapGraph:
	var graph := ForestMapGraph.new()
	graph.seed_value = seed_val if seed_val >= 0 else 73129
	graph.is_grid = true
	graph.grid_size = Vector2i(9, 7)

	# 仅保留少量不封路的地形障碍点缀（trees / water），其余全为可通行方格
	var tree_cells: Array[Vector2i] = [
		Vector2i(0, 0), # A1 边缘古木
		Vector2i(1, 1), # B2 哨塔侧树影
		Vector2i(5, 2), # F3 哨卡北侧林木
	]
	var water_cells: Array[Vector2i] = [
		Vector2i(4, 4), # E5 浅潭（E6/E7 均可绕行通过）
	]
	for tc in tree_cells:
		graph.set_obstacle(tc, "trees")
	for wc in water_cells:
		graph.set_obstacle(wc, "water")

	# 特殊地点配置（其余非障碍格默认注册为 PASSAGE 空节点，踩上后仍可继续行动）
	var specials := {
		Vector2i(1, 3): {"kind": ForestMapGraph.NodeKind.SPAWN, "name": "猎林入口"},
		Vector2i(0, 3): {"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "入口补给"},
		Vector2i(1, 2): {"kind": ForestMapGraph.NodeKind.LOOKOUT, "name": "断枝高台"},
		Vector2i(2, 1): {"kind": ForestMapGraph.NodeKind.DESTINY_GATE, "name": "命运石之门"},
		Vector2i(4, 0): {"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "林荫行囊"},
		Vector2i(5, 1): {"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "遗落行囊"},
		Vector2i(6, 1): {"kind": ForestMapGraph.NodeKind.GAMBLE, "name": "迷雾庄台"},
		Vector2i(5, 3): {"kind": ForestMapGraph.NodeKind.BATTLE, "name": "林间哨卡"},
		Vector2i(0, 5): {"kind": ForestMapGraph.NodeKind.GAMBLE, "name": "林边骰局"},
		Vector2i(1, 5): {"kind": ForestMapGraph.NodeKind.CAMP, "name": "西林营火"},
		Vector2i(2, 5): {"kind": ForestMapGraph.NodeKind.DANGER, "name": "荆棘险径"},
		Vector2i(3, 5): {"kind": ForestMapGraph.NodeKind.CAMP, "name": "旧猎人营火"},
		Vector2i(4, 6): {"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "溪畔行囊"},
		Vector2i(5, 5): {"kind": ForestMapGraph.NodeKind.SHRINE, "name": "荒野御灵社"},
		Vector2i(6, 6): {"kind": ForestMapGraph.NodeKind.EVENT, "name": "残碑秘窟"},
		Vector2i(7, 5): {"kind": ForestMapGraph.NodeKind.HIDEOUT, "name": "翠影树洞"},
		Vector2i(7, 1): {"kind": ForestMapGraph.NodeKind.ELITE, "name": "追猎者驻地"},
		Vector2i(8, 1): {"kind": ForestMapGraph.NodeKind.DESTINY_GATE, "name": "余晖命运石之门"},
		Vector2i(8, 2): {"kind": ForestMapGraph.NodeKind.FORGE, "name": "余烬锻台"},
		Vector2i(7, 3): {"kind": ForestMapGraph.NodeKind.CENTER, "name": "烬心祭坛"},
		Vector2i(8, 4): {"kind": ForestMapGraph.NodeKind.SHOP, "name": "战前行商"},
		Vector2i(8, 5): {"kind": ForestMapGraph.NodeKind.EXIT, "name": "关底守卫 · 归途石门"},
	}

	for y in graph.grid_size.y:
		for x in graph.grid_size.x:
			var cell := Vector2i(x, y)
			if graph.is_obstacle(cell):
				continue
			var nid := ForestMapGraph.cell_label(cell)
			var kind: int = ForestMapGraph.NodeKind.PASSAGE
			var title := "林间空地"
			if specials.has(cell):
				kind = int(specials[cell].kind)
				title = String(specials[cell].name)
			var node := ForestMapGraph.MapNode.new(
				nid,
				title,
				kind,
				Vector2.ZERO,
				ForestMapGraph.kind_icon(kind),
				ForestMapGraph.kind_summary(kind),
				cell
			)
			graph.register_grid_node(cell, node)

	graph.connect_grid_orthogonals()

	# 东侧巡逻闭环（不阻挡 B4->C4->C3->C2 到门路线，也不阻挡 C4->F4 直接接战路线）
	graph.patrol_route = ["G5", "H5", "H6", "G6"]
	return graph

static func generate(seed_val: int = -1, floor_level: int = 2) -> ForestMapGraph:
	return generate_grid(seed_val, floor_level)

## 第 2 层及后续所有楼层统一使用 9×7 方格地图（随机种子决定地形与地点分布，保持少障碍、多有用节点、空节点自由通行）
static func generate_grid(seed_val: int = -1, floor_level: int = 2) -> ForestMapGraph:
	if seed_val < 0:
		seed_val = int(Time.get_unix_time_from_system() * 1000) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ (floor_level * 9973)

	var graph := ForestMapGraph.new()
	graph.seed_value = seed_val
	graph.is_grid = true
	graph.grid_size = Vector2i(9, 7)

	# 1. 锚定关键整备节点，探索路线及支线仍由种子决定。
	var spawn_cell := Vector2i(rng.randi_range(0, 1), rng.randi_range(2, 4))
	var early_gate_cell := spawn_cell + Vector2i(2, rng.randi_range(-1, 1))
	var shop_y := rng.randi_range(2, 4)
	var shop_cell := Vector2i(7, shop_y)
	var exit_cell := Vector2i(8, shop_y)
	var center_cell := shop_cell + Vector2i(0, 1 if rng.randi_range(0, 1) == 0 else -1)

	# 巡逻闭环在整备通路的另一侧，仍会拦截前往周边支线的小队。
	var patrol_top := 1 if shop_y >= 3 else 4
	var p_cells: Array[Vector2i] = [
		Vector2i(5, patrol_top),
		Vector2i(6, patrol_top),
		Vector2i(6, patrol_top + 1),
		Vector2i(5, patrol_top + 1),
	]

	var reserved := {
		spawn_cell: true,
		exit_cell: true,
		shop_cell: true,
		center_cell: true,
		early_gate_cell: true,
	}
	# 为首座命运门及行商保留不经过障碍、遭遇或巡逻的入口。
	for x in range(spawn_cell.x + 1, early_gate_cell.x + 1):
		reserved[Vector2i(x, spawn_cell.y)] = true
	for x in range(4, shop_cell.x):
		reserved[Vector2i(x, shop_y)] = true
	for pc in p_cells:
		reserved[pc] = true

	# 2. 放置 4 处不封路的轻量地形障碍（树林 / 水域）
	var candidate_obs: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(3, 0), Vector2i(4, 3), Vector2i(4, 5),
		Vector2i(2, 6), Vector2i(7, 0), Vector2i(8, 6), Vector2i(1, 1)
	]
	_shuffle_cells(candidate_obs, rng)
	var obs_placed := 0
	for oc in candidate_obs:
		if obs_placed >= 4:
			break
		if reserved.has(oc):
			continue
		# 不贴着 spawn 或 exit 堵路
		if (oc - spawn_cell).abs().x + (oc - spawn_cell).abs().y <= 1:
			continue
		if (oc - exit_cell).abs().x + (oc - exit_cell).abs().y <= 1:
			continue
		graph.set_obstacle(oc, "water" if obs_placed == 0 else "trees")
		reserved[oc] = true
		obs_placed += 1

	# 3. 按分区放置有用节点，其余格为空节点 PASSAGE。
	var specials: Dictionary = {}
	specials[spawn_cell] = {"kind": ForestMapGraph.NodeKind.SPAWN, "name": "层间入口"}
	specials[exit_cell] = {"kind": ForestMapGraph.NodeKind.EXIT, "name": "关底守卫 · 归途石门"}
	specials[shop_cell] = {"kind": ForestMapGraph.NodeKind.SHOP, "name": "战前行商"}
	specials[center_cell] = {"kind": ForestMapGraph.NodeKind.CENTER, "name": "烬心祭坛"}
	specials[early_gate_cell] = {"kind": ForestMapGraph.NodeKind.DESTINY_GATE, "name": "命运石之门"}
	if floor_level >= 4:
		# 使用行商通路上的预留空格，同种子的其他节点不会重新洗牌。
		specials[shop_cell + Vector2i.LEFT] = {"kind": ForestMapGraph.NodeKind.DESTINY_GATE, "name": "战前命运石之门"}

	# 西区非战斗安全池（cols 0..3）：早门、瞭望台、补给、神龛、营地、树洞
	var west_cells: Array[Vector2i] = []
	for y in graph.grid_size.y:
		for x in range(0, 4):
			var c := Vector2i(x, y)
			if not reserved.has(c) and not graph.is_obstacle(c):
				west_cells.append(c)
	_shuffle_cells(west_cells, rng)

	var west_roles := [
		{"kind": ForestMapGraph.NodeKind.LOOKOUT, "name": "断枝高台"},
		{"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "遗落行囊"},
		{"kind": ForestMapGraph.NodeKind.SHRINE, "name": "荒野御灵社"},
		{"kind": ForestMapGraph.NodeKind.CAMP, "name": "林间营火"},
		{"kind": ForestMapGraph.NodeKind.HIDEOUT, "name": "翠影树洞"},
		{"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "林荫补给"},
	]
	for role in west_roles:
		if west_cells.is_empty():
			break
		var pick: Vector2i = west_cells.pop_back()
		specials[pick] = role
		reserved[pick] = true

	# 中东区（cols 4..8）：战斗、精英、锻台、事件、博弈、险地、后门、额外补给与营地
	var east_cells: Array[Vector2i] = []
	for y in graph.grid_size.y:
		for x in range(4, 9):
			var c := Vector2i(x, y)
			if not reserved.has(c) and not graph.is_obstacle(c):
				east_cells.append(c)
	_shuffle_cells(east_cells, rng)

	var mid_roles := [
		{"kind": ForestMapGraph.NodeKind.DESTINY_GATE, "name": "余晖命运石之门"},
		{"kind": ForestMapGraph.NodeKind.FORGE, "name": "余烬锻台"},
		{"kind": ForestMapGraph.NodeKind.BATTLE, "name": "林间哨卡"},
		{"kind": ForestMapGraph.NodeKind.ELITE, "name": "追猎者驻地"},
		{"kind": ForestMapGraph.NodeKind.EVENT, "name": "残碑秘窟"},
		{"kind": ForestMapGraph.NodeKind.DANGER, "name": "荆棘裂谷"},
		{"kind": ForestMapGraph.NodeKind.GAMBLE, "name": "迷雾庄台"},
		{"kind": ForestMapGraph.NodeKind.SUPPLY, "name": "深林行囊"},
		{"kind": ForestMapGraph.NodeKind.CAMP, "name": "战前营地"},
		{"kind": ForestMapGraph.NodeKind.BATTLE, "name": "焦木伏击"},
		{"kind": ForestMapGraph.NodeKind.SHRINE, "name": "林光神龛"},
	]
	for role in mid_roles:
		if east_cells.is_empty():
			break
		var pick: Vector2i = east_cells.pop_back()
		specials[pick] = role
		reserved[pick] = true

	# 4. 注册全部可通行格（非特殊点即为空节点 PASSAGE）
	for y in graph.grid_size.y:
		for x in graph.grid_size.x:
			var cell := Vector2i(x, y)
			if graph.is_obstacle(cell):
				continue
			var nid := ForestMapGraph.cell_label(cell)
			var kind: int = ForestMapGraph.NodeKind.PASSAGE
			var title := "林间空地"
			if specials.has(cell):
				kind = int(specials[cell].kind)
				title = String(specials[cell].name)
			var node := ForestMapGraph.MapNode.new(
				nid,
				title,
				kind,
				Vector2.ZERO,
				ForestMapGraph.kind_icon(kind),
				ForestMapGraph.kind_summary(kind),
				cell
			)
			graph.register_grid_node(cell, node)

	graph.connect_grid_orthogonals()

	# 巡逻路线绑定到中东侧闭环
	var patrol_ids: Array[String] = []
	for pc in p_cells:
		var pnid := graph.node_id_at(pc)
		if not pnid.is_empty():
			patrol_ids.append(pnid)
	if patrol_ids.size() >= 2:
		graph.patrol_route = patrol_ids

	return graph

static func _shuffle_cells(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _ensure_fixed_edge(g: ForestMapGraph, id: String, from_id: String, to_id: String, kind: int, bend: float) -> void:
	if from_id == to_id or g.find_edge(from_id, to_id) != null:
		return
	var edge := ForestMapGraph.MapEdge.new(id, from_id, to_id, kind, bend)
	g.add_edge(edge)

static func _set_node_meta(node: ForestMapGraph.MapNode, kind: int, title: String) -> void:
	if node == null:
		return
	node.kind = kind
	node.name = title
	node.icon = ForestMapGraph.kind_icon(kind)
	node.description = ForestMapGraph.kind_summary(kind)

static func _add_edge_internal(g: ForestMapGraph, id: String, from_id: String, to_id: String, kind: int, rng: RandomNumberGenerator) -> void:
	if from_id == to_id or g.find_edge(from_id, to_id) != null:
		return
	var bend := (1.0 if rng.randf() > 0.5 else -1.0) * rng.randf_range(0.04, 0.10)
	var edge := ForestMapGraph.MapEdge.new(id, from_id, to_id, kind, bend)
	g.add_edge(edge)

static func _ensure_edge(g: ForestMapGraph, count: int, a: String, b: String, rng: RandomNumberGenerator) -> void:
	if g.find_edge(a, b) == null:
		_add_edge_internal(g, "patrol_e_%d" % count, a, b, ForestMapGraph.RouteKind.LOOP, rng)
