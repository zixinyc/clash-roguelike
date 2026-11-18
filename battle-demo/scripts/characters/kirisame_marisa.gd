extends RefCounted

const STARS := "marisa_stars"
const LASER := "marisa_laser"
const ORRERY := "marisa_orrery"
const SPARK := "marisa_spark"
const CARDS := [STARS, LASER, ORRERY, SPARK]

const MARISA_STARS := {
	"name": "星辰幻想", "cost": 2, "base": 5, "power": 4, "coins": 2,
	"kind": "attack", "owner": 0, "damage_base": 5, "damage_power": 1,
	"tag": "魔理沙专属", "flavor": "先点亮第一颗星。",
	"description": "拼点获胜火花+1；初始5，正面攻币+1逐币累计，队伍增伤每技能一次。"
}
const MARISA_LASER := {
	"name": "非指向性激光", "cost": 3, "base": 5, "power": 4, "coins": 2,
	"kind": "attack", "owner": 0, "damage_base": 5, "damage_power": 3,
	"tag": "魔理沙专属", "flavor": "散开的光同样灼热。",
	"description": "最多3目标；每击原伤−4。拼赢后按实际命中人数增加火花。"
}
const MARISA_ORRERY := {
	"name": "天球仪", "cost": 3, "base": 10, "power": 0, "coins": 0,
	"kind": "guard", "owner": 0,
	"tag": "魔理沙专属", "flavor": "群星环绕。",
	"description": "无法拼点；本回合及下回合每次受击减伤5，火花+1。"
}
const MARISA_SPARK := {
	"name": "极限火花", "cost": 5, "base": 0, "power": 20, "coins": 1,
	"kind": "ultimate", "owner": 0,
	"tag": "魔理沙专属", "flavor": "火力就是答案。",
	"description": "胜利或单方面释放：每敌10×火花，消耗全部火花。"
}

static func create_unit() -> Dictionary:
	return {
		"name": "雾雨魔理沙", "role": "火花", "hp": 45, "max_hp": 45,
		"shield": 0, "acted": false, "speed_min": 5, "speed_max": 7,
		"spark": 0, "orrery_until": 0, "orrery_active": false,
	}

static func prepare_round(hero: Dictionary, turn: int) -> void:
	hero.orrery_active = (turn <= int(hero.get("orrery_until", 0)))

static func add_spark(hero: Dictionary, amount: int) -> int:
	hero.spark = clampi(int(hero.get("spark", 0)) + amount, 0, 10)
	return int(hero.spark)

static func clash_bonus(hero: Dictionary, reimu_alive: bool, skill_kind: String) -> int:
	var bonus := 0
	if reimu_alive:
		bonus -= 2
	if int(hero.get("spark", 0)) > 5 and skill_kind != "guard":
		bonus += 2
	return bonus

static func damage_bonus(hero: Dictionary, reimu_alive: bool) -> int:
	var bonus := 0
	if reimu_alive:
		bonus += 5
	if int(hero.get("spark", 0)) > 5:
		bonus += 2
	return bonus
