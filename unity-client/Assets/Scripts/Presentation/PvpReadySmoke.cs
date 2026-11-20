using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator PvpReadySmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            drivePvpOpponent=false;trialSkipSave=true;trialTimeIndex=0;
            OpenPortBattle(false);
            SmokeCheck(ConfirmSkillGroups()&&!BattleOverlayOpen,"ordinary battle starts without an open record or confirmation");
            yield return Capture(folder,"single-compact");
            OpenBattleJournal();
            yield return Capture(folder,"single-journal");
            CloseBattleOverlay();
            ExitPortBattle();
            SmokeCheck(portRules==null&&forest!=null,"single battle exit returns to the existing map");
            OpenTeamSetup(TeamMode.Pvp,false);
            teamDraft[0].Clear();AddTeamMember("reimu");AddTeamMember("marisa");
            teamSeat=1;teamDraft[1].Clear();AddTeamMember("sakuya");AddTeamMember("flandre");
            ConfirmTeamSetup();InitializeForest(48);
            yield return TrialWalk(forestCampaign.Players[1].Position);
            var duel=forestCampaign.Duel;
            SyncPvpBoard(duel);
            SmokeCheck(FindPortrait(duel.Sides[0].Units[0])!=null&&FindPortrait(duel.Sides[1].Units[0])!=null,
                "both sides load their real battle portraits");
            PickPvpActor(duel,0,0);PickPvpCard(duel,0,"yin_yang_orb");
            PickPvpActor(duel,1,0);PickPvpCard(duel,1,"murder_doll");
            SmokeCheck(duel.Sides[0].Equipped[0].Contains("yin_yang_orb")&&duel.Sides[1].Equipped[0].Contains("murder_doll"),
                "both sets can be edited in the same stage");
            yield return Capture(folder,"pvp-deck");
            ReadyPvpSide(duel,1);
            SmokeCheck(duel.Stage==TrialDuelStage.Deck&&duel.WaitingText(1)=="对方出招中","right deck can lock first");
            ReadyPvpSide(duel,0);
            SyncPvpBoard(duel);
            PickPvpActor(duel,0,0);PickPvpCard(duel,0,"needle");
            PickPvpActor(duel,1,0);PickPvpCard(duel,1,"needle");
            SmokeCheck(pvpSelection.All(selection=>selection.Skill=="needle"),"both sides keep independent skill selections");
            yield return Capture(folder,"pvp-choose");
            PickPvpTarget(duel,0,0);PickPvpTarget(duel,1,0);
            SmokeCheck(duel.Planned(0,0)!=null&&duel.Planned(1,0)!=null,"both actions use the live target controls");
            int[] hp=duel.Sides.Select(side=>side.Units[0].Hp).ToArray();
            int[] cost=duel.Sides.Select(side=>side.Cost).ToArray();
            ReadyPvpSide(duel,0);
            yield return Capture(folder,"pvp-wait");
            float hold=Time.realtimeSinceStartup+.3f;
            while(Time.realtimeSinceStartup<hold)yield return null;
            SmokeCheck(duel.Stage==TrialDuelStage.Plan&&duel.WaitingText(0)=="对方出招中"&&
                pvpPlayback==null&&duel.Beats.Count==0&&duel.Sides.Select(side=>side.Units[0].Hp).SequenceEqual(hp)&&
                duel.Sides.Select(side=>side.Cost).SequenceEqual(cost),"only one ready cannot start or cost HP and resources");
            ReadyPvpSide(duel,1);
            speed=1;
            float deadline=Time.realtimeSinceStartup+12;
            while((pvpBeat==null||pvpBeat.Kind!="clash"||pvpPhase<.45f)&&Time.realtimeSinceStartup<deadline)yield return null;
            SmokeCheck(pvpPlayback!=null&&pvpBeat!=null&&pvpBeat.Kind=="clash"&&
                PvpActorX(0,0)>PvpBaseX(0,0)&&PvpActorX(1,0)<PvpBaseX(1,0),"after both ready, actors actually approach each other");
            yield return Capture(folder,"pvp-clash");
            pvpSkip=true;
            while(duel.Round==1&&Time.realtimeSinceStartup<deadline)yield return null;
            SmokeCheck(duel.Round==2&&duel.Stage==TrialDuelStage.Plan&&!duel.IsReady(0)&&!duel.IsReady(1),"next round reopens both sides automatically");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            PickPvpActor(duel,0,0);PickPvpActor(duel,1,0);
            ReadyPvpSide(duel,1);
            SmokeCheck(duel.IsReady(1)&&duel.WaitingText(1)=="对方出招中"&&duel.CanPlan(0,0,"needle",0),
                "right can prepare first while left remains editable");
            yield return Capture(folder,"pvp-right-wait-small");
            int floor=forestCampaign.Players[1].FloorIndex;
            string winnerTile=forestCampaign.Players[0].Position;
            pvpViewSeat=1;
            SmokeCheck(PvpCostLabel(duel,0)==""&&PvpCostLabel(duel,1).Contains("cost")&&!battleJournalOpen,"only selected seat sees a balance; journal starts hidden");
            yield return Capture(folder,"pvp-private-balance");
            OpenBattleJournal();
            yield return Capture(folder,"pvp-journal-open");
            CloseBattleOverlay();
            RequestBattleExit(()=>ExitCampaignDuel(duel,1),PvpExitPrompt(duel,1));
            SmokeCheck(forestCampaign.Duel==duel&&duel.Winner==-1,"opening the confirmation does not surrender");
            yield return Capture(folder,"pvp-confirm-exit");
            CloseBattleOverlay();
            SmokeCheck(forestCampaign.Duel==duel,"cancel leaves the live duel in place");
            RequestBattleExit(()=>ExitCampaignDuel(duel,1),PvpExitPrompt(duel,1));
            ConfirmBattleExit();
            var loser=forestCampaign.Players[1];
            SmokeCheck(duel.Winner==0&&forestCampaign.Duel==null&&loser.FloorIndex==floor&&
                loser.Map.Node(loser.Position).Kind==ForestNodeKind.Eientei&&loser.RecoveryTurns==1&&
                forestCampaign.Players[0].Position==winnerTile,"confirming seats the loser at the same-floor Eientei and preserves the winner position");
            yield return Capture(folder,"pvp-exit-return");
            File.WriteAllText(Path.Combine(folder,"pvp-ready-smoke.txt"),
                "PVP_READY_SMOKE_PASSED\nReal same-tile encounter, two editable decks and hands, either side ready first, no early state change, real clash animation, automatic next round. 1440x900 and 1000x650.\n");
            Debug.Log("PVP_READY_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
