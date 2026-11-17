# touhou · Unity 单机成品分支

本分支新增可编辑的 **Unity 2022.3.62f3c1** 工程和 **Windows 64 位运行包**，包含森林节点地图、迷雾探索及 2026-11-17 新拼点/逐枚硬币攻击机制。main 分支保留；本分支同步角色设计的 Godot 参考，Unity 为新规则可玩主线。

- [直接下载 Windows 完整成品](https://github.com/zixinyc/clash-roguelike/raw/refs/heads/touhou/releases/ClashRoguelike-Unity-Windows-touhou.zip)：解压后运行 ClashRoguelike.exe，试玩不需要安装 Unity。
- 或下载本分支整个 ZIP，解压后双击根目录 **启动Unity单机版.cmd**。
- [Unity 工程、运行与构建说明](unity-client/README.md)。
- [新拼点机制、效果扩展、修改清单和 12 项验收](unity-client/COIN_SYSTEM.md)。
- [项目清单：已有成果、未完成和待讨论](unity-client/PROJECT_INVENTORY.md)。
- [角色设计与兼容说明](unity-client/ROLE_INTEGRATION.md)：博丽灵梦、十六夜咲夜、8个专属技能和最新状态/居中操作界面。
- [实际验证与构建限制](unity-client/VALIDATION.md)。七组共 **3,647** 项断言，实际新战斗与森林撤离通过。

本轮使用既有 Unity Mono 播放器重新编译程序集并验收；本机许可限制尚未解决，未声称完成编辑器全量构建。旧追击额外攻击已停用；多人/PVP、存档和正式美术未完成。Godot 的 battle-demo 同步了角色源分支但保留其规则差异，请用 Unity 成品验证新硬币机制。已同步主分支最新打击反馈，Unity 具备蓄力、命中停顿和接触音效。角色入口：森林设置 → 角色测试，或单场顶部切换阵容。

![新拼点实机](unity-client/Preview/coin-clash.png)

---

以下保留原 main 分支的 Godot 项目说明，作为参考与协作历史。

# Clash Roguelike｜拼点肉鸽

探索《边狱巴士》式拼点战斗与《杀戮尖塔》式卡牌构筑、随机路线和战后成长的结合，由朋友共同协作开发。

**当前阶段：Godot 单场战斗原型。已提供可下载、可修改的源工程，支持敌方先规划、隐藏技能与公开箭头、角色随机速度、多行动格、180 秒响应、拼点与 cost。**
## 这是总文档
## 下载与运行

1. 点击 **Code → Download ZIP** 下载 main 分支源码并解压，或使用 Git 克隆仓库。
2. 下载 [Godot 4.7.2 标准版](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)，不需要 .NET 版。
3. 在 Godot 中导入 **battle-demo/project.godot**，按 **F5** 运行。
4. 点击游戏右下角的 **自动安排**，再点击 **准备完成**，或自己拖动行动箭头安排出牌。

[完整运行与修改说明](battle-demo/README.md)。源码 ZIP 不包含引擎和独立游戏安装包。

![单场战斗画面](battle-demo/preview/planning.png)

## 想做出的体验

- 对抗：双方技能比拼威力，硬币破坏会改变后续交锋。
- 演出：前冲、对撞、破币与追击，让每次胜负有清晰的画面和声音反馈。
- 构筑：通过技能、卡牌和成长奖励，形成不同的应对方式。
- 冒险：在分岔路线、战斗和事件之间选择，完成一局可反复挑战的旅程。

已确定采用小队、手牌与拼点，出牌与购物共用可跨战斗保留的 cost 钱包；战斗具有基础与表现收入、出牌限制和失败部分退款。具体数值、角色数量、操作方式与美术风格仍在讨论。

## 从这里开始

| 你想了解什么 | 文档 |
| --- | --- |
| 下载、运行或修改当前战斗原型 | [Godot 战斗演示](battle-demo/README.md) |
| 当前确定了哪些玩法，哪些数值还在测试 | [玩法设计草案 v0.1](docs/玩法设计/玩法设计草案.md) |
| 如何和朋友一起使用仓库 | [GitHub 公有仓库协作指南](docs/协作指南/GitHub协作指南.md) |
| 有哪些可参考的项目，拼点如何实现 | [技术调研](docs/技术调研/拼点肉鸽技术调研.md) |
| 接下来分几步开发 | [开发路线](docs/玩法设计/开发路线.md) |
| 想和朋友讨论技能或 hunter | [文档讨论](docs/文档讨论/README.md) |
| 所有文档与当前状态 | [按分类查看文档](docs/README.md) |

## 技术方向

已选择 Godot 4 与 GDScript。当前原型将战斗结算与动画播放分开，使用确定的随机种子与事件记录；加速演出不改变规则结果。

当前优先通过单场战斗试玩验证拼点规则和手感，再讨论后续地图、成长与联机。

## 一起协作

1. 在 [Issues](https://github.com/zixinyc/clash-roguelike/issues) 记录想法、任务或问题，一件事写一个 Issue。
2. 动手前写明认领人、改动范围和完成标准，避免两个人重复修改同一处。
3. 从最新的 `main` 创建任务分支，例如 `docs/combat-ideas`。
4. 完成后发起 Pull Request（PR，合并申请），让另一位成员检查改动后合并。

这些是团队建议，尚未通过分支保护强制执行。具体网页操作见[协作指南](docs/协作指南/GitHub协作指南.md)。

## 素材与许可

参考作品用于说明玩法灵感，本项目与其开发商无关联。新增角色、美术、音乐和动画应使用原创或获得许可的素材，并记录来源。

本仓库原创代码、程序绘制内容与文档采用 [MIT 许可证](LICENSE)，允许使用、修改、再分发及商业使用，分发时保留版权声明和许可文本。Godot 引擎与其他第三方内容遵守各自许可证。