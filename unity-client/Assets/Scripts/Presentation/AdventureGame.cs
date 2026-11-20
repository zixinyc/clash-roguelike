using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        int selectedRoster=1;
        bool adventureMode,portBusy,portPrepared,fromMap,portSkip;
        ExplorationRun exploration;
        PortBattleRules portRules;
        PortState portShown;
        PortEvent portEvent;
        int portHero=-1,portSlot=-1,portPage,portPlanCount;
        string portCard="",portNotice="点击角色，查看专属技能。";
        bool portShared;
        bool portExplicitSlot;
        float portPhase;
        string[] categoryNames={"进攻","大招","防御"};
        string[] heroNames={"灰烬","长锋","织火"};
        void InitializeAdventure()
        { CloseBattleOverlay();adventureMode=true;exploration=new ExplorationRun();ConfigureAdventureParty(exploration.Resources);heroNames=exploration.Resources.Members().Select(x=>x.Name).ToArray();portRules=null;portShown=null;portBusy=false;portPrepared=false;portHero=-1;portCard="";forestMode=true;InitializeForest(); }
        void AdventureUpdate()
        {
            if(Input.GetKeyDown(KeyCode.Escape))CancelTargetLine();
            if(teamSetup){if(Input.GetKeyDown(KeyCode.Escape))CloseTeamSetup();return;}
            if(effectInspectorOpen&&Input.GetKeyDown(KeyCode.Escape)){CloseEffectInspector();return;}
            if(Input.GetKeyDown(KeyCode.R)&&portRules==null&&(!TrialActive||forestCampaign.Duel==null)) { StopAllCoroutines();InitializeAdventure();return; }
            if(UpdateTrialFlow())return;
            if(portRules==null){if(forestMode)ForestUpdate();return;}
            if(loadoutSelecting)return;
            if(!portBusy&&!portPrepared&&portRules.State.Outcome==""&&portRules.Tick(Time.unscaledDeltaTime)) { portCard="";portPrepared=true;StartPortRound();return; }
            if(portBusy||portRules.State.Outcome!="")return;
            if(Input.GetKeyDown(KeyCode.Return))
            {
                UiKeyPress("port.primary");
                if(portPrepared){StartPortRound();UiConfirm("port.primary");return;}
                if(CanPreparePort){PreparePortRound();UiConfirm("port.primary");}else UiDeny("port.primary");
                return;
            }
            if(portPrepared)return;
            if(Input.GetKeyDown(KeyCode.Escape)){portCard="";portNotice="已取消目标选择。";}
            if(Input.GetKeyDown(KeyCode.Delete))CancelPortSlot();
            var visible=VisiblePortCards();for(int i=0;i<5;i++)if(Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1+i))&&portPage*5+i<visible.Length)SelectPortCard(visible[portPage*5+i].Id);
        }
        void OpenPortBattle(bool map,int encounter=0,bool touhou=false,bool zixi=false)
        {
            CloseEffectInspector();
            CloseBattleOverlay();
            fromMap=map;portRules=map?(forestMode?forest.CreateBattle():exploration.CreateBattle()):new PortBattleRules(73129,encounter,touhou,zixi);portShown=portRules.Snapshot();portHero=-1;portSlot=-1;portCard="";portPrepared=false;portBusy=false;portPage=0;portEvent=null;portExplicitSlot=false;
            if(!map&&touhou&&selectedRoster==3){portRules.ConfigureFlandre(FlandreSkills.Create());portShown=portRules.Snapshot();}
            log.Clear();portNotice="敌方已规划。点击己方角色，选择技能与敌方行动。";
            BeginSkillGroupSelection();
        }
        PortCard[] VisiblePortCards()
        { return portHero<0?new PortCard[0]:portRules.State.Hand.Select(key=>PortContent.Card(PatchouliSkills.EquippedKey(portShown.Heroes[portHero],key))).Where(x=>portShared?x.Owner<0:portShown.Owns(portHero,x)).ToArray(); }
        int DefaultTarget(int unit)
        {
            var available=portRules.State.EnemySlots.Where(x=>x.Unit==unit&&x.Active&&x.Category!=2).ToArray();
            var first=available.FirstOrDefault(x=>portRules.PairFor(x.Id)<0);return first!=null?first.Id:available.Length>0?available[0].Id:unit*3;
        }
        int PortraitTarget(int unit,bool unopposed)
        {
            var slots=portRules.State.EnemySlots.Where(s=>s.Unit==unit&&PortTargetLegal(s.Id));
            var slot=unopposed
                ?slots.FirstOrDefault(s=>!s.Active||s.Category==2||s.TargetOwnPuppet)
                :slots.OrderBy(s=>s.Active&&s.Category!=2&&!s.TargetOwnPuppet?0:1).FirstOrDefault();
            return slot==null?-1:slot.Id;
        }
        string PortCardError(string key)
        { if(portHero<0)return "先选角色";var skill=PortContent.Card(key);int slot=portRules.SlotFor(portHero,key,portExplicitSlot?portSlot:-1);if(!skill.TargetsEnemy)return portRules.CanAssign(key,slot,-1);var targets=portRules.State.EnemySlots.Where(x=>portRules.State.Enemies[x.Unit].Hp>0).ToArray();foreach(var t in targets)if(portRules.CanAssign(key,slot,t.Id)=="")return "";return targets.Length==0?"没有存活目标":portRules.CanAssign(key,slot,targets[0].Id); }
        void SelectPortHero(int actor)
        {
            if(portBusy||portPrepared||portRules.State.Outcome!=""||portRules.State.Heroes[actor].Hp<=0)return;
            if(portRules.State.HeroSlots[actor*3].Frozen){portNotice="时停回合只有咲夜可以行动。";return;}
            portHero=actor;portCard="";portPage=0;portShared=false;portExplicitSlot=false;var previous=portRules.State.HeroSlots.Where(x=>x.Unit==actor&&x.Active).OrderByDescending(x=>x.Order).FirstOrDefault();portSlot=previous==null?actor*3:previous.Id;portNotice=PortHeroName(actor)+"：选择专属或通用技能。";
        }
        void SelectPortCard(string key)
        {
            if(portBusy||portPrepared||portHero<0)return;string error=PortCardError(key);if(error!=""){portNotice=error;return;}
            portCard=key;portSlot=portRules.SlotFor(portHero,key,portExplicitSlot?portSlot:-1);
            if(!PortContent.Card(key).TargetsEnemy)CommitPortTarget(-1);else portNotice=PortContent.Card(key).Name+"：从己方角色拖线，或直接点击目标。";
        }
        bool PortTargetLegal(int id)
        {return !portBusy&&!portPrepared&&portCard!=""&&portHero>=0&&portRules.CanAssign(portCard,portSlot,id)=="";}
        void CommitPortTarget(int id)
        {
            if(!PortTargetLegal(id))return;
            if(portRules.Assign(portCard,portHero,id,portSlot)) {portNotice=PortHeroName(portHero)+" · "+PortContent.Card(portCard).Name+" 已安排";Log(portNotice);portCard="";portExplicitSlot=false;portShown=portRules.Snapshot();}
        }
        void CancelPortSlot()
        {if(portBusy||portPrepared)return;if(portRules.Cancel(portSlot)){portCard="";portShown=portRules.Snapshot();portNotice="已撤销该行动，释放预留费用。";}}
        bool CanPreparePort { get { return portRules!=null&&!portBusy&&!portPrepared&&portCard==""&&portRules.State.Outcome==""&&portRules.State.PlanCount>0; } }
        void PreparePortRound(){if(!CanPreparePort)return;portPrepared=true;portNotice="行动已锁定；点击演示一回合。";UiTriggerClashSweep();}
        void StartPortRound()
        {if(!portPrepared||portBusy||portRules.State.Outcome!="")return;portPlanCount=portRules.State.PlanCount;portPrepared=false;portCard="";portPlaybackRoutine=StartCoroutine(PortPlayback());}
        IEnumerator PortPlayback()
        {
            portBusy=true;portSkip=false;
            foreach(var e in portRules.ResolveStream())
            {
                portEvent=e;portShown=e.Snapshot.Copy(false);portNotice=e.Coin==null?e.Message:CoinHint(e.Coin,e.Type);Log(e.Message);portPhase=0;
                if(e.Type==FlandreSkills.MusicEvent)PlayFlandreMusic();
                float duration=e.Type=="clash"?.65f:e.Type=="strike"||e.Hits!=null?.45f:e.Type=="clash_end"?.4f:e.Type=="attack_end"?.18f:.12f;
                yield return PlayBattleBeat(e.Hits!=null?"strike":e.Type,e.Coin,duration,p=>portPhase=p,()=>portSkip);
            }
            StopImpactShake();
            portPlaybackRoutine=null;portEvent=null;portRules.NextRound();portShown=portRules.Snapshot();portBusy=false;portHero=-1;portSlot=-1;portNotice=portShown.Outcome==""?"新回合，点击角色继续安排。":portShown.Outcome=="victory"?"战斗胜利，可返回地图。":"战斗失败，可返回地图。";
        }
        void SkipPort()
        {if(portBusy){StopImpactShake();portSkip=true;portNotice="快速结算中；平局仍按规则重投。";}}
        void ReturnPortMap()
        {if(portBusy||portRules.State.Outcome=="")return;if(fromMap){if(forestMode)forest.FinishBattle(portRules.State);else exploration.FinishBattle(portRules.State);}portRules=null;portShown=null;portPrepared=false;if(forestPassAfterBattle){forestPassAfterBattle=false;PassForestPlayer();}}
        bool PortExitIsForfeit
        {get{return fromMap&&forestMode&&forestCampaign!=null&&forestCampaign.Pvp&&portShown.Outcome=="";}}

        void ExitPortBattle()
        {
            if(portRules==null)return;
            bool forfeit=PortExitIsForfeit;
            if(portPlaybackRoutine!=null){StopCoroutine(portPlaybackRoutine);portPlaybackRoutine=null;}
            StopImpactShake();
            portBusy=false;
            loadoutSelecting=false;
            CloseEffectInspector();
            if(portShown.Outcome!=""){ReturnPortMap();return;}
            if(fromMap)
            {
                if(forestMode)forest.LeaveMapBattle(portShown,forfeit);
                else
                {
                    exploration.Cost=portShown.Cost;
                    exploration.Resources.ApplyMembers(portShown.Heroes);
                    exploration.InBattle=false;
                }
            }
            portRules=null;portShown=null;portEvent=null;portPrepared=false;portCard="";
            if(forestPassAfterBattle){forestPassAfterBattle=false;PassForestPlayer();}
        }

        void DrawAdventure()
        {
            BeginScreenFrame();
            if(DrawBattleOverlay(TrialActive&&forestCampaign.Duel!=null?forestCampaign.Duel.Log:log)){GUI.matrix=Matrix4x4.identity;return;}
            if(teamSetup){CancelTargetLine();DrawTeamSetup();}
            else if(TrialActive&&forestCampaign.Duel!=null)DrawCampaignDuel(forestCampaign.Duel);
            else if(LocalOpponentTurn)DrawLocalOpponentTurn();
            else if(portRules==null){CancelTargetLine();if(forestMode)DrawForest();else DrawExploration();}
            else
            {
                DrawPortBattle();
                if(uiProbeMarkerVisible)DrawUiProbeMarker();
                if(TrialActive&&fromMap)Label(1120,116,260,24,TrialClockText(),14,Cyan,TextAnchor.MiddleRight);
            }
            GUI.matrix=Matrix4x4.identity;
        }
        string NodeTitle(string kind)
        {switch(kind){case "battle":return "战斗";case "elite":return "精英";case "exit":return "出口";case "supply":return "补给";case "treasure":return "宝藏";case "event":return "事件";case "camp":return "营地";case "shop":return "商店";default:return "空地";}}
        void DrawExploration()
        {
            Label(36,24,700,48,GameTitle+" / 废林探索",31,Gold);Label(38,78,1000,26,"小队探索    /    战斗、节点收益与共享钱包",14,Muted);
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
            Panel(new Rect(1050,125,360,720),Hex("34161F"),Hex("703541"));Label(1072,145,315,42,exploration.Finished?"探索结束":"探索日志",26,Gold);
            Label(1072,203,315,48,"cost  "+exploration.Cost,30,Gold);
            for(int i=0;i<3;i++){Label(1072,275+i*57,315,28,heroNames[i]+"   "+exploration.Hp[i]+" / "+exploration.MaxHp[i],18,Cyan);Fill(new Rect(1072,310+i*57,310,4),Hex("703541"));Fill(new Rect(1072,310+i*57,310*(float)exploration.Hp[i]/exploration.MaxHp[i],4),Gold);}
            Label(1072,485,315,120,exploration.Message,18,Pale);
            GUI.enabled=exploration.Pending=="";
            if(Btn(new Rect(1072,615,315,36),"返回节点森林"))forestMode=true;
            if(Btn(new Rect(1072,662,315,42),"重新探索"))InitializeAdventure();
            if(Btn(new Rect(1072,718,315,42),"单场战斗试玩"))OpenPortBattle(false,0,selectedRoster==1,selectedRoster==2);
            if(Btn(new Rect(1072,774,315,42),"旧版单场战斗")){adventureMode=false;Restart();}
            GUI.enabled=true;
            Label(36,860,1360,25,"相邻格移动 · 节点收益只能领取一次 · 战后 cost 和生命带回地图 · R 重新探索",13,Muted);
            if(exploration.Pending!="")DrawNodeChoice();
        }
        void DrawNodeChoice()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.75f));Panel(new Rect(425,270,590,350),Hex("34161F"),Gold);
            string kind=exploration.Pending;Label(455,296,530,46,NodeTitle(kind),28,Gold);
            Label(455,360,530,60,kind=="shop"?"花费 6 cost，让存活队员各恢复 8 生命。":kind=="camp"?"选择营地补给，治疗不会复活倒下的队员。":"安全搜寻，或用存活队员生命换取更多资源。",17,Pale);
            GUI.enabled=kind!="shop"||exploration.Cost>=6;
            if(Btn(new Rect(455,436,530,44),kind=="shop"?"购买治疗 · 6 cost":kind=="camp"?"全队治疗 +10":"安全搜寻 · +5 cost"))exploration.Choose(0);GUI.enabled=true;
            if(kind!="shop"){if(Btn(new Rect(455,493,530,44),kind=="camp"?"获得 5 cost":"冒险搜寻 · 存活成员 −4 HP / +12 cost"))exploration.Choose(1);}
            else if(Btn(new Rect(455,493,530,44),"离开，稍后再来"))exploration.LeaveShop();
        }
        void DrawPortBattle()
        {
            string confirm=PortExitIsForfeit?"退出视为战败，队伍将在本层永远亭复活。":null;
            if(loadoutSelecting){CancelTargetLine();DrawSkillGroupSelection();DrawBattleButtons(ExitPortBattle,confirm,false);return;}
            DrawUiSettingsStrip();
            Label(700,25,139,40,"回合 "+portShown.Turn,24,Pale);
            UiNumberLabel("port.cost",new Rect(842,25,130,42),"cost ",portShown.Cost,23,Gold);
            double remaining=portRules.State.Remaining;
            Label(982,27,128,34,portBusy?"演出中":portPrepared?"已准备":Math.Ceiling(remaining)+" 秒",16,
                UiBattleClockColor(portBusy||portPrepared||portShown.Outcome!=""?-1:remaining,Cyan));
            DrawRosterSwitch();DrawZixiEnhancement();
            DrawPortStatuses();
            DrawBattlefieldPanel();
            if(!portBusy)DrawPlannedClashes();
            DrawPortTargetLine();
            for(int active=0;active<2;active++)
            {
                for(int i=0;i<portShown.Heroes.Count;i++)if(DuelParticipant(true,i)==(active==1))DrawPortUnit(true,i);
                for(int i=0;i<portShown.Enemies.Count;i++)if(DuelParticipant(false,i)==(active==1))DrawPortUnit(false,i);
            }
            Matrix4x4 shakeSaved=GUI.matrix;
            try
            {
                if(portBusy)ApplyShakeOffset();
                DrawDuelStage();
                if(portEvent!=null&&portEvent.Hits!=null)DrawGroupDamage(portEvent,portPhase);
                else if(portEvent!=null&&portEvent.Coin!=null)DrawCoinPanel(portEvent.Coin,portEvent.Type,portPhase,portEvent.Damage);
            }
            finally { GUI.matrix=shakeSaved; }
            Label(40,527,1000,32,PortGuide(),15,Gold,TextAnchor.MiddleCenter);
            DrawPortCenteredActions();
            DrawPortHandHeader();
            GUI.enabled=!portBusy&&!portPrepared&&portHero>=0;
            if(Btn(new Rect(575,610,110,27),"专属技能",!portShared)){portShared=false;portPage=0;UiSoundSegment();}
            if(Btn(new Rect(695,610,110,27),"通用技能",portShared)){portShared=true;portPage=0;UiSoundSegment();}
            var cards=VisiblePortCards();int pages=Math.Max(1,(cards.Length+4)/5);portPage=Math.Min(portPage,pages-1);
            int pageDir=UiPortPageChanged(portPage,pages);
            if(pageDir!=0)
            {
                var entranceIds=new System.Collections.Generic.List<string>();
                for(int i=0;i<5&&portPage*5+i<cards.Length;i++)entranceIds.Add("port.card."+cards[portPage*5+i].Id);
                UiTriggerPageEntrance(pageDir,entranceIds);
            }
            if(Btn(new Rect(823,610,90,27),"上一页")){portPage=(portPage+pages-1)%pages;UiSoundSegment();}
            if(Btn(new Rect(923,610,130,27),(portPage+1)+" / "+pages+" 下一页")){portPage=(portPage+1)%pages;UiSoundSegment();}GUI.enabled=true;
            if(portHero<0) {Panel(new Rect(32,647,1027,203),Hex("34161F"),Hex("703541"));Label(100,699,880,60,PortHandPlaceholder(),23,Muted,TextAnchor.MiddleCenter);}
            else for(int i=0;i<5&&portPage*5+i<cards.Length;i++)DrawPortCard(cards[portPage*5+i],i);
            if(!DrawEnemySkillDetails(new Rect(1080,527,330,323)))
            {if(effectInspectorOpen)DrawEffectInspector();else DrawPortOperationPanel();}
            UiHintLine(new Rect(32,865,1120,24),"1–5 选技能 · 点击敌方立绘查看技能 · Shift+点击单方面指定 · Enter 准备 / 演示");
            if(portShown.Outcome!=""&&!portBusy)DrawPortResult();
            DrawBattleButtons(ExitPortBattle,confirm);
        }
        void DrawBattlefieldPanel()
        {
            Panel(new Rect(30,162,1380,355),Hex("34161F"),Hex("703541"));
            Fill(new Rect(31,391,1378,125),Hex("291119"));
            Line(new Vector2(31,414),new Vector2(1408,414),Hex("703541"),2);
        }
        void DrawPortHandHeader()
        {
            if(!portBusy&&!portPrepared&&portShown.WorldActive&&portHero>=0&&portShown.Heroes[portHero].CharacterId=="sakuya")
            {
                Label(32,612,190,26,PortHeroName(portHero),15,Cyan);
                foreach(var slot in portShown.HeroSlots.Where(s=>s.Unit==portHero&&s.Flexible))
                {
                    string label="行动 "+(slot.Category+1)+" · 速度 "+slot.Speed;
                    if(!Btn(new Rect(230+slot.Category*112,610,106,27),label,portExplicitSlot&&portSlot==slot.Id))continue;
                    portCard="";
                    portSlot=slot.Id;
                    portExplicitSlot=true;
                }
                return;
            }
            string labelText=portHero<0?portBusy?"我方行动已锁定":portPrepared?"已准备 · 等待演示":"点击己方角色查看技能":PortHeroName(portHero)+" · "+PortRoleSummary(portHero);
            Label(32,612,530,26,labelText,15,Cyan);
        }

        void DrawPortUnit(bool allied,int index)
        {
            var units=allied?portShown.Heroes:portShown.Enemies;var u=units[index];if(u.MaxHp<=0)return;float x=PortActorX(allied,index),y=370;
            bool summon=PatchouliSkills.IsSummon(u);
            bool selected=allied&&portHero==index;Color tint=u.Hp<=0?Hex("35414A"):allied?(index==2?Cyan:Gold):Red;
            if(portEvent!=null&&(portEvent.Hero==index&&allied||portEvent.Enemy==index&&!allied)){
                if(portEvent.Type=="strike"&&portEvent.AttackerAllied!=allied&&portPhase>=.25f&&portPhase<.38f)tint=Pale;
            }
            int portraitTarget=!allied&&portCard!=""?PortraitTarget(index,Event.current.shift):-1;
            bool legal=!allied&&portraitTarget>=0&&PortTargetLegal(portraitTarget);
            bool portraitHover=PortPortraitRect(x).Contains(Event.current.mousePosition);
            Rect outline=new Rect(x-61,y-127,128,169);
            if(!portBusy&&(selected||legal))Outline(outline,selected||portraitHover?Gold:UiBreathingBorder(Cyan,uiTime),2);
            else if(!allied&&!portBusy&&u.Hp>0&&portraitHover)Outline(outline,Red,1);
            var savedMatrix=GUI.matrix;var savedColor=GUI.color;
            try
            {
                if(portBusy)ApplyShakeOffset();
                if(portBusy&&!DuelParticipant(allied,index))GUI.color=new Color(1,1,1,.4f);
                if(DuelParticipant(allied,index))GUIUtility.RotateAroundPivot((allied?1:-1)*Mathf.Sin(portPhase*Mathf.PI)*7,new Vector2(x,y-5));
                DrawPortFigure(allied,index,x,y,tint);
            }
            finally { GUI.matrix=savedMatrix;GUI.color=savedColor; }
            x=CombatX(allied,index);
            Label(x-77,401,165,25,u.Name,17,selected?Gold:Pale,TextAnchor.MiddleCenter);Fill(new Rect(x-60,432,135,5),Hex("633643"));Fill(new Rect(x-60,432,135*(float)u.Hp/u.MaxHp,5),allied?Cyan:Red);Label(x-70,439,155,19,u.Hp+" / "+u.MaxHp,11,Muted,TextAnchor.MiddleCenter);
            DrawUnitEffects(allied,index,x);
            if(allied&&summon)
            {Label(x-70,173,155,30,"自动行动 · 速度 "+portShown.HeroSlots[index*3].Speed,11,Gold,TextAnchor.MiddleCenter);return;}
            GUI.enabled=!portBusy&&u.Hp>0&&(!allied||!portPrepared&&!portShown.HeroSlots[index*3].Frozen);
            var portraitAction=new GUIContent("",allied?"选择角色":legal?"指定目标":"查看敌方技能");
            if(GUI.Button(PortPortraitRect(x),portraitAction,GUIStyle.none))
            {if(allied)SelectPortHero(index);else if(legal)CommitPortTarget(portraitTarget);else ShowPortEnemySkills(index);}GUI.enabled=true;
            if(u.Hp<=0||portShown.Outcome!="")return;
            // During coin playback, the skill name is already drawn with the coin result.
            if(portBusy&&portEvent!=null&&(portEvent.Hits!=null||portEvent.Coin!=null&&(portEvent.Coin.Type=="clash"||portEvent.Type=="strike")))return;

            var slots=allied?portShown.HeroSlots:portShown.EnemySlots;
            foreach(var s in slots.Where(a=>a.Unit==index&&a.Active&&!a.Done))
            {
                if(allied&&portCard!=""&&portSlot==s.Id)continue;
                Rect r=PortSlotRect(allied,x,s.Category);
                bool target=!allied&&PortTargetLegal(s.Id);
                string skillName;
                if(allied||portBusy)skillName=PortContent.Card(s.Key).Name;
                else if(s.TargetOwnPuppet)skillName="→ 己方人偶";
                else
                {
                    var revealed=RevealedEnemyCard(s);
                    skillName=revealed!=null?revealed.Name:s.Category==2?"防御":"→ "+PortHeroName(s.Target);
                }
                string label=(s.Flexible?"行动 "+(s.Category+1):categoryNames[s.Category])+" "+s.Speed+" · "+skillName;
                Panel(r,Hex("172630"),target?UiBreathingBorder(Cyan,uiTime+index*0.37f):allied&&portSlot==s.Id?Gold:Hex("667369"));
                Label(r.x+4,r.y+2,r.width-8,23,label,12,Pale,TextAnchor.MiddleCenter);
                GUI.enabled=!portBusy&&!portPrepared&&(allied?!s.Frozen:target);
                if(GUI.Button(r,GUIContent.none,GUIStyle.none)){if(allied){SelectPortHero(index);portSlot=s.Id;portExplicitSlot=true;}else CommitPortTarget(s.Id);}GUI.enabled=true;
            }
        }
        void DrawPortCard(PortCard c,int index)
        {
            float x=32+index*208;bool selected=portCard==c.Id;
            float baseY=selected?639:647;Rect hit=new Rect(x,baseY,195,203);
            UiSetShortcut("port.card."+c.Id,(index+1).ToString());
            UiEntrance entrance=UiEntranceFor("port.card."+c.Id);
            float slide=entrance.Offset*34f;float alpha=entrance.Alpha;
            string error=PortCardError(c.Id);bool available=error==""&&!portBusy&&!portPrepared;
            float lift=UiCardLift("port.card."+c.Id,hit,available);
            float y=baseY-lift;Rect r=new Rect(x+slide,y,195,203);
            Color fill=UiCardFill(available,selected,lift/3f);Color border=UiCardBorder(available,selected,lift/3f);
            fill.a*=alpha;border.a*=alpha;
            float borderWidth=selected?2f:1f;
            Fill(r,border);Fill(new Rect(r.x+borderWidth,r.y+borderWidth,r.width-2*borderWidth,r.height-2*borderWidth),fill);
            Color tagColor=UiAlpha(Cyan,alpha);
            Color costColor=UiAlpha(Gold,alpha);
            Color nameColor=UiAlpha(Pale,alpha);
            Label(x+13+slide,y+8,130,24,c.Tag,12,tagColor);Label(x+153+slide,y+6,30,34,c.Cost.ToString(),26,costColor);
            int titleSize=c.Name.Length>=13?15:c.Name.Length>=9?17:23;
            Label(x+13+slide,y+43,170,42,c.Name,titleSize,nameColor);
            Color statColor=UiAlpha(Gold,alpha);
            string stats=!c.TargetsEnemy?(c.NoDamage?"辅助 · 不拼点":"盾  +9"):
                c.Coins==0?"需要元素石":"初始 "+c.Base+"  ·  "+c.Coins+" 枚";
            Label(x+13+slide,y+85,170,26,stats,18,statColor);
            if(c.TargetsEnemy&&c.Coins>0)Label(x+13+slide,y+114,174,24,"拼币 +"+c.ClashCoinPower+"  /  攻币 +"+c.AttackCoinPower,12,tagColor);
            Color descColor=UiAlpha(Muted,alpha);
            Label(x+13+slide,y+142,selected?124:170,50,c.Description,12,descColor);
            if(selected){Fill(new Rect(r.xMax-44,r.yMax-22,42,20),Gold);Label(r.xMax-44,r.yMax-22,42,20,"已选",11,Hex("34161F"),TextAnchor.MiddleCenter);}
            if(!available)Fill(new Rect(r.x+1,r.y+1,193,201),new Color(0.03f,0.05f,0.07f,0.3f*alpha));GUI.enabled=available;
            if(GUI.Button(hit,new GUIContent("",c.Description+(error==""?"":"\n"+error)),GUIStyle.none))SelectPortCard(c.Id);GUI.enabled=true;
        }
        void DrawPortOperationPanel()
        {
            int count=portBusy?portPlanCount:portShown.PlanCount;Panel(new Rect(1080,647,330,203),Hex("34161F"),Hex("703541"));
            Label(1098,660,132,27,"本回合行动",18,Gold);
            UiCountLabel("port.count",new Rect(1230,660,34,27),count,18,Gold,TextAnchor.MiddleRight);
            Label(1264,660,60,27," / "+PortActionLimit(),18,Gold);
            UiNumber reserved=UiNumberFor("port.reserved");reserved.Set(portShown.Reserved);
            UiNumber available=UiNumberFor("port.available");available.Set(portShown.Cost-portShown.Reserved);
            Color costColor=Cyan;
            if(reserved.Flash>0f)costColor=Color.Lerp(Cyan,reserved.FlashUp?Gold:Red,reserved.Flash*0.85f);
            Label(1098,698,294,26,"预留 "+reserved.Display+" / 可用 "+available.Display+" cost",14,costColor);
            string detail=portCard!=""?PortContent.Card(portCard).Name+"\n"+PortContent.Card(portCard).Description:GUI.tooltip;
            if(!string.IsNullOrEmpty(detail))Label(1098,737,294,102,detail,12,Pale);
            else{Label(1098,737,294,48,portCard!=""?"点击敌方本体可自动选行动；点击行动格可精确指定。":"同速可以接招；最后有效指定获得拼点。",14,Pale);
            Label(1098,797,294,42,portPrepared?"已锁定，费用尚未支付。":portBusy?"正在依次结算并播放行动。":"安排只预留费用，可以撤销或改牌。",13,Muted);}
        }
        void DrawPortResult()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.75f));Panel(new Rect(440,285,560,310),Hex("34161F"),Gold);
            Label(465,320,510,60,portShown.Outcome=="victory"?"VICTORY / 战斗胜利":"DEFEAT / 战斗失败",30,portShown.Outcome=="victory"?Gold:Red,TextAnchor.MiddleCenter);
            Label(480,400,480,60,"回合 "+portShown.Turn+"  ·  余额 "+portShown.Cost+" cost\n生命与余额将带回地图。",18,Pale,TextAnchor.MiddleCenter);
        }
        void FillPortPlans()
        {
            if(portRules.State.CustomTeam){FillCustomPlans();return;}
            if(portRules.State.TouhouTeam||portRules.State.ZixiTeam){FillTouhouPlans();return;}
            string[][] preferred={new[]{"exploit","probe","nova","guard"},new[]{"all_in","steady_edge","shatter","guard"},new[]{"support_strike","light_guard","cover","nova"}};
            for(int h=0;h<3;h++)
            {
                if(portRules.State.Heroes[h].Hp<=0)continue;int target=portRules.State.Enemies.FindIndex(x=>x.Hp>0);if(target<0)break;
                if(h<2&&portRules.State.Enemies[h].Hp>0)target=h;
                foreach(string key in preferred[h].Concat(new[]{"needle","ember","guard"}))
                {
                    if(portRules.State.HeroSlots.Any(s=>s.Unit==h&&s.Active))break;
                    int slot=portRules.SlotFor(h,key);if(portRules.State.HeroSlots[slot].Active)continue;
                    portRules.Assign(key,h,PortContent.Card(key).Category==2?-1:DefaultTarget(target));
                }
            }
            portShown=portRules.Snapshot();
        }
        void AutoPortPlan(){FillPortPlans();portPrepared=true;StartPortRound();}
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
            SmokeCheck(portShown.PlanCount==1&&portShown.HeroSlots.Count(x=>x.Unit==0&&x.Active)==1,"one skill across categories");PreparePortRound();
            yield return Capture(folder,"port-prepared");StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Type!="clash"))yield return null;
            yield return Capture(folder,"port-clash");while(portBusy)yield return null;speed=4;
            for(int i=0;i<20&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome!="","complete translated battle");string outcome=portRules.State.Outcome;yield return Capture(folder,"port-complete");
            int expected=portRules.State.Cost+(outcome=="victory"?4:0);int[] hp=portRules.State.Heroes.Select(x=>x.Hp).ToArray();ReturnPortMap();
            SmokeCheck(exploration.Cost==expected&&exploration.Hp.SequenceEqual(hp),"actual completed battle carries wallet and HP back");yield return Capture(folder,"map-after-battle");
            OpenPortBattle(false,0,selectedRoster==1,selectedRoster==2);foreach(var s in portRules.State.EnemySlots)s.Active=false;portRules.State.Enemies[0].Hp=1;portRules.State.Enemies[1].Hp=0;
            SelectPortHero(0);SelectPortCard("probe");CommitPortTarget(0);PreparePortRound();StartPortRound();while(portBusy)yield return null;
            Debug.Log("ADVENTURE_VICTORY outcome="+portShown.Outcome+" state="+portRules.State.Outcome+" heroHp="+string.Join(",",portRules.State.Heroes.Select(x=>x.Hp))+" enemyHp="+string.Join(",",portRules.State.Enemies.Select(x=>x.Hp))+" cost="+portRules.State.Cost+" card="+portCard+" slot="+portSlot);
            SmokeCheck(portShown.Outcome=="victory","victory rendering fixture");yield return Capture(folder,"port-victory");ReturnPortMap();
            OpenPortBattle(false,0,selectedRoster==1,selectedRoster==2);Screen.SetResolution(1000,650,false);yield return null;yield return null;SelectPortHero(2);SelectPortCard("light_guard");yield return Capture(folder,"port-small");
            portRules=null;yield return Capture(folder,"map-small");
            string report="UNITY_ADVENTURE_SMOKE_PASSED\nTranslated checks: "+portChecks+"\nLegacy checks: "+legacyChecks+"\nActual complete battle: "+outcome+"\nMap movement, event, shop, role skills, two actions, hidden enemy cards, preparation, speed resolution, actual map-battle-map wallet/HP, victory fixture, two resolutions verified.\n";
            File.WriteAllText(Path.Combine(folder,"adventure-smoke.txt"),report);Debug.Log(report);Application.Quit(0);
        }
    }
}
