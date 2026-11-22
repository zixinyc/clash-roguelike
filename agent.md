# 《余烬交锋｜Clash Roguelike》Agent 必读协作指引

> **[!IMPORTANT] 必读要求（Mandatory Reading）**  
> 任何 Agent 或开发者在接手本仓库、审查代码或修改功能前，**必须先阅读以下压缩代码全景文档**：  
> 👉 **[`docs/代码速查/代码全景与模块指南.md`](docs/代码速查/代码全景与模块指南.md)**  
> 该文档将项目 GDScript 浓缩为直观的数据流图、模块职责表、关键数据结构与测试护栏，人类与 Agent 均可在 3 分钟内掌握全局，避免盲目扫盘。

---

## 1. 快速上手三步走

1. **先读架构速查**：阅读 [`docs/代码速查/代码全景与模块指南.md`](docs/代码速查/代码全景与模块指南.md)，定位你要修改的模块文件。
2. **检查工作区状态**：运行 `git status --short --branch`，确认当前是否有并行开发的未提交文件（例如 `scripts/characters/ziwu.gd` 等），切勿覆盖他人或并行子 Agent 的改动。
3. **遵守美术与测试护栏**：
   - **视觉一致性**：所有新增或重构的 UI 界面必须统一使用 `battle-demo/scripts/map_visuals.gd`（`ForestMapVisuals`）的**晨曦阳光林野 + 胡桃木底色 (`#33261a`) + 黄铜金镶边 (`#d6a447`) + 羊皮纸 (`#f6edd8`)** 风格，严禁使用旧版冷蓝灰测试配色。
   - **逻辑与视图分离**：战斗规则只进 `battle_rules.gd`，探索状态只进 `forest_run.gd`，UI 脚本只消费状态快照与事件。
   - **测试不破损**：修改 `battle_setup.gd`、`exploration_map.gd` 或 `planning_ui.gd` 时，必须保留自动化测试（如 `tests/test_battle_setup.gd`）所依赖的节点名（如 `%ClearLineup`）与属性引用。

---

## 2. 核心路径导航

| 目录 / 文件 | 说明 |
| :--- | :--- |
| [`docs/代码速查/代码全景与模块指南.md`](docs/代码速查/代码全景与模块指南.md) | **【必读】** 架构、核心脚本、角色机制、数据结构与改动导航 |
| [核心脚本定位](docs/代码速查/核心脚本定位.md) | 通过文件和函数签名定位本轮常用入口 |
| [五层远征与敌方强化](docs/代码速查/代码全景与模块指南.md#五层远征与敌方强化) | 第 1～4 层选择规则、战斗数值传参和第 5 层通关接点 |
| [拼点概率与探索奖励](docs/代码速查/代码全景与模块指南.md#拼点概率与探索奖励) | 正面率、节点与战后奖励入口，含命运石之门和全队强化方案 |
| [`battle-demo/project.godot`](battle-demo/project.godot) | Godot 4.7.2 主工程配置（主场景入口为 `res://battle_setup.tscn`） |
| [`battle-demo/scripts/`](battle-demo/scripts/) | 全部核心 GDScript 源码（探索、战斗、UI、视觉、音频与 `characters/` 角色模块） |
| [`battle-demo/tests/`](battle-demo/tests/) | 自动化回归测试脚本（`test_*.gd`），按当前文件清单选跑 |
| [`asset/素材清单.md`](asset/素材清单.md) | 战斗特效（`fx/`）、音效（`sfx/`）与第三方开源参考清单 |
| [`asset/背景音乐计划.md`](asset/背景音乐计划.md) | 暗潮风格分层 BGM 规划方案 |
| [`idea/`](idea/) | 待讨论与扩展的设计想法（如阵容组合 Buff、界面演进） |

---

## 3. 并行开发与验证约定

- **并行开发切分**：不同子 Agent 并行工作时，应按「主界面与联机大厅（`battle_setup.gd`）」、「角色与羁绊规则（`battle_rules.gd` + `characters/`）」、「探索事件与遗物扩展（`forest_run.gd` + `relic_system.gd`）」解耦分工。
- **验证命令**：每次完成阶段性代码更新后，使用 `.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path battle-demo --script "tests/test_xxx.gd"` 进行回归校验，确保前面功能 100% 完整。
