using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public partial class PortBattleRules
    {
        bool SageAlive {get{return State.Heroes.Any(u=>PatchouliSkills.IsSummon(u)&&u.Hp>0);}}

        bool PlayPatchouliUtility(List<PortEvent> events,int source,PortCard skill)
        {
            var actor=State.Heroes[source];
            if(actor.Patchouli==null&&!PatchouliSkills.IsSummon(actor))return false;
            return PatchouliSkills.Utility(actor,skill.Id,State.Turn,State.Heroes.FirstOrDefault(PatchouliSkills.IsSummon),
                State.Heroes,State.Enemies,message=>Emit(events,"ability",message,source));
        }

        void PlayPatchouliAttack(List<PortEvent> events,int source,int target,PortCard skill,CoinAction action)
        {
            if(skill.NoDamage||PlayPatchouliUtility(events,source,skill))return;
            var actor=State.Heroes[source];
            var strike=new PatchouliStrike(actor,skill.Id,target,State.Enemies);
            var random=new CoinRandomSource(FlipCoin);
            CoinStep last=null;
            for(CoinStep step;actor.Hp>0&&(step=action.NextAttack(random))!=null;)
            {
                last=step;
                int raw=strike.Raw(step);
                var living=strike.Targets.Where(i=>State.Enemies[i].Hp>0).ToArray();
                if(living.Length==1)
                {
                    DealNewHit(events,source,living[0],raw,"strike",step,ignoreShield:strike.IgnoresShield);
                    strike.OnHit(State.Enemies[living[0]]);
                }
                else if(living.Length>1)
                    DealGroupHit(events,source,skill.Name,living,i=>raw,step,ignoreShield:strike.IgnoresShield,onEnemyHit:strike.OnHit);
                if(living.Length>0)action.NotifyHit(step.Heads);
                if(PatchouliSkills.Asthma(actor)>0)Emit(events,"ability","姆Q · 自身 −2 HP",source);
            }
            FinishTouhouHits(events,source,target,action,last);
        }

        void PlaySage(List<PortEvent> events,int source)
        {
            var actor=State.Heroes[source];
            if(!PatchouliSkills.SageCanAct(actor,State.Turn))return;
            var enemies=Enumerable.Range(0,State.Enemies.Count).Where(i=>State.Enemies[i].Hp>0).ToArray();
            if(enemies.Length==0)return;
            int target=enemies[rng.Range(enemies.Length)];
            var skill=PortContent.Card(PatchouliSkills.Variant((ElementStone)(rng.Range(5)+1),ElementStone.None));
            Emit(events,"ability","贤者之石 · 自动施放 "+skill.Name,source,target);
            if(!PlayPatchouliUtility(events,source,skill))
                PlayPatchouliAttack(events,source,target,skill,CoinRuntime(skill,true,source,target));
        }

        void FinishStoneDraw(List<PortEvent> events,int source,PortCard skill)
        {
            var actor=State.Heroes[source];
            if(actor.Patchouli!=null&&skill.Id==PatchouliSkills.Draw)
                Emit(events,"ability",PatchouliSkills.DrawStone(actor,rng),source);
        }

        void PatchouliEndRound(List<PortEvent> events)
        {
            for(int i=0;i<State.Heroes.Count;i++)
            {
                var actor=State.Heroes[i];
                if(actor.PatchouliBurn>0&&actor.Hp>0)
                {
                    int before=actor.Hp;
                    ReceiveAllyDamage(events,i,null,PatchouliSkills.AdjustDamage(null,actor,actor.PatchouliBurn));
                    Emit(events,"status_damage",actor.Name+" · 燃烧 −"+(before-actor.Hp)+" HP",i);
                }
            }
            for(int i=0;i<State.Enemies.Count;i++)
            {
                var unit=State.Enemies[i];
                if(unit.PatchouliBurn<=0||unit.Hp<=0)continue;
                int before=unit.Hp;
                FlandreSkills.Receive(unit,null,unit.PatchouliBurn,FlandreReport(events,-1,i));
                Emit(events,"status_damage",unit.Name+" · 燃烧 −"+(before-unit.Hp)+" HP",-1,i);
            }
        }
    }
}
