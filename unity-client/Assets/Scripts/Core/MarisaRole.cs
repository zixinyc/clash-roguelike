using System;
using System.Linq;
using System.Collections.Generic;
namespace ClashRoguelike
{
    public static partial class TouhouRoles
    {
        public static readonly string[] MarisaCards={"marisa_stars","marisa_laser","marisa_orrery","marisa_spark"};
        public static Unit Marisa(){return new Unit{Name="雾雨魔理沙",Role="火花",CharacterId="marisa",Hp=45,MaxHp=45,MinSpeed=5,MaxSpeed=7,RoleState=new TouhouRoleState()};}
        public static PortCard[] MarisaDefinitions(){return new[]{
            new PortCard("marisa_stars","星辰幻想","魔理沙专属",2,5,4,1,2,"拼点获胜火花+1；初始5，正面攻币+1逐币累计，队伍增伤每技能一次。","先点亮第一颗星。",0,"attack"),
            new PortCard("marisa_laser","非指向性激光","魔理沙专属",3,5,4,3,2,"最多3目标；每击原伤−4。拼赢后按实际命中人数增加火花。","散开的光同样灼热。",0,"attack"),
            new PortCard("marisa_orrery","天球仪","魔理沙专属",3,10,0,0,0,"无法拼点；本回合及下回合每次攻击减伤5，火花+1。","群星环绕。",0,"guard"),
            new PortCard("marisa_spark","极限火花","魔理沙专属",5,0,20,0,1,"胜利或单方面释放：每敌10×火花，消耗全部火花。","火力就是答案。",0,"ultimate")};}
    }
    public partial class PortBattleRules
    {
        bool IsMarisa(int unit){return State.TouhouTeam&&unit==0;}
        bool CanFundMarisa(PortCard skill,int slotId)
        {
            var rest=State.HeroSlots.Where(x=>x.Active&&x.Id!=slotId).ToArray();int missing=Math.Max(0,rest.Sum(x=>PortContent.Card(x.Key).Cost)+skill.Cost-State.Cost);if(missing==0)return true;
            if(!State.TouhouTeam||State.Heroes[0].Hp<=missing*5)return false;
            int own=rest.Where(x=>x.Unit==0).Sum(x=>PortContent.Card(x.Key).Cost)+(State.HeroSlots[slotId].Unit==0?skill.Cost:0);return missing<=own&&missing<=Math.Max(0,State.EnemyCost-State.EnemySlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost));
        }
        void PayMarisaFunding(List<PortEvent> events)
        {
            if(!State.TouhouTeam)return;State.EnemyCost-=State.EnemySlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost);int missing=Math.Max(0,State.HeroSlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost)-State.Cost);if(missing==0)return;
            if(State.Heroes[0].Hp<=missing*5||missing>State.EnemyCost)throw new InvalidOperationException("Unaffordable locked theft");
            State.Heroes[0].Hp-=missing*5;State.EnemyCost-=missing;State.Cost+=missing;Emit(events,"ability","魔理沙用 "+missing*5+" 生命偷取 "+missing+" 敌方cost",0);
        }
        void GainSpark(List<PortEvent> events,int amount)
        {if(!State.TouhouTeam)return;var s=State.Heroes[0].RoleState;s.Spark=Math.Min(10,s.Spark+amount);Emit(events,"ability","火花 "+s.Spark+" / 10",0);}
        int MarisaClashBonus(PortSlot slot,PortCard skill)
        {return IsMarisa(slot.Unit)?(State.Heroes[2].Hp>0?-2:0)+(State.Heroes[0].RoleState.Spark>5&&skill.Kind!="guard"?2:0):0;}
        void AttackNewHero(List<PortEvent> events,PortSlot slot,int target,CoinAction action,PortCard skill,ZixiContext context)
        {if(IsMarisa(slot.Unit))AttackMarisa(events,slot,target,action,skill,true);else if(State.Heroes[slot.Unit].Zixi!=null)AttackZixi(events,slot,target,action,skill,context);else Attack(events,true,slot.Unit,target,action,skill);}
        void AttackMarisa(List<PortEvent> events,PortSlot slot,int target,CoinAction action,PortCard skill,bool won)
        {
            var targets=new List<int>{target};if(skill.Id=="marisa_laser"||skill.Id=="marisa_spark")targets.AddRange(Enumerable.Range(0,State.Enemies.Count).Where(i=>i!=target&&State.Enemies[i].Hp>0).Take(skill.Id=="marisa_laser"?2:State.Enemies.Count));
            int sparks=State.Heroes[0].RoleState.Spark;int bonus=(State.Heroes[2].Hp>0?5:0)+(sparks>5?2:0);if(skill.Id=="marisa_spark"){State.Heroes[0].RoleState.Spark=0;Emit(events,"ability","极限火花：消耗 "+sparks+" 层火花",0);}
            var hitTargets=new HashSet<int>();CoinStep step,last=null;
            while((step=action.NextAttack(new CoinRandomSource(FlipCoin)))!=null)
            {
                last=step;bool hit=false;foreach(int id in targets)
                {
                    var victim=State.Enemies[id];if(victim.Hp<=0)continue;int raw=skill.Id=="marisa_spark"?10*sparks:step.RawDamage-(skill.Id=="marisa_laser"?4:0);
                    if(step.AttackIndex==1&&(skill.Id!="marisa_spark"||sparks>0))raw+=bonus;int damage=DealNewHit(events,0,id,Math.Max(0,raw),"strike",step);if(damage>0)hitTargets.Add(id);hit=true;
                }
                if(hit)action.NotifyHit(step.Heads);
            }
            action.CompleteAttack();if(last!=null){var end=Emit(events,"attack_end",skill.Name+" 攻击结束：消耗 "+action.AttackCount+" 枚硬币",0,target);end.Coin=last.Copy();end.Coin.Left=action.Snapshot();}
            if(won&&skill.Id=="marisa_laser")GainSpark(events,hitTargets.Count);
        }
        int DealNewHit(List<PortEvent> events,int source,int target,int raw,string type,CoinStep coin=null)
        {
            var victim=State.Enemies[target];if(victim.Hp<=0)return 0;int blocked=Math.Min(victim.Shield,raw),damage=raw-blocked;victim.Shield-=blocked;victim.Hp=Math.Max(0,victim.Hp-damage);
            var ev=Emit(events,type,victim.Name+" 原始 "+raw+" / 实伤 "+damage,source,target);ev.AttackerAllied=true;ev.Damage=damage;ev.Coin=coin==null?null:coin.Copy();if(ev.Coin!=null){ev.Coin.RawModifier+=raw-ev.Coin.RawDamage;ev.Coin.RawDamage=raw;}return damage;
        }
    }
}
