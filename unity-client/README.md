# Unity 随机关卡与战斗UI雏形

Unity 2022.3.62f3c1。解压仓库 releases 内 Windows ZIP，运行 ClashRoguelike.exe，试玩无需安装Unity。也可双击仓库根目录启动脚本。

默认进入随机森林；地图设置可输入种子复现、重新生成或打开原预设/旧网格。主地图顶部可以更换东方三人、ZiXi或原小队。遇敌后先给每名角色选择A/B技能组，再安排本回合行动。连线显示拼点或单方面攻击，基础风险分平衡/优势/劣势。角色直接在原战场上交锋，硬币跟随人物，已兼容本地新导入的三张东方透明立绘。

- [本轮功能、全部改动、风险定义与未完成项](PROTOTYPE.md)
- [已有主Demo与人物](MAIN_DEMO.md)
- [当前硬币规则](COIN_SYSTEM.md)
- [实际验证记录](VALIDATION.md)

通过Unity Hub添加本目录，打开Assets/Scenes/Battle.unity。解压运行包到Builds/Windows后，Windows PowerShell运行Tools/BuildLocalPlayer.ps1可重新编译并运行九组检查；编辑器菜单也保留检查入口。由于本机许可问题，本次交付使用既有Windows Mono播放器重新编译程序集，已实际运行，未声称完整Editor/IL2CPP构建。

技能组暂存于当前会话、未写磁盘；风险是基础牌面估计而非完整胜率，不泄露隐藏敌方技能；动画为已有立绘位移/倾斜/刀光雏形。保留当前速度、攻击累计规则及角色数值。正式构筑存档、完整预测、骨骼动画、联机尚未完成。
