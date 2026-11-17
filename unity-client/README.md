# 余烬交锋 · Unity 单机版

`touhou` 分支交付：森林节点地图、真实迷雾、角色规划、拼点与逐枚硬币攻击。更新于 2026-11-17。

当前主工程在 `unity-client/`，Godot 参考工程继续保留在 `battle-demo/`。本轮新拼点规则实现在 Unity 中；分支名不代表本轮已重做为东方人物题材。

## 直接试玩 Windows 成品

不需要安装 Unity。可选以下任一方式：

1. 下载本分支完整源码 ZIP，解压后双击仓库根目录的 `启动Unity单机版.cmd`。它会把 `releases/ClashRoguelike-Unity-Windows-touhou.zip` 解压到 `unity-client/Builds/Windows/` 后启动。
2. 单独下载上述 Windows ZIP，解压到一个文件夹，运行其中的 `ClashRoguelike.exe`。请保留旁边的 `_Data`、`MonoBleedingEdge` 和 `UnityPlayer.dll`，不要只复制 EXE。

本成品是 Windows 64 位 Unity Mono 播放器。完整运行包及校验值在 `releases/`。压缩包需要先解压，不能直接在压缩软件内运行 EXE。

## 怎么玩

- 默认进入单机森林：点击相连的亮起节点移动，寻找中心祭坛，打赢精英取得烬核，再到归途石门撤离。右侧是本局资源、状态、日志和受视野限制的环境情报。
- 战斗先点己方角色，再点技能，最后点敌人或敌方具体行动格。每人最多两种分类行动；准备完成锁定，演示一回合才付费并执行。
- 拼点每轮重投双方全部余币；平局均不损币，败一轮少一枚；一方归零后，只有胜方按余币逐枚攻击。每击重新从初始点数计算。
- 拼点和攻击加值是独立字段，卡面分别显示；演出显示每轮/每击的正反面、公式、破币、余币与累计原始伤害。右下战斗记录可以滚动。
- 地图 Enter 结束回合；战斗 Enter 准备/演示，1–5 选当前页技能，Delete 撤销。R 重新探索；退出目前不保存。
- 地图设置中可进入保留的旧网格。命令行 `--grid` 进入旧网格，`--legacy` 进入旧单场；两个 Unity 战斗入口都已使用新硬币规则。

## 使用 Unity 修改工程

1. Unity Hub 添加 `unity-client/`，使用工程记录的 **Unity 2022.3.62f3c1**。
2. 打开 `Assets/Scenes/Battle.unity`，点击 Play。运行时初始化会建立界面。
3. `Clash Roguelike / Run rule checks` 执行检查；`Clash Roguelike / Build Windows game` 使用现有构建入口输出 Windows 版。

工程沿用 C# 与 IMGUI，没有更换框架。当前依赖只有 Unity 内置 audio、imgui 模块。源码不包含 Library、Temp、UserSettings 等本机缓存。

公开副本清空了未使用的主机平台口令和签名配置字符串，保留当前 Windows 配置；本地项目中的配置未改。开发其他平台时需自行配置相应平台资料。

本机 Unity 编辑器许可校验受限，因此本次通过既有 Windows Mono 播放器重新编译 C# 并实机验收；**不是一次新的编辑器完整构建**。已提供可运行成品，不要求试玩者先解决编辑器许可。其他机器的编辑器构建尚未验收。

## 沿用当前本地编译方式

先把 `releases` 中的播放器解压到 `unity-client/Builds/Windows`。然后在仓库根目录的开发用 PowerShell 中运行：

```powershell
& .\unity-client\Tools\BuildLocalPlayer.ps1
```

脚本调用 Windows .NET Framework 的 C# 编译器，引用该播放器的程序集，运行六组检查，全部通过后才替换 `Assembly-CSharp.dll`，同时备份旧程序集。此方法针对当前 **Mono** 版，不适用于 IL2CPP。编辑器完整构建仍使用上方菜单。

播放器参数 `--coin-smoke=绝对目录`、`--forest-smoke=绝对目录`、`--adventure-smoke=绝对目录`、`--visual-smoke=绝对目录` 分别运行新硬币、森林、旧网格、旧单场验收。验收会自动操作本局、写测试文件并退出；平常试玩不要加这些参数。

## 规则与测试

[新硬币系统说明](COIN_SYSTEM.md) 包括修改清单、完整流程、效果接口、12 项验收对应证据和冲突处理。[验收说明](VALIDATION.md) 区分模型断言、实机自动流程和实际输入范围。

六组共 **3,561 项断言通过**。新规则实际普通战胜利，森林普通/精英战与撤离回归通过；1440×900、1000×650 已查看。地图数据与绘制文件未改，速度接招规则保留。

旧“余势追击”额外攻击效果违反新规则，已停用并在卡面说明，等待重新设计。当前已有牌的两种加值分别继承原值，不代表它们绑定。多人/PVP、存档、正式美术、JSON 热加载和具体复杂状态效果尚未完成。严格规则下永远等点的配置会一直重投，界面可响应；未擅自加入强制判胜，详情见系统说明。
