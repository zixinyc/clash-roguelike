# 当前硬币规则

本次仅接入主Demo角色入口，保留已更新的正式战斗底层。拼点初始点数、拼点硬币加值、攻击硬币加值分别保存。每轮重新投全部余币，平局不破币，败方只损失一枚；一方归零后胜方用剩余币攻击。投币继续使用宿主随机数。

当前攻击阶段正面硬币加值逐币累计，反面保留本技能已累计加值；新技能清零。不是早期“每击重置点数”的实现。ZiXi的拼点初始值与攻击初始值亦按已录入数据分别处理。效果不增加硬币、不恢复失去的硬币；角色特殊群体或状态伤害保留现有适配。具体边界见 CHARACTER_INTEGRATION.md。

CoinCombat.cs/CoinLog.cs/CoinChecks.cs负责硬币状态、公式、日志与专项；BattleRules.cs与PortBattleRules.cs负责宿主适配；TouhouRoles.cs、MarisaRole.cs、ZixiRole.cs负责角色。CoinBattleView.cs、ReadableCombat.cs、CombatImpact.cs及AdventureGame.cs负责展示。专项1313项、角色154项，八组合计3474项。原追加攻击牌仍未重新设计。本轮没有修改上述核心逻辑或数据。