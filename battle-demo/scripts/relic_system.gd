class_name RelicSystem
extends RefCounted

## 探险通用遗物与消耗品数据库及被动效果引擎

const RELICS := {
	"mercury_die": {
		"name": "水银骰子",
		"icon": "🪙",
		"rarity": "rare",
		"description": "全队所有技能在拼点时，每次掷出正面，拼点点数额外 +1。",
		"price": 14
	},
	"adversity_blade": {
		"name": "逆境锋刃",
		"icon": "⚔️",
		"rarity": "uncommon",
		"description": "当敌方行动格速度高于我方时，我方该行动格拼点初始基础威力 +2。",
		"price": 12
	},
	"weight_of_balance": {
		"name": "天平砝码",
		"icon": "⚖️",
		"rarity": "rare",
		"description": "拼点双方点数相同时，打破僵局，直接判定我方胜出。",
		"price": 16
	},
	"piercing_cone": {
		"name": "破阵铁锥",
		"icon": "🗡️",
		"rarity": "uncommon",
		"description": "全队对带有护盾的敌人造成伤害时，额外造成 3 点无视护盾的贯穿伤害。",
		"price": 11
	},
	"ember_pouch": {
		"name": "余烬金袋",
		"icon": "💰",
		"rarity": "common",
		"description": "每场战斗获胜结算时，额外带回 +4 Cost。",
		"price": 9
	},
	"everburning_tinder": {
		"name": "永燃火种",
		"icon": "🕯️",
		"rarity": "rare",
		"description": "战斗中每回合开始时的固定费用收入由 8 提升至 10 Cost。",
		"price": 15
	},
	"greedy_contract": {
		"name": "行商契约",
		"icon": "📜",
		"rarity": "common",
		"description": "废林行商处所有商品与治疗服务享受 7 折（向上取整）优惠。",
		"price": 8
	},
	"warden_bell": {
		"name": "守夜人铜铃",
		"icon": "🛡️",
		"rarity": "common",
		"description": "战斗第 1 回合开始时，全队所有存活角色自动获得 5 点开场护盾。",
		"price": 9
	},
	"leech_shard": {
		"name": "汲血残片",
		"icon": "🩸",
		"rarity": "uncommon",
		"description": "击杀任意敌人时，为全队存活角色恢复 3 点生命值。",
		"price": 12
	},
	"trail_rations": {
		"name": "行军干粮",
		"icon": "🏕️",
		"rarity": "common",
		"description": "在营地（Camp）休整时，生命恢复量额外 +6 点。",
		"price": 7
	},
	"brass_compass": {
		"name": "黄铜罗盘",
		"icon": "🧭",
		"rarity": "common",
		"description": "林间探险基础探照视野 +1 格（提前探知相邻更远节点的类型）。",
		"price": 10
	},
	"ranger_cloak": {
		"name": "游侠斗篷",
		"icon": "🪶",
		"rarity": "uncommon",
		"description": "林间小道移动时产生的噪音与警戒度增长速度降低 50%。",
		"price": 10
	}
}

const ITEMS := {
	"ember_catalyst": {
		"name": "余烬催化剂",
		"icon": "🧪",
		"description": "战斗规划阶段使用：本回合立即获得 +3 临时可用 Cost。",
		"price": 5,
		"combat_only": true
	},
	"dense_smoke": {
		"name": "浓缩烟雾弹",
		"icon": "💨",
		"description": "战斗规划阶段使用：使指定队友本回合获得截击特权且受到首击伤害减半。",
		"price": 6,
		"combat_only": true
	},
	"weighted_coin": {
		"name": "特制铅币",
		"icon": "🪙",
		"description": "战斗规划阶段使用：选定一张手牌，本次拼点首枚硬币 100% 必定掷出正面。",
		"price": 6,
		"combat_only": true
	},
	"field_poultice": {
		"name": "野战膏药",
		"icon": "🩹",
		"description": "地图或战斗中均可使用：立即为选定角色恢复 12 点生命值。",
		"price": 6,
		"combat_only": false
	}
}

const RELIC_DB := RELICS
const CONSUMABLE_DB := ITEMS

static func get_relic(key: String) -> Dictionary:
	return RELICS.get(key, {})

static func get_consumable(key: String) -> Dictionary:
	return ITEMS.get(key, {})

static func get_unowned_relics(owned: Array) -> Array[String]:
	var pool: Array[String] = []
	for k in RELICS.keys():
		if not owned.has(k):
			pool.append(k)
	return pool

static func has_relic(relics: Array, key: String) -> bool:
	return relics.has(key)

static func roll_random_relic(owned: Array, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = []
	for k in RELICS.keys():
		if not owned.has(k):
			pool.append(k)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]

static func roll_random_item(rng: RandomNumberGenerator) -> String:
	var keys: Array = ITEMS.keys()
	return keys[rng.randi() % keys.size()]

static func relic_name(key: String) -> String:
	return RELICS.get(key, {}).get("name", key)

static func item_name(key: String) -> String:
	return ITEMS.get(key, {}).get("name", key)
