# 东方异像谭 · Unity 项目

## Windows 试玩

解压 [Windows x64 试玩包](../releases/ClashRoguelike-Unity-Windows-touhou.zip)，运行 `ClashRoguelike.exe`。保留同目录下的 `ClashRoguelike_Data`、`MonoBleedingEdge` 和 `UnityPlayer.dll`。下载整个分支的 ZIP 后，也可在解压目录双击根目录的 `启动Unity单机版.cmd`。

- 普通探索有五层，抵达第五层取得异动石即可通关。红魔馆有四场招募挑战，战胜后解锁相应角色。
- 人机 PVP 有四层，从五个主题中随机选取四个。同格遭遇后，双方各自选技，准备后统一结算。持有异动石的一方需要找到出口撤离。
- 战斗选中己方立绘和符卡后点击敌人指定目标。未在指定目标时，可点敌方立绘查看技能资料。顶栏可调动效与声音。

完整操作、角色与技能见[游戏说明书](游戏说明书.md)。

## 编辑与构建

1. 在 Unity Hub 添加本目录。项目使用 **Unity 2022.3.62f3c1**。
2. 打开 `Assets/Scenes/Battle.unity`，点击 Play。
3. 从 `Clash Roguelike` 菜单打开规则检查或构建 Windows 版。也可在 PowerShell 7 使用 `Tools/BuildLocalPlayer.ps1`，前提是 Windows 试玩包已解压至 `Builds/Windows/`。

当前提供的成品复用了 Windows Mono 播放器，并重新编译了游戏脚本。[更新与运行验收](VALIDATION.md) · [界面反馈设计](UI_FEEDBACK_DESIGN.md)
