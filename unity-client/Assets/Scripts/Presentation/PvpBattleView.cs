using System;
using System.Collections;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        sealed class PvpSelection
        {
            public int Actor=-1,Slot;
            public bool Shared;
            public string Skill="";
            public Vector2 Scroll;
            public void Reset(){Actor=-1;Slot=0;Shared=false;Skill="";Scroll=Vector2.zero;}
        }

        readonly PvpSelection[] pvpSelection={new PvpSelection(),new PvpSelection()};
        CampaignDuel pvpDuel;
        TrialDuelStage pvpInputStage;
        int playedPvpRound;
        Coroutine pvpPlayback;
        TrialDuelBeat pvpBeat;
        Unit[][] pvpFrame;
        float pvpPhase;
        bool pvpSkip,pvpLineMoved;
        int pvpViewSeat;

        void SyncPvpBoard(CampaignDuel duel)
        {
            if(pvpDuel!=duel)
            {
                CancelTargetLine();
                if(pvpPlayback!=null)StopCoroutine(pvpPlayback);
                StopImpactShake();
                pvpDuel=duel;pvpPlayback=null;pvpBeat=null;pvpFrame=null;playedPvpRound=0;
                CloseBattleOverlay();
                pvpViewSeat=duel.Recruitment||drivePvpOpponent?0:forestCampaign.ActivePlayer;
                ResetDuelSelection(duel);
                pvpInputStage=duel.Stage;
            }
            if(duel.Stage==pvpInputStage)return;
            CancelTargetLine();
            pvpInputStage=duel.Stage;
            CloseEnemySkillDetails();
            ResetDuelSelection(duel);
        }

        void ResetDuelSelection(CampaignDuel duel)
        {
            foreach(var selection in pvpSelection)selection.Reset();
            if(!duel.Recruitment||!EditPvpSide(duel,0))return;
            var actors=duel.Sides[0].Units;
            int first=Enumerable.Range(0,actors.Length).Where(i=>PatchouliSkills.LivingFighter(actors[i]))
                .OrderByDescending(i=>duel.Slots(0,i)).DefaultIfEmpty(-1).First();
            if(first>=0)PickPvpActor(duel,0,first);
        }

        void UpdatePvpBoard(CampaignDuel duel)
        {
            SyncPvpBoard(duel);
            if((duel.Stage==TrialDuelStage.Reveal||duel.Stage==TrialDuelStage.Finished)&&playedPvpRound!=duel.Round)
            {
                playedPvpRound=duel.Round;
                pvpPlayback=StartCoroutine(PlayPvpRound(duel));
            }
        }

        IEnumerator PlayPvpRound(CampaignDuel duel)
        {
            int round=duel.Round;
            var beats=duel.Beats.ToArray();
            pvpFrame=duel.RoundOpening;pvpSkip=false;pvpBeat=null;
            yield return null;
            foreach(var beat in beats)
            {
                if(forestCampaign==null||forestCampaign.Duel!=duel||duel.Round!=round||pvpSkip)break;
                pvpBeat=beat;
                pvpPhase=0;
                float duration=beat.Kind=="clash"?.65f:beat.Kind=="strike"?.45f:.55f;
                yield return PlayBattleBeat(beat.Kind,beat.Coin,duration,phase=>
                {
                    pvpPhase=phase;
                    if(phase>=.45f)pvpFrame=beat.Units;
                },()=>pvpSkip||forestCampaign==null||forestCampaign.Duel!=duel||duel.Round!=round,
                    beat.Kind=="clash"&&beat.Coin!=null&&beat.Coin.FinalWinner>=0);
                pvpFrame=beat.Units;
            }
            pvpBeat=null;pvpFrame=null;
            if(forestCampaign!=null&&forestCampaign.Duel==duel&&duel.Round==round&&!pvpSkip)
            {
                float time=.5f;
                while(time>0&&!pvpSkip&&forestCampaign!=null&&forestCampaign.Duel==duel&&duel.Round==round)
                {if(!BattleOverlayOpen)time-=Time.unscaledDeltaTime;yield return null;}
            }
            StopImpactShake();
            pvpPlayback=null;
            if(forestCampaign!=null&&forestCampaign.Duel==duel&&duel.Round==round&&duel.Stage==TrialDuelStage.Reveal)
                duel.NextRound();
        }

        bool EditPvpSide(CampaignDuel duel,int seat)
        {return (!drivePvpOpponent||seat==0)&&(duel.Stage==TrialDuelStage.Deck||duel.Stage==TrialDuelStage.Plan)&&duel.CanEdit(seat);}

        void PickPvpActor(CampaignDuel duel,int seat,int actor)
        {
            var unit=duel.Sides[seat].Units[actor];
            if(!EditPvpSide(duel,seat)||!PatchouliSkills.LivingFighter(unit))return;
            pvpSelection[seat].Actor=actor;
            pvpSelection[seat].Slot=0;
            pvpSelection[seat].Shared=duel.Recruitment&&duel.Stage==TrialDuelStage.Plan&&
                !duel.Cards(seat,actor).Any(key=>PortContent.Card(key).Owner>=0);
            pvpSelection[seat].Skill="";
            pvpSelection[seat].Scroll=Vector2.zero;
        }

        bool PvpCardLegal(CampaignDuel duel,int seat,int actor,PortCard card)
        {
            if(duel.Stage==TrialDuelStage.Deck)return true;
            int slot=pvpSelection[seat].Slot;
            if(!card.TargetsEnemy)return duel.CanPlan(seat,actor,card.Id,-1,slot);
            return Enumerable.Range(0,duel.Sides[1-seat].Units.Length).Any(i=>duel.CanPlan(seat,actor,card.Id,i,slot))||
                Enumerable.Range(0,duel.Sides[seat].Units.Length).Any(i=>duel.CanPlan(seat,actor,card.Id,-i-2,slot));
        }

        void PickPvpCard(CampaignDuel duel,int seat,string key)
        {
            var selection=pvpSelection[seat];
            if(selection.Actor<0||!EditPvpSide(duel,seat))return;
            if(duel.Stage==TrialDuelStage.Deck){duel.Toggle(seat,selection.Actor,key);return;}
            var card=PortContent.Card(key);
            if(!PvpCardLegal(duel,seat,selection.Actor,card))return;
            if(card.TargetsEnemy)selection.Skill=key;
            else if(duel.Plan(seat,selection.Actor,key,-1,selection.Slot))selection.Skill="";
        }

        bool PvpTargetLegal(CampaignDuel duel,int seat,int target)
        {
            var selection=pvpSelection[seat];
            return EditPvpSide(duel,seat)&&duel.Stage==TrialDuelStage.Plan&&selection.Skill!=""&&
                duel.CanPlan(seat,selection.Actor,selection.Skill,target,selection.Slot);
        }

        void PickPvpTarget(CampaignDuel duel,int seat,int target)
        {
            var selection=pvpSelection[seat];
            if(PvpTargetLegal(duel,seat,target)&&duel.Plan(seat,selection.Actor,selection.Skill,target,selection.Slot))selection.Skill="";
        }

        void ReadyPvpSide(CampaignDuel duel,int seat)
        {
            if(!EditPvpSide(duel,seat)||pvpSelection[seat].Skill!=""&&duel.Stage==TrialDuelStage.Plan)return;
            if(duel.SetReady(seat))pvpSelection[seat].Skill="";
        }

        Color PvpColor(int seat){return seat==0?Cyan:Hex("FF8992");}
        static float PvpBaseX(int seat,int actor)
        {return seat==0?123+152*actor:1317-152*actor;}

        bool PvpParticipant(int seat,int actor)
        {
            return pvpBeat!=null&&(pvpBeat.Seat==seat&&pvpBeat.Actor==actor||
                pvpBeat.Kind=="clash"&&seat==1&&pvpBeat.Target==actor||
                pvpBeat.Hits!=null&&pvpBeat.Hits.Any(hit=>hit.Allied==(seat==0)&&hit.Target==actor));
        }

        float PvpActorX(int seat,int actor)
        {
            float origin=PvpBaseX(seat,actor);
            if(!PvpParticipant(seat,actor)||pvpBeat.Target<0)return origin;
            int direction=seat==0?1:-1;
            float progress=DuelAdvance(pvpPhase)/60;
            if(pvpBeat.Kind=="clash")
            {
                float center=(PvpBaseX(0,pvpBeat.Actor)+PvpBaseX(1,pvpBeat.Target))/2;
                return progress<0?origin+direction*DuelAdvance(pvpPhase):
                    Mathf.LerpUnclamped(origin,center-direction*74,progress);
            }
            if(pvpBeat.Kind!="strike")return origin;
            if(pvpBeat.Seat!=seat||pvpBeat.Actor!=actor)return origin-direction*ImpactRecoil(pvpPhase);
            if(pvpBeat.Hits!=null&&pvpBeat.Hits.Length>1)return origin;
            float target=PvpBaseX(1-seat,pvpBeat.Target);
            return progress<0?origin+direction*DuelAdvance(pvpPhase):
                Mathf.LerpUnclamped(origin,target-direction*130,progress);
        }

        static Rect PvpPortraitRect(float x){return new Rect(x-64,237,128,164);}

        int? PvpTargetAt(CampaignDuel duel,int seat,Vector2 pointer)
        {
            for(int target=0;target<duel.Sides[1-seat].Units.Length;target++)
                if(PvpPortraitRect(PvpBaseX(1-seat,target)).Contains(pointer)&&PvpTargetLegal(duel,seat,target))
                    return target;
            for(int target=0;target<duel.Sides[seat].Units.Length;target++)
                if(PvpPortraitRect(PvpBaseX(seat,target)).Contains(pointer)&&PvpTargetLegal(duel,seat,-target-2))
                    return -target-2;
            return null;
        }

        void DrawPvpTargetLine(CampaignDuel duel)
        {
            var input=Event.current;
            bool dragging=targetLineBattle==duel;
            int seat=dragging?targetLineActor/4:-1;
            if(dragging&&input.type==EventType.MouseDrag)pvpLineMoved=true;
            if(!dragging&&input.type==EventType.MouseDown)
            {
                var choice=pvpSelection[pvpViewSeat];
                if(choice.Actor>=0&&choice.Skill!=""&&PvpPortraitRect(PvpBaseX(pvpViewSeat,choice.Actor)).Contains(input.mousePosition))
                {seat=pvpViewSeat;pvpLineMoved=false;}
            }
            if(seat<0)return;
            var selection=pvpSelection[seat];
            if(!EditPvpSide(duel,seat)||selection.Skill==""||selection.Actor<0)
            {CancelTargetLine();return;}
            var source=PvpPortraitRect(PvpBaseX(seat,selection.Actor));
            if(dragging&&!pvpLineMoved&&input.type==EventType.MouseUp&&input.button==0&&
                source.Contains(input.mousePosition)&&PvpTargetLegal(duel,1-seat,selection.Actor))
            {
                PickPvpTarget(duel,1-seat,selection.Actor);
                CancelTargetLine();input.Use();return;
            }
            if(!UpdateTargetLine(input,GUIUtility.hotControl==0,duel,seat*4+selection.Actor,selection.Skill,source,default(Rect),
                (point,shift)=>PvpTargetAt(duel,seat,point),target=>PickPvpTarget(duel,seat,target))||input.type!=EventType.Repaint)return;
            var pointed=PvpTargetAt(duel,seat,input.mousePosition);
            var end=input.mousePosition;
            if(pointed.HasValue)
                end=new Vector2(PvpBaseX(pointed.Value>=0?1-seat:seat,pointed.Value>=0?pointed.Value:-pointed.Value-2),320);
            Line(new Vector2(source.center.x,320),end,pointed.HasValue?PvpColor(seat):Muted,3);
        }

        void DrawPvpUnit(CampaignDuel duel,int seat,int actor,Unit unit)
        {
            if(unit.MaxHp<=0)return;
            float x=PvpActorX(seat,actor);
            var color=PvpColor(seat);
            var bounds=PvpPortraitRect(x);
            bool activeView=seat==pvpViewSeat;
            bool enemyTarget=!activeView&&PvpTargetLegal(duel,1-seat,actor);
            bool puppetTarget=activeView&&unit.Puppet&&PvpTargetLegal(duel,seat,-actor-2);
            bool inspect=!activeView&&pvpPlayback==null;
            if(enemyTarget||puppetTarget)
                Outline(bounds,bounds.Contains(Event.current.mousePosition)?Gold:UiBreathingBorder(PvpColor(pvpViewSeat),uiTime),2);
            else if(activeView&&EditPvpSide(duel,seat)&&pvpSelection[seat].Actor==actor)Outline(bounds,color,2);
            else if(inspect&&bounds.Contains(Event.current.mousePosition))Outline(bounds,color,1);
            var matrix=GUI.matrix;
            var old=GUI.color;
            try
            {
                if(pvpPlayback!=null)ApplyShakeOffset();
                if(pvpBeat!=null&&!PvpParticipant(seat,actor))GUI.color=new Color(1,1,1,.46f);
                if(PvpParticipant(seat,actor)&&pvpBeat.Kind!="ability")
                    GUIUtility.RotateAroundPivot((seat==0?1:-1)*Mathf.Sin(pvpPhase*Mathf.PI)*7,new Vector2(x,365));
                DrawBattleFigure(unit,seat==0,x,370,color);
            }
            finally { GUI.matrix=matrix;GUI.color=old; }
            // Keep the status row readable when a moving portrait passes a teammate.
            x=PvpBaseX(seat,actor);
            Label(x-76,404,152,26,unit.Name,unit.Name.Length>10?13:16,color,TextAnchor.MiddleCenter);
            Fill(new Rect(x-60,433,120,5),Hex("633643"));
            Fill(new Rect(x-60,433,120*(float)unit.Hp/unit.MaxHp,5),color);
            string status=unit.Puppet?"人偶":PatchouliSkills.IsSummon(unit)?"自动行动":
                duel.Stage==TrialDuelStage.Deck?"":"速度 "+duel.Speed(seat,actor);
            Label(x-72,444,144,24,unit.Hp+" / "+unit.MaxHp+" HP   "+status,12,Pale,TextAnchor.MiddleCenter);
            var state=unit.Flandre!=null?"存在 "+unit.Flandre.Existence+"/4"+(unit.Flandre.ChargeTurn>0?" · 蓄力":""):
                unit.Remilia!=null?"绯红 "+unit.Remilia.Scarlet+" · 过热 "+unit.Remilia.Overheat:
                unit.Patchouli!=null?"元素 "+PatchouliSkills.StoneName(unit.Patchouli.Main)+" / "+PatchouliSkills.StoneName(unit.Patchouli.Off):"";
            if(unit.Zixi!=null)state="超形上学 "+unit.Zixi.Metaphysics+"/6 · 因果 "+unit.Zixi.Causality+"/3";
            if(unit.CharacterId=="marisa")state="火花 "+unit.RoleState.Spark+"/10";
            if(unit.CharacterId=="reimu"&&unit.RoleState.DreamDue>0)state="梦想宝玉 "+unit.RoleState.DreamOrbs+"/3";
            if(duel.Stage!=TrialDuelStage.Deck&&unit.Exorcism>0)state+=(state==""?"":" · ")+"退治 "+unit.Exorcism;
            if(state!="")Label(x-72,467,144,22,state,12,Gold,TextAnchor.MiddleCenter);
            if(unit.Shield>0)Label(x-72,490,144,20,"护盾 "+unit.Shield,12,Cyan,TextAnchor.MiddleCenter);
            GUI.enabled=enemyTarget||puppetTarget||inspect||activeView&&EditPvpSide(duel,seat)&&PatchouliSkills.LivingFighter(unit);
            var portraitAction=new GUIContent("",enemyTarget||puppetTarget?"指定目标":inspect?"查看敌方技能":"选择角色");
            if(GUI.Button(bounds,portraitAction,GUIStyle.none))
            {
                if(enemyTarget)PickPvpTarget(duel,1-seat,actor);
                else if(puppetTarget)PickPvpTarget(duel,seat,-actor-2);
                else if(inspect)ShowCampaignEnemySkills(duel,seat,actor);
                else PickPvpActor(duel,seat,actor);
            }
            GUI.enabled=true;
        }

        void DrawPvpBeat()
        {
            if(pvpBeat==null||pvpBeat.Coin==null)return;
            var coin=pvpBeat.Coin;
            float x=PvpActorX(pvpBeat.Seat,pvpBeat.Actor);
            if(pvpBeat.Kind=="clash")
            {
                float other=PvpActorX(1,pvpBeat.Target);
                DrawPvpClashCoins(x,coin.Left.Name,coin.LeftFaces,coin.LeftPower,coin.Winner==1);
                DrawPvpClashCoins(other,coin.Right.Name,coin.RightFaces,coin.RightPower,coin.Winner==0);
                DrawDuelSpark((x+other)/2,pvpPhase,Gold);
            }
            else if(pvpBeat.Kind=="strike")
            {
                Label(x-95,174,190,25,coin.Left.Name,14,Gold,TextAnchor.MiddleCenter);
                CoinToken(new Vector2(x-29,213),coin.Heads,25,pvpPhase);
                Label(x-10,198,65,30,coin.RawDamage.ToString(),23,Pale,TextAnchor.MiddleCenter);
                if(pvpBeat.Hits==null||pvpPhase<.45f)return;
                foreach(var hit in pvpBeat.Hits)
                {
                    float target=PvpActorX(hit.Allied?0:1,hit.Target);
                    Label(target-63,300-30*pvpPhase,126,32,"−"+hit.Damage+" HP",19,Red,TextAnchor.MiddleCenter);
                    DrawDuelSpark(target,pvpPhase,Red);
                }
            }
        }

        void DrawPvpClashCoins(float x,string name,bool[] faces,int power,bool loses)
        {
            Label(x-105,171,210,24,name,14,Gold,TextAnchor.MiddleCenter);
            CoinFaces(faces,x-105,207,210,pvpPhase,loses);
            Label(x-72,225,144,30,power.ToString(),23,Pale,TextAnchor.MiddleCenter);
        }


        string[] CampaignHandKeys(CampaignDuel duel,int seat)
        {
            var choice=pvpSelection[seat];
            if(choice.Actor<0)return new string[0];
            return duel.Stage==TrialDuelStage.Deck?duel.Exclusive(seat,choice.Actor):duel.Cards(seat,choice.Actor)
                .Where(key=>(PortContent.Card(key).Owner<0)==choice.Shared).ToArray();
        }

        void DrawLocalPvpHand(CampaignDuel duel)
        {
            const int seat=0;
            var choice=pvpSelection[seat];
            bool deck=duel.Stage==TrialDuelStage.Deck;
            Panel(new Rect(30,555,978,300),Hex("34161F"),Hex("703541"));
            Label(45,562,690,32,deck?"我的专属卡组":duel.Stage==TrialDuelStage.Plan?"我的手牌":"回合结算",19,Cyan);
            if(!EditPvpSide(duel,seat))
            {
                if(duel.WaitingText(seat)!="")Label(45,604,940,35,"已准备",16,Gold,TextAnchor.MiddleCenter);
                return;
            }
            var team=duel.Sides[seat];
            for(int i=0;i<Math.Min(CharacterRoster.Capacity,team.Units.Length);i++)
            {
                if(!PatchouliSkills.LivingFighter(team.Units[i]))continue;
                if(Btn(new Rect(45+i*173,602,167,34),team.Units[i].Name,choice.Actor==i))PickPvpActor(duel,seat,i);
            }
            int actor=choice.Actor;
            bool pending=choice.Skill!="";
            string detail=actor<0?"点击己方角色查看技能。":"";
            if(actor>=0)
            {
                if(!deck)
                {
                    if(Btn(new Rect(45,648,98,29),"专属",!choice.Shared)){choice.Shared=false;choice.Scroll=Vector2.zero;}
                    if(Btn(new Rect(148,648,98,29),"通用",choice.Shared)){choice.Shared=true;choice.Scroll=Vector2.zero;}
                    for(int slot=0;slot<duel.Slots(seat,actor)&&duel.Slots(seat,actor)>1;slot++)
                        if(Btn(new Rect(274+93*slot,648,89,29),"行动 "+(slot+1),choice.Slot==slot))
                        {choice.Slot=slot;choice.Skill="";}
                    if(team.Units[actor].Zixi!=null&&duel.Planned(seat,actor,choice.Slot)!=null&&
                        Btn(new Rect(798,648,190,29),"强化 · 3 超形上学",duel.IsEnhanced(seat,actor,choice.Slot)))
                        duel.ToggleEnhancement(seat,actor,choice.Slot);
                }
                else Label(46,643,460,32,"已携带 "+team.Equipped[actor].Count+" / 4",14,Pale);
                var keys=CampaignHandKeys(duel,seat);
                if(keys.Length==0)detail="当前角色未携带专属牌，可切换到「通用」。";
                var area=new Rect(44,683,947,94);
                choice.Scroll=GUI.BeginScrollView(area,choice.Scroll,new Rect(0,0,927,Math.Max(92,((keys.Length+5)/6)*45)));
                for(int i=0;i<keys.Length;i++)
                {
                    var card=PortContent.Card(keys[i]);
                    var rect=new Rect(i%6*154,i/6*45,149,40);
                    bool highlighted=deck?team.Equipped[actor].Contains(card.Id):choice.Skill==card.Id;
                    GUI.enabled=PvpCardLegal(duel,seat,actor,card);
                    if(Btn(rect,card.Name+"  "+card.Cost,highlighted))PickPvpCard(duel,seat,card.Id);
                    GUI.enabled=true;
                    if(rect.Contains(Event.current.mousePosition))detail=card.Description;
                }
                GUI.EndScrollView();
            }
            pending=choice.Skill!="";
            if(pending)detail=PortContent.Card(choice.Skill).Name+" · 点击目标或从己方角色拖线";
            else if(!deck&&detail==""&&actor>=0)
            {
                var order=duel.Planned(seat,actor,choice.Slot);
                if(order!=null)detail="已安排 "+PortContent.Card(order.Key).Name;
            }
            Label(45,778,945,25,detail,13,Pale);
            GUI.enabled=pending||!deck&&actor>=0&&duel.Planned(seat,actor,choice.Slot)!=null;
            if(Btn(new Rect(45,811,130,34),pending?"取消选技":"撤销安排"))
            {
                if(!pending)duel.RemovePlan(seat,actor,choice.Slot);
                choice.Skill="";
            }
            GUI.enabled=!pending;
            int arranged=duel.PlannedCount(seat);
            string button=duel.Recruitment?(deck?"确认卡组":arranged>0?"结算回合 · 已安排 "+arranged+" 项":"跳过行动"):
                deck?"准备 · 锁定卡组":"准备  ·  已安排 "+arranged+" 项";
            if(Btn(new Rect(670,808,319,40),button,true))ReadyPvpSide(duel,seat);
            GUI.enabled=true;
        }

        void DrawPvpSide(CampaignDuel duel,int seat)
        {
            float x=seat==0?30:925;
            var color=PvpColor(seat);
            var team=duel.Sides[seat];
            var selection=pvpSelection[seat];
            bool editable=seat==pvpViewSeat&&EditPvpSide(duel,seat),deck=duel.Stage==TrialDuelStage.Deck;
            Panel(new Rect(x,555,485,301),Hex("34161F"),Hex("703541"));
            string title=deck?"专属卡组":"本回合技能";
            if(duel.IsReady(seat)&&(duel.Stage==TrialDuelStage.Deck||duel.Stage==TrialDuelStage.Plan))
                title="已准备";
            else if(!editable)title=seat!=pvpViewSeat&&duel.CanEdit(seat)?"等待切换视角":"已锁定";
            Label(x+14,562,453,30,"玩家 "+(seat+1)+" · "+title,19,color);
            if(!editable)return;
            for(int actor=0;actor<Math.Min(CharacterRoster.Capacity,team.Units.Length);actor++)
            {
                var unit=team.Units[actor];
                if(unit.MaxHp<=0||PatchouliSkills.IsSummon(unit))continue;
                GUI.enabled=PatchouliSkills.LivingFighter(unit);
                if(Btn(new Rect(x+10+155*actor,602,151,30),unit.Name,selection.Actor==actor))
                    PickPvpActor(duel,seat,actor);
                GUI.enabled=true;
            }
            int chosen=selection.Actor;
            if(chosen>=0)
            {
                int slotCount=duel.Slots(seat,chosen);
                bool extraActions=!deck&&slotCount>1;
                if(extraActions)
                {
                    for(int slot=0;slot<slotCount;slot++)
                        if(Btn(new Rect(x+10+100*slot,641,95,29),"行动 "+(slot+1),selection.Slot==slot))
                        {selection.Slot=slot;selection.Skill="";}
                }
                var keys=(deck?duel.Exclusive(seat,chosen):duel.Cards(seat,chosen)).ToArray();
                int handY=extraActions?674:645;
                int handHeight=784-handY;
                if(keys.Length==0)Label(x+12,handY,453,32,"本角色可用通用牌",14,Muted,TextAnchor.MiddleCenter);
                selection.Scroll=GUI.BeginScrollView(new Rect(x+10,handY,465,handHeight),selection.Scroll,new Rect(0,0,444,Math.Max(handHeight-2,((keys.Length+2)/3)*45)));
                for(int i=0;i<keys.Length;i++)
                {
                    var card=PortContent.Card(keys[i]);
                    var rect=new Rect(i%3*148,i/3*45,144,41);
                    bool selected=deck?team.Equipped[chosen].Contains(card.Id):selection.Skill==card.Id;
                    GUI.enabled=PvpCardLegal(duel,seat,chosen,card);
                    if(Btn(rect,card.Name+"  "+card.Cost,selected))PickPvpCard(duel,seat,card.Id);
                    GUI.Label(rect,new GUIContent("",card.Description),GUIStyle.none);
                    GUI.enabled=true;
                }
                GUI.EndScrollView();
            }
            else Label(x+10,650,465,58,deck?"选择角色查看可携带符卡":"点击己方角色开始安排",16,Muted,TextAnchor.MiddleCenter);

            int count=duel.PlannedCount(seat);
            string info=deck?"每人最多携带 4 张专属牌":selection.Skill!=""?"拖线或点击目标":"已安排 "+count+" 项";
            Label(x+12,788,462,24,info,13,Pale);
            bool pending=selection.Skill!="";
            GUI.enabled=pending||!deck&&chosen>=0&&duel.Planned(seat,chosen,selection.Slot)!=null;
            if(Btn(new Rect(x+10,814,143,32),pending?"取消选技":"撤销此角色"))
            {if(!pending)duel.RemovePlan(seat,chosen,selection.Slot);selection.Skill="";}
            GUI.enabled=!pending;
            if(Btn(new Rect(x+167,809,307,39),deck?"准备 · 锁定卡组":"准备",true))ReadyPvpSide(duel,seat);
            GUI.enabled=true;
        }

        string PvpCostLabel(CampaignDuel duel,int seat)
        {return seat==pvpViewSeat?"    "+duel.Sides[seat].Cost+" cost":"";}

        string PvpExitPrompt(CampaignDuel duel,int seat)
        {
            return duel.Recruitment||duel.Stage==TrialDuelStage.Finished?null:
                "玩家 "+(seat+1)+" 将判负，队伍在本层永远亭复活。";
        }

        void ExitCampaignDuel(CampaignDuel duel,int seat)
        {
            if(forestCampaign==null||forestCampaign.Duel!=duel)return;
            if(pvpPlayback!=null)StopCoroutine(pvpPlayback);
            StopImpactShake();
            pvpPlayback=null;pvpBeat=null;pvpFrame=null;
            if(duel.Stage==TrialDuelStage.Finished){FinishTrialBattle();return;}
            if(!duel.Recruitment)
            {
                if(duel.Forfeit(seat))FinishTrialBattle();
                return;
            }
            forestCampaign.AbortTrialDuel(false);
            forest=forestCampaign.Current;
            UpdateForestNames();
        }

        void DrawCampaignDuel(CampaignDuel duel)
        {
            SyncPvpBoard(duel);
            DrawUiSettingsStrip();
            Label(630,22,180,43,"回合 "+duel.Round,23,Gold,TextAnchor.MiddleCenter);
            if(forestCampaign.Trial.TurnSeconds>0)
                Label(806,30,105,26,TrialClockText(),13,UiBattleClockColor(forestCampaign.TurnTimeLeft,Muted),TextAnchor.MiddleCenter);
            if(!duel.Recruitment&&!drivePvpOpponent&&Btn(new Rect(915,25,197,33),"玩家 "+(pvpViewSeat+1)+" 视角 · 切换"))
            {CancelTargetLine();CloseEnemySkillDetails();pvpViewSeat=1-pvpViewSeat;}
            for(int seat=0;seat<2;seat++)
            {
                float x=seat==0?30:735;
                var color=PvpColor(seat);
                Fill(new Rect(x,106,675,42),Color.Lerp(Hex("34161F"),color,.17f));
                bool planning=duel.Stage==TrialDuelStage.Deck||duel.Stage==TrialDuelStage.Plan;
                string status=planning?(duel.IsReady(seat)?"已准备":"出招中 · "+Math.Ceiling(duel.ChoiceLeft[seat])+" 秒"):"已锁定";
                if(duel.Recruitment)status=seat==1?"每回合 "+duel.Slots(1,0)+" 张 · 点击立绘查看技能":
                    planning?(duel.Stage==TrialDuelStage.Deck?"配置卡组":"选择行动"):"";
                string side=duel.Recruitment?(seat==0?"你的队伍":"挑战对手"):
                    drivePvpOpponent?(seat==0?"你的队伍":"人机对手"):"玩家 "+(seat+1);
                double seconds=planning&&!duel.Recruitment&&!duel.IsReady(seat)?duel.ChoiceLeft[seat]:-1;
                Label(x+13,109,375,36,side+PvpCostLabel(duel,seat),17,color);
                Label(x+350,109,312,36,status,17,UiBattleClockColor(seconds,color),TextAnchor.MiddleRight);
            }
            DrawBattlefieldPanel();
            if(duel.Stage==TrialDuelStage.Plan)DrawPvpTargetLine(duel);
            var shown=pvpFrame??(pvpPlayback==null&&playedPvpRound!=duel.Round?duel.RoundOpening:null);
            for(int active=0;active<2;active++)for(int seat=0;seat<2;seat++)
                for(int actor=0;actor<duel.Sides[seat].Units.Length;actor++)
                    if(PvpParticipant(seat,actor)==(active==1))DrawPvpUnit(duel,seat,actor,
                        shown==null?duel.Sides[seat].Units[actor]:shown[seat][actor]);
            var battleMatrix=GUI.matrix;
            try
            {
                if(pvpPlayback!=null)ApplyShakeOffset();
                DrawPvpBeat();
            }
            finally { GUI.matrix=battleMatrix; }
            string result=duel.Recruitment?(duel.Winner==0?"挑战胜利 · 解锁 "+duel.Sides[1].Units[0].Name:"挑战失败 · 返回本层永远亭"):
                "玩家 "+(duel.Winner+1)+" 胜利";
            string subtitle=pvpBeat!=null?pvpBeat.Message:pvpPlayback!=null?(duel.Recruitment?"符卡对决 · 回合结算":"双方已准备 · 回合结算"):
                duel.Stage==TrialDuelStage.Finished?result:
                duel.WaitingText(pvpViewSeat)!=""?duel.WaitingText(pvpViewSeat):
                duel.Stage==TrialDuelStage.Deck?(duel.Recruitment?"可为己方携带专属牌，留空仍可使用通用牌":"配置你的专属卡组，完成后点击准备"):
                duel.Recruitment?"选技后点击对手确定目标，空手时点击对手查看技能":"安排本回合行动 · 点击对手可查看角色技能";
            Label(35,520,1370,30,subtitle,16,Gold,TextAnchor.MiddleCenter);
            if(duel.Recruitment||drivePvpOpponent)DrawLocalPvpHand(duel);
            else{DrawPvpSide(duel,0);DrawPvpSide(duel,1);}
            DrawEnemySkillDetails(new Rect(duel.Recruitment||drivePvpOpponent?1020:525,555,390,300));
            if(pvpPlayback!=null&&Btn(new Rect(545,812,350,36),"跳过演出"))
            {pvpSkip=true;StopImpactShake();}
            int exitingSeat=pvpViewSeat;
            DrawBattleButtons(()=>ExitCampaignDuel(duel,exitingSeat),PvpExitPrompt(duel,exitingSeat));
        }
    }
}
