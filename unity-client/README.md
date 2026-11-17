# Unity 主 Demo · 东方三人队与 ZiXi

使用 Unity 2022.3.62f3c1。下载 `releases/ClashRoguelike-Unity-Windows-touhou.zip`，完整解压后运行 `ClashRoguelike.exe`，试玩无需安装 Unity。仓库根目录启动脚本也可解压并运行。

默认进入魔理沙、咲夜、灵梦组成的森林探索。主地图顶部“队伍 / 更换”可选择东方三人、ZiXi队或原小队；选择“开始新探索”后才重置。ZiXi队为灰烬、ZiXi、织火，和东方队使用同一地图与战斗流程。`--zixi` 直接进入ZiXi森林，`--battle` 进入当前阵容单场，`--original-team` 使用原小队。

- [主 Demo 人物、文件清单、验收与限制](MAIN_DEMO.md)
- [人物技能兼容约定](CHARACTER_INTEGRATION.md)
- [当前项目清单](PROJECT_INVENTORY.md)
- [当前硬币规则](COIN_SYSTEM.md)
- [当前验收记录](VALIDATION.md)

通过 Unity Hub 添加本目录，打开 `Assets/Scenes/Battle.unity`。若具有有效编辑器许可，可使用项目原有编辑器构建菜单；本机许可问题未解决，本次采用既有 Windows Mono 播放器重新编译 C# 程序集，已实际运行，不是新的编辑器全量构建。解压运行包到 `Builds/Windows` 后，Windows PowerShell 运行 `Tools/BuildLocalPlayer.ps1` 可重新编译并执行八组检查。`Builds`、Unity缓存、个人设置与本机诊断日志不入源码。

本轮保留 G 盘已经更新的攻击硬币加值累计规则、紧凑界面、状态详情、速度和打击反馈，没有恢复早期逐击重置方案。角色仍采用占位外形；Unity自由混编、少人队伍、存档、多人和正式平衡未完成。Godot参考的阵容/卡组功能与Unity预设队伍存在差异。