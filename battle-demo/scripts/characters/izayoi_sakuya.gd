extends RefCounted

const MURDER_DOLL := {"name": "杀人玩偶", "cost": 2, "base": 5, "power": 3, "coins": 1, "kind": "attack", "owner": 1, "fixed_damage": true, "description": "单体，满币总伤害 8"}
const STOPWATCH := {"name": "咲夜特制秒表", "cost": 4, "base": 5, "power": 15, "coins": 1, "kind": "ultimate", "owner": 1, "description": "接下来两回合，敌方速度 −3（最低 1）；全队拼点时每快 2 点威力 +1（最多 +3）"}
const PRIVATE_SQUARE := {"name": "私人空间", "cost": 3, "base": 5, "power": 10, "coins": 1, "kind": "guard", "owner": 1, "targeted": true, "description": "下回合自身速度 +3，每次攻击伤害 +5"}
const THE_WORLD := {"name": "咲夜的世界", "cost": 5, "base": 5, "power": 20, "coins": 1, "kind": "ultimate", "owner": 1, "description": "下回合仅咲夜可行动，拥有 3 个不限类别的技能槽；敌方无法拼点或防御。每场可安排一次"}
const CARDS := ["murder_doll", "stopwatch", "private_square", "the_world"]

static func create_unit() -> Dictionary:
	return {
		"name": "十六夜咲夜", "role": "时停", "hp": 40, "max_hp": 40,
		"shield": 0, "acted": false, "speed_min": 5, "speed_max": 9,
		"ignores_intercept_speed": true, # 完美且潇洒的女仆
		"world_used": false, "world_round": 0,
		"watch_until": 0, "watch_active": false, "space_pending": false, "space_active": false,
	}

static func prepare_round(hero: Dictionary, turn: int) -> void:
	hero.watch_active = turn <= hero.watch_until
	hero.space_active = hero.space_pending
	hero.space_pending = false

static func speed_modifier(hero: Dictionary, allied: bool, unit: int) -> int:
	if not allied:
		return -3 if hero.watch_active else 0
	return 3 if unit == 1 and hero.space_active else 0

static func stopwatch_bonus(hero: Dictionary, ally_speed: int, enemy_speed: int) -> int:
	return clampi((ally_speed - enemy_speed) / 2, 0, 3) if hero.watch_active else 0

# 银色小刀与私人空间的增伤每次攻击只结算一次。
static func damage_bonus(hero: Dictionary, turn: int) -> int:
	var silver_knife := 5 if turn <= 2 else (2 if turn == 3 else 0)
	return silver_knife + (5 if hero.space_active else 0)

static func release(hero: Dictionary, key: String, turn: int) -> String:
	match key:
		"stopwatch":
			hero.watch_until = turn + 2
			return "咲夜特制秒表：接下来两回合敌方减速，速度领先时强化拼点"
		"private_square":
			hero.space_pending = true
			return "私人空间：下回合咲夜速度 +3，每次攻击伤害 +5"
		"the_world":
			hero.world_round = turn + 1
			return "咲夜的世界：下回合只有咲夜可以行动"
	return ""
