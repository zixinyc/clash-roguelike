using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class PortChecks
    {
        static int checks;
        static void Check(bool ok,string message){checks++;if(!ok)throw new Exception("Godot port: "+message);}
        sealed class Wins:PortBattleRules{protected override bool FlipCoin(double chance){return chance>.5;}}
        sealed class Loses:PortBattleRules{protected override bool FlipCoin(double chance){return chance<=.5;}}
        static void OnlyFirstAttack(PortBattleRules b)
        {foreach(var e in b.State.EnemySlots)e.Active=false;b.State.EnemySlots[0].Active=true;b.State.EnemySlots[0].Key="ember";b.State.EnemySlots[0].Target=0;b.State.Enemies[0].Hp=500;b.State.Enemies[0].MaxHp=500;}
        public static int Run()
        {
            checks=0;Check(PortContent.Cards.Length==33&&PortContent.Hand.Length==16,"translated definitions and hand");
            var b=new PortBattleRules();Check(b.State.Cost==30&&b.State.HeroSlots.Count==9&&b.State.EnemySlots.Count==6,"source economy and slot layout");
            Check(b.State.Heroes[0].Hp==48&&b.State.Heroes[1].Hp==42&&b.State.Heroes[2].Hp==46,"source role HP");
            Check(b.Snapshot().EnemySlots.All(x=>x.Key==""&&x.Card==-1)&&b.State.EnemySlots.Any(x=>x.Key!=""),"enemy cards hidden in response snapshot");
            Check(!b.Assign("all_in",0,0)&&!b.Assign("cover",1,0)&&!b.Assign("probe",2,0),"role ownership");
            string before=b.State.Fingerprint();Check(!b.Assign("cleave",0,99)&&b.State.Fingerprint()==before,"invalid target is inert");
            Check(b.Assign("cleave",0,0)&&b.Assign("guard",0,-1)&&!b.Assign("nova",0,1),"two actions per actor and category limits");
            Check(b.State.Cost==30&&b.State.Reserved==4,"only reserves before locking");
            Check(!b.Assign("guard",1,-1),"same physical card not duplicated");
            Check(b.Cancel(2)&&b.State.Reserved==3,"cancel releases slot reservation");
            b.Assign("probe",0,0);Check(b.State.HeroSlots[0].Key=="probe"&&b.State.Reserved==1,"same category replaces slot");
            b.State.HeroSlots[0].Speed=b.State.EnemySlots[0].Speed;b.State.EnemySlots[0].Target=2;
            Check(b.PairFor(0)==0,"preserves Unity same-speed interception");
            b.Assign("all_in",1,0);b.State.HeroSlots[3].Speed=b.State.HeroSlots[0].Speed+1;b.Assign("probe",0,0);
            Check(b.PairFor(0)==0,"preserves Unity last eligible designation");
            b.State.HeroSlots[0].Speed=1;b.State.EnemySlots[0].Speed=8;b.State.EnemySlots[0].Target=0;
            Check(b.CanClash(b.State.HeroSlots[0],b.State.EnemySlots[0]),"original target may answer slowly");
            b.State.EnemySlots[0].Target=2;Check(b.CanAssign("probe",0,0)==""&&!b.CanClash(b.State.HeroSlots[0],b.State.EnemySlots[0]),"slow unopposed attack stays legal");
            var shield=new Wins();foreach(var e in shield.State.EnemySlots)e.Active=false;
            shield.State.Heroes[0].Hp=0;shield.Assign("light_guard",2,-1);shield.Resolve();
            Check(shield.State.Heroes[2].Shield==9&&shield.State.Heroes[1].Shield==8&&shield.State.Heroes[0].Shield==0,"support guard and no revival");
            var observe=new Wins();foreach(var e in observe.State.EnemySlots)e.Active=false;observe.Assign("observe",0,0);observe.Resolve();
            Check(observe.State.Preparation==1,"observation obtains preparation after solo attack");
            var support=new Wins();foreach(var e in support.State.EnemySlots)e.Active=false;support.State.EnemySlots[0].Active=true;support.State.EnemySlots[0].Key="ember";support.State.EnemySlots[0].Target=2;support.Assign("support_strike",2,0);support.Resolve();
            Check(support.State.Heroes[0].Shield==4&&support.State.Heroes[1].Shield==4,"support strike grants ally shields");
            var exploit=new Wins();OnlyFirstAttack(exploit);exploit.State.Preparation=1;exploit.Assign("exploit",0,0);var exploitEvents=exploit.Resolve();
            Check(exploitEvents.First(x=>x.Type=="clash").Left==16&&exploitEvents.Any(x=>x.Message.Contains("消耗准备")&&x.Snapshot.Preparation==0),"exploit consumes preparation and adds four clash base power");
            var breaker=new Wins();OnlyFirstAttack(breaker);breaker.State.EnemySlots[0].Target=1;breaker.Assign("all_in",1,0);Check(breaker.Resolve().First(x=>x.Type=="clash").Left==17,"breaker adds two clash base power");
            var loss=new Loses();OnlyFirstAttack(loss);loss.State.EnemySlots[0].Target=1;loss.Assign("all_in",1,0);var lossEvents=loss.Resolve();
            Check(lossEvents.Any(x=>x.Message.Contains("损失 2")&&x.Snapshot.Heroes[1].Hp==40),"breaker failure loses two HP before retaliation");
            Check(lossEvents.Count(x=>x.Type=="refund")==1,"one partial refund for complete clash loss");
            var follow=new Wins();OnlyFirstAttack(follow);follow.Assign("follow",0,0);var followEvents=follow.Resolve();Check(followEvents.Where(x=>x.Type=="strike").Select(x=>x.Damage).SequenceEqual(new[]{8,11}),"follow uses its two remaining coins with cumulative damage and no third attack");
            var priest=new PortBattleRules(5,1);foreach(var e in priest.State.EnemySlots)e.Active=false;priest.State.EnemySlots[2].Active=true;priest.State.EnemySlots[2].Key="guard";priest.Resolve();Check(priest.State.Enemies[0].Shield==9&&priest.State.Enemies[1].Shield==6,"priest guards allies");
            var warden=new PortBattleRules();foreach(var e in warden.State.EnemySlots)e.Active=false;warden.State.EnemySlots[5].Active=true;warden.State.EnemySlots[5].Key="guard";warden.Resolve();Check(warden.State.Enemies[1].Shield==14,"warden enhanced guard");
            b=new PortBattleRules();before=b.State.Fingerprint();Check(!b.Tick(-1)&&b.State.Fingerprint()==before,"negative timer ignored");Check(b.Tick(180),"180 second response");
            b.Resolve();Check(b.State.Phase=="finished"||b.State.Outcome!="","round resolves");int oldCost=b.State.Cost;b.NextRound();Check(b.State.Turn==2&&b.State.Cost==oldCost+8&&b.State.Remaining==180,"new round income and response reset");
            for(uint seed=1;seed<=30;seed++)
            {
                var a=new PortBattleRules(seed);var c=new PortBattleRules(seed);a.Assign("probe",0,0);c.Assign("probe",0,0);a.Assign("cover",2,-1);c.Assign("cover",2,-1);
                var ea=a.Resolve();var ec=c.Resolve();Check(a.State.Fingerprint()==c.State.Fingerprint(),"same seed same result");Check(string.Join("|",ea.Select(x=>x.Message).ToArray())==string.Join("|",ec.Select(x=>x.Message).ToArray()),"same event sequence");
                int hp=a.State.Heroes[0].Hp;var snapshot=a.Snapshot();snapshot.Heroes[0].Hp=-999;Check(a.State.Heroes[0].Hp==hp,"snapshot isolation");
            }
            var map=new ExplorationRun();Check(!map.Move(3,1)&&map.X==0,"nonadjacent movement blocked");Check(map.Move(1,1)&&map.Seen.Contains(8),"adjacency and reveal");
            Check(map.Move(2,1)&&map.InBattle,"map enters battle");var fight=map.CreateBattle();fight.State.Cost=22;fight.State.Heroes[0].Hp=31;fight.State.Outcome="victory";
            Check(map.FinishBattle(fight.State)&&map.Cost==26&&map.Hp[0]==31&&map.Cleared.Contains(8),"carry wallet HP and reward");
            Check(!map.FinishBattle(fight.State)&&map.Cost==26,"reward cannot be claimed twice");map.Move(1,1);map.Move(2,1);Check(!map.InBattle,"cleared battle does not repeat");
            map=new ExplorationRun();map.Move(1,1);map.Move(1,2);map.Hp=new[]{2,0,9};int old=map.Cost;Check(map.Choose(1)&&map.Cost==old+12&&map.Hp.SequenceEqual(new[]{1,0,5}),"event trade and living HP floor");
            Check(!map.Choose(1),"event cannot repeat");map=new ExplorationRun();map.X=3;map.Y=2;map.Pending="shop";map.Cost=5;Check(!map.Choose(0)&&map.Cost==5,"shop funds");Check(map.LeaveShop()&&map.Pending=="","leave shop");
            map.Pending="shop";map.Cost=10;map.Hp=new[]{40,0,20};Check(map.Choose(0)&&map.Cost==4&&map.Hp.SequenceEqual(new[]{48,0,28}),"shop healing no revival");
            map=new ExplorationRun();map.X=4;map.Y=1;map.Move(5,1);Check(map.Finished,"map exit");
            return checks;
        }
    }
}
