using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator PrototypeSmoke(string folder)
        {
            Directory.CreateDirectory(folder);int count=PrototypeChecks.Run();while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            selectedRoster=1;InitializeAdventure();int seed=forest.Map.Seed;string layout=forest.Map.Serialize();yield return Capture(folder,"prototype-random-map");
            InitializeForest(seed,true);SmokeCheck(forest.Map.Serialize()==layout,"seed replay is identical through main UI handler");
            string start=forest.Position;string supply=forest.Map.Links(start).Select(e=>forest.Map.Node(e.Other(start))).First(n=>n.Kind==ForestNodeKind.Supply).Id;string battle=forest.Map.Links(start).Select(e=>forest.Map.Node(e.Other(start))).First(n=>n.Kind==ForestNodeKind.Battle).Id;
            ForestClick(supply);ForestClick(start);ForestEndTurn();ForestClick(battle);SmokeCheck(loadoutSelecting&&forest.InBattle&&fromMap,"actual random map encounter opens prebattle group choice");int wallet=portShown.Cost;
            yield return Capture(folder,"prototype-deck-a");skillGroups.Select(CharacterKey(0),ActorSkills(0),1);var chosen=skillGroups.Cards(CharacterKey(0),ActorSkills(0));yield return Capture(folder,"prototype-deck-b");
            SmokeCheck(ConfirmSkillGroups()&&!loadoutSelecting&&portShown.Cost==wallet,"deck confirmation changes no resource");SelectPortHero(0);SmokeCheck(VisiblePortCards().Select(c=>c.Id).SequenceEqual(chosen),"equipped group controls actual visible hand");FillPortPlans();portShown=portRules.Snapshot();
            for(int i=0;i<3;i++)SmokeCheck(FindPortrait(portShown.Heroes[i])!=null,"inherited transparent portrait loaded for main battle");
            SmokeCheck(portShown.PlanCount>=2&&portShown.EnemySlots.Any(s=>s.Active&&s.Category!=2&&portRules.PairFor(s.Id)>=0),"real assignments form clash pairs");yield return Capture(folder,"prototype-planning-lines");PreparePortRound();speed=1;StartPortRound();bool captured=false;
            while(portBusy){if(!captured&&portEvent!=null&&portEvent.Type=="clash"&&portPhase>=.45f&&portPhase<.65f){SmokeCheck(DuelParticipant(true,portEvent.Hero)&&DuelAdvance(portPhase)>45&&PortActorX(true,portEvent.Hero)!=CombatX(true,portEvent.Hero)&&ShownCombatX(false,portEvent.Enemy)==PortActorX(false,portEvent.Enemy),"original actors move in the battlefield and coin anchors follow");yield return Capture(folder,"prototype-duel-contact");captured=true;speed=4;}yield return null;}
            SmokeCheck(captured,"actual clash contact captured");SmokeCheck(!portShown.Hand.Contains(TouhouRoles.MarisaCards[2]),"removed utility remains unavailable next round");
            for(int turn=0;turn<24&&portRules.State.Outcome=="";turn++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portShown.Outcome!="","real configured encounter completes");string outcome=portShown.Outcome;int expectedCost=portShown.Cost+(outcome=="victory"?4:0);int[] hp=portShown.Heroes.Select(u=>u.Hp).ToArray();ReturnPortMap();SmokeCheck(forest.Party.Cost==expectedCost&&forest.Party.Hp.SequenceEqual(hp),"real configured battle returns correct resources");yield return Capture(folder,"prototype-map-return");
            OpenPortBattle(false,0,false,true);skillGroups.Select(CharacterKey(1),ActorSkills(1),1);yield return Capture(folder,"prototype-zixi-deck");SmokeCheck(ConfirmSkillGroups(),"independent ZiXi loadout accepted");SelectPortHero(1);SmokeCheck(VisiblePortCards().Length==2,"ZiXi group controls its own hand");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;FillPortPlans();portShown=portRules.Snapshot();yield return Capture(folder,"prototype-small-lines");OpenPortBattle(false,0,true);yield return Capture(folder,"prototype-small-deck");
            File.WriteAllText(Path.Combine(folder,"prototype-smoke.txt"),"UNITY_BATTLE_UI_PROTOTYPE_PASSED\nPrototype checks: "+count+"\nRandom map seed="+seed+"; replay identical; actual supply/move/normal battle.\nPer-character A/B groups, locked selected hand across rounds; planning pairs and duel contact; actual battle result="+outcome+"; real HP/cost returned; ZiXi B group; 1440x900 and 1000x650.\nNo HP/damage fixtures; automated shared UI handlers, not full physical input acceptance.\n");Application.Quit(0);
        }
    }
}
