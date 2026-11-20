using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    public static class CoinChecks
    {
        static int checks;static void Check(bool ok,string message){checks++;if(!ok)throw new Exception("Coin rules: "+message);}
        sealed class Script:ICoinRandom
        {readonly List<bool> faces;int faceIndex;public int Calls;public Script(params bool[] results){faces=new List<bool>(results);}public bool Flip(double chance){Calls++;if(faceIndex>=faces.Count)throw new Exception("Unexpected extra coin roll");return faces[faceIndex++];}}
        sealed class Constant:ICoinRandom{public int Calls;public bool Flip(double chance){Calls++;return false;}}
        sealed class Recorded:ICoinRandom{readonly BattleRandom rng;public int Calls;public Recorded(uint seed){rng=new BattleRandom(seed);}public bool Flip(double c){Calls++;return rng.Flip(c);}}
        sealed class TailsPort:PortBattleRules{protected override bool FlipCoin(double chance){return false;}}
        sealed class EnemyHeadsPort:PortBattleRules{protected override bool FlipCoin(double chance){return chance<=.5;}}
        static CoinAction Act(int basis,int clash,int attack,int coins,IEnumerable<CoinEffect> effects=null){return new CoinAction(new CoinSkill("测试技能",basis,clash,attack,coins,effects),.5);}
        static List<CoinStep> Strikes(CoinAction a,ICoinRandom rng){var list=new List<CoinStep>();CoinStep step;while((step=a.NextAttack(rng))!=null)list.Add(step);return list;}
        public static int Run()
        {
            checks=0;
            // 1,3: unequal rounds remove exactly one loser coin, stop immediately at zero.
            var l=Act(6,2,4,3);var r=Act(1,1,2,2);var rolls=new Script(false,false,false,false,false, false,false,false,false);
            var clash=new CoinClash(l,r,rolls);var a=clash.Step();Check(a.LeftPower==6&&a.RightPower==1&&a.LeftRemaining==3&&a.RightRemaining==1,"one loser coin, not one coin per toss");
            var b=clash.Step();Check(clash.Complete&&clash.Winner==0&&r.RemainingCoins==0&&l.RemainingCoins==3,"continuous losses finish at zero");int calls=rolls.Calls;
            Check(clash.Step()==null&&rolls.Calls==calls&&r.NextAttack(rolls)==null,"finished clash never rerolls and loser cannot attack");
            var attacks=Strikes(l,new Script(true,false,true));Check(attacks.Count==3&&l.RemainingCoins==0&&l.AttackCount==3,"winner attacks exactly three surviving coins");
            Check(attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{10,10,14})&&l.TotalRawDamage==34,"winner carries attack coin power through tails and later heads");
            // 2: ties preserve all coins; the next round is a fresh complete reroll.
            l=Act(5,2,7,2);r=Act(5,2,1,2);rolls=new Script(true,false,false,true, true,true,false,false, true,true,false);
            clash=new CoinClash(l,r,rolls);a=clash.Step();Check(a.Winner==-1&&l.RemainingCoins==2&&r.RemainingCoins==2&&!clash.Complete,"tie does not spend either side");
            b=clash.Step();Check(b.LeftFaces.SequenceEqual(new[]{true,true})&&b.RightFaces.SequenceEqual(new[]{false,false})&&b.LeftPower==9&&b.RightPower==5,"tie rerolls all and starts again from base");
            a=clash.Step();Check(a.LeftFaces.Length==2&&a.RightFaces.Length==1&&clash.Complete,"next round rolls current remaining counts");
            // 4,5: sides can alternate wins; throwing never removes coins by itself.
            l=Act(5,2,3,2);r=Act(5,2,4,2);rolls=new Script(true,true,false,false, false,false,true, true,false);clash=new CoinClash(l,r,rolls);
            var steps=new[]{clash.Step(),clash.Step(),clash.Step()};Check(steps.Select(x=>x.Winner).SequenceEqual(new[]{0,1,0}),"wins can alternate without resetting lost coins");
            Check(steps.Select(x=>x.LeftPower).SequenceEqual(new[]{9,5,7})&&steps.Select(x=>x.RightPower).SequenceEqual(new[]{5,7,5}),"round scores do not inherit prior heads");
            Check(rolls.Calls==9&&l.RemainingCoins==1&&r.RemainingCoins==0,"rolls sum to all remaining coins each round");
            attacks=Strikes(l,new Script(false));Check(attacks.Count==1&&attacks[0].RawDamage==5&&r.NextAttack(new Script())==null,"lost clash coins never become attacks");
            // Distinct clash/attack powers; each attack flips one surviving coin and carries its contribution.
            var independent=Act(5,2,7,3);rolls=new Script(false,true,false);attacks=Strikes(independent,rolls);
            Check(rolls.Calls==3&&attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{5,12,12}),"attack power seven accumulates and tails preserve prior heads");
            Check(attacks.Select(x=>x.RemainingAttackCoins).SequenceEqual(new[]{2,1,0})&&attacks.Last().TotalRawDamage==29,"attack consumes one coin and sums cumulative hits");
            calls=rolls.Calls;Check(independent.NextAttack(rolls)==null&&independent.AttackCount==3&&rolls.Calls==calls,"spent attack coins cannot be reused");
            Check(independent.Skill.ClashCoinPower==2&&independent.Skill.AttackCoinPower==7&&independent.Skill.CoinCount==3,"definition remains unchanged throughout action");
            // Repeated ties are never replaced by the old random decider.
            var forever=new Constant();l=Act(5,0,1,2);r=Act(5,0,2,2);clash=new CoinClash(l,r,forever);
            for(int i=0;i<512;i++){a=clash.Step();Check(a.Winner==-1&&a.LeftRemaining==2&&a.RightRemaining==2&&!clash.Complete,"constant tie must remain a tie");}
            Check(forever.Calls==2048,"no secret random decider or loss during long ties");
            var responsive=new TailsPort();foreach(var e in responsive.State.EnemySlots)e.Active=false;responsive.State.EnemySlots[0].Active=true;responsive.State.EnemySlots[0].Key="steady";responsive.State.EnemySlots[0].Target=0;responsive.Assign("steady",0,0);
            var stream=responsive.ResolveStream().Take(25).ToArray();Check(stream.Count(x=>x.Type=="clash")==24&&stream.Where(x=>x.Type=="clash").All(x=>x.Coin.Winner==-1&&x.Coin.LeftRemaining==2&&x.Coin.RightRemaining==2),"battle exposes one incremental tie event at a time");
            // 11: effect commands contain only the four allowed stats; runtime counters are read-only.
            foreach(int invalid in new[]{-1,4,50}){bool rejected=false;try{new CoinEffect("illegal",CoinTrigger.SkillStart,(CoinStat)invalid,10);}catch(ArgumentException){rejected=true;}Check(rejected,"reject coin/count effect target");}
            Check(typeof(CoinAction).GetProperty("RemainingCoins").GetSetMethod()==null&&typeof(CoinAction).GetProperty("AttackCount").GetSetMethod()==null&&typeof(CoinSkill).GetProperty("CoinCount").GetSetMethod()==null,"public effect code cannot set coin counters");
            var effects=new List<CoinEffect>{new CoinEffect("cast",CoinTrigger.SkillStart,CoinStat.BasePower,2),new CoinEffect("clash",CoinTrigger.ClashStart,CoinStat.BasePower,4,CoinEffectScope.Clash),new CoinEffect("round",CoinTrigger.BeforeClashRound,CoinStat.ClashCoinPower,1,CoinEffectScope.ClashRound)};
            var definition=new CoinSkill("作用域",5,2,7,2,effects);effects.Clear();l=new CoinAction(definition,.5);r=Act(1,0,0,1);clash=new CoinClash(l,r,new Script(true,true,false));a=clash.Step();
            Check(a.LeftBase==11&&a.LeftClashPower==3&&a.LeftPower==17,"cast and clash/round scopes combine for clash");
            attacks=Strikes(l,new Script(false,true));Check(attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{7,14})&&l.Skill.CoinCount==2,"clash-only buffs cannot leak into attacks or alter count");
            Check(definition.Effects.Count==3&&((ICollection<CoinEffect>)definition.Effects).IsReadOnly,"skill owns an immutable copy of effect data");
            // Every supported timing is reachable without granting extra coins or attacks.
            var timingEffects=Enum.GetValues(typeof(CoinTrigger)).Cast<CoinTrigger>().Select(t=>new CoinEffect(t.ToString(),t,CoinStat.RawDamage,0)).ToArray();
            l=Act(5,2,3,2,timingEffects);r=Act(5,2,3,2);clash=new CoinClash(l,r,new Script(false,false,false,false, true,true,false,false, false,false,true, true,false));var traces=new List<string>();
            while(!clash.Complete)traces.AddRange(clash.Step().Effects);a=l.NextAttack(new Script(true));traces.AddRange(a.Effects);l.NotifyHit(a.Heads);traces.AddRange(l.DrainEffects());l.CompleteAttack();traces.AddRange(l.DrainEffects());
            var solo=Act(5,2,3,1,timingEffects);a=solo.NextAttack(new Script(false));traces.AddRange(a.Effects);solo.NotifyHit(a.Heads);solo.CompleteAttack();traces.AddRange(solo.DrainEffects());
            foreach(CoinTrigger trigger in Enum.GetValues(typeof(CoinTrigger)))Check(traces.Any(x=>x.StartsWith(trigger.ToString()+" /")),"timing "+trigger);
            Check(l.AttackCount==1&&l.RemainingCoins==0&&r.AttackCount==0,"all trigger effects preserve the clash/attack coin budget");
            // Timed states, conditional face effects, per-hit raw modifiers, and stacking.
            var statuses=new List<CoinStatus>();var opponentStatuses=new List<CoinStatus>();
            effects=new List<CoinEffect>{new CoinEffect("cast",CoinTrigger.SkillStart,CoinStat.RawDamage,1),new CoinEffect("before",CoinTrigger.BeforeAttack,CoinStat.RawDamage,2,CoinEffectScope.Attack),new CoinEffect("heads",CoinTrigger.AttackHeads,CoinStat.RawDamage,4,CoinEffectScope.Attack,condition:CoinCondition.Heads),new CoinEffect("tails",CoinTrigger.AttackTails,CoinStat.RawDamage,-1,CoinEffectScope.Attack,condition:CoinCondition.Tails),new CoinEffect("hit",CoinTrigger.Hit,CoinStat.BasePower,3,CoinEffectScope.Status,2),new CoinEffect("ended",CoinTrigger.SkillEnd,CoinStat.AttackCoinPower,2,CoinEffectScope.Status),new CoinEffect("debuff",CoinTrigger.Hit,CoinStat.ClashCoinPower,-1,CoinEffectScope.Status,2,recipient:CoinRecipient.Opponent)};
            l=new CoinAction(new CoinSkill("状态",5,2,3,2,effects),.5,statuses,opponentStatuses);a=l.NextAttack(new Script(true));l.NotifyHit(true);bool duplicate=false;try{l.NotifyHit(true);}catch(InvalidOperationException){duplicate=true;}
            b=l.NextAttack(new Script(false));l.NotifyHit(false);l.CompleteAttack();Check(a.RawDamage==15&&b.RawDamage==13&&l.TotalRawDamage==28,"coin carry persists; base status refreshes; raw effects remain per hit");
            Check(duplicate&&statuses.Single(x=>x.Id=="hit").Value==6&&opponentStatuses.Single().Value==-2,"one hit callback per coin; timed self/opponent states stack");
            Check(l.AttackCount==2&&l.RemainingCoins==0&&l.NextAttack(new Script())==null,"hit/end effects cannot create attacks");
            CoinStatus.NextRound(statuses);Check(statuses.Count==1&&statuses[0].RemainingTurns==1,"one-turn end state expires; two-turn hit state persists");CoinStatus.NextRound(statuses);Check(statuses.Count==0,"timed status expires at battle round transition");
            foreach(CoinStacking stacking in Enum.GetValues(typeof(CoinStacking)))
            {
                statuses=new List<CoinStatus>{new CoinStatus("s",CoinStat.BasePower,5,1)};var effect=new CoinEffect("s",CoinTrigger.Hit,CoinStat.BasePower,2,CoinEffectScope.Status,3,stacking);
                l=new CoinAction(new CoinSkill("叠加",5,1,1,1,new[]{effect}),.5,statuses);a=l.NextAttack(new Script(false));l.NotifyHit(false);int expected=stacking==CoinStacking.Add?7:stacking==CoinStacking.Replace?2:5;
                Check(statuses[0].Value==expected&&statuses[0].RemainingTurns==(stacking==CoinStacking.Ignore?1:3),"explicit stacking policy "+stacking);
            }
            // Snapshot modification is presentation-only and cannot restore spent coins.
            var snap=l.Snapshot();snap.RemainingCoins=999;Check(l.RemainingCoins==0,"runtime snapshot cannot restore coins");
            bool reuse=false;try{new CoinClash(l,Act(5,1,1,1),new Constant());}catch(ArgumentException){reuse=true;}Check(reuse,"cannot reuse an action for a second clash");
            statuses=new List<CoinStatus>();var guard=new CoinAction(new CoinSkill("无攻击防御",0,0,0,0,new[]{new CoinEffect("cast-status",CoinTrigger.SkillStart,CoinStat.BasePower,1,CoinEffectScope.Status),new CoinEffect("end-status",CoinTrigger.SkillEnd,CoinStat.AttackCoinPower,1,CoinEffectScope.Status)}),.5,statuses);
            Check(guard.NextAttack(new Script())==null&&guard.AttackCount==0&&statuses.Count==2,"zero-coin nonattack skills run start/end effects without inventing attacks");
            var winEffect=new[]{new CoinEffect("victor",CoinTrigger.ClashEnd,CoinStat.BasePower,3,condition:CoinCondition.ClashWon)};l=Act(1,0,1,1,winEffect);r=Act(10,0,2,2,winEffect);clash=new CoinClash(l,r,new Constant());a=clash.Step();
            Check(a.FinalWinner==1&&l.ClashWinner==1&&r.ClashWinner==1,"both action snapshots record the same final winning side");
            Check(Strikes(r,new Constant()).All(x=>x.RawDamage==13)&&l.NextAttack(new Script())==null,"conditional final-win effect works for the right-hand winner only");
            var statusBattle=new PortBattleRules();statusBattle.State.Heroes[0].Statuses.Add(new CoinStatus("buff",CoinStat.BasePower,2,2));var statusSnapshot=statusBattle.Snapshot();CoinStatus.NextRound(statusSnapshot.Heroes[0].Statuses);
            Check(statusBattle.State.Heroes[0].Statuses[0].RemainingTurns==2&&statusSnapshot.Heroes[0].Statuses[0].RemainingTurns==1,"UI status snapshots do not age authoritative buffs");
            var target=new PortBattleRules();foreach(var e in target.State.EnemySlots)e.Active=false;target.State.Enemies[0].Hp=1;target.State.Enemies[1].Hp=0;target.Assign("cleave",0,0);var overkill=target.Resolve().Where(x=>x.Type=="strike").ToArray();
            Check(overkill.Length==2&&overkill[1].Damage==0&&overkill.Last().Coin.RemainingAttackCoins==0,"all remaining coins retire once; dead target is never hit/retargeted again");
            // Fixed reference sequences prevent an implementation-mirroring formula from hiding a reset bug.
            foreach(var reference in new[]{
                new {Faces=new[]{true,false,true},Damage=new[]{7,7,9}},
                new {Faces=new[]{true,true,true},Damage=new[]{7,9,11}},
                new {Faces=new[]{false,false,false},Damage=new[]{5,5,5}},
                new {Faces=new[]{false,true,true},Damage=new[]{5,7,9}}})
            {
                l=Act(5,9,2,3);attacks=Strikes(l,new Script(reference.Faces));
                Check(attacks.Select(x=>x.RawDamage).SequenceEqual(reference.Damage),"fixed cumulative damage reference");
                Check(l.TotalRawDamage==reference.Damage.Sum(),"sum individual cumulative hits, not just final power");
            }
            l=Act(10,1,-2,3);attacks=Strikes(l,new Script(true,false,true));
            Check(attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{8,8,6}),"negative attack coins carry signed contributions");
            l=Act(5,1,2,3,new[]{new CoinEffect("per-hit",CoinTrigger.SkillStart,CoinStat.RawDamage,5)});
            attacks=Strikes(l,new Script(true,false,true));Check(attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{12,12,14}),"raw modifiers are not compounded into coin carry");
            l=Act(5,1,2,3,new[]{new CoinEffect("heads-power",CoinTrigger.AttackHeads,CoinStat.AttackCoinPower,1,CoinEffectScope.Attack)});
            attacks=Strikes(l,new Script(true,false,true));Check(attacks.Select(x=>x.RawDamage).SequenceEqual(new[]{8,8,11}),"use each coin's own effective power without revaluing prior heads");
            var fresh=Act(5,1,2,1);Check(fresh.NextAttack(new Script(false)).RawDamage==5,"new skill starts with zero attack carry");
            l=Act(10,4,2,3);r=Act(1,0,1,1);clash=new CoinClash(l,r,new Script(true,true,true,false));clash.Step();
            attacks=Strikes(l,new Script(false,false,false));Check(attacks.All(x=>x.RawDamage==10),"clash heads and clash power do not carry into damage phase");
            var enemy=new EnemyHeadsPort();foreach(var e in enemy.State.EnemySlots)e.Active=false;
            enemy.State.EnemySlots[0].Active=true;enemy.State.EnemySlots[0].Key="needle";enemy.State.EnemySlots[0].Target=1;
            var enemyHits=enemy.Resolve().Where(x=>x.Type=="strike").ToArray();
            Check(enemyHits.Select(x=>x.Coin.RawDamage).SequenceEqual(new[]{5,7})&&enemyHits.Select(x=>x.Damage).SequenceEqual(new[]{5,7}),"enemy adapter uses cumulative coins and actual damage consistently");
            var frozen=attacks[1].Copy();frozen.Left.AttackCoinTotal=999;
            Check(attacks[1].Left.AttackCoinTotal==0&&l.Snapshot().AttackCoinTotal==0,"attack carry snapshots remain isolated");
            // Seeded property checks: every round and every attack obey the same invariants.
            for(uint seed=1;seed<=64;seed++)
            {
                var random=new Recorded(seed);l=Act(3+(int)seed%4,1+(int)seed%3,5,1+(int)seed%4);r=Act(4,2,1,1+(int)seed%3);clash=new CoinClash(l,r,random);int rounds=0;
                while(!clash.Complete&&rounds++<1000)
                {
                    int oldL=l.RemainingCoins,oldR=r.RemainingCoins,oldCalls=random.Calls;a=clash.Step();
                    Check(random.Calls-oldCalls==oldL+oldR&&a.LeftFaces.Length==oldL&&a.RightFaces.Length==oldR,"seeded full reroll counts");
                    Check(a.LeftPower==a.LeftBase+a.LeftFaces.Count(x=>x)*a.LeftClashPower&&a.RightPower==a.RightBase+a.RightFaces.Count(x=>x)*a.RightClashPower,"seeded exact clash formulas");
                    Check(l.RemainingCoins==oldL-(a.Winner==1?1:0)&&r.RemainingCoins==oldR-(a.Winner==0?1:0),"seeded only loser loses one");
                }
                Check(clash.Complete,"seeded ordinary clash terminates naturally");var winner=clash.Winner==0?l:r;var loser=clash.Winner==0?r:l;int budget=winner.RemainingCoins,sum=0;
                int carry=0;while((a=winner.NextAttack(random))!=null){int previous=carry;if(a.Heads)carry+=a.AttackCoinPower;sum+=a.RawDamage;Check(a.AttackCarry==previous&&a.AttackAccumulated==carry&&a.RawDamage==a.AttackBase+carry+a.RawModifier&&a.TotalRawDamage==sum,"seeded cumulative attack formulas");}
                Check(winner.AttackCount==budget&&winner.RemainingCoins==0&&loser.AttackCount==0&&loser.NextAttack(random)==null,"seeded survivor attack budget and loser suppression");
            }
            return checks;
        }
    }
}
