using System;
using System.IO;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator CoinSmoke(string folder)
        {
            Directory.CreateDirectory(folder);int coinChecks=CoinChecks.Run();int otherChecks=BattleRuleChecks.Run()+InteractionChecks.Run()+PanelChecks.Run()+PortChecks.Run()+ForestChecks.Run()+TouhouChecks.Run();
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            OpenPortBattle(false);SelectPortHero(0);SelectPortCard("probe");CommitPortTarget(DefaultTarget(0));
            yield return Capture(folder,"coin-skill-data");PreparePortRound();yield return Capture(folder,"coin-prepared");
            speed=1;StartPortRound();var captures=new HashSet<string>();var observed=new List<CoinStep>();PortEvent previous=null;CoinStep previousHit=null;
            for(int battleRound=0;battleRound<20;)
            {
                if(portBusy)
                {
                    var ev=portEvent;
                    if(ev!=null&&ev.Coin!=null&&ev!=previous)
                    {
                        previous=ev;var step=ev.Coin;observed.Add(step.Copy());
                        if(ev.Type=="clash")SmokeCheck(step.LeftPower==step.LeftBase+step.LeftFaces.Count(x=>x)*step.LeftClashPower&&step.RightPower==step.RightBase+step.RightFaces.Count(x=>x)*step.RightClashPower,"runtime exact clash formulas");
                        if(ev.Type=="strike")SmokeCheck(step.AttackAccumulated==step.AttackCarry+(step.Heads?step.AttackCoinPower:0)&&step.RawDamage==step.AttackBase+step.AttackAccumulated+step.RawModifier&&step.AttackIndex<=step.AttackBudget&&step.RemainingAttackCoins==step.AttackBudget-step.AttackIndex,"runtime exact raw attack and conserved coin budget");
                        if(ev.Type=="strike")
                        {
                            SmokeCheck(step.AttackIndex==1?step.AttackCarry==0:previousHit!=null&&previousHit.AttackIndex+1==step.AttackIndex&&step.AttackCarry==previousHit.AttackAccumulated,"runtime carries prior coin power only within one skill");
                            previousHit=step.Copy();
                        }
                    }
                    if(ev!=null&&ev.Coin!=null&&portPhase>.55f)
                    {
                        string name=ev.Type=="clash"?(ev.Coin.Winner<0?"coin-tie":"coin-clash"):ev.Type=="strike"?(ev.Coin.Heads?"coin-attack-heads":"coin-attack-tails"):ev.Type=="clash_end"?"coin-final-winner":ev.Type=="attack_end"?"coin-attack-complete":null;
                        if(name!=null&&captures.Add(name))yield return Capture(folder,name);
                    }
                    yield return null;continue;
                }
                if(portRules.State.Outcome!="")break;
                battleRound++;if(captures.Contains("coin-tie")&&captures.Contains("coin-attack-heads")&&captures.Contains("coin-attack-tails"))speed=4;
                AutoPortPlan();yield return null;
            }
            SmokeCheck(portRules.State.Outcome!="","actual battle completes under new coin rules");
            SmokeCheck(captures.Contains("coin-clash")&&captures.Contains("coin-attack-heads")&&captures.Contains("coin-attack-tails")&&captures.Contains("coin-final-winner")&&captures.Contains("coin-attack-complete"),"actual player renders both faces, final winner and exhausted attack coins");
            string outcome=portRules.State.Outcome;yield return Capture(folder,"coin-battle-complete");
            OpenPortBattle(false);Screen.SetResolution(1000,650,false);yield return null;yield return null;SelectPortHero(1);yield return Capture(folder,"coin-small-skills");
            SelectPortCard("all_in");CommitPortTarget(DefaultTarget(0));PreparePortRound();speed=1;StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Coin==null||portEvent.Type!="clash"||portPhase<.55f))yield return null;
            SmokeCheck(portEvent!=null&&portEvent.Type=="clash","small window reaches clash");yield return Capture(folder,"coin-small-clash");SkipPort();while(portBusy)yield return null;
            string report="UNITY_COIN_SMOKE_PASSED\nCoin checks: "+coinChecks+"\nOther checks: "+otherChecks+"\nActual normal battle: "+outcome+"\nCaptured types: "+string.Join(",",captures.ToArray())+"\nObserved coin events: "+observed.Count+"\nReal player frames, original skill/role/economy data. No battle fixture HP edits. Fresh clash rounds and cumulative attack-coin formulas, exhausted coins, both faces, final winner and two window sizes verified.\n";
            File.WriteAllText(Path.Combine(folder,"coin-smoke.txt"),report);File.WriteAllLines(Path.Combine(folder,"coin-events.txt"),observed.Select(CoinLog.Fingerprint).ToArray());Debug.Log(report);Application.Quit(0);
        }
    }
}

