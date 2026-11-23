extends RefCounted

const YIN_YANG_ORB := {"name": "阴阳宝玉", "cost": 1, "base": 3, "power": 2, "coins": 2, "kind": "attack", "owner": 2, "fixed_damage": true, "description": "满币总伤害 7，造成伤害时给目标加 1 层退治"}
const FANTASY_SEAL := {"name": "梦想妙珠", "cost": 2, "base": 1, "power": 2, "coins": 5, "kind": "attack", "owner": 2, "fixed_damage": true, "description": "满币总伤害 11，每段造成伤害叠 1 层退治，每回合最多加 2 层"}
const DEMON_SEAL := {"name": "封魔阵", "cost": 4, "base": 5, "power": 5, "coins": 1, "kind": "guard", "owner": 2, "targeted": true, "requires_clash": true, "no_damage": true, "description": "防御拼点获胜后，使目标及左侧最近的存活敌人下回合拼点威力 −2"}
const FANTASY_NATURE := {"name": "梦想天生", "cost": 5, "base": 10, "power": 10, "coins": 1, "kind": "ultimate", "owner": 2, "requires_clash": true, "no_damage": true, "description": "拼赢获得 1 层梦想宝玉，接下来三回合每次拼赢再加 1 层（上限 3）。第三个回合结束时，各敌人受到 5 × 宝玉层数 × 自身退治层数的伤害，灵梦退场"}
const CARDS := ["yin_yang_orb", "fantasy_seal", "demon_seal", "fantasy_nature"]

static func create_unit() -> Dictionary:
	return {"name": "博丽灵梦", "role": "退治", "hp": 50, "max_hp": 50, "shield": 0, "acted": false, "speed_min": 5, "speed_max": 7, "dream_orbs": 0, "dream_due": 0}

static func prepare_enemy_round(enemy: Dictionary) -> void:
	enemy.exorcism_active = enemy.get("exorcism_pending", false)
	enemy.exorcism_pending = false
	enemy.seal_active = enemy.get("seal_pending", false)
	enemy.seal_pending = false
	enemy.exorcism = enemy.get("exorcism", 0)

static func clash_bonus(enemy: Dictionary) -> int:
	# 乐园的无敌巫女
	return 1 if enemy.get("gensokyo_native", false) else 0

static func enemy_clash_penalty(enemy: Dictionary) -> int:
	return (3 if enemy.exorcism_active else 0) + (2 if enemy.seal_active else 0)

static func exorcism_limit(key: String) -> int:
	return 2 if key == "fantasy_seal" else int(key == "yin_yang_orb")

static func add_exorcism(enemy: Dictionary) -> String:
	enemy.exorcism += 1
	if enemy.exorcism < 4:
		return ""
	enemy.exorcism = 0
	enemy.exorcism_pending = true
	return "%s的退治引爆：下回合拼点威力 −3，伤害减半" % enemy.name

static func release_on_win(hero: Dictionary, enemies: Array[Dictionary], key: String, target: int, turn: int) -> Array[String]:
	var messages: Array[String] = []
	if hero.dream_due > 0 and hero.dream_orbs < 3:
		hero.dream_orbs += 1
		messages.append("梦想宝玉：%d/3 层" % hero.dream_orbs)
	if key == "demon_seal":
		messages.append(apply_demon_seal(enemies, target))
	if key == "fantasy_nature":
		hero.dream_orbs = 1
		hero.dream_due = turn + 3
		messages.append("梦想天生开始蓄能：第 %d 回合结束时发动" % hero.dream_due)
	return messages

static func apply_demon_seal(enemies: Array[Dictionary], target: int) -> String:
	enemies[target].seal_pending = true
	for left in range(target - 1, -1, -1):
		if enemies[left].hp > 0:
			enemies[left].seal_pending = true
			break
	return "封魔阵：目标和最近的左侧敌人下回合拼点威力 −2"

static func dream_damage(hero: Dictionary, enemy: Dictionary) -> int:
	return 5 * hero.dream_orbs * enemy.exorcism
