using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        bool adventureMode,portBusy,portPrepared,fromMap,portSkip;
        ExplorationRun exploration;
        PortBattleRules portRules;
        PortState portShown;
        PortEvent portEvent;
        int portHero=-1,portSlot=-1,portPage,portPlanCount;
        string portCard="",portNotice="点击角色，查看专属技能。";
        bool portShared;
        float portPhase;
        string[] categoryNames={"进攻","大招","防御"};
        string[] heroNames={"灰烬","长锋","织火"};
        void InitializeAdventure()
        { adventureMode=true;exploration=new ExplorationRun();portRules=null;portShown=null;portBusy=false;portPrepared=false;portHero=-1;portCard="";forestMode=true;InitializeForest(); }
        void AdventureUpdate()
        {
            if(Input.GetKeyDown(KeyCode.R)) { StopAllCoroutines();InitializeAdventure();return; }
            if(portRules==null){if(forestMode)ForestUpdate();return;}
            if(!portBusy&&!portPrepared&&portRules.State.Outcome==""&&portRules.Tick(Time.unscaledDeltaTime)) { portCard="";portPrepared=true;StartPortRound();return; }
            if(portBusy||portRules.State.Outcome!="")return;
            if(Input.GetKeyDown(KeyCode.Return)){if(portPrepared)StartPortRound();else PreparePortRound();return;}
            if(portPrepared)return;
            if(Input.GetKeyDown(KeyCode.Escape)){portCard="";portNotice="已取消目标选择。";}
            if(Input.GetKeyDown(KeyCode.Delete))CancelPortSlot();
            var visible=VisiblePortCards();for(int i=0;i<5;i++)if(Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1+i))&&portPage*5+i<visible.Length)SelectPortCard(visible[portPage*5+i].Id);
        }
        void OpenPortBattle(bool map,int encounter=0)
        {
            fromMap=map;portRules=map?(forestMode?forest.CreateBattle():exploration.CreateBattle()):new PortBattleRules(73129,encounter);portShown=portRules.Snapshot();portHero=-1;portSlot=-1;portCard="";portPrepared=false;portBusy=false;portPage=0;portEvent=null;
            log.Clear();portNotice="敌方已规划。点击己方角色，选择技能与敌方行动。";
        }
        PortCard[] VisiblePortCards()
        { return portHero<0?new PortCard[0]:PortContent.Hand.Select(PortContent.Card).Where(x=>portShared?x.Owner<0:x.Owner==portHero).ToArray(); }
        int DefaultTarget(int unit)
        {
            var available=portRules.State.EnemySlots.Where(x=>x.Unit==unit&&x.Active&&x.Category!=2).ToArray();
            var first=available.FirstOrDefault(x=>portRules.PairFor(x.Id)<0);return first!=null?first.Id:available.Length>0?available[0].Id:unit*3;
        }
        string PortCardError(string key)
        { if(portHero<0)return "先选角色";return portRules.CanAssign(key,portRules.SlotFor(portHero,key),PortContent.Card(key).Category==2?-1:portRules.State.EnemySlots.FindIndex(x=>portRules.State.Enemies[x.Unit].Hp>0)); }
        void SelectPortHero(int actor)
        {
            if(portBusy||portPrepared||portRules.State.Outcome!=""||portRules.State.Heroes[actor].Hp<=0)return;
            portHero=actor;portCard="";portPage=0;portShared=false;var previous=portRules.State.HeroSlots.Where(x=>x.Unit==actor&&x.Active).OrderByDescending(x=>x.Order).FirstOrDefault();portSlot=previous==null?actor*3:previous.Id;portNotice=heroNames[actor]+"：选择专属或通用技能。";
        }
        void SelectPortCard(string key)
        {
            if(portBusy||portPrepared||portHero<0)return;string error=PortCardError(key);if(error!=""){portNotice=error;return;}
            portCard=key;portSlot=portRules.SlotFor(portHero,key);
            if(PortContent.Card(key).Category==2)CommitPortTarget(-1);else portNotice=PortContent.Card(key).Name+"：点击敌方角色或具体行动格。";
        }
        bool PortTargetLegal(int id)
        {return !portBusy&&!portPrepared&&portCard!=""&&portHero>=0&&portRules.CanAssign(portCard,portSlot,id)=="";}
        void CommitPortTarget(int id)
        {
            if(!PortTargetLegal(id))return;
            if(portRules.Assign(portCard,portHero,id)) {portNotice=heroNames[portHero]+" · "+PortContent.Card(portCard).Name+" 已安排";Log(portNotice);portCard="";portShown=portRules.Snapshot();}
        }
        void CancelPortSlot()
        {if(portBusy||portPrepared)return;if(portRules.Cancel(portSlot)){portCard="";portShown=portRules.Snapshot();portNotice="已撤销该行动，释放预留费用。";}}
        bool CanPreparePort { get { return portRules!=null&&!portBusy&&!portPrepared&&portCard==""&&portRules.State.Outcome==""&&portRules.State.PlanCount>0; } }
        void PreparePortRound(){if(!CanPreparePort)return;portPrepared=true;portNotice="行动已锁定；点击演示一回合。";}
        void StartPortRound()
        {if(!portPrepared||portBusy||portRules.State.Outcome!="")return;portPlanCount=portRules.State.PlanCount;portPrepared=false;portCard="";StartCoroutine(PortPlayback());}
        IEnumerator PortPlayback()
        {
            portBusy=true;portSkip=false;
            foreach(var e in portRules.ResolveStream())
            {
                portEvent=e;portShown=e.Snapshot.Copy(false);portNotice=e.Coin==null?e.Message:CoinHint(e.Coin,e.Type);Log(e.Message);portPhase=0;
                if(!muted&&(e.Type=="clash"||e.Type=="strike"))audioSource.PlayOneShot(e.Type=="clash"?clashClip:hitClip);
                float duration=e.Type=="clash"?1.25f:e.Type=="strike"?.95f:e.Type=="clash_end"||e.Type=="attack_end"?1f:.15f;
                if(portSkip){portPhase=1;yield return null;}else while(portPhase<1&&!portSkip){portPhase+=Time.unscaledDeltaTime*speed/duration;yield return null;}
            }
            portEvent=null;portRules.NextRound();portShown=portRules.Snapshot();portBusy=false;portHero=-1;portSlot=-1;portNotice=portShown.Outcome==""?"新回合，点击角色继续安排。":portShown.Outcome=="victory"?"战斗胜利，可返回地图。":"战斗失败，可返回地图。";
        }
        void SkipPort()
        {if(portBusy){portSkip=true;portNotice="快速结算中；平局仍按规则重投。";}}
        void ReturnPortMap()
        {if(portBusy||portRules.State.Outcome=="")return;if(fromMap){if(forestMode)forest.FinishBattle(portRules.State);else exploration.FinishBattle(portRules.State);}portRules=null;portShown=null;portPrepared=false;}
        void DrawAdventure()
        {
            float scale=Mathf.Min(Screen.width/1440f,Screen.height/900f);GUI.matrix=Matrix4x4.TRS(new Vector3((Screen.width-1440*scale)/2,(Screen.height-900*scale)/2,0),Quaternion.identity,new Vector3(scale,scale,1));
            Fill(new Rect(0,0,1440,900),Hex("0B141C"));
            if(portRules==null){if(forestMode)DrawForest();else DrawExploration();}else DrawPortBattle();GUI.matrix=Matrix4x4.identity;
        }
        string NodeTitle(string kind)
        {switch(kind){case "battle":return "战斗";case "elite":return "精英";case "exit":return "出口";case "supply":return "补给";case "treasure":return "宝藏";case "event":return "事件";case "camp":return "营地";case "shop":return "商店";default:return "空地";}}
        void DrawExploration()
        {
            Label(36,24,700,48,"余烬交锋 / 废林探索",31,Gold);Label(38,78,1000,26,"小队探索    /    战斗、节点收益与共享钱包",14,Muted);
            Panel(new Rect(30,125,1000,720),Hex("132725"),Hex("426053"));
            for(int y=0;y<4;y++)for(int x=0;x<6;x++)
            {
                int id=y*6+x;Rect r=new Rect(48+x*160,145+y*170,148,156);bool seen=exploration.Seen.Contains(id),here=exploration.X==x&&exploration.Y==y,clear=exploration.Cleared.Contains(id),near=exploration.CanMove(x,y);
                Color color=here?Gold:near?Cyan:Hex("354A44");Panel(r,seen?Hex("18322C"):Hex("101D23"),color);
                for(int t=0;t<3;t++){float tx=r.x+23+t*40;Line(new Vector2(tx,r.y+45),new Vector2(tx+13,r.y+72),Hex("304F3E"),6);Line(new Vector2(tx+13,r.y+72),new Vector2(tx+25,r.y+45),Hex("304F3E"),6);}
                Label(r.x+6,r.y+84,136,32,here?"◆ 小队":!seen?"未知区域":clear?"已清理":NodeTitle(ExplorationRun.Node(x,y)),20,here?Gold:seen?Pale:Muted,TextAnchor.MiddleCenter);
                Label(r.x+8,r.y+125,130,22,near?"点击移动":clear?"可通行":"",12,near?Cyan:Muted,TextAnchor.MiddleCenter);
                GUI.enabled=near;if(GUI.Button(r,GUIContent.none,GUIStyle.none)){exploration.Move(x,y);if(exploration.InBattle)OpenPortBattle(true);}GUI.enabled=true;
            }
            Panel(new Rect(1050,125,360,720),Hex("12202A"),Hex("35474F"));Label(1072,145,315,42,exploration.Finished?"探索结束":"探索日志",26,Gold);
            Label(1072,203,315,48,"cost  "+exploration.Cost,30,Gold);
            for(int i=0;i<3;i++){Label(1072,275+i*57,315,28,heroNames[i]+"   "+exploration.Hp[i]+" / "+exploration.MaxHp[i],18,Cyan);Fill(new Rect(1072,310+i*57,310,4),Hex("35474F"));Fill(new Rect(1072,310+i*57,310*(float)exploration.Hp[i]/exploration.MaxHp[i],4),Gold);}
            Label(1072,485,315,120,exploration.Message,18,Pale);
            GUI.enabled=exploration.Pending=="";
            if(Btn(new Rect(1072,615,315,36),"返回节点森林"))forestMode=true;
            if(Btn(new Rect(1072,662,315,42),"重新探索"))InitializeAdventure();
            if(Btn(new Rect(1072,718,315,42),"单场战斗试玩"))OpenPortBattle(false);
            if(Btn(new Rect(1072,774,315,42),"旧版单场战斗")){adventureMode=false;Restart();}
            GUI.enabled=true;
            Label(36,860,1360,25,"相邻格移动 · 节点收益只能领取一次 · 战后 cost 和生命带回地图 · R 重新探索",13,Muted);
            if(exploration.Pending!="")DrawNodeChoice();
        }
        void DrawNodeChoice()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.75f));Panel(new Rect(425,270,590,350),Hex("12202A"),Gold);
            string kind=exploration.Pending;Label(455,296,530,46,NodeTitle(kind),28,Gold);
            Label(455,360,530,60,kind=="shop"?"花费 6 cost，让存活队员各恢复 8 生命。":kind=="camp"?"选择营地补给，治疗不会复活倒下的队员。":"安全搜寻，或用存活队员生命换取更多资源。",17,Pale);
            GUI.enabled=kind!="shop"||exploration.Cost>=6;
            if(Btn(new Rect(455,436,530,44),kind=="shop"?"购买治疗 · 6 cost":kind=="camp"?"全队治疗 +10":"安全搜寻 · +5 cost"))exploration.Choose(0);GUI.enabled=true;
            if(kind!="shop"){if(Btn(new Rect(455,493,530,44),kind=="camp"?"获得 5 cost":"冒险搜寻 · 存活成员 −4 HP / +12 cost"))exploration.Choose(1);}
            else if(Btn(new Rect(455,493,530,44),"离开，稍后再来"))exploration.LeaveShop();
        }
        void DrawPortBattle()
        {
            Label(30,20,600,42,"余烬交锋 / 行动规划",29,Gold);
            Label(30,68,650,26,"角色专属牌 · 每人两个分类行动 · 目标与速度公开，敌方技能隐藏",13,Muted);
            Label(700,25,190,40,"回合 "+portShown.Turn,24,Pale);Label(900,24,190,42,"cost "+portShown.Cost,28,Gold);
            Label(1100,25,120,36,portBusy?"演出中":portPrepared?"已准备":Math.Ceiling(portRules.State.Remaining)+" 秒",18,Cyan);
            if(Btn(new Rect(1250,25,150,36),"演出 ×"+speed))speed=speed==1?2:speed==2?4:1;
            Panel(new Rect(30,110,1380,407),Hex("12202A"),Hex("35474F"));Fill(new Rect(31,381,1378,135),Hex("0D1922"));Line(new Vector2(31,414),new Vector2(1408,414),Hex("3F4A47"),2);
            for(int i=0;i<3;i++)DrawPortUnit(true,i);for(int i=0;i<2;i++)DrawPortUnit(false,i);
            if(portEvent!=null&&portEvent.Coin!=null)DrawCoinPanel(portEvent.Coin,portEvent.Type,portPhase,portEvent.Damage);
            Label(50,486,1340,24,portNotice,12,Muted);
            Label(32,533,1000,30,portNotice,15,Gold);Label(32,575,470,30,portHero<0?"点击己方角色查看技能":heroNames[portHero]+" · "+(portHero==0?"准备 "+portShown.Preparation:portHero==1?"高费拼点 +2 / 失败 −2 HP":"防御援护队友"),16,Cyan);
            GUI.enabled=!portBusy&&!portPrepared&&portHero>=0;
            if(Btn(new Rect(575,573,110,31),"专属技能",!portShared)){portShared=false;portPage=0;}
            if(Btn(new Rect(695,573,110,31),"通用技能",portShared)){portShared=true;portPage=0;}
            var cards=VisiblePortCards();int pages=Math.Max(1,(cards.Length+4)/5);portPage=Math.Min(portPage,pages-1);
            if(Btn(new Rect(823,573,90,31),"上一页"))portPage=(portPage+pages-1)%pages;
            if(Btn(new Rect(923,573,130,31),(portPage+1)+" / "+pages+" 下一页"))portPage=(portPage+1)%pages;GUI.enabled=true;
            if(portHero<0) {Panel(new Rect(32,625,1027,225),Hex("12202A"),Hex("35474F"));Label(100,699,880,60,portBusy?"按速度执行行动":"点击角色 → 技能 → 敌方角色或行动格",24,Muted,TextAnchor.MiddleCenter);}
            else for(int i=0;i<5&&portPage*5+i<cards.Length;i++)DrawPortCard(cards[portPage*5+i],i);
            DrawBattleJournal();DrawPortOperationPanel();Label(32,865,1120,24,"1–5 选当前页技能 · Delete 撤销选中行动格 · Enter 准备 / 演示 · R 重新探索",12,Muted);
            if(Btn(new Rect(1250,862,150,30),"重新探索")){StopAllCoroutines();InitializeAdventure();}
            if(portShown.Outcome!=""&&!portBusy)DrawPortResult();
        }
        void DrawPortUnit(bool allied,int index)
        {
            var units=allied?portShown.Heroes:portShown.Enemies;var u=units[index];float x=allied?(portBusy?110+index*150:180+index*147):(portBusy?1095+index*190:1010+index*215),y=370;
            bool selected=allied&&portHero==index;Color tint=u.Hp<=0?Hex("35414A"):allied?(index==2?Cyan:Gold):Red;
            if(portEvent!=null&&(portEvent.Hero==index&&allied||portEvent.Enemy==index&&!allied)&&(portEvent.Type=="clash"||portEvent.Type=="strike"))x+=(allied?1:-1)*Mathf.Sin(Mathf.Clamp01(portPhase)*Mathf.PI)*24;
            bool legal=!allied&&PortTargetLegal(DefaultTarget(index));if(selected||legal)Outline(new Rect(x-61,y-127,128,169),selected?Gold:Cyan,2);
            Fill(new Rect(x-15,y-119,31,32),tint);Fill(new Rect(x-25,y-81,51,66),Color.Lerp(tint,Hex("192630"),0.65f));
            Line(new Vector2(x-10,y-22),new Vector2(x-22,y+27),tint,12);Line(new Vector2(x+10,y-22),new Vector2(x+27,y+27),tint,12);Line(new Vector2(x-21,y-69),new Vector2(x-43,y-16),tint,9);Line(new Vector2(x+21,y-69),new Vector2(x+46,y-38),tint,9);Line(new Vector2(x+40,y-25),new Vector2(x+(allied?81:-42),y-103),Pale,4);
            Label(x-77,421,165,27,u.Name,17,selected?Gold:Pale,TextAnchor.MiddleCenter);Fill(new Rect(x-60,454,135,5),Hex("25353D"));Fill(new Rect(x-60,454,135*(float)u.Hp/u.MaxHp,5),allied?Cyan:Red);Label(x-70,462,155,21,u.Hp+" / "+u.MaxHp+(u.Shield>0?" 盾"+u.Shield:""),11,Muted,TextAnchor.MiddleCenter);
            GUI.enabled=!portBusy&&!portPrepared&&u.Hp>0;
            if(GUI.Button(new Rect(x-67,y-130,144,174),GUIContent.none,GUIStyle.none)){if(allied)SelectPortHero(index);else CommitPortTarget(DefaultTarget(index));}GUI.enabled=true;
            var slots=allied?portShown.HeroSlots:portShown.EnemySlots;
            foreach(var s in slots.Where(a=>a.Unit==index))
            {
                Rect r=new Rect(x-71,145+s.Category*30,portBusy&&allied?138:150,25);bool target=!allied&&PortTargetLegal(s.Id);string label=categoryNames[s.Category]+" "+s.Speed;
                if(s.Active)label+=" · "+(allied?PortContent.Card(s.Key).Name:portShown.Phase=="response"?s.Category==2?"防御":"→ "+heroNames[s.Target]:PortContent.Card(s.Key).Name);
                else label+=" · 空";
                Panel(r,Hex("172630"),target?Cyan:allied&&portSlot==s.Id?Gold:s.Active?Hex("667369"):Hex("293941"));Label(r.x+4,r.y+2,r.width-8,23,label,12,s.Active?Pale:Muted,TextAnchor.MiddleCenter);
                GUI.enabled=!portBusy&&!portPrepared&&(allied?u.Hp>0:target);
                if(GUI.Button(r,GUIContent.none,GUIStyle.none)){if(allied){SelectPortHero(index);portSlot=s.Id;}else CommitPortTarget(s.Id);}GUI.enabled=true;
            }
        }
        void DrawPortCard(PortCard c,int index)
        {
            float x=32+index*208,y=portCard==c.Id?620:628;Rect r=new Rect(x,y,195,220);string error=PortCardError(c.Id);bool available=error==""&&!portBusy&&!portPrepared;
            Panel(r,available?Hex("192630"):Hex("111C24"),portCard==c.Id?Gold:Hex("3C4C51"));Label(x+13,y+8,130,24,c.Tag,12,Cyan);Label(x+153,y+6,30,34,c.Cost.ToString(),26,Gold);
            Label(x+13,y+43,170,38,c.Name,23,Pale);Label(x+13,y+85,170,26,c.Category==2?"盾  +9":"初始 "+c.Base+"  ·  "+c.Coins+" 枚",18,Gold);
            if(c.Category!=2)Label(x+13,y+114,174,24,"拼币 +"+c.ClashCoinPower+"  /  攻币 +"+c.AttackCoinPower,12,Cyan);Label(x+13,y+146,170,64,c.Description,12,Muted);
            if(!available)Fill(new Rect(x+1,y+1,193,218),new Color(0.03f,0.05f,0.07f,0.3f));GUI.enabled=available;
            if(GUI.Button(r,new GUIContent("",error==""?c.Description:error),GUIStyle.none))SelectPortCard(c.Id);GUI.enabled=true;
        }
        void DrawPortOperationPanel()
        {
            int count=portBusy?portPlanCount:portShown.PlanCount;Panel(new Rect(1080,680,330,170),Hex("12202A"),Hex("35474F"));Label(1098,690,294,24,"本回合行动   "+count+" / 6",16,Gold);
            int step=portHero<0?0:portCard!=""?2:1;for(int i=0;i<3;i++)Label(1098+i*100,719,95,22,new[]{"1 角色","2 技能","3 目标"}[i],13,!portBusy&&!portPrepared&&step==i?Gold:Muted);
            Label(1098,747,294,40,portBusy?"按速度从高到低执行。":portPrepared?"已准备，点击演示一回合。":portCard!=""?"点击敌方角色，或精确点击行动格。":portHero<0?"点击己方角色。":"可安排两种分类的行动。",13,Pale);
            Label(1098,785,294,22,"预留 "+portShown.Reserved+" / 可用 "+(portShown.Cost-portShown.Reserved)+" cost",12,Muted);
            GUI.enabled=portPrepared&&!portBusy||CanPreparePort;
            if(Btn(new Rect(1098,812,188,28),portBusy?"正在演出":portPrepared?"演示一回合":"准备完成",true)){if(portPrepared)StartPortRound();else PreparePortRound();}GUI.enabled=true;
            if(portBusy){if(Btn(new Rect(1294,812,98,28),"跳过演出"))SkipPort();}
            else if(portPrepared){if(Btn(new Rect(1294,812,98,28),"调整安排"))portPrepared=false;}
            else {GUI.enabled=portSlot>=0&&portShown.HeroSlots[portSlot].Active;if(Btn(new Rect(1294,812,98,28),"撤销安排"))CancelPortSlot();GUI.enabled=true;}
        }
        void DrawPortResult()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.75f));Panel(new Rect(440,285,560,310),Hex("12202A"),Gold);
            Label(465,320,510,60,portShown.Outcome=="victory"?"VICTORY / 战斗胜利":"DEFEAT / 战斗失败",30,portShown.Outcome=="victory"?Gold:Red,TextAnchor.MiddleCenter);
            Label(480,400,480,60,"回合 "+portShown.Turn+"  ·  余额 "+portShown.Cost+" cost\n生命与余额将带回地图。",18,Pale,TextAnchor.MiddleCenter);
            if(Btn(new Rect(560,515,320,48),"返回地图",true))ReturnPortMap();
        }
        void AutoPortPlan()
        {
            string[][] preferred={new[]{"exploit","probe","nova","guard"},new[]{"all_in","steady_edge","shatter","guard"},new[]{"support_strike","light_guard","cover","nova"}};
            for(int h=0;h<3;h++)
            {
                if(portRules.State.Heroes[h].Hp<=0)continue;int target=portRules.State.Enemies.FindIndex(x=>x.Hp>0);if(target<0)break;
                if(h<2&&portRules.State.Enemies[h].Hp>0)target=h;
                foreach(string key in preferred[h].Concat(new[]{"needle","ember","guard"}))
                {
                    int slot=portRules.SlotFor(h,key);if(portRules.State.HeroSlots[slot].Active)continue;
                    portRules.Assign(key,h,PortContent.Card(key).Category==2?-1:DefaultTarget(target));
                }
            }
            portShown=portRules.Snapshot();portPrepared=true;StartPortRound();
        }
        IEnumerator AdventureSmoke(string folder)
        {
            Directory.CreateDirectory(folder);int portChecks=PortChecks.Run();int legacyChecks=BattleRuleChecks.Run()+InteractionChecks.Run()+PanelChecks.Run();
            Debug.Log("UNITY_PORT_CHECKS_PASSED checks="+portChecks+" legacy="+legacyChecks);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            yield return Capture(folder,"map-start");
            exploration.Move(1,1);exploration.Move(1,2);SmokeCheck(exploration.Pending=="event","map event entry");yield return Capture(folder,"map-event");
            exploration.Choose(1);exploration.Move(2,2);exploration.Move(3,2);SmokeCheck(exploration.Pending=="shop","map shop entry");yield return Capture(folder,"map-shop");exploration.Choose(0);
            exploration.Move(2,2);exploration.Move(2,1);SmokeCheck(exploration.InBattle,"map to battle");int enteringCost=exploration.Cost;OpenPortBattle(true);
            SmokeCheck(portRules.State.Cost==enteringCost,"wallet carries into battle");yield return Capture(folder,"port-battle-response");
            SelectPortHero(0);SelectPortCard("probe");yield return Capture(folder,"port-role-targets");CommitPortTarget(DefaultTarget(0));SelectPortCard("guard");
            SmokeCheck(portShown.PlanCount==2&&portShown.HeroSlots.Count(x=>x.Unit==0&&x.Active)==2,"two category actions");PreparePortRound();
            yield return Capture(folder,"port-prepared");StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Type!="clash"))yield return null;
            yield return Capture(folder,"port-clash");while(portBusy)yield return null;speed=4;
            for(int i=0;i<20&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome!="","complete translated battle");string outcome=portRules.State.Outcome;yield return Capture(folder,"port-complete");
            int expected=portRules.State.Cost+(outcome=="victory"?4:0);int[] hp=portRules.State.Heroes.Select(x=>x.Hp).ToArray();ReturnPortMap();
            SmokeCheck(exploration.Cost==expected&&exploration.Hp.SequenceEqual(hp),"actual completed battle carries wallet and HP back");yield return Capture(folder,"map-after-battle");
            OpenPortBattle(false);foreach(var s in portRules.State.EnemySlots)s.Active=false;portRules.State.Enemies[0].Hp=1;portRules.State.Enemies[1].Hp=0;
            SelectPortHero(0);SelectPortCard("probe");CommitPortTarget(0);PreparePortRound();StartPortRound();while(portBusy)yield return null;
            SmokeCheck(portShown.Outcome=="victory","victory rendering fixture");yield return Capture(folder,"port-victory");ReturnPortMap();
            OpenPortBattle(false);Screen.SetResolution(1000,650,false);yield return null;yield return null;SelectPortHero(2);SelectPortCard("light_guard");yield return Capture(folder,"port-small");
            portRules=null;yield return Capture(folder,"map-small");
            string report="UNITY_ADVENTURE_SMOKE_PASSED\nTranslated checks: "+portChecks+"\nLegacy checks: "+legacyChecks+"\nActual complete battle: "+outcome+"\nMap movement, event, shop, role skills, two actions, hidden enemy cards, preparation, speed resolution, actual map-battle-map wallet/HP, victory fixture, two resolutions verified.\n";
            File.WriteAllText(Path.Combine(folder,"adventure-smoke.txt"),report);Debug.Log(report);Application.Quit(0);
        }
    }
}
