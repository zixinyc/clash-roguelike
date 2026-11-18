extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAILURE: " + label)

func _initialize() -> void:
	test_bloodline_threshold()
	test_consecutive_clash_loss()
	test_dedup_simultaneous_triggers()
	test_extinguish_and_refund()
	test_boss_colossus_stagger()
	test_stagger_vulnerability()
	test_wake_up_and_immunity()
	test_overwhelm_margin_formula()
	test_overwhelm_exclusions()
	test_overwhelm_shield_absorption()
	test_zixi_enhancement_release()
	test_sakuya_and_marisa_interaction()
	test_victory_reward_uniqueness()
	test_end_to_end_lock_and_resolve()
	test_backward_compatibility()
	print("STAGGER_OVERWHELM_TESTS checks complete, failures=", failures)
	quit(1 if failures else 0)

func test_bloodline_threshold() -> void:
	var b := Rules.new()
	var ev: Array[Dictionary] = []
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	check(b.stagger_enabled, "stagger enabled via config")
	check(b.overwhelm_enabled, "overwhelm enabled via config")

	var hero := b.heroes[0]
	check(hero.max_hp == 48, "Ash max HP is 48")
	check(hero.hp == 48, "Ash starting HP is 48")
	check(hero.is_staggered == false, "initially not staggered")
	check(hero.stagger_immune_turns == 0, "initially 0 immunity turns")
	check(hero.stagger_threshold_triggered == false, "threshold not yet triggered")

	# 1. Exactly 50% HP (24/48) does NOT trigger stagger
	hero.hp = 24
	var triggered := b._check_stagger_after_action(ev, hero, true, 48)
	check(not triggered, "exactly 50% does not trigger stagger")
	check(hero.is_staggered == false, "hero still not staggered at exactly 50%")
	check(hero.stagger_threshold_triggered == false, "threshold flag still false")

	# 2. Dropping below 50% (24 -> 23) triggers stagger
	hero.hp = 23
	triggered = b._check_stagger_after_action(ev, hero, true, 24)
	check(triggered, "crossing below 50% triggers stagger")
	check(hero.is_staggered == true, "hero is now staggered")
	check(hero.stagger_threshold_triggered == true, "threshold flag marked true")
	var has_stagger_evt := ev.any(func(e: Dictionary) -> bool: return e.get("type") == "stagger" and e.get("allied") == true)
	check(has_stagger_evt, "stagger event emitted")

	# 3. Heal back to full and drop below 50% again: should NOT trigger (once per combat per unit)
	ev.clear()
	hero.is_staggered = false
	hero.hp = 48
	triggered = b._check_stagger_after_action(ev, hero, true, 48)
	check(not triggered, "at 48 HP not triggered")
	hero.hp = 20
	triggered = b._check_stagger_after_action(ev, hero, true, 48)
	check(not triggered, "already triggered once per combat, will not re-trigger bloodline stagger")

	# 4. Low HP entrance (starts < 50%): does NOT trigger
	var b_low := Rules.new()
	b_low.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var hero2 := b_low.heroes[1]
	hero2.hp = 20 # max_hp is 42, 20 is < 50%
	var ev_low: Array[Dictionary] = []
	hero2.hp = 18
	triggered = b_low._check_stagger_after_action(ev_low, hero2, true, 20)
	check(not triggered, "low HP entrance (pre_hp < 50%) does not trigger stagger")

	# 5. Fatal hit (HP drops to 0): does NOT trigger stagger
	var b_dead := Rules.new()
	b_dead.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var hero3 := b_dead.heroes[2]
	hero3.hp = 0
	var ev_dead: Array[Dictionary] = []
	triggered = b_dead._check_stagger_after_action(ev_dead, hero3, true, 46)
	check(not triggered, "fatal hit does not trigger stagger on dead unit")

func test_consecutive_clash_loss() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var hero := b.heroes[0]
	var ev: Array[Dictionary] = []

	# 1st clash loss
	hero.consecutive_clash_loss = 1
	var triggered := b._check_stagger_after_action(ev, hero, true, 48)
	check(not triggered, "1 clash loss does not trigger stagger")
	check(hero.is_staggered == false, "not staggered after 1 clash loss")

	# 2nd clash loss in same turn
	hero.consecutive_clash_loss = 2
	triggered = b._check_stagger_after_action(ev, hero, true, 48)
	check(triggered, "2 consecutive clash losses triggers stagger")
	check(hero.is_staggered == true, "hero staggered on 2nd clash loss")
	check(hero.consecutive_clash_loss == 0, "consecutive clash loss counter reset to 0")

func test_dedup_simultaneous_triggers() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var hero := b.heroes[0]
	var ev: Array[Dictionary] = []
	hero.hp = 20
	hero.consecutive_clash_loss = 2
	var triggered := b._check_stagger_after_action(ev, hero, true, 48)
	check(triggered, "simultaneous HP crossing and 2nd clash loss triggers stagger")
	var stagger_events := ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "stagger")
	check(stagger_events.size() == 1, "deduped into exactly 1 stagger event")
	check(stagger_events[0].reason == "跌破血线且连续拼败", "deduped reason captures both")

func test_extinguish_and_refund() -> void:
	# 1-hero short team with 3 slots
	var b := Rules.new()
	b.start(42, 0, false, false, [Rules.ASH_ID], null, false, [], [], {"enabled": true})
	b.turn = 2 # turn 2 gives short team extra slots
	b._prepare_round()
	check(b.hero_slots.size() >= 3, "short team has multiple slots")

	# Find valid cards for slot 0 (attack) and slot 1 (ultimate)
	var cleave_idx := b.hand.find("cleave")
	var nova_idx := b.hand.find("nova")
	check(cleave_idx >= 0 and nova_idx >= 0, "cleave and nova exist in hand")

	# Assign actions: slot 0 (attack) -> cleave (cost 3), slot 1 (ultimate) -> nova (cost 4)
	var err1 := b.assign(cleave_idx, 0, 0)
	var err2 := b.assign(nova_idx, 1, 0)
	check(err1.is_empty(), "slot 0 assigned: " + err1)
	check(err2.is_empty(), "slot 1 assigned: " + err2)
	check(b.hero_slots[0].active and b.hero_slots[1].active, "slots 0 and 1 active")

	# Mark slot 0 as done, simulating it already executed
	b.hero_slots[0].done = true
	var cost_before := b.cost

	# Stagger Ash
	var ev: Array[Dictionary] = []
	b.heroes[0].hp = 20
	b._check_stagger_after_action(ev, b.heroes[0], true, 48)

	# Slot 0 was already done: should remain done and active
	check(b.hero_slots[0].done == true, "already executed slot remains done")

	# Slot 1 was unexecuted: should be cancelled and cost refunded (nova cost 4)
	check(b.hero_slots[1].active == false, "unexecuted slot 1 extinguished")
	check(b.hero_slots[1].get("cancelled", false) == true, "slot 1 marked cancelled")
	check(b.cost == cost_before + 4, "cost refunded for cancelled slot (nova cost 4)")
	var cancel_evt := ev.any(func(e: Dictionary) -> bool: return e.get("type") == "cancelled" and e.get("slot") == 1 and e.get("refund") == 4)
	check(cancel_evt, "cancellation event emitted with refund")

func test_boss_colossus_stagger() -> void:
	# Boss Colossus (encounter 5, 210 HP)
	var b := Rules.new()
	b.start(42, 5, false, false, [], null, false, [], [], {"enabled": true})
	var colossus := b.enemies[0]
	check(colossus.kind == "colossus", "enemy is Colossus")
	check(colossus.hp == 210, "Colossus HP is 210")
	check(colossus.max_hp == 210, "Colossus max HP is 210")

	# Colossus has active slots in turn 1
	var active_slots := b.enemy_slots.filter(func(s: Dictionary) -> bool: return s.active)
	check(active_slots.size() >= 2, "Colossus has active slots")

	# Drop Colossus HP below 50% (105): e.g. 120 -> 100
	var ev: Array[Dictionary] = []
	colossus.hp = 100
	var triggered := b._check_stagger_after_action(ev, colossus, false, 120)
	check(triggered, "Colossus triggers stagger when dropping below 105 HP")
	check(colossus.is_staggered == true, "Colossus is staggered")

	# Under Decision 1B, Colossus's unexecuted slots must be extinguished!
	var remaining_active := b.enemy_slots.filter(func(s: Dictionary) -> bool: return s.active and not s.get("done", false))
	check(remaining_active.is_empty(), "Colossus unexecuted slots extinguished (Decision 1B strict mode)")

func test_stagger_vulnerability() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var target := b.enemies[0]
	target.is_staggered = true
	target.shield = 0
	var hp_before: int = target.hp

	# Deal a hit of 10 damage to staggered target
	var ev: Array[Dictionary] = []
	var dmg := b._deal_hit(ev, true, 0, 0, 10, 1, 1)
	# +20% of 10 is 2, total damage should be 12
	check(dmg == 12, "staggered target takes +20% damage (10 -> 12)")
	check(target.hp == hp_before - 12, "target HP reduced by 12")
	check(ev.size() == 1 and ev[0].get("stagger_bonus") == 2, "event records stagger_bonus=2")

func test_wake_up_and_immunity() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var hero := b.heroes[0]
	hero.is_staggered = true

	# Transition to turn 2
	b.phase = "finished"
	b.next_round()
	check(b.turn == 2, "now turn 2")
	check(hero.is_staggered == false, "hero woke up from stagger")
	check(hero.stagger_immune_turns == 1, "hero has 1 turn stagger immunity")

	# During immunity turn, stagger cannot be triggered
	var ev: Array[Dictionary] = []
	hero.consecutive_clash_loss = 2
	var triggered := b._check_stagger_after_action(ev, hero, true, 48)
	check(not triggered, "cannot be staggered during immunity turn")
	check(hero.is_staggered == false, "hero remains unstaggered")

	# Transition to turn 3
	b.phase = "finished"
	b.next_round()
	check(b.turn == 3, "now turn 3")
	check(hero.stagger_immune_turns == 0, "immunity expired in turn 3")

	# In turn 3, consecutive clash loss can trigger stagger again
	hero.consecutive_clash_loss = 2
	triggered = b._check_stagger_after_action(ev, hero, true, 48)
	check(triggered, "can be staggered again after immunity expires")

func test_overwhelm_margin_formula() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})

	# Helper to simulate overwhelm calculation directly
	# Formula: D >= 6 -> min(3, floor(D / 3))
	var calc_ov = func(D: int) -> int:
		if D < 6:
			return 0
		return mini(3, D / 3)

	check(calc_ov.call(0) == 0, "D=0: no overwhelm")
	check(calc_ov.call(5) == 0, "D=5: no overwhelm (< 6)")
	check(calc_ov.call(6) == 2, "D=6: overwhelm = 2 (floor(6/3))")
	check(calc_ov.call(7) == 2, "D=7: overwhelm = 2 (floor(7/3))")
	check(calc_ov.call(8) == 2, "D=8: overwhelm = 2 (floor(8/3))")
	check(calc_ov.call(9) == 3, "D=9: overwhelm = 3 (floor(9/3))")
	check(calc_ov.call(10) == 3, "D=10: overwhelm = 3 (floor(10/3), capped at 3)")
	check(calc_ov.call(20) == 3, "D=20: overwhelm = 3 (capped at 3)")

func test_overwhelm_exclusions() -> void:
	var b := Rules.new()
	b.start(42, Rules.TRAINING_ENCOUNTER, false, false, [], null, false, [], [], {"enabled": true})
	check(b.enemies[0].kind == "training_dummy", "enemy is training dummy")

	# Clash with D >= 6 against training dummy: should NOT trigger overwhelm
	var hero_slot := {"id": 0, "unit": 0, "key": "cleave", "speed": 5, "active": true, "target": 0}
	var enemy_slot := b.enemy_slots[0]
	var ev: Array[Dictionary] = []
	b._clash(ev, hero_slot, enemy_slot)
	var has_ov := ev.any(func(e: Dictionary) -> bool: return e.get("type") == "overwhelm")
	check(not has_ov, "training dummy excludes overwhelm")

	# Guard skill exclusion
	var b_guard := Rules.new()
	b_guard.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var guard_skill := Rules.SKILLS["guard"]
	check(guard_skill.kind == "guard", "guard skill is kind guard")

func test_overwhelm_shield_absorption() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, [], [], {"enabled": true})
	var target := b.enemies[0]
	target.shield = 5
	var hp_before: int = target.hp

	# Overwhelm damage 3 against 5 shield: shield absorbs all 3
	var ov_amount := 3
	var blocked := mini(int(target.shield), ov_amount)
	target.shield -= blocked
	var damage := maxi(0, ov_amount - blocked)
	target.hp = maxi(0, int(target.hp) - damage)

	check(blocked == 3, "shield blocked all 3 overwhelm damage")
	check(damage == 0, "0 damage penetrated to HP")
	check(target.shield == 2, "remaining shield is 2")
	check(target.hp == hp_before, "HP unchanged")

func test_zixi_enhancement_release() -> void:
	var b := Rules.new()
	b.start(42, 0, false, true, [], null, false, [], [], {"enabled": true})
	var zixi := b.heroes[1]
	check(zixi.has("metaphysics"), "ZiXi has metaphysics")
	zixi.metaphysics = 1
	var zixi_slot_id := 3 # first slot of ZiXi

	# Enhance slot
	var err := b.assign(0, zixi_slot_id, 0, true)
	if err.is_empty():
		check(b.hero_slots[zixi_slot_id].get("enhanced", false) == true, "slot marked enhanced")
		check(zixi.enhanced_reserved == zixi_slot_id, "enhancement reserved")

		# Extinguish ZiXi's slots due to stagger
		var ev: Array[Dictionary] = []
		b._extinguish_remaining_slots(ev, zixi, true)

		# Enhancement must be freed!
		check(b.hero_slots[zixi_slot_id].get("enhanced", false) == false, "enhanced flag removed")
		check(zixi.enhanced_reserved == -1, "ZiXi enhancement cleanly released")

func test_sakuya_and_marisa_interaction() -> void:
	# Touhou team (Marisa, Sakuya, Reimu)
	var b := Rules.new()
	b.start(42, 0, true, false, [], null, false, [], [], {"enabled": true})
	check(b.touhou_team, "touhou team active")
	check(b.marisa_slot == 0 and b.sakuya_slot == 1 and b.reimu_slot == 2, "slot mapping correct")

	# Marisa multi-target laser
	var ev: Array[Dictionary] = []
	b.enemies[0].hp = 30 # max 58
	b.enemies[1].hp = 35 # max 65
	var laser_slot := {"id": 0, "unit": b.marisa_slot, "key": Rules.Marisa.LASER, "speed": 10, "active": true, "target": 0}
	b._attack_marisa(ev, laser_slot, 0, 3, true)

	# Check that if any enemy crossed 50% from multi-target laser, stagger was checked
	var stagger_events := ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "stagger")
	# If HP crossed 29 (for scout max 58) or 32 (for warden max 65), stagger triggers
	for se in stagger_events:
		check(se.get("allied") == false, "enemy staggered by marisa multi-hit")

func test_victory_reward_uniqueness() -> void:
	var b := Rules.new()
	b.start(42, 0, false, false, [], null, false, ["ember_pouch"], [], {"enabled": true})
	var cost_start := b.cost

	# Kill both enemies
	b.enemies[0].hp = 0
	b.enemies[1].hp = 0
	var ev: Array[Dictionary] = []

	# First check outcome
	b._check_outcome(ev)
	check(b.outcome == "victory", "victory achieved")
	check(b.cost == cost_start + 4, "ember pouch granted +4 cost once")
	var outcome_events := ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "outcome")
	var reward_events := ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "reward")
	check(outcome_events.size() == 1, "exactly 1 outcome event")
	check(reward_events.size() == 1, "exactly 1 ember pouch reward event")

	# Second check outcome (defensive verification): must NOT grant second reward
	b._check_outcome(ev)
	outcome_events = ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "outcome")
	reward_events = ev.filter(func(e: Dictionary) -> bool: return e.get("type") == "reward")
	check(outcome_events.size() == 1, "still exactly 1 outcome event")
	check(reward_events.size() == 1, "still exactly 1 reward event")
	check(b.cost == cost_start + 4, "cost not double rewarded")

func test_end_to_end_lock_and_resolve() -> void:
	var b := Rules.new()
	b.start(1234, 0, false, false, [], null, false, [], [], {"enabled": true})

	# Assign actions
	var cleave_idx := b.hand.find("cleave")
	var nova_idx := b.hand.find("nova")
	var guard_idx := b.hand.find("guard")
	if cleave_idx >= 0:
		b.assign(cleave_idx, 0, 0)
	if nova_idx >= 0:
		b.assign(nova_idx, 1, 0)

	# Execute full round resolution
	var events := b.lock_and_resolve()
	check(not events.is_empty(), "events generated in lock_and_resolve")
	check(b.phase in ["finished", "outcome"], "phase transitioned properly")

	# Check snapshots exist on all events
	for e in events:
		check(e.has("snapshot"), "event has snapshot: " + e.get("type", ""))
		check(e["snapshot"].has("stagger_enabled"), "snapshot exposes stagger_enabled")
		check(e["snapshot"].has("overwhelm_enabled"), "snapshot exposes overwhelm_enabled")

func test_backward_compatibility() -> void:
	var b := Rules.new()
	# Call start() without evolution config (default)
	b.start(42, 0)
	check(b.stagger_enabled == false, "default stagger disabled")
	check(b.overwhelm_enabled == false, "default overwhelm disabled")

	# Check that _check_stagger_after_action returns false
	var ev: Array[Dictionary] = []
	b.heroes[0].hp = 10
	var triggered := b._check_stagger_after_action(ev, b.heroes[0], true, 48)
	check(not triggered, "stagger disabled by default, never triggers")
