extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const ForestRun = preload("res://scripts/forest_run.gd")
const Generator = preload("res://scripts/forest_random_generator.gd")
const Graph = preload("res://scripts/forest_map_graph.gd")
const Kind = Graph.NodeKind
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]
const FIGHTS := [Kind.BATTLE, Kind.ELITE, Kind.CENTER, Kind.EXIT]
const ENCOUNTERS := [0, 3, 6, 1, 4, 7, 5]
const ROUND_LIMIT := 40

class AutoPlanner extends "res://scripts/planning_ui.gd":
	func _refresh(_state: Dictionary) -> void:
		pass

var auto := AutoPlanner.new()

func _initialize() -> void:
	auto.log_label = Label.new()
	var args := OS.get_cmdline_user_args()
	if "maps" in args:
		_audit_maps(500)
	else:
		var trials := 200
		if not args.is_empty() and args[-1].is_valid_int():
			trials = maxi(1, int(args[-1]))
		var teams := {
			"default": Rules.DEFAULT_LINEUP,
			"pufufu": Rules.PUFUFU_LINEUP,
			"duo": [Rules.ASH_ID, Rules.BLADE_ID],
			"ziwu": [Rules.ZIWU_ID],
		}
		var selected_team := teams.keys().any(func(label: String) -> bool: return label in args)
		for label in teams:
			if selected_team and not label in args:
				continue
			if not "runs" in args and not "guided" in args:
				_audit_encounters(label, teams[label], trials)
			if not "battles" in args:
				var routes := ["guided"] if "guided" in args else ["direct", "prepared"]
				_audit_expeditions(label, teams[label], trials, routes)
	auto.log_label.free()
	auto.free()
	quit()

func _nodes(map: Graph, kind: int) -> Array[String]:
	var ids: Array[String] = []
	for node in map.nodes.values():
		if node.kind == kind:
			ids.append(node.id)
	return ids

# Avoid fresh hostile nodes and the patrol circuit unless they are the target.
# This uses the generated map for routing. Each move still uses live visibility.
func _path(map: Graph, start: String, end: String, safe: bool, cleared: Dictionary = {}, avoid_patrol: bool = true) -> Array[String]:
	var queue: Array[String] = [start]
	var previous := {start: ""}
	var cursor := 0
	while cursor < queue.size():
		var id := queue[cursor]
		cursor += 1
		if id == end:
			var path: Array[String] = []
			while id != start:
				path.push_front(id)
				id = previous[id]
			return path
		for direction in DIRECTIONS:
			var next := map.node_id_at(map.cell_of(id) + direction)
			if next.is_empty() or previous.has(next):
				continue
			if safe and next != end and ((avoid_patrol and next in map.patrol_route) or (map.nodes[next].kind in FIGHTS and not cleared.has(next))):
				continue
			previous[next] = id
			queue.append(next)
	return []

func _audit_maps(trials: int) -> void:
	for floor in range(1, ForestRun.MAX_FLOOR + 1):
		var samples := 1 if floor == 1 else trials
		var count := {"samples": samples, "shop_missing": 0, "shop_safe": 0, "shop_without_hostiles": 0, "exit_skip": 0, "altar_skip": 0, "shop_exit_offroute": 0, "shop_altar_offroute": 0}
		count["gate_counts"] = {}
		var values := {"shop_distance": [], "shop_to_exit": [], "shop_to_altar": [], "exit_detour": [], "altar_detour": [], "early_gate": [], "late_gate": [], "altar_distance": []}
		for i in samples:
			var map := Generator.generate_floor1_grid() if floor == 1 else Generator.generate_grid(84001 + i * 97, floor)
			var shops := _nodes(map, Kind.SHOP)
			if shops.size() != 1:
				count.shop_missing += 1
				continue
			var shop: String = shops[0]
			count.shop_safe += int(not _path(map, map.start_id, shop, true).is_empty())
			count.shop_without_hostiles += int(not _path(map, map.start_id, shop, true, {}, false).is_empty())
			count.exit_skip += int(_path(map, map.start_id, map.exit_id, true).size() > 0)
			count.altar_skip += int(_path(map, map.start_id, map.center_id, true).size() > 0)
			# Detours compare unrestricted walking distance. Safety is counted separately.
			var to_shop := _path(map, map.start_id, shop, false).size()
			var to_exit := _path(map, map.start_id, map.exit_id, false).size()
			var to_altar := _path(map, map.start_id, map.center_id, false).size()
			var shop_exit := _path(map, shop, map.exit_id, false).size()
			var shop_altar := _path(map, shop, map.center_id, false).size()
			var exit_detour := to_shop + shop_exit - to_exit
			var altar_detour := to_shop + shop_altar - to_altar
			var gates := _nodes(map, Kind.DESTINY_GATE)
			count.gate_counts[gates.size()] = int(count.gate_counts.get(gates.size(), 0)) + 1
			var gates_by_name := _gate_ids_by_name(map, gates)
			count.shop_exit_offroute += int(exit_detour > 0)
			count.shop_altar_offroute += int(altar_detour > 0)
			values.shop_distance.append(to_shop)
			values.shop_to_exit.append(shop_exit)
			values.shop_to_altar.append(shop_altar)
			values.exit_detour.append(exit_detour)
			values.altar_detour.append(altar_detour)
			values.early_gate.append(_path(map, map.start_id, gates_by_name["命运石之门"], true).size())
			values.late_gate.append(_path(map, gates_by_name["余晖命运石之门"], map.exit_id, false).size())
			values.altar_distance.append(to_altar)
		for key in values:
			var sorted: Array = values[key]
			sorted.sort()
			count[key] = [sorted.front(), sorted[floori((sorted.size() - 1) * 0.5)], sorted[floori((sorted.size() - 1) * 0.9)], sorted.back()]
		print("MAP ", floor, " ", JSON.stringify(count))

func _gate_ids_by_name(map: Graph, gates: Array[String]) -> Dictionary:
	var ids := {}
	for gate in gates:
		ids[map.get_node(gate).name] = gate
	return ids

func _audit_encounters(label: String, lineup: Array, trials: int) -> void:
	var run := _start_run(lineup, 62003)
	for rate in [0.45, 0.60]:
		run.destiny_tier = 1 if rate == 0.60 else 0
		for encounter in ENCOUNTERS:
			var counts := {"auto": 0, "tactical": 0, "timeouts": 0}
			for i in trials:
				for policy in ["auto", "tactical"]:
					var battle := _fight(run, encounter, 50021 + i * 37, policy)
					counts[policy] += int(battle.outcome == "victory")
					counts.timeouts += int(battle.outcome.is_empty())
			print("BATTLE ", label, " ", rate, " ", encounter, " ", JSON.stringify(counts), " n=", trials)

func _audit_expeditions(label: String, lineup: Array, trials: int, routes: Array) -> void:
	for route in routes:
		for policy in ["auto", "tactical"]:
			var stats := {
				"wins": 0, "fight_wins": 0, "fights": 0, "timeouts": 0, "blocked": 0,
				"deaths": [0, 0, 0, 0, 0], "defeats_by_enemy": [0, 0, 0, 0, 0, 0, 0, 0],
				"boss_tiers": [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]],
				"boss_wins": [0, 0, 0, 0, 0],
			}
			for i in trials:
				_expedition(lineup, 62003 + i * 97, route, policy, stats)
			print("RUN ", label, " ", route, " ", policy, " ", JSON.stringify(stats), " n=", trials)

func _start_run(lineup: Array, seed_value: int) -> ForestRun:
	var run := ForestRun.new()
	run.initialize(Generator.generate_floor1_grid(seed_value), 0, ["mercury_die"], ["field_poultice", "dense_smoke"], seed_value, lineup)
	return run

func _expedition(lineup: Array, seed_value: int, route: String, policy: String, stats: Dictionary) -> void:
	var run := _start_run(lineup, seed_value)
	var battle_rng := RandomNumberGenerator.new()
	battle_rng.seed = seed_value
	while not run.finished:
		var map: Graph = run.map
		var itinerary: Array[String] = []
		if route in ["prepared", "guided"]:
			var gates := _gate_ids_by_name(map, _nodes(map, Kind.DESTINY_GATE))
			itinerary.append(gates["命运石之门"])
			if route == "prepared":
				var shrines := _nodes(map, Kind.SHRINE)
				shrines.sort_custom(func(a: String, b: String) -> bool: return map.cell_of(a).x < map.cell_of(b).x)
				var camps := _nodes(map, Kind.CAMP)
				camps.sort_custom(func(a: String, b: String) -> bool: return map.cell_of(a).x > map.cell_of(b).x)
				itinerary.append_array([shrines[0], _nodes(map, Kind.BATTLE)[0], camps[0], gates["余晖命运石之门"], _nodes(map, Kind.FORGE)[0]])
			itinerary.append(_nodes(map, Kind.SHOP)[0])
		itinerary.append(map.exit_id)
		for destination in itinerary:
			var path := _path(map, run.position, destination, true, run.cleared)
			if path.is_empty() and run.position != destination:
				path = _path(map, run.position, destination, true, run.cleared, false)
			if path.is_empty() and run.position != destination:
				path = _path(map, run.position, destination, false)
			if path.is_empty() and run.position != destination:
				stats.blocked += 1
				return
			for step in path:
				if run.dice_rolled and run.actions_left == 0:
					run.end_turn()
					_resolve_node(run, battle_rng, policy, stats)
					if run.finished or run.floor_cleared:
						break
				if not run.dice_rolled:
					run.roll_action_dice()
				if not run.move(step):
					stats.blocked += 1
					return
				_resolve_node(run, battle_rng, policy, stats)
				if run.finished or run.floor_cleared:
					break
			if run.finished or run.floor_cleared:
				break
		if run.finished:
			break
		var next_seed := seed_value + run.floor_level * 13217
		var next_map := Generator.generate_grid(next_seed, run.floor_level + 1)
		if not run.advance_to_next_floor(next_map, next_seed, "fortified"):
			stats.blocked += 1
			return
	stats.wins += int(run.won_expedition)

func _resolve_node(run: ForestRun, rng: RandomNumberGenerator, policy: String, stats: Dictionary) -> void:
	if run.in_battle:
		var encounter := run.current_encounter
		var is_boss := run.is_boss_battle()
		if is_boss:
			stats.boss_tiers[run.floor_level - 1][run.destiny_tier] += 1
		var battle := _fight(run, encounter, rng.randi(), policy)
		var hp: Array[int] = []
		for hero in battle.heroes:
			hp.append(hero.hp)
		var won := battle.outcome == "victory"
		stats.fight_wins += int(won)
		stats.fights += 1
		stats.timeouts += int(battle.outcome.is_empty())
		if is_boss and won:
			stats.boss_wins[run.floor_level - 1] += 1
		if not won:
			stats.deaths[run.floor_level - 1] += 1
			stats.defeats_by_enemy[encounter] += 1
		run.items.assign(battle.active_items)
		run.apply_battle_result(won, hp, battle.cost)
	match run.pending:
		"destiny_gate":
			run.claim_destiny_gate()
			while run.upgrade_destiny_tier().ok:
				pass
			run.leave_destiny_gate()
		"camp":
			run.apply_choice(0 if _missing_hp(run) >= 10 else 1)
		"shrine":
			run.apply_choice(1)
		"forge":
			run.apply_choice(0)
		"shop":
			for slot in run.get_dead_hero_slots():
				run.shop_revive_hero(slot)
			if run.carried_cost >= 14:
				run.apply_choice(0 if _missing_hp(run) >= 12 else 1)
			run.leave_shop()
		"card_reward":
			var best := -1
			var best_score := 19.0
			for i in run.pending_card_rewards.size():
				var key := run.pending_card_rewards[i]
				var card: Dictionary = Rules.SKILLS[key]
				var score := _damage(card, 0.65) - 1.5 * int(card.cost)
				if score > best_score and not card.get("requires_clash", false):
					best = i
					best_score = score
			if best < 0 or not run.claim_card_reward(best).ok:
				run.skip_card_reward()
		"":
			pass
		_:
			run.cleared[run.position] = true
			run.pending = ""

func _missing_hp(run: ForestRun) -> int:
	var missing := 0
	for i in run.party_hp.size():
		if run.party_hp[i] > 0:
			missing += run.party_max_hp[i] - run.party_hp[i]
	return missing

func _fight(run: ForestRun, encounter: int, seed_value: int, policy: String) -> Rules:
	var battle := Rules.new()
	var config := {
		"flex_attack_in_ultimate": true, "unopposed_bonus": true,
		"deck_cycle": true, "synergy_enabled": true, "draw_count": Rules.DEFAULT_DRAW_COUNT,
		"ally_clash_heads_chance": run.get_clash_heads_rate(),
		"card_instances": run.card_instances, "deck_enchants": run.deck_enchants,
		"party_hp": run.party_hp, "party_max_hp": run.party_max_hp,
	}
	config.merge(run.get_enemy_modifier_config())
	battle.start(seed_value, encounter, false, false, run.lineup, run.deck, false, run.relics, run.items, config)
	battle.cost = run.carried_cost + maxi(0, battle.cost - Rules.START_COST)
	for slot in battle.enemy_slots:
		if slot.active and slot.category != 2:
			slot.target = battle._living_target(slot.target)
	while battle.outcome.is_empty() and battle.turn <= ROUND_LIMIT:
		_use_items(battle, encounter)
		if policy == "auto":
			auto.battle = battle
			auto._auto_plan()
		else:
			_plan_tactical(battle)
		battle.lock_and_resolve()
		if battle.outcome.is_empty():
			battle.next_round()
	return battle

func _use_items(battle: Rules, encounter: int) -> void:
	var threatened := false
	for hero in battle.heroes:
		if hero.hp > 0 and hero.hp <= hero.max_hp - 12:
			battle.use_item("field_poultice")
			threatened = threatened or hero.hp <= 24
	if encounter == 5 or threatened:
		battle.use_item("dense_smoke")

func _damage(card: Dictionary, rate: float) -> float:
	var coins: int = card.coins
	if card.has("damage_base"):
		return float(card.damage_base) + float(card.damage_power) * coins * rate
	return coins * (float(card.base) + (coins + 1) * 0.5 * float(card.power) * rate)

# Score legal plans by expected damage and threat coverage without sampling future rolls.
func _plan_tactical(battle: Rules) -> void:
	var covered := {}
	var planned_damage := {}
	var targets := []
	var threats := {}
	var unopposed_targets := {}
	var slots := []
	for slot in battle.hero_slots:
		if battle.heroes[slot.unit].hp > 0 and not slot.get("frozen", false):
			slots.append(slot)
	for target in battle.enemy_slots:
		if battle.enemies[target.unit].hp <= 0:
			continue
		if target.active and target.category != 2:
			targets.append(target)
			threats[target.id] = _damage(Rules.SKILLS[target.key], 0.50)
		elif not unopposed_targets.has(target.unit):
			targets.append(target)
			unopposed_targets[target.unit] = true
	while not slots.is_empty():
		var best := []
		var best_score := 0.0
		for slot in slots:
			var hero: Dictionary = battle.heroes[slot.unit]
			for card_index in battle.hand.size():
				var key := battle.hand[card_index]
				var card: Dictionary = Rules.SKILLS[key]
				var owner := Rules.card_owner(key)
				if not battle.slot_accepts_category(slot, key) or (owner >= 0 and owner != hero.character_id):
					continue
				var damage := _damage(card, 0.65)
				var cost := battle.card_effective_cost(card_index)
				var price := cost * (0.65 if battle.cost - battle.reserved_cost() >= 12 else 1.7)
				if not Rules.targets_enemy(key):
					var incoming := 0.0
					for target in targets:
						if target.target == slot.unit and not covered.has(target.id):
							incoming += float(threats.get(target.id, 0))
					var score := minf(incoming, Rules.ally_guard_amount(key) + 3) * 0.6 - price
					if key in ["cover", "light_guard", "pufufu_soft_guard"] and not threats.is_empty():
						score += 4.0
					if score > best_score and battle.can_assign(card_index, slot.id, -1).is_empty():
						best = [card_index, slot, -1, false, false, 0.0]
						best_score = score
					continue
				for target in targets:
					var clashes := battle.can_clash(slot, target)
					if clashes and covered.has(target.id):
						continue
					var foe: Dictionary = battle.enemies[target.unit]
					var enhanced := card.has("enhance_name") and battle.enhancement_error(hero, slot.id, key).is_empty()
					var expected := damage + Rules.UNOPPOSED_BONUS
					var score := expected
					if clashes:
						var enemy_card: Dictionary = Rules.SKILLS[target.key]
						var ally_power := float(card.base) + float(card.coins) * (float(card.power) + 1.0) * battle.ally_clash_heads_chance
						ally_power += Rules.clash_bonus(key, hero.character_id, int(hero.get("preparation", 0))) + (2.0 if enhanced else 0.0)
						var enemy_power := float(enemy_card.base) + float(enemy_card.coins) * (float(enemy_card.power) + 1.0) * 0.5
						var odds := clampf(0.53 + (ally_power - enemy_power) * 0.105 + (card.coins - enemy_card.coins) * 0.07, 0.03, 0.98)
						expected = damage * odds * 0.82
						score = expected + float(threats[target.id]) * (odds * 2.0 - 0.22)
						if battle.heroes[target.target].hp <= 22:
							score += odds * 6.0
					if key == "pufufu_soft_guard" and not threats.is_empty():
						score += 5.0
					var remaining := float(foe.hp + foe.shield) - float(planned_damage.get(target.unit, 0.0))
					score -= price + maxf(0.0, expected - maxf(remaining, 1.0)) * 0.8
					if remaining > 0.0 and expected >= remaining:
						score += 9.0 if battle.enemies.size() > 1 else 3.0
					if score > best_score and battle.can_assign(card_index, slot.id, target.id, enhanced).is_empty():
						best = [card_index, slot, target.id, enhanced, clashes, expected]
						best_score = score
		if best.is_empty():
			break
		battle.assign(best[0], best[1].id, best[2], best[3])
		if best[2] >= 0:
			var unit: int = battle.enemy_slots[best[2]].unit
			planned_damage[unit] = float(planned_damage.get(unit, 0.0)) + best[5]
			if best[4]:
				covered[best[2]] = true
		slots.erase(best[1])
