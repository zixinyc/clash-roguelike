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
	},
	"dawn_amber": {
		"name": "晨曦琥珀",
		"icon": "🌅",
		"rarity": "uncommon",
		"description": "战斗第 1 回合开始时，全队存活角色额外获得 6 点开场护盾。",
		"price": 11
	},
	"broken_crest": {
		"name": "断剑徽记",
		"icon": "🗡️",
		"rarity": "rare",
		"description": "单方面攻击与队友夹击的额外伤害加成由 +3 提升至 +5。",
		"price": 13
	},
	"time_hourglass": {
		"name": "时之沙漏",
		"icon": "⏳",
		"rarity": "uncommon",
		"description": "林野探索投掷 1d4 行动骰时，若基础点数为 1，自动修正为 2 步。",
		"price": 11
	},
	"hakurei_amulet": {
		"name": "博丽御守",
		"icon": "⛩️",
		"rarity": "common",
		"description": "在营地休整或御灵神龛祈福时，生命恢复效果额外提升 50%。",
		"price": 9
	}
}

const ITEMS := {
	"ember_catalyst": {
		"name": "余烬催化剂",
		"icon": "🧪",
		"description": "立即获得 5 cost。",
		"price": 5,
		"combat_only": true
	},
	"dense_smoke": {
		"name": "浓缩烟雾弹",
		"icon": "💨",
		"description": "全体存活队员本回合获得 8 护盾。",
		"price": 6,
		"combat_only": true
	},
	"weighted_coin": {
		"name": "特制铅币",
		"icon": "🪙",
		"description": "下一次我方掷币全部为正面。",
		"price": 6,
		"combat_only": true
	},
	"field_poultice": {
		"name": "野战膏药",
		"icon": "🩹",
		"description": "为受伤的存活队员中生命最低的一位恢复最多 12 生命。可在地图或战斗中使用。",
		"price": 6,
		"combat_only": false
	},
	"whetstone": {
		"name": "淬火磨刀石",
		"icon": "🪨",
		"description": "本回合全队所有技能拼点基础威力 +2。",
		"price": 6,
		"combat_only": true
	},
	"echo_pendulum": {
		"name": "回响灵摆",
		"icon": "🔮",
		"description": "地图中使用：疲劳 -2 且获得 3 cost；战斗中使用：立即获得 3 cost 且全队 +4 护盾。",
		"price": 7,
		"combat_only": false
	},
	"phoenix_feather": {
		"name": "凤凰尾羽",
		"icon": "🪶",
		"description": "地图使用：复活 1 名阵亡队员并恢复 30% 生命值（若全员存活则为伤势最重者恢复 16 生命）；战斗中使用：全体存活队员恢复 10 生命并获得 6 护盾。",
		"price": 8,
		"combat_only": false
	},
	"shatter_bomb": {
		"name": "破甲炸弹",
		"icon": "💣",
		"description": "仅限战斗使用：摧毁敌方全体最多 12 点护盾，且本回合全队拼点威力 +1。",
		"price": 6,
		"combat_only": true
	},
	"clarity_elixir": {
		"name": "澄明甘露",
		"icon": "💧",
		"description": "地图使用：消除全部疲劳，并获得 4 cost；战斗中使用：立即获得 4 cost，灵台空明。",
		"price": 6,
		"combat_only": false
	},
	"gambler_die": {
		"name": "命运秘骰",
		"icon": "🎲",
		"description": "投掷 1d6 秘骰。地图使用：单数 +6 cost，双数 +2 命运；战斗中使用：1~3 全队 +7 护盾，4~5 +5 cost，6 本回合全队硬币必出正面。",
		"price": 7,
		"combat_only": false
	}
}

const RELIC_DB := RELICS
const CONSUMABLE_DB := ITEMS

const ITEM_ART := {
	"ember_catalyst": preload("res://art/items/ember_catalyst.png"),
	"dense_smoke": preload("res://art/items/dense_smoke.png"),
	"weighted_coin": preload("res://art/items/weighted_coin.png"),
	"field_poultice": preload("res://art/items/field_poultice.png"),
	"whetstone": preload("res://art/items/whetstone.png"),
	"echo_pendulum": preload("res://art/items/echo_pendulum.png"),
	"phoenix_feather": preload("res://art/items/phoenix_feather.png"),
	"shatter_bomb": preload("res://art/items/shatter_bomb.png"),
	"clarity_elixir": preload("res://art/items/clarity_elixir.png"),
	"gambler_die": preload("res://art/items/gambler_die.png"),
}

static func get_item_art(key: String) -> Texture2D:
	return ITEM_ART.get(key)

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
