using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        ForestCampaign forestCampaign;bool forestPvpMode,forestPassAfterBattle;ForestMapDefinition shownFloor;ForestRun shownExplorer;
        void PassForestPlayer(){if(forestCampaign==null||!forestCampaign.Pvp||forestCampaign.Finished)return;forestCampaign.AdvancePlayer();forest=forestCampaign.Current;heroNames=CharacterRoster.Team(forest.Party.Roster).Select(x=>x.Name).ToArray();}
        Rect ForestTile(ForestNode n){var p=ForestPoint(n);return new Rect(p.x-48,p.y-24,96,48);}
        void DrawLayeredForest()
        {
            if(shownFloor!=forest.Map||shownExplorer!=forest){shownFloor=forest.Map;shownExplorer=forest;if(forestArt!=null)forestArt.Dispose();forestArt=new ForestMapArt(forest.Map.Seed^forest.FloorIndex*7919);forestLogCount=0;}
            var intel=forest.Intel();forestArt.UpdateFog(forest,intel,forest.Map.RoadGrid?(Func<ForestNode,Vector2>)RoadProjected:null);
            Label(28,18,550,43,"迷途竹林 / 森林追猎",29,Hex("E4D4AD"));
            Label(30,65,550,29,(forestCampaign!=null?forestCampaign.Phase:"地图")+" · 玩家"+(forest.PlayerId+1)+" · 种子 "+forest.Map.Seed,14,forestCampaign!=null&&forestCampaign.StoneHolder>=0?Red:Muted);
            int count=forestCampaign==null?1:forestCampaign.Floors.Length;
            for(int i=0;i<count;i++){Rect tab=new Rect(610+i*78,25,70,34);Panel(tab,i==forest.FloorIndex?Hex("314B43"):Hex("142327"),i==forest.FloorIndex?Gold:Hex("394B4A"));Label(tab.x,tab.y+4,70,25,"第"+(i+1)+"层",15,i==forest.FloorIndex?Gold:Muted,TextAnchor.MiddleCenter);}
            Label(610,72,480,24,"当前：第"+(forest.FloorIndex+1)+"层 · 地图回合 "+forest.Turn+" · "+(forest.RecoveryTurns>0?"永远亭休整":forest.Phase),13,Pale);
            GUI.enabled=forest.Pending==""&&!forest.Finished;
            if(Btn(new Rect(1280,27,134,35),"设定 / 地图")){forestSettings=true;forestRosterMenu=false;}
            if(Btn(new Rect(1100,68,314,30),"队伍："+MainRosterName(forest.Party.Roster)+" / 更换"))OpenMainRosterPicker();GUI.enabled=true;
            Panel(forestRect,Hex("0E2528"),Hex("526758"));DrawEasternBackdrop();GUI.DrawTexture(forestRect,forestArt.Fog);
            if(forest.Map.RoadGrid)DrawRoadTiles(intel);
            else
            {
            foreach(var e in forest.Map.Edges)DrawSquareRoute(e,intel);
            foreach(var node in forest.Map.Nodes.Where(n=>intel.Known.Contains(n.Id)))
            {
                var r=ForestTile(node);bool visible=intel.Visible.Contains(node.Id),here=node.Id==forest.Position,selected=node.Id==forest.Selected,can=forest.CanMove(node.Id);Color accent=LayerColor(node.Kind);
                Panel(r,visible?Hex("223A38"):Hex("182C2E"),selected?Gold:here?Cyan:can?Hex("A9B690"):Hex("4A625A"));
                Fill(new Rect(r.x+1,r.y+1,4,r.height-2),accent);Label(r.x+7,r.y+4,r.width-10,22,node.Name,13,visible?Pale:Muted,TextAnchor.MiddleCenter);
                string tag=LayerType(node.Kind)+(forest.Cleared.Contains(node.Id)?" · 已领":"");Label(r.x+5,r.y+27,r.width-10,17,tag,10,accent,TextAnchor.MiddleCenter);
                GUI.enabled=!forestSettings&&forest.Pending==""&&!forest.Finished&&forest.RecoveryTurns==0;
                if(GUI.Button(r,new GUIContent("",NodeSummary(node)),GUIStyle.none))ForestClick(node.Id);GUI.enabled=true;
            }
            }
            if(forestCampaign!=null)foreach(var player in forestCampaign.Players)
            {
                bool locked=forestCampaign.StoneHolder==player.PlayerId&&player!=forest;
                if(locked?forestCampaign.LockFloor!=forest.FloorIndex:!forest.CanSeePlayer(player))continue;
                var point=LayerPoint(forest.Map.Node(locked?forestCampaign.LockNode:player.Position));
                float shift=forestCampaign.Pvp?(player.PlayerId==0?-13:13):0;
                Color c=forestCampaign.StoneHolder==player.PlayerId?Red:player==forest?Gold:Cyan;Rect marker=new Rect(point.x-15+shift,point.y-43,30,17);Fill(marker,Hex("14262A"));Outline(marker,c,1);Label(marker.x,marker.y,30,17,(player.PlayerId==0?"A":"B")+(forestCampaign.StoneHolder==player.PlayerId?"石":""),11,c,TextAnchor.MiddleCenter);
            }
            if(intel.PatrolNode!=null){var p=LayerPoint(forest.Map.Node(intel.PatrolNode));Label(p.x+22,p.y-39,45,19,"妖兽",11,Red,TextAnchor.MiddleCenter);}
            DrawForestSidebar(intel);DrawLayeredFooter();
            if(forest.Pending!="")DrawLayeredChoice();if(forestSettings)DrawForestSettings();
            if(forestCampaign!=null&&forestCampaign.Finished)DrawLayeredFinish();
        }
        void DrawEasternBackdrop()
        {
            for(int i=0;i<26;i++){float x=forestRect.x+20+(i*83+forest.Map.Seed%41)%990,y=forestRect.y+30+(i*137)%570;Color c=new Color(.24f,.42f,.33f,.24f);Line(new Vector2(x,y+70),new Vector2(x+8,y-25),c,3);for(int j=0;j<3;j++){float yy=y-j*22;Line(new Vector2(x+2,yy),new Vector2(x+23,yy-13),c,2);Line(new Vector2(x+3,yy-8),new Vector2(x-14,yy-18),c,2);}}
            Color vermilion=new Color(.67f,.27f,.24f,.35f);float tx=forestRect.x+850,ty=forestRect.y+580;Line(new Vector2(tx-36,ty),new Vector2(tx-36,ty-70),vermilion,5);Line(new Vector2(tx+36,ty),new Vector2(tx+36,ty-70),vermilion,5);Line(new Vector2(tx-50,ty-70),new Vector2(tx+50,ty-70),vermilion,8);Line(new Vector2(tx-42,ty-49),new Vector2(tx+42,ty-49),vermilion,4);
            for(int i=0;i<3;i++){float x=forestRect.x+125+i*321,y=forestRect.y+135+(i%2)*292;Color stone=new Color(.48f,.56f,.48f,.28f);Line(new Vector2(x,y),new Vector2(x,y-33),stone,5);Outline(new Rect(x-11,y-50,22,17),stone,2);Line(new Vector2(x-18,y-52),new Vector2(x,y-62),stone,3);Line(new Vector2(x,y-62),new Vector2(x+18,y-52),stone,3);Fill(new Rect(x-3,y-46,6,8),new Color(.86f,.62f,.32f,.28f));Fill(new Rect(x+18,y-33,8,23),new Color(.77f,.69f,.52f,.24f));Line(new Vector2(x+20,y-27),new Vector2(x+24,y-15),vermilion,1);}
        }
        void DrawSquareRoute(ForestEdge e,ForestIntel intel)
        {
            if(e.Hidden&&!intel.KnownEdges.Contains(e.Id))return;bool a=intel.Known.Contains(e.From),b=intel.Known.Contains(e.To);if(!a&&!b)return;
            Vector2 p=ForestPoint(forest.Map.Node(e.From)),q=ForestPoint(forest.Map.Node(e.To));int hash=e.Id.Aggregate(0,(v,ch)=>(v*31+ch)&int.MaxValue);float x=(p.x+q.x)/2+(hash%11-5)*1.5f;
            Vector2[] points={p,new Vector2(x,p.y),new Vector2(x,q.y),q};Color c=e.Kind==ForestRouteKind.Shortcut?Hex("AC94C2"):intel.Travelled.Contains(e.Id)?Gold:e.Kind==ForestRouteKind.Main?Hex("A6AE86"):Hex("688780");c.a=a&&b?.8f:.23f;
            for(int part=0;part<3;part++)for(int step=0;step<18;step++){if(e.Hidden&&step%3==0)continue;var start=Vector2.Lerp(points[part],points[part+1],step/18f);var end=Vector2.Lerp(points[part],points[part+1],(step+1)/18f);if(forest.Map.Nodes.Any(n=>n.Id!=e.From&&n.Id!=e.To&&ForestTile(n).Contains((start+end)/2)))continue;Line(start,end,c,e.Kind==ForestRouteKind.Main?2.4f:1.5f);}
        }
        Color LayerColor(ForestNodeKind kind){if(kind==ForestNodeKind.Eientei)return Hex("B7D6B9");if(kind==ForestNodeKind.DownwardTransition||kind==ForestNodeKind.UpwardEntrance)return Hex("92C9CF");if(kind==ForestNodeKind.MutationStone)return Hex("F0B1CD");if(kind==ForestNodeKind.Anomaly)return Hex("C58BC4");return ForestColor(kind);}
        string LayerType(ForestNodeKind kind){if(kind==ForestNodeKind.Road)return "道路格";if(kind==ForestNodeKind.Encounter)return "奇遇";if(kind==ForestNodeKind.Spawn)return "出生入口";if(kind==ForestNodeKind.Eientei)return "复活锚点";if(kind==ForestNodeKind.DownwardTransition)return "向下一层";if(kind==ForestNodeKind.UpwardEntrance)return "返回上层";if(kind==ForestNodeKind.MutationStone)return "最终目标";if(kind==ForestNodeKind.Anomaly)return "4～5妖群";return ForestType(kind);}
        string NodeSummary(ForestNode n)
        {
            var e=forest.Map.Edge(forest.Position,n.Id);string cost=n.Id==forest.Position?"已在此格":e==null?"须沿相连路线抵达":"行动"+e.ActionCost+" / 情报"+e.IntelCost+" / HP"+e.HpCost;
            string reward=n.Kind==ForestNodeKind.Supply?"3cost或补给1（二选一）":n.Kind==ForestNodeKind.Camp?"10HP或5cost；两者均清疲劳":n.Kind==ForestNodeKind.Shop?"候选价4/5/6；同品每次+2；无治疗":n.Kind==ForestNodeKind.Lookout?"首次情报/追踪各1；2回合视野、下战揭牌":n.Kind==ForestNodeKind.Hideout?"隐蔽2回合、警戒−2；下战首轮少1敌行动":n.Kind==ForestNodeKind.Danger?"−2/3HP、警戒+2；首次+2情报并揭捷径":n.Kind==ForestNodeKind.Battle?"胜利+4cost、+1情报":n.Kind==ForestNodeKind.Elite?"胜利+8cost、遗物1（最多2；可绕开）":n.Kind==ForestNodeKind.Anomaly?"4～5个原模板敌人；胜利按普通奖励":n.Kind==ForestNodeKind.Eientei?"死亡回到本层，休整一地图回合":n.Kind==ForestNodeKind.MutationStone?(forestCampaign!=null&&forestCampaign.Pvp?"满血、拼点+1伤害+5，锁定并生成出口":"取得即完成单机"):n.Kind==ForestNodeKind.DownwardTransition||n.Kind==ForestNodeKind.UpwardEntrance?"1行动切层，可继续本层探索":n.Kind==ForestNodeKind.Exit?"仅异动石持有者到达后逃亡成功":n.Kind==ForestNodeKind.Center?"情报换战斗准备，或警戒换少量cost":"恢复、战斗准备或5～10cost，二选一";
            if(n.Kind==ForestNodeKind.Spawn)reward="随机出生位置，没有自动资源奖励";
            if(n.Kind==ForestNodeKind.Road)reward="沿已连接的道路前进";
            if(n.Kind==ForestNodeKind.Encounter)reward="随机恢复20HP或获5～10 cost";
            if(forest.Map.RoadGrid&&(n.Kind==ForestNodeKind.Event||n.Kind==ForestNodeKind.Center))reward="恢复20HP或获得5～10 cost（二选一）";
            if(forest.Map.RoadGrid&&n.Kind==ForestNodeKind.Hideout)reward="首次警戒−2；可刷新2回合隐蔽；下战首轮少1敌行动";
            if(e!=null&&e.Hidden&&!forest.Intel().KnownEdges.Contains(e.Id))cost="须沿已发现路线抵达";
            return n.Name+" / "+LayerType(n.Kind)+" · "+cost+"\n收益/风险："+reward+(forest.Cleared.Contains(n.Id)?"（一次性收益已领取）":"");
        }
        void DrawLayeredFooter()
        {
            Label(29,793,1000,22,forest.Map.RoadGrid?"逐格行动 · 金色描边可移动 · 紫色接缝为已发现的捷径":"永远亭＝本层复活 · 下层传送≠上层入口 · 仅路线端点相连，交叉不通",12,Muted);
            var node=forest.Map.Node(forest.Selected);
            string state=node.Id==forest.Position?forest.Message:forest.CanMove(node.Id)?"可移动 · "+(forest.Intel().Visited.Contains(node.Id)?"已走过":"未到访"):forest.MoveError(node.Id);
            Label(29,823,1000,68,NodeSummary(node)+"\n"+state,12,Gold);
            GUI.enabled=!forestSettings&&forest.Pending==""&&!forest.Finished;
            if(Btn(new Rect(1068,796,350,39),forestCampaign!=null&&forestCampaign.Pvp?"结束回合 · 交给另一玩家":"结束地图回合",true))ForestEndTurn();
            var here=forest.Map.Node(forest.Position);bool can=!forestSettings&&forest.Pending==""&&!forest.Finished&&forest.ActionsLeft>0&&forest.RecoveryTurns==0;GUI.enabled=can;
            if(here.Kind==ForestNodeKind.DownwardTransition||here.Kind==ForestNodeKind.UpwardEntrance){if(Btn(new Rect(1068,845,350,37),here.Kind==ForestNodeKind.DownwardTransition?"下到下一层 · 1行动":"返回上一层 · 1行动"))forest.Transition();}
            else if(here.Kind==ForestNodeKind.Lookout){if(Btn(new Rect(1068,845,350,37),"再次观察 · 1行动 / 不重复领资源"))forest.Observe();}
            else if(here.Kind==ForestNodeKind.Hideout){if(Btn(new Rect(1068,845,350,37),"刷新隐蔽 · 1行动"))forest.Hide();}
            else GUI.enabled=false;GUI.enabled=true;
            if(forestCampaign!=null&&forestCampaign.Pvp&&forestCampaign.StoneHolder>=0)
            {
                int floor=forestCampaign.LockFloor;
                var locked=forestCampaign.Floors[floor].Node(forestCampaign.LockNode);
                string text=forestCampaign.StoneHolder==forest.PlayerId?"本队持有异动石":"锁定玩家"+(forestCampaign.StoneHolder+1)+" · 第"+(floor+1)+"层 · "+RoadCoordinate(locked);
                var exit=forestCampaign.Floors[forestCampaign.ExitTier].Node(forestCampaign.ExitNode);
                Label(1082,685,315,72,text+"\n出口：第"+(exit.FloorIndex+1)+"层 · "+RoadCoordinate(exit),12,Red);
            }
        }
        void DrawLayeredChoice()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.8f));Panel(new Rect(410,240,620,420),Hex("173036"),Gold);Label(440,263,560,40,forest.Map.Node(forest.Position).Name,28,Gold);
            if(forest.Pending=="shop")
            {Label(440,315,560,50,"候选价：追踪4、情报×2为5、补给6；同品每次+2。可反复来访，不出售治疗。",15,Pale);string[] products={"追踪工具 +1","情报 +2","补给道具 +1"};for(int i=0;i<3;i++){int price=forest.ShopPrice(i);GUI.enabled=forest.Party.Cost>=price;if(Btn(new Rect(440,381+i*53,560,43),products[i]+" · "+price+" cost"))forest.Choose(i);}GUI.enabled=true;if(Btn(new Rect(440,562,560,43),"离开行商"))forest.LeaveShop();return;}
            string first=forest.Pending=="supply"?"获得3 cost":forest.Pending=="camp"?"全队恢复10HP，清除疲劳":forest.Pending=="altar"?"消耗1情报，下战伤害+3（候选）":forest.EventChoice(0);
            string second=forest.Pending=="supply"?"获得1个补给道具":forest.Pending=="camp"?"获得5 cost，清除疲劳":forest.Pending=="altar"?"警戒+1，获得3 cost（候选）":forest.EventChoice(1);
            Label(440,322,560,45,"一次性地点；两条选择均消耗本次机会。路线代价已在移动时支付。",15,Pale);
            GUI.enabled=forest.Pending!="altar"||forest.IntelFragments>0;if(Btn(new Rect(440,404,560,50),first))forest.Choose(0);GUI.enabled=true;if(Btn(new Rect(440,480,560,50),second))forest.Choose(1);
        }
        void DrawLayeredSettings()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.82f));Panel(new Rect(435,155,570,610),Hex("173036"),Gold);Label(465,178,510,40,"迷途竹林 · 地图设定",27,Gold);
            Label(465,235,510,45,"单机5层；本地双队4层（地图模拟，非联网）。切换模式会开始新局。",15,Pale);
            if(Btn(new Rect(465,298,510,40),"新建单机 · 5层")){forestPvpMode=false;InitializeForest();}
            if(Btn(new Rect(465,350,510,40),"新建本地双队追猎 · 4层")){forestPvpMode=true;InitializeForest();}
            forestSeedText=GUI.TextField(new Rect(465,410,235,37),forestSeedText,10);int seed;GUI.enabled=int.TryParse(forestSeedText,out seed)&&seed>=0;if(Btn(new Rect(710,410,265,37),"按种子重建当前模式"))InitializeForest(seed,true);GUI.enabled=true;
            if(Btn(new Rect(465,470,245,40),"参考FOREST|1地图"))InitializeForest(73129,false);
            if(Btn(new Rect(720,470,255,40),"旧方格地图")){forestMode=false;forestSettings=false;exploration=new ExplorationRun();exploration.Resources.ConfigureRoster(selectedRoster);}
            if(Btn(new Rect(465,530,510,40),"更换队伍 · 新探索"))OpenMainRosterPicker();if(Btn(new Rect(465,590,510,40),"返回竹林",true))forestSettings=false;
        }
        void DrawLayeredFinish()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.77f));Panel(new Rect(430,275,580,330),Hex("173036"),Gold);Label(455,310,530,60,forestCampaign.Pvp?"玩家"+(forestCampaign.Winner+1)+"携石逃亡成功":"异动石入手 · 单机完成",28,Gold,TextAnchor.MiddleCenter);Label(455,390,530,70,"第"+(forest.FloorIndex+1)+"层 · 地图回合"+forest.Turn+"\n路线与资源由真实状态结算",17,Pale,TextAnchor.MiddleCenter);if(Btn(new Rect(495,510,450,48),"开始新的竹林探索"))InitializeForest();
        }
    }
}
