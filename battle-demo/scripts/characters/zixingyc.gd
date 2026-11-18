extends RefCounted

const OBSERVATION := "observation"
const ASSOCIATION := "association"
const REFLECTION := "reflection"
const REASONING := "reasoning"
const RETRIEVAL := "retrieval"
const GENERATION := "generation"

const MEMORY_PER_ROUND := 3
const OVERLOAD_THRESHOLD := 5
const SEVERE_OVERLOAD_THRESHOLD := 8
const MEMORIES_PER_CORPUS := 3
const ENDING_LIMIT := 2

const REASONING_ORDER := [OBSERVATION, ASSOCIATION, REFLECTION]
const RETRIEVAL_ORDER := [REFLECTION, ASSOCIATION, OBSERVATION]
const GENERATION_ORDER := [OBSERVATION, REFLECTION, ASSOCIATION]

const ATTENTION := "zixingyc_attention"
const RESIDUAL := "zixingyc_residual"
const PARADOX := "zixingyc_paradox"
const YESTERDAY := "zixingyc_yesterday"
const ENDING := "zixingyc_ending"
const CARDS := [ATTENTION, RESIDUAL, PARADOX, YESTERDAY, ENDING]

const ATTENTION_CARD := {
	"name": "注意力机制", "cost": 1, "kind": "attack",
	"base": 4, "power": 2, "coins": 2, "damage_base": 3, "damage_power": 2,
	"archive_corpus": REASONING,
	"description": "拼赢额外写入一份观测；结算后按观测、关联、反思整理成推理语料。",
}
const RESIDUAL_CARD := {
	"name": "残差连接", "cost": 2, "kind": "attack",
	"base": 4, "power": 3, "coins": 2, "damage_base": 3, "damage_power": 3,
	"archive_corpus": GENERATION,
	"description": "每三条已整理记忆使本次伤害 +2（最多 +10）；攻击后将最早三条未整理记忆整理成生成语料。",
}
const PARADOX_CARD := {
	"name": "自指悖论", "cost": 3, "kind": "attack",
	"base": 5, "power": 3, "coins": 2, "damage_base": 4, "damage_power": 3,
	"archive_corpus": RETRIEVAL,
	"description": "拼赢使目标下次与你拼点 −2；成功削弱时写入关联，并按反思、关联、观测整理成检索语料。对已削弱目标的拼胜攻击额外 +3 伤害。",
}
const YESTERDAY_CARD := {
	"name": "被删除的昨天", "cost": 4, "kind": "guard",
	"base": 7, "power": 4, "coins": 1, "targeted": true, "requires_clash": true, "no_damage": true,
	"description": "拼赢获得 10 护盾；拼败额外写入反思。已整理三条记忆时，本次拼败伤害降低 30%。",
}
const ENDING_CARD := {
	"name": "记忆的终点不存在", "cost": 5, "kind": "ultimate",
	"base": 6, "power": 4, "coins": 3, "requires_clash": true, "no_damage": true,
	"description": "至少有一份语料，且本次拼赢时发动。对每个存活敌人造成 8 + 4 × 语料总数的伤害，生成加成另计。每场至多发动两次。",
}

# 规则层常量
const OVERLOAD_PENALTY := 2
const SEVERE_OVERLOAD_PENALTY := 4
const CORPUS_THRESHOLD := 2
const REASONING_INCOME_MAX := 2
const RETRIEVAL_PENALTY_MAX := 2
const GENERATION_BONUS_MAX := 5
const RESIDUAL_BONUS_MAX := 10
const YESTERDAY_SHIELD := 10
const YESTERDAY_REDUCTION := 0.7
const YESTERDAY_ORGANIZED_MIN := 3
const PARADOX_WEAKEN := 2
const PARADOX_BONUS := 3
const MEMORY_NAMES := {OBSERVATION: "观测", ASSOCIATION: "关联", REFLECTION: "反思"}
const CORPUS_NAMES := {REASONING: "推理", RETRIEVAL: "检索", GENERATION: "生成"}


static func create_unit() -> Dictionary:
	return {
		"name": "ZiXingYC", "role": "未被遗忘的观测者",
		"hp": 40, "max_hp": 40, "speed_min": 7, "speed_max": 9,
		"shield": 0, "acted": false,
		# 每条记忆包含 id、type 和 organized。id 按写入顺序递增。
		"memory_log": [], "memory_round_gains": 0, "organized_this_round": false,
		"corpora": {REASONING: 0, RETRIEVAL: 0, GENERATION: 0},
		"ending_uses": 0,
		"next_memory_id": 1,
	}


static func prepare_round(hero: Dictionary) -> void:
	hero.memory_round_gains = 0
	hero.organized_this_round = false


static func memory_name(kind: String) -> String:
	return MEMORY_NAMES.get(kind, kind)


static func corpus_name(kind: String) -> String:
	return CORPUS_NAMES.get(kind, kind)


static func unorganized(hero: Dictionary) -> Array:
	var result: Array = []
	for memory in hero.memory_log:
		if not bool(memory.organized):
			result.append(memory)
	return result


static func unorganized_count(hero: Dictionary) -> int:
	return hero.memory_log.size() - organized_count(hero)


static func organized_count(hero: Dictionary) -> int:
	var count := 0
	for memory in hero.memory_log:
		if bool(memory.organized):
			count += 1
	return count


static func overload_penalty(hero: Dictionary) -> int:
	var count := unorganized_count(hero)
	if count >= SEVERE_OVERLOAD_THRESHOLD:
		return SEVERE_OVERLOAD_PENALTY
	if count >= OVERLOAD_THRESHOLD:
		return OVERLOAD_PENALTY
	return 0


static func write_memory(hero: Dictionary, kind: String) -> int:
	if int(hero.memory_round_gains) >= MEMORY_PER_ROUND:
		return -1
	var memory := {"id": int(hero.next_memory_id), "type": kind, "organized": false}
	hero.next_memory_id = int(hero.next_memory_id) + 1
	hero.memory_log.append(memory)
	hero.memory_round_gains = int(hero.memory_round_gains) + 1
	return int(memory.id)


static func recipe_order(recipe: String) -> Array:
	match recipe:
		REASONING:
			return REASONING_ORDER
		RETRIEVAL:
			return RETRIEVAL_ORDER
		GENERATION:
			return GENERATION_ORDER
	return []


# 整理挑选：推理与检索各取每种类型最早的一条；生成取最早三条未整理记忆并按类型稳定排列。
static func archive_picks(hero: Dictionary, recipe: String) -> Array:
	var pool := unorganized(hero)
	if recipe == GENERATION:
		if pool.size() < MEMORIES_PER_CORPUS:
			return []
		var oldest := pool.slice(0, MEMORIES_PER_CORPUS)
		var generated: Array = []
		for kind in GENERATION_ORDER:
			for memory in oldest:
				if memory.type == kind:
					generated.append(memory)
		return generated
	var order := recipe_order(recipe)
	var picked: Array = []
	for kind in order:
		var found: Dictionary = {}
		for memory in pool:
			if String(memory.type) == kind:
				found = memory
				break
		if found.is_empty():
			return []
		picked.append(found)
	return picked


# 先验证三个 ID 各异、都存在且未整理，再一次性标记三条并增加一份语料。
static func archive(hero: Dictionary, recipe: String) -> Array:
	if bool(hero.organized_this_round):
		return []
	var picked := archive_picks(hero, recipe)
	if picked.size() != MEMORIES_PER_CORPUS:
		return []
	var seen := {}
	for memory in picked:
		if bool(memory.organized) or seen.has(int(memory.id)):
			return []
		seen[int(memory.id)] = true
	for memory in picked:
		memory.organized = true
	hero.corpora[recipe] = int(hero.corpora.get(recipe, 0)) + 1
	hero.organized_this_round = true
	return picked


static func corpora_total(hero: Dictionary) -> int:
	var total := 0
	for kind in [REASONING, RETRIEVAL, GENERATION]:
		total += int(hero.corpora.get(kind, 0))
	return total


static func reasoning_income(hero: Dictionary) -> int:
	var count := int(hero.corpora.get(REASONING, 0))
	return mini(REASONING_INCOME_MAX, count / CORPUS_THRESHOLD)


static func retrieval_penalty(hero: Dictionary) -> int:
	var count := int(hero.corpora.get(RETRIEVAL, 0))
	return mini(RETRIEVAL_PENALTY_MAX, count / CORPUS_THRESHOLD)


static func generation_bonus(hero: Dictionary) -> int:
	return mini(GENERATION_BONUS_MAX, int(hero.corpora.get(GENERATION, 0)))


static func residual_bonus(hero: Dictionary) -> int:
	return mini(RESIDUAL_BONUS_MAX, (organized_count(hero) / MEMORIES_PER_CORPUS) * 2)


static func ending_damage(hero: Dictionary) -> int:
	return 8 + 4 * corpora_total(hero) + generation_bonus(hero)


static func ending_error(hero: Dictionary) -> String:
	if int(hero.get("ending_uses", 0)) >= ENDING_LIMIT:
		return "记忆的终点不存在每场至多发动两次"
	if corpora_total(hero) <= 0:
		return "至少需要一份语料才能发动记忆的终点不存在"
	return ""


# 拼点开始时结算过载、检索、悖论标记与减伤条件。
static func begin_clash(hero: Dictionary, key: String, enemy: Dictionary, enemy_base: int, right_base: int) -> Dictionary:
	var mark := int(enemy.get("zixingyc_mark", 0)) > 0
	var weakened := right_base < enemy_base
	if mark:
		weakened = true
		enemy.erase("zixingyc_mark")
	var reduction := 1.0
	if key == YESTERDAY and organized_count(hero) >= YESTERDAY_ORGANIZED_MIN:
		reduction = YESTERDAY_REDUCTION
	return {
		"overload": overload_penalty(hero),
		"retrieval": retrieval_penalty(hero),
		"weakened": weakened,
		"mark_consumed": mark,
		"reduction": reduction,
	}


# 拼赢：先写入观测，再结算卡面效果。
static func on_clash_win(hero: Dictionary, key: String) -> Dictionary:
	var result := {"written": [], "shield": 0, "ending": 0}
	var base := write_memory(hero, OBSERVATION)
	if base >= 0:
		result.written.append({"id": base, "type": OBSERVATION})
	match key:
		ATTENTION:
			var extra := write_memory(hero, OBSERVATION)
			if extra >= 0:
				result.written.append({"id": extra, "type": OBSERVATION})
		YESTERDAY:
			result.shield = YESTERDAY_SHIELD
		ENDING:
			if int(hero.ending_uses) < ENDING_LIMIT and corpora_total(hero) > 0:
				hero.ending_uses = int(hero.ending_uses) + 1
				result.ending = ending_damage(hero)
	return result


static func apply_paradox(hero: Dictionary, enemy: Dictionary) -> int:
	enemy.zixingyc_mark = 1
	return write_memory(hero, ASSOCIATION)


# 拼败：写入反思，「被删除的昨天」再追加一条反思。
static func on_clash_loss(hero: Dictionary, key: String) -> Dictionary:
	var result := {"written": []}
	var base := write_memory(hero, REFLECTION)
	if base >= 0:
		result.written.append({"id": base, "type": REFLECTION})
	if key == YESTERDAY:
		var extra := write_memory(hero, REFLECTION)
		if extra >= 0:
			result.written.append({"id": extra, "type": REFLECTION})
	return result


# 手牌区摘要：未整理条数、三类计数、过载、三种语料与本轮整理状态。
static func summary(hero: Dictionary) -> String:
	var counts := {OBSERVATION: 0, ASSOCIATION: 0, REFLECTION: 0}
	for memory in unorganized(hero):
		counts[String(memory.type)] = int(counts.get(String(memory.type), 0)) + 1
	return "记忆 未整理 %d（观测%d 关联%d 反思%d）· 过载 −%d · 语料 推%d 检%d 生%d · 本轮%s" % [
		unorganized_count(hero),
		int(counts[OBSERVATION]), int(counts[ASSOCIATION]), int(counts[REFLECTION]),
		overload_penalty(hero),
		int(hero.corpora.get(REASONING, 0)), int(hero.corpora.get(RETRIEVAL, 0)), int(hero.corpora.get(GENERATION, 0)),
		"已整理" if bool(hero.organized_this_round) else "未整理",
	]


# 选牌提示：符卡自带配方与当前材料是否充足。
static func archive_hint(hero: Dictionary, recipe: String) -> String:
	if recipe.is_empty():
		return ""
	var names := PackedStringArray()
	for kind in recipe_order(recipe):
		names.append(memory_name(kind))
	var text := "整理 %s：%s" % [corpus_name(recipe), "→".join(names)]
	if hero.organized_this_round:
		return text + "（本回合已整理）"
	var missing := missing_materials(hero, recipe)
	if missing.is_empty():
		return text + "（材料充足）"
	return text + "（材料不足，缺 %s）" % missing


static func missing_materials(hero: Dictionary, recipe: String) -> String:
	if recipe == GENERATION:
		var needed := MEMORIES_PER_CORPUS - unorganized_count(hero)
		return "%d 条未整理记忆" % needed if needed > 0 else ""
	var names: Array = []
	var pool := unorganized(hero)
	for kind in recipe_order(recipe):
		var found := false
		for memory in pool:
			if String(memory.type) == kind:
				found = true
				break
		if not found:
			names.append(memory_name(kind))
	return "、".join(names)
