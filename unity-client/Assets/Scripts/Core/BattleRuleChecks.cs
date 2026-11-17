using System;
using System.Linq;
using System.Collections.Generic;

namespace ClashRoguelike
{
    // Runs independently and in Unity; failures stop the Windows build.
    public static class BattleRuleChecks
    {
        static int checks;
        static void Check(bool condition,string message) { checks++; if(!condition) throw new Exception("Rule check failed: "+message); }
        sealed class ThreeTies : BattleRules
        { int flips;protected override bool FlipCoin(double chance){return ++flips>12&&chance>.5;} }
        static BattleRules Quiet()
        {
            var b=new BattleRules(23);
            foreach(var u in b.State.Heroes.Concat(b.State.Enemies)) { u.Hp=1000; u.MaxHp=1000; u.Speed=4; }
            foreach(var e in b.State.Enemies) { e.Base=0; e.ClashCoinPower=e.AttackCoinPower=0; e.Coins=1; e.Target=2; }
            return b;
        }
        static BattleEvent[] Actions(List<BattleEvent> events) { return events.Where(x=>x.Type=="action").ToArray(); }
        static void ArrangeTeam(BattleRules b)
        {
            for(int h=0;h<b.State.Heroes.Count;h++)
            {
                if(b.State.Heroes[h].Hp<=0) continue;
                int target=b.State.Enemies.FindIndex(e=>e.Hp>0&&e.Target==h);
                if(target<0) target=b.State.Enemies.FindIndex(e=>e.Hp>0);
                for(int c=0;c<b.State.Hand.Count;c++) if(b.CanPlay(c,h,target)=="") { b.Play(c,h,target); break; }
            }
        }
        public static int Run()
        {
            checks=0;
            var b=new BattleRules(); string before=b.State.Fingerprint();
            Check(b.Play(-1,0,0).Count==0&&b.Play(0,-1,0).Count==0&&b.Play(0,0,99).Count==0,"invalid inputs rejected");
            Check(b.State.Fingerprint()==before,"invalid inputs leave state untouched");
            Check(b.State.Heroes.Concat(b.State.Enemies).All(u=>u.Speed>=u.MinSpeed&&u.Speed<=u.MaxSpeed),"initial speed ranges");
            b.State.Cost=0; Check(b.Play(0,0,0).Count==0,"empty wallet");
            b.State.Cost=9; b.State.Heroes[0].Hp=0; Check(b.Play(0,0,0).Count==0,"dead actor");

            b=Quiet(); var planEvents=b.Play(0,0,0);
            Check(planEvents.Count==1&&planEvents[0].Type=="planned","arranging does not resolve");
            Check(b.State.Cost==9&&b.State.ReservedCost==3&&b.State.Heroes.All(h=>h.Hp==1000&&!h.Acted)&&b.State.Enemies.All(e=>!e.Spent),"reservation leaves wallet and combat untouched");
            Check(b.State.Hand.Count==5&&b.State.Plays==1,"hand indices remain stable while planning");
            before=b.State.Fingerprint(); Check(b.Play(0,1,0).Count==0&&b.State.Fingerprint()==before,"cannot reserve the same card twice");
            b.Play(2,0,1); Check(b.State.ReservedCost==1&&b.State.Plays==1&&b.State.Plans[0].Enemy==1,"replacement releases previous reservation");
            b.State.Cost=1; before=b.State.Fingerprint();
            Check(b.Play(0,0,0).Count==0&&b.State.Fingerprint()==before,"unaffordable replacement preserves old action");
            Check(b.Play(2,0,0).Count==1&&b.State.ReservedCost==1,"own reserved card can be retargeted");
            Check(b.Cancel(0)&&b.State.ReservedCost==0&&b.State.Plays==0,"cancel releases card and cost");
            before=b.State.Fingerprint(); Check(!b.Cancel(0)&&b.State.Fingerprint()==before,"repeat cancellation is harmless");

            b=Quiet(); b.State.Heroes[0].Speed=8; b.State.Heroes[1].Speed=5;
            b.Play(0,0,0); b.Play(1,1,0);
            Check(b.ClashHero(0)==1,"last eligible assignment wins over faster actor");
            b.State.Heroes[1].Speed=4; Check(b.ClashHero(0)==1,"equal speed can redirect");
            b.State.Heroes[1].Speed=3; Check(b.ClashHero(0)==0,"ineligible slower attack cannot steal clash");
            b.State.Heroes[2].Speed=1; b.Play(2,2,0);
            Check(b.ClashHero(0)==2,"original target can take clash back at lower speed");
            b.Cancel(2); Check(b.ClashHero(0)==0,"cancelling latest restores prior eligible assignment");
            b.State.Heroes[1].Speed=5; b.Play(1,1,0); b.Play(0,0,0);
            Check(b.ClashHero(0)==0,"reconfirming an existing assignment makes it last");
            b.Play(4,0,-1); Check(b.ClashHero(0)==1,"switching to guard releases clash");
            b.Play(2,2,1); Check(b.State.Plays==3&&b.Play(1,1,1).Count==1&&b.State.Plays==3,"all three actors can still replace actions");

            b=Quiet(); b.State.Heroes[0].Speed=2; b.State.Enemies[0].Speed=8;
            b.State.Enemies[0].Base=1; b.Play(0,0,0);
            Check(!b.CanClash(0,0)&&b.CanPlay(0,0,0)=="","low speed may attack without clashing");
            var events=b.EndTurn(); var actions=Actions(events);
            Check(!events.Any(e=>e.Type=="clash"),"different original target prevents low-speed clash");
            Check(actions[0].Enemy==0&&!actions[0].Allied&&actions[0].Speed==8,"unopposed faster enemy acts first");
            Check(actions.Last().Hero==0&&actions.Last().Allied&&actions.Last().Speed==2,"slower unopposed attack is retained");
            Check(events.Any(e=>e.Type=="strike"&&!e.Allied&&e.Target==2)&&events.Any(e=>e.Type=="strike"&&e.Allied&&e.Target==0),"both unpaired attacks deal damage");
            Check(!events.Any(e=>e.Type=="refund"||e.Type=="reward"),"unopposed actions have no clash economy");
            Check(b.State.Cost==9-3+3&&b.State.Plans.Count==0&&b.State.ReservedCost==0,"pay exactly once then add income");

            b=Quiet(); b.State.Heroes[2].Speed=1; b.State.Enemies[0].Speed=8; b.Play(0,2,0);
            events=b.EndTurn(); actions=Actions(events);
            Check(actions[0].Hero==2&&actions[0].Speed==8&&actions[0].Result=="拼点","slow original target responds at attacker speed");
            Check(actions.Count(e=>e.Allied&&e.Hero==2)==1&&actions.Count(e=>e.Enemy==0)==1,"clash consumes both actions exactly once");

            b=Quiet(); foreach(var e in b.State.Enemies) e.Target=0;
            b.Play(0,0,0); b.Play(1,1,1); b.Play(4,2,-1);
            events=b.EndTurn(); actions=Actions(events);
            Check(actions.Length==3&&actions.All(e=>e.Speed==4),"equal-speed clashes and guard resolve independently");
            Check(actions.Select(e=>e.Hero).SequenceEqual(new[]{0,1,2}),"equal-speed order is stable and visible");
            Check(events.Where(e=>e.Type=="clash").Select(e=>e.Enemy).Distinct().Count()==2,"two separate same-speed clashes");
            Check(events.Count(e=>e.Type=="reward")==1,"only first clash win pays reward");
            Check(b.State.Heroes.All(h=>!h.Acted&&h.Shield==0)&&b.State.Enemies.All(e=>!e.Spent),"new turn refreshes actions and shields");
            Check(b.State.Heroes.Concat(b.State.Enemies).All(u=>u.Speed>=u.MinSpeed&&u.Speed<=u.MaxSpeed),"new turn speed ranges");

            foreach(bool fastGuard in new[]{true,false})
            {
                b=Quiet(); b.State.Heroes[0].Speed=fastGuard?9:1; b.State.Enemies[0].Speed=6; b.State.Enemies[0].Base=6; b.State.Enemies[0].Target=0;
                b.Play(4,0,-1); events=b.EndTurn();
                Check(events.Any(e=>e.Type=="strike"&&e.Blocked>0)==fastGuard,"guard takes effect only at its execution speed");
                Check(events.Count(e=>e.Type=="paid")==1&&events.Count(e=>e.Type=="guard")==1,"guard charged and performed once");
            }

            b=Quiet(); b.State.Heroes[0].Speed=9; b.State.Heroes[1].Speed=5; b.State.Enemies[0].Hp=1;
            b.Play(0,0,0); b.Play(1,1,0); events=b.EndTurn();
            Check(events.Any(e=>e.Type=="cancelled"&&e.Hero==1),"early unilateral kill cancels later locked clash");
            Check(!events.Any(e=>e.Type=="clash")&&!Actions(events).Any(e=>!e.Allied&&e.Enemy==0),"dead target neither clashes nor retargets");
            Check(events.Count(e=>e.Type=="paid")==2&&!events.Any(e=>e.Type=="refund"),"cancelled committed action is not refunded");
            var locked=events.First(e=>e.Type=="strike"&&e.Allied).Snapshot;
            Check(BattleRules.ClashHero(locked,0)==1,"display keeps the locked clash partner after target dies");
            locked.LockedClashes[0]=0;
            Check(events.First(e=>e.Type=="paid").Snapshot.LockedClashes[0]==1,"locked pairings are isolated between event snapshots");

            b=Quiet(); b.State.Heroes[0].Hp=1; b.State.Heroes[0].Speed=1;
            b.State.Enemies[0].Speed=8; b.State.Enemies[0].Target=0; b.State.Enemies[0].Base=100;
            b.Play(0,0,1); events=b.EndTurn();
            Check(events.Any(e=>e.Type=="cancelled"&&e.Hero==0)&&!events.Any(e=>e.Type=="strike"&&e.Allied),"actor killed before own turn cannot attack");

            foreach(string key in new[]{"cleave","ember","needle"})
            {
                b=Quiet(); b.State.Hand[0]=key; b.State.Enemies[0].Base=100; b.State.Enemies[0].ClashCoinPower=b.State.Enemies[0].AttackCoinPower=0;
                b.State.Enemies[0].Target=0; b.Play(0,0,0); events=b.EndTurn(); int paid=BattleRules.GetSkill(key).Cost;
                Check(events.Count(e=>e.Type=="refund")==1&&events.First(e=>e.Type=="refund").Amount==paid/2,"one refund using floor half of paid cost");
                Check(b.State.Cost==9-paid+paid/2+3,"loss wallet accounting");
            }

            b=Quiet(); b.Play(0,0,0); events=b.EndTurn();
            before=b.State.Fingerprint(); events[0].Snapshot.Plans[0].Enemy=99; events[0].Snapshot.Heroes[0].Hp=0; events[0].Snapshot.Hand.Clear();
            Check(b.State.Fingerprint()==before,"event snapshots deeply isolate plans, units and hand");
            var direct=Quiet(); var revised=Quiet(); direct.Play(0,0,0);
            revised.Play(1,0,1); revised.Cancel(0); revised.Play(0,0,0);
            direct.EndTurn(); revised.EndTurn(); Check(direct.State.Fingerprint()==revised.State.Fingerprint(),"planning edits never consume RNG or change final result");

            b=new ThreeTies();b.State.Enemies[0].Base=5;b.State.Enemies[0].ClashCoinPower=b.State.Enemies[0].AttackCoinPower=0;b.State.Enemies[1].Hp=0;b.Play(0,0,0);events=b.EndTurn();var ties=events.Where(e=>e.Type=="clash").ToArray();
            Check(ties.Take(3).All(e=>e.Winner<0&&e.HeroRemaining==2&&e.EnemyRemaining==2)&&ties.All(e=>!e.Decider)&&ties.Last().EnemyRemaining==0,"three ties preserve coins and continue until an actual power difference");
            b=new BattleRules(); b.State.Enemies[0].Hp=1; b.State.Enemies[0].Spent=true; b.State.Enemies[1].Hp=0;
            b.Play(0,0,0); events=b.EndTurn();
            Check(b.State.Outcome=="victory"&&events.Last().Type=="outcome"&&!b.State.Resolving&&b.State.Plans.Count==0,"victory closes resolution cleanly");
            Check(b.Play(0,1,0).Count==0&&b.EndTurn().Count==0&&!b.Cancel(0),"finished battle rejects commands");
            b.Start(); Check(b.State.Outcome==""&&b.State.Cost==9&&b.State.Turn==1&&b.State.Plans.Count==0,"restart resets planning");
            foreach(var h in b.State.Heroes) h.Hp=1; foreach(var e in b.State.Enemies) e.Base=100;
            for(int i=0;i<4&&b.State.Outcome=="";i++) b.EndTurn();
            Check(b.State.Outcome=="defeat"&&!b.State.Resolving,"party defeat terminates");

            for(uint seed=1;seed<=60;seed++)
            {
                var first=new BattleRules(seed); var second=new BattleRules(seed);
                for(int round=0;round<50&&first.State.Outcome=="";round++)
                {
                    ArrangeTeam(first); ArrangeTeam(second);
                    Check(first.State.ReservedCost<=first.State.Cost,"reservations never overdraw wallet");
                    var a=first.EndTurn(); var c=second.EndTurn();
                    Check(string.Join("|",a.Select(e=>e.Fingerprint()).ToArray())==string.Join("|",c.Select(e=>e.Fingerprint()).ToArray()),"deterministic full event log");
                    Check(first.State.Fingerprint()==second.State.Fingerprint(),"deterministic final state");
                    var sequence=a.Where(e=>e.Type=="action"||e.Type=="cancelled").ToArray();
                    Check(sequence.Select(e=>e.Speed).SequenceEqual(sequence.Select(e=>e.Speed).OrderByDescending(v=>v)),"all queued actions run by descending speed");
                    Check(Actions(a).Where(e=>e.Allied).GroupBy(e=>e.Hero).All(g=>g.Count()==1),"no actor executes twice");
                    Check(Actions(a).Where(e=>!e.Allied||e.Result=="拼点").GroupBy(e=>e.Enemy).All(g=>g.Count()==1),"no enemy action executes twice");
                    Check(first.State.Cost>=0&&first.State.Heroes.Concat(first.State.Enemies).All(u=>u.Hp>=0&&u.Hp<=u.MaxHp&&u.Shield>=0),"resource and life bounds");
                    before=first.State.Fingerprint(); foreach(var ev in a) { var display=ev.Snapshot.Copy(); display.Cost=0; display.Plans.Clear(); }
                    Check(first.State.Fingerprint()==before,"playback cannot mutate authoritative state");
                }
                Check(first.State.Outcome!="","seeded full battle terminates");
            }
            return checks;
        }
    }
}
