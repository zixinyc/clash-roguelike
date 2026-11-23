extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Minghe = Rules.Minghe
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func battle(deck: Variant = null) -> DemoBattleRules:
	var rules := Rules.new()
	rules.start(218, Rules.TRAINING_ENCOUNTER, false, false, [Rules.MINGHE_ID, Rules.ASH_ID, Rules.WEAVER_ID], deck)
	return rules

func _initialize() -> void:
	var rules := battle()
	check(rules.hand.filter(func(k: String) -> bool: return k in Minghe.CARDS).size() == 8, "minghe has eight cards")
	check(rules.hand.has(Minghe.PRELUDE) and rules.hand.has(Minghe.HARMONY) and rules.hand.has(Minghe.OMNI), "the requested keys are offered in the default hand")
	check(Rules.card_owner(Minghe.CONCERTO) == Rules.MINGHE_ID and not Rules.available_cards([Rules.ASH_ID]).has(Minghe.CONCERTO), "cards require minghe")
	var fastest := rules._minghe_fastest(0)
	check(rules.minghe_slot == 0 and fastest > 0 and rules.heroes[fastest].next_clash.get("先声夺势", 0) == 1, "opening passive targets fastest teammate")
	var idx := rules.hand.find(Minghe.CONCERTO)
	check(not rules.assign_support(idx, 0, -1, 0).is_empty(), "minghe cannot choose self for single ally buffs")
	check(rules.assign_support(idx, 0, -1, 2).is_empty(), "shared support accepts a distinct recipient")
	var events := rules.lock_and_resolve()
	check(events[0].type == "ability" and events[0].message.contains("先声夺势"), "the next timeline broadcasts the opening passive before support")
	check(rules.heroes[2].shield == 8, "shared support resolves its own shield")
	check(rules.heroes[2].next_clash.get("清商协奏", 0) == 3, "shared support preserves explicit target")
	check(rules.heroes[0].rhythm == 1 and rules.heroes[2].next_damage_bonus.get("余音绕梁", 0) == 2, "ally buff triggers rhythm and damage passive")
	check(events.any(func(event: Dictionary) -> bool: return event.type == "ability" and event.message.contains("余音绕梁")), "the echo broadcasts its effect")
	rules.next_round()
	check(rules.heroes[2].shield == 0, "ordinary support shield expires")
	check(rules.heroes[0].rhythm_buff_count == 0 and rules.heroes[0].rhythm_passive_uses == 0, "the next round resets the echo counters before planning")

	rules = battle()
	rules.heroes[0].rhythm = 2
	idx = rules.hand.find(Minghe.CONCERTO)
	check(rules.assign(idx, 2, -1, true).is_empty(), "concerto enhancement is available")
	check(rules.heroes[0].rhythm == 1, "concerto reserves one rhythm")
	rules.cancel(2)
	check(rules.heroes[0].rhythm == 2, "cancel restores reserved rhythm")
	idx = rules.hand.find(Minghe.HARMONY)
	rules.heroes[0].rhythm = 1
	check(not rules.can_assign(idx, 2, -1, true).is_empty(), "harmony enhancement requires two rhythm")
	rules.heroes[0].rhythm = 2
	check(rules.assign(idx, 2, -1, true).is_empty() and rules.heroes[0].rhythm == 0, "resonance reserves two rhythm")
	check(rules.assign(idx, 2, -1, true).is_empty() and rules.heroes[0].rhythm == 0, "replacing an enhanced reservation spends its cost only once")
	rules.cancel(2)
	rules.cancel(2)
	check(rules.heroes[0].rhythm == 2, "cancel refunds the matching reservation only once")
	check(rules.assign(idx, 2, -1, true).is_empty() and rules.heroes[0].rhythm == 0, "resonance reserves two rhythm")
	rules.lock_and_resolve()
	check(rules.heroes[0].shield == 6 and rules.heroes[1].shield == 6 and rules.heroes[2].shield == 6, "resonance shields every living member")
	check(rules.heroes[0].rhythm == 2 and rules.heroes[0].rhythm_reserved == 0, "passive counts only teammate buffs and spends the reservation")
	check(rules.heroes[1].next_clash.get("和鸣共震", 0) == 4 and rules.heroes[1].next_damage_bonus.get("和鸣共震", 0) == 4 and rules.heroes[1].next_damage_bonus.get("余音绕梁", 0) == 2, "enhanced resonance and passive grant distinct attack bonuses")
	var hits: Array[Dictionary] = []
	rules.enemies[0].shield = 20
	check(rules._deal_hit(hits, true, 1, 0, 4, 1, 1, false, "ember") == 0 and rules.enemies[0].shield == 10, "one-shot ally damage still hits shielding")
	check(rules._deal_hit(hits, true, 1, 0, 4, 1, 1, false, "ember") == 0 and rules.enemies[0].shield == 6, "next-attack damage is consumed once")
	rules.next_round()
	check(rules.heroes[0].rhythm == 2 and rules.heroes[0].enhanced_slot == -1, "the next round clears the enhancement marker without refunding a played card")

	rules = battle([Minghe.OMNI, Minghe.TUNING])
	rules.heroes[0].rhythm = 3
	idx = rules.hand.find(Minghe.OMNI)
	check(rules.assign(idx, 1, -1).is_empty(), "finale can be assigned without opposing target")
	check(not rules.assign_support(idx, 0).is_empty(), "finale is an ultimate and stays in its regular slot")
	rules.lock_and_resolve()
	check(rules.heroes[0].rhythm == 2 and rules.heroes[0].no_rhythm_round == 2, "finale spends old rhythm before earning echo rhythm and blocks next round")
	check(rules.heroes[0].next_damage_bonus.get("万象同频", 0) == 9 and rules.heroes[1].next_damage_bonus.get("万象同频", 0) == 9 and rules.heroes[1].next_clash.get("万象同频", 0) == 5, "finale uses the pre-cast rhythm count")
	check(rules.cost == Rules.START_COST - 5 + 2, "finale returns two Cost")
	rules.next_round()
	check(rules.assign_support(rules.hand.find(Minghe.TUNING), 0).is_empty(), "tuning can be played while rhythm gain is blocked")
	rules.lock_and_resolve()
	check(rules.heroes[0].rhythm == 2, "blocked rhythm gain is ignored")
	test_prelude_and_infusion()
	test_interrupted_harmony()
	test_legacy_card_keys()
	print("MINGHE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func test_prelude_and_infusion() -> void:
	var rules := battle([Minghe.PRELUDE, Minghe.INFUSION, Minghe.HARMONY])
	check(rules.hand.has(Minghe.PRELUDE) and rules.hand.has(Minghe.HARMONY), "requested keys work in explicitly supplied decks")
	rules.heroes[0].rhythm = 2
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.99])
	check(rules.assign(rules.hand.find(Minghe.PRELUDE), 2, 0, false, false, 1).is_empty(), "prelude can clash and support a chosen teammate")
	var events := rules.lock_and_resolve()
	var clashes := events.filter(func(event: Dictionary) -> bool: return event.type == "clash")
	check(not clashes.is_empty() and clashes[0].left == 12, "minghe's current rhythm adds to base clash power")
	check(rules.heroes[1].next_clash.get("清音起手", 0) == 2 and rules.heroes[0].rhythm == 4, "prelude gains its own rhythm in addition to echo")

	rules = battle([Minghe.PRELUDE])
	rules._apply_minghe_buff(1, 1, 0, "test_a")
	rules._apply_minghe_buff(2, 1, 0, "test_b")
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.99])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "prelude remains playable after both echo uses")
	rules.lock_and_resolve()
	check(rules.heroes[0].rhythm == 3 and rules.heroes[0].rhythm_passive_uses == 2, "prelude earns its own rhythm after reaching the echo limit")

	rules = battle([Minghe.PRELUDE])
	rules.enemy_slots[0].key = "nova"
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.0, 0.0, 0.0, 0.99, 0.0, 0.0, 0.0])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "prelude can lose a clash")
	rules.lock_and_resolve()
	check(rules.heroes[1].next_clash.get("清音起手", 0) == 1 and rules.heroes[0].rhythm == 1, "prelude loses with the smaller buff and only echo rhythm")

	rules = battle([Minghe.INFUSION, "steady"])
	var target := 1
	check(rules.assign_support(0, 0, -1, target).is_empty(), "infusion can be placed in phase zero")
	check(rules.assign(1, 3, 0).is_empty(), "the infusion recipient attacks on the same timeline")
	events = rules.lock_and_resolve()
	var strikes := events.filter(func(event: Dictionary) -> bool: return event.type == "strike" and event.allied)
	check(not strikes.is_empty() and strikes[0].get("next_damage_bonus", 0) == 7, "phase zero applies infusion and echo to the recipient's first hit")
	check(rules.cost == Rules.START_COST - 2 - 2 + 1 + 1, "phase-zero infusion returns one Cost and leaves clash rewards independent")

	rules = battle([Minghe.INFUSION])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "infusion can also clash")
	rules.lock_and_resolve()
	check(rules.heroes[1].next_damage_bonus.get("灵韵灌注", 0) == 5 and rules.cost == Rules.START_COST - 2 + 1 + 2, "infusion keeps its fixed damage bonus and refunds two Cost on a win")

	rules = battle([Minghe.INFUSION])
	rules.enemy_slots[0].key = "nova"
	rules.custom_coin_rolls.assign([0.99, 0.99, 0.0, 0.0, 0.0, 0.99, 0.0, 0.0, 0.0])
	check(rules.assign(0, 2, 0, false, false, 1).is_empty(), "infusion can resolve after losing a clash")
	rules.lock_and_resolve()
	check(rules.heroes[1].next_damage_bonus.get("灵韵灌注", 0) == 5 and rules.cost == Rules.START_COST - 2 + 1 + 1, "infusion returns one Cost in addition to the normal loss refund")

	rules = battle([Minghe.HARMONY])
	rules.heroes[2].hp = 0
	check(rules.assign_support(0, 0).is_empty(), "base harmony can resolve in phase zero")
	rules.lock_and_resolve()
	check(rules.heroes[0].next_clash.get("和鸣共震", 0) == 2 and rules.heroes[1].shield == 6 and rules.heroes[2].shield == 0, "base harmony buffs and shields living allies only")

func test_interrupted_harmony() -> void:
	var rules := battle([Minghe.HARMONY])
	rules.start(218, 0, false, false, [Rules.MINGHE_ID, Rules.ASH_ID, Rules.WEAVER_ID], [Minghe.HARMONY], false, [], [], {"stagger": true, "party_hp": [24, 48, 46]})
	rules.heroes[0].rhythm = 2
	rules.hero_slots[2].speed = 1
	rules.enemy_slots[0].speed = 10
	rules.enemy_slots[0].target = 0
	for slot in rules.enemy_slots:
		slot.active = slot.id == 0
	check(rules.assign(0, 2, -1, true).is_empty(), "harmony can reserve rhythm before an enemy interruption")
	rules.lock_and_resolve()
	check(rules.hero_slots[2].get("cancelled", false) and rules.heroes[0].rhythm == 2 and rules.heroes[0].rhythm_reserved == 0, "stagger refunds harmony's unspent rhythm")
	check(rules.heroes[1].shield == 0, "interrupted harmony does not apply its team shield")

func test_legacy_card_keys() -> void:
	var rules := battle([Minghe.LEGACY_HARMONY])
	check(rules.hand == [Minghe.LEGACY_HARMONY] and rules.assign_support(0, 0).is_empty(), "existing decks retain a playable legacy harmony instance")
	rules.lock_and_resolve()
	check(rules.heroes[1].shield == 6 and rules.heroes[1].next_clash.get("和鸣共震", 0) == 2, "legacy harmony uses the same effects")
	check(CardPool.count_copies([Minghe.LEGACY_HARMONY], Minghe.HARMONY) == 1 and CardPool.rarity_of(Minghe.LEGACY_HARMONY) == CardPool.rarity_of(Minghe.HARMONY), "legacy and current keys share card rarity and copy limits")
