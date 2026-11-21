# 余烬交锋 · Godot 4 战斗与探索工程

本目录（`battle-demo/`）包含《余烬交锋》的核心 Godot 工程源码，涵盖单场战斗演习、阳光林野探索地图、尖塔卡组循环与战斗演进系统。

![行动规划画面](preview/planning.png)

---

## 🎮 运行方式

### 1. 运行免安装发布包（推荐）
- 前往 **[Releases 页面](https://github.com/zixinyc/clash-roguelike/releases/latest)** 下载 `ClashRoguelike_Windows_v0.4.0.zip`；
- 解压后双击根目录下的 **`余烬交锋.exe`** 直接进入游戏，已内置独立游戏引擎与全量编译资源。

### 2. 使用 Godot 4 源码运行
- 下载 [Godot 4.7.2 标准版](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)；
- 在 Godot 启动器中点击「导入」，选择 `battle-demo/project.godot`；
- 按 **F5** 启动主场景 `battle_setup.tscn`（阵容配置、探索模式与演习模式入口）；
- 也可在编辑器内直接按 **F6** 独立调试特定场景（如 `exploration_map.tscn` 或 `main.tscn`）。

---

## 🕹 玩法说明与交互指引

1. **阵容与整备**：
   - 自由选择 1～3 名出战角色与对战敌组；
   - 探索模式自动构建 10 张初始精简卡组，初始持有 18 Cost。
2. **行动出牌与规划**：
   - 选中攻击牌后，敌方行动槽展示 `🟢 迎击`、`💠 拦截`、`🟡 单打`、`⚡ 夹击` 等关系微标；
   - **左键直点** 高亮敌方槽即可快速安排出牌；拖拽箭头可查看实时判定胶囊；
   - **防御牌安排**：选中防御牌直接点击我方蓝色防守槽；
   - **撤销安排**：右键点击已安排的我方槽快速撤销并释放预留 Cost；
   - **大招格放攻击牌**：开启 `flex_attack_in_ultimate`，单角色可在攻槽与大招槽同时安排攻击牌；
   - **单方夹击加成**：非拼点攻击与夹击造成额外 **+3 伤害**。
3. **废林探索旅程**：
   - 每回合投掷 **1d4 行动骰** 决定探索步数，高疲劳（`>=6`）扣 1 步且保底 1 步；
   - 战后 3 选 1 符卡奖励（可跳过折算 +2 Cost）；
   - 探索商店提供售卡货架与 5 Cost 删牌精简；
   - 锻台节点提供 4 Cost 符卡附魔（轻灵减费、破势拼点 +1）。

---

## ⌨️ 快捷键速查

| 按键 | 功能 |
| :--- | :--- |
| **1 ～ 9** | 选择手牌区第 1 到第 9 张牌 |
| **Space (空格)** | 自动安排当前角色可打出的手牌 |
| **Enter (回车)** | 锁定规划，准备交锋并进入战斗演出 |
| **Delete** | 撤销最后一个安排的行动槽 |
| **顶部 1x / 2x / 3x** | 切换战斗演出倍速 |

---

## 🧪 自动化测试验证

在仓库根目录使用 PowerShell 运行自动化测试：

```powershell
$godot = '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'

# 跑通全部 25 套测试 (22 个无头测试 + 3 个真实视口渲染测试)
Get-ChildItem -Path battle-demo\tests\test_*.gd | ForEach-Object {
    $file = $_.Name
    if ($file -match '_render\.gd$') {
        & $godot --path battle-demo --script "tests/$file"
    } else {
        & $godot --headless --path battle-demo --script "tests/$file"
    }
}

# 规划图形流程烟雾测试
& $godot --path battle-demo -- --planning-smoke
```

---

## 📁 目录与模块索引

* **`scripts/`**：核心玩法代码
  * `battle_rules.gd`：战斗底层规则、抽弃牌堆流转、硬币拼点、有效费用计算与状态机
  * `card_pool.gd`：37 张符卡稀有度、同名上限与 3 选 1 算法
  * `forest_run.gd`：探索局内状态、1d4 骰子 RNG、卡牌 UID 实例与锻台附魔持久化
  * `exploration_map.gd`：左图右栏手记探索 UI、立体骰盘、3 选 1 弹窗与锻台附魔面板
  * `map_visuals.gd`：阳光林野矢量徽章、丁达尔光束、晨雾云霭绘制工厂
  * `battle_stage.gd` & `planning_ui.gd`：54×48 战术槽、动态高亮关系标签与战斗舞台
* **`tests/`**：25 个全覆盖测试套件
* **`preview/`**：文档与商店展示截图
* **`export_presets.cfg`**：Godot 4 Windows Desktop 导出配置
