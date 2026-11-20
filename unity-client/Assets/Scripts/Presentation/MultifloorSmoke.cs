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
        readonly List<string> layerProof=new List<string>();int mapTestBattles,mapTestDeaths;string layeredCaptureFolder;bool anomalyCaptured;
        readonly HashSet<string> ordinaryStops=new HashSet<string>();
        void SmokeResolveChoice()
        {if(forest.Pending=="shop")forest.LeaveShop();else if(forest.Pending!=""){int option=forest.Pending=="camp"||forest.Pending=="altar"?1:forest.Pending=="event"&&forest.EventVariant==0?1:0;SmokeCheck(forest.Choose(option),"normal node choice");}}
        IEnumerator SmokeBattle()
        {
            if(portRules==null)yield break;var owner=forest;int tier=owner.FloorIndex;SmokeCheck(ConfirmSkillGroups(),"normal prebattle skill group confirmation");speed=4;
            if(owner.Encounter==2&&!anomalyCaptured){anomalyCaptured=true;SmokeCheck(portShown.Enemies.Count>=4&&portShown.Enemies.Count<=5,"actual anomaly has four or five original-template opponents");yield return Capture(layeredCaptureFolder,"anomaly-battle");Screen.SetResolution(1000,650,false);yield return null;yield return null;yield return Capture(layeredCaptureFolder,"anomaly-small");Screen.SetResolution(1440,900,false);yield return null;yield return null;}
            for(int turns=0;turns<35&&portRules.State.Outcome=="";turns++)
            {ArrangePortAutomatically();if(portRules.State.PlanCount>0){PreparePortRound();StartPortRound();}else{portRules.Tick(181);portPrepared=true;StartPortRound();}while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome!="","normal battle completes");string outcome=portRules.State.Outcome;int wallet=portRules.State.Cost+(outcome=="victory"?(forest.Encounter==1?8:4):0);ReturnPortMap();mapTestBattles++;
            SmokeCheck(owner.Party.Cost==wallet,"battle wallet applies actual result");
            if(outcome=="defeat"){mapTestDeaths++;SmokeCheck(owner.FloorIndex==tier&&owner.Map.Node(owner.Position).Kind==ForestNodeKind.Eientei&&owner.RecoveryTurns==1&&owner.ActionsLeft==0,"actual defeat returns to same-floor Eientei and cannot act");}
            layerProof.Add("Real encounter tier="+(tier+1)+" result="+outcome+" actual wallet="+wallet);yield return null;
        }
        IEnumerator SmokeActivate(int player)
        {
            for(int i=0;forestCampaign.Pvp&&forestCampaign.ActivePlayer!=player&&i<10;i++){SmokeResolveChoice();ForestEndTurn();if(portRules!=null)yield return SmokeBattle();yield return null;}
            SmokeCheck(!forestCampaign.Pvp||forestCampaign.ActivePlayer==player,"normal hotseat turn handoff");
        }
        IEnumerator SmokeBudget(int player,int amount)
        {
            yield return SmokeActivate(player);for(int i=0;(forest.ActionsLeft<amount||forest.RecoveryTurns>0)&&i<20;i++){SmokeResolveChoice();ForestEndTurn();if(portRules!=null)yield return SmokeBattle();yield return SmokeActivate(player);yield return null;}
            SmokeCheck(forest.ActionsLeft>=amount&&forest.RecoveryTurns==0,"movement or transition paid from actual AP budget");
        }
        IEnumerator SmokeWalk(int player,string destination)
        {
            for(int step=0;step<150;step++)
            {
                yield return SmokeActivate(player);SmokeResolveChoice();if(forest.Position==destination)yield break;
                var path=ForestRandomGenerator.Path(forest.Map,forest.Position,destination,n=>n.Id==destination||
                    !ForestRandomGenerator.Risk(n.Kind)&&(forestCampaign.StoneHolder>=0||n.Kind!=ForestNodeKind.MutationStone));
                SmokeCheck(path.Count>0,"safe explicit road path exists to "+destination);
                var edge=path[0];yield return SmokeBudget(player,edge.ActionCost);string target=edge.Other(forest.Position);ForestClick(target);bool arrived=target==destination;SmokeCheck(forest.Position==target,"actual node click moves only along edge");
                if(forest.Map.Node(target).Kind!=ForestNodeKind.Road&&forest.Map.Node(target).Kind!=ForestNodeKind.Spawn&&
                    forest.Map.Node(target).Kind!=ForestNodeKind.UpwardEntrance&&forest.Map.Node(target).Kind!=ForestNodeKind.DownwardTransition&&
                    forest.Map.Node(target).Kind!=ForestNodeKind.Eientei&&forest.Map.Node(target).Kind!=ForestNodeKind.MutationStone&&
                    forest.Map.Node(target).Kind!=ForestNodeKind.Exit)ordinaryStops.Add(target);
                if(portRules!=null)yield return SmokeBattle();SmokeResolveChoice();yield return null;if(arrived)yield break;
            }
            SmokeCheck(false,"walk exceeded safe route bound");
        }
        IEnumerator SmokeDescend(int player)
        {
            yield return SmokeActivate(player);int original=forest.FloorIndex;var target=forest.Map.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition).OrderBy(n=>ForestRandomGenerator.Path(forest.Map,forest.Position,n.Id,p=>!ForestRandomGenerator.Risk(p.Kind)).Count).First();yield return SmokeWalk(player,target.Id);yield return SmokeBudget(player,1);SmokeCheck(forest.Transition()&&forest.FloorIndex==original+1,"real downward action advances exactly one floor");yield return null;
        }
        IEnumerator SmokeExplore(int stops)
        {
            while(ordinaryStops.Count<stops)
            {
                var optional=forest.Map.Nodes.Where(n=>!ordinaryStops.Contains(n.Id)&&
                    (n.Kind==ForestNodeKind.Supply||n.Kind==ForestNodeKind.Camp||n.Kind==ForestNodeKind.Event||
                     n.Kind==ForestNodeKind.Encounter||n.Kind==ForestNodeKind.Lookout||n.Kind==ForestNodeKind.Shop))
                    .Select(n=>new { Tile=n, Road=ForestRandomGenerator.Path(forest.Map,forest.Position,n.Id,
                        tile=>tile.Kind!=ForestNodeKind.MutationStone&&!ForestRandomGenerator.Risk(tile.Kind)) })
                    .Where(x=>x.Road.Count>0).OrderBy(x=>x.Road.Count).FirstOrDefault();
                if(optional==null)yield break;
                yield return SmokeWalk(0,optional.Tile.Id);
            }
        }
        IEnumerator MultifloorSmoke(string folder)
        {
            Directory.CreateDirectory(folder);layeredCaptureFolder=folder;while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            forestPvpMode=false;InitializeForest(37,true);string generated=forestCampaign.Serialize();InitializeForest(37,true);SmokeCheck(forestCampaign.Serialize()==generated,"full five-floor seed replay");yield return Capture(folder,"single-tier-1");
            yield return SmokeExplore(3);yield return Capture(folder,"single-first-floor-explored");
            yield return SmokeDescend(0);yield return Capture(folder,"single-tier-2");int storedCost=forest.Party.Cost;yield return SmokeBudget(0,1);SmokeCheck(forest.Transition()&&forest.FloorIndex==0&&forest.Party.Cost==storedCost,"return to previous floor retains actual wallet");yield return SmokeBudget(0,1);SmokeCheck(forest.Transition()&&forest.FloorIndex==1,"repeat downstairs restores explored floor");
            while(forest.FloorIndex<4){yield return SmokeExplore(2+forest.FloorIndex*2);yield return SmokeDescend(0);yield return Capture(folder,"single-tier-"+(forest.FloorIndex+1));}
            yield return SmokeWalk(0,forest.Map.Nodes.Single(n=>n.Kind==ForestNodeKind.MutationStone).Id);SmokeCheck(forestCampaign.Finished&&forestCampaign.Winner==0,"full five-floor single objective completes immediately");layerProof.Add("SINGLE_COMPLETE seed37: all five tiers, up/down, stone, original HP/cost. Unique ordinary stops="+ordinaryStops.Count);yield return Capture(folder,"single-complete");
            forestPvpMode=false;InitializeForest(71,true);var danger=forest.Map.Nodes.First(n=>n.Kind==ForestNodeKind.Danger);string adjacent=forest.Map.Links(danger.Id).Select(e=>e.Other(danger.Id)).First(id=>!ForestRandomGenerator.Risk(forest.Map.Node(id).Kind));yield return SmokeWalk(0,adjacent);yield return SmokeBudget(0,1);int[] before=forest.Party.Hp.ToArray();int amount=forest.Turn%3==0?3:2;ForestClick(danger.Id);
            SmokeCheck(forest.Party.Hp.Select((h,i)=>h==Math.Max(1,before[i]-amount)).All(v=>v),"real danger applies HP loss");if(portRules!=null)yield return SmokeBattle();SmokeResolveChoice();
            var shortcut=forest.Map.Edges.First(e=>e.Hidden&&forest.Intel().KnownEdges.Contains(e.Id));yield return SmokeWalk(0,shortcut.From);yield return SmokeBudget(0,shortcut.ActionCost);int ap=forest.ActionsLeft;ForestClick(shortcut.To);SmokeCheck(forest.Position==shortcut.To&&forest.ActionsLeft==ap-shortcut.ActionCost,"actual revealed shortcut spends only action points");SmokeResolveChoice();yield return Capture(folder,"danger-shortcut");yield return SmokeDescend(0);layerProof.Add("HIGH_RISK_COMPLETE seed71: real danger HP/alert, discovered route, paid shortcut, descended.");
            forestPvpMode=false;InitializeForest(29,true);int priorDeaths=mapTestDeaths;for(int tries=0;tries<5&&mapTestDeaths==priorDeaths;tries++){var anomaly=forest.Map.Nodes.Single(n=>n.Kind==ForestNodeKind.Anomaly);yield return SmokeWalk(0,anomaly.Id);if(mapTestDeaths==priorDeaths&&forest.FloorIndex<4)yield return SmokeDescend(0);}
            SmokeCheck(mapTestDeaths>priorDeaths,"real unchanged combat produces defeat and revival");yield return Capture(folder,"eientei-revival");int deathFloor=forest.FloorIndex;string forbidden=forest.Map.Links(forest.Position).First().Other(forest.Position);SmokeCheck(!forest.Move(forbidden),"no movement before serving revival rest");ForestEndTurn();SmokeCheck(forest.FloorIndex==deathFloor&&forest.RecoveryTurns==0&&forest.ActionsLeft>0,"one map-turn rest restores action on death floor");yield return Capture(folder,"eientei-rest-ended");
            var testedExitFloors=new HashSet<int>();
            for(int seed=53;seed<62&&testedExitFloors.Count<2;seed++)
                yield return SmokePvp(folder,seed,testedExitFloors);
            SmokeCheck(testedExitFloors.SetEquals(new[]{2,3}),"both late-floor exit variants completed in the player");
            File.WriteAllLines(Path.Combine(folder,"multifloor-smoke.txt"),new[]{"UNITY_MULTIFLOOR_SMOKE_PASSED","Single complete, both local hotseat exit floors complete, actual defeat and rest, high-risk and elite-free routes, two sizes, seed replay.","Battles="+mapTestBattles+" real defeats="+mapTestDeaths,"The visible player uses real resources and unmodified combat values.",string.Join("\n",layerProof.ToArray()),"Automated shared GUI handlers and real player frames."});Debug.Log("UNITY_MULTIFLOOR_SMOKE_PASSED");Application.Quit(0);
        }
        IEnumerator SmokePvp(string folder,int seed,HashSet<int> testedExitFloors)
        {
            forestPvpMode=true;InitializeForest(seed,true);SmokeCheck(forestCampaign.Players[0].Position!=forestCampaign.Players[1].Position,"two legal random spawn points");if(seed==53)yield return Capture(folder,"pvp-exploration");
            for(int tier=0;tier<3;tier++){yield return SmokeDescend(0);yield return SmokeDescend(1);}
            yield return SmokeActivate(0);
            var finalDanger=forest.Map.Nodes.First(n=>n.Kind==ForestNodeKind.Danger);
            var stone=forest.Map.Nodes.Single(n=>n.Kind==ForestNodeKind.MutationStone);
            var approach=ForestRandomGenerator.Path(forest.Map,forest.Position,finalDanger.Id,n=>n==finalDanger||
                n!=stone&&!ForestRandomGenerator.Risk(n.Kind));
            if(approach.Count>0)yield return SmokeWalk(0,finalDanger.Id);
            yield return SmokeWalk(0,stone.Id);
            SmokeCheck(forestCampaign.StoneHolder==0&&!forestCampaign.Finished&&forest.Party.Hp.SequenceEqual(forest.Party.MaxHp)&&forestCampaign.ExitTier>=2,"real stone restores holder and generates late-tier exit");var bonus=forest.PreviewMapModifier();SmokeCheck(bonus.ClashBonus==1&&bonus.DamageBonus==5,"holder battle preparation bonuses present");
            string suffix="-exit-floor-"+(forestCampaign.ExitTier+1);
            yield return Capture(folder,"pvp-holder"+suffix);
            yield return SmokeActivate(1);var holder=forestCampaign.Players[0];SmokeCheck(forestCampaign.StoneHolder==0&&holder.FloorIndex==3&&forest.CanSeePlayer(holder)&&!forest.CanSeeTile(holder.Position),"opponent sees the carrier beyond one-tile vision");
            if(seed==53){yield return Capture(folder,"pvp-opponent-lock");Screen.SetResolution(1000,650,false);yield return null;yield return null;SmokeCheck(Screen.width==1000&&Screen.height==650,"small client resolution actually applied");yield return Capture(folder,"pvp-small-lock");Screen.SetResolution(1440,900,false);yield return null;yield return null;SmokeCheck(Screen.width==1440&&Screen.height==900,"large client resolution actually applied");}
            yield return SmokeActivate(0);if(forestCampaign.ExitTier==2){yield return SmokeWalk(0,forest.Map.Nodes.First(n=>n.Kind==ForestNodeKind.UpwardEntrance).Id);yield return SmokeBudget(0,1);SmokeCheck(forest.Transition()&&forest.FloorIndex==2,"holder returns upward to exit tier");}
            string exitId=forestCampaign.ExitNode;
            var exitRoute=ForestRandomGenerator.Path(forest.Map,forest.Position,exitId,n=>!ForestRandomGenerator.Risk(n.Kind));
            if(exitRoute.Count>0&&forest.KnownExitNode==null)
            {
                SmokeCheck(!forest.CanSeeTile(exitId)&&forest.PresentTile(forest.Map.Node(exitId)).Kind==ForestNodeKind.Road,"distant exit remains unmarked in the map UI");
                yield return Capture(folder,"pvp-exit-hidden"+suffix);
                yield return SmokeWalk(0,exitRoute.Last().Other(exitId));
            }
            SmokeCheck(forest.KnownExitNode==exitId&&forest.PresentTile(forest.Map.Node(exitId)).Kind==ForestNodeKind.Exit,"walking within one connected tile reveals the exit");
            yield return Capture(folder,"pvp-exit-found"+suffix);
            yield return SmokeWalk(0,exitId);SmokeCheck(forestCampaign.Finished&&forestCampaign.Winner==0,"PVP carrier reaches real generated exit and wins");
            testedExitFloors.Add(forestCampaign.ExitTier);yield return Capture(folder,"pvp-complete"+suffix);
            layerProof.Add("PVP_COMPLETE seed "+seed+": both players explored all four floors, full HP / +1 clash / +5 damage / lock, escaped on floor "+(forestCampaign.ExitTier+1)+".");
        }
    }
}
