# GitHub 公有仓库协作指南

适用于 [clash-roguelike](https://github.com/zixinyc/clash-roguelike)，面向刚开始使用 GitHub 的项目成员。先用网页协作文档，开始写游戏时再使用本地工具。

## 先找到文档分类

直接打开 [docs 导航](../README.md)。其中“文档讨论”是实际文件夹，包含 [技能想法](../文档讨论/技能想法.md) 和 [hunter](../文档讨论/hunter.md)。

分支下拉框决定你正在修改哪个版本；文件路径决定内容归入哪个文件夹。`docs/skill-ideas` 是分支名，`docs/文档讨论/技能想法.md` 才是文档路径。日常阅读选 `main`，再从文件列表进入目录。

## 1. 先理解六个词

| 名称 | 通俗解释 | 本项目例子 |
| --- | --- | --- |
| Repository，仓库 | 项目文件夹，加上每次修改的历史 | clash-roguelike |
| Issue | 一张可讨论、认领的任务单 | 设计三种拼点技能 |
| Branch，分支 | 从现有版本分出来的一条工作线 | docs/combat-ideas |
| Commit，提交 | 保存一次有说明的修改记录 | docs: 补充破币规则示例 |
| Pull Request，PR | 请大家检查并合并改动的申请 | 将技能设计合并到 main |
| Merge，合并 | 把分支上的修改加入目标分支 | 将文档改动加入 main |

`main` 是大家共同使用的主版本。日常从它分出任务分支，检查完再合并回来。团队约定和系统强制规则是两回事：本次仅写入约定，未启用分支保护。

## 2. 公有仓库与协作者权限

公有意味着别人可以查看和下载仓库。登录用户通常可以通过 Fork（复制到自己的账号）再提交 PR 的方式贡献，但不会因为仓库公有就自动拥有原仓库写入权限。

你和朋友长期一起开发，推荐把朋友加为 Collaborator（协作者）。朋友使用自己的账号，不需要共享你的账号或密码。

你现在的仓库属于个人账号：你是所有者，朋友接受邀请后成为协作者，可以向仓库推送改动。是否能直接改主分支，还取决于之后设置的保护规则。

操作步骤：

1. 打开[项目首页](https://github.com/zixinyc/clash-roguelike)。
2. 点击顶部 **Settings**。
3. 在左侧 Access 区域找到 **Collaborators**；部分界面可能显示 **Collaborators & teams**。
4. 点击 **Add people**，搜索朋友的 GitHub 用户名并核对账号。
5. 发送邀请，让朋友登录自己的账号接受邀请。

本次没有自动邀请任何人。官方说明：[邀请个人仓库协作者](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/repository-access-and-collaboration/inviting-collaborators-to-a-personal-repository)。

## 3. 不写代码的朋友也能参与

- 策划：在 Issue 中写场景、技能和事件想法，在文档里完善确定的规则。
- 美术和音乐：讨论素材需求，提交有使用权的作品和来源说明。
- 测试：记录操作步骤、预期行为、实际行为与截图。
- 程序：领取功能或问题，在任务分支实现，通过 PR 交付。

仓库文件、Issue 标题与评论、PR 讨论均可能公开，不要把密码、令牌、私人聊天或未获许可的素材放进来。

## 4. 先用 Issue 分工

打开 [Issues](https://github.com/zixinyc/clash-roguelike/issues)，点击 **New issue**，一件事写一个任务。若界面出现模板选择，选择合适模板或创建空白 Issue。

建议格式：

```markdown
标题：设计三种基础拼点技能

目标：让玩家能选择稳定、爆发或多次对抗的技能。
范围：只写规则和例子，暂不实现程序。
认领人：填写负责人的 GitHub 用户名。
完成标准：写出三种技能的基础威力、硬币数量、效果和一次对抗例子。
关联文档：说明拟修改的文档路径。
```

有权限时在右侧 Assignees 指定负责人；暂时不能指定时，用评论说明“我来做”。新想法可以先写 Issue 讨论，不必立即变成开发任务。

## 5. 用网页完成第一次协作

练习任务：朋友新增一份技能想法文档。以下按朋友已接受协作者邀请的情况说明。

1. **创建分支。** 打开 Code 页，在文件列表上方点击 `main` 下拉框，输入 `docs/combat-ideas`，选择从 main 创建这个新分支。确认当前显示的是新分支。
2. **添加文档。** 点击 **Add file → Create new file**，文件名输入 `docs/文档讨论/技能想法.md`，写下技能名称、作用和具体例子。也可以进入现有文档，通过编辑按钮修改。
3. **保存提交。** 点击 **Commit changes**，填写说明，例如 `docs: 新增三种基础技能想法`。确认提交到当前任务分支；若界面提供新建分支选项，核对分支名称后再提交。
4. **发起 PR。** 进入 **Pull requests → New pull request**，设置 `base: main`、`compare: docs/combat-ideas`。检查 Files changed 中只有预期改动，然后点击 **Create pull request**。
5. **说明结果。** PR 中写明改了什么、为什么改、如何检查；如果完成了某个 Issue，可写 `Closes #编号`，把“编号”替换为真实 Issue 编号。
6. **请另一位成员检查。** 可以在聊天里把 PR 链接发给对方。另一位成员查看 Files changed，提出意见；作者继续提交到同一分支，PR 会更新。
7. **合并。** 检查通过后，有合并权限的成员点击 **Merge pull request** 或选择 **Squash and merge**，再确认。简单任务推荐 Squash，把本次任务合成一条提交记录。

PR 合并后回到 main，确认文档已经出现。首次初始化文档由维护者直接提交 main；之后建议用上述流程。

如果朋友还没有协作者权限，网页可能引导其 Fork：改动保存在朋友的仓库，再向 `zixinyc/clash-roguelike` 的 main 发起 PR 即可。你们固定团队优先采用同仓库分支方式。

官方练习：[Hello World：分支、提交与 PR](https://docs.github.com/en/get-started/using-github/hello-world)。

## 6. 开始本地开发后怎么做

不习惯命令行，可以使用 GitHub Desktop：克隆仓库，创建分支，在编辑器修改文件，检查 Changes 后提交，Push，再创建 PR。首次选择一个空的新文件夹保存克隆，避免覆盖已有工作。

已经安装 Git 的成员，可以在打算保存项目的父目录运行：

```bash
git clone https://github.com/zixinyc/clash-roguelike.git
cd clash-roguelike
git switch main
git pull --ff-only origin main
git switch -c docs/combat-ideas
```

修改文档后，只添加本次想提交的文件，例如：

```bash
git status
git add docs/文档讨论/技能想法.md
git diff --cached
git commit -m "docs: 新增三种基础技能想法"
git push -u origin docs/combat-ideas
```

然后在 GitHub 网页创建 PR。首次推送按 Git 凭据管理器或客户端提示登录自己的 GitHub 账号；HTTPS 推送不使用 GitHub 账号密码作为 Git 密码。

下次开始新任务前，先保存好现有改动，切回 main 并拉取更新，再创建新的任务分支。例子中的分支名称仅用于演示，实际每个任务使用不同名称。

如果本地 main 有未提交的改动，或 `git pull --ff-only` 报错，先运行 `git status` 检查并沟通，不要为了同步而执行强制推送或硬重置。

## 7. 两个人同时修改怎么办

尽量把不同任务放在不同文件。比如一个人写战斗规则，另一个人写事件，不同时大改同一份长文档。

如果 PR 显示冲突，表示 GitHub 无法自动决定哪些内容保留。由改动双方确认要保留的内容，解决后重新检查；不要直接用“覆盖整个文件”的方式处理。复杂冲突可以把 PR 链接和报错发来一起处理。

## 8. 团队先采用的约定

- 一个 Issue 对应一个明确结果；一个分支尽量只做一个任务。
- 开始前认领，完成后给出检查方法。
- main 保留已检查的共同版本，实验放在任务分支。
- 文档写明提议、已确定和已实现的区别。
- 素材带来源与许可信息；不提交缓存、账号凭证和个人文件。
- 尽量由另一位成员检查 PR。需要系统强制时，再配置 main 的分支规则；目前尚未设置。

公有可见性也不等于自动授予开源许可。本项目暂未选择许可证，后续由团队确定代码与素材的许可方式。参考：[GitHub 仓库许可说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。

## 9. 今天就能完成的一次练习

你邀请一位朋友并确认其接受邀请；朋友建一个 `docs/first-idea` 分支，新增 `docs/文档讨论/第一个想法.md`，提交并发起 PR；你阅读后合并。刷新 main，看到新文档，就走完了最小协作闭环。
