class_name CardPool
extends RefCounted

const DemoBattleRules = preload("res://scripts/battle_rules.gd")

## 杀戮尖塔式卡池定义：稀有度分层、同名副本上限、初始卡组与 3 选 1 抽卡算法

const MIN_DECK_SIZE := 5
const MAX_DECK_SIZE := 22
const SKIP_REWARD_COST := 2
const REMOVE_CARD_COST := 5

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"

const RARITY_META := {
	RARITY_COMMON: {"label": "普通", "color": Color("6bc275"), "copy_limit": 3, "price": 4},
	RARITY_UNCOMMON: {"label": "罕见", "color": Color("5bb8e8"), "copy_limit": 2, "price": 6},
	RARITY_RARE: {"label": "稀有", "color": Color("f5c963"), "copy_limit": 1, "price": 9},
}

# 平衡优化：4 张扎实通用核心（含高威断轨）+ 每名出战队员 2 张招牌套路牌 = 3 人队经典 10 张尖塔初始牌库
const NEUTRAL_STARTER := ["cleave", "ember", "guard", "guard"]

const HERO_STARTER_CARD := {
	DemoBattleRules.ASH_ID: "probe",
	DemoBattleRules.BLADE_ID: "steady_edge",
	DemoBattleRules.WEAVER_ID: "cover",
	DemoBattleRules.SAKUYA_ID: "murder_doll",
	DemoBattleRules.REIMU_ID: "yin_yang_orb",
	DemoBattleRules.ZIXI_ID: "zixi_central_limit",
	DemoBattleRules.ZIXINGYC_ID: "zixingyc_attention",
	DemoBattleRules.MARISA_ID: "marisa_stars",
	DemoBattleRules.PUFUFU_ID: "pufufu_soft_guard",
	DemoBattleRules.ZIWU_ID: "ziwu_cold_edge",
}

const HERO_STARTER_CARDS := {
	DemoBattleRules.ASH_ID: ["probe", "exploit"],
	DemoBattleRules.BLADE_ID: ["steady_edge", "all_in"],
	DemoBattleRules.WEAVER_ID: ["cover", "support_strike"],
	DemoBattleRules.SAKUYA_ID: ["murder_doll", "private_square"],
	DemoBattleRules.REIMU_ID: ["yin_yang_orb", "fantasy_seal"],
	DemoBattleRules.ZIXI_ID: ["zixi_central_limit", "zixi_convergence"],
	DemoBattleRules.ZIXINGYC_ID: ["zixingyc_attention", "zixingyc_residual"],
	DemoBattleRules.MARISA_ID: ["marisa_stars", "marisa_laser"],
	DemoBattleRules.PUFUFU_ID: ["pufufu_soft_guard", "pufufu_fuzz_friction"],
	DemoBattleRules.ZIWU_ID: ["ziwu_cold_edge", "ziwu_backstab"],
}

const CARD_RARITY := {
	# 通用牌
	"needle": RARITY_COMMON,
	"guard": RARITY_COMMON,
	"ember": RARITY_COMMON,
	"steady": RARITY_COMMON,
	"cleave": RARITY_UNCOMMON,
	"risk": RARITY_UNCOMMON,
	"nova": RARITY_RARE,
	# 灰烬
	"probe": RARITY_COMMON,
	"observe": RARITY_COMMON,
	"exploit": RARITY_UNCOMMON,
	"follow": RARITY_RARE,
	# 长锋
	"steady_edge": RARITY_COMMON,
	"all_in": RARITY_UNCOMMON,
	"shatter": RARITY_RARE,
	# 织火
	"cover": RARITY_COMMON,
	"support_strike": RARITY_UNCOMMON,
	"light_guard": RARITY_RARE,
	# 十六夜咲夜
	"murder_doll": RARITY_COMMON,
	"private_square": RARITY_UNCOMMON,
	"stopwatch": RARITY_RARE,
	"the_world": RARITY_RARE,
	# 博丽灵梦
	"yin_yang_orb": RARITY_COMMON,
	"fantasy_seal": RARITY_COMMON,
	"demon_seal": RARITY_UNCOMMON,
	"fantasy_nature": RARITY_RARE,
	# ZiXi
	"zixi_central_limit": RARITY_COMMON,
	"zixi_convergence": RARITY_UNCOMMON,
	"zixi_martingale": RARITY_UNCOMMON,
	"zixi_almost_sure": RARITY_RARE,
	# ZiXingYC
	"zixingyc_attention": RARITY_COMMON,
	"zixingyc_residual": RARITY_COMMON,
	"zixingyc_paradox": RARITY_UNCOMMON,
	"zixingyc_yesterday": RARITY_UNCOMMON,
	"zixingyc_ending": RARITY_RARE,
	# 雾雨魔理沙
	"marisa_stars": RARITY_COMMON,
	"marisa_orrery": RARITY_UNCOMMON,
	"marisa_laser": RARITY_UNCOMMON,
	"marisa_spark": RARITY_RARE,
	# pufufu
	"pufufu_fuzz_friction": RARITY_COMMON,
	"pufufu_soft_guard": RARITY_COMMON,
	"pufufu_static_fuzz": RARITY_COMMON,
	"pufufu_fuzz_heal": RARITY_COMMON,
	"pufufu_fuzz_combo": RARITY_UNCOMMON,
	"pufufu_fuzz_bless": RARITY_UNCOMMON,
	"pufufu_fuzz_barrier": RARITY_UNCOMMON,
	"pufufu_warm_echo": RARITY_RARE,
	"pufufu_thick_wall": RARITY_RARE,
	"pufufu_fluff_hug": RARITY_RARE,
	# ZiWu
	"ziwu_cold_edge": RARITY_COMMON,
	"ziwu_backstab": RARITY_UNCOMMON,
	"ziwu_lone_intercept": RARITY_UNCOMMON,
	"ziwu_meridian_slash": RARITY_RARE,
}

static func rarity_of(key: String) -> String:
	return String(CARD_RARITY.get(key, RARITY_COMMON))

static func rarity_label(key: String) -> String:
	return String(RARITY_META[rarity_of(key)].label)

static func rarity_color(key: String) -> Color:
	return RARITY_META[rarity_of(key)].color

static func copy_limit(key: String) -> int:
	return int(RARITY_META[rarity_of(key)].copy_limit)

static func shop_price(key: String) -> int:
	return int(RARITY_META[rarity_of(key)].price)

static func count_copies(deck: Array, key: String) -> int:
	var n := 0
	for k in deck:
		if String(k) == key:
			n += 1
	return n

static func build_starter_deck(lineup: Array) -> Array[String]:
	var result: Array[String] = []
	for k in NEUTRAL_STARTER:
		result.append(String(k))
	for id in lineup:
		var hero_id := int(id)
		var hero_cards: Array = HERO_STARTER_CARDS.get(hero_id, [])
		for c in hero_cards:
			var starter_key := String(c)
			if count_copies(result, starter_key) < copy_limit(starter_key):
				result.append(starter_key)
	return result

static func can_add_card(deck: Array, key: String) -> Dictionary:
	if not DemoBattleRules.SKILLS.has(key):
		return {"ok": false, "reason": "未知卡牌：%s" % key}
	if deck.size() >= MAX_DECK_SIZE:
		return {"ok": false, "reason": "牌库已达上限（%d 张），请先在商店精简删牌。" % MAX_DECK_SIZE}
	var cur := count_copies(deck, key)
	var lim := copy_limit(key)
	if cur >= lim:
		return {"ok": false, "reason": "【%s】已达%s卡同名上限（%d/%d 张）。" % [DemoBattleRules.SKILLS[key].name, rarity_label(key), cur, lim]}
	return {"ok": true, "reason": ""}

static func can_remove_card(deck: Array, idx: int) -> Dictionary:
	if idx < 0 or idx >= deck.size():
		return {"ok": false, "reason": "请选择有效的卡牌。"}
	if deck.size() <= MIN_DECK_SIZE:
		return {"ok": false, "reason": "牌库至少保留 %d 张卡牌，无法继续删除。" % MIN_DECK_SIZE}
	return {"ok": true, "reason": ""}

static func eligible_reward_pool(lineup: Array, deck: Array) -> Array[String]:
	var available: Array = DemoBattleRules.available_cards(lineup)
	var result: Array[String] = []
	for k in available:
		var key := String(k)
		if count_copies(deck, key) < copy_limit(key):
			result.append(key)
	return result

static func roll_card_choices(lineup: Array, deck: Array, rng: RandomNumberGenerator, tier: String = "normal", count: int = 3) -> Array[String]:
	var pool := eligible_reward_pool(lineup, deck)
	if pool.is_empty():
		return []
	var by_rarity := {
		RARITY_COMMON: [] as Array[String],
		RARITY_UNCOMMON: [] as Array[String],
		RARITY_RARE: [] as Array[String],
	}
	for k in pool:
		by_rarity[rarity_of(k)].append(k)

	var picked: Array[String] = []
	var want := mini(count, pool.size())
	for slot_idx in want:
		var target_rarity := _pick_target_rarity(tier, slot_idx, rng)
		var candidate := _draw_from_rarity_with_fallback(by_rarity, target_rarity, picked, rng)
		if not candidate.is_empty():
			picked.append(candidate)
	return picked

static func _pick_target_rarity(tier: String, slot_idx: int, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	match tier:
		"boss":
			if slot_idx == 0:
				return RARITY_RARE
			return RARITY_RARE if r < 0.55 else RARITY_UNCOMMON
		"elite":
			if slot_idx == 0:
				return RARITY_RARE if r < 0.45 else RARITY_UNCOMMON
			return RARITY_RARE if r < 0.25 else (RARITY_UNCOMMON if r < 0.75 else RARITY_COMMON)
		"shop":
			if slot_idx == 0:
				return RARITY_COMMON
			if slot_idx == 1:
				return RARITY_UNCOMMON
			return RARITY_RARE if r < 0.65 else RARITY_UNCOMMON
		_:
			return RARITY_RARE if r < 0.14 else (RARITY_UNCOMMON if r < 0.52 else RARITY_COMMON)

static func _draw_from_rarity_with_fallback(by_rarity: Dictionary, preferred: String, already: Array[String], rng: RandomNumberGenerator) -> String:
	var order: Array[String] = []
	match preferred:
		RARITY_RARE:
			order = [RARITY_RARE, RARITY_UNCOMMON, RARITY_COMMON]
		RARITY_UNCOMMON:
			order = [RARITY_UNCOMMON, RARITY_COMMON, RARITY_RARE]
		_:
			order = [RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE]
	for rar in order:
		var avail: Array[String] = []
		for k in by_rarity[rar]:
			if not already.has(k):
				avail.append(k)
		if not avail.is_empty():
			return avail[rng.randi() % avail.size()]
	return ""

static func card_owner_label(key: String) -> String:
	var owner := DemoBattleRules.card_owner(key)
	if owner < 0:
		return "全队通用"
	var roster := DemoBattleRules.create_roster()
	if owner >= 0 and owner < roster.size():
		return "%s专属" % roster[owner].name
	return "专属"

static func card_summary_text(key: String) -> String:
	if not DemoBattleRules.SKILLS.has(key):
		return ""
	var s: Dictionary = DemoBattleRules.SKILLS[key]
	var kind_str := "防御" if s.kind == "guard" else ("大招" if s.kind == "ultimate" else "进攻")
	var stat_str := ""
	if s.kind == "guard" and not s.get("targeted", false):
		stat_str = "护盾"
	elif int(s.get("coins", 0)) > 0:
		var lo := int(s.get("base", 0))
		var hi := lo + int(s.get("power", 0)) * int(s.get("coins", 0))
		stat_str = "威力 %d-%d (%d币)" % [lo, hi, int(s.get("coins", 0))]
	var desc := String(s.get("description", ""))
	if stat_str.is_empty():
		return "%s · %s" % [kind_str, desc]
	return "%s · %s\n%s" % [kind_str, stat_str, desc]
