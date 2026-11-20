
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {

        IEnumerator SmokeInspectEnemyPortrait(CampaignDuel duel,int seat,int actor)
        {
            CloseEnemySkillDetails();
            var point=PvpPortraitRect(PvpBaseX(seat,actor)).center;
            bool movable=false;
            for(int attempt=0;attempt<3&&!movable;attempt++)
            {movable=UiPointTo(point.x,point.y);yield return null;yield return null;}
            if(movable)
            {
                yield return UiSyntheticClick();yield return null;yield return null;
                SmokeCheck(enemySkillDetails!=null,"clicking the actual opposing portrait opens skill details");
                Debug.Log("ENEMY_SKILL_PORTRAIT_CLICK_PASSED recruit="+duel.Recruitment);
            }
            else ShowCampaignEnemySkills(duel,seat,actor);
        }

        int ChangedDuelPixels(Texture2D first,Texture2D next,Rect designRegion)
        {
            Rect content=UiContentBounds();
            float scale=content.width/CanvasWidth;
            int x=Mathf.RoundToInt(content.x+designRegion.x*scale);
            int y=Mathf.RoundToInt(first.height-content.y-designRegion.yMax*scale);
            int width=Mathf.RoundToInt(designRegion.width*scale);
            int height=Mathf.RoundToInt(designRegion.height*scale);
            var a=first.GetPixels(x,y,width,height);
            var b=next.GetPixels(x,y,width,height);
            int changed=0;
            for(int i=0;i<a.Length;i++)if(!a[i].Equals(b[i]))changed++;
            return changed;
        }

        IEnumerator PvpOpponentSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            Screen.SetResolution(1440,900,false);
            UiMotionLevel=1;speed=1;
            trialSkipSave=true;trialTimeIndex=0;
            OpenTeamSetup(TeamMode.Pvp,false);
            teamDraft[0].Clear();AddTeamMember("reimu");AddTeamMember("zixi");
            teamSeat=1;teamDraft[1].Clear();AddTeamMember("sakuya");AddTeamMember("marisa");
            ConfirmTeamSetup();InitializeForest(48);

            SmokeCheck(forestCampaign.PvpOpeningProtected&&forest.Map.RoadColumns==13&&forest.Map.RoadRows==9&&
                forest.Map.Nodes.Count>=78,"live PVP room opens on the larger protected board");
            var shapes=RoadTop.Select(vertex=>Vector2.Scale(vertex,RoadScale)).ToArray();
            SmokeCheck(forest.Map.Nodes.All(tile=>shapes.All(vertex=>forestRect.Contains(LayerPoint(tile)+vertex)))&&
                forest.Map.Nodes.All(tile=>forest.Map.Nodes.All(other=>tile==other||!InsideFace(LayerPoint(other)-LayerPoint(tile),shapes))),
                "tile footprints fit in the viewport and click centers remain distinct");
            yield return Capture(folder,"pvp-map-large");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            yield return Capture(folder,"pvp-map-large-small");
            Screen.SetResolution(1440,900,false);yield return null;yield return null;

            var rival=forestCampaign.Players[1];
            string origin=rival.Position;
            ForestEndTurn(true);
            SmokeCheck(LocalOpponentTurn,"human ends turn and computer takes control without a second player");
            yield return Capture(folder,"pvp-ai-map-turn");
            float deadline=Time.realtimeSinceStartup+25;
            while(LocalOpponentTurn&&forestCampaign.Duel==null&&Time.realtimeSinceStartup<deadline)yield return null;
            SmokeCheck(rival.Position!=origin,"computer took a legal map movement");
            SmokeCheck(forestCampaign.ActivePlayer==0||forestCampaign.Duel!=null,"computer yielded the turn or initiated a real encounter");

            activeTeam=new[]{"zixi"};
            InitializeForest(48);
            yield return TrialWalk(forestCampaign.Players[1].Position);
            var duel=forestCampaign.Duel;
            SmokeCheck(!forestCampaign.PvpOpeningProtected&&duel!=null,"a real same-tile encounter opens once protection ends");
            SyncPvpBoard(duel);
            yield return SmokeInspectEnemyPortrait(duel,1,0);
            var catalog=duel.VisibleSkillCatalog(1,0).Select(PortContent.Card).Select(card=>card.Name);
            SmokeCheck(enemySkillDetails.Select(card=>card.Name).SequenceEqual(catalog)&&duel.PlannedCount(1)==0,
                "PvP portrait details show the character catalog and leave choices hidden");
            yield return Capture(folder,"pvp-enemy-skills");
            CloseEnemySkillDetails();
            PickPvpActor(duel,1,0);
            ReadyPvpSide(duel,1);
            SmokeCheck(pvpSelection[1].Actor<0&&!duel.IsReady(1)&&!EditPvpSide(duel,1),"human has no input route into the opponent's deck");
            PickPvpActor(duel,0,0);PickPvpCard(duel,0,"zixi_central_limit");
            SmokeCheck(duel.Sides[0].Equipped[0].Contains("zixi_central_limit"),
                "the real card controls equip the new ability");
            yield return Capture(folder,"pvp-my-deck");
            ReadyPvpSide(duel,0);
            deadline=Time.realtimeSinceStartup+8;
            while(duel.Stage==TrialDuelStage.Deck&&Time.realtimeSinceStartup<deadline)yield return null;
            SmokeCheck(duel.Stage==TrialDuelStage.Plan&&duel.Sides[1].Equipped[0].Count==4,"opponent equips and readies its own deck");
            SyncPvpBoard(duel);
            PickPvpActor(duel,1,0);
            PickPvpActor(duel,0,0);PickPvpCard(duel,0,"zixi_central_limit");PickPvpTarget(duel,0,0);
            SmokeCheck(duel.Planned(0,0)!=null&&pvpSelection[1].Actor<0,"human action is planned through the live private panel");
            yield return Capture(folder,"pvp-my-specials");
            ReadyPvpSide(duel,0);
            SmokeCheck(duel.Stage==TrialDuelStage.Plan&&duel.WaitingText(0)=="对方出招中"&&duel.Beats.Count==0,
                "first ready displays the waiting subtitle and no early combat");
            yield return Capture(folder,"pvp-ai-waiting");
            deadline=Time.realtimeSinceStartup+15;
            while((pvpBeat==null||pvpBeat.Kind!="clash"||pvpPhase<.45f)&&Time.realtimeSinceStartup<deadline)yield return null;
            SmokeCheck(duel.IsReady(1)&&pvpBeat!=null&&pvpBeat.Kind=="clash"&&pvpBeat.Coin!=null&&
                pvpBeat.Coin.Right.Name==PortContent.Card(duel.Planned(1,pvpBeat.Target).Key).Name,"opponent skill names are revealed in actual coin playback: "+string.Join(" | ",duel.Log.ToArray()));
            float clashPeak=0f,decisivePeak=0f,strikePeak=0f;
            int movedPixels=0,chromeChanges=-1;
            bool measured=false,captured=false;
            while(duel.Round==1&&Time.realtimeSinceStartup<deadline)
            {
                if(pvpBeat!=null&&pvpBeat.Coin!=null&&pvpPhase>=.45f)
                {
                    yield return new WaitForEndOfFrame();
                    float offset=shakeApplied.magnitude;
                    if(pvpBeat.Kind=="clash")
                    {
                        if(screenShake.Amplitude==ScreenShake.ClashEndAmplitude)decisivePeak=Mathf.Max(decisivePeak,offset);
                        else clashPeak=Mathf.Max(clashPeak,offset);
                        if(!measured&&offset>.5f)
                        {
                            var beat=pvpBeat;
                            float held=pvpPhase;
                            var frame=GrabFrameTexture();
                            yield return new WaitForEndOfFrame();
                            var next=GrabFrameTexture();
                            if(pvpBeat==beat&&pvpPhase==held)
                            {
                                movedPixels=ChangedDuelPixels(frame,next,new Rect(515,164,410,225));
                                if(movedPixels>0)
                                {
                                    chromeChanges=ChangedDuelPixels(frame,next,new Rect(30,106,675,42))
                                        +ChangedDuelPixels(frame,next,new Rect(48,406,150,52))
                                        +ChangedDuelPixels(frame,next,new Rect(30,585,440,246));
                                    measured=true;
                                }
                            }
                            Destroy(frame);Destroy(next);
                        }
                        if(measured&&!captured)
                        {
                            yield return Capture(folder,"pvp-ai-clash");
                            captured=true;
                        }
                    }
                    else if(pvpBeat.Kind=="strike"&&screenShake.Amplitude==ScreenShake.StrikeAmplitude)
                        strikePeak=Mathf.Max(strikePeak,offset);
                }
                yield return null;
            }
            SmokeCheck(clashPeak>.5f&&decisivePeak>.5f&&strikePeak>.1f&&strikePeak<clashPeak,
                "real PvP playback paints the clash, final clash and lighter strike: "+clashPeak+"/"+decisivePeak+"/"+strikePeak);
            SmokeCheck(measured&&chromeChanges==0,"held PvP frames move only the battlefield, with top bar, HP and hand fixed");
            SmokeCheck(ShakeOffset==Vector2.zero&&shakeApplied==Vector2.zero,"returning to planning clears the PvP impact");
            SmokeCheck(duel.Round==2&&duel.Stage==TrialDuelStage.Plan,"returns to the next private planning round");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            PickPvpActor(duel,0,0);pvpSelection[0].Shared=true;
            yield return Capture(folder,"pvp-my-shared-small");
            File.WriteAllText(Path.Combine(folder,"pvp-opponent-smoke.txt"),
                "PVP_OPPONENT_SMOKE_PASSED\nLarger 13×9 map, opening protection, AI map action, own deck and hand, UI input isolation, both-ready gate, coin replay, next turn, 1440x900 and 1000x650.\n"+
                "Rendered shake peaks (design px): clash "+clashPeak.ToString("0.00")+"; final "+decisivePeak.ToString("0.00")+"; strike "+strikePeak.ToString("0.00")+"\n"+
                "Held playback frames: changed battlefield pixels "+movedPixels+", HUD pixels "+chromeChanges+"\n");
            Debug.Log("PVP_OPPONENT_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
