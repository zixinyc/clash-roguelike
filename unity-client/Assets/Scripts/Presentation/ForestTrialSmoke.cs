using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator TrialWalk(string tile,bool avoidOtherChallenges=false)
        {
            while(forestCampaign.PvpOpeningProtected)ForestEndTurn(true);
            int actor=forest.PlayerId;
            int steps=0;
            while(forest.Position!=tile&&steps++<120)
            {
                if(forest.Pending=="shop")forest.LeaveShop();
                else if(forest.Pending!="")forest.Choose(0);
                if(forest.ActionsLeft<=0)
                {
                    ForestEndTurn(true);
                    if(forestCampaign.Pvp&&forest.PlayerId!=actor)ForestEndTurn(true);
                }
                var edge=ForestRandomGenerator.Path(forest.Map,forest.Position,tile,n=>!ForestRandomGenerator.Risk(n.Kind)&&
                    (!avoidOtherChallenges||n.Id==tile||!forestCampaign.RecruitAvailable(n.Id,forest.FloorIndex))).First();
                SmokeCheck(forest.PlayerId==actor&&forest.CanMove(edge.Other(forest.Position)),"ordinary road offers legal action");
                ForestClick(edge.Other(forest.Position));
                SmokeCheck(portRules==null,"safe scripted route reaches preview without environmental combat");
                yield return null;
            }
            SmokeCheck(forest.Position==tile&&forestCampaign.Duel!=null,"entering the chosen tile starts encounter");
        }

        void OpenTrialPlanning(CampaignDuel duel)
        {
            duel.SetReady(0);
            if(!duel.Recruitment)duel.SetReady(1);
            SmokeCheck(duel.Stage==TrialDuelStage.Plan,"normal planning phase opens");
        }


        IEnumerator SmokeRecruitChallenge(string folder,string identity,string tile,bool demonstratePlayback)
        {
            yield return TrialWalk(tile,true);
            var duel=forestCampaign.Duel;
            SyncPvpBoard(duel);
            SmokeCheck(duel.Recruitment&&duel.Sides[1].Units[0].CharacterId==identity&&
                pvpSelection[0].Actor==0&&pvpSelection[1].Actor<0&&CampaignHandKeys(duel,0).Contains("marisa_stars"),
                "actual challenge opens the single-player battlefield with the exclusive hand visible");
            SmokeCheck(FindPortrait(duel.Sides[1].Units[0])!=null,"challenger's portrait loads");
            yield return SmokeInspectEnemyPortrait(duel,1,0);
            SmokeCheck(enemySkillDetails.Length==6&&duel.Slots(1,0)==2,"opponent inspection shows six cards for a two-character team");
            yield return Capture(folder,"recruit-"+identity+"-enemy-skills");
            CloseEnemySkillDetails();
            int reimu=Array.FindIndex(duel.Sides[0].Units,u=>u.CharacterId=="reimu");
            if(demonstratePlayback)
            {
                PickPvpCard(duel,0,"marisa_stars");
                PickPvpActor(duel,0,reimu);PickPvpCard(duel,0,"eight_way_bind");
                SmokeCheck(duel.Sides[0].Equipped[0].Contains("marisa_stars")&&duel.Sides[0].Equipped[reimu].Contains("eight_way_bind"),
                    "both newly available exclusive cards equip through the real controls");
            }
            yield return Capture(folder,"recruit-"+identity+"-deck");
            ReadyPvpSide(duel,0);
            SyncPvpBoard(duel);
            SmokeCheck(duel.Stage==TrialDuelStage.Plan&&CampaignHandKeys(duel,0).Contains(demonstratePlayback?"marisa_stars":"nova"),
                "plan opens on the selected character with a usable exclusive or common hand");
            for(int played=0;played<24&&duel.Winner<0;played++)
            {
                int current=duel.Round;
                foreach(int actor in new[]{0,reimu})
                {
                    if(duel.Sides[0].Units[actor].Hp<=0)continue;
                    PickPvpActor(duel,0,actor);
                    bool first=demonstratePlayback&&played==0;
                    if(first&&actor==reimu)
                    {
                        PickPvpCard(duel,0,"eight_way_bind");PickPvpTarget(duel,0,0);
                        SmokeCheck(duel.Planned(0,actor).Key=="eight_way_bind","new targeted exclusive can be arranged through its portrait");
                    }
                    string key=first&&actor==0?"marisa_stars":"nova";
                    if(!duel.CanPlan(0,actor,key,0))key="needle";
                    pvpSelection[0].Shared=PortContent.Card(key).Owner<0;
                    SmokeCheck(CampaignHandKeys(duel,0).Contains(key),"chosen action appears in the selected hand tab");
                    PickPvpCard(duel,0,key);
                    if(PvpTargetLegal(duel,0,0))PickPvpTarget(duel,0,0);
                }
                bool frozen=duel.Sides[1].Units[0].RoleState!=null&&duel.Sides[1].Units[0].RoleState.WorldRound==current;
                SmokeCheck(duel.PlannedCount(0)>0||frozen,"skill controls record real actions unless the foe stopped time");
                if(played==0)yield return Capture(folder,"recruit-"+identity+"-skills");
                ReadyPvpSide(duel,0);
                SmokeCheck(duel.RoundOpening!=null,"challenge goes through the duel playback");
                if(played==0)SmokeCheck(duel.PlannedCount(1)==2,"the live two-character challenge actually selected two opponent cards");
                if(demonstratePlayback&&played==0)
                    SmokeCheck(duel.Beats.Any(beat=>beat.Message.Contains("星辰幻想")),"newly equipped exclusive enters actual resolution");
                float deadline=Time.realtimeSinceStartup+17;
                bool captured=false;
                while(duel.Round==current&&Time.realtimeSinceStartup<deadline)
                {
                    if(playedPvpRound==current&&pvpPlayback==null&&duel.Stage==TrialDuelStage.Finished)break;
                    if(pvpPlayback!=null&&playedPvpRound==current)
                    {
                        if(!demonstratePlayback||played>0||captured)pvpSkip=true;
                        else if(pvpBeat!=null&&pvpBeat.Kind=="clash"&&pvpPhase>=.45f&&shakeApplied!=Vector2.zero)
                        {
                            SmokeCheck(pvpBeat.Coin!=null&&PvpActorX(1,0)<PvpBaseX(1,0),"challenge uses live portrait and coin animation");
                            UiMotionLevel=0;
                            yield return new WaitForEndOfFrame();
                            SmokeCheck(ShakeOffset==Vector2.zero&&shakeApplied==Vector2.zero,
                                "turning motion off during a real recruitment clash stops the impact immediately");
                            yield return Capture(folder,"recruit-"+identity+"-clash");
                            UiMotionLevel=1;
                            captured=true;
                        }
                    }
                    yield return null;
                }
                SmokeCheck(Time.realtimeSinceStartup<deadline&&(!demonstratePlayback||played>0||captured),
                    "challenge playback finishes and reopens the next round");
            }
            SmokeCheck(duel.Winner==0&&pvpPlayback==null,"ordinary starting party wins the actual "+identity+" challenge (winner "+duel.Winner+", round "+duel.Round+")");
            yield return Capture(folder,"recruit-"+identity+"-victory");
            FinishTrialBattle();
            var members=forest.Party.Members();
            SmokeCheck(forestCampaign.Duel==null&&members.Where((member,index)=>forest.Party.MaxHp[index]>0)
                .Any(member=>member.CharacterId==identity),"returning to the map recruits "+identity+" into an open slot");
        }

        IEnumerator ForestTrialSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            UiMotionLevel=1;
            drivePvpOpponent=false;trialSkipSave=true;forestSettings=true;forestTrialSetup=true;
            yield return Capture(folder,"trial-configuration");

            forestTrialMode=false;forestPvpMode=false;InitializeForest(48);
            int opening=forest.ActionBudget;
            SmokeCheck(forest.ActionsLeft==ForestCampaign.ActionsForDie(forest.LastDie),"classic forest starts with a dice budget");
            var road=forest.Map.Links(forest.Position).First(e=>!e.Hidden&&e.ActionCost==1);
            ForestClick(road.Other(forest.Position));
            SmokeCheck(forest.ActionsLeft==opening-1,"actual movement spends exactly one rolled point");
            yield return Capture(folder,"classic-dice-spent");
            if(forest.Pending=="shop")forest.LeaveShop();
            else if(forest.Pending!="")forest.Choose(0);
            ForestEndTurn(true);
            SmokeCheck(forest.Turn==2&&forest.ActionsLeft==ForestCampaign.ActionsForDie(forest.LastDie),"classic forest rolls a fresh budget on end turn");
            yield return Capture(folder,"classic-dice-new-turn");

            forestTrialMode=true;forestPvpMode=true;trialTimeIndex=1;trialSkillSeconds=30;
            InitializeForest(48);
            SmokeCheck(forestCampaign.Themes.Length==4&&forestCampaign.Themes.Distinct().Count()==4,"actual four distinct themes");
            SmokeCheck(forestCampaign.Players.All(p=>p.ActionsLeft==ForestCampaign.ActionsForDie(p.LastDie)),"both PVP players start with their own dice budget");
            yield return Capture(folder,"trial-pvp-map");
            yield return TrialWalk(forestCampaign.Players[1].Position);
            var duel=forestCampaign.Duel;
            SmokeCheck(!duel.Recruitment&&duel.Toggle(0,"marisa_meteor"),"actual shared tile and selectable exclusive");
            yield return Capture(folder,"trial-deck");
            duel.Tick(11);
            SmokeCheck(duel.Stage==TrialDuelStage.Plan&&duel.Sides[1].Equipped.All(cards=>cards.Count==0),
                "empty PVP deck remains empty after timeout");
            yield return Capture(folder,"trial-skill-choice");
            duel.Tick(31);
            SmokeCheck(duel.Stage==TrialDuelStage.Reveal&&duel.Log.Any(row=>row.Contains("自动安排")),"independent deadline resolves priority plans");
            yield return Capture(folder,"trial-priority-result");
            string meet=forest.Position;
            SmokeCheck(forestCampaign.TickTurnClock(65),"outer timer expires during duel");
            ExpireTrialTurn();
            SmokeCheck(forestCampaign.Duel==null&&forestCampaign.ActivePlayer==1&&
                forestCampaign.Players.All(player=>player.Position!=meet&&player.Map.Distance(meet,player.Position)<=2),"outer timeout retreats both and hands off turn");
            yield return Capture(folder,"trial-retreat");

            trialTimeIndex=0;
            InitializeForest(48);
            yield return TrialWalk(forestCampaign.Players[1].Position);
            duel=forestCampaign.Duel;
            OpenTrialPlanning(duel);
            string tile=forest.Position;
            for(int round=0;round<20&&duel.Winner<0;round++)
            {
                for(int actor=0;actor<duel.Sides[0].Units.Length;actor++)
                {
                    int target=duel.Sides[1].Units.Select((unit,index)=>new{unit,index}).Where(x=>x.unit.Hp>0)
                        .OrderBy(x=>x.unit.Hp).First().index;
                    if(!duel.Plan(actor,"nova",target))duel.Plan(actor,"needle",target);
                }
                int currentRound=duel.Round;
                duel.SetReady(0);duel.SetReady(1);
                while(duel.Winner<0&&duel.Round==currentRound){pvpSkip=true;yield return null;}
                yield return null;
            }
            SmokeCheck(duel.Winner==0,"real team wins normal rounds against an opponent passing");
            FinishTrialBattle();
            SmokeCheck(forest.Position==tile&&forestCampaign.Players[1].Map.Node(forestCampaign.Players[1].Position).Kind==ForestNodeKind.Eientei,
                "real win preserves location and loser goes to local Eientei");
            yield return Capture(folder,"trial-pvp-victory-return");

            forestPvpMode=false;InitializeForest(48);
            SmokeCheck(forest.Party.MaxHp[1]==0&&forestCampaign.Themes[0]==ForestTheme.ScarletMansion,"normal begins at Scarlet Mansion with two members");
            yield return Capture(folder,"trial-normal");
            yield return SmokeRecruitChallenge(folder,"sakuya",forestCampaign.RecruitNode,true);
            InitializeForest(43);
            yield return SmokeRecruitChallenge(folder,"flandre",forestCampaign.FlandreNode,false);
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            OpenTeamSetup(TeamMode.Normal,false);
            teamDraft[0].Clear();AddTeamMember("marisa");AddTeamMember("reimu");
            ConfirmTeamSetup();InitializeForest(110);
            yield return SmokeRecruitChallenge(folder,RemiliaSkills.Id,forestCampaign.RemiliaNode,false);
            InitializeForest(43);
            yield return SmokeRecruitChallenge(folder,PatchouliSkills.Id,forestCampaign.PatchouliNode,false);
            yield return Capture(folder,"trial-normal-recruited-small");
            File.WriteAllText(Path.Combine(folder,"forest-trial-smoke.txt"),
                "FOREST_TRIAL_UNITY_SMOKE_PASSED\nMap settings, seeded themes and die, timed deck and automatic selection, same-tile PvP, map timeout retreat and handoff, real duel win and same-floor defeat, interactive deck / skill / portrait targeting / playback and victory against all four recruitment challenges, live clash shake and immediate motion disable, and two sizes. Recruited progress is intentionally not written by this smoke run.\n");
            Debug.Log("FOREST_TRIAL_UNITY_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
