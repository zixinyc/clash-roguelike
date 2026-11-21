extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")
const Setup = preload("res://battle_setup.tscn")
const ZiXingYC = Rules.ZiXingYC

class FixedCoins extends "res://scripts/battle_rules.gd":
	var ally_heads := 0
	var enemy_bonus := 0

	func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
		var heads := mini(coins, ally_heads) if chance > 0.5 else 0
		return {"heads": heads, "value": maxi(0, base + heads * power + (0 if chance > 0.5 else enemy_bonus))}

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh() -> FixedCoins:
	var battle := FixedCoins.new()
	battle.start(73129, 0, false, false, [Rules.ZIXINGYC_ID])
	set_attacks(battle)
	return battle

func set_attacks(battle: DemoBattleRules, active_ids: Array = [0], key: String = "needle") -> void:
	for slot in battle.enemy_slots:
		slot.active = slot.id in active_ids
		if slot.active:
			slot.key = key
			slot.target = 0
			slot.speed = 4

func play(battle: DemoBattleRules, key: String, slot: int, target: int = 0) -> bool:
	return battle.assign(battle.hand.find(key), slot, target).is_empty()

func hero_of(battle: DemoBattleRules) -> Dictionary:
	return battle.heroes[0]

func seed_memories(hero: Dictionary, types: Array, organized: bool = false) -> void:
	hero.memory_log.clear()
	hero.next_memory_id = 1
	for kind in types:
		hero.memory_log.append({"id": int(hero.next_memory_id), "type": kind, "organized": organized})
		hero.next_memory_id += 1
	hero.memory_round_gains = 0

func strikes(events: Array[Dictionary]) -> Array[Dictionary]:
	return events.filter(func(event: Dictionary) -> bool: return event.type == "strike")

func first_clash(events: Array[Dictionary]) -> Dictionary:
	for event in events:
		if event.type == "clash":
			return event
	return {}

func total_damage(events: Array[Dictionary]) -> int:
	var total := 0
	for hit in strikes(events):
		total += int(hit.damage)
	return total

func messages(events: Array[Dictionary]) -> String:
	var text := ""
	for event in events:
		if event.type == "ability":
			text += String(event.message)
	return text


func test_roster() -> void:
	var roster := Rules.create_roster()
	check(roster.size() >= 7 and roster[Rules.ZIXINGYC_ID].name == "ZiXingYC", "roster keeps the old ids and adds the new character")
	check(roster[Rules.ZIXINGYC_ID].hp == 40 and roster[Rules.ZIXINGYC_ID].speed_min == 7 and roster[Rules.ZIXINGYC_ID].speed_max == 9, "hp and speed follow the approved preview")
	check(Rules.card_owner(ZiXingYC.ATTENTION) == Rules.ZIXINGYC_ID and Rules.card_owner(ZiXingYC.ENDING) == Rules.ZIXINGYC_ID, "the five cards belong to the new character")
	check(Rules.card_owner("ember") < 0 and Rules.card_owner("zixi_central_limit") == Rules.ZIXI_ID, "the existing card owners stay untouched")
	var with_char := Rules.available_cards([Rules.ZIXINGYC_ID])
	var without := Rules.available_cards([Rules.ASH_ID])
	check(with_char.has(ZiXingYC.RESIDUAL) and not without.has(ZiXingYC.RESIDUAL), "exclusive cards only appear with the character in the lineup")
	check(Rules.available_cards([Rules.ASH_ID, Rules.ZIXINGYC_ID, Rules.WEAVER_ID]).has(ZiXingYC.YESTERDAY), "the character can join any team order")
	var battle := fresh()
	check(battle.hand.has(ZiXingYC.ATTENTION) and battle.hand.has(ZiXingYC.ENDING), "all five cards enter the hand")
	check(play(battle, ZiXingYC.ATTENTION, 0, 0), "the attack card reaches the enemy slot")
	check(play(battle, ZiXingYC.YESTERDAY, 2, 0), "the defense card can clash with its target")
	check(not play(battle, ZiXingYC.ENDING, 1, 0), "the ending needs at least one corpus")
	check(not play(battle, ZiXingYC.ATTENTION, 1, 0), "the attack card does not fit the ultimate slot")


func test_memory_writes() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	battle.lock_and_resolve()
	check(hero.memory_log.size() == 2, "winning attention writes an observation for the clash and one extra")
	check(String(hero.memory_log[0].type) == ZiXingYC.OBSERVATION and String(hero.memory_log[1].type) == ZiXingYC.OBSERVATION, "both writes are observations")
	check(int(hero.memory_log[0].id) == 1 and int(hero.memory_log[1].id) == 2, "the memory ids increase monotonically")
	check(int(hero.memory_round_gains) == 2, "the writes count against the three per round budget")
	battle = fresh()
	hero = hero_of(battle)
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.YESTERDAY, 2, 0)
	battle.lock_and_resolve()
	check(hero.memory_log.size() == 2 and String(hero.memory_log[0].type) == ZiXingYC.REFLECTION, "losing yesterday writes a reflection for the clash")
	check(String(hero.memory_log[1].type) == ZiXingYC.REFLECTION, "the defense card adds a second reflection")
	battle = fresh()
	hero = hero_of(battle)
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	battle.lock_and_resolve()
	check(hero.memory_log.size() == 1 and String(hero.memory_log[0].type) == ZiXingYC.REFLECTION, "a lost clash writes one reflection")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	hero.memory_round_gains = 2
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	battle.lock_and_resolve()
	check(hero.memory_log.size() == 3, "the three memory budget stops the extra write")
	check(String(hero.memory_log[2].type) == ZiXingYC.OBSERVATION, "the clash result is written before the card bonus")


func test_archive() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION])
	hero.memory_log[0].id = 4
	hero.memory_log[1].id = 5
	hero.memory_log[2].id = 6
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	var events := battle.lock_and_resolve()
	check(int(hero.corpora[ZiXingYC.REASONING]) == 1, "attention archives one reasoning corpus")
	check(bool(hero.memory_log[0].organized) and bool(hero.memory_log[1].organized) and bool(hero.memory_log[2].organized), "all three memories are marked organized")
	check(int(hero.memory_log[0].id) == 4 and int(hero.memory_log[1].id) == 5 and int(hero.memory_log[2].id) == 6, "the log keeps its original order")
	check(ZiXingYC.archive_picks(hero, ZiXingYC.REASONING).is_empty(), "organized memories cannot be used twice")
	check(messages(events).contains("整理推理"), "the log reports the archive")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	battle.lock_and_resolve()
	check(int(hero.corpora[ZiXingYC.REASONING]) == 0, "a missing memory type keeps the state unchanged")
	check(not bool(hero.memory_log[0].organized), "a failed archive does not mark anything")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION])
	var picks := ZiXingYC.archive_picks(hero, ZiXingYC.RETRIEVAL)
	check(picks.size() == 3, "retrieval needs one of each type")
	check(String(picks[0].type) == ZiXingYC.REFLECTION and String(picks[1].type) == ZiXingYC.ASSOCIATION and String(picks[2].type) == ZiXingYC.OBSERVATION, "retrieval follows reflection, association, observation")
	check(not ZiXingYC.archive(hero, ZiXingYC.REASONING).is_empty(), "the archive succeeds when the materials are ready")
	check(ZiXingYC.archive(hero, ZiXingYC.RETRIEVAL).is_empty(), "only one archive per round")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION])
	var generated := ZiXingYC.archive_picks(hero, ZiXingYC.GENERATION)
	check(generated.size() == 3, "generation takes the earliest three unorganized memories")
	check(String(generated[0].type) == ZiXingYC.OBSERVATION and String(generated[1].type) == ZiXingYC.OBSERVATION and String(generated[2].type) == ZiXingYC.REFLECTION, "generation keeps duplicates and sorts by observation, reflection, association")
	check(not ZiXingYC.archive(hero, ZiXingYC.GENERATION).is_empty() and int(hero.corpora[ZiXingYC.GENERATION]) == 1, "the generation archive succeeds with three memories")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.ASSOCIATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION, ZiXingYC.OBSERVATION])
	generated = ZiXingYC.archive_picks(hero, ZiXingYC.GENERATION)
	check(generated.map(func(memory: Dictionary) -> int: return int(memory.id)) == [2, 1, 3], "generation takes the oldest three before sorting; a later observation stays out")
	play(battle, ZiXingYC.RESIDUAL, 0)
	battle.lock_and_resolve()
	check(not bool(hero.memory_log[3].organized) and int(hero.corpora[ZiXingYC.GENERATION]) == 1, "Residual keeps the newer memory unorganized")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION])
	hero.memory_log[1].id = hero.memory_log[0].id
	check(ZiXingYC.archive(hero, ZiXingYC.REASONING).is_empty() and ZiXingYC.unorganized_count(hero) == 3, "duplicate memory ids cannot produce a corpus or partially organize memories")


func test_attention_after_non_win() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.ASSOCIATION])
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.ATTENTION, 0)
	battle.lock_and_resolve()
	check(int(hero.corpora[ZiXingYC.REASONING]) == 1, "Attention can organize the reflection from its resolved loss")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.ASSOCIATION, ZiXingYC.REFLECTION])
	set_attacks(battle, [0], "ember")
	play(battle, ZiXingYC.ATTENTION, 0)
	var events := battle.lock_and_resolve()
	check(events.any(func(event: Dictionary) -> bool: return event.type == "stalemate"), "the fixture reaches a resolved stalemate")
	check(int(hero.corpora[ZiXingYC.REASONING]) == 1 and hero.memory_log.size() == 3, "Attention sorts on stalemate without writing a win or loss memory")


func test_overload() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	check(ZiXingYC.overload_penalty(hero) == 0, "four unorganized memories are free")
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	check(ZiXingYC.overload_penalty(hero) == 2, "five unorganized memories cost two points")
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	check(ZiXingYC.overload_penalty(hero) == 4, "eight unorganized memories cost four points")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	var clash := first_clash(battle.lock_and_resolve())
	check(int(clash.left) == 6, "five unorganized memories reduce the own clash by two")
	check(int(clash.right) == 3, "the enemy value is untouched by the overload")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION])
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	clash = first_clash(battle.lock_and_resolve())
	check(int(clash.left) == 4, "eight unorganized memories reduce the own clash by four")


func test_paradox() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	battle.ally_heads = 2
	play(battle, ZiXingYC.PARADOX, 0, 0)
	var events := battle.lock_and_resolve()
	check(int(battle.enemies[0].get("zixingyc_mark", 0)) == 1, "the paradox marks the target")
	check(int(battle.enemies[1].get("zixingyc_mark", 0)) == 0, "the other enemies are not marked")
	check(hero.memory_log.size() == 2 and String(hero.memory_log[0].type) == ZiXingYC.OBSERVATION, "the clash result writes an observation")
	check(String(hero.memory_log[1].type) == ZiXingYC.ASSOCIATION, "the weakening writes an association")
	check(int(hero.corpora[ZiXingYC.RETRIEVAL]) == 0, "one memory type is not enough for retrieval")
	check(total_damage(events) == 10, "the attack deals the base damage without the extra three")
	battle = fresh()
	hero = hero_of(battle)
	battle.enemies[0].zixingyc_mark = 1
	battle.ally_heads = 2
	play(battle, ZiXingYC.PARADOX, 0, 0)
	events = battle.lock_and_resolve()
	var clash := first_clash(events)
	check(int(clash.right) == 1, "the marked target loses two points in the next clash")
	check(int(battle.enemies[0].get("zixingyc_mark", 0)) == 1, "the consumed mark is applied again by the new victory")
	check(total_damage(events) == 13, "winning against an already weakened target adds three damage")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.REFLECTION])
	battle.enemies[0].hp = 1
	battle.ally_heads = 2
	play(battle, ZiXingYC.PARADOX, 0)
	battle.lock_and_resolve()
	check(battle.enemies[0].hp == 0 and int(battle.enemies[0].get("zixingyc_mark", 0)) == 0, "Paradox cannot mark a target killed by its attack")
	check(hero.memory_log.size() == 2 and not bool(hero.organized_this_round), "a lethal Paradox neither writes association nor archives retrieval")


func test_yesterday() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	battle.ally_heads = 2
	play(battle, ZiXingYC.YESTERDAY, 2, 0)
	var events := battle.lock_and_resolve()
	check(int(hero.shield) == 10, "winning yesterday grants ten shield")
	check(strikes(events).is_empty(), "the defense card deals no damage")
	check(hero.memory_log.any(func(entry: Dictionary) -> bool: return entry.type == ZiXingYC.REFLECTION), "winning Yesterday also grants reflection")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION], true)
	hero.shield = 200
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.YESTERDAY, 2, 0)
	var reduced := strikes(battle.lock_and_resolve())
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION], true)
	hero.shield = 200
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.YESTERDAY, 2, 0)
	var plain := strikes(battle.lock_and_resolve())
	check(reduced.size() == 2 and plain.size() == 2, "every incoming segment reaches the shield")
	var matched := true
	for i in reduced.size():
		if int(reduced[i].blocked) != int(floor(float(int(plain[i].blocked)) * 0.7)):
			matched = false
	check(matched, "three organized memories reduce the incoming damage by thirty percent")
	check(int(plain[0].blocked) > int(reduced[0].blocked), "the reduction lowers the blocked amount")


func test_corpora_effects() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	hero.corpora[ZiXingYC.REASONING] = 1
	battle.phase = "finished"
	battle.next_round()
	check(battle.cost == Rules.START_COST + Rules.BASE_INCOME + 1 and battle.cost == 27, "the first reasoning corpus grants one extra cost next round")
	check(int(battle.extra_income) == 1, "the extra income is reported in the snapshot")
	hero.corpora[ZiXingYC.REASONING] = 6
	battle.phase = "finished"
	battle.next_round()
	check(int(battle.extra_income) == 2, "the reasoning income stops at two")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.RETRIEVAL] = 1
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	var clash := first_clash(battle.lock_and_resolve())
	check(int(clash.right) == 2, "the first retrieval corpus weakens the opponent by one")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.GENERATION] = 3
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	check(total_damage(battle.lock_and_resolve()) == 10, "three generation corpora add three damage once per attack")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.GENERATION] = 9
	battle.ally_heads = 2
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	check(total_damage(battle.lock_and_resolve()) == 12, "the generation bonus stops at five")
	battle = fresh()
	battle.ally_heads = 2
	play(battle, "needle", 0)
	var shared_base := total_damage(battle.lock_and_resolve())
	battle = fresh()
	battle.ally_heads = 2
	hero_of(battle).corpora[ZiXingYC.GENERATION] = 3
	play(battle, "needle", 0)
	check(shared_base > 0 and total_damage(battle.lock_and_resolve()) == shared_base + 3, "generation adds damage once to a shared attack too")


func test_residual_bonus() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION])
	check(play(battle, ZiXingYC.RESIDUAL, 0, 1), "residual can use an idle slot")
	battle.lock_and_resolve()
	check(hero.memory_log.size() == 3 and hero.corpora.generation == 1, "an unopposed Residual records two observations and archives")
	battle = fresh()
	hero = hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION], true)
	check(ZiXingYC.residual_bonus(hero) == 2, "three organized memories give two extra damage")
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION, ZiXingYC.OBSERVATION], true)
	check(ZiXingYC.residual_bonus(hero) == 4, "six organized memories give four extra damage")
	var many := []
	for i in 15:
		many.append(ZiXingYC.OBSERVATION)
	seed_memories(hero, many, true)
	check(ZiXingYC.residual_bonus(hero) == 10, "the residual bonus stops at ten")


func test_ending() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	hero.corpora[ZiXingYC.REASONING] = 1
	hero.corpora[ZiXingYC.RETRIEVAL] = 1
	hero.corpora[ZiXingYC.GENERATION] = 1
	check(play(battle, ZiXingYC.ENDING, 1, 0), "the ending can be planned with a corpus in hand")
	battle.ally_heads = 2
	var events := battle.lock_and_resolve()
	var hits := strikes(events)
	check(hits.size() == 2, "the ending hits every living enemy")
	check(int(hits[0].damage) == 21 and int(hits[1].damage) == 21, "one reasoning, one retrieval and one generation corpus deal twenty one damage")
	check(int(hero.ending_uses) == 1, "one activation is used")
	check(int(hero.corpora[ZiXingYC.REASONING]) == 1 and int(hero.corpora[ZiXingYC.GENERATION]) == 1, "the corpora survive the bombardment")
	battle.next_round()
	set_attacks(battle)
	check(play(battle, ZiXingYC.ENDING, 1), "a second activation can be assigned")
	battle.lock_and_resolve()
	battle.next_round()
	set_attacks(battle)
	check(int(hero.ending_uses) == 2 and not play(battle, ZiXingYC.ENDING, 1), "two real activations prevent assigning a third")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.REASONING] = 1
	battle.enemy_bonus = 60
	play(battle, ZiXingYC.ENDING, 1, 0)
	events = battle.lock_and_resolve()
	check(int(hero.ending_uses) == 0, "losing the clash never activates the ending")
	check(strikes(events).size() == 2, "the losing side only takes the enemy attack")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.REASONING] = 1
	hero.ending_uses = 2
	check(not play(battle, ZiXingYC.ENDING, 1, 0), "the third activation is refused")
	check(int(hero.ending_uses) == 2, "the counter stays at two")
	battle = fresh()
	hero = hero_of(battle)
	hero.corpora[ZiXingYC.REASONING] = 1
	battle.ally_heads = 2
	play(battle, ZiXingYC.ENDING, 1, 0)
	battle.lock_and_resolve()
	check(int(hero.ending_uses) == 1 and hero.memory_log.size() == 1, "the ending clash still writes a memory")
	battle.start(73129, 0, false, false, [Rules.ZIXINGYC_ID])
	hero = hero_of(battle)
	check(int(hero.ending_uses) == 0 and hero.memory_log.is_empty() and int(hero.corpora[ZiXingYC.REASONING]) == 0, "restarting clears the record and the corpora")


func test_cancelled() -> void:
	var battle := fresh()
	var hero := hero_of(battle)
	seed_memories(hero, [ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION])
	play(battle, ZiXingYC.ATTENTION, 0, 0)
	battle.enemies[0].hp = 0
	battle.lock_and_resolve()
	check(int(hero.corpora[ZiXingYC.REASONING]) == 0, "a cancelled action does not archive")
	check(hero.memory_log.size() == 3, "a cancelled action writes no memory")


func test_ui() -> void:
	var scene := BattleScene.instantiate()
	root.add_child(scene)
	scene.sound.enabled = false
	scene.zixingyc_button.pressed.emit()
	var deck = scene.hand_view
	check(deck.visible_indices.size() == 5, "the preset exposes the five cards")
	check(deck.role_summary.text.contains("未整理 0") and deck.role_summary.text.contains("过载 −0"), "the hand panel reads the memory counters")
	check(deck.role_summary.text.contains("语料 推0 检0 生0") and deck.role_summary.text.contains("本轮未整理"), "the hand panel reads the corpora and the round state")
	var chosen: int = scene.battle.hand.find(ZiXingYC.ATTENTION)
	scene._select_card(chosen)
	check(scene.hint.text.contains("整理 推理：观测→关联→反思") and scene.hint.text.contains("材料不足"), "the card hint shows the recipe and the missing material")
	seed_memories(scene.battle.heroes[1], [ZiXingYC.OBSERVATION, ZiXingYC.REFLECTION, ZiXingYC.ASSOCIATION])
	scene._refresh(scene.battle.snapshot())
	scene._select_card(chosen)
	check(scene.hint.text.contains("材料充足"), "the card hint reports ready materials")
	check(deck.role_summary.text.contains("未整理 3"), "the panel counts the unorganized memories")
	scene.speed = 50.0
	scene._auto_plan()
	var used := {}
	for slot in scene.battle.hero_slots:
		if slot.active and slot.unit == 1:
			used[slot.key] = true
	check(used.has(ZiXingYC.ATTENTION) or used.has(ZiXingYC.RESIDUAL) or used.has(ZiXingYC.PARADOX) or used.has(ZiXingYC.YESTERDAY) or used.has(ZiXingYC.ENDING), "the auto plan uses the exclusive cards")
	await scene._resolve()
	check(scene.battle.turn >= 2 or not scene.battle.outcome.is_empty(), "the character takes part in a real fight")
	if "--zixingyc-preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var width := DisplayServer.window_get_size().x
		var saved := root.get_texture().get_image().save_png("res://test-output/zixingyc-runtime-%d.png" % width)
		check(saved == OK and scene.stage.zixingyc_texture != null, "the real viewport shows the local portrait")
	scene.team_button.pressed.emit()
	check(scene.battle.heroes[1].character_id == Rules.SAKUYA_ID and not scene.zixingyc_team, "the Touhou shortcut replaces the ZiXingYC preset")
	scene.queue_free()
	await process_frame


func test_setup_page() -> void:
	var setup := Setup.instantiate()
	root.add_child(setup)
	await process_frame
	check(setup.role_buttons.size() >= 7, "the setup page lists the new character")
	setup.get_node("%ClearLineup").pressed.emit()
	setup.role_buttons[Rules.ZIXINGYC_ID].button_pressed = true
	await process_frame
	check(setup.members == [Rules.ZIXINGYC_ID], "the new character can be picked in the lineup")
	var cards: Array = setup._selected_cards()
	check(cards.has(ZiXingYC.ATTENTION) and cards.has(ZiXingYC.ENDING) and cards.has(ZiXingYC.YESTERDAY), "the five exclusive cards are listed")
	setup.launch.pressed.emit()
	await process_frame
	var ui: Control = setup.active_battle
	check(ui != null, "the battle starts from the setup page")
	if ui != null:
		ui.sound.enabled = false
		var battle: DemoBattleRules = ui.battle
		check(battle.heroes.size() == 1 and battle.heroes[0].name == "ZiXingYC", "the battle uses the selected character")
		check(battle.hand.has(ZiXingYC.ENDING), "the exclusive cards enter the hand")
		ui.setup_button.pressed.emit()
		await process_frame
	setup.queue_free()
	await process_frame


func _run() -> void:
	test_roster()
	await test_setup_page()
	test_memory_writes()
	test_archive()
	test_attention_after_non_win()
	test_overload()
	test_paradox()
	test_yesterday()
	test_corpora_effects()
	test_residual_bonus()
	test_ending()
	test_cancelled()
	await test_ui()
	print("ZIXINGYC checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
