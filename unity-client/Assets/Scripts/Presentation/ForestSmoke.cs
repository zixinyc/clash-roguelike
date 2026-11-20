using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator ForestSmoke(string folder)
        {
            Directory.CreateDirectory(folder);int checks=ForestChecks.Run(),old=BattleRuleChecks.Run()+InteractionChecks.Run()+PanelChecks.Run()+PortChecks.Run();
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;speed=4;selectedRoster=0;InitializeForest(73129,false);
            SmokeCheck(forest.Position=="n0"&&forest.Intel().PatrolNode==null,"initial fog conceals patrol");
            yield return Capture(folder,"forest-start");
            ForestClick("n1");SmokeCheck(forest.Position=="n1"&&forest.Supply==2&&forest.Party.Cost==34,"actual node click supplies");
            ForestClick("n2");SmokeCheck(portRules!=null&&forest.InBattle&&portRules.State.Cost==34,"forest enters original battle");
            SmokeCheck(ConfirmSkillGroups(),"default standalone party deck is ready");
            yield return Capture(folder,"forest-battle");
            for(int i=0;i<20&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome=="victory","actual forest battle victory");
            int expected=portRules.State.Cost+4;int[] hp=portRules.State.Heroes.Select(x=>x.Hp).ToArray();ReturnPortMap();
            SmokeCheck(forest.Party.Cost==expected&&forest.Party.Hp.SequenceEqual(hp)&&forest.Cleared.Contains("n2"),"original battle result carries to forest");
            yield return Capture(folder,"forest-after-battle");
            ForestEndTurn();ForestClick("n3");SmokeCheck(forest.Intel().KnownEdges.Contains("e40"),"observation reveals hidden shortcut");
            ForestClick("n4");SmokeCheck(forest.Pending=="event","interactive event entry");
            yield return Capture(folder,"forest-event");forest.Choose(0);ForestEndTurn();ForestClick("n5");ForestClick("n6");
            SmokeCheck(forest.HiddenTurns>0,"hideout changes status");ForestEndTurn();int beforeShortcut=forest.ActionsLeft;ForestClick("n21");
            SmokeCheck(forest.Position=="n21"&&forest.ActionsLeft==beforeShortcut-2,"shortcut only spends two action points");
            yield return Capture(folder,"forest-shortcut");ForestEndTurn();ForestClick("n19");SmokeCheck(!forest.Finished,"exit locked without core");ForestClick("n20");
            SmokeCheck(forest.Pending=="shop","shop at connected node");yield return Capture(folder,"forest-shop");forest.Choose(0);
            Screen.SetResolution(1000,650,false);yield return null;yield return null;yield return Capture(folder,"forest-small");
            Screen.SetResolution(1440,900,false);yield return null;yield return null;
            // A second normal run verifies the full objective with the real patrol enabled.
            // No starting position, rewards, enemy HP or combat rules are changed.
            InitializeForest(73129,false);ForestClick("n1");ForestClick("n7");SmokeCheck(forest.Pending=="camp","normal route camp entry");forest.Choose(1);ForestEndTurn();
            ForestClick("n10");ForestClick("n16");ForestEndTurn();ForestClick("n15");
            SmokeCheck(forest.Alert==2&&!forest.InBattle,"danger and hiding coexist with actual patrol");yield return Capture(folder,"forest-center-route");
            ForestClick("n11");SmokeCheck(portRules!=null&&forest.Encounter==1,"center enters original elite battle");
            SmokeCheck(ConfirmSkillGroups(),"default standalone party deck is ready for the elite encounter");
            for(int i=0;i<24&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            string elite=portRules.State.Outcome;SmokeCheck(elite=="victory","actual unmodified elite victory");ReturnPortMap();
            SmokeCheck(forest.EmberCore,"center elite grants objective once");ForestEndTurn();
            ForestClick("n15");SmokeCheck(forest.Alert>0,"danger applies HP and alert");yield return Capture(folder,"forest-danger");
            ForestClick("n20");forest.LeaveShop();ForestEndTurn();ForestClick("n19");SmokeCheck(forest.Finished,"full normal objective run reaches real exit");
            yield return Capture(folder,"forest-finish");
            InitializeForest(92,true);SmokeCheck(forest.Map.Seed==92,"seed variant initialization");yield return Capture(folder,"forest-seeded");
            string report="UNITY_FOREST_SMOKE_PASSED\nForest model checks: "+checks+"\nExisting checks: "+old+"\nNormal forest encounter: actual victory, wallet and HP carried back.\nExploration: supply, fog, observation, event, hideout, paid hidden shortcut, locked exit, shop, two resolutions.\nSecond complete normal run, patrol enabled, no fixture state: camp, lookout, hiding, danger, original elite "+elite+", core reward, shop, successful exit.\nSeed variant initialized. Captures are actual player frames. GUI callbacks were invoked by automation; real mouse/keyboard acceptance is separate.\n";
            File.WriteAllText(Path.Combine(folder,"forest-smoke.txt"),report);Debug.Log(report);Application.Quit(0);
        }
    }
}
