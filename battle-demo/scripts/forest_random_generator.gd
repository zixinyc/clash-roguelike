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
	ForestMapGraph.NodeKind.PASSAGE: "古道石阶",
	ForestMapGraph.NodeKind.CAMP: "猎人余火",
	ForestMapGraph.NodeKind.SHOP: "行商营地",
	ForestMapGraph.NodeKind.SHRINE: "御灵神龛",
	ForestMapGraph.NodeKind.FORGE: "余烬锻台",
	ForestMapGraph.NodeKind.GAMBLE: "迷雾庄台",
	ForestMapGraph.NodeKind.EXIT: "归途石门",
}

static func generate_map(seed_val: int = -1) -> ForestMapGraph:
	return generate(seed_val)

static func generate(seed_val: int = -1) -> ForestMapGraph:
	if seed_val < 0:
		seed_val = int(Time.get_unix_time_from_system() * 1000) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var graph := ForestMapGraph.new()
	graph.seed_value = seed_val
	
	# 分层节点数量规划：7层架构 (Spawn -> 2~3 -> 3~4 -> 3~4 -> Center/Forge -> 3~4 -> 2~3 -> Exit)
	var layer_sizes: Array[int] = [
		1,
		rng.randi_range(2, 3),
		rng.randi_range(3, 4),
		rng.randi_range(3, 4),
		3, # 中心层：保底烬心祭坛、余烬锻台、特殊通道
		rng.randi_range(3, 4),
		rng.randi_range(2, 3),
		1
	]
	
	var total_layers := layer_sizes.size()
	var layers: Array[Array] = [] # 每层的节点 ID 列表
	var node_counter := 0
	
	# 节点池（根据阶段动态权重）
	var normal_pool: Array[int] = [
		ForestMapGraph.NodeKind.BATTLE,
		ForestMapGraph.NodeKind.SUPPLY,
		ForestMapGraph.NodeKind.EVENT,
		ForestMapGraph.NodeKind.HIDEOUT,
		ForestMapGraph.NodeKind.LOOKOUT,
		ForestMapGraph.NodeKind.DANGER,
		ForestMapGraph.NodeKind.SHRINE
	]
	var late_pool: Array[int] = [
		ForestMapGraph.NodeKind.ELITE,
		ForestMapGraph.NodeKind.SHOP,
		ForestMapGraph.NodeKind.FORGE,
		ForestMapGraph.NodeKind.GAMBLE,
		ForestMapGraph.NodeKind.CAMP,
		ForestMapGraph.NodeKind.BATTLE
	]
	
	for l in total_layers:
		var size: int = layer_sizes[l]
		var layer_nodes: Array[String] = []
		for j in size:
			var node_id := "n_%d" % node_counter
			node_counter += 1
			layer_nodes.append(node_id)
			
			# 确定节点类型
			var kind: int = ForestMapGraph.NodeKind.BATTLE
			if l == 0:
				kind = ForestMapGraph.NodeKind.SPAWN
			elif l == total_layers - 1:
				kind = ForestMapGraph.NodeKind.EXIT
			elif l == 4 and j == 1:
				kind = ForestMapGraph.NodeKind.CENTER
			elif l == 4 and j == 0:
				kind = ForestMapGraph.NodeKind.FORGE
			elif l < 4:
				kind = normal_pool[rng.randi() % normal_pool.size()]
			else:
				kind = late_pool[rng.randi() % late_pool.size()]
			
			# 计算坐标 (X 横向推进，Y 纵向均匀微扰)
			var base_x := 0.08 + float(l) * (0.84 / float(total_layers - 1))
			var jitter_x := rng.randf_range(-0.02, 0.02)
			var pos_x := clampf(base_x + jitter_x, 0.05, 0.95)
			
			var base_y := 0.5 if size == 1 else 0.16 + float(j) * (0.68 / float(size - 1))
			var jitter_y := 0.0 if size == 1 else rng.randf_range(-0.04, 0.04)
			var pos_y := clampf(base_y + jitter_y, 0.10, 0.90)
			
			var prefix: String = PREFIXES[rng.randi() % PREFIXES.size()]
			var suffix: String = SUFFIXES.get(kind, "旧地")
			var title: String = prefix + suffix
			
			var node := ForestMapGraph.MapNode.new(node_id, title, kind, Vector2(pos_x, pos_y), ForestMapGraph.kind_icon(kind))
			graph.add_node(node)
		
		layers.append(layer_nodes)
	
	# 保底必有关键功能节点修正
	graph.get_node(layers[1][0]).kind = ForestMapGraph.NodeKind.SUPPLY
	graph.get_node(layers[1][0]).name = "遗落行囊"
	graph.get_node(layers[1][1]).kind = ForestMapGraph.NodeKind.BATTLE
	graph.get_node(layers[1][1]).name = "迷雾哨卡"
	
	if layers[2].size() >= 2:
		graph.get_node(layers[2][0]).kind = ForestMapGraph.NodeKind.LOOKOUT
		graph.get_node(layers[2][0]).name = "断枝高台"
		graph.get_node(layers[2][1]).kind = ForestMapGraph.NodeKind.SHRINE
		graph.get_node(layers[2][1]).name = "荒野御灵社"
	
	if layers[3].size() >= 2:
		graph.get_node(layers[3][0]).kind = ForestMapGraph.NodeKind.HIDEOUT
		graph.get_node(layers[3][0]).name = "深层树洞"
		graph.get_node(layers[3][1]).kind = ForestMapGraph.NodeKind.DANGER
		graph.get_node(layers[3][1]).name = "咒雾裂谷"
	
	graph.get_node(layers[4][1]).kind = ForestMapGraph.NodeKind.CENTER
	graph.get_node(layers[4][1]).name = "烬心祭坛"
	
	if layers[5].size() >= 2:
		graph.get_node(layers[5][0]).kind = ForestMapGraph.NodeKind.ELITE
		graph.get_node(layers[5][0]).name = "追猎者驻地"
		graph.get_node(layers[5][1]).kind = ForestMapGraph.NodeKind.SHOP
		graph.get_node(layers[5][1]).name = "废林行商"
	
	if layers[6].size() >= 1:
		graph.get_node(layers[6][0]).kind = ForestMapGraph.NodeKind.CAMP
		graph.get_node(layers[6][0]).name = "最后营火"
	
	# 建立层间连线 (主干、支线与环路)
	var edge_count := 0
	for l in range(1, layers.size()):
		var prev_layer: Array = layers[l - 1]
		var curr_layer: Array = layers[l]
		
		# 1. 主干道保底
		var main_prev: String = prev_layer[mini(1, prev_layer.size() - 1)]
		var main_curr: String = curr_layer[mini(1, curr_layer.size() - 1)]
		_add_edge_internal(graph, "e_%d" % edge_count, main_prev, main_curr, ForestMapGraph.RouteKind.MAIN, rng)
		edge_count += 1
		
		# 2. 保证每个当前节点至少有一条来自上一层的输入
		for node_to in curr_layer:
			var has_in := false
			for node_from in prev_layer:
				if graph.find_edge(node_from, node_to) != null:
					has_in = true
					break
			if not has_in:
				var chosen_from: String = prev_layer[rng.randi() % prev_layer.size()]
				_add_edge_internal(graph, "e_%d" % edge_count, chosen_from, node_to, ForestMapGraph.RouteKind.BRANCH, rng)
				edge_count += 1
		
		# 3. 保证上一层的每个节点至少连出一条到下一层
		for node_from in prev_layer:
			var has_out := false
			for node_to in curr_layer:
				if graph.find_edge(node_from, node_to) != null:
					has_out = true
					break
			if not has_out:
				var chosen_to: String = curr_layer[rng.randi() % curr_layer.size()]
				_add_edge_internal(graph, "e_%d" % edge_count, node_from, chosen_to, ForestMapGraph.RouteKind.BRANCH, rng)
				edge_count += 1
		
		# 4. 随机增加分支与跨层环路 (增加肉鸽多选自由度)
		for node_to in curr_layer:
			if rng.randf() < 0.45:
				var chosen_from: String = prev_layer[rng.randi() % prev_layer.size()]
				if graph.find_edge(chosen_from, node_to) == null:
					_add_edge_internal(graph, "e_%d" % edge_count, chosen_from, node_to, ForestMapGraph.RouteKind.LOOP, rng)
					edge_count += 1
	
	# 建立闭环巡逻路线 (供巡逻兽群游走)
	if layers[3].size() >= 2 and layers[4].size() >= 2:
		var a: String = layers[3][0]
		var b: String = layers[4][0]
		var c: String = layers[4][mini(2, layers[4].size() - 1)]
		var d: String = layers[3][mini(1, layers[3].size() - 1)]
		_ensure_edge(graph, edge_count, a, b, rng); edge_count += 1
		_ensure_edge(graph, edge_count, b, c, rng); edge_count += 1
		_ensure_edge(graph, edge_count, c, d, rng); edge_count += 1
		_ensure_edge(graph, edge_count, d, a, rng); edge_count += 1
		graph.patrol_route = [a, b, c, d]
	
	# 建立隐秘捷径 (跨越多层，需消耗 1 点情报碎片与 2 点行动力)
	if layers[2].size() > 0 and layers[6].size() > 0:
		var sc_from: String = layers[2][layers[2].size() - 1]
		var sc_to: String = layers[6][layers[6].size() - 1]
		var sc := ForestMapGraph.MapEdge.new("shortcut_0", sc_from, sc_to, ForestMapGraph.RouteKind.SHORTCUT, 0.12)
		sc.hidden = true
		sc.action_cost = 2
		sc.intel_cost = 1
		graph.add_edge(sc)
	
	return graph

static func _add_edge_internal(g: ForestMapGraph, id: String, from_id: String, to_id: String, kind: int, rng: RandomNumberGenerator) -> void:
	if from_id == to_id or g.find_edge(from_id, to_id) != null:
		return
	var bend := (1.0 if rng.randf() > 0.5 else -1.0) * rng.randf_range(0.04, 0.10)
	var edge := ForestMapGraph.MapEdge.new(id, from_id, to_id, kind, bend)
	g.add_edge(edge)

static func _ensure_edge(g: ForestMapGraph, count: int, a: String, b: String, rng: RandomNumberGenerator) -> void:
	if g.find_edge(a, b) == null:
		_add_edge_internal(g, "patrol_e_%d" % count, a, b, ForestMapGraph.RouteKind.LOOP, rng)
