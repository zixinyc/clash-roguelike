# Unity 试玩项目

## 试玩与编辑

- Windows x64 玩家可直接解压 [试玩包](../releases/ClashRoguelike-Unity-Windows-touhou.zip)，运行 `ClashRoguelike.exe`。同目录下的 `ClashRoguelike_Data`、`MonoBleedingEdge` 和 `UnityPlayer.dll` 需要一起保留。
- Unity Hub 添加本目录，使用 **Unity 2022.3.62f3c1**，打开 `Assets/Scenes/Battle.unity` 后点 Play。可以从 `Clash Roguelike` 菜单运行规则检查或构建 Windows 版。
- 本次试玩成品使用现有 Windows Unity Mono 运行时与重新编译的游戏程序集。若使用 `Tools/BuildLocalPlayer.ps1` 更新程序集，先把试玩包解压至 `Builds/Windows/`，然后在 PowerShell 7 运行该脚本。

## 操作

点击高亮的相邻石板移动。进入功能格后可查看结算，位于上层入口或下层传送时可花一行动切层。地图按 Enter 结束回合。单机在第五层取石通关。设置可切换为本地双队，同机轮流操作，持石队须从第三层或第四层撤离。战败在原层永远亭休整一个地图回合。

战前每名角色有 A/B 两套方案，每套保留 1–4 张专属技能，通用牌另计。确认后按己方角色、技能、目标的顺序安排。配装记忆保留于当前游戏会话。设置保留旧预设地图，`--grid` 和 `--legacy` 分别进入旧网格和旧单场演示。

[更新内容、已验收路径与剩余事项](VALIDATION.md)
