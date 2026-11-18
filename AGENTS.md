# 《余烬交锋》项目协作约定

## 项目入口

- 主工程在 `battle-demo/`。单场从 `battle_setup.tscn` 配置队伍后进入 `main.tscn`，废林从 `exploration_map.tscn` 进入，同样实例化 `main.tscn`。启动与测试命令见 [原型 README](battle-demo/README.md)。
- 本机便携 Godot 可用 `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`。记录实际 `--version` 输出和渲染后端。`project.godot` 的 `4.3` feature tag 与本机可执行文件版本各自记录。
- 功能入口见 [架构索引](docs/原型架构与功能索引.md)。文档中的历史固定地图、牌面或测试数量可能落后，接手先核对当前 Git 差异、运行入口和测试。

## 状态归属

- `battle_rules.gd` 的 `DemoBattleRules` 管理纯 GDScript 规则、费用、战斗 RNG 和结算事件。`lock_and_resolve()` 锁定规划并产生事件序列，`planning_ui.gd` 消费快照，`battle_stage.gd` 与 `synth_audio.gd` 播放表现。动画时长、倍速和音效 RNG 与战斗结果独立。
- `forest_run.gd` 的 `ForestRun` 管理单局探索的阵容、卡组、生命、`carried_cost`、遗物与消耗品。换人按角色稳定 ID 核对状态，跨层使用同一个 run，重开创建新的 run。探索场景负责接桥，地图基础胜利奖励由 `apply_battle_result()` 发放，修改奖励时同步核对战斗侧遗物奖励和回写路径。
- 当前手牌每回合按配置牌恢复，`card_key` 是牌型稳定标识，`hand` 下标和行动格 ID 只属于当前战斗。通用牌为队伍共享。少人补格可以集中在同一角色身上，改打断规则时以实际待结算行动和配对关系验收。
- 改牌要同时追踪牌面及目标提示、手动和自动安排、预留、锁定扣费、退款、角色专属效果和上下层传值。修改拼点时区分单次掷币、整次拼点的最终胜负、后续攻击掷币及其 RNG。

## 回归与交接

- 改代码前确认 `git status`，保留并行工作区改动。用本机 Godot 按实际测试入口跑基线。2026-11-18 的盘点为 21 个 `tests/test_*.gd`，其中三个 `*_render.gd` 要真实视口，`test_rules.gd` 继承 `test_planning.gd`。新增规则用固定种子或可控投掷测关键分支。渲染、声音听感和真人平衡按实际验证情况报告。
- 使用正常入口验收战斗和地图回写，记录可复跑命令、用例及通过范围。引擎缓存和测试截图使用项目已有忽略目录。
- [战斗演进审查与阶段提示词](docs/协作指南/战斗演进审查与阶段提示词.md) 是失衡、压制、附魔、羁绊、演出的派工入口。里面的试验参数与规则取舍是待确认提案。接手按阶段读取已确认契约和上一阶段证据，需求确认状态记录在任务文档。
