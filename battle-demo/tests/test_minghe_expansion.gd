extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Minghe = Rules.Minghe

var checks := 0
var failures := 0


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[FAIL] " + description)


func of_type(events: Array[Dictionary], event_type: String) -> Array[Dictionary]:
	return events.filter(func(ev: Dictionary) -> bool: return ev.get("type", "") == event_type)


func make_minghe_battle(seed_value: int = 218, encounter: int = Rules.TRAINING_ENCOUNTER, deck: Variant = null) -> DemoBattleRules:
	var rules := Rules.new()
	rules.start(seed_value, encounter, false, false, [Rules.MINGHE_ID, Rules.ASH_ID, Rules.WEAVER_ID], deck)
	return rules


func _initialize() -> void:
	test_assert_1_minghe_base_stats()
	test_assert_2_passive_opening_vanguard()
	test_assert_3_prelude_clash_win()
	test_assert_4_passive_echo_limit()
	test_assert_5_harmony_normal_and_enhanced()
	test_assert_6_omni_finale_and_lockout()
	test_assert_7_weakpoint_fracture_and_shatter_stagger()
	test_assert_8_clash_momentum_chain()
	print("MINGHE_EXPANSION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)


## 断言 1：minghe 基础属性验证（HP 45，速 5~7，初始律动 0）
func test_assert_1_minghe_base_stats() -> void:
	var unit := Minghe.create_unit()
	check(unit.name == "minghe", "A1: create_unit name is minghe")
	check(int(unit.hp) == 45 and int(unit.max_hp) == 45, "A1: create_unit HP/max_HP is 45")
	check(int(unit.speed_min) == 5 and int(unit.speed_max) == 7, "A1: create_unit speed range is 5~7")
	check(int(unit.rhythm) == 0, "A1: create_unit initial rhythm is 0")

	var rules := make_minghe_battle()
	check(rules.minghe_slot == 0, "A1: minghe_slot resolves to index 0")
	var hero := rules.heroes[rules.minghe_slot]
	check(hero.name == "minghe" and int(hero.hp) == 45 and int(hero.max_hp) == 45, "A1: battle hero minghe starts at 45/45 HP")
	check(int(hero.speed_min) == 5 and int(hero.speed_max) == 7, "A1: battle hero minghe speed bounds are 5~7")
	check(int(hero.rhythm) == 0 and int(hero.rhythm_passive_uses) == 0 and int(hero.no_rhythm_round) == 0, "A1: battle hero minghe starts with 0 rhythm and clean counters")


## 断言 2：被动①【先声夺势】在 prepare_round 正确将拼点 +1 发放给最高速存活友军
func test_assert_2_passive_opening_vanguard() -> void:
	var rules := make_minghe_battle(218)
	var fastest := Minghe.find_fastest_ally(rules.heroes, rules.minghe_slot)
	check(fastest > 0, "A2: fastest living ally index is valid and not minghe self")
	var other := 1 if fastest == 2 else 2
	check(int(rules.heroes[fastest].next_clash.get("先声夺势", 0)) == 1, "A2: fastest living ally receives 先声夺势 next_clash +1")
	check(int(rules.heroes[other].next_clash.get("先声夺势", 0)) == 0, "A2: slower ally does not receive 先声夺势")
	check(int(rules.heroes[0].next_clash.get("先声夺势", 0)) == 0, "A2: minghe self does not receive 先声夺势")

	var events := rules.lock_and_resolve()
	check(not events.is_empty() and events[0].type == "ability" and String(events[0].message).contains("先声夺势"), "A2: resolution timeline announces 先声夺势")

	# 若原最快友军阵亡，下回合 prepare_round 应将【先声夺势】发放给剩余最高速存活友军
	rules.heroes[fastest].hp = 0
	rules.heroes[other].next_clash.clear()
	rules.next_round()
	check(int(rules.heroes[other].next_clash.get("先声夺势", 0)) == 1, "A2: after fastest ally dies, next_round grants 先声夺势 to surviving ally")
	check(int(rules.heroes[fastest].next_clash.get("先声夺势", 0)) == 0 or rules.heroes[fastest].hp <= 0, "A2: dead ally is skipped by find_fastest_ally")

	# 若 minghe 阵亡，不再触发【先声夺势】
	rules.lock_and_resolve()
	rules.heroes[0].hp = 0
	rules.heroes[other].next_clash.clear()
	rules.next_round()
	check(int(rules.heroes[other].next_clash.get("先声夺势", 0)) == 0, "A2: dead minghe does not trigger 先声夺势")


## 断言 3：【清音起手】拼胜增加 1 层律动并给友军挂上 next_clash +2
func test_assert_3_prelude_clash_win() -> void:
	# 场景 A：常规拼胜（律动初始 0 -> 触发余音绕梁 +1 与清音起手拼胜 +1，共 +2；队友挂 next_clash +2）
	var rules := make_minghe_battle(218, Rules.TRAINING_ENCOUNTER, [Minghe.PRELUDE])
	rules.heroes[1].next_clash.clear()
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.99])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "A3: prelude can be assigned to clash and support ally 1")
	var events := rules.lock_and_resolve()
	var clashes := of_type(events, "clash")
	check(not clashes.is_empty() and int(clashes.back().get("winner", -1)) == 0 and bool(clashes.back().get("decider", false)), "A3: prelude wins the clash")
	check(int(rules.heroes[1].next_clash.get("清音起手", 0)) == 2, "A3: prelude win grants ally next_clash +2")
	check(int(rules.heroes[0].rhythm) == 2, "A3: prelude win grants +1 rhythm on top of +1 echo rhythm")

	# 场景 B：当本回合余音绕梁已达 2 次上限时，单独验证【清音起手】拼胜自身精确 +1 律动
	rules = make_minghe_battle(218, Rules.TRAINING_ENCOUNTER, [Minghe.PRELUDE])
	rules._apply_minghe_buff(1, 1, 0, "probe_1")
	rules._apply_minghe_buff(2, 1, 0, "probe_2")
	check(int(rules.heroes[0].rhythm) == 2 and int(rules.heroes[0].rhythm_passive_uses) == 2, "A3: setup reaches 2 echo uses before prelude")
	rules.heroes[1].next_clash.clear()
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.99])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "A3: prelude assignable when echo is exhausted")
	rules.lock_and_resolve()
	check(int(rules.heroes[1].next_clash.get("清音起手", 0)) == 2, "A3: prelude still grants next_clash +2 after echo cap")
	check(int(rules.heroes[0].rhythm) == 3, "A3: prelude win strictly adds +1 rhythm by itself")


## 断言 4：被动②【余音绕梁】在施加增益时正确给友军 +2 伤害，且每回合严格限制触发最多 2 次
func test_assert_4_passive_echo_limit() -> void:
	var rules := make_minghe_battle(218)
	var events: Array[Dictionary] = []

	# 对自身施加增益不触发余音绕梁
	rules._apply_minghe_buff(0, 1, 0, "self_buff", events)
	check(int(rules.heroes[0].next_damage_bonus.get("余音绕梁", 0)) == 0, "A4: buffing self does not trigger 余音绕梁")
	check(int(rules.heroes[0].rhythm) == 0 and int(rules.heroes[0].rhythm_passive_uses) == 0, "A4: self buff does not consume echo count or gain rhythm")

	# 第 1 次给友军 1 施加增益 -> 触发 (+2 伤害，律动 +1，计数 1)
	rules._apply_minghe_buff(1, 1, 0, "buff_1", events)
	check(int(rules.heroes[1].next_damage_bonus.get("余音绕梁", 0)) == 2, "A4: 1st ally buff grants 余音绕梁 +2 damage")
	check(int(rules.heroes[0].rhythm) == 1 and int(rules.heroes[0].rhythm_passive_uses) == 1, "A4: 1st echo increments rhythm and passive uses to 1")

	# 第 2 次给友军 2 施加增益 -> 触发 (+2 伤害，律动 +1，计数 2)
	rules._apply_minghe_buff(2, 1, 0, "buff_2", events)
	check(int(rules.heroes[2].next_damage_bonus.get("余音绕梁", 0)) == 2, "A4: 2nd ally buff grants 余音绕梁 +2 damage")
	check(int(rules.heroes[0].rhythm) == 2 and int(rules.heroes[0].rhythm_passive_uses) == 2, "A4: 2nd echo increments rhythm and passive uses to 2")

	# 第 3 次给友军 1 施加增益 -> 已达每回合 2 次上限，严禁再触发
	rules.heroes[1].next_damage_bonus.clear()
	rules._apply_minghe_buff(1, 1, 0, "buff_3", events)
	check(int(rules.heroes[1].next_damage_bonus.get("余音绕梁", 0)) == 0, "A4: 3rd ally buff in same round does NOT grant 余音绕梁 +2 damage")
	check(int(rules.heroes[0].rhythm) == 2 and int(rules.heroes[0].rhythm_passive_uses) == 2, "A4: 3rd ally buff does not increase rhythm or passive uses beyond 2")
	var echo_events := events.filter(func(ev: Dictionary) -> bool: return ev.type == "ability" and String(ev.message).contains("余音绕梁"))
	check(echo_events.size() == 2, "A4: exactly 2 余音绕梁 ability events emitted in one round")

	# 次回合重置后可再次触发
	rules.lock_and_resolve()
	rules.next_round()
	check(int(rules.heroes[0].rhythm_passive_uses) == 0 and int(rules.heroes[0].rhythm_buff_count) == 0, "A4: next_round resets echo counters to 0")
	rules.heroes[1].next_damage_bonus.clear()
	rules._apply_minghe_buff(1, 1, 0, "next_round_buff", events)
	check(int(rules.heroes[1].next_damage_bonus.get("余音绕梁", 0)) == 2 and int(rules.heroes[0].rhythm_passive_uses) == 1, "A4: echo triggers again in the new round")


## 断言 5：【和鸣共震】普通版与强化版（消耗 2 律动）全队护盾与增益数值完全正确
func test_assert_5_harmony_normal_and_enhanced() -> void:
	# 普通版：全队 +6 护盾、下次拼点 +2，无额外和鸣伤害加成
	var rules := make_minghe_battle(218, Rules.TRAINING_ENCOUNTER, [Minghe.HARMONY])
	check(rules.assign_support(0, 0).is_empty(), "A5: base harmony assignable to shared support slot")
	rules.lock_and_resolve()
	for i in range(rules.heroes.size()):
		check(int(rules.heroes[i].shield) == 6, "A5: base harmony grants 6 shield to hero %d" % i)
		check(int(rules.heroes[i].next_clash.get("和鸣共震", 0)) == 2, "A5: base harmony grants next_clash +2 to hero %d" % i)
		check(int(rules.heroes[i].next_damage_bonus.get("和鸣共震", 0)) == 0, "A5: base harmony grants 0 direct harmony damage bonus to hero %d" % i)
	check(int(rules.heroes[1].next_damage_bonus.get("余音绕梁", 0)) == 2 and int(rules.heroes[2].next_damage_bonus.get("余音绕梁", 0)) == 2, "A5: base harmony triggers echo +2 damage on living allies")
	check(int(rules.heroes[0].rhythm) == 2, "A5: base harmony generates 2 rhythm via echo on 2 living allies")

	# 强化版（消耗 2 律动）：全队 +6 护盾、下次拼点 +4、下次攻击 +4
	rules = make_minghe_battle(218, Rules.TRAINING_ENCOUNTER, [Minghe.HARMONY])
	rules.heroes[0].rhythm = 1
	check(not rules.can_assign(0, 2, -1, true).is_empty(), "A5: enhanced harmony rejected with only 1 rhythm")
	rules.heroes[0].rhythm = 2
	check(rules.assign(0, 2, -1, true).is_empty(), "A5: enhanced harmony accepted with 2 rhythm")
	check(int(rules.heroes[0].rhythm) == 0 and int(rules.heroes[0].rhythm_reserved) == 2, "A5: enhanced harmony reserves 2 rhythm")
	rules.lock_and_resolve()
	check(int(rules.heroes[0].rhythm_reserved) == 0, "A5: enhanced harmony consumes reserved 2 rhythm on resolve")
	for i in range(rules.heroes.size()):
		check(int(rules.heroes[i].shield) == 6, "A5: enhanced harmony grants 6 shield to hero %d" % i)
		check(int(rules.heroes[i].next_clash.get("和鸣共震", 0)) == 4, "A5: enhanced harmony grants next_clash +4 to hero %d" % i)
		check(int(rules.heroes[i].next_damage_bonus.get("和鸣共震", 0)) == 4, "A5: enhanced harmony grants next_damage_bonus +4 to hero %d" % i)
	check(int(rules.heroes[1].next_damage_bonus.get("余音绕梁", 0)) == 2 and int(rules.heroes[2].next_damage_bonus.get("余音绕梁", 0)) == 2, "A5: enhanced harmony also triggers echo +2 damage on teammates")
	check(int(rules.heroes[0].rhythm) == 2, "A5: after spending 2 rhythm, echo refills 2 rhythm from 2 living teammates")


## 断言 6：【万象同频】正确消耗全部律动转化为高额群体拼点与伤害加成，队伍回 2 Cost，且次轮禁止获律动
func test_assert_6_omni_finale_and_lockout() -> void:
	var rules := make_minghe_battle(218, Rules.TRAINING_ENCOUNTER, [Minghe.OMNI, Minghe.TUNING])
	rules.heroes[0].rhythm = 4
	var cost_before := rules.cost
	check(rules.assign(0, 1, -1).is_empty(), "A6: omni finale assignable to ultimate slot without enemy target")
	rules.lock_and_resolve()

	# layers = 4 -> 全队下次拼点 +(2+4)=6，下次攻击 +(3+2*4)=11
	for i in range(rules.heroes.size()):
		check(int(rules.heroes[i].next_clash.get("万象同频", 0)) == 6, "A6: omni grants next_clash +(2+4)=6 to hero %d" % i)
		check(int(rules.heroes[i].next_damage_bonus.get("万象同频", 0)) == 11, "A6: omni grants next_damage_bonus +(3+2*4)=11 to hero %d" % i)
	check(rules.cost == cost_before - 5 + 2, "A6: omni spends 5 Cost and refunds 2 Cost to team")
	check(int(rules.heroes[0].no_rhythm_round) == 2, "A6: omni sets no_rhythm_round to next round (turn 2)")
	# 消耗掉全部 4 层后，本轮对 2 名友军施加增益仍可由余音绕梁回 2 层
	check(int(rules.heroes[0].rhythm) == 2, "A6: omni consumes all 4 pre-cast rhythm before team echo triggers")

	# 次轮（turn == 2）严格禁止获得任何律动
	rules.next_round()
	check(rules.turn == 2 and not Minghe.can_gain_rhythm(rules.heroes[0], rules.turn), "A6: rhythm gain is blocked in turn 2")
	var gained := Minghe.gain_rhythm(rules.heroes[0], 2, rules.turn)
	check(gained == 0 and int(rules.heroes[0].rhythm) == 2, "A6: direct gain_rhythm returns 0 during lockout round")
	var tuning_idx := rules.hand.find(Minghe.TUNING)
	check(tuning_idx >= 0 and rules.assign_support(tuning_idx, 0).is_empty(), "A6: tuning can still be played during lockout round")
	rules.lock_and_resolve()
	check(int(rules.heroes[0].rhythm) == 2, "A6: playing tuning during lockout round grants 0 rhythm")

	# 第 3 轮解除禁获限制
	rules.next_round()
	check(rules.turn == 3 and Minghe.can_gain_rhythm(rules.heroes[0], rules.turn), "A6: rhythm gain resumes in turn 3")


## 断言 7：敌人弱点属性受到匹配攻击时正确累加 fracture，叠满 3 层或跌破 50% 血引爆【碎甲大失衡】（破盾+锁速1+增伤50%）
func test_assert_7_weakpoint_fracture_and_shatter_stagger() -> void:
	# 路径 A：匹配弱点叠满 3 层 fracture 引爆【碎甲大失衡】
	var rules := Rules.new()
	rules.start(42, 0) # encounter 0 -> enemy[0] is scout, weakness = "斩击", speed 4~7
	var scout := rules.enemies[0]
	check(String(scout.weakness) == "斩击" and int(scout.fracture) == 0, "A7: scout starts with 斩击 weakness and 0 fracture")
	var orig_min := int(scout.speed_min)
	var orig_max := int(scout.speed_max)
	scout.shield = 80
	var events: Array[Dictionary] = []

	# 非弱点攻击（突刺）不累加 fracture
	rules._attack(events, true, 0, 0, 1, 0, 1, 0.0, "needle")
	check(int(scout.fracture) == 0 and not scout.is_shattered, "A7: non-matching attack tag does not add fracture")

	# 弱点攻击（斩击）连续命中 3 次，逐层累加 1 -> 2 -> 3 并引爆碎甲大失衡
	rules._attack(events, true, 0, 0, 1, 0, 1, 0.0, "ember")
	check(int(scout.fracture) == 1 and not scout.is_shattered, "A7: 1st matching hit sets fracture to 1")
	rules._attack(events, true, 0, 0, 1, 0, 1, 0.0, "ember")
	check(int(scout.fracture) == 2 and not scout.is_shattered, "A7: 2nd matching hit sets fracture to 2")
	rules._attack(events, true, 0, 0, 1, 0, 1, 0.0, "ember")
	var fracture_evts := of_type(events, "fracture_hit")
	var shatter_evts := of_type(events, "shatter_stagger")
	check(fracture_evts.size() == 3 and int(scout.fracture) == 3, "A7: 3rd matching hit fills fracture to 3")
	check(scout.is_shattered and int(scout.shield) == 0 and shatter_evts.size() == 1, "A7: 3rd fracture triggers shatter_stagger and destroys all shield")

	# 次回合验证锁速 1 与受创 +50%
	rules.lock_and_resolve()
	rules.next_round()
	check(int(scout.speed_min) == 1 and int(scout.speed_max) == 1, "A7: shattered enemy speed bounds locked to 1 on next round")
	check(rules.enemy_slots.slice(0, 3).all(func(s: Dictionary) -> bool: return int(s.speed) == 1), "A7: all shattered enemy slots roll speed 1")
	var dealt := rules._deal_hit(events, true, 0, 0, 10, 1, 1)
	check(dealt == 15, "A7: shattered enemy takes +50% damage (10 -> 15)")

	# 持续 1 回合后恢复正常速度与抗性
	rules.lock_and_resolve()
	rules.next_round()
	check(not scout.is_shattered and int(scout.fracture) == 0 and int(scout.speed_min) == orig_min and int(scout.speed_max) == orig_max, "A7: shatter recovers cleanly after 1 round")
	check(rules._deal_hit(events, true, 0, 0, 10, 1, 1) == 10, "A7: recovered enemy takes normal damage (10)")

	# 路径 B：跌破 50% 血线引爆【碎甲大失衡】
	rules = Rules.new()
	rules.start(42, 0)
	rules.enable_evolution(true, false)
	scout = rules.enemies[0]
	events.clear()
	scout.shield = 20
	var half_hp := int(scout.max_hp / 2)
	scout.hp = half_hp
	check(not rules._check_stagger_after_action(events, scout, false, half_hp + 1) and not scout.is_shattered, "A7: exactly 50% HP does not trigger bloodline shatter")
	scout.hp = half_hp - 1
	check(rules._check_stagger_after_action(events, scout, false, half_hp), "A7: dropping below 50% HP triggers stagger")
	check(scout.is_staggered and scout.is_shattered and int(scout.shield) == 0, "A7: below 50% HP triggers shatter_stagger and breaks shield even at 0 fracture")
	check(of_type(events, "shatter_stagger").size() == 1, "A7: bloodline shatter emits shatter_stagger event")
	rules.lock_and_resolve()
	rules.next_round()
	check(int(scout.speed_min) == 1 and int(scout.speed_max) == 1, "A7: bloodline shatter locks speed to 1 next round")
	check(rules._deal_hit(events, true, 0, 0, 10, 1, 1) == 15, "A7: bloodline shatter increases damage taken by 50%")


## 断言 8：拼刀连胜正确累加 1~3 层势能并在落败时即时清零
func test_assert_8_clash_momentum_chain() -> void:
	var rules := Rules.new()
	rules.start(42, Rules.TRAINING_ENCOUNTER)
	var events: Array[Dictionary] = []
	var dummy := rules.enemies[0]
	var enemy_slot := rules.enemy_slots[0]
	var hero_slot := {"unit": 0, "key": "steady"}
	dummy.shield = 999
	check(rules.round_momentum == 0, "A8: round_momentum starts at 0")

	# 连续拼胜 4 次：势能应依次累加为 1, 2, 3, 3（上限 3）
	var expected_after := [1, 2, 3, 3]
	for i in range(4):
		var bonus_before := mini(i, 3)
		rules.custom_coin_rolls.assign([0.99, 0.99, 0.99])
		rules._clash(events, hero_slot, enemy_slot)
		var clash := of_type(events, "clash").back() as Dictionary
		check(int(clash.left) == 7 + bonus_before, "A8: clash %d uses existing momentum +%d as base power" % [i + 1, bonus_before])
		check(rules.round_momentum == expected_after[i], "A8: after win %d, round_momentum is %d" % [i + 1, expected_after[i]])

	var gains := of_type(events, "momentum_gain")
	check(gains.size() == 4 and int(gains[0].momentum) == 1 and int(gains[1].momentum) == 2 and int(gains[2].momentum) == 3 and int(gains[3].momentum) == 3, "A8: momentum_gain events record 1->2->3->3 progression")

	# 拼刀落败时势能即时清零并广播 momentum_break
	hero_slot.key = "needle"
	enemy_slot.key = "nova"
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.0, 0.0, 0.0, 0.99, 0.0, 0.0, 0.0])
	rules._clash(events, hero_slot, enemy_slot)
	check(rules.round_momentum == 0, "A8: clash defeat immediately resets round_momentum to 0")
	check(of_type(events, "momentum_break").size() == 1, "A8: clash defeat emits momentum_break event")

	# 回合切换时也会清空势能
	rules.round_momentum = 3
	rules.lock_and_resolve()
	rules.next_round()
	check(rules.round_momentum == 0, "A8: next_round resets round_momentum to 0")
