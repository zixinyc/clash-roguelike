using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    public sealed class ForestSignal
    {
        public string Id,NodeId,Kind,Text;public int CreatedTurn,ExpiresTurn;
        public ForestSignal Copy(){return (ForestSignal)MemberwiseClone();}
    }
    public sealed class ForestJournalEntry {public int Turn;public string Message;}
    public sealed class ForestIntel
    {
        public HashSet<string> Known,Visible,Visited,KnownEdges,Travelled;
        public List<ForestSignal> Signals;public string PatrolNode;
    }
    public sealed class ForestRun
    {
        public readonly ForestMapDefinition Map;
        public readonly ExpeditionResources Party=new ExpeditionResources();
        public string Position {get;private set;} public string Selected {get;private set;}
        public int Turn=1,ActionsLeft=2,ActionBudget=2,Fatigue,Alert,HiddenTurns,Supply=1,Trackers=1,Smoke=1,IntelFragments,Version;
        public bool InBattle,Finished,EmberCore;public int Encounter;
        public string Pending="",Message="沿亮起的林间小径探索，夺取烬核后返回归途石门。";public int EventVariant;
        public readonly HashSet<string> Cleared=new HashSet<string>();
        public readonly List<ForestJournalEntry> Journal=new List<ForestJournalEntry>();
        readonly HashSet<string> known=new HashSet<string>(),visible=new HashSet<string>(),visited=new HashSet<string>(),knownEdges=new HashSet<string>(),travelled=new HashSet<string>(),reportedSignals=new HashSet<string>();
        readonly List<ForestSignal> signals=new List<ForestSignal>();
        readonly Random random;string patrol,noiseNode;int patrolWaypoint,noiseExpires,observationExpires,trackingExpires,signalCounter,patrolReturnTurn;bool patrolEncounter;
        public ForestRun(ForestMapDefinition definition)
        {Map=definition;Map.Validate();random=new Random(definition.Seed);Position=Map.StartId;Selected=Position;patrol=Map.PatrolRoute.Count>0?Map.PatrolRoute[0]:null;foreach(var e in Map.Edges.Where(x=>!x.Hidden))knownEdges.Add(e.Id);visited.Add(Position);Reveal();Log("小队进入焦黑森林。单机探索开始。");}
        public string Phase {get{return Finished?"探索结束":InBattle?"遭遇战斗":Pending!=""?"地点抉择":ActionsLeft==0?"等待结束回合":"探索行动";}}
        public int Exposure {get{return HiddenTurns>0?15:Math.Min(100,45+Alert*9+(Map.Node(Position).Kind==ForestNodeKind.Danger?10:0));}}
        public string MoveError(string id)
        {
            if(Finished||InBattle||Pending!="")return "请先处理当前地点或战斗。";
            if(Map.Node(id)==null||!known.Contains(id))return "尚未发现该地点。";
            if(id==Position)return "当前位置。";
            var e=Map.Edge(Position,id);if(e==null)return "没有直接连接的路线。";
            if(e.Hidden&&!knownEdges.Contains(e.Id))return "尚未发现这条通道。";
            if(ActionsLeft<e.ActionCost)return "本回合移动力不足，请结束回合。";
            if(IntelFragments<e.IntelCost)return "捷径需要 "+e.IntelCost+" 片情报。";
            return "";
        }
        public bool CanMove(string id){return MoveError(id)=="";}
        public bool ClickNode(string id)
        {
            if(Map.Node(id)==null||!known.Contains(id))return false;Selected=id;
            if(id==Position){Message="当前位置："+Map.Node(id).Name;Version++;return false;}
            string error=MoveError(id);if(error!=""){Message=error;Version++;return false;}return Move(id);
        }
        public bool Move(string id)
        {
            if(!CanMove(id))return false;var edge=Map.Edge(Position,id);string previous=Position;ActionsLeft-=edge.ActionCost;IntelFragments-=edge.IntelCost;travelled.Add(edge.Id);Position=id;Selected=id;visited.Add(id);Fatigue=Math.Min(8,Fatigue+edge.ActionCost);
            if(edge.Kind==ForestRouteKind.Shortcut)Log("通过特殊通道，消耗 "+edge.ActionCost+" 移动力与 "+edge.IntelCost+" 情报。");
            Log("从 "+Map.Node(previous).Name+" 移动至 "+Map.Node(id).Name+"。");Reveal();EnterNode();CheckPatrolContact();Version++;return true;
        }
        void EnterNode()
        {
            var n=Map.Node(Position);Message="抵达 "+n.Name+"。";
            if(Cleared.Contains(Position)){Message+=" 地点已处理，收益不可重复领取。";return;}
            switch(n.Kind)
            {
                case ForestNodeKind.Battle:BeginBattle(0);break;
                case ForestNodeKind.Elite:case ForestNodeKind.Center:BeginBattle(1);break;
                case ForestNodeKind.Supply:Party.Cost+=4;Supply++;Cleared.Add(Position);Log("拾取补给：+4 cost，补给 +1。");break;
                case ForestNodeKind.Lookout:IntelFragments++;Trackers++;Cleared.Add(Position);Observe(false);Log("首次使用观察点：情报 +1，追踪工具 +1。");break;
                case ForestNodeKind.Hideout:HiddenTurns=2;Alert=Math.Max(0,Alert-2);Message="隐入树影，两回合内降低暴露。";Log(Message);break;
                case ForestNodeKind.Danger:
                    int damage=Turn%3==0?3:2;for(int i=0;i<3;i++)if(Party.Hp[i]>0)Party.Hp[i]=Math.Max(1,Party.Hp[i]-damage);
                    Alert=Math.Min(5,Alert+2);noiseNode=Position;noiseExpires=Turn+2;Log("危险区侵蚀：存活成员 −"+damage+" 生命，警戒上升。");AddSignal(Position,"danger","咒灰翻涌，附近存在危险变化。",2);break;
                case ForestNodeKind.Event:Pending="event";EventVariant=random.Next(3);Log("发现随机事件，等待小队选择。");break;
                case ForestNodeKind.Camp:Pending="camp";Log("抵达营地，可以治疗或获取资源。");break;
                case ForestNodeKind.Shop:Pending="shop";Log("发现行商，可以使用现有 cost 购买治疗。");break;
                case ForestNodeKind.Passage:Message="发现特殊通道端点。观察附近可能找到隐藏连接。";Log(Message);break;
                case ForestNodeKind.Exit:
                    if(EmberCore){Finished=true;Message="携带烬核成功撤离废林。";Log(Message);}
                    else{Message="归途石门尚未开启：需要先取得中心祭坛的烬核。";Log(Message);}break;
            }
        }
        void BeginBattle(int encounter){InBattle=true;Encounter=encounter;patrolEncounter=false;Log("遭遇"+(encounter==1?"精英":"敌人")+"，进入原有战斗系统。");}
        public PortBattleRules CreateBattle(){if(!InBattle)throw new InvalidOperationException("No forest battle pending");return Party.CreateBattle(Encounter);}
        public bool FinishBattle(PortState result)
        {
            if(!InBattle||result.Outcome=="")return false;Party.ApplyBattleResult(result,Encounter);InBattle=false;
            if(result.Outcome=="victory")
            {
                if(!patrolEncounter)Cleared.Add(Position);AddSignal(Position,"battle","此地留有刚结束的战斗痕迹。",4);
                Log("战斗胜利，生命与 cost 返回地图；战斗奖励 +"+(Encounter==1?8:4)+" cost。");
                if(Map.Node(Position).Kind==ForestNodeKind.Center&&!EmberCore){EmberCore=true;IntelFragments+=2;Log("夺取烬核，情报 +2；前往归途石门完成探索。");}
                if(patrolEncounter){patrolReturnTurn=Turn+2;patrol=Map.PatrolRoute.FirstOrDefault(x=>x!=Position);Log("击退兽群，它暂时退入林深。");}
            }
            else{Finished=true;Log("小队战败，本次探索结束。");}Message=Journal.Last().Message;Reveal();Version++;return true;
        }
        bool CanAct {get{return !InBattle&&!Finished&&Pending==""&&ActionsLeft>0;}}
        public bool UseSupply()
        {if(!CanAct||Supply<=0||!Party.Hp.Where((h,i)=>h>0&&h<Party.MaxHp[i]).Any())return false;Supply--;ActionsLeft--;Party.Heal(6);Log("使用补给：存活成员恢复 6 生命，补给 −1。");Version++;return true;}
        public bool UseSmoke()
        {if(!CanAct||Smoke<=0)return false;Smoke--;ActionsLeft--;HiddenTurns=2;Alert=Math.Max(0,Alert-2);Log("使用烟雾弹：两回合内降低可见度，烟雾弹 −1。");Message="烟雾掩护了小队的行动。";Version++;return true;}
        public bool UseTracker()
        {if(!CanAct||Trackers<=0)return false;Trackers--;ActionsLeft--;trackingExpires=Turn+2;foreach(var n in Within(Position,2))known.Add(n);Log("使用追踪工具：辨认两条道路内的环境踪迹，持续两回合。");Message="追踪工具不会直接透视视野外的敌人。";RefreshSignals();Version++;return true;}
        public bool Hide()
        {if(!CanAct||Map.Node(Position).Kind!=ForestNodeKind.Hideout)return false;ActionsLeft--;HiddenTurns=2;Alert=Math.Max(0,Alert-2);Log("重新隐蔽，降低暴露与警戒。");Version++;return true;}
        public bool Observe(bool consume=true)
        {
            if(consume&&(!CanAct||Map.Node(Position).Kind!=ForestNodeKind.Lookout))return false;
            if(consume)ActionsLeft--;observationExpires=Turn+2;
            var reach=Within(Position,2);foreach(var e in Map.Edges.Where(x=>x.Hidden&&(reach.Contains(x.From)||reach.Contains(x.To))))
                if(knownEdges.Add(e.Id)){known.Add(e.From);known.Add(e.To);Log("发现隐藏通道："+Map.Node(e.From).Name+" ↔ "+Map.Node(e.To).Name+"。");}
            Reveal();Log("登高观察，当前视野扩展至两条普通道路，持续两回合。");Version++;return true;
        }
        public bool Choose(int choice)
        {
            if(Pending==""||choice<0||choice>1||Finished||InBattle)return false;
            if(Pending=="event"&&EventVariant==1&&choice==1)
            {
                if(random.NextDouble()<.55){Party.Cost+=8;Smoke++;Log("救下迷途猎人：+8 cost，烟雾弹 +1。");}
                else{for(int i=0;i<3;i++)if(Party.Hp[i]>0)Party.Hp[i]=Math.Max(1,Party.Hp[i]-2);Alert=Math.Min(5,Alert+1);Log("猎人是陷阱：存活成员 −2 生命，警戒上升。");}
            }
            else if(Pending=="event"&&EventVariant==2&&choice==0)
            {if(Party.Cost<3)return false;Party.Cost-=3;IntelFragments+=2;Log("解读残信：−3 cost，情报 +2。");}
            else
            {
                string kind=Pending;if(!Party.ApplyChoice(kind,choice))return false;
                Log(kind=="shop"?"购买治疗：−6 cost，存活成员恢复 8 生命。":kind=="camp"?choice==0?"营地休息：存活成员恢复 10 生命。":"营地搜集：+5 cost。":choice==0?"安全搜寻：+5 cost。":"冒险搜寻：存活成员 −4 生命，+12 cost。");
            }
            if(Pending=="camp")Fatigue=Math.Max(0,Fatigue-3);Cleared.Add(Position);Pending="";Message="地点已结算，继续探索。";Version++;return true;
        }
        public bool LeaveShop(){if(Pending!="shop")return false;Pending="";Message="离开行商，可以稍后再来。";Version++;return true;}
        public bool EndTurn()
        {
            if(InBattle||Finished||Pending!="")return false;bool rested=ActionsLeft==ActionBudget;Turn++;HiddenTurns=Math.Max(0,HiddenTurns-1);Fatigue=Math.Max(0,Fatigue-(rested?2:1));Alert=Math.Max(0,Alert-(HiddenTurns>0?2:rested?1:0));
            ActionBudget=Fatigue>=6?1:2;ActionsLeft=ActionBudget;signals.RemoveAll(x=>x.ExpiresTurn<Turn);MovePatrol();Reveal();CheckPatrolContact();
            if(!InBattle)Log("第 "+Turn+" 回合开始，移动力 "+ActionBudget+"。" + (HiddenTurns>0?" 隐蔽仍生效。":""));Version++;return true;
        }
        void MovePatrol()
        {
            if(patrol==null||Map.PatrolRoute.Count==0||Turn<patrolReturnTurn)return;
            bool heard=noiseNode!=null&&Turn<=noiseExpires;string target=heard?noiseNode:Map.PatrolRoute[(patrolWaypoint+1)%Map.PatrolRoute.Count];
            var next=Map.Links(patrol).Where(x=>x.Kind!=ForestRouteKind.Shortcut).Select(x=>x.Other(patrol)).OrderBy(x=>Map.Distance(x,target,false)).ThenBy(x=>x,StringComparer.Ordinal).FirstOrDefault();
            string old=patrol;if(next!=null)patrol=next;if(patrol==target&&!heard)patrolWaypoint++;
            AddSignal(old,"track","地上有近期兽群足迹。",3);AddSignal(patrol,"noise","林间传来沉重的枝木断裂声。",1);
        }
        void CheckPatrolContact()
        {
            if(InBattle||Pending!=""||Finished||patrol!=Position||Turn<patrolReturnTurn)return;
            if(HiddenTurns>0){Log("树影掩护了小队，巡游兽群没有发现你。");return;}Alert=5;BeginBattle(0);patrolEncounter=true;Message="巡游兽群截住了小队。";
        }
        HashSet<string> Within(string start,int radius)
        {
            var result=new HashSet<string>{start};var frontier=new List<string>{start};
            for(int step=0;step<radius;step++){var next=new List<string>();foreach(string n in frontier)foreach(var e in Map.Links(n).Where(x=>x.Kind!=ForestRouteKind.Shortcut&&(!x.Hidden||knownEdges.Contains(x.Id))))if(result.Add(e.Other(n)))next.Add(e.Other(n));frontier=next;}return result;
        }
        void Reveal()
        {
            visible.Clear();foreach(string id in Within(Position,Turn<=observationExpires?2:1)){visible.Add(id);known.Add(id);}known.Add(Position);
            foreach(var e in Map.Links(Position).Where(x=>x.Kind==ForestRouteKind.Shortcut&&(!x.Hidden||knownEdges.Contains(x.Id))))known.Add(e.Other(Position));RefreshSignals();
        }
        void AddSignal(string node,string kind,string text,int duration)
        {signals.Add(new ForestSignal{Id="signal-"+(++signalCounter),NodeId=node,Kind=kind,Text=text,CreatedTurn=Turn,ExpiresTurn=Turn+duration});}
        bool SignalVisible(ForestSignal s)
        {return s.ExpiresTurn>=Turn&&known.Contains(s.NodeId)&&(visible.Contains(s.NodeId)||(Turn<=trackingExpires&&Within(Position,2).Contains(s.NodeId)));}
        void RefreshSignals()
        {foreach(var s in signals.Where(SignalVisible))if(reportedSignals.Add(s.Id))Log("发现异动："+Map.Node(s.NodeId).Name+" · "+s.Text);}
        public ForestIntel Intel()
        {
            return new ForestIntel{Known=new HashSet<string>(known),Visible=new HashSet<string>(visible),Visited=new HashSet<string>(visited),KnownEdges=new HashSet<string>(knownEdges),Travelled=new HashSet<string>(travelled),Signals=signals.Where(SignalVisible).Select(x=>x.Copy()).ToList(),PatrolNode=patrol!=null&&visible.Contains(patrol)&&Turn>=patrolReturnTurn?patrol:null};
        }
        void Log(string text)
        {Journal.Add(new ForestJournalEntry{Turn=Turn,Message=text});if(Journal.Count>120)Journal.RemoveAt(0);}
    }
}
