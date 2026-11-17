using System;
using System.IO;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        bool forestMode=true,forestSettings,forestAmbient=true;
        ForestRun forest;
        ForestMapArt forestArt;
        Vector2 forestLogScroll;
        int forestLogCount;
        string forestSource="预设地图";
        readonly Rect forestRect=new Rect(22,116,1028,664);
        void InitializeForest(int seed=73129,bool variation=false)
        {
            ForestMapDefinition definition=null;forestSource=variation?"种子变体":"预设地图";
            string path=Path.Combine(Application.streamingAssetsPath,"forest-maze.forest");
            if(!variation&&File.Exists(path))try{definition=ForestMapDefinition.Parse(File.ReadAllText(path));}catch(Exception e){Debug.LogWarning("Forest preset invalid: "+e.Message);forestSource="内置安全预设";}
            if(definition==null)definition=ForestMapDefinition.Generate(seed,variation);
            forest=new ForestRun(definition);forestMode=true;forestSettings=false;forestLogCount=0;forestLogScroll=Vector2.zero;
            if(forestArt!=null)forestArt.Dispose();forestArt=new ForestMapArt(definition.Seed);
        }
        void ForestUpdate()
        {if(Input.GetKeyDown(KeyCode.Return)&&!forestSettings)ForestEndTurn();if(Input.GetKeyDown(KeyCode.Escape))forestSettings=false;}
        void ForestClick(string id)
        {if(forestSettings)return;forest.ClickNode(id);ForestBattleHook();}
        void ForestEndTurn(){forest.EndTurn();ForestBattleHook();}
        void ForestBattleHook(){if(forest.InBattle&&portRules==null)OpenPortBattle(true);}
        Vector2 ForestPoint(ForestNode n){return new Vector2(forestRect.x+n.X*forestRect.width,forestRect.y+n.Y*forestRect.height);}
        Color ForestColor(ForestNodeKind kind)
        {
            switch(kind){case ForestNodeKind.Battle:return Hex("B87859");case ForestNodeKind.Elite:return Hex("C76255");case ForestNodeKind.Supply:case ForestNodeKind.Camp:return Hex("C7B38A");case ForestNodeKind.Event:return Hex("B2A0C2");case ForestNodeKind.Lookout:return Hex("8CAFB0");case ForestNodeKind.Hideout:return Hex("7E9C80");case ForestNodeKind.Danger:return Hex("A36AAC");case ForestNodeKind.Center:return Hex("EEA15E");case ForestNodeKind.Passage:return Hex("A48DBD");case ForestNodeKind.Exit:return Hex("C6D2BC");default:return Gold;}
        }
        string ForestType(ForestNodeKind kind)
        {
            switch(kind){case ForestNodeKind.Spawn:return "旧入口";case ForestNodeKind.Battle:return "普通遭遇";case ForestNodeKind.Elite:return "精英战斗";case ForestNodeKind.Supply:return "补给点";case ForestNodeKind.Event:return "随机事件";case ForestNodeKind.Lookout:return "观察点";case ForestNodeKind.Hideout:return "隐蔽点";case ForestNodeKind.Danger:return "危险区域";case ForestNodeKind.Center:return "中心高收益区";case ForestNodeKind.Passage:return "特殊通道";case ForestNodeKind.Camp:return "营地";case ForestNodeKind.Shop:return "行商";case ForestNodeKind.Exit:return "撤离点";default:return "地点";}
        }
        void ForestStamp(Texture2D texture,Vector2 p,float size,Color color)
        {Color old=GUI.color;GUI.color=color;GUI.DrawTexture(new Rect(p.x-size/2,p.y-size/2,size,size),texture);GUI.color=old;}
        Vector2 ForestCurve(ForestEdge edge,float t)
        {
            Vector2 a=ForestPoint(forest.Map.Node(edge.From)),b=ForestPoint(forest.Map.Node(edge.To)),d=b-a,n=new Vector2(-d.y,d.x).normalized*edge.Bend*forestRect.width;
            Vector2 c=a+d/3+n,e=a+d*2/3-n*.35f;float u=1-t;return u*u*u*a+3*u*u*t*c+3*u*t*t*e+t*t*t*b;
        }
        void ForestPath(ForestEdge edge,ForestIntel intel)
        {
            if(edge.Hidden&&!intel.KnownEdges.Contains(edge.Id))return;
            bool a=intel.Known.Contains(edge.From),b=intel.Known.Contains(edge.To);if(!a&&!b)return;
            bool lit=intel.Visible.Contains(edge.From)||intel.Visible.Contains(edge.To),walked=intel.Travelled.Contains(edge.Id);Color c=edge.Kind==ForestRouteKind.Shortcut?Hex("89749E"):walked?Hex("AD8754"):edge.Kind==ForestRouteKind.Main?Hex("71614A"):Hex("53615B");
            c.a=lit?.9f:.45f;if(!a||!b)c.a=.16f;
            const int segments=28;
            for(int i=0;i<segments;i++)
            {
                float t=(float)i/segments;if(!a&&t<.8f||!b&&t>.2f)continue;
                if(edge.Kind==ForestRouteKind.Shortcut&&i%4>=2)continue;
                Vector2 p=ForestCurve(edge,t),q=ForestCurve(edge,(float)(i+1)/segments);if(!forestRect.Contains(p)||!forestRect.Contains(q))continue;
                Line(p,q,new Color(.025f,.032f,.026f,c.a),7);Line(p,q,c,edge.Kind==ForestRouteKind.Main||walked?2.6f:1.8f);
                if(walked&&i%5==0)ForestStamp(forestArt.Glow,p,6,new Color(.8f,.48f,.22f,.5f));
            }
        }
        void ForestIcon(ForestNodeKind kind,Vector2 p,float radius,Color color)
        {
            float r=radius;
            switch(kind)
            {
                case ForestNodeKind.Battle:case ForestNodeKind.Elite:
                    Line(p+new Vector2(-r,-r),p+new Vector2(r,r),color,2);Line(p+new Vector2(r,-r),p+new Vector2(-r,r),color,2);
                    Line(p+new Vector2(-r,-r/2),p+new Vector2(-r/2,-r),color,2);Line(p+new Vector2(r,r/2),p+new Vector2(r/2,r),color,2);if(kind==ForestNodeKind.Elite)ForestStamp(forestArt.Ring,p,r*3.5f,color);break;
                case ForestNodeKind.Supply:case ForestNodeKind.Shop:
                    Outline(new Rect(p.x-r,p.y-r*.6f,r*2,r*1.4f),color,1.6f);Line(p+new Vector2(-r*.5f,-r*.6f),p+new Vector2(-r*.5f,-r),color,2);Line(p+new Vector2(-r*.5f,-r),p+new Vector2(r*.5f,-r),color,2);Line(p+new Vector2(r*.5f,-r),p+new Vector2(r*.5f,-r*.6f),color,2);break;
                case ForestNodeKind.Lookout:
                    Line(p+new Vector2(-r,0),p+new Vector2(0,-r*.65f),color,2);Line(p+new Vector2(0,-r*.65f),p+new Vector2(r,0),color,2);Line(p+new Vector2(r,0),p+new Vector2(0,r*.65f),color,2);Line(p+new Vector2(0,r*.65f),p+new Vector2(-r,0),color,2);ForestStamp(forestArt.Glow,p,r*.7f,color);break;
                case ForestNodeKind.Hideout:
                    for(int i=-1;i<=1;i++){Line(p+new Vector2(i*r*.7f,r),p+new Vector2(i*r*.4f,-r),color,2);Line(p+new Vector2(i*r*.4f,-r),p+new Vector2(i*r*.4f+r*.5f,-r*.3f),color,1);}break;
                case ForestNodeKind.Danger:
                    Line(p+new Vector2(0,-r),p+new Vector2(r,r),color,2);Line(p+new Vector2(r,r),p+new Vector2(-r,r),color,2);Line(p+new Vector2(-r,r),p+new Vector2(0,-r),color,2);Line(p+new Vector2(0,-r*.3f),p+new Vector2(0,r*.35f),color,2);break;
                case ForestNodeKind.Center:case ForestNodeKind.Camp:
                    Line(p+new Vector2(-r*.7f,r*.7f),p+new Vector2(-r*.9f,0),color,2);Line(p+new Vector2(-r*.9f,0),p+new Vector2(0,-r),color,2);Line(p+new Vector2(0,-r),p+new Vector2(-r*.15f,r*.15f),color,2);Line(p+new Vector2(-r*.15f,r*.15f),p+new Vector2(r*.65f,-r*.3f),color,2);Line(p+new Vector2(r*.65f,-r*.3f),p+new Vector2(r*.7f,r*.7f),color,2);Line(p+new Vector2(r*.7f,r*.7f),p+new Vector2(-r*.7f,r*.7f),color,2);break;
                case ForestNodeKind.Event:
                    Label(p.x-r,p.y-r*1.2f,r*2,r*2.4f,"?",(int)(r*2),color,TextAnchor.MiddleCenter);break;
                case ForestNodeKind.Exit:case ForestNodeKind.Passage:
                    Line(p+new Vector2(-r,r),p+new Vector2(-r,-r*.6f),color,2);Line(p+new Vector2(-r,-r*.6f),p+new Vector2(0,-r),color,2);Line(p+new Vector2(0,-r),p+new Vector2(r,-r*.6f),color,2);Line(p+new Vector2(r,-r*.6f),p+new Vector2(r,r),color,2);break;
                default:
                    Line(p+new Vector2(0,-r),p+new Vector2(r,0),color,2);Line(p+new Vector2(r,0),p+new Vector2(0,r),color,2);Line(p+new Vector2(0,r),p+new Vector2(-r,0),color,2);Line(p+new Vector2(-r,0),p+new Vector2(0,-r),color,2);break;
            }
        }
        void DrawForest()
        {
            if(forest==null)InitializeForest();var intel=forest.Intel();forestArt.UpdateFog(forest,intel);
            Label(28,20,590,42,"余烬交锋 / 废林追猎",30,Hex("D8C7A5"));Label(30,70,590,26,"单机探索  /  夺取烬核，穿过迷雾返回归途石门",13,Muted);
            Label(650,27,190,36,"回合 "+forest.Turn.ToString("00"),23,Gold);Label(845,30,385,30,"小队行动 · "+forest.Phase,16,Pale);
            Label(650,70,570,24,"相邻移动 1 点  /  捷径 2 点 + 1 情报  /  道具使用 1 点",12,Muted);
            GUI.enabled=forest.Pending==""&&!forest.Finished;if(Btn(new Rect(1280,31,134,35),"设置 / 地图"))forestSettings=!forestSettings;GUI.enabled=true;
            Panel(forestRect,Hex("101714"),Hex("343D35"));GUI.DrawTexture(new Rect(forestRect.x+1,forestRect.y+1,forestRect.width-2,forestRect.height-2),forestArt.Terrain);GUI.DrawTexture(forestRect,forestArt.Fog);
            foreach(var edge in forest.Map.Edges)ForestPath(edge,intel);
            float time=Time.realtimeSinceStartup;
            foreach(var node in forest.Map.Nodes.Where(n=>intel.Known.Contains(n.Id)))
            {
                Vector2 p=ForestPoint(node);bool visible=intel.Visible.Contains(node.Id),can=forest.CanMove(node.Id),here=node.Id==forest.Position,selected=node.Id==forest.Selected,cleared=forest.Cleared.Contains(node.Id);Color c=ForestColor(node.Kind);if(!visible)c=Color.Lerp(c,Hex("5C625E"),.65f);
                if(node.Kind==ForestNodeKind.Center){ForestStamp(forestArt.Glow,p,125,new Color(.9f,.25f,.04f,visible?.7f:.25f));ForestStamp(forestArt.Ring,p,61+Mathf.Sin(time*1.7f)*3,new Color(.85f,.49f,.22f,.65f));}
                if(node.Kind==ForestNodeKind.Danger)ForestStamp(forestArt.Glow,p,65,new Color(.5f,.13f,.5f,visible?.35f:.1f));
                if(can)ForestStamp(forestArt.Glow,p,68,new Color(.88f,.59f,.27f,.35f));
                ForestStamp(forestArt.Glow,p,37,Hex("080C0C"));ForestStamp(forestArt.Ring,p,39,can?Gold:here?Pale:c);ForestIcon(node.Kind,p,9,c);
                if(selected)ForestStamp(forestArt.Ring,p,49,Gold);
                if(cleared)Fill(new Rect(p.x+13,p.y-16,4,4),Hex("A18C60"));
                Label(p.x-61,p.y+22,122,22,node.Name,11,selected?Gold:visible?Pale:Muted,TextAnchor.MiddleCenter);
                GUI.enabled=!forestSettings&&forest.Pending==""&&!forest.Finished;
                if(GUI.Button(new Rect(p.x-23,p.y-23,46,46),new GUIContent("",ForestType(node.Kind)+" · "+forest.MoveError(node.Id)),GUIStyle.none))ForestClick(node.Id);GUI.enabled=true;
            }
            Vector2 player=ForestPoint(forest.Map.Node(forest.Position));ForestStamp(forestArt.Glow,player,90,new Color(1,.67f,.29f,.30f));ForestStamp(forestArt.Ring,player,56+Mathf.Sin(time*2)*3,Gold);
            Line(player+new Vector2(-6,-31),player+new Vector2(0,-24),Gold,2);Line(player+new Vector2(0,-24),player+new Vector2(6,-31),Gold,2);Label(player.x-24,player.y-51,48,20,"小队",11,Gold,TextAnchor.MiddleCenter);
            if(intel.PatrolNode!=null)
            {
                Vector2 p=ForestPoint(forest.Map.Node(intel.PatrolNode))+new Vector2(21,-20);ForestStamp(forestArt.Glow,p,35,new Color(.9f,.12f,.08f,.7f));ForestIcon(ForestNodeKind.Elite,p,5,Red);Label(p.x-25,p.y-27,70,20,"兽群",11,Red,TextAnchor.MiddleCenter);
            }
            foreach(var s in intel.Signals.Take(4)){var p=ForestPoint(forest.Map.Node(s.NodeId))+new Vector2(-24,-15);ForestStamp(forestArt.Glow,p,12,s.Kind=="danger"?new Color(.6f,.2f,.6f,.5f):new Color(.6f,.65f,.62f,.5f));}
            if(forestAmbient)for(int i=0;i<16;i++){float x=forestRect.x+40+(i*79+forest.Map.Seed%70)%(int)(forestRect.width-80),y=forestRect.y+30+(i*113+time*(3+i%3))%(forestRect.height-60);ForestStamp(forestArt.Glow,new Vector2(x,y),i%3==0?8:4,new Color(.8f,.44f,.18f,.16f));}
            DrawForestSidebar(intel);DrawForestFooter();
            if(forest.Pending!="")DrawForestChoice();
            if(forestSettings)DrawForestSettings();
            if(forest.Finished)DrawForestFinish();
        }
        void ForestModule(Rect r,string title)
        {Panel(r,Hex("111B20"),Hex("343D3D"));Label(r.x+15,r.y+10,r.width-30,25,title,16,Hex("BBA786"));}
        void DrawForestSidebar(ForestIntel intel)
        {
            ForestModule(new Rect(1068,116,350,135),"资源 / 背包");Label(1084,150,310,32,"cost   "+forest.Party.Cost,24,Gold);
            bool open=!forestSettings&&forest.Pending==""&&!forest.Finished&&forest.ActionsLeft>0;
            Label(1084,195,117,24,"补给  "+forest.Supply,13,Pale);GUI.enabled=open&&forest.Supply>0&&forest.Party.Hp.Where((h,i)=>h>0&&h<forest.Party.MaxHp[i]).Any();if(Btn(new Rect(1200,192,38,24),"用"))forest.UseSupply();
            Label(1250,195,110,24,"追踪  "+forest.Trackers,13,Pale);GUI.enabled=open&&forest.Trackers>0;if(Btn(new Rect(1365,192,38,24),"用"))forest.UseTracker();
            Label(1084,224,117,24,"烟雾弹  "+forest.Smoke,13,Pale);GUI.enabled=open&&forest.Smoke>0;if(Btn(new Rect(1200,221,38,24),"用"))forest.UseSmoke();GUI.enabled=true;Label(1250,224,160,24,"情报碎片  "+forest.IntelFragments,13,Pale);
            ForestModule(new Rect(1068,263,350,167),"状态 / 小队");Label(1084,298,310,24,"移动力 "+forest.ActionsLeft+" / "+forest.ActionBudget+"     可见地点 "+intel.Visible.Count,13,Pale);
            for(int i=0;i<3;i++){float x=1084+i*106;Label(x,326,103,21,heroNames[i]+" "+forest.Party.Hp[i]+"/"+forest.Party.MaxHp[i],11,Muted);Fill(new Rect(x,350,94,3),Hex("35474F"));Fill(new Rect(x,350,94*(float)forest.Party.Hp[i]/forest.Party.MaxHp[i],3),Cyan);}
            Label(1084,365,310,24,"可见度（暴露） "+forest.Exposure+"%   "+(forest.HiddenTurns>0?"隐蔽 "+forest.HiddenTurns+" 回合":"未隐蔽"),12,forest.HiddenTurns>0?Cyan:Muted);
            Label(1084,393,310,25,"警戒 "+forest.Alert+" / 5        疲劳 "+forest.Fatigue+" / 8",13,forest.Alert>=3?Red:Muted);
            ForestModule(new Rect(1068,442,350,190),"最近行动");
            var entries=forest.Journal.ToArray();text.fontSize=12;text.wordWrap=true;float contentHeight=0;var heights=new float[entries.Length];for(int i=0;i<entries.Length;i++){heights[i]=Math.Max(23,text.CalcHeight(new GUIContent("["+entries[i].Turn.ToString("00")+"] "+entries[i].Message),284)+8);contentHeight+=heights[i];}
            if(forestLogCount!=entries.Length){forestLogCount=entries.Length;forestLogScroll.y=contentHeight;}
            forestLogScroll=GUI.BeginScrollView(new Rect(1080,480,326,140),forestLogScroll,new Rect(0,0,294,contentHeight));float y=0;
            for(int i=0;i<entries.Length;i++){Label(2,y,284,heights[i],"["+entries[i].Turn.ToString("00")+"] "+entries[i].Message,12,i==entries.Length-1?Pale:Muted);y+=heights[i];}GUI.EndScrollView();
            ForestModule(new Rect(1068,644,350,136),"周边异动 / 环境情报");
            int line=0;if(intel.PatrolNode!=null){Label(1084,680,316,28,"兽群可见："+forest.Map.Node(intel.PatrolNode).Name,12,Red);line++;}
            foreach(var s in intel.Signals.OrderByDescending(s=>s.CreatedTurn).Take(3-line)){Label(1084,680+line*28,316,28,(forest.Turn-s.CreatedTurn)+" 回合前 · "+forest.Map.Node(s.NodeId).Name+" / "+(s.Kind=="track"?"兽群足迹":s.Kind=="noise"?"枝木断裂声":s.Kind=="battle"?"战斗痕迹":"危险变化"),11,Muted);line++;}
            if(line==0)Label(1084,685,312,55,"风声掩盖了异动。\n当前视野内暂无可靠踪迹。",12,Muted);
        }
        void DrawForestFooter()
        {
            ForestNodeKind[] kinds={ForestNodeKind.Battle,ForestNodeKind.Supply,ForestNodeKind.Event,ForestNodeKind.Lookout,ForestNodeKind.Hideout,ForestNodeKind.Danger,ForestNodeKind.Center};string[] names={"遭遇","补给","事件","观察","隐蔽","危险","高收益"};
            for(int i=0;i<7;i++){Vector2 p=new Vector2(40+i*137,814);ForestIcon(kinds[i],p,6,ForestColor(kinds[i]));Label(p.x+15,p.y-9,100,22,names[i],12,Muted);}
            string[] routes={"主路线","支线 / 环路","已走过","特殊通道"};Color[] colors={Hex("71614A"),Hex("53615B"),Hex("AD8754"),Hex("89749E")};for(int i=0;i<4;i++){float x=30+i*230;Line(new Vector2(x,845),new Vector2(x+30,845),colors[i],2);Label(x+39,835,180,24,routes[i],11,Muted);}
            var selected=forest.Map.Node(forest.Selected);string info=selected==null?"":selected.Id==forest.Position?forest.Message:selected.Name+" / "+ForestType(selected.Kind)+"  ·  "+forest.MoveError(selected.Id);
            Label(30,867,1008,26,info,12,Gold);
            GUI.enabled=!forestSettings&&forest.Pending==""&&!forest.Finished;if(Btn(new Rect(1068,801,350,43),"结束回合  →",true))ForestEndTurn();GUI.enabled=true;
            bool open=!forestSettings&&forest.Pending==""&&!forest.Finished&&forest.ActionsLeft>0;GUI.enabled=open&&forest.Map.Node(forest.Position).Kind==ForestNodeKind.Lookout;
            if(Btn(new Rect(1068,855,170,30),"登高观察"))forest.Observe();GUI.enabled=open&&forest.Map.Node(forest.Position).Kind==ForestNodeKind.Hideout;if(Btn(new Rect(1248,855,170,30),"隐入林影"))forest.Hide();GUI.enabled=true;
        }
        void DrawForestChoice()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.78f));Panel(new Rect(425,270,590,350),Hex("12202A"),Gold);
            string kind=forest.Pending,title=kind=="shop"?"废林行商":kind=="camp"?"旧猎人营":forest.EventVariant==1?"迷途猎人":forest.EventVariant==2?"烧焦的残信":"灰碑遗物";
            Label(455,296,530,46,title,28,Gold);Label(455,356,530,66,kind=="shop"?"使用现有钱包购买治疗；倒下的队员不会复活。":kind=="camp"?"在余火旁休整，或收集可用物资。":"林中的选择会改变真实资源与小队状态。",17,Pale);
            string a=kind=="shop"?"治疗全队 +8 HP · 6 cost":kind=="camp"?"休整 · 全队 +10 HP":forest.EventVariant==2?"解读残信 · −3 cost / +2 情报":"安全搜寻 · +5 cost";
            string b=kind=="shop"?"离开，稍后再来":kind=="camp"?"搜集物资 · +5 cost":forest.EventVariant==1?"接近猎人 · 可能获物资，也可能遇险":"冒险搜寻 · −4 HP / +12 cost";
            GUI.enabled=kind=="shop"?forest.Party.Cost>=6:kind=="event"&&forest.EventVariant==2?forest.Party.Cost>=3:true;
            if(Btn(new Rect(455,436,530,44),a))forest.Choose(0);GUI.enabled=true;
            if(Btn(new Rect(455,493,530,44),b)){if(kind=="shop")forest.LeaveShop();else forest.Choose(1);}
        }
        void DrawForestSettings()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.8f));Panel(new Rect(455,200,530,510),Hex("12202A"),Gold);Label(485,225,470,44,"废林设定",27,Gold);
            Label(485,287,470,70,forestSource+" · 种子 "+forest.Map.Seed+"\n单机小队探索；兽群是环境敌人。",16,Pale);
            if(Btn(new Rect(485,375,470,40),forestAmbient?"环境余火：开":"环境余火：关"))forestAmbient=!forestAmbient;
            if(Btn(new Rect(485,428,470,40),"新探索 · 预设地图"))InitializeForest();
            if(Btn(new Rect(485,481,470,40),"新探索 · 种子变体"))InitializeForest((forest.Map.Seed+7919)&int.MaxValue,true);
            if(Btn(new Rect(485,534,470,40),"旧方格地图 · 对照入口")){forestMode=false;forestSettings=false;exploration=new ExplorationRun();}
            if(Btn(new Rect(485,603,470,40),"返回森林",true))forestSettings=false;
        }
        void DrawForestFinish()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.76f));Panel(new Rect(440,285,560,310),Hex("12202A"),Gold);bool won=forest.EmberCore&&forest.Party.Hp.Any(x=>x>0);
            Label(465,320,510,60,won?"烬核归途 / 探索完成":"余火熄灭 / 探索结束",29,won?Gold:Red,TextAnchor.MiddleCenter);
            Label(480,400,480,60,"地图回合 "+forest.Turn+"  ·  剩余 "+forest.Party.Cost+" cost\n"+(won?"小队带着烬核走出了废林。":"小队未能完成这次探索。"),17,Pale,TextAnchor.MiddleCenter);
            if(Btn(new Rect(560,515,320,48),"重新探索",true))InitializeForest();
        }
    }
}
