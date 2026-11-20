using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    public sealed class ForestFloorLink
    {public int Upper,Lower;public string DownNode,UpNode;}
    public sealed partial class ForestCampaign
    {
        public readonly int Seed;public readonly bool Pvp;public readonly ForestMapDefinition[] Floors;public readonly List<ForestRun> Players=new List<ForestRun>();
        public readonly HashSet<string> Completed=new HashSet<string>();public int ActivePlayer,StoneHolder=-1,ExitTier=-1;public string ExitNode="";public bool Finished;public int Winner=-1;
        public readonly Dictionary<string,int[]> Market=new Dictionary<string,int[]>();
        public readonly List<ForestFloorLink> FloorLinks=new List<ForestFloorLink>();
        public int LockFloor {get{return StoneHolder<0?-1:Players[StoneHolder].FloorIndex;}}
        public string LockNode {get{return StoneHolder<0?null:Players[StoneHolder].Position;}}
        public ForestCampaign(int seed,bool pvp,int roster=1,ForestTrialOptions trial=null,string[] composition=null)
        {Seed=seed;Pvp=pvp;Floors=ForestRandomGenerator.GenerateFloors(seed,pvp);for(int tier=0;tier<Floors.Length-1;tier++)foreach(var down in Floors[tier].Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition))FloorLinks.Add(new ForestFloorLink{Upper=tier,Lower=tier+1,DownNode=down.Id,UpNode=Floors[tier+1].Nodes.Single(n=>n.Kind==ForestNodeKind.UpwardEntrance).Id});var spawn=Floors[0].Nodes.Where(n=>n.Kind==ForestNodeKind.Spawn).OrderBy(n=>n.Id,StringComparer.Ordinal).ToArray();var r=new Random(seed);int offset=r.Next(spawn.Length);for(int i=0;i<(pvp?2:1);i++)Players.Add(new ForestRun(this,i,spawn[(offset+i)%spawn.Length].Id,trial==null?(i==0?roster:2):pvp?(i==0?trial.TeamA:trial.TeamB):1));if(composition!=null)Players[0].Party.ConfigureTeam(composition);EnableTrial(trial);}
        public ForestRun Current {get{return Players[ActivePlayer];}}
        public static int ActionsForDie(int face)
        {
            if(face<1||face>6)throw new ArgumentOutOfRangeException("face");
            return (face+1)/2;
        }
        public const int PvpOpeningTurns=3;
        public bool PvpOpeningProtected {get{return Pvp&&Trial!=null&&StoneHolder<0&&
            Players.Any(player=>player.Turn<=PvpOpeningTurns);}}
        public string Phase {get{return Finished?"已结束":StoneHolder>=0?"追猎 / 逃亡":"探索阶段";}}
        public void AdvancePlayer()
        {
            if(!Pvp||Finished)return;
            ActivePlayer=(ActivePlayer+1)%Players.Count;
            ResetTurnClock();
            if(Trial!=null)TryTrialEncounter(Current);
        }
        void SetStoneHolder(ForestRun run)
        {
            if(StoneHolder>=0)Players[StoneHolder].EmberCore=false;
            StoneHolder=run.PlayerId;
            run.EmberCore=true;
        }

        bool IsExitTile(int floor,string node){return ExitTier==floor&&ExitNode==node;}
        internal bool AtExit(ForestRun run){return IsExitTile(run.FloorIndex,run.Position);}
        public bool TakeStone(ForestRun run)
        {
            if(Finished||StoneHolder>=0||run.FloorIndex!=Floors.Length-1||run.Map.Node(run.Position).Kind!=ForestNodeKind.MutationStone)return false;
            SetStoneHolder(run);
            if(!Pvp){Finished=true;Winner=run.PlayerId;run.Finished=true;run.Record("取得异动石：单机探索立即完成。");return true;}
            run.Party.RestoreTeam();
            var random=new Random(unchecked(Seed*17+run.PlayerId*7919+run.Turn*31));
            int final=Floors.Length-1;
            int targetFloor=final-random.Next(2);
            var returnLink=FloorLinks.FirstOrDefault(l=>l.Lower==final);
            var candidates=ExitCandidates(targetFloor,targetFloor==final?run.Position:returnLink==null?null:returnLink.DownNode);
            if(candidates.Length==0){targetFloor=final;candidates=ExitCandidates(final,run.Position);}
            var exit=candidates[random.Next(candidates.Length)];
            ExitTier=targetFloor;ExitNode=exit.Id;
            string recovery=run.Party.FlandreIndex>=0?"队伍恢复生命，芙兰朵露遵循恶魔的妹妹":"持有者全队满血";
            foreach(var player in Players)
            {
                player.Record("异动石由玩家"+(StoneHolder+1)+"持有：位置已锁定。逃亡出口现已生成，靠近后才可发现。"+recovery+"；战斗拼点+1 / 伤害+5。");
                player.RefreshExitIntel();
            }
            return true;
        }
        ForestNode[] ExitCandidates(int floor,string arrival)
        {
            if(arrival==null)return new ForestNode[0];
            var map=Floors[floor];
            return map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road &&
                ForestRandomGenerator.Path(map,arrival,n.Id,tile=>!ForestRandomGenerator.Risk(tile.Kind)).Count>0)
                .OrderBy(n=>n.Id,StringComparer.Ordinal).ToArray();
        }
        public void Escape(ForestRun run){if(Pvp&&!Finished&&StoneHolder==run.PlayerId&&AtExit(run)){Winner=run.PlayerId;Finished=true;foreach(var p in Players)p.Finished=true;run.Record("异动石持有者抵达出口，逃亡成功。");}}
        public string Serialize()
        {
            string header="CAMPAIGN|"+Seed+"|"+Pvp;
            if(Trial!=null)header+="|trial|"+string.Join(",",Themes)+"|"+Trial.TurnSeconds+"|"+Trial.PlanSeconds;
            return header+"\n"+string.Join("\n",Floors.Select(f=>f.Serialize()).ToArray())+
                string.Join("\n",FloorLinks.Select(l=>"T|"+l.Upper+"|"+l.DownNode+"|"+l.Lower+"|"+l.UpNode).ToArray());
        }
    }
    public sealed partial class ForestRun
    {
        public ForestCampaign Campaign {get;private set;}public int PlayerId {get;private set;}public int FloorIndex {get;private set;}public int RecoveryTurns {get;private set;}
        public bool Modern {get{return Map.FormatVersion>=2;}}public readonly BattleModifier NextBattle=new BattleModifier();public readonly List<string> Relics=new List<string>();
        public readonly Dictionary<string,int[]> ShopPurchases=new Dictionary<string,int[]>();
        readonly Dictionary<int,FloorMemory> memories=new Dictionary<int,FloorMemory>();readonly Dictionary<int,string> returnPoints=new Dictionary<int,string>();PortBattleRules activeMapBattle;
        readonly HashSet<string> usedHideoutCover=new HashSet<string>();
        sealed class FloorMemory
        {public HashSet<string> Known,Visible,Visited,Edges,Travelled,Reported;public List<ForestSignal> Signals;public string Patrol,Noise;public int Waypoint,NoiseExpires,Observation,Tracking,SignalCounter,PatrolReturn;}
        public ForestRun(ForestCampaign campaign,int player,string spawn,int roster):this(campaign.Floors[0],campaign.Seed,player)
        {Campaign=campaign;PlayerId=player;Cleared=campaign.Completed;ShopPurchases=campaign.Market;Position=spawn;Selected=spawn;known.Clear();visible.Clear();visited.Clear();visited.Add(spawn);Party.ConfigureRoster(roster);Message="进入迷途竹林：选择路线，寻找下层传送。";Journal.Clear();Log("玩家"+(player+1)+"进入第1层迷途竹林。"+(campaign.Pvp?"本地双队探索开始。":"单机探索开始。"));Reveal();RollMovementBudget();}
        public void Record(string text){Message=text;Log(text);Version++;}
        public int KnownExitFloor {get{return exitDiscovered?Campaign.ExitTier:-1;}}
        public string KnownExitNode {get{return exitDiscovered?Campaign.ExitNode:null;}}

        internal void RefreshExitIntel()
        {
            if(!PvpFog||exitDiscovered||FloorIndex!=Campaign.ExitTier||!visible.Contains(Campaign.ExitNode))return;
            exitDiscovered=true;
            Record("发现追猎出口。异动石持有者可由此撤离。");
        }

        public ForestNode PresentTile(ForestNode node)
        {
            if(KnownExitFloor!=FloorIndex||KnownExitNode!=node.Id)return node;
            return new ForestNode(node.Id,node.X,node.Y,ForestNodeKind.Exit,"追猎出口")
                {Tier=node.Tier,FloorIndex=node.FloorIndex};
        }

        public bool CanSeePlayer(ForestRun other)
        {
            if(other==this)return true;
            if(other.FloorIndex!=FloorIndex||Campaign!=null&&Campaign.PvpOpeningProtected)return false;
            return PvpFog&&Campaign.StoneHolder==other.PlayerId||
                other.HiddenTurns==0&&visible.Contains(other.Position);
        }
        void ApplyHideout()
        {
            HiddenTurns=2;
            if(!Map.RoadGrid||usedHideoutCover.Add(Position))Alert=Math.Max(0,Alert-2);
            if(Modern)NextBattle.EnemySlotsFirstTurn=-1;
        }
        public bool Transition()
        {
            if(!CanAct||Campaign==null)return false;var kind=Map.Node(Position).Kind;int next=kind==ForestNodeKind.DownwardTransition?FloorIndex+1:kind==ForestNodeKind.UpwardEntrance?FloorIndex-1:-1;if(next<0||next>=Campaign.Floors.Length)return false;
            ForestFloorLink link=kind==ForestNodeKind.DownwardTransition?Campaign.FloorLinks.FirstOrDefault(l=>l.Upper==FloorIndex&&l.DownNode==Position):Campaign.FloorLinks.Where(l=>l.Lower==FloorIndex&&l.UpNode==Position).OrderBy(l=>returnPoints.ContainsKey(FloorIndex)&&l.DownNode==returnPoints[FloorIndex]?0:1).FirstOrDefault();if(link==null)return false;
            string origin=Position;if(next>FloorIndex)returnPoints[next]=origin;SaveFloor();ActionsLeft--;FloorIndex=next;Map=Campaign.Floors[next];RestoreFloor();
            string arrival=kind==ForestNodeKind.DownwardTransition?link.UpNode:link.DownNode;
            Position=arrival;Selected=arrival;visited.Add(arrival);Reveal();Record("来到第"+(next+1)+"层 "+Campaign.ThemeNameAt(next)+"。");
            Campaign.TryTrialEncounter(this);return true;
        }
        void SaveFloor(){memories[FloorIndex]=new FloorMemory{Known=new HashSet<string>(known),Visible=new HashSet<string>(visible),Visited=new HashSet<string>(visited),Edges=new HashSet<string>(knownEdges),Travelled=new HashSet<string>(travelled),Reported=new HashSet<string>(reportedSignals),Signals=signals.Select(s=>s.Copy()).ToList(),Patrol=patrol,Noise=noiseNode,Waypoint=patrolWaypoint,NoiseExpires=noiseExpires,Observation=observationExpires,Tracking=trackingExpires,SignalCounter=signalCounter,PatrolReturn=patrolReturnTurn};}
        void RestoreFloor()
        {
            known.Clear();visible.Clear();visited.Clear();knownEdges.Clear();travelled.Clear();reportedSignals.Clear();signals.Clear();FloorMemory m;
            if(memories.TryGetValue(FloorIndex,out m)){known.UnionWith(m.Known);visible.UnionWith(m.Visible);visited.UnionWith(m.Visited);knownEdges.UnionWith(m.Edges);travelled.UnionWith(m.Travelled);reportedSignals.UnionWith(m.Reported);signals.AddRange(m.Signals);patrol=m.Patrol;noiseNode=m.Noise;patrolWaypoint=m.Waypoint;noiseExpires=m.NoiseExpires;observationExpires=m.Observation;trackingExpires=m.Tracking;signalCounter=m.SignalCounter;patrolReturnTurn=m.PatrolReturn;}
            else{foreach(var e in Map.Edges.Where(e=>!e.Hidden))knownEdges.Add(e.Id);patrol=Map.PatrolRoute.FirstOrDefault();patrolWaypoint=0;noiseNode=null;observationExpires=0;trackingExpires=0;patrolReturnTurn=0;}
        }
        public void Revive()
        {InBattle=false;Pending="";Position=Map.Nodes.First(n=>n.Kind==ForestNodeKind.Eientei).Id;Selected=Position;Party.RestoreTeam();RecoveryTurns=1;ActionsLeft=0;HiddenTurns=0;NextBattle.Clear();activeMapBattle=null;visited.Add(Position);Reveal();Record("在第"+(FloorIndex+1)+"层永远亭复活；本回合休整，结束回合后恢复行动。");}
        void EnterModernNode()
        {
            if(Campaign!=null&&Campaign.AtExit(this)){Campaign.Escape(this);return;}
            var n=Map.Node(Position);bool used=Cleared.Contains(Position);
            if(n.Kind==ForestNodeKind.Shop){Pending="shop";Record("林间行商：追踪工具4 cost、补给6 cost，同品每次涨2。");return;}
            if(n.Kind==ForestNodeKind.Lookout){if(!used){Trackers++;Cleared.Add(Position);}Observe(false);return;}
            if(n.Kind==ForestNodeKind.Hideout){ApplyHideout();Record("隐蔽2回合；下一场敌方首轮少1个行动格，不叠加。");return;}
            if(n.Kind==ForestNodeKind.Danger)
            {
                int damage=Turn%3==0?3:2;
                for(int i=0;i<Party.Hp.Length;i++)if(Party.Hp[i]>0)Party.Hp[i]=Math.Max(1,Party.Hp[i]-damage);
                Alert=Math.Min(5,Alert+2);
                noiseNode=Position;
                noiseExpires=Turn+2;
                bool revealedShortcut=false;
                if(!used)
                {
                    Cleared.Add(Position);
                    var hidden=Map.Edges.Where(e=>e.Hidden&&!knownEdges.Contains(e.Id))
                        .OrderBy(e=>Math.Min(Map.Distance(Position,e.From,false),Map.Distance(Position,e.To,false))).FirstOrDefault();
                    if(hidden!=null)
                    {
                        knownEdges.Add(hidden.Id);
                        known.Add(hidden.From);
                        known.Add(hidden.To);
                        revealedShortcut=true;
                    }
                }
                AddSignal(Position,"danger","瘴气竹径留下噪音与踪迹。",2);
                Record("瘴气：存活成员−"+damage+"HP，警戒+2。"+(revealedShortcut?"发现附近的隐藏捷径。":""));
                return;
            }
            if(n.Kind==ForestNodeKind.MutationStone){if(Campaign!=null&&!Campaign.TakeStone(this))Record("异动石已被取走；查看当前锁定目标。");return;}
            if(n.Kind==ForestNodeKind.Exit){if(Campaign!=null)Campaign.Escape(this);return;}
            if(n.Kind==ForestNodeKind.DownwardTransition||n.Kind==ForestNodeKind.UpwardEntrance){Record("已到达"+n.Name+"，可消耗1行动推进，也可继续探索本层。");return;}
            if(n.Kind==ForestNodeKind.Eientei){Record("永远亭：本层复活锚点，平时经过不会免费恢复生命。");return;}
            if(n.Kind==ForestNodeKind.Encounter)
            {
                if(used)return;
                bool heal=random.Next(2)==0;
                if(heal)Party.Heal(20);
                else{int reward=random.Next(5,11);Party.Cost+=reward;Record("奇遇：获得 "+reward+" cost。");}
                if(heal)Record("奇遇：存活队员恢复最多20HP。");
                Cleared.Add(Position);
                return;
            }
            if(used){Record("此处已结算，不能重复领取。");return;}
            switch(n.Kind){case ForestNodeKind.Battle:BeginBattle(0);break;case ForestNodeKind.Elite:BeginBattle(1);break;case ForestNodeKind.Anomaly:BeginBattle(2);break;case ForestNodeKind.Supply:Pending="supply";break;case ForestNodeKind.Camp:Pending="camp";break;case ForestNodeKind.Event:Pending="event";EventVariant=random.Next(3);break;case ForestNodeKind.Center:Pending=Map.RoadGrid?"event":"altar";break;}
        }
        public int ShopPrice(int item){int[] bought;int count=ShopPurchases.TryGetValue(Position,out bought)?bought[item]:0;return new[]{4,6}[item]+count*2;}
        public string EventChoice(int option)
        {
            if(Map.RoadGrid)return option==0?"恢复存活队员20HP":"获得5～10 cost";
            int kind=(EventVariant+option)%3;
            return kind==0?"恢复存活队员20HP":kind==1?"下场拼点+1 / 伤害+3":"获得5～10 cost";
        }
        bool ChooseModern(int choice)
        {
            if(Pending==""||Finished||InBattle||choice<0)return false;
            if(Pending=="shop")
            {if(choice>1)return false;int price=ShopPrice(choice);if(Party.Cost<price)return false;Party.Cost-=price;if(!ShopPurchases.ContainsKey(Position))ShopPurchases[Position]=new int[2];ShopPurchases[Position][choice]++;if(choice==0)Trackers++;else Supply++;Record("购买完成：−"+price+" cost，下次同品价格+2。");return true;}
            if(choice>1)return false;
            if(Pending=="supply"){if(choice==0)Party.Cost+=3;else Supply++;}
            else if(Pending=="camp"){if(choice==0)Party.Heal(10);else Party.Cost+=5;}
            else if(Pending=="event"){int variant=Map.RoadGrid?choice*2:(EventVariant+choice)%3;if(variant==0)Party.Heal(20);else if(variant==1){NextBattle.ClashBonus=Math.Max(1,NextBattle.ClashBonus);NextBattle.DamageBonus=Math.Max(3,NextBattle.DamageBonus);}else Party.Cost+=random.Next(5,11);}
            else if(Pending=="altar"){if(choice==0)NextBattle.DamageBonus=Math.Max(3,NextBattle.DamageBonus);else{Alert=Math.Min(5,Alert+1);Party.Cost+=3;}}
            else return false;
            Cleared.Add(Position);Pending="";Record("地点选择已结算，不能重复领取。");return true;
        }
        PortBattleRules CreateMapBattle()
        {
            if(activeMapBattle!=null)return activeMapBattle;var modifier=PreviewMapModifier();
            var b=Party.CreateBattle(Encounter==1?1:0);b.ApplyMapPreparation(modifier,Encounter==2?4+(Map.Seed+Turn+FloorIndex&1):0);activeMapBattle=b;return b;
        }
        public BattleModifier PreviewMapModifier()
        {var modifier=NextBattle.Copy();if(Campaign!=null&&Campaign.Pvp&&Campaign.StoneHolder==PlayerId){modifier.ClashBonus++;modifier.DamageBonus+=5;}if(!Map.RoadGrid)foreach(string relic in Relics){if(relic=="灵符·锐")modifier.DamageBonus++;else modifier.ClashBonus++;}return modifier;}
        bool FinishModernBattle(PortState result)
        {
            NextBattle.Clear();activeMapBattle=null;
            if(result.Outcome!="victory"){Revive();return true;}
            if(!patrolEncounter)Cleared.Add(Position);if(Encounter==1){if(Relics.Count<2)Relics.Add(Relics.Count==0?"灵符·锐":"灵符·衡");Record(Map.RoadGrid?"精英胜利：+8 cost；遗物最多携带2件，效果待确认。":"精英胜利：+8 cost；遗物最多携带2件（效果候选值）。");}else Record("战斗胜利：+4 cost。");
            if(patrolEncounter){patrolReturnTurn=Turn+2;patrol=Map.PatrolRoute.FirstOrDefault(x=>x!=Position);}AddSignal(Position,"battle","此地留有妖群战斗痕迹。",4);Reveal();Version++;return true;
        }
    }
}
