extends SceneTree

const Rules = preload("res://scripts/battle_rules.gd")
const Marisa = preload("res://scripts/characters/kirisame_marisa.gd")

class Heads extends "res://scripts/battle_rules.gd":
	func _roll(base: int, power: int, coins: int, chance: float) -> Dictionary:
		var heads := coins if chance > 0.5 else 0
		return {"value": maxi(0, base + power * heads), "heads": heads}

class Tails extends "res://scripts/battle_rules.gd":
	func _roll(base: int, _power: int, _coins: int, _chance: float) -> Dictionary:
		return {"value": maxi(0, base), "heads": 0}

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + message)

func quiet(b: DemoBattleRules, attack_id: int = -1, target: int = 0) -> void:
	b.cost = 100
	for u in b.enemies:
		u.hp = 1000
		u.max_hp = 1000
	for s in b.enemy_slots:
		s.active = s.id == attack_id
		if s.active:
			s.key = "needle"
			s.target = target

func _run() -> void:
	print("--- Running Marisa Tests ---")
	
	# 1. Roster and Lineup checks
	var b := Heads.new()
	b.start(73129, 0, true)
	check(b.touhou_team and b.heroes[0].name == "雾雨魔理沙" and b.heroes[0].hp == 45, "Marisa is in Touhou roster with 45 HP")
	check(b.hand.size() == 18 and Marisa.CARDS.all(func(k: String) -> bool: return b.hand.has(k)), "Marisa exclusive cards in hand")
	check(b.heroes[0].speed_min == 5 and b.heroes[0].speed_max == 7, "Marisa speed is 5-7")
	check(not b.can_assign(b.hand.find("marisa_stars"), 3, 0).is_empty(), "Sakuya cannot use Marisa card")
	
	# 2. Solo Stars Damage (unopposed)
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b)
	check(b.assign(b.hand.find("marisa_stars"), 0, 0).is_empty(), "Marisa assigns stars")
	var ev := b.lock_and_resolve()
	var strikes := ev.filter(func(e: Dictionary) -> bool: return e.type == "strike" and e.allied)
	var total_dmg := 0
	for s in strikes:
		total_dmg += int(s.damage)
	check(total_dmg == 18 and b.heroes[0].spark == 0, "Solo stars deals 18 damage and spark remains 0")
	
	# 3. Clash Stars
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b, 0, 0)
	check(b.assign(b.hand.find("marisa_stars"), 0, 0).is_empty(), "Marisa assigns stars for clash")
	ev = b.lock_and_resolve()
	var clash: Dictionary = ev.filter(func(e: Dictionary) -> bool: return e.type == "clash")[0]
	check(clash.left == 11 and b.heroes[0].spark == 1, "Clash left power is 11 (5 base + 8 power - 2 Reimu penalty) and win gives 1 spark")
	
	# 4. Laser multi-target & spark gain
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b, 0, 0)
	check(b.assign(b.hand.find("marisa_laser"), 0, 0).is_empty(), "Marisa assigns laser")
	ev = b.lock_and_resolve()
	strikes = ev.filter(func(e: Dictionary) -> bool: return e.type == "strike" and e.allied)
	total_dmg = 0
	for s in strikes:
		total_dmg += int(s.damage) - int(s.get("momentum_damage", 0))
	check(b.heroes[0].spark == 2 and total_dmg == 32, "Laser hits two enemies for 32 total damage and gains 2 spark")
	
	# 5. Orrery damage reduction
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b)
	check(b.assign(b.hand.find("marisa_orrery"), 2, -1).is_empty(), "Marisa assigns orrery")
	b.lock_and_resolve()
	check(b.heroes[0].spark == 1 and b.heroes[0].shield == 0, "Orrery gives 1 spark and no shield")
	b.next_round()
	check(b.heroes[0].orrery_active, "Orrery active next round")
	quiet(b, 0, 0)
	b.enemies[0].hp = 1000
	ev = b.lock_and_resolve()
	check(b.heroes[0].hp == 45, "Orrery reduces enemy damage by 5 and protects HP")
	
	# 6. Master Spark
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b)
	b.heroes[0].spark = 3
	check(b.assign(b.hand.find("marisa_spark"), 1, 0).is_empty(), "Marisa assigns Master Spark")
	ev = b.lock_and_resolve()
	strikes = ev.filter(func(e: Dictionary) -> bool: return e.type == "strike" and e.allied)
	check(b.heroes[0].spark == 0 and strikes.size() == 2 and strikes[0].damage == 35 and strikes[1].damage == 35, "Master Spark consumes 3 sparks, dealing 35 to each enemy")
	
	# 7. Blood theft / cost borrowing
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b)
	b.cost = 0
	check(b.assign(b.hand.find("marisa_stars"), 0, 0).is_empty() and b.heroes[0].hp == 45, "Blood theft is reserved without upfront HP loss")
	b.cancel(0)
	check(b.heroes[0].hp == 45, "Cancel preserves Marisa HP")
	check(b.assign(b.hand.find("marisa_stars"), 0, 0).is_empty(), "Re-assign stars")
	b.lock_and_resolve()
	check(b.heroes[0].hp == 35 and b.enemy_cost == Rules.START_COST - 2, "Lock and resolve deducts 10 HP (2 cost * 5) and reduces enemy cost by 2")
	
	# 8. Theft fatal check
	b = Heads.new()
	b.start(73129, 0, true)
	quiet(b)
	b.cost = 0
	b.heroes[0].hp = 10
	check(not b.can_assign(b.hand.find("marisa_stars"), 0, 0).is_empty(), "Cannot borrow if HP is not strictly greater than required")
	
	print("MARISA_TESTS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
