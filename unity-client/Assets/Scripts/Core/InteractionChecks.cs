using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class InteractionChecks
    {
        static int checks;
        static void Check(bool ok,string message) { checks++; if(!ok) throw new Exception("Click interaction failed: "+message); }
        public static int Run()
        {
            checks=0; var b=new BattleRules(); var ui=new BattleInteraction(b); string initial=b.State.Fingerprint();
            Check(ui.Hero==-1&&ui.Card==-1,"starts without implicit actor or card");
            Check(!ui.SelectSkill(0)&&!ui.SelectEnemy(0),"cannot skip actor and skill steps");
            Check(b.State.Fingerprint()==initial,"early enemy clicks do not spend or arrange");
            Check(ui.SelectHero(0)&&ui.SelectSkill(0),"actor then attack skill");
            Check(ui.WaitingForTarget&&b.State.Plans.Count==0&&b.State.Fingerprint()==initial,"skill selection waits without reservation");
            Check(ui.CanTarget(0)&&ui.CanTarget(1)&&!ui.CanTarget(-1)&&!ui.CanTarget(99),"only living in-range targets");
            Check(!ui.SelectEnemy(99)&&ui.Card==0&&b.State.Fingerprint()==initial,"invalid target preserves pending selection and state");
            Check(ui.SelectEnemy(0)&&ui.Committed&&ui.Card==-1,"third click commits without confirmation");
            Check(b.State.Plans.Count==1&&b.State.Plans[0].Hero==0&&b.State.Plans[0].Enemy==0,"correct actor skill and target");
            Check(b.State.Cost==9&&b.State.ReservedCost==3&&!b.State.Heroes[0].Acted,"selection reserves only, speed execution unchanged");
            string committed=b.State.Fingerprint(); Check(!ui.SelectEnemy(1)&&b.State.Fingerprint()==committed,"duplicate enemy click cannot create another action");
            ui.SelectHero(1); Check(ui.Card==-1&&ui.LastEnemy==-1,"switching actor resets pending targeting");
            Check(!ui.SelectSkill(0)&&ui.Card==-1,"other actor cannot use a reserved skill");
            ui.SelectSkill(1); ui.SelectHero(2); Check(ui.Hero==2&&ui.Card==-1&&!ui.CanTarget(1),"switch mid-targeting never inherits a skill");
            ui.SelectSkill(4); Check(ui.Committed&&ui.Card==-1&&b.State.Plans.Any(p=>p.Hero==2&&p.Enemy==-1),"guard self-targets on skill click");
            Check(b.State.Heroes[2].Shield==0,"guard still resolves by speed, not immediately");
            Check(ui.Cancel()&&b.State.Plans.Count==1&&b.State.ReservedCost==3,"cancel releases only selected actor plan");
            ui.SelectHero(0); ui.SelectSkill(2); ui.SelectEnemy(1);
            Check(b.State.Plans.Count==1&&b.State.Plans[0].Card==2&&b.State.Plans[0].Enemy==1&&b.State.ReservedCost==1,"three clicks replace plan without double charging");
            b.State.Heroes[1].Hp=0; Check(!ui.SelectHero(1)&&ui.Hero==0,"dead actor cannot replace selection");
            b.State.Enemies[0].Hp=0; ui.SelectSkill(1); string before=b.State.Fingerprint();
            Check(!ui.CanTarget(0)&&!ui.SelectEnemy(0)&&b.State.Fingerprint()==before&&ui.WaitingForTarget,"dead target ignored without consuming action");
            b.State.Cost=0; ui.ClearSkill(); Check(!ui.SelectSkill(0)&&ui.Card==-1,"unaffordable skill cannot enter targeting");
            b=new BattleRules(); ui=new BattleInteraction(b);
            b.State.Heroes[0].Speed=6; b.State.Heroes[1].Speed=7; b.State.Heroes[2].Speed=3;
            b.State.Enemies[0].Speed=5; b.State.Enemies[0].Target=2; b.State.Enemies[1].Speed=8; b.State.Enemies[1].Target=1;
            ui.SelectHero(1); ui.SelectSkill(0); ui.SelectEnemy(0);
            ui.SelectHero(0); ui.SelectSkill(1); ui.SelectEnemy(0);
            Check(b.ClashHero(0)==0,"last eligible click wins instead of faster earlier actor");
            ui.Cancel(); Check(b.ClashHero(0)==1,"cancel restores previous speed pairing");
            ui.SelectHero(2); ui.SelectSkill(2); Check(ui.CanTarget(1)&&!b.CanClash(2,1),"slower unopposed attack remains legal"); ui.SelectEnemy(1);
            Check(b.State.Plans.Any(p=>p.Hero==2&&p.Enemy==1),"click respects low-speed attack rule");
            ui.SelectHero(0); ui.SelectSkill(1); ui.SelectEnemy(0);
            var events=b.EndTurn(); Check(events.Any(e=>e.Type=="action")&&events.Count(e=>e.Type=="paid")==3,"existing speed resolver pays and executes team plans");
            b.State.Outcome="victory"; before=b.State.Fingerprint();
            Check(!ui.SelectHero(0)&&!ui.SelectSkill(0)&&!ui.SelectEnemy(0)&&b.State.Fingerprint()==before,"finished battle is noninteractive");
            ui.Clear(); Check(ui.Hero==-1&&ui.Card==-1&&!ui.WaitingForTarget,"restart clears all interaction state");
            return checks;
        }
    }
}
