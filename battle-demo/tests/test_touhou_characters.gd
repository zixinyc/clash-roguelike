extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const BattleScene = preload("res://main.tscn")

class Wins extends "res://scripts/battle_rules.gd":
	func _roll(base: int, _power: int, _coins: int, chance: float) -> Dictionary:
		return {"value": maxi(0, base) + (100 if chance > 0.5 else 0), "heads": 0}

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func quiet(b: DemoBattleRules, attack_id: int = -1, target: int = 0) -> void:
	for slot in b.enemy_slots:
		slot.active = slot.id == attack_id
		if slot.active:
			slot.target = target
			slot.key = "needle"

func assign(b: DemoBattleRules, key: String, slot: int, target: int) -> bool:
	return b.assign(b.hand.find(key), slot, target).is_empty()

func event_damage(events: Array[Dictionary], target: int) -> int:
	var damage := 0
	for event in events:
		if event.type == "strike" and event.target == target:
			damage += event.damage
	return damage

func _test_sakuya() -> void:
	var b := Wins.new()
	b.start(73129, 0, true)
	check(b.heroes[1].hp == 40 and b.heroes[2].hp == 50 and b.hand.size() == 18, "test roster and dedicated cards")
	check(not assign(b, "murder_doll", 0, 0), "Sakuya card is exclusive")
	quiet(b, 0)
	b.hero_slots[3].speed = 5
	b.enemy_slots[0].speed = 7
	check(assign(b, "murder_doll", 3, 0), "place Murder Doll")
	var events := b.lock_and_resolve()
	check(events.any(func(e: Dictionary) -> bool: return e.type == "intercept" and e.hero == 1), "Sakuya intercepts a faster attack")
	check(event_damage(events, 0) == 13, "Murder Doll deals 8 plus the opening damage bonus")

	b.start(73129, 0, true)
	quiet(b)
	check(assign(b, "stopwatch", 4, 0) and assign(b, "private_square", 5, 0), "utility skills can share a round")
	events = b.lock_and_resolve()
	check(not events.any(func(e: Dictionary) -> bool: return e.type in ["strike", "guard"]), "utility skills have no damage or shield")
	b.next_round()
	check(b.hero_slots[3].speed >= 8 and b.hero_slots[3].speed <= 12, "Private Square speed starts next round")
	check(Rules.Sakuya.damage_bonus(b.heroes[1], 2) == 10, "Private Square stacks with Silver Knife for one round")
	check(b.enemy_slots[3].speed in [1, 2] and Rules.Sakuya.stopwatch_bonus(b.heroes[1], 9, 1) == 3, "Stopwatch slows to at least 1 and caps bonus at 3")
	quiet(b)
	check(assign(b, "the_world", 4, 3), "The World can be released")
	b.lock_and_resolve()
	b.next_round()
	check(b.heroes[1].watch_active and not b.heroes[1].space_active, "Stopwatch lasts two rounds and Private Square one")
	check(Rules.Sakuya.damage_bonus(b.heroes[1], 3) == 2, "Silver Knife damage on third round")
	check(b.enemy_slots.all(func(slot: Dictionary) -> bool: return not slot.active), "no enemy attacks or defenses during The World")
	check(not assign(b, "cleave", 0, 0) and not assign(b, "yin_yang_orb", 6, 0), "stopped teammates cannot plan actions")
	check(assign(b, "murder_doll", 3, 0) and assign(b, "murder_doll", 4, 0), "two flexible Sakuya slots and can repeat")
	check(not assign(b, "steady", 5, 3), "third action rejected")
	events = b.lock_and_resolve()
	check(b.plays == 2 and not events.any(func(e: Dictionary) -> bool: return e.type == "clash"), "The World attacks cannot be clashed")
	b.next_round()
	check(not b.heroes[1].watch_active and Rules.Sakuya.damage_bonus(b.heroes[1], 4) == 0, "round buffs expire")
	check(not assign(b, "the_world", 4, 0) and not b.hero_slots[3].get("flexible", false), "The World stays spent and slots revert")

func _test_reimu() -> void:
	var b := Wins.new()
	b.start(73129, 0, true)
	quiet(b)
	check(assign(b, "yin_yang_orb", 6, 3), "place Yin-Yang Orb")
	var events := b.lock_and_resolve()
	check(event_damage(events, 1) == 7 and b.enemies[1].exorcism == 1, "Orb damage and single mark")
	b.next_round()
	for round_index in 2:
		quiet(b)
		check(assign(b, "fantasy_seal", 6, 0), "place Fantasy Seal")
		events = b.lock_and_resolve()
		check(event_damage(events, 0) == 11 and b.enemies[0].exorcism == (2 if round_index == 0 else 0), "Fantasy Seal damage, mark cap and detonation")
		b.next_round()
	check(b.enemies[0].exorcism_active and b.enemies[1].exorcism == 1, "detonation activates next round and marks are separate")
	b.enemies[0].gensokyo_native = true
	check(Rules.Reimu.clash_bonus(b.enemies[0]) == 1 and Rules.Reimu.clash_bonus(b.enemies[1]) == 0, "native foe trait gates Reimu's passive")
	var hits: Array[Dictionary] = []
	b._attack(hits, false, 0, 2, 7, 0, 1, 0.5)
	check(event_damage(hits, 2) == 3 and Rules.Reimu.enemy_clash_penalty(b.enemies[0]) == 3, "detonation halves damage and penalizes clash by 3")
	quiet(b, 3, 2)
	check(assign(b, "demon_seal", 8, 3), "Seal of Demons uses targeted defense")
	events = b.lock_and_resolve()
	check(not events.any(func(e: Dictionary) -> bool: return e.type in ["strike", "guard"]), "winning defense deals no damage and adds no shield")
	b.next_round()
	check(b.enemies.all(func(enemy: Dictionary) -> bool: return Rules.Reimu.enemy_clash_penalty(enemy) == 2), "defense applies to the target and left neighbor, exorcism expires")

func _test_dream() -> void:
	var b := Wins.new()
	b.start(73129, 0, true)
	quiet(b)
	check(not assign(b, "fantasy_nature", 7, 0), "Fantasy Nature requires an opposing action")
	quiet(b, 0, 2)
	check(assign(b, "fantasy_nature", 7, 0), "place Fantasy Nature")
	var events := b.lock_and_resolve()
	check(b.heroes[2].dream_orbs == 1 and b.heroes[2].dream_due == 4 and event_damage(events, 0) == 0, "initial win arms the delayed attack without damage")
	b.next_round()
	for target in [0, 3]:
		quiet(b, target, 2)
		check(not assign(b, "fantasy_nature", 7, target), "cannot recast while charging")
		check(assign(b, "yin_yang_orb" if target == 0 else "fantasy_seal", 6, target), "place a charge-building attack")
		b.lock_and_resolve()
		b.next_round()
	check(b.heroes[2].dream_orbs == 3, "clash wins charge the delayed attack to three layers")
	quiet(b)
	events = b.lock_and_resolve()
	check(event_damage(events, 0) == 15 and event_damage(events, 1) == 30 and b.heroes[2].hp == 0, "delayed damage uses each target's own marks, then Reimu leaves")

	b.start(73129, 0, true)
	quiet(b, 0, 2)
	assign(b, "fantasy_nature", 7, 0)
	b.lock_and_resolve()
	b.next_round()
	quiet(b, 0, 2)
	b.heroes[2].hp = 1
	events = b.lock_and_resolve()
	check(b.heroes[2].hp == 0 and b.heroes[2].dream_due == 0, "death cancels the delayed attack")

func _run() -> void:
	_test_sakuya()
	_test_reimu()
	_test_dream()
	var scene := BattleScene.instantiate()
	root.add_child(scene)
	scene.sound.enabled = false
	scene.team_button.pressed.emit()
	scene.hand_view.hero_buttons[2].pressed.emit()
	check(scene.battle.touhou_team and scene.hand_view.visible_indices.size() == 4, "single-battle UI exposes Reimu's cards")
	scene._select_card(scene.battle.hand.find("demon_seal"))
	check(scene.selected_slot == 8, "selecting targeted defense switches to the defense slot")
	scene.team_button.pressed.emit()
	check(scene.battle.hand.size() == 16 and scene.hand_view.cards.size() == 16, "switching back restores original hand and view")
	scene.queue_free()
	await process_frame
	print("TOUHOU_CHARACTERS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
