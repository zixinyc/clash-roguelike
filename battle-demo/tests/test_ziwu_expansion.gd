extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const ZiWu = Rules.ZiWu
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var hero := ZiWu.create_unit()
	ZiWu.prepare_round(hero, 1, 2, true)
	var afterimage := ZiWu.begin_clash(hero, {"key": ZiWu.AFTERIMAGE}, ZiWu.AFTERIMAGE_CARD)
	check(afterimage.bonus == 6, "solo afterimage adds two points above the missing-ally bonus")
	check(ZiWu.finish_clash(hero, ZiWu.AFTERIMAGE, 0, afterimage, 1).cost_refund == 1 and hero.insulation == 1, "afterimage wins restore one Cost and Insulation")
	check(ZiWu.finish_clash(hero, ZiWu.AFTERIMAGE, 0, afterimage, 1).cost_refund == 0, "afterimage refund is limited to once per turn")
	ZiWu.reserve_enhancement(hero, 0, ZiWu.LONE_BREAK)
	check(hero.insulation == 0 and not ZiWu.enhancement_error(hero, 0, ZiWu.LONE_INTERCEPT).is_empty(), "replacement cannot overspend the reserved insulation")
	ZiWu.unreserve_enhancement(hero, 0)
	check(hero.insulation == 1, "cancel refunds the exact one-layer price")
	var lone_break := ZiWu.finish_clash(hero, ZiWu.LONE_BREAK, 0, {"enhanced": true}, 1)
	check(lone_break.shield == 5 and lone_break.extra_damage == 6 and lone_break.weaken == 2, "enhanced solo Lone Break combines its effects")
	var frost := ZiWu.finish_clash(hero, ZiWu.FROST_TURN, 0, {}, 1)
	check(frost.shield == 7 and hero.shield_until[2] == 7, "solo Frost Turn shield persists through next round")
	var chase := ZiWu.begin_clash(hero, {"key": ZiWu.SHADOW_CHASE}, ZiWu.SHADOW_CHASE_CARD, {"hp": 10, "max_hp": 20}, true)
	check(chase.bonus == 7 and ZiWu.finish_clash(hero, ZiWu.SHADOW_CHASE, 0, chase, 1).extra_damage == 6, "Shadow Chase uses earlier deaths and half-HP threshold")

	var rules := Rules.new()
	rules.start(37, Rules.TRAINING_ENCOUNTER, false, false, [Rules.ZIWU_ID, Rules.ASH_ID])
	var card := rules.hand.find(ZiWu.BLOOD_PACT)
	check(card >= 0, "Blood Pact is registered in the playable hand")
	rules.heroes[1].shield = 4
	rules.heroes[1].shield_until[2] = 4
	check(rules.assign(card, 0, 1, false, true).is_empty(), "Blood Pact targets a living ally")
	var before_hp := int(rules.heroes[1].hp)
	var events := rules.lock_and_resolve()
	check(rules.heroes[1].hp == before_hp - 2 and rules.heroes[1].shield == 0 and rules.heroes[1].shield_until.is_empty(), "Blood Pact consumes carried shield before HP")
	check(rules.heroes[0].shield == 6 and rules.heroes[0].insulation == 1, "Blood Pact grants six shield and one insulation")
	check(events.any(func(event: Dictionary) -> bool: return event.type == "strike" and event.get("friendly", false) and event.source == 0 and event.target == 1), "strike reports the two ally indexes")
	rules.next_round()
	rules.heroes[1].hp = 6
	rules.hero_slots[0].speed = 11
	rules.hero_slots[6].speed = 7
	var chase_card := rules.hand.find(ZiWu.SHADOW_CHASE)
	check(rules.assign(rules.hand.find(ZiWu.BLOOD_PACT), 0, 1, false, true).is_empty() and rules.assign(chase_card, 6, 0).is_empty(), "sacrifice and chase can be queued in timeline order")
	var reserve := rules.reserved_cost()
	events = rules.lock_and_resolve()
	check(reserve == 5 and events.any(func(event: Dictionary) -> bool: return "影袭追命 · 本回合已有单位阵亡，返还 1 Cost" in event.get("message", "")), "Shadow Chase refunds one Cost after the earlier ally defeat")
	check(rules.heroes[1].hp == 0 and rules.heroes[0].insulation == 4, "lethal Blood Pact triggers the first ally defeat rewards")
	print("ZIWU_EXPANSION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
