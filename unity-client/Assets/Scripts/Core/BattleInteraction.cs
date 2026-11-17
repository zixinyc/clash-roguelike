using System.Linq;

namespace ClashRoguelike
{
    // Scene clicks select and reserve actions through the existing speed resolver.
    public sealed class BattleInteraction
    {
        readonly BattleRules rules;
        public int Hero { get; private set; }
        public int Card { get; private set; }
        public int LastEnemy { get; private set; }
        public string Message { get; private set; }
        public bool Committed { get; private set; }
        public bool Prepared { get; private set; }
        public bool WaitingForTarget { get { return Card>=0; } }
        bool ValidPlans { get { return rules.State.Outcome==""&&!rules.State.Resolving&&rules.State.Plans.Count>0&&rules.State.Plans.All(p=>rules.CanPlay(p.Card,p.Hero,p.Enemy)==""); } }
        public bool CanPrepare { get { return Open&&!WaitingForTarget&&ValidPlans; } }
        public bool CanPlayPrepared { get { return Prepared&&!WaitingForTarget&&ValidPlans; } }
        public bool CanUndo { get { return Open&&rules.State.Plans.Any(p=>p.Hero==Hero); } }
        public bool AllArranged
        {
            get
            {
                int actors=rules.State.Heroes.Count(h=>h.Hp>0&&!h.Acted);
                return actors>0&&!WaitingForTarget&&rules.State.Plans.Count>=System.Math.Min(BattleRules.MaxPlays,actors);
            }
        }
        public int ActiveStep { get { return Prepared||AllArranged||Committed?-1:Hero<0?0:WaitingForTarget?2:1; } }
        public string PanelStatus { get { return Prepared?"准备就绪":WaitingForTarget?"选择目标":AllArranged?"全部已安排":Committed?"安排完成":Hero<0?"等待操作":"选择技能"; } }
        public string PanelHint
        {
            get
            {
                if(Prepared) return "行动已锁定，点击演示一回合。";
                if(WaitingForTarget) return "点击敌方角色选择目标。";
                if(AllArranged) return "所有行动已安排，可以准备完成。";
                if(Committed) return "行动安排完成，可继续选择角色。";
                return Hero<0?"点击战场中的己方角色。":"请选择技能。";
            }
        }
        public BattleInteraction(BattleRules rules) { this.rules=rules; Clear(); }
        public void Clear()
        { Hero=-1; Card=-1; LastEnemy=-1; Committed=false; Prepared=false; Message="点击己方角色，展开可用技能"; }
        public void ClearSkill()
        { Card=-1; LastEnemy=-1; Committed=false; Message=Hero<0?"点击己方角色，展开可用技能":"选择技能，再点击高亮敌人"; }
        bool Open { get { return rules.State.Outcome==""&&!rules.State.Resolving&&!Prepared; } }
        public bool Prepare()
        {
            if(!CanPrepare) { Message=WaitingForTarget?"先完成目标选择，或按 Esc 取消。":"请先完成至少一项有效安排。"; return false; }
            Prepared=true; Committed=false; Message=PanelHint; return true;
        }
        public void ResumePlanning()
        { if(!Prepared) return; Prepared=false; ClearSkill(); Message="可继续调整安排。"; }
        public bool CanSelectHero(int index)
        { return Open&&index>=0&&index<rules.State.Heroes.Count&&rules.State.Heroes[index].Hp>0&&!rules.State.Heroes[index].Acted; }
        public bool SelectHero(int index)
        {
            Committed=false;
            if(!CanSelectHero(index)) { Message="请选择仍可行动的己方角色"; return false; }
            Hero=index; ClearSkill(); Message=rules.State.Heroes[index].Name+" · 选择技能（来自共享手牌）"; return true;
        }
        public string SkillError(int index)
        {
            if(Prepared) return "已准备，请先返回调整。";
            if(!CanSelectHero(Hero)) return "先点击可行动的己方角色";
            if(index<0||index>=rules.State.Hand.Count) return "请选择一项技能";
            var skill=BattleRules.GetSkill(rules.State.Hand[index]);
            int target=skill.Guard?-1:rules.State.Enemies.FindIndex(x=>x.Hp>0);
            return rules.CanPlay(index,Hero,target);
        }
        public bool SelectSkill(int index)
        {
            Committed=false; string error=SkillError(index);
            if(error!="") { Message=error; return false; }
            Card=index; LastEnemy=-1;
            if(BattleRules.GetSkill(rules.State.Hand[index]).Guard) return Commit(-1);
            Message=rules.State.Heroes[Hero].Name+" · "+BattleRules.GetSkill(rules.State.Hand[index]).Name+"：点击高亮敌人完成安排"; return true;
        }
        public bool CanTarget(int index)
        {
            return Open&&Card>=0&&Card<rules.State.Hand.Count&&!BattleRules.GetSkill(rules.State.Hand[Card]).Guard&&rules.CanPlay(Card,Hero,index)=="";
        }
        public bool SelectEnemy(int index)
        {
            Committed=false;
            if(!CanTarget(index)) { Message=Card<0?"先点击己方角色和技能":"该目标无效；请点击高亮敌人"; return false; }
            return Commit(index);
        }
        bool Commit(int target)
        {
            var events=rules.Play(Card,Hero,target);
            if(events.Count==0) { Message="当前无法安排此行动"; return false; }
            var e=events[0]; LastEnemy=target; Card=-1; Committed=true;
            Message=rules.State.Heroes[Hero].Name+" · "+e.Skill+(target<0?" → 自身":" → "+rules.State.Enemies[target].Name)+" 已安排；预留 "+e.Paid+" cost";
            return true;
        }
        public bool Cancel()
        {
            Committed=false;
            if(!Open) { Message="已锁定安排，请先返回调整。"; return false; }
            if(!rules.Cancel(Hero)) { Message="当前角色没有安排"; return false; }
            ClearSkill(); Message="已撤销 "+rules.State.Heroes[Hero].Name+" 的安排，释放手牌和预留费用"; return true;
        }
    }
}
