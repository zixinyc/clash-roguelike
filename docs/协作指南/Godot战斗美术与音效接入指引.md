# Godot 战斗美术与音效接入指引

适用于《余烬交锋》`battle-demo/` 原型。第一批接入拼点火花、命中冲击环、拼点音和命中音，分别验收后再接入失衡、大招和其余界面声音。

## 从素材库挑选运行时文件

`asset/fx/` 和 `asset/sfx/` 是源素材库。目前本机有 29 张 512×512 RGBA PNG、24 条 44.1 kHz 单声道 16 位 WAV。可以先看[特效总览](../../asset/fx/_preview_sheet.png)、打开[音效试听页](../../asset/sfx/试听.html)，再查[素材来源与规格](../../asset/素材清单.md)。`_00`、`_01`、`_02` 是候选变体，可以在同一个接触帧对照选一张。

Godot 的 `res://` 从 `battle-demo/` 开始。确定要用的 PNG 放进建议目录 `battle-demo/runtime_assets/fx/`，WAV 放进 `battle-demo/runtime_assets/sfx/`，例如 `res://runtime_assets/fx/fx_shockwave_00.png`。素材库保留原图、试听页、索引及生成记录。现有 `battle-demo/art/` 受 `.gitignore` 忽略，新目录可被 Git 追踪，方便别人在全新检出后复现。交接时核对运行文件及对应 `.import`，缓存 `battle-demo/.godot/` 和截图 `test-output/` 走已有忽略规则。

| 时机 | 首批资源 | 接线位置 |
| --- | --- | --- |
| 拼点双方接触 | 既有 `art/battle-impact.png` 和 `sfx_clash_metal_a.wav` | `battle_stage.gd` 的 `play_event()` → `clash` → `_contact()`。现有 `battle-impact.png` 与 `asset/fx/fx_impact_spark_00.png` 字节一致，沿用当前贴图即可。若该首批需要在全新检出中也显示火花，把同一素材纳入运行目录并用其路径。 |
| 攻击实际命中 | `fx_shockwave_00.png` 和 `sfx_hit_flesh_a.wav` | `play_event()` 的 `strike` 分支，以当前接触点定位。可用 `blocked` 与 `damage` 区分盾击和实伤，纯护盾吸收可配 `sfx_guard_block_a.wav`。 |
| 对手硬币被打掉 | `sfx_clash_coin_break_a.wav` | `clash` 事件 `winner >= 0` 时可播。先和主碰撞音试听，×4 优先保留一次清楚的碰撞。 |
| 失衡触发 | `fx_debris_00.png` | `stagger` 事件，定位在被失衡单位；优先维持状态说明可读。 |
| 大招实际释放 | `fx_rune_mark_00.png` 与 `sfx_skill_cast_a.wav` | 挂在已确认的实际施放事件上。当前 `paid` 表示费用或演出账目，包含无需作为释放触发的动作。等明确的施放事件就位再接入，压制和失衡各沿用自身事件。 |
| 选牌与结算 | `sfx_ui_select_card_a.wav`、`sfx_victory_a.wav`、`sfx_defeat_a.wav` | `planning_ui.gd` 已调用的 `select`、`victory`、`defeat`。第二批逐项替换。 |

## 接在演出层

1. 让 Godot 导入选好的文件。PNG 在导入面板检查 Alpha，WAV 检查采样及循环，战斗短音默认单次播放。资源在场景准备时读取并缓存，`_draw()`、每段命中和每帧 Tween 复用纹理及音流。先在常见尺寸上检查 512px 是否合适，再决定是否为小特效单独制作 256px 副本。
2. `battle_stage.gd` 管贴图和接触位置。原有火花在 `_draw_overlay()` 使用 `impact_texture`。若新增发光冲击环，让单独的 `Sprite2D`/`TextureRect` 使用 `CanvasItemMaterial` 的 `BLEND_MODE_ADD`，避免让整个战场一起加色。暗色碎屑、烟尘和血雾先用普通 Alpha 混合。特效回收放在 `reset_visuals()` 或所属场景的离场路径，保留缺图时已有程序绘制兜底。
3. 声音沿用 `planning_ui.gd` 把 `stage.impact_sound` 接到 `synth_audio.gd` 的入口。先按事件标识解析为短音流，没找到对应 WAV 就沿用当前合成音。现有决胜碰撞和实际受击可能都传 `strike`，分开使用两种音色时，需要让 `clash` 与 `strike` 分支发出明确的演出标识。以后挑选 `a`/`b` 变体时使用独立演出 RNG，或者按事件顺序轮换。
4. 接触帧同时触发贴图、音效和数值。复用现有等待与接触停留预算，短音可以继续播放，速度切换无需等待音频或贴图播完。×2/×4 下优先保留最后一次决胜和关键命中。确认重开、返回地图、多段与全体攻击都能清掉残留状态，画面与规则继续通过事件和快照交接。

```powershell
$godot = (Resolve-Path '.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe').Path
& $godot --headless --path battle-demo --editor --import --quit
& $godot --headless --path battle-demo --script tests/test_planning.gd
& $godot --headless --path battle-demo --script tests/test_stagger_overwhelm.gd
& $godot --path battle-demo --script tests/test_target_render.gd
```

| 验收场景 | 实际要看什么 |
| --- | --- |
| 同种子对照 | 开关特效、声音变体或改倍速后，战斗最终 HP、Cost、胜负和规则事件一致。渲染测试核对素材导入，出牌和能力测试核对规则。 |
| ×1/×2/×4 实际窗口 | 选牌、平局重投、决胜、盾吸收、受伤、失衡与大招各走一次。1000×650 下火花定位在接触点，卡牌费用、HP 和目标提示仍能看清。重开或返回地图后无残影。 |
| 扬声器或耳机 | 碰撞、格挡和实伤可辨，连续命中时没有断头或一串过响的叠音。无头/Dummy 运行用于脚本与事件验证，听感由实际音频输出确认。 |
| 性能与交付 | 新文件加入后用相同阵容对照首进和二次进战。日志中没有资源缺失或运行时逐命中读取素材的记录。含文件清单、触发点、实际截图和已试听范围。可参考[运行优化记录](../任务记录/运行卡顿与界面刷新优化.md)。 |
