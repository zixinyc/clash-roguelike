# AI 生成游戏美术素材：两条可落地的路线

这篇是学习笔记，来源是 B 站 UP 主「孤独生命态」的两个视频（合集名：ai游戏美术资产怎么来？）。视频没有口播，全部内容在画面里，我逐帧读完了。

- 《live2d、spine啥都不会，如何让oc动起来还能进游戏？》 https://www.bilibili.com/video/BV1sopt67EJQ （2 分 59 秒）
- 《【2.0更新】我真的不会美术啊！如何用ai解决素材问题？》 https://www.bilibili.com/video/BV1mXHy6cEWy （4 分 02 秒）

作者说明：这套流程全部本地跑，作者机器是 RTX 3080 20GB。

## 一句话结论

两条路线，各有各的坑：

- 路线 A（第一个视频）：一张立绘 → 拆成二十多个部件 → 套骨骼和表情 → 导出成骨骼数据 + 图集，接进游戏。适合「高质量立绘做少量动作」。
- 路线 B（第二个视频）：让 AI 直接生成动作视频 → 抽成序列帧 → 像素化 → 补动作 → 在 Godot 里拼起来。适合「像素风、要很多动作」。

## 路线 A：一张立绘动起来

作者给的耗时表（原表照抄，单位是分钟）：

| 步骤 | 工具 | 用时 |
| --- | --- | --- |
| 正面站姿 | Qwen Image 2.1 编辑（2K） | 约 4 分钟 / 张 |
| 拆部件 | See-through 2048 + 1280 补调 | 约 18 + 8 分钟 |
| 表情 | Qwen 编辑 3 张 + 各拆一遍 | 约 4 + 8 分钟 / 张 |
| 超分 | Real-ESRGAN 动漫模型 | 约 30 秒 |
| 骨骼 + 动作 | 脚本生成 Spine 4.2 骨骼 | 几秒 |

具体操作：

1. 先要一张标准正面图。用 Qwen Image 2.1 编辑输入原图，要求：正面、对称、双手下垂、纯色背景。作者第一版把头发削掉了一截，改了一次提示词第二版才对。所以这一张要来回抽。
2. 拆部件。用 See-through，把一张图自动拆成二十多个语义图层（前发、后发、脸、眼睛、虹膜、眉毛、睫毛、耳朵、鼻子、嘴巴、上衣、手套、下装、腿饰、鞋、尾巴、翅膀……），每层带透明通道，还带前后遮挡顺序，浏览器里直接下载分层 PSD。作者用的分辨率是 2048，再用 1280 补调一次。
3. 骨骼 + 表情。部件会自动套上网格和骨骼（头部是 7×7 的网格骨骼，转头时五官跟着脸变形不会飘出去；尾巴会自动长出 4 节骨骼）。表情要单独做一遍：闭眼、张嘴、笑，各画一张再各拆一次。
4. 超分。Real-ESRGAN 动漫模型，约 30 秒。注意这一步会改线条，作者试了三个模型，APISR 会把笑纹完全盖掉，所以没选它。
5. 骨骼 + 动作。脚本自动生成 Spine 4.2 骨骼，几秒钟。
6. 导出给游戏。导出 Spine 4.2 的骨骼 JSON 和图集，Unity、Godot、网页都能跑。

作者踩过的坑：

- 表情和身体部件是两件事，表情必须单独画、单独拆。
- 眨眼、耳朵这种小配件要单独做一层，不要跟着整体换，否则眨眼时只有一小块在动。
- 超分放在最后，会把线改掉，所以流程里作者是「拆完 → 超分 → 再上骨骼」。

## 路线 B：让 AI 出视频再抽帧

1. 先出两个「中枢姿势」。用 Qwen 编辑出 A（待机）、R（跑动）两个姿势。每个动作的两端都回到同一张图，背景全程不变，这样动作之间才能无缝拼接。
2. 参考图的形式决定成败。作者用同一个 Blender 人偶、同一个种子，只换参考图形式：灰色剪影失败，OpenPose 骨架成功，深度图成功，Blender 渲染的深度图成功。结论是别给灰模，要给骨架或深度。
3. 生成视频。用视频模型按参考图出动作视频，作者说一次约 16 秒。
4. 抽帧。拼接处看不出接缝就算过。音频上脚步声间隔 0.36 秒能和画面的脚步对上。
5. 像素化。要点：先在高清图上抠绿，再分段去毛边；用 box 最小化逼近；抠图用 BitReNet；缩放用最近邻。像素版要单独调，作者对比过 1.42 和 1.72 两版。
6. 补动作。先用 Qwen 画一张「爆炸图」把角色拆成部件：第一次让它列上臂/前臂/大腿/小腿失败了，第二次改说「整套手臂 / 整套双腿」才拆对，6 个部件、画风一致，每次约 30 秒。接着用正弦参数化补动作：idle 2.0 秒、walk 1.0 秒、run 0.6 秒、jump 1.2 秒、wave 1.6 秒，全部循环。作者的最终形态是 12 根骨骼、10 个插槽。
7. 转进 Godot 后修两个 bug：
   - 切换动作时姿势残留。原因是每个动作都用自己的骨骼打帧，改成所有动作共用同一套骨骼打帧就好了。
   - 「动不起来」。原因是轨道里值为 0 的地方写成了整数 0，整条轨道被当成整数插值，一律写浮点数就行。

作者自己说还没做完的：头部二次动画（网格）、裙子多段与裙摆、更多动作从视频里提取。

## 两条路线怎么选

作者给的对比：

| | 视频帧路线（Qwen → 视频 → 像素化） | 切片骨架路线 |
| --- | --- | --- |
| 一致性 | 逐帧生成，靠全局颜色压漂移 | 同一套贴图，零漂移 |
| 动作 | 任意动作，含余跳感、转身 | 关节被约束住，转身要另做部件 |
| 加一个动作 | 一次视频生成（约 16 秒）+ 后处理 | 改关键帧数据，重复调用很贵 |
| 授权 | 无 | Spine 运行时主要收费，Godot Skeleton2D 免费 |

Godot 4 那条免费的路子作者也实测了：Spine JSON → Skeleton2D + Bone2D + 蒙皮 Polygon2D + AnimationPlayer，和原版逐条对比，大部分姿势对齐。

## 落到我们项目上

我们现在的角色是代码画的色块（见 battle-demo/preview/clash.png），README 里「演出」那段要求前冲、对撞、破币与追击，所以角色最少要有这几组动作：待机、前冲或攻击、受击、胜利或倒地。

建议这么开工：

1. 先用路线 A 做 5 个角色（灰烬、长锋、炽火、锈刃巡卫、失序哨兵）的立绘，加待机、受击、胜利三组动作。
2. 风格要往现在的 UI 上靠。现在是深色科幻底子，角色是低饱和剪影加少量高饱和点缀（蓝刃、红刃），所以出图提示词要写「暗背景、剪影化、边缘少量高饱和光」，不要让模型出白底萌系立绘。
3. 授权走 Godot Skeleton2D 那条，不买 Spine 运行时。Spine JSON 本身不要钱，收费的是 Spine 的官方运行时。
4. 美术风格本来还在讨论，正好用这两条流程做一轮「风格探针」：同一个角色两条路线各出一版，挑更贴现有 UI 的那种，再决定全量做。
5. 素材来源和授权要记进仓库。README「素材与许可」那节已经写了新增美术要记录来源，AI 出的图也一样。

## 工具在作者和我们机器上的现状

我们本机已经有：

- ComfyUI（Aki v3 版，路径 C:\Users\ZIXIN\Downloads\aidraw\ComfyUI-aki-v3（dit，new）\ComfyUI），显卡是 RTX 5070 Ti Laptop 12GB
- R-ESRGAN 4x+ Anime6B.pth（超分那一步能直接用）
- Flux Kontext（改图，可以替代 Qwen 改图那一步）
- RMBG（抠图、抠绿）
- comfyui_controlnet_aux（内含 DWPose，抽骨架用）
- UltimateSDUpscale

还缺的：

- Qwen-Image-2.1。开源权重在 Hugging Face 的 Qwen/Qwen-Image-2.1，本机 12GB 显存要开 CPU offload 才能跑，也可以直接用云端 API 免折腾。
- See-through。原项目是 shitagaki-lab/see-through，ComfyUI 插件版在 ComfyUI-Manager 里搜 See Through 就能装。官方说 8GB 显存起步、16GB 更稳。作者跑的是 2048 分辨率，12GB 可能吃紧，先用 1280 试。

## 复现方式

原始视频和素材截图存在本机 .tools/video-learn/ 里（这个目录不进 Git）。要重看或重抽帧：

```powershell
# 重下音频（转写用）
yt-dlp -f ba -o "BV1sopt67EJQ.%(ext)s" "https://www.bilibili.com/video/BV1sopt67EJQ"

# 重下带画面的完整视频
yt-dlp -f "mp4/best[ext=mp4]" -o "video_%(id)s.%(ext)s" "https://www.bilibili.com/video/BV1mXHy6cEWy"
```

这两个视频的音频只有背景音乐，没有人声解说，所以转写出来是空的，内容全在画面里。抽帧用 PyAV（不依赖 ffmpeg），脚本见 .tools/video-learn/。

## 延伸学习清单

下面这些是 B 站上同类型的公开视频，标题、链接、播放量是从那两个视频页面的相关推荐里抓下来的真实数据。同作者的合集「ai游戏美术资产怎么来？」还有两集没看。

### 同一个作者、合集里剩下的两集

- spine2d模型进入3d场景基础效果预览（0 分 53 秒） https://www.bilibili.com/video/BV1vtpv6nEQf
- 为什么我放弃了本地ai建模？你应该试试ai像素建模！（6 分 34 秒） https://www.bilibili.com/video/BV1TsJB6uEut

### 拆件与 Live2D

- [开源]psd一键生成live2d工程。psd2live（常日缠，5.8 万） https://www.bilibili.com/video/BV17utZ6hE64
- 【Krene】从设计到live2d！图片一键分层！AI可以做psd图层文件啦！（1.2 万） https://www.bilibili.com/video/BV1zLxM6sE4y
- 【Day 3】纯 AI Live2D：从一张图做出能动的人（宫怜月大肥鱼） https://www.bilibili.com/video/BV1egxu6mEUu
- 「Live2D」解放双手，让Live2D自己建模（Cubefox，4 万） https://www.bilibili.com/video/BV1xwNPedEcT
- 【live2d拆分】跟原画师拼了（许兑九，11 万） https://www.bilibili.com/video/BV1fS411P7FV

### Spine 骨骼（跟我们的拼点演出最相关）

- AI一键生成Spine动画（北国风雪儿） https://www.bilibili.com/video/BV1Wcpb6yE4D
- Spine动画 2d AI生成游戏角色，用astra制作2d骨骼动画 https://www.bilibili.com/video/BV1x8nv6wEfg
- 用astra制作2d骨骼动画，消耗了astra10%额度（斯蒂芬小布丁） https://www.bilibili.com/video/BV18ahx6KEDd
- 千夏spine全流程——骨骼建立与权重绑定（岁伴，1.2 万） https://www.bilibili.com/video/BV1tCGq6QEVk
- 【Spine】物理约束有多无脑（鱼骨头_哒哒哒，2.3 万） https://www.bilibili.com/video/BV1sjAaeAEqh
- spine 动作+像素风格+法线贴图（脑细胞无用404，11.8 万） https://www.bilibili.com/video/BV1G5bnzvE9T

### 像素与帧动画

- 创建一个像素角色需要哪些基础动画？【全套像素帧动画角色动作拆解】（blue蓝云cloud，36.3 万） https://www.bilibili.com/video/BV1JZ8Zz9EWn
- 【像素角色动画】动作与连招的设计思路（blue蓝云cloud，17.8 万） https://www.bilibili.com/video/BV1W95B6DETX
- 2026 了，不会还有人不会用 ai 做帧动画吧？基础篇教学 2（aifps工作室） https://www.bilibili.com/video/BV1kRRzBnEwn
- 【Rika AI】独立游戏开发者福音！真正生产级的ai像素动画工具（干燥小镰刀，12.1 万） https://www.bilibili.com/video/BV1ieZ8B9EvS
- 【工具教程】AI生成像素帧序列人物再更新（bimelona，6.7 万） https://www.bilibili.com/video/BV1dQPezJEmG
- 像素版和高清版，你更喜欢哪一种？（N0p3_） https://www.bilibili.com/video/BV1mjHW6NEUS

### 动作与视频生成

- 迄今为止最好用的动作生成AI！（琅泽多元派，13.5 万） https://www.bilibili.com/video/BV1jJJG62EMQ
- seedance2.0的动漫太强了……（滑大稽狼，16.3 万） https://www.bilibili.com/video/BV1jvFWz2Eax
- 谢谢你seedance2.0一人制作动画op不是梦（一唐丸一，5.1 万） https://www.bilibili.com/video/BV1mJZiBtEjk
- AI动画 即梦 Seedance 2.0 多武器测试 战斗集锦（醉过罪过，12.5 万） https://www.bilibili.com/video/BV1SMLE6CEQk
- 假如让deepseek harness自己生成动画，它会做出什么样的东西？（猴不爱说，7.1 万） https://www.bilibili.com/video/BV11X8t6vEZu
- deepseek v4 Flash正式版直出像素资产图（葬爱的芙莉莲，7.3 万） https://www.bilibili.com/video/BV12tGP6XEmB

### 3D 与建模

- gpt6+tripo制作完整角色。（派派wj，2.7 万） https://www.bilibili.com/video/BV19GH86wEBX
- 两个小时用gpt6做的？（blender先森，5.8 万） https://www.bilibili.com/video/BV1Xoeb6xEcK

### 素材站、工程落地与兜底

- ai制作游戏必备免费素材网站（敲敲go，2 万） https://www.bilibili.com/video/BV12KDUB3EdQ
- 3分钟速成gemini制作游戏素材（浅墨千羽，6.4 万） https://www.bilibili.com/video/BV1dRdzB5E87
- 一周时间，我用 Godot MCP + AI Agent 做了一个游戏 Demo（小张0610） https://www.bilibili.com/video/BV1qFJi6mEy7
- unity2d 求职demo ai制作 类银河恶魔城游戏《影渊》（吃不吃猪扒包） https://www.bilibili.com/video/BV1GPLr61Efx

## 视频里提到、可以直接上手的工具

- See-through（拆图）：原项目 shitagaki-lab/see-through，ComfyUI 插件在 Manager 里搜 See Through 安装。
- psd2live：PSD 直接生成 Live2D 工程，配套仓库 https://github.com/Ariakage/live2d-agent-kit （要 Java 21，附 VTube Studio 示例模型，插件里有 setup-psd2live.sh）。
- Rika AI（像素动画，网页版）：https://rika-ai.com/ 。上传 32/64/128/256 的像素图，内置 idle、walk、run、attack、jump、hit、defeated 七种动作，V1 出 8 到 16 帧、V2 可到 32 帧，能导出 PNG 精灵图和 GIF，有免费额度，也能申请 API key 接进自己的流程。
- Krita（免费画图与逐帧动画）：https://krita.io/cn/ 。有逐帧时间轴和洋葱皮，能直接导出动画帧序列。
- 其他视频里反复出现的：Tripo 和 Blender（3D）、Seedance 2.0（即梦，动作视频）、Astra（2D 骨骼动画）、DWPose（抽骨架，本机 controlnet_aux 已经带）。

