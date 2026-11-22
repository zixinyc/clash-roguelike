extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")
const Setup = preload("res://battle_setup.tscn")
const CardPool = preload("res://scripts/card_pool.gd")
const Pufufu = Rules.Pufufu

# 固定掷币结果：hero_heads 控制我方硬币，enemy_heads + enemy_bonus 控制敌方硬币。
class FixedCoins extends "res://scripts/battle_rules.gd":
	var hero_heads := 0
	var enemy_heads := 0
	var enemy_bonus := 0
	func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
		var heads := mini(coins, hero_heads) if chance > 0.5 else mini(coins, enemy_heads)
		var value := maxi(0, base + heads * power)
		if chance <= 0.5:
			value += enemy_bonus
		return {"value": value, "heads": heads}

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


## 起一场只带 pufufu 的战斗。默认用训练木桩当唯一敌人，结算干净可预期。
func fresh(deck: Array = [], encounter: int = Rules.TRAINING_ENCOUNTER) -> FixedCoins:
	var battle := FixedCoins.new()
	var cards: Array = deck if not deck.is_empty() else Rules.available_cards([Rules.PUFUFU_ID])
	battle.start(73129, encounter, false, false, [Rules.PUFUFU_ID], cards)
	return battle


func hero_slot(battle: FixedCoins, unit: int, category: int) -> int:
	for slot in battle.hero_slots:
		if int(slot.unit) == unit and int(slot.category) == category:
			return int(slot.id)
	return -1


func enemy_slot(battle: FixedCoins, unit: int, category: int) -> int:
	for slot in battle.enemy_slots:
		if int(slot.unit) == unit and int(slot.category) == category:
			return int(slot.id)
	return -1


func test_roster() -> void:
	var roster := Rules.create_roster()
	check(roster.size() >= 9, "the roster grows to at least nine characters")
	var hero: Dictionary = roster[Rules.PUFUFU_ID]
	check(String(hero.name) == "pufufu" and String(hero.role) == "绒毛圣盾", "pufufu keeps her identity")
	check(int(hero.hp) == 80 and int(hero.max_hp) == 80, "pufufu has 80 hp")
	check(int(hero.speed_min) == 2 and int(hero.speed_max) == 4, "pufufu is the slowest hero")
	check(hero.has("fluff") and hero.has("shield_until"), "pufufu carries the fluff and the carried shield state")


func test_ownership() -> void:
	check(Rules.card_owner("pufufu_soft_guard") == Rules.PUFUFU_ID, "the exclusive cards belong to pufufu")
	var available: Array = Rules.available_cards([Rules.PUFUFU_ID])
	var exclusive := 0
	for key in available:
		if Rules.card_owner(key) == Rules.PUFUFU_ID:
			exclusive += 1
	check(exclusive == 10, "all ten exclusive cards join the deck")
	var others: Array = Rules.available_cards([Rules.ASH_ID])
	var leaked := false
	for key in others:
		if Rules.card_owner(key) == Rules.PUFUFU_ID:
			leaked = true
	check(not leaked, "no pufufu card shows up without pufufu")
	var battle := FixedCoins.new()
	battle.start(73129, 0, false, false, [Rules.ASH_ID])
	battle.hand = ["pufufu_soft_guard"]
	battle.hand_instances = [{"uid": "card_0", "key": "pufufu_soft_guard", "enchant": ""}]
	check(battle.can_assign(0, 0, 0).contains("只能由"), "another hero cannot use the exclusive card")


func test_deck_pool() -> void:
	var starter := CardPool.build_starter_deck([Rules.PUFUFU_ID])
	check(starter.has("pufufu_soft_guard") and starter.has("pufufu_fuzz_friction"), "the starter deck carries two pufufu cards")
	check(CardPool.rarity_of("pufufu_thick_wall") == CardPool.RARITY_RARE, "the wall is a rare card")
	check(CardPool.rarity_of("pufufu_fuzz_friction") == CardPool.RARITY_COMMON, "the friction is a common card")
	var pool: Array = CardPool.eligible_reward_pool([Rules.PUFUFU_ID], [])
	var exclusive := 0
	for key in pool:
		if Rules.card_owner(key) == Rules.PUFUFU_ID:
			exclusive += 1
	check(exclusive == 10, "the reward pool offers every exclusive card")


func test_soft_guard_win() -> void:
	var battle := fresh(["pufufu_soft_guard"])
	battle.hero_heads = 2
	var card := battle.hand.find("pufufu_soft_guard")
	var slot := hero_slot(battle, 0, 2)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 0)).is_empty(), "the guard card is playable")
	battle.lock_and_resolve()
	var hero: Dictionary = battle.heroes[0]
	check(int(hero.shield) == 10, "winning the clash grants 10 shield")
	check(int(hero.fluff) == 1, "the card grants one fluff layer")
	check(int(battle.enemies[0].hp) == Rules.TRAINING_HP - 4, "the chip damage lands on the enemy")


func test_soft_guard_lose() -> void:
	# 目标选敌方防御格：拼不到点，按「拼输」结算，行动不会被取消
	var battle := fresh(["pufufu_soft_guard"])
	var card := battle.hand.find("pufufu_soft_guard")
	var slot := hero_slot(battle, 0, 2)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 2)).is_empty(), "the guard card works without a clash")
	var events := battle.lock_and_resolve()
	var hero: Dictionary = battle.heroes[0]
	check(not events.any(func(event: Dictionary) -> bool: return event.type == "cancelled"), "the action is never cancelled for pufufu")
	check(int(hero.shield) == 7, "losing the clash still grants 7 shield")
	check(int(hero.fluff) == 1, "the card grants one fluff layer either way")

	# 拼点真的输了也走拼输分支
	var lost := fresh(["pufufu_soft_guard"])
	lost.hero_heads = 0
	lost.enemy_heads = 2
	lost.enemy_bonus = 10
	var lost_card := lost.hand.find("pufufu_soft_guard")
	check(lost.assign(lost_card, hero_slot(lost, 0, 2), enemy_slot(lost, 0, 0)).is_empty(), "the guard card can lose the clash")
	lost.lock_and_resolve()
	check(int(lost.heroes[0].shield) == 7, "a lost clash grants the smaller shield")


func test_fluff_heal() -> void:
	var battle := fresh(["pufufu_fuzz_heal"])
	battle.heroes[0].hp = 50
	battle.hero_heads = 2
	var card := battle.hand.find("pufufu_fuzz_heal")
	var slot := hero_slot(battle, 0, 2)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 0)).is_empty(), "the healing card is playable")
	battle.lock_and_resolve()
	var hero: Dictionary = battle.heroes[0]
	check(int(hero.hp) == 60, "winning the clash heals the lowest ally for 10")
	check(int(hero.shield) == 8, "the healing card grants 8 shield to herself")

	var loss := fresh(["pufufu_fuzz_heal"])
	loss.heroes[0].hp = 50
	loss.hero_heads = 0
	loss.enemy_heads = 2
	loss.enemy_bonus = 10
	var loss_card := loss.hand.find("pufufu_fuzz_heal")
	check(loss.assign(loss_card, hero_slot(loss, 0, 2), enemy_slot(loss, 0, 0)).is_empty(), "the healing card can lose the clash")
	loss.lock_and_resolve()
	check(int(loss.heroes[0].hp) == 56, "losing the clash still heals for 6")
	check(int(loss.heroes[0].shield) == 8, "the healing card keeps its shield when the clash is lost")


func test_thick_wall_and_enhance() -> void:
	var battle := fresh(["pufufu_thick_wall"])
	var hero: Dictionary = battle.heroes[0]
	var slot := hero_slot(battle, 0, 2)
	var target := enemy_slot(battle, 0, 2)
	hero.fluff = 1
	check(not battle.enhancement_error(hero, slot, "pufufu_thick_wall").is_empty(), "one fluff layer is not enough")
	hero.fluff = 3
	check(battle.enhancement_error(hero, slot, "pufufu_thick_wall").is_empty(), "two fluff layers unlock the enhancement")
	check(not battle.enhancement_error(hero, slot, "pufufu_soft_guard").is_empty(), "only the wall can be enhanced")
	var card := battle.hand.find("pufufu_thick_wall")
	check(battle.assign(card, slot, target, true).is_empty(), "the enhanced wall is playable")
	check(int(hero.fluff) == 1, "the enhancement consumes two fluff layers")
	battle.lock_and_resolve()
	check(int(hero.shield) == 23, "the enhanced wall grants 14 + 1 + 8 shield")
	check(int(hero.double_reflect_round) == battle.turn, "the enhanced wall doubles the reflect this turn")
	check(int(hero.shield_until.get(battle.turn + 1, 0)) == 23, "the wall shield crosses into the next round")

	# 撤销强化要把蓬松还回来
	var undo := fresh(["pufufu_thick_wall"])
	undo.heroes[0].fluff = 4
	var undo_slot := hero_slot(undo, 0, 2)
	var undo_card := undo.hand.find("pufufu_thick_wall")
	check(undo.assign(undo_card, undo_slot, enemy_slot(undo, 0, 2), true).is_empty(), "the enhanced wall is playable again")
	check(int(undo.heroes[0].fluff) == 2, "the enhancement reserves two fluff layers")
	undo.cancel(undo_slot)
	check(int(undo.heroes[0].fluff) == 4, "cancelling returns the fluff layers")


func test_fluff_hug() -> void:
	var battle := fresh(["pufufu_fluff_hug"])
	var hero: Dictionary = battle.heroes[0]
	hero.fluff = 4
	hero.hp = 50
	var card := battle.hand.find("pufufu_fluff_hug")
	var slot := hero_slot(battle, 0, 1)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 2)).is_empty(), "the finisher is playable")
	battle.lock_and_resolve()
	check(int(hero.fluff) == 0, "the finisher consumes every fluff layer")
	check(int(hero.hp) == 63, "the finisher heals the party for 5 + 2 * 4")
	check(int(hero.shield) == 28, "the finisher grants 14 team shield plus 14 of her own")
	check(int(hero.no_fluff_round) == battle.turn + 1, "the finisher blocks fluff next round")
	battle.next_round()
	check(int(hero.round_hit_fluff) == 0, "the round counters restart")

	# 下回合受击拿不到蓬松，但反伤照常
	battle.heroes[0].hp = 80
	var events: Array[Dictionary] = []
	battle._deal_hit(events, false, 0, 0, 5, 1, 1)
	check(int(hero.fluff) == 0, "being hit next round grants no fluff")
	check(int(battle.enemies[0].hp) < Rules.TRAINING_HP, "the reflect still works")


func test_passives() -> void:
	var battle := fresh(["pufufu_soft_guard"], 0)
	var hero: Dictionary = battle.heroes[0]
	var events: Array[Dictionary] = []
	battle._deal_hit(events, false, 0, 0, 5, 1, 1)
	check(int(hero.hp) == 78, "the hit lands and the passive heal answers")
	check(int(hero.fluff) == 1, "the first hit grants one fluff layer")
	check(int(hero.round_passive_heals) == 1, "the passive heal runs once")
	check(int(battle.enemies[0].hp) == 58 - 3, "the reflect answers for 3 + fluff")
	battle._deal_hit(events, false, 0, 0, 5, 1, 1)
	check(int(hero.fluff) == 2, "the second hit grants another fluff layer")
	check(int(hero.round_passive_heals) == 2, "the passive heal runs twice")
	check(int(battle.enemies[0].hp) == 58 - 7, "the reflect grows with the fluff")
	battle._deal_hit(events, false, 0, 0, 5, 1, 1)
	check(int(hero.fluff) == 2, "the hit fluff stops at two per round")
	check(int(hero.round_passive_heals) == 2, "the passive heal stops at two per round")

	# 反伤翻倍
	var doubled := fresh(["pufufu_soft_guard"], 0)
	doubled.heroes[0].double_reflect_round = doubled.turn
	doubled.heroes[0].fluff = 2
	var doubled_events: Array[Dictionary] = []
	doubled._deal_hit(doubled_events, false, 0, 0, 5, 1, 1)
	check(int(doubled.enemies[0].hp) == 58 - 10, "the strengthened reflect is doubled")

	# 蓬松上限
	var capped := fresh(["pufufu_soft_guard"], 0)
	capped.heroes[0].fluff = 6
	var capped_events: Array[Dictionary] = []
	capped._deal_hit(capped_events, false, 0, 0, 5, 1, 1)
	check(int(capped.heroes[0].fluff) == 6, "the fluff cap holds at six")


func test_passives_in_a_real_fight() -> void:
	var battle := fresh(["pufufu_soft_guard"], 0)
	battle.hero_heads = 0
	battle.enemy_heads = 2
	battle.enemy_bonus = 10
	var card := battle.hand.find("pufufu_soft_guard")
	var slot := hero_slot(battle, 0, 2)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 0)).is_empty(), "the guard card is playable against the scout")
	battle.lock_and_resolve()
	var hero: Dictionary = battle.heroes[0]
	check(int(hero.fluff) == 3, "the fight grants two fluff layers from hits plus one from the card")
	check(int(hero.round_passive_heals) == 2, "the passive heal fires twice in the fight")
	check(int(battle.enemies[0].hp) < 58, "the scout pays for hitting her")
	check(int(battle.enemies[1].hp) < 65, "the other enemy pays too")
	check(int(hero.hp) < 80, "the enemies got their hits in")


func test_fluff_rules() -> void:
	# 绒毛摩擦给两层蓬松
	var battle := fresh(["pufufu_fuzz_friction"])
	var card := battle.hand.find("pufufu_fuzz_friction")
	var slot := hero_slot(battle, 0, 0)
	check(battle.assign(card, slot, enemy_slot(battle, 0, 0)).is_empty(), "the zero cost card is playable")
	battle.lock_and_resolve()
	check(int(battle.heroes[0].fluff) == 2, "the friction grants two fluff layers")

	# 绒毛连击拼赢也叠蓬松
	var combo := fresh(["pufufu_fuzz_combo"])
	combo.hero_heads = 2
	var combo_card := combo.hand.find("pufufu_fuzz_combo")
	check(combo.assign(combo_card, hero_slot(combo, 0, 0), enemy_slot(combo, 0, 0)).is_empty(), "the combo card is playable")
	combo.lock_and_resolve()
	check(int(combo.heroes[0].fluff) == 2, "winning the combo grants two fluff layers")
	check(int(combo.heroes[0].hp) == 80, "winning the combo costs no health")

	# 拼输要掉血，但照样叠蓬松
	var combo_loss := fresh(["pufufu_fuzz_combo"])
	combo_loss.hero_heads = 0
	combo_loss.enemy_heads = 2
	combo_loss.enemy_bonus = 10
	var combo_loss_card := combo_loss.hand.find("pufufu_fuzz_combo")
	check(combo_loss.assign(combo_loss_card, hero_slot(combo_loss, 0, 0), enemy_slot(combo_loss, 0, 0)).is_empty(), "the combo card can lose the clash")
	combo_loss.lock_and_resolve()
	check(int(combo_loss.heroes[0].hp) == 78, "losing the combo costs 2 health")
	check(int(combo_loss.heroes[0].fluff) == 0, "losing the combo grants no fluff")

	# 暖绒回响需要至少一层蓬松
	var echo := fresh(["pufufu_warm_echo"])
	var echo_card := echo.hand.find("pufufu_warm_echo")
	var echo_slot := hero_slot(echo, 0, 1)
	check(not echo.can_assign(echo_card, echo_slot, enemy_slot(echo, 0, 0)).is_empty(), "the echo needs one fluff layer")
	echo.heroes[0].fluff = 2
	echo.heroes[0].hp = 40
	check(echo.assign(echo_card, echo_slot, enemy_slot(echo, 0, 2)).is_empty(), "the echo is playable with fluff")
	echo.lock_and_resolve()
	check(int(echo.heroes[0].hp) == 48, "the echo heals the party for 8")
	check(int(echo.heroes[0].fluff) == 1, "the echo consumes one fluff layer")

	# 蓬松护佑给最低血队友挂跨回合护盾
	var bless := fresh(["pufufu_fuzz_bless"])
	bless.heroes[0].hp = 60
	var bless_card := bless.hand.find("pufufu_fuzz_bless")
	check(bless.assign(bless_card, hero_slot(bless, 0, 2), enemy_slot(bless, 0, 2)).is_empty(), "the bless card is playable")
	bless.lock_and_resolve()
	check(int(bless.heroes[0].shield) == 17, "the bless card gives 12 team shield plus 5 of her own")
	check(int(bless.heroes[0].shield_until.get(bless.turn + 1, 0)) == 12, "the ally shield crosses into the next round")


func test_ui() -> void:
	var scene := BattleScene.instantiate()
	root.add_child(scene)
	scene.sound.enabled = false
	scene.pufufu_button.pressed.emit()
	await process_frame
	var index := -1
	for i in scene.battle.heroes.size():
		if int(scene.battle.heroes[i].character_id) == Rules.PUFUFU_ID:
			index = i
	check(index >= 0, "the pufufu preset puts her on the field")
	if index >= 0:
		scene.hand_view.refresh(scene.battle.snapshot(), index, -1, false, -1, false)
		check(scene.hand_view.role_summary.text.contains("蓬松"), "the hand panel reads the fluff counter")
		check(scene.hand_view.role_summary.text.contains("反伤"), "the hand panel reads the reflect value")
		var exclusive := 0
		for key in scene.battle.hand:
			if Rules.card_owner(key) == Rules.PUFUFU_ID:
				exclusive += 1
		check(exclusive == 10, "the preset hand carries every exclusive card")
	scene.queue_free()
	await process_frame


func test_setup_page() -> void:
	var setup := Setup.instantiate()
	root.add_child(setup)
	await process_frame
	check(setup.role_buttons.size() >= 9, "the setup page lists pufufu")
	setup.get_node("%ClearLineup").pressed.emit()
	setup.role_buttons[Rules.PUFUFU_ID].button_pressed = true
	await process_frame
	check(setup.members == [Rules.PUFUFU_ID], "pufufu can be picked in the lineup")
	var cards: Array = setup._selected_cards()
	check(cards.has("pufufu_soft_guard") and cards.has("pufufu_fluff_hug") and cards.has("pufufu_thick_wall"), "the exclusive cards are listed")
	setup.queue_free()
	await process_frame


func _run() -> void:
	test_roster()
	test_ownership()
	test_deck_pool()
	test_soft_guard_win()
	test_soft_guard_lose()
	test_fluff_heal()
	test_thick_wall_and_enhance()
	test_fluff_hug()
	test_passives()
	test_passives_in_a_real_fight()
	test_fluff_rules()
	await test_ui()
	await test_setup_page()
	print("PUFUFU checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
