using System;
using System.Linq;
using System.Collections.Generic;
namespace ClashRoguelike
{
    public static partial class TouhouRoles
    {
        public static readonly string[] MarisaCards={"marisa_stars","marisa_laser","marisa_orrery","marisa_spark","marisa_meteor","marisa_blazing_star"};
        public static Unit Marisa(){return new Unit{Name="雾雨魔理沙",Role="火花",CharacterId="marisa",Hp=45,MaxHp=45,MinSpeed=5,MaxSpeed=7,RoleState=new TouhouRoleState()};}
        public static PortCard[] MarisaDefinitions(){return new[]{
            new PortCard("marisa_stars","星辰幻想","魔理沙专属",2,4,2,2,2,"两币；全正裸伤8；拼点获胜火花+1。","先点亮第一颗星。",0,"attack",splitAttackPower:true),
            new PortCard("marisa_laser","非指向性激光","魔理沙专属",3,5,3,3,2,"最多3目标；每个目标全正裸伤7，首次伤害−4；拼赢后按实际命中人数增加火花。","散开的光同样灼热。",0,"attack",splitAttackPower:true),
            new PortCard("marisa_orrery","天球仪","魔理沙专属",3,10,0,0,0,"无法拼点；本回合及下回合每次攻击减伤5，火花+1。","群星环绕。",0,"guard"),
            new PortCard("marisa_spark","极限火花","魔理沙专属",5,0,20,0,1,"敌方全体10×火花；消耗所有火花，至少5层时无视护盾。","火力就是答案。",0,"ultimate"),
            new PortCard("marisa_meteor","龙陨石","魔理沙专属",0,8,3,0,2,"成功释放恢复2 cost；单目标固定10伤，不吃外部加成。","流星坠落。",0,"attack"),
            new PortCard("marisa_blazing_star","炽热之星","魔理沙专属",10,30,-10,-10,1,"最多3目标；正面降10点，最终点数×火花，无视护盾。施放后HP降为10；低于10则扣3 cost。","星光穿过夜幕。",0,"ultimate")};}
    }
    public partial class PortBattleRules
    {
        const int MarisaHealthPerCost = 3;
        int MarisaActor {get{return State.Actor("marisa");}}
        bool IsMarisa(int unit){return unit>=0&&unit==MarisaActor;}
        bool CanFundMarisa(PortCard skill,int slotId)
        {
            var rest=State.HeroSlots.Where(x=>x.Active&&x.Id!=slotId).ToArray();
            int cost=rest.Sum(x=>PortContent.Card(x.Key).Cost)+skill.Cost;
            if(MarisaActor>=0&&State.Heroes[MarisaActor].Hp<10&&(skill.Id=="marisa_blazing_star"||rest.Any(s=>s.Key=="marisa_blazing_star")))
                return cost+3<=State.Cost;
            int missing=Math.Max(0,cost-State.Cost);if(missing==0)return true;
            if(MarisaActor>=0&&(skill.Id=="marisa_blazing_star"||rest.Any(s=>s.Key=="marisa_blazing_star"))&&
                State.Heroes[MarisaActor].Hp-missing*MarisaHealthPerCost<10)return false;
            if(MarisaActor<0||State.Heroes[MarisaActor].Hp<=missing*MarisaHealthPerCost)return false;
            int own=rest.Where(x=>x.Unit==MarisaActor).Sum(x=>PortContent.Card(x.Key).Cost)+(State.HeroSlots[slotId].Unit==MarisaActor?skill.Cost:0);return missing<=own&&missing<=Math.Max(0,State.EnemyCost-State.EnemySlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost));
        }
        void PayMarisaFunding(List<PortEvent> events)
        {
            if(!State.TouhouTeam)return;State.EnemyCost-=State.EnemySlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost);int missing=Math.Max(0,State.HeroSlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost)-State.Cost);if(missing==0)return;
            if(State.Heroes[MarisaActor].Hp<=missing*MarisaHealthPerCost||missing>State.EnemyCost)throw new InvalidOperationException("Unaffordable locked theft");
            State.Heroes[MarisaActor].Hp-=missing*MarisaHealthPerCost;State.EnemyCost-=missing;State.Cost+=missing;Emit(events,"ability","魔理沙用 "+missing*MarisaHealthPerCost+" 生命偷取 "+missing+" 敌方cost",MarisaActor);
        }
        void GainSpark(List<PortEvent> events,int amount)
        {if(MarisaActor<0)return;var s=State.Heroes[MarisaActor].RoleState;s.Spark=Math.Min(10,s.Spark+amount);Emit(events,"ability","火花 "+s.Spark+" / 10",MarisaActor);}
        int MarisaClashBonus(PortSlot slot,PortCard skill)
        {return IsMarisa(slot.Unit)?(MarisaHasCompanion()?-2:0)+(State.Heroes[MarisaActor].RoleState.Spark>5&&skill.Kind!="guard"?2:0):0;}
        bool MarisaHasCompanion()
        {return State.Heroes.Any(u=>u.CharacterId=="reimu"||u.CharacterId=="alice"||u.CharacterId=="patchouli");}
        void AttackNewHero(List<PortEvent> events,PortSlot slot,int target,CoinAction action,PortCard skill,ZixiContext context)
        {if(IsMarisa(slot.Unit))AttackMarisa(events,slot,target,action,skill,true);else if(skill.Id=="engraved_soul")AttackEngravedSoul(events,slot.Unit,target,action);else if(State.Heroes[slot.Unit].Zixi!=null)AttackZixi(events,slot,target,action,skill,context);else Attack(events,true,slot.Unit,target,action,skill);}
        int[] TouhouTargets(int primary,int capacity)
        {
            return new[]{primary}.Concat(Enumerable.Range(0,State.Enemies.Count)
                .Where(i=>i!=primary&&State.Enemies[i].Hp>0).Take(Math.Max(0,capacity-1))).ToArray();
        }
        void AttackEngravedSoul(List<PortEvent> events,int actor,int target,CoinAction action)
        {
            var targets=TouhouTargets(target,3);
            CoinStep step,last=null;
            var random=new CoinRandomSource(FlipCoin);
            while((step=action.NextAttack(random))!=null)
            {
                last=step;
                if(DealGroupHit(events,actor,action.Skill.Name,targets,id=>step.RawDamage,step).Length>0)
                    action.NotifyHit(step.Heads);
            }
            FinishTouhouHits(events,actor,target,action,last);
        }
        void AttackMarisa(List<PortEvent> events,PortSlot slot,int target,CoinAction action,PortCard skill,bool won)
        {
            bool laser=skill.Id=="marisa_laser",spark=skill.Id=="marisa_spark",meteor=skill.Id=="marisa_meteor",blazing=skill.Id=="marisa_blazing_star";
            var marisa=State.Heroes[MarisaActor];
            if(blazing&&marisa.Hp<10&&State.Cost<3)
            {Emit(events,"cancelled","炽热之星：支付完回合费用后不足3 cost，无法释放",slot.Unit,target);return;}
            var targets=TouhouTargets(target,spark?State.Enemies.Count:laser||blazing?3:1);
            int sparks=marisa.RoleState.Spark;
            int bonus=(MarisaHasCompanion()?5:0)+(sparks>5?2:0);
            if(spark){marisa.RoleState.Spark=0;Emit(events,"ability","极限火花：消耗 "+sparks+" 层火花",slot.Unit);}
            if(meteor){State.Cost+=2;Emit(events,"ability","龙陨石：恢复2 cost",slot.Unit);}
            int rawTotal=0;
            var hitTargets=new HashSet<int>();CoinStep step,last=null;
            while((step=action.NextAttack(new CoinRandomSource(FlipCoin)))!=null)
            {
                last=step;
                bool first=step.AttackIndex==1;
                int raw=spark?10*sparks:blazing?step.RawDamage*sparks:meteor?(first?10:0):step.RawDamage-(laser&&first?4:0);
                if(first&&!meteor&&(!(spark||blazing)||sparks>0))raw+=bonus;
                raw=Math.Max(0,raw);
                var report=step.Copy();
                rawTotal+=raw;
                report.TotalRawDamage=rawTotal;
                if(spark||laser||blazing)
                {
                    var hits=DealGroupHit(events,slot.Unit,skill.Name,targets,id=>raw,report,ignoreShield:blazing||spark&&sparks>=5);
                    if(hits.Length==0)continue;
                    foreach(var hit in hits)hitTargets.Add(hit.Target);
                }
                else
                {
                    if(State.Enemies[target].Hp<=0)continue;
                    DealNewHit(events,slot.Unit,target,raw,"strike",report,allowMapBonus:!meteor);
                }
                action.NotifyHit(step.Heads);
            }
            FinishTouhouHits(events,slot.Unit,target,action,last);
            if(won&&laser)GainSpark(events,hitTargets.Count);
            if(blazing)
            {
                if(marisa.Hp<10){State.Cost-=3;Emit(events,"ability","炽热之星：低血量代价 3 cost",slot.Unit);}
                else {marisa.Hp=10;Emit(events,"ability","炽热之星：魔理沙生命降至 10",slot.Unit);}
            }
        }
        void FinishTouhouHits(List<PortEvent> events,int source,int target,CoinAction action,CoinStep last)
        {
            action.CompleteAttack();
            if(last==null)return;
            var end=Emit(events,"attack_end",action.Skill.Name+" 攻击结束：消耗 "+action.AttackCount+" 枚硬币",source,target);
            end.Coin=last.Copy();
            end.Coin.Left=action.Snapshot();
        }
        int DealNewHit(List<PortEvent> events,int source,int target,int raw,string type,CoinStep coin=null,bool ignoreShield=false,bool allowMapBonus=true)
        {
            var victim=State.Enemies[target];
            if(victim.Hp<=0)return 0;
            int damage=ApplyEnemyHit(source,target,raw,FlandreReport(events,source,target),ignoreShield,allowMapBonus);
            var ev=Emit(events,type,victim.Name+" 原始 "+raw+" / 实伤 "+damage,source,target);
            ev.AttackerAllied=true;
            ev.Damage=damage;
            ev.Coin=ReportedCoin(coin,raw);
            return damage;
        }

        int ApplyEnemyHit(int source,int target,int raw,Action<string,bool> report,bool ignoreShield,bool allowMapBonus)
        {
            var victim=State.Enemies[target];
            int blocked=ignoreShield?0:Math.Min(victim.Shield,raw);
            int damage=raw-blocked;
            if(allowMapBonus)damage=MapFinalDamage(true,true,damage);
            victim.Shield-=blocked;
            var actor=State.Heroes[source];
            if(actor.FlandreDamageDownTurn==State.Turn)damage=Math.Max(0,damage-2);
            return FlandreSkills.Receive(victim,actor,PatchouliSkills.AdjustDamage(actor,victim,damage-2*actor.RedMist),report);
        }

        static CoinStep ReportedCoin(CoinStep coin,int raw)
        {
            if(coin==null)return null;
            var copy=coin.Copy();
            copy.RawModifier+=raw-copy.RawDamage;
            copy.RawDamage=raw;
            return copy;
        }

        PortHit[] DealGroupHit(List<PortEvent> events,int source,string skillName,IEnumerable<int> targets,
            Func<int,int> rawDamage,CoinStep coin=null,bool ignoreShield=false,int? allyDamage=null,Action<Unit> onEnemyHit=null)
        {
            var hits=new List<PortHit>();
            var notices=new List<Action>();
            foreach(int target in targets)
            {
                var enemy=State.Enemies[target];
                if(enemy.Hp<=0)continue;
                int raw=rawDamage(target);
                int damage=ApplyEnemyHit(source,target,raw,
                    (message,music)=>notices.Add(()=>FlandreReport(events,source,target)(message,music)),ignoreShield,true);
                if(onEnemyHit!=null)onEnemyHit(enemy);
                hits.Add(new PortHit(false,target,raw,damage));
            }
            if(allyDamage.HasValue)
            {
                int raw=allyDamage.Value;
                for(int target=0;target<State.Heroes.Count;target++)
                {
                    var ally=State.Heroes[target];
                    if(target==source||ally.Hp<=0)continue;
                    bool dodged=PatchouliSkills.Evades(ally,raw);
                    int blocked=dodged?0:Math.Min(raw,ally.Shield);
                    ally.Shield-=blocked;
                    int actor=target;
                    int damage=dodged?0:ReceiveAllyDamage(events,actor,null,
                        PatchouliSkills.AdjustDamage(null,ally,raw-blocked-2*State.Heroes[source].RedMist));
                    hits.Add(new PortHit(true,target,raw,damage));
                }
            }
            if(hits.Count==0)return new PortHit[0];

            string messageText=skillName+" · "+string.Join("、",hits.Select(hit=>
                (hit.Allied?State.Heroes:State.Enemies)[hit.Target].Name+" −"+hit.Damage+" HP"));
            var ev=Emit(events,coin==null?"status_damage":"strike",messageText,source);
            ev.Hits=hits.ToArray();
            ev.SkillName=skillName;
            ev.AttackerAllied=true;
            ev.Damage=hits.Sum(hit=>hit.Damage);
            ev.Coin=ReportedCoin(coin,hits[0].Raw);
            foreach(var notice in notices)notice();
            return ev.Hits;
        }
    }
}
