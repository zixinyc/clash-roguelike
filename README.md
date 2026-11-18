# touhou · 东方竹林与角色修订

这个分支包含《神秘拼点小游戏》的 Unity 试玩版。默认使用东方三人队，可在游戏中切换为 ZiXi 队或原小队。

- [下载 Windows 试玩版](releases/ClashRoguelike-Unity-Windows-touhou.zip)。解压后运行 `ClashRoguelike.exe`，无需安装 Unity。下载整个分支源码后也可以双击根目录的 `启动Unity单机版.cmd`。
- [Unity 项目与操作说明](unity-client/README.md)。源码位于 `unity-client/`。
- [本次更新与实机验收](unity-client/VALIDATION.md) · [下载包 SHA-256 与自动检查](releases/build-manifest.json)。

主地图采用斜俯视石板路。单机走五层并取得异动石，本地双队在第四层取得异动石后需要追踪和撤离。角色修订包含魔理沙、咲夜、灵梦的已确认技能调整，以及每名角色独立的 A/B 配装方案。

Godot 参考工程仍在 `battle-demo/`。
