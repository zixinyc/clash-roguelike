# 界面反馈层设计 v3 · 2026-11-20

范围：`unity-client/` 的界面表现层。只谈观感与手感：悬停、按下、禁用、焦点、提示、声音、数值跳动。
不触碰战斗规则、数值、随机、结算流程。核心逻辑文件（`Core/*`）保持只读。

> v3 的变化：v2 之后第一批已经做进代码，本稿同步到实装状态。
> 主题色随"红白界面改版"一起换了，§4.1 / §5 的颜色改成现役值；
> 动效档位语义按 §7 重定；§9 补上指针对齐的实测结论。

---

## 0. 已确认的方向

| 决策项 | 结论 |
| --- | --- |
| 基调 | **分层**：操作层干脆利落，内容层偏华丽 |
| 按下反馈 | **全部按钮缩放**（含小按钮） |
| 第一批范围 | **战斗主按钮 + 技能手牌** |
| 动效强度设置 | 进第一版，默认"标准"，0 档等价现状 |
| 指针对齐 | 实测通过：`Event.current.mousePosition` 就是设计空间 |
| 声音分档 | 全部关 / 仅战斗 / 全部开 |

分层定义：

- **操作层**：按钮、页签、分段开关。反馈短、硬、准，只回答"能不能点、点了没、选中没"。
- **内容层**：技能卡、角色立绘、行动格、连线、徽章、数值。允许慢一点的呼吸、抬起、扩散、光泽。
- 两者共用同一套状态机与插值设施，只是时长与装饰强度不同。

---

## 1. 活路径确认

主 Demo 的实际界面是 **Port 战斗**，不是 `BattleGame.cs` 里的旧单场：

| 元素 | 位置 |
| --- | --- |
| Port 战斗主界面 | `Presentation/AdventureGame.cs:195` `DrawPortBattle` |
| 技能手牌 | `AdventureGame.cs:298` `DrawPortCard` |
| 主按钮组 | `Presentation/BattleGuidance.cs:58` `DrawPortCenteredActions` |
| 右侧状态面板 | `AdventureGame.cs:319` `DrawPortOperationPanel` |
| 战斗记录 | `Presentation/CoinBattleView.cs:36` `DrawBattleJournal` |
| 旧单场（仍在，但非主路径） | `BattleGame.cs:357` `OnGUI` |

第一批的落点因此确定在 `AdventureGame.cs` 与 `BattleGuidance.cs`，不动 `BattleGame.cs` 的旧单场界面。

---

## 2. 现状（v2 核对代码时的样子，动手前）

下面这张表是第一批开工**之前**的现状，留着当对照。第一批做完后的情况见 §11。

| 事实 | 位置 |
| --- | --- |
| 全局按钮只有一个实现 `Btn(Rect,string,bool)`，用 `GUI.backgroundColor` 染色 + Unity 默认皮肤 | `BattleGame.cs:514` |
| 悬停反馈只有一处：皮肤 `button.hover.textColor=Gold` | `BattleGame.cs:346` |
| 没有按下态、缩放、回弹、焦点环、自定义提示框 | 全局无 |
| 没有补间设施。战斗演出是协程 `phase` 浮点；环境动效用 `Time.realtimeSinceStartup` 正弦 | `CombatImpact.cs:9`、`DuelStage.cs:14`、`ForestMapView.cs:114` |
| 自绘热区：自绘外观 + `GUI.Button(rect, GUIContent.none, GUIStyle.none)`，无自绘悬停 | `AdventureGame.cs:236/259/273`、`BattleGame.cs:470/496`、`ForestMapView.cs:126`、`LayeredForestView.cs:37`、`ReadableCombat.cs:142` |
| Port 路径连旧单场那点悬停都没有 | `AdventureGame.cs:226` 只判断 `selected \|\| legal` |
| 音效只有两条程序化正弦（命中/碰撞），音量 0.25 | `BattleGame.cs:63-72`、`CombatImpact.cs:20` |
| 声音开关已有 | `BattleGame.cs:362` |
| 界面固定 1440×900 设计空间，`GUI.matrix` 整体缩放 | `BattleGame.cs:352` |
| 已有抓帧与自检设施 | `BattleGame.cs:128/146` |

一句话：**画面是自己画的，交互是 Unity 默认皮肤，两套语言没接上。**

---

## 3. 必须先解决的四个坑

这四条不是优化项，是不做就会做错的地方。

### 坑 1 · 只有一个 `Update()`，且战斗路径会提前 return

`BattleGame.Update()` 在 `BattleGame.cs:226`，第 229 行 `if(adventureMode){ AdventureUpdate(); return; }`。
主 Demo 永远 `adventureMode == true`，所以**如果把动画推进写在 `AdventureUpdate()` 里或 `Update()` 的分支之后，UI 动画在战斗界面根本不跑**。

→ 动画推进必须写在 `BattleGame.Update()` 的**最顶部**，在任何分支之前：

```csharp
void Update()
{
    UiTick(Time.unscaledDeltaTime);      // ← 必须在最前面
    if(effectInspectorOpen && ...) { ... }
    if(adventureMode) { AdventureUpdate(); return; }
    ...
}
```

时间源用 `Time.unscaledDeltaTime`：与演出倍速（`CombatImpact.cs:16` 用 `unscaledDeltaTime*speed`）、与 `portRules.Tick(unscaledDeltaTime)` 的倒计时都不冲突。UI 反馈速度恒定，不随倍速加速——这是对的。

### 坑 2 · 缩放的绘制矩形与热区矩形必须分开

`DrawPortCard` 里自绘矩形和 `GUI.Button` 热区是同一个 `r`。按下时若把绘制矩形缩小、而热区仍按原矩形判定，缩到一半鼠标就"掉出"按钮，按下态提前结束；反之若热区跟着缩，靠近边缘点击会落空。

→ **热区恒为原始矩形，缩放只作用于绘制。** 自绘按钮统一遵守这一条：

```csharp
bool inside = originalRect.Contains(pointer);   // 命中用原矩形
Rect draw   = ScaleRect(originalRect, scale);  // 绘制用缩放矩形
```

### 坑 3 · 手牌"选中"已经有一处 8px 位移，会和悬停抬起撞车

`AdventureGame.cs:264`：`float x=32+index*208, y=portCard==c.Id?639:647;`
选中的卡本来就上移 8 像素（硬切，无过渡）。如果悬停再抬 2–3px，玩家分不清"悬停"和"选中"。

→ 两者用**不同通道**表达，不叠加同类信号：

| 通道 | 悬停 | 选中 |
| --- | --- | --- |
| 位移 | 抬 3px | 抬 8px（保留现状） |
| 描边 | 转金 1px | 常驻金 2px |
| 底色 | 提亮一档 | 提亮两档 |
| 角标 | 无 | 右上角加"已选"小标 |

叠加后位移 11px、描边 2px 金，区分度足够。

### 坑 4 · 说明文字已有固定落点，不必新造 tooltip 气泡

`AdventureGame.cs:279`：`string detail = portCard!="" ? ... : GUI.tooltip;`
卡牌说明已经通过 `GUI.tooltip` 汇到右侧"本回合行动"面板显示。**第一版不做浮动提示框**，沿用这个固定位置——说明文字不该跟着鼠标跑，容易被窗口边缘截断。

`DrawPortCard` 传入的 `GUIContent("", c.Description + error)` 已经同时承载说明与错误原因，保持不动。

---

## 4. 状态机

### 4.1 操作层

配色随"红白界面改版"一起换过，下面是现役值（`UiFx.cs` `DrawUiButton`）。

| 状态 | 表现 | 时长 |
| --- | --- | --- |
| 次按钮常态 | 底 `#56232E`，描边 `#80414B` 1px，文字 `Pale #E7E9E3` | — |
| 次按钮悬停 | 底 `#78303C`，描边 `#F6A7A9` 1px，文字转金 `#DFBD83` | 进 90ms / 出 140ms |
| 主按钮常态 | 底 `#F6DFDA`，文字 `#45141E`，内圈 1px 浅色高光 | — |
| 主按钮悬停 | 底向 `Pale` 提亮，描边恒为 `#F6A7A9` | 同上 |
| 按下 | 底向 `#210B11` 压 30%，描边向文字色偏 35%，缩放见 4.2 | 40ms 到位 |
| 松开 | 回 100%，一次 4% 过冲 | 约 120ms 稳定 |
| 禁用 | 底向 `#34161F` 压 55%，描边转 `#4B3038`，文字转 `Muted` | 180ms 淡化 |
| 焦点 | 外圈 2px `Cyan #94C4CA`，从底色渐入 | 100ms 淡入 |
| 拒绝 | 描边转 `Red` + 6px 横向抖 3 次 | 180ms 衰减 |
| 确认 | 金色扩散环 6px | 220ms |
| 忙碌 | 底向 `#4B3038` 压 55%，文字转 `Muted` | 常驻 |

描边宽度按画布缩放补偿：`width = (1 + press) / scale`，屏幕上恒为 1 像素，小窗下不至于糊成半像素。

### 4.2 缩放幅度：按按钮高度归一

"全部按钮缩放"要真的看得出来。小按钮 27–28px 高，缩 3.5% 只有 1px，等于没缩。

规则：**目标视觉下沉量恒定 1.6px**，

```
scale = 1 - 1.6 / height      然后夹到 [0.940, 0.965]
```

| 高度 | scale | 实际下沉 |
| --- | --- | --- |
| 27px（小按钮） | 0.941 | 1.6px |
| 28px | 0.943 | 1.6px |
| 36px | 0.956 | 1.6px |
| 38px（主按钮） | 0.958 | 1.6px |
| 48px | 0.965（触夹） | 1.7px |

回弹过冲量：相对缩放量的 4%，即从 0.958 回弹冲到约 1.002，再回落 1.0。

### 4.3 内容层

| 元素 | 悬停 | 选中 | 其他 |
| --- | --- | --- | --- |
| 技能卡 | 抬 3px，描边转金，底色提亮 | 抬 8px，金描边 2px，角标 | 不可用：压暗 + 说明走右侧面板 |
| 角色立绘 | 描边 1px→2px，亮度 +8% | 保持金描边 | 合法目标：描边呼吸 1.2s 周期、幅度 15% |
| 行动格 | 描边转金 | 金描边常驻 | — |
| 风险连线 | 无 | — | 结算确认时沿线扫一道光 400ms |
| cost 数字 | — | — | 变化时 320ms ease-out cubic 滚动 + 颜色闪一下 |
| 已安排计数 | — | — | 增加时 scale 1.15→1（180ms）+ 闪金 |
| 倒计时 | — | — | ≤10 秒转红并每秒脉冲 |

### 4.4 插值实现

悬停用指数逼近（帧率无关）：

```csharp
static float UiApproach(float value,float target,float dt,float duration)
{
    if(duration<=0f) return target;
    return value + (target-value) * (1f - Mathf.Exp(-3f*dt/duration));
}
```

95% 到位耗时 = duration。

按下用二阶阻尼弹簧。过冲量要精确可控，用解析解而不是裸弹簧积分：

```csharp
// 目标：过冲 4%，稳定约 120ms
// Mp = exp(-PI*z/sqrt(1-z^2)) = 0.04  ->  z = 0.716
// wn = 4 / (z * 0.12) ≈ 46.6
static float UiSpring(float t,float z,float wn,float from,float to)
{
    float wd = wn * Mathf.Sqrt(1f - z*z);
    float e  = Mathf.Exp(-z*wn*t);
    return to + (from-to) * e * (Mathf.Cos(wd*t) + (z*wn/wd)*Mathf.Sin(wd*t));
}
```

`UiSpring` 输入 `t` 为从按下（或松开）起算的秒数。松开时 `from` 用当前缩放值、`to` 用 1.0，参数同上。临界阻尼版（无过冲）留作 0 档动效强度使用：`z=1`，`x = to + (from-to)*(1+wn*t)*exp(-wn*t)`。

---

## 5. 第一批规格

### 5.1 战斗主按钮（操作层）

`BattleGuidance.cs:56` `DrawPortCenteredActions`，三个按钮：

| 按钮 | 矩形 | 层级 | 已选/主 |
| --- | --- | --- | --- |
| 自动安排 | (430,566,160,38) | 次 | 否 |
| 准备交锋 / 演示一回合 | (605,566,230,38) | 主 | 是（金底深字） |
| 跳过演出 / 调整安排 / 撤销当前行动 | (850,566,160,38) | 次 | 否 |

具体要求：

1. 主按钮常态改为浅底 `#F6DFDA` + 深字 `#45141E`（红白改版后已改，深字浅底对比够）。
2. 主按钮文案在「交锋进行中 / 演示一回合 · Enter / 准备交锋 · Enter」三种之间切换。切换时做 **120ms 淡出 → 换字 → 120ms 淡入**，位置不动，避免文字跳变。
3. 「交锋进行中」为忙碌态：底色降饱和，右侧加脉冲点，且不响应点击（现状已用 `GUI.enabled` 禁用，需自绘等价表现）。
4. 全部三键：悬停 90/140ms、按下 40ms、缩放按 4.2 公式、禁用 180ms 淡化。
5. 按 Enter 触发的等价按钮也要走同一套按下反馈（键盘焦点环 + 短缩放），否则键盘与鼠标两套手感不一致。

三个按钮已换成自绘 `UiButton("port.auto" / "port.primary" / "port.third", ...)`，
键盘路径 `AdventureGame.Update` 走 `UiKeyPress("port.primary")`，按下瞬间 `SetFocus`，
主按钮额外走 `UiConfirm`（金色扩散环 + 确认音）。
条件不满足时按 Enter 走 `UiDeny`（红描边 + 抖动 + 拒绝音）。

### 5.2 技能手牌（内容层）

`AdventureGame.cs:262` `DrawPortCard`，5 张 195×203。

| 项 | 要求 |
| --- | --- |
| 悬停 | 抬 3px（用 `y` 偏移，rect 高度不变）、描边 `#703843`→`#F6A7A9`、底色 `#49202A`→`#562833`、进入/退出 120ms/180ms |
| 选中 | 保留现有上移 8px + 金描边 2px + 底色提亮两档 + 右上角"已选"角标 |
| 不可用 | 现有半透明压暗保留（`Fill(..., a=0.3)`），额外加"不可用"灰描边，与"可用但未选"区分 |
| 说明 | 沿用 `GUIContent` 说明 → `GUI.tooltip` → 右侧面板，不新增气泡 |
| 分页 | 换页时卡片整体替换，按 `c.Id` 记忆动画状态，跨页保留悬停渐变进度 |
| 翻页入场 | 新一页的卡片从行进方向外侧滑进来（前进从右、后退从左），逐张错开 45ms，同时淡入 |

手牌的 `y` 已经依赖选中态（`639` / `647`）。悬停抬起叠加在其上时，最终 y = 基础 y − 选中偏移 − 悬停偏移，两者互不干扰（见坑 3）。

抬起量在"丰富"档才生效（2 档加卡片抬起，见 §7）。

### 5.3 右侧状态面板（内容层）

`AdventureGame.cs:275` `DrawPortOperationPanel`：

- 标题里的 `count`（已安排数）增加时：scale 1.15→1（180ms，弹性）+ 闪金一次。
- 「预留 X / 可用 Y cost」在 cost 变化时数字滚动 320ms，cost 增加闪金、减少闪红。
- 面板本身不缩放。它是信息容器，不是按钮。

### 5.4 顶栏数值

`AdventureGame.cs:166-167`：回合、cost、倒计时。

- cost 变化 → 320ms 滚动 + 闪色。
- 倒计时 ≤10 秒 → 转 `#D48178` 并每秒脉冲一次。

---

## 6. 声音

复用现有程序化正弦 `Tone()`，不引入音频资源。UI 音独立声源、独立音量，不与战斗音共用 0.25 的总音量。

| 事件 | 频率 | 时长 | 音量 |
| --- | --- | --- | --- |
| 按下 | 760Hz | 45ms | 0.14 |
| 确认（准备交锋、回合推进） | 660Hz → 990Hz 双音 | 120ms | 0.16 |
| 拒绝 | 180Hz | 120ms | 0.16 |
| 分段切换（专属/通用、翻页） | 520Hz | 30ms | 0.10 |
| 悬停 | 880Hz | 20ms | 0.07（要开到"音效 全开"才有） |
| 战斗命中 | 150Hz | 160ms | 0.25（现状不动） |

顶栏"声音：开/关"扩为三档：**全部关 / 仅战斗 / 全部开**。

| 档 | 战斗音 | 界面音 |
| --- | --- | --- |
| 全部关 | 无 | 无 |
| 仅战斗 | 有 | 无 |
| 全部开 | 有 | 有（还要"界面音效"档位允许） |

"界面音效"自己也分三档：**关 / 按键（按下、确认、拒绝、分段）/ 全开（再加悬停）**。
悬停音默认在"按键"档，也就是默认不响——鼠标扫过一排按钮是很吵的。

档位存在 `PlayerPrefs`（`clash.ui.tier` / `clash.ui.sound`），战斗音靠 `audioSource.mute` 一刀切，界面音走 `UiFeedback.UiSoundAllowed` 判定。

---

## 7. 设置项

设置条落在 Port 战斗顶栏左侧（设计坐标 36,26 起），三个小按钮：

- **动效强度**：`0 关 / 1 标准 / 2 丰富`。语义按实装定：
  - 0 关：只换颜色。不缩放、不回弹、不抖动、数字直接换。
  - 1 标准：悬停、按下下沉、4% 回弹过冲、数字滚动、确认扩散环。
  - 2 丰富：标准档之上再加卡片抬起 3px、计数弹跳 1.15→1。
- **界面音效**：关 / 按键 / 全开。与声音档相乘：只有"全部开"且该档位允许时才响。
- **声音**：全部关 / 仅战斗 / 全部开。

三者都存 `PlayerPrefs`（`clash.ui.motion` / `clash.ui.sound` / `clash.ui.tier`），进游戏时读回。
旧单场顶栏那个"声音：开/关"按钮也换成三档循环，与设置条共用同一份状态。

键盘提示行（底部那行说明）已经接上快捷键：悬停某个按钮时，右端贴一枚键帽，写着它的快捷键；
按下快捷键时键帽闪一下（220ms 衰减）。登记在绘制时做，`UiSetShortcut(id,keys)`。
当前登记的：主按钮 `Enter`、撤销 `Delete`、五张手牌 `1`–`5`。

---

## 8. 全局风险清单

1. **IMGUI 每帧多次进入 OnGUI**（Layout + Repaint）。动画状态一律在 `Update()` 推进，绝不在 `OnGUI` 里累加，否则速度翻倍。
2. **Layout 阶段不要画**。重绘绘制（Fill/Outline/Label）包在 `Event.current.type == EventType.Repaint` 里，省一半开销。
3. **自绘接管事件后不能再用 `GUI.Button`**，否则同帧触发两次。自绘按钮自己拿 `GUIUtility.GetControlID` + `hotControl`。
4. **缩放只作用于绘制，热区用原矩形**（坑 2）。
5. **描边宽度会随 `GUI.matrix` 缩放**。已按 `1/scale` 补偿（`UiStrokeScale()`），屏幕上恒为 1 像素。
6. **别抢拖拽连线那条链**。`BattlePlanningView.UpdateTargetLine` 已经 `input.Use()`，且靠 `GUIUtility.hotControl==0` 判断是否可起拖（`BattlePlanningView.cs:108`）。自绘按钮按下时设 `hotControl`，恰好会让拖拽判定为"指针被占用"，行为正确；但不要额外 `Use()` 掉 `MouseDown`。
7. **自绘后禁用态要自己画**。现在靠 Unity 皮肤自动变灰。
8. **全局只有一个 `Update()`**（坑 1）。
9. **自绘按钮需要稳定 id**。建议显式传字符串 id（如 `"port.primary"`、`"port.card."+c.Id`），过渡期可用标签+矩形哈希兜底。

---

## 9. 验收方式

沿用现有设施，不新增框架：

- **纯逻辑检查**：新增 `UiChecks`，覆盖插值收敛、弹簧过冲幅度、禁用不响应、已选不触发点击、拒绝计时衰减、缩放公式夹取。不需要真机。
- **抓帧**：`Capture()` 抓 BPM，人工比对悬停/按下/禁用/已选/焦点/确认六种外观。已有大量 `*Smoke` 流程可直接加抓帧点。
- **实机重点**：1440×900 与 1000×650 各跑一遍，确认指针对齐（见 9.1）、热区与视觉框重合、拖拽连线不受影响、Enter 键路径反馈正常。
- **交付路线**：仍走现有 Mono 播放器程序集补丁（`Tools/BuildLocalPlayer.ps1`），Unity 编辑器许可限制未变，不做完整编辑器构建。

### 9.1 指针对齐：已实测，结论推翻当初的假设

原设想是 `Event.current.mousePosition` 不在设计空间、要用 `GUIUtility.ScreenToGUIPoint` 换算。
实机跑下来是反的（`--ui-smoke` 打印）：

| 量 | 1440×900（scale 0.938） | 1000×650（scale 0.651） | 结论 |
| --- | --- | --- | --- |
| `event - analytic` | 3e-05 | -3e-05 | 事件坐标就是设计空间 |
| `ScreenToGUIPoint` 与 analytic 的差 | y 偏 337 | y 偏 273 | 这个不能信 |
| 洋红标记漂移 | 1.41px | 0.71px | 指针与光标重合 |

结论：**`Event.current.mousePosition` 直接可用**（在 `GUI.matrix` 设好之后读），
`GUIUtility.ScreenToGUIPoint(Input.mousePosition)` 不要用，它给的是 GUI 层坐标，和设计空间差一截。
解析换算 `UiAnalyticPointer()`（屏幕像素 → 设计空间）只在调试与注入时用。

配套结论：`Screen.SetResolution` 会留在 PlayerPrefs 里，冒烟前必须显式设回 1440×900，
否则采样落在别的分辨率上，坐标全错。

---

## 10. 待拍板

| 问题 | 结论 |
| --- | --- |
| 手牌选中上移 8px 是否保留 | 保留，改用"金描边 2px + 角标"加强区分，悬停抬 3px 叠加 |
| 主按钮底色 | 红白改版后定为浅底 `#F6DFDA` + 深字 `#45141E` |
| "全部缩放"是否接受小按钮 0.941 这种较大幅度 | 接受。若嫌小按钮抖，把小按钮目标下沉量降到 1.1px（scale 0.960） |
| 指针对齐是否作为第一批的前置门槛 | 是，已做完（见 9.1） |
| 动效档位语义 | 0 只换颜色；1 加缩放/回弹/滚动/扩散；2 再加卡片抬起与计数弹跳 |
| 声音分档 | 全部关 / 仅战斗 / 全部开，与"界面音效"档位相乘 |

第三批候选：角色立绘呼吸、翻页时卡片的落位微调、结算演出的镜头语言、命中时的白闪。
屏幕震动已提前落地，规格见 §12。

---

## 11. 实施状态（第一批 + 第二批 + 震动已落地）

| 项 | 状态 | 落点 |
| --- | --- | --- |
| 纯逻辑层：插值、弹簧、按钮状态机、数字滚动、计数弹跳 | 完成 | `Core/UiFeedback.cs`，102 项检查 |
| 纯逻辑检查 | 完成 | `Core/UiChecks.cs`（`ProjectTools.Validate` 一并跑） |
| 自绘按钮 + 指针 + 绘制层 | 完成 | `Presentation/UiFx.cs` |
| 战斗主按钮接入 | 完成 | `BattleGuidance.cs` `DrawPortCenteredActions` |
| 技能手牌接入（悬停抬起、描边） | 完成 | `AdventureGame.cs` `DrawPortCard` |
| 右侧面板计数与顶栏 cost 数值 | 完成 | `UiCountLabel` / `UiNumberLabel` |
| 指针对齐实机验证 | 完成 | `--ui-smoke` 标记漂移 ≤1.41px |
| 描边 `1/scale` 补偿 | 完成 | `UiStrokeScale()` |
| 界面音（按下/确认/拒绝/分段） | 完成 | `UiFx.cs` `UiSound*` |
| 声音三档 + 界面音效档位 + 动效档位 | 完成 | 顶栏设置条 `DrawUiSettingsStrip` |
| 键盘焦点环 | 完成 | `UiFeedback.SetFocus`，`UiKeyPress` 接管焦点 |
| 动效档位 0/1/2 的分层效果 | 完成 | `UiFeedback.MotionEnabled` / `RichMotion` |
| 键盘提示行的快捷键悬停显示 + 按下闪键帽 | 完成 | `UiHintLine`，冒烟实测 `HINT shortcut='Enter'` |
| 悬停音（要"音效 全开"） | 完成 | `UiSoundHover`，880Hz/20ms |
| 翻页时卡片方向性入场 | 完成 | `UiEntrance`，前进从右、后退从左，逐张错开 45ms |
| 确认后连线扫光 | 完成 | `UiTriggerClashSweep`，沿线 400ms 跑一道亮光 |
| 合法目标描边呼吸 | 完成 | `UiBreathingBorder`，1.2s 周期、幅度 15% |
| 角色立绘呼吸 | 未做 | 第三批（内容层） |
| 命中屏幕震动（拼点重、攻击轻） | 完成 | `Core/ScreenShake.cs` + `Presentation/ScreenShakeFx.cs`，见 §12 |

冒烟回归：guidance / forest / visual / compact / touhou / portrait / coin / ui 全绿；
`adventure-smoke` 仍挂在"victory rendering fixture"，那是改版前就有的旧账（存档基线同样失败），跟这批无关。

---

## 12. 屏幕震动（第三批 · 已落地）

需求原话：**"拼点的时候带有震动效果，攻击的时候也有轻微震动。"**
即：拼点 = 重、攻击 = 轻，两档手感必须一眼能分辨。

### 12.1 参数

| 触发 | 峰值幅度 | 时长 | 频率 | 说明 |
| --- | --- | --- | --- | --- |
| `clash` 拼点落点 | 9.0 px | 0.28 s | 19 Hz | 重。每轮重投各震一次 |
| `clash_end` 拼点落定 | 12.0 px | 0.34 s | 15 Hz | 最重。整轮拼完、结果拍板时 |
| `strike` 攻击命中 | 3.2 px | 0.13 s | 26 Hz | 轻。硬币打出去的那一下 |

幅度是**单轴峰值**，双轴同时生效：X 轴满幅，Y 轴按 0.55 缩放，所以斜向晃而不是纯水平抖。

### 12.2 数学

包络取 `(1-t)²`（起手快、收尾软），波形：

```
x(t) = A · (1-t)² · sin(2π f t)
y(t) = A · 0.55 · (1-t)² · sin(2π f · 1.37 t + 1.1)
```

- `t ≥ duration` 时位移**精确归零**，不留半像素残影。
- 频率刻意避开 60 fps 的整倍数（19 / 26 Hz），免得每帧采样落在同一相位上变成"卡住不动"。
- 新的触发会**替换**旧的一次震动并重新起算，不会叠加两条包络。
- 纯逻辑放在 `Core/ScreenShake.cs`（不引用 UnityEngine），可离线编译与检查。

### 12.3 作用范围

**只震战场里的内容**：单位立绘、拼点火花、硬币面板、伤害数字。
**不震**：战斗面板外框、顶栏、状态条、手牌、右侧操作面板。

做法是给战场内容整体套一层 `GUI.matrix` 平移，画完立刻还原。
这样外框不会和内容之间裂开一条缝，指针热区也不受影响（演出期间按钮本来就是禁用的）。

### 12.4 档位与其它约束

- 动效档位 **0（动效 关）不抖**，与"0 档只换颜色，不缩放不抖动"一致。
- 震动计时走 `UiTick`（未缩放时间），**不跟着演出倍速跑**：4 倍速下时长仍是 0.28 秒的手感。
- 4 倍速时连续事件可能撞在一起（后一次触发替换前一次），这是取舍：宁可不叠加，也不要抖成一团。

### 12.5 验收

| 层 | 手段 | 结果 |
| --- | --- | --- |
| 纯逻辑 | `Core/UiChecks.cs` `ShakeImpactsDecay()` | 15 项：闲置为 0、峰值不超幅、到点归零、攻击 < 拼点、`clash_end` > `clash`、零幅不触发、重复触发替换、`Stop()` 清空 |
| 实机 | `--compact-smoke` | 拼点峰值 8.19 px，攻击峰值 2.68 px |
| 实机（画面真的动了） | 同上，抓两帧比亮像素质心 | 演出阶段被 hold 住的两帧之间，横向重心移动 1.85 px（面板外框不动） |
| 实机（写进了矩阵） | 同上，读 `shakeApplied` | 落点后矩阵里确实有位移 |
| 回归 | `--ui-smoke` / `--visual-smoke` | 全绿，旧版单场战斗路径无回归 |

逐帧位移轨迹（x / y，单位 px，拼点落点后连续采样）：

```
7.8/1.8  8.2/-0.6  7.3/-2.8  5.3/-4.0  2.6/-4.1  -0.3/-3.0  1.5/0.3  0.5/-0.5  -0.5/-1.1  -1.3/-1.3
```

### 12.6 顺带修掉的一个旧账

`--compact-smoke` 一直没确认技能组，`loadoutSelecting` 一直为真，
`DrawPortBattle` 每帧提前返回到选卡界面——**规则在跑，画面上根本没有战场**，
那批 `compact-*.bmp` 截图拍的一直是选卡界面。
补上 `ConfirmSkillGroups()` 后截图里才是真战场，震动的像素级验证也才有着落。

## 13. 招募战与 PVP 的界面适配

- 普通遭遇、招募战、PVP 和旧单场使用同一套战斗震动。招募战和 PVP 的最后一轮拼点直接使用落定强度，沿用现有的播放事件。
- 位移只应用于立绘、火花、硬币和伤害数字。外框、生命条、状态徽标、手牌与点击热区保持固定。
- 各战斗模式共用动效与声音设置。关闭动效立即清除位移。跳过演出、退出或中止对战时也会清除位移。
- 合法目标的描边悬停时转金，关闭动效时保留静态高亮。有效倒计时剩余 10 秒时变红，动效开启时轻微脉冲。
- 本次接入的范围是界面反馈。角色立绘待机呼吸、白闪与进一步的镜头设计保留为后续候选。
