# 余烬交锋 · Godot 原型

从阵容与卡组开始打单场，或从废林探索进入多层地图。配置、引导和场景以本分支为准。

![行动规划画面](preview/planning.png)

## 运行

- **可运行打包版本**：直接运行打包目录（`余烬交锋_Windows/`）下的 `余烬交锋.exe` 即可进入游戏，已内置游戏引擎与全部资源包。
- **源码运行**：使用 [Godot 4.7.2 标准版](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) 导入本目录的 `project.godot` 后按 **F5** 进入阵容与探索主页。要直接进入废林探索，也可直接运行 `exploration_map.tscn`。

## 怎么玩

1. 选 1～3 名角色、携带牌和敌组。开战后选中角色或行动格可看专属牌，「通用」显示全队共用牌。
2. 选牌后拖我方行动格到敌方目标，或使用目标下拉框和「安排」。防御牌可以直接安排。安排先预留 cost，可撤销或替换。
3. 点击「准备交锋」开始结算。可先用「自动安排」填格。数字键选择当前组的牌，空格安排，Enter 开战，Delete 撤销。上方可切换演出倍速。
4. 废林里沿可达路径行动，战斗结束后返回地图。商店可以补给与整备。战斗的规划阶段可从右上角「道具」查看并使用已携带的消耗品。

费用、速度与接招见[行动规划与速度](../docs/玩法设计/行动规划与速度.md)。角色练习见[角色资源试玩](../docs/玩法设计/行动规划与速度.md#角色资源试玩)。

## 验证命令

在仓库根目录运行 PowerShell。本机便携版示例如下，其他安装替换 `$godot`。

```powershell
$godot = '.\.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --version
& $godot --headless --path battle-demo --editor --import --quit
& $godot --headless --path battle-demo --script tests/test_rules.gd
& $godot --headless --path battle-demo --script tests/test_forest_map.gd
& $godot --headless --path battle-demo --script tests/test_stagger_overwhelm.gd
& $godot --path battle-demo -- --planning-smoke
```

- 按改动选跑 `battle-demo/tests/test_*.gd`。每个 `*_render.gd` 需要实际视口，运行对应脚本时去掉 `--headless`。`test_rules.gd` 继承 `test_planning.gd` 的基础断言。
- 最后一条跑一轮图形规划流程并截图。`test-output/` 与 `.godot/` 都是项目忽略目录。
- 本项目配置 GL Compatibility。`project.godot` 的 `4.3` 是 feature tag，实测引擎版本看 `--version`。记录平台、渲染后端及真实通过范围。

## 开发与历史

任务接手见 [AGENTS.md](../AGENTS.md)，源码入口见[架构索引](../docs/原型架构与功能索引.md)。初期玩法参数与历次验收见[文档导航](../docs/README.md#按问题查旧记录)。

原创代码、程序绘制内容与文档采用 [MIT 许可证](../LICENSE)。第三方素材与 Godot 各自遵守其许可证。[素材清单](../asset/素材清单.md)
