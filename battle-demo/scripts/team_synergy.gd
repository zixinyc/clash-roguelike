class_name TeamSynergy
extends RefCounted

## 队伍羁绊共鸣系统（落地 idea/阵容组合Buff.md）
## 根据出战 1～3 名角色的阵营与构筑特征自动激活轻量战术共鸣，
## 在主界面选人、探索顶栏及战斗第 1 回合同步展示与生效。

const Rules = preload("res://scripts/battle_rules.gd")

static func evaluate(members: Array) -> Array[Dictionary]:
	var unique: Array[int] = []
	for m in members:
		var id := int(m)
		if not unique.has(id):
			unique.append(id)
	if unique.is_empty():
		return []

	var result: Array[Dictionary] = []

	# 1. 孤影独行（单人出战）
	if unique.size() == 1:
		result.append({
			"id": "lone_wolf",
			"icon": "🐺",
			"name": "孤影独行",
			"desc": "单骑出战：每回合固定收入 +2 Cost，开场获得 +6 护盾。",
			"color": Color("f5c963"),
		})
		return result

	# 2. 薪火守望（余烬原初小队：灰烬 / 长锋 / 织火 至少 2 人）
	var ember_count := _count_in(unique, [Rules.ASH_ID, Rules.BLADE_ID, Rules.WEAVER_ID])
	if ember_count >= 2:
		var full := ember_count >= 3
		result.append({
			"id": "ember_watch",
			"icon": "🔥",
			"name": "薪火守望" + (" · 满编" if full else ""),
			"desc": "首回合全队 +4 护盾" + ("，灰烬开场自带 1 层【准备】。" if full else "。"),
			"full": full,
			"color": Color("f0a45d"),
		})

	# 3. 幻想乡结界（东方嘉宾：咲夜 / 灵梦 / 魔理沙 至少 2 人）
	var touhou_count := _count_in(unique, [Rules.SAKUYA_ID, Rules.REIMU_ID, Rules.MARISA_ID])
	if touhou_count >= 2:
		result.append({
			"id": "gensokyo_barrier",
			"icon": "⛩️",
			"name": "幻想乡结界",
			"desc": "首回合额外 +2 Cost，全队速度下限 +1。",
			"color": Color("e88fb4"),
		})

	# 4. 理性推演（ZiXi + ZiXingYC 同时在场）
	if unique.has(Rules.ZIXI_ID) and unique.has(Rules.ZIXINGYC_ID):
		result.append({
			"id": "rational_deduction",
			"icon": "📐",
			"name": "理性推演",
			"desc": "开场 ZiXi +1 层【超形上学】，ZiXingYC 自动写入 1 条【观测】。",
			"color": Color("76d1da"),
		})

	# 5. 绒盾守护（pufufu + 至少 1 名队友）
	if unique.has(Rules.PUFUFU_ID):
		result.append({
			"id": "fluff_bastion",
			"icon": "☁️",
			"name": "绒盾守护",
			"desc": "首回合全队 +3 护盾，pufufu 开场获得 1 层【蓬松】。",
			"color": Color("9ad98b"),
		})

	# 6. 绝缘利刃（ZiWu 与队友同行）
	if unique.has(Rules.ZIWU_ID):
		result.append({
			"id": "insulated_edge",
			"icon": "🗡️",
			"name": "孤刃同行",
			"desc": "开场 ZiWu 获得 1 层【绝缘】，首回合行动更凌厉。",
			"color": Color("c792ea"),
		})

	# 7. 异界共鸣（跨阵营混搭兜底）
	if result.is_empty():
		result.append({
			"id": "cross_resonance",
			"icon": "✦",
			"name": "异界共鸣",
			"desc": "跨阵营混编：首回合额外 +1 Cost，全队获得 +2 开场护盾。",
			"color": Color("8bc8ce"),
		})

	return result

static func _count_in(unique: Array[int], pool: Array) -> int:
	var n := 0
	for id in pool:
		if unique.has(int(id)):
			n += 1
	return n

static func summary_line(members: Array) -> String:
	var synergies := evaluate(members)
	if synergies.is_empty():
		return "选择 1～3 名角色即可预览阵容羁绊共鸣"
	var parts: Array[String] = []
	for s in synergies:
		parts.append("%s %s（%s）" % [s.icon, s.name, s.desc])
	return "  |  ".join(parts)

static func compact_badges(members: Array) -> String:
	var synergies := evaluate(members)
	if synergies.is_empty():
		return ""
	var parts: Array[String] = []
	for s in synergies:
		parts.append("%s %s" % [s.icon, s.name])
	return " · ".join(parts)
