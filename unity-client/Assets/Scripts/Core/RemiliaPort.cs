using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public partial class PortBattleRules
    {
        void PlayRemiliaAction(List<PortEvent> events,int actor,int target,PortCard card,CoinAction action,bool fromClash)
        {
            var unit=State.Heroes[actor];
            if(RemiliaSkills.CastCurse(unit,card.Id,State.Turn))
            {
                Emit(events,"guard","弗拉德·采佩什的诅咒：敌方全体受诅咒，持续至下回合末。",actor,target);
                return;
            }
            if(card.NoDamage)return;
            var strike=new RemiliaStrike(unit,card.Id,target,State.Enemies,fromClash);
            var random=new CoinRandomSource(FlipCoin);
            CoinStep last=null;
            for(CoinStep step;(step=action.NextAttack(random))!=null;)
            {
                last=step;
                var living=strike.Targets.Where(i=>State.Enemies[i].Hp>0).ToArray();
                if(living.Length==0)continue;
                var before=living.Select(i=>State.Enemies[i].Hp).ToArray();
                if(living.Length==1)
                    DealNewHit(events,actor,living[0],strike.Raw(living[0],step),"strike",step);
                else
                    DealGroupHit(events,actor,card.Name,living,i=>strike.Raw(i,step),step);
                for(int i=0;i<living.Length;i++)strike.RecordHit(living[i],before[i]-State.Enemies[living[i]].Hp);
                action.NotifyHit(step.Heads);
            }
            FinishTouhouHits(events,actor,target,action,last);
            Emit(events,"ability",strike.Finish(State.Enemies),actor,target);
        }

        void TryRemiliaCounter(List<PortEvent> events,int enemy)
        {
            int actor=State.Actor(RemiliaSkills.Id);
            if(actor<0||!FlandreSkills.MemberCanAct(State.Enemies[enemy])||
                !RemiliaSkills.SpendCounter(State.Heroes[actor],State.Turn))return;
            var card=PortContent.Card(RemiliaSkills.Star);
            Emit(events,"ability","诅咒反击 · 大卫之星",actor,enemy);
            PlayRemiliaAction(events,actor,enemy,card,CoinRuntime(card,true,actor,enemy),false);
        }

        int ReceiveAllyDamage(List<PortEvent> events,int target,Unit attacker,int damage,int enemy=-1)
        {
            var victim=State.Heroes[target];
            int before=victim.Hp;
            if(RemiliaSkills.PreventDefeat(victim,damage,ref State.Cost))
            {
                Emit(events,"ability",victim.Name+" · 最有威严之人：消耗 10 cost，保留 1 HP",target,enemy);
                return before-1;
            }
            return FlandreSkills.Receive(victim,attacker,damage,FlandreReport(events,target,enemy));
        }
    }
}
