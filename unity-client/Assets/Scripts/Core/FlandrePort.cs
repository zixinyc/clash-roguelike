using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public partial class PortBattleRules
    {
        public void ConfigureFlandre(Unit member)
        {
            if(State.Turn!=1||State.PlanCount!=0||!State.TouhouTeam||member.Flandre==null)
                throw new InvalidOperationException("Flandre must be configured before the first turn.");
            State.Heroes[1]=member.Copy();
            PrepareRound();
        }

        Action<string,bool> FlandreReport(List<PortEvent> events,int hero,int enemy=-1)
        {
            return (message,music)=>Emit(events,music?FlandreSkills.MusicEvent:"ability",message,hero,enemy);
        }

        bool UseFlandreSupport(List<PortEvent> events,PortSlot slot)
        {
            var actor=State.Heroes[slot.Unit];
            if(actor.Flandre==null)return false;
            return FlandreSkills.UseSupport(actor,slot.Key,State.Turn,
                power=>DealGroupHit(events,slot.Unit,PortContent.Card(slot.Key).Name,Enumerable.Range(0,State.Enemies.Count),id=>power),
                FlandreReport(events,slot.Unit));
        }

        void FlandreAttack(List<PortEvent> events,PortSlot slot,int primary,CoinAction action,PortCard card)
        {
            var source=State.Heroes[slot.Unit];
            var random=new CoinRandomSource(FlipCoin);
            var targets=FlandreSkills.Targets(card.Id,primary,State.Enemies).ToArray();
            bool ripple=card.Id==FlandreSkills.Ripple;
            bool group=FlandreSkills.HitsAllEnemies(card.Id)||card.Id==FlandreSkills.Rainbow;
            CoinStep last=null;
            for(CoinStep step;(step=action.NextAttack(random))!=null;)
            {
                last=step;
                int power=ripple?
                    FlandreSkills.RipplePower(source,FlandreReport(events,slot.Unit)):
                    Math.Max(0,step.RawDamage);
                if(group)
                {
                    var hits=DealGroupHit(events,slot.Unit,card.Name,targets,id=>power,step,
                        allyDamage:ripple?(int?)power:null,onEnemyHit:enemy=>
                        {
                            if(card.Id==FlandreSkills.Clock&&FlandreSkills.MemberCanAct(enemy))
                                enemy.FlandreDamageDownTurn=State.Turn+1;
                        });
                    if(hits.Any(hit=>!hit.Allied))action.NotifyHit(step.Heads);
                }
                else if(State.Enemies[primary].Hp>0)
                {
                    DealNewHit(events,slot.Unit,primary,power,"strike",step);
                    action.NotifyHit(step.Heads);
                }
            }
            FinishTouhouHits(events,slot.Unit,primary,action,last);
        }

        void AttackOwnPuppet(List<PortEvent> events,PortSlot slot,PortCard card)
        {
            var target=State.Enemies[slot.Target];
            if(!target.Puppet)return;
            var rolls=new CoinAction(card.CoinData,.5,State.Enemies[slot.Unit].Statuses);
            var random=new CoinRandomSource(FlipCoin);
            for(CoinStep step;(step=rolls.NextAttack(random))!=null;)
                FlandreSkills.Receive(target,null,Math.Max(1,step.RawDamage),FlandreReport(events,-1,slot.Target));
            rolls.CompleteAttack();
        }
    }
}
