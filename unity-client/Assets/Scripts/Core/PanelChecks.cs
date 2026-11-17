using System;

namespace ClashRoguelike
{
    public static class PanelChecks
    {
        static int checks;
        static void Check(bool ok,string message) { checks++; if(!ok) throw new Exception("Dynamic panel failed: "+message); }
        static void Plan(BattleInteraction ui,int actor,int card,int target)
        { ui.SelectHero(actor); ui.SelectSkill(card); ui.SelectEnemy(target); }
        public static int Run()
        {
            checks=0; var b=new BattleRules(); var ui=new BattleInteraction(b); string before=b.State.Fingerprint();
            Check(ui.ActiveStep==0&&ui.PanelStatus=="等待操作","initial phase");
            Check(!ui.CanPrepare&&!ui.CanUndo&&!ui.CanPlayPrepared&&!ui.Prepare(),"empty round cannot enter demonstration");
            Check(b.State.Fingerprint()==before,"rejected preparation is read-only");
            ui.SelectHero(0); Check(ui.ActiveStep==1&&ui.PanelHint=="请选择技能。","actor phase");
            ui.SelectSkill(0); Check(ui.ActiveStep==2&&ui.PanelStatus=="选择目标"&&!ui.CanPrepare,"pending target blocks readiness");
            ui.SelectEnemy(0); Check(ui.PanelStatus=="安排完成"&&ui.ActiveStep==-1&&ui.CanPrepare&&ui.CanUndo,"completed plan feedback and undo");
            before=b.State.Fingerprint(); Check(ui.Prepare()&&ui.Prepared&&ui.CanPlayPrepared&&!ui.CanPrepare,"only demonstration available once prepared");
            Check(b.State.Fingerprint()==before&&b.State.Cost==9&&b.State.ReservedCost==3,"preparation does not resolve or spend");
            Check(!ui.SelectHero(1)&&!ui.SelectSkill(1)&&!ui.SelectEnemy(1)&&!ui.Cancel(),"prepared selections cannot be edited");
            Check(b.State.Fingerprint()==before,"locked actions remain intact");
            Check(!ui.Prepare()&&ui.Prepared,"double prepare cannot toggle readiness");
            ui.ResumePlanning(); Check(!ui.Prepared&&ui.CanPrepare&&ui.CanUndo&&!ui.CanPlayPrepared,"return to editing without releasing plans");
            Check(b.State.Fingerprint()==before,"return to editing preserves plans and speed");
            ui.SelectSkill(1); Check(!ui.CanPrepare&&!ui.Prepare()&&ui.WaitingForTarget,"unfinished replacement blocks preparation");
            ui.ClearSkill(); Check(ui.CanPrepare,"cancel pending selection restores readiness");
            ui.Cancel(); Check(!ui.CanPrepare&&!ui.CanUndo&&b.State.ReservedCost==0,"undo final arrangement disables prepare");
            Plan(ui,0,0,0); Plan(ui,1,1,1); Plan(ui,2,2,0);
            Check(ui.AllArranged&&ui.PanelStatus=="全部已安排"&&ui.CanPrepare,"all actors arranged");
            ui.SelectSkill(4); Check(ui.AllArranged&&ui.CanPrepare,"self-target guard remains complete");
            ui.SelectSkill(2); Check(ui.WaitingForTarget&&!ui.AllArranged&&!ui.CanPrepare,"all plans do not override unfinished editing");
            ui.ClearSkill(); ui.Prepare(); ui.ResumePlanning(); ui.Cancel();
            Check(!ui.AllArranged&&ui.CanPrepare,"partial team may leave others waiting under existing rules");
            b.State.Heroes[0].Hp=0; Check(!ui.CanPrepare,"stale dead-actor plan cannot prepare");
            b=new BattleRules(); ui=new BattleInteraction(b); b.State.Heroes[1].Hp=0; b.State.Heroes[2].Hp=0;
            Plan(ui,0,0,0); Check(ui.AllArranged&&ui.CanPrepare,"only living actors count toward completion");
            ui.Prepare(); b.State.Enemies[0].Hp=0; Check(!ui.CanPlayPrepared,"stale dead-target plan cannot start");
            b.Start(); ui.Clear(); Check(!ui.Prepared&&!ui.CanPlayPrepared&&ui.ActiveStep==0,"reset clears panel phase");
            b.State.Outcome="victory"; Check(!ui.CanPrepare&&!ui.Prepare(),"finished battle cannot prepare");
            return checks;
        }
    }
}
