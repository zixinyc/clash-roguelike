# ZiWu 角色接线说明

给接手「把 ZiWu 接进《余烬交锋》主引擎」的模型看。

角色脚本已经写完并测过，文件是 `battle-demo/scripts/characters/ziwu.gd`，
自带测试 `battle-demo/tests/test_ziwu.gd`（117 项断言全绿，不依赖引擎接线）。

这一份只讲「引擎要改哪里、怎么调」，角色自己的规则不用再改。

---

## 一、先看角色设计是什么

ZiWu 是「绝缘独行客」：队友越少她越强，队友死光后靠处决队友继续变强。

四张符卡：

| 符卡 | 费用 | 拼点威力 | 伤害 | 说明 |
| --- | --- | --- | --- | --- |
| 冷刃试锋 | 1 | 15 ~ 21 | 基础 8，每枚正面 +4（满 16） | 双正面额外 +3；拼输后下回合受伤 +2 |
| 断缘处决 | 2 | 16 ~ 24 | 基础 10，每枚正面 +5（满 20） | 目标血量 ≤50% 时拼点 +3；可以指向友军并无视血量与护盾直接处决 |
| 孤影截杀 | 4 | 19 ~ 29 | 基础 12，每枚正面 +6（满 24） | 拼赢额外 +4；可消耗 2 层绝缘强化成「绝影突袭」 |
| 子午绝灭斩 | 5 | 22 ~ 34 | 基础 15，每枚正面 +8（满 31） | 终符；消耗全部绝缘，每层额外 +5；结算后自扣 5 HP |

两条被动规则：

- 被动① 独行加成：每缺少 1 名存活友军，拼点 +2、伤害 +3。满编 3 人时缺 2 人就是拼点 +4、伤害 +6。
- 被动② 断缘祭刃：处决或击杀友军后触发 —— 绝缘 +2、恢复 5 HP、本回合首次触发返还 3 cost；用「断缘处决」触发时额外获得 8 护盾。

三条资源规则：

- 绝缘上限 5 层。「绝影突袭」强化消耗 2 层绝缘，每回合只能强化一次。
- 独行时（场上没有存活友军）拼赢产 1 层绝缘，每回合最多 1 层。
- 终符「子午绝灭斩」放行条件：存活友军 ≤1，或持有 ≥3 层绝缘。发动后消耗全部绝缘，并且下一回合无法再通过拼点产绝缘。

---

## 二、引擎要改的七处

### 1）登记角色与四张符卡

`battle-demo/scripts/battle_rules.gd`：

```gdscript
const ZiWu = preload("res://scripts/characters/ziwu.gd")

# SKILLS 里加四张牌
"ziwu_cold_edge": ZiWu.COLD_EDGE_CARD,
"ziwu_backstab": ZiWu.BACKSTAB_CARD,
"ziwu_lone_intercept": ZiWu.LONE_INTERCEPT_CARD,
"ziwu_meridian_slash": ZiWu.MERIDIAN_SLASH_CARD,

# enum 末尾追加（追加在最后，已有 ID 不会变）
enum { ASH_ID, BLADE_ID, WEAVER_ID, SAKUYA_ID, REIMU_ID, ZIXI_ID, ZIXINGYC_ID, MARISA_ID, ZIWU_ID }
const ZIWU_LINEUP := [ASH_ID, ZIWU_ID, WEAVER_ID]

# create_roster() 里追加 ZiWu.create_unit()
# card_owner() 里加 if key in ZiWu.CARDS: return ZIWU_ID
# available_cards() 里把 ZiWu.CARDS 加进列表
```

`battle_setup.gd` 不用改，它是从 `Rules.create_roster()` 动态生成角色按钮的。

### 2）回合准备

`_prepare_round()` 现在是这样分发护盾逻辑的：

```gdscript
if units[u].has("shield_until"):
    ZiXi.prepare_round(units[u], turn)
else:
    units[u].shield = 0
```

ZiWu 也有 `shield_until`，但它要重置的字段和 ZiXi 不同，所以要加一个分支（放在 `shield_until` 判断之前）：

```gdscript
if units[u].has("insulation"):
    var ctx := ZiWu.round_context(heroes, u)
    ZiWu.prepare_round(units[u], turn, ctx.missing_allies, ctx.is_solo)
elif units[u].has("shield_until"):
    ZiXi.prepare_round(units[u], turn)
else:
    units[u].shield = 0
```

`round_context()` 返回 `{"missing_allies": int, "is_solo": bool}`：

- `missing_allies` = 满编 3 人时缺少的存活友军数，取值 0 ~ 2。
- `is_solo` = 场上没有任何存活友军。

另外，`prepare_round` 会写 `hero.extra_cards`（独行时为 1，否则 0）。如果要让「独行多抽一张牌」生效，在 `_draw_cards()` 里把抽牌数加上 `hero.extra_cards` 即可；不接也不影响其他功能。

### 3）拼点三处调用

`_clash()` 里，ZiXi 那段旁边加 ZiWu 的：

```gdscript
var ziWu_clash := {}
if hero.has("insulation"):
    ziWu_clash = ZiWu.begin_clash(hero, h, left_skill, enemies[e.unit])
    left_skill.base += int(ziWu_clash.bonus)
```

拼赢那处（`if lc > 0:` 分支内，ZiXi 的 `win_clash` 旁边）：

```gdscript
if not ziWu_clash.is_empty():
    var gained := ZiWu.win_clash(hero, h.key, bool(h.get("enhanced", false)), turn)
    if gained > 0:
        _emit(events, {"type": "ability", "message": "ZiWu：绝缘 +%d" % gained})
```

拼点结算那处（`_clash()` 末尾，ZiXi 的 `_finish_zixi_clash` 旁边）：

```gdscript
if not ziWu_clash.is_empty() and heroes[h.unit].hp > 0:
    _finish_ziwu_clash(events, h, 0 if lc > 0 else 1, ziWu_clash)
```

`result` 的约定和 ZiXi 一样：`0` = 拼赢，`1` = 拼败，`-1` = 平局。

`_finish_ziwu_clash()` 要做的事：把 `finish_clash` 返回的 `extra_damage` 当追加伤害补一发，再把 `self_damage` 扣到 ZiWu 自己身上。

### 4）伤害怎么算

ZiWu 的四张牌用的是 ZiXi 同款伤害模型（不是引擎默认的 `base`/`power` 那套）：

- 第 1 段伤害 = 基础伤害 + 全局伤害加成 + 该枚硬币正面数 × 每枚正面伤害
- 第 2 段起 = 该枚硬币正面数 × 每枚正面伤害
- 牌面写的「满 X」是两段相加

角色里已经写好了换算函数，引擎逐枚硬币掷点之后调用它：

```gdscript
var heads := []                                  # 每枚硬币掷出的正面数
var damage := ZiWu.strike_damage(slot.key, heads, ziWu_clash)
for i in damage.size():
    _deal_hit(events, true, slot.unit, target, damage[i], i + 1, damage.size())
```

`clash` 里的 `damage_bonus` 是「缺友军 + 绝缘」的伤害加成，`strike_damage` 会自动加到第一段。

注意：`_clash()` 里现在的分支顺序是「先 Marisa，再 `left_skill.has("damage_base")`」，ZiWu 的牌也有 `damage_base`，所以 ZiWu 的分支必须插在 `has("damage_base")` 那一支之前，否则会被 ZiXi 的结算函数接管。

### 5）强化

现在 `can_assign()` 的强化校验写死成「必须有 `metaphysics` 字段」（那是 ZiXi 的资源）：

```gdscript
if enhanced:
    if not heroes[slot.unit].has("metaphysics") or not skill.has("enhance_name"):
        return "这张牌不能强化"
    return ZiXi.enhancement_error(heroes[slot.unit], slot_id)
```

ZiWu 用的是 `insulation` 字段，要改成按角色分发：

```gdscript
if enhanced:
    var unit_hero := heroes[slot.unit]
    if unit_hero.has("insulation"):
        return ZiWu.enhancement_error(unit_hero, slot_id, key)
    if not unit_hero.has("metaphysics") or not skill.has("enhance_name"):
        return "这张牌不能强化"
    return ZiXi.enhancement_error(unit_hero, slot_id)
```

`assign()` 和 `cancel()` 里的预留/退回也要同样分发：

```gdscript
# assign()
if enhanced:
    if hero.has("insulation"):
        ZiWu.reserve_enhancement(hero, slot_id)
    else:
        ZiXi.reserve_enhancement(hero, slot_id)
    slot.enhanced = true

# cancel() / assign() 里撤销旧强化
if slot.get("enhanced", false):
    if hero.has("insulation"):
        ZiWu.unreserve_enhancement(hero, slot_id)
    else:
        ZiXi.unreserve_enhancement(hero, slot_id)
    slot.erase("enhanced")
```

（不能用「先试 ZiXi、失败再试 ZiWu」这种写法，因为 `ZiXi.unreserve_enhancement` 会在 ZiWu 身上凭空造出 `metaphysics` 字段。）

### 6）终符门槛

`can_assign()` 里要加终符门槛校验：

```gdscript
if key == ZiWu.MERIDIAN_SLASH:
    var alive_allies := 0
    for i in heroes.size():
        if i != slot.unit and int(heroes[i].hp) > 0:
            alive_allies += 1
    var ending_error := ZiWu.ultimate_error(heroes[slot.unit], alive_allies)
    if not ending_error.is_empty():
        return ending_error
```

`ultimate_error()` 返回空字符串就是可以发动。

### 7）友军处决（断缘处决指向队友）

这是 ZiWu 最特别的一块，主引擎目前完全没有「攻击友军」这条路径，需要新加。

**排面侧**：`can_assign()` 和 `assign()` 要多一个 `friendly: bool = false` 参数（加在最后并给默认值，现有调用不用改）：

- `friendly == true` 时，不校验敌方行动格，改为校验目标友军存活。
- `slot.ally_target = 目标队友下标`；`slot.targeted` 置 false，`slot.target` 不用。

```gdscript
# can_assign() 里，friendly == true 的分支
if friendly:
    if not skill.get("can_target_ally", false):
        return "这张牌不能指向友军"
    if target < 0 or target >= heroes.size() or heroes[target].hp <= 0:
        return "请选择存活的队友"
    if target == slot.unit:
        return "不能对自己出手"
```

**结算侧**：`_solo()` 现在开头会把「需要拼点」的牌取消掉，友军分支必须插在这段判断之前：

```gdscript
func _solo(events: Array[Dictionary], slot: Dictionary, allied: bool) -> void:
    var skill: Dictionary = SKILLS[slot.key]
    var units: Array[Dictionary] = heroes if allied else enemies
    if allied and slot.has("ally_target"):
        _ziwu_friendly_attack(events, slot, skill)
        return
    # 下面才是原来的 requires_clash 取消判断
```

`_ziwu_friendly_attack()` 要做的事：

1. 取 `slot.ally_target` 指向的队友，确认还活着。
2. 无视血量与护盾直接处决：伤害 = 队友当前生命（`ZiWu.ally_execute_damage(victim)`），队友血量归零、护盾清零。
3. 发一条 `strike` 事件，并且带上 `friendly: true`（`battle_stage.gd` 的演出要靠这个字段区分友军受击）。
4. 队友退场后调用被动：

```gdscript
var result := ZiWu.on_ally_killed(hero, String(victim.name), slot.key, turn)
# result: cost_refund / insulation_gained / healed / shield
```

5. `cost_refund` 要加到 `cost` 上；`shield` 要给 ZiWu 自己加护盾。

另外两处连带改动：

- `_solo()` 里「需要拼点就取消」的判断，要把 ZiWu 也算进去。现状是只判断了 ZiXingYC：

```gdscript
if allied and (skill.has("enhance_name") or (units[slot.unit].character_id in [ZIXINGYC_ID, ZIWU_ID] and skill.get("requires_clash", false))):
```

- `_deal_hit()` 里加「冷刃试锋拼输后下回合受伤 +2」：

```gdscript
if not allied and index == 1 and hit > 0:
    hit += ZiWu.vulnerable_damage(victim, turn)
```

（只在 `victim.has("insulation")` 的角色身上加，其他角色不受影响。）

---

## 三、界面要改的四处

`battle-demo/scripts/role_hand.gd`：

1. `CARD_ORDER` 里加四张牌的位置（建议放在 ZiXingYC 那一段后面）。
2. `refresh()` 的 `match int(hero.character_id):` 加一支：

```gdscript
Rules.ZIWU_ID:
    role_summary.text = Rules.ZiWu.summary(hero)
```

3. 强化勾选框的显隐条件现在是 `var is_zixi := hero.has("metaphysics")`，ZiWu 要单独处理：
   - 强化勾选框只在选中「孤影截杀」时出现。
   - 错误提示用 `Rules.ZiWu.enhancement_error(hero, slot_id, selection_key)`。
   - 勾选框上的文字要写「强化 · 2 层」（ZiXi 是 3 层）。
4. `card.bonus` 那行，ZiWu 要显示自己的拼点加成（缺友军 + 绝缘）。

`battle-demo/scripts/planning_ui.gd`：

5. 选到能指向友军的牌时，要有一个「攻击队友…」的入口，打开一个选队友的小面板。
   `docs/hunter` 分支上有一版实现可以参考：`battle-demo/scripts/planning_ui.gd` 里的
   `friendly_button` / `friendly_panel` / `friendly_picker` / `friendly_confirm`。
   注意那条分支的引擎比现在的主线旧，直接照抄要自己对齐接口。

`battle-demo/scripts/card_view.gd`：

6. `USE_HINTS` 里加四张牌的一句话提示（现在缺了会退回显示完整 description，会把卡面挤满）。

---

## 四、几个容易踩的坑

1. **平局**。`_clash()` 平局时走 `result = -1`。ZiWu 的 `finish_clash` 只在拼赢（0）和拼败（1）时有动作，平局不触发易伤也不加伤害。
2. **绝影突袭的 +3 下次拼点**是在 `win_clash` 里写进 `hero.next_clash` 的，
   真正被消费是在下一次 `begin_clash`（它会清空 `next_clash`）。
   中间再拼赢别的牌不会覆盖它，也不会提前消耗它。
3. **终符的绝缘快照**。`begin_clash` 会记 `insulation_snapshot`，
   终符按这个快照算「消耗了几层绝缘 × 5 的追加伤害」。
   拼败时绝缘一样被消耗光（`hero.insulation = 0`），只是没有追加伤害。
4. **终符的自扣 5 HP 至少保留 1 点**，不会自杀。
5. **护盾的跨回合部分**。`absorb_carried_shield()` 只负责扣 `shield_until`，
   当前护盾 `shield` 由引擎在 `_deal_hit()` 里单独扣减（现有 ZiXi 就是这个约定，别改反了）。
6. **友军处决不拼点**。它走 `_solo()` 分支，不参与配对，所以不会和敌方行动配成拼点。
7. **`vuln_round` 不会自动清零**，靠「回合号对不上」自然失效。
   如果同一回合先拼输再拼赢，易伤依然保留到下一回合。

---

## 五、验收

接线完成后跑：

```powershell
$godot = '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
Get-ChildItem -Path battle-demo\tests\test_*.gd | ForEach-Object {
    $file = $_.Name
    if ($file -match '_render\.gd$') {
        & $godot --path battle-demo --script "tests/$file"
    } else {
        & $godot --headless --path battle-demo --script "tests/$file"
    }
}
& $godot --path battle-demo -- --planning-smoke
```

现在的基线是 26 个测试文件全绿（其中 `test_ziwu.gd` 117 项断言只测角色本身，不碰引擎）。
接线之后建议再加一层战斗流程测试：让 ZiWu 真的打一场，验证拼点加成、终符消耗、友军处决三条链路。
