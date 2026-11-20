
using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        // The presentation drives only the local opponent. The campaign still accepts each seat's independent choices.
        bool drivePvpOpponent=true;
        CampaignDuel opponentDuel;
        TrialDuelStage opponentDuelStage;
        int opponentDuelRound;
        float opponentReadyAt,opponentStepAt;
        ForestCampaign opponentCampaign;
        readonly Dictionary<string,int> opponentVisits=new Dictionary<string,int>();

        bool LocalOpponentTurn {get{return drivePvpOpponent&&TrialActive&&forestCampaign.Pvp&&
            !forestCampaign.Finished&&forestCampaign.ActivePlayer==1;}}

        void UpdateLocalOpponentDuel(CampaignDuel duel)
        {
            if(!drivePvpOpponent)return;
            if(opponentDuel!=duel||opponentDuelStage!=duel.Stage||opponentDuelRound!=duel.Round)
            {
                opponentDuel=duel;opponentDuelStage=duel.Stage;opponentDuelRound=duel.Round;
                opponentReadyAt=Time.unscaledTime+(duel.Stage==TrialDuelStage.Deck?1.3f:1.6f);
            }
            if(Time.unscaledTime>=opponentReadyAt)duel.ReadyLocalOpponent();
        }

        void DrawLocalOpponentTurn()
        {
            CancelTargetLine();
            Label(30,20,840,48,GameTitle+" / 人机对抗",29,Gold);
            Label(38,72,800,35,TrialClockText(),15,Muted);
            Label(300,378,840,65,"对方行动中",31,Gold,TextAnchor.MiddleCenter);
        }

        void UpdateLocalOpponentMap()
        {
            if(opponentCampaign!=forestCampaign)
            {
                opponentCampaign=forestCampaign;opponentVisits.Clear();
                opponentStepAt=Time.unscaledTime+.55f;
            }
            if(Time.unscaledTime<opponentStepAt)return;
            opponentStepAt=Time.unscaledTime+.42f;
            if(portRules!=null)
            {
                if(portBusy){portSkip=true;return;}
                if(portRules.State.Outcome!=""){ReturnPortMap();return;}
                if(loadoutSelecting)ConfirmSkillGroups();
                FillPortPlans();
                portPrepared=true;
                StartPortRound();
                return;
            }
            if(forest.InBattle){ForestBattleHook();return;}
            bool hurt=forest.Party.Hp.Where((hp,i)=>hp>0&&hp*3<forest.Party.MaxHp[i]*2).Any();
            if(forest.Pending=="shop"){forest.LeaveShop();return;}
            if(forest.Pending!="")
            {
                int choice=0;
                if(forest.Pending=="camp")choice=hurt?0:1;
                if(forest.Pending=="event")choice=forest.EventChoice(0).StartsWith("恢复")==hurt?0:1;
                if(!forest.Choose(choice))forest.SkipTrialChoice();
                return;
            }
            if(forest.ActionsLeft<=0||forest.RecoveryTurns>0){ForestEndTurn(true);return;}
            if(hurt&&forest.UseSupply())return;

            var intel=forest.Intel();
            int targetFloor=forestCampaign.Floors.Length-1;
            string goal=null;
            if(forestCampaign.StoneHolder==1)
            {
                if(forest.KnownExitNode!=null)targetFloor=forest.KnownExitFloor;
                else if(forest.FloorIndex>=targetFloor-1)
                {
                    goal=OpponentSearchTarget(intel);
                    if(goal!=null)targetFloor=forest.FloorIndex;
                    else if(forest.FloorIndex==targetFloor)targetFloor--;
                }
            }
            if(forestCampaign.StoneHolder==0)targetFloor=forestCampaign.LockFloor;
            var current=forest.Map.Node(forest.Position);
            if((forest.FloorIndex<targetFloor&&current.Kind==ForestNodeKind.DownwardTransition||
                forest.FloorIndex>targetFloor&&current.Kind==ForestNodeKind.UpwardEntrance)&&forest.Transition())return;

            if(goal==null)goal=OpponentMapGoal(targetFloor,intel);
            var distances=OpponentDistances(goal,intel);
            var next=forest.Map.Links(forest.Position).Select(edge=>edge.Other(forest.Position))
                .Where(forest.CanMove).OrderBy(id=>OpponentMoveScore(id,intel,distances,hurt))
                .ThenBy(id=>id,StringComparer.Ordinal).FirstOrDefault();
            if(next==null){ForestEndTurn(true);return;}
            string key=forest.FloorIndex+":"+next;
            int walked;opponentVisits.TryGetValue(key,out walked);opponentVisits[key]=walked+1;
            ForestClick(next);
        }

        string OpponentMapGoal(int floor,ForestIntel intel)
        {
            if(floor==forest.FloorIndex)
            {
                if(forestCampaign.StoneHolder==1)return forest.KnownExitNode;
                if(forestCampaign.StoneHolder==0)return forestCampaign.LockNode;
            }
            var kind=forest.FloorIndex<floor?ForestNodeKind.DownwardTransition:
                forest.FloorIndex>floor?ForestNodeKind.UpwardEntrance:ForestNodeKind.MutationStone;
            return forest.Map.Nodes.Where(n=>intel.Known.Contains(n.Id)&&n.Kind==kind)
                .OrderBy(n=>Mathf.Abs(n.X-forest.Map.Node(forest.Position).X)+Mathf.Abs(n.Y-forest.Map.Node(forest.Position).Y))
                .Select(n=>n.Id).FirstOrDefault();
        }

        string OpponentSearchTarget(ForestIntel intel)
        {
            var reachable=OpponentDistances(forest.Position,intel);
            return reachable.Where(step=>!intel.Visited.Contains(step.Key))
                .OrderBy(step=>step.Value).ThenBy(step=>step.Key,StringComparer.Ordinal)
                .Select(step=>step.Key).FirstOrDefault();
        }

        Dictionary<string,int> OpponentDistances(string goal,ForestIntel intel)
        {
            var distances=new Dictionary<string,int>();
            if(goal==null)return distances;
            var pending=new Queue<string>();
            pending.Enqueue(goal);distances[goal]=0;
            while(pending.Count>0)
            {
                string from=pending.Dequeue();
                foreach(var edge in forest.Map.Links(from))
                {
                    string to=edge.Other(from);
                    if(distances.ContainsKey(to)||!intel.Known.Contains(to)||!intel.KnownEdges.Contains(edge.Id))continue;
                    distances[to]=distances[from]+1;pending.Enqueue(to);
                }
            }
            return distances;
        }

        int OpponentMoveScore(string id,ForestIntel intel,Dictionary<string,int> distances,bool hurt)
        {
            int distance,visits;
            bool routed=distances.TryGetValue(id,out distance);
            opponentVisits.TryGetValue(forest.FloorIndex+":"+id,out visits);
            var kind=forest.Map.Node(id).Kind;
            int risk=kind==ForestNodeKind.Elite||kind==ForestNodeKind.Anomaly?6:kind==ForestNodeKind.Danger?4:0;
            if(hurt&&kind==ForestNodeKind.Camp&&!forest.Cleared.Contains(id))risk-=5;
            return (routed?distance*40:4000)+(intel.Visited.Contains(id)?2:0)+Math.Min(8,visits)*3+risk;
        }
    }
}
