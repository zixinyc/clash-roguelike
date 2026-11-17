using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        sealed class EffectBadge
        {
            public string Id,Label,Detail;
            public EffectBadge(string id,string label,string detail){Id=id;Label=label;Detail=detail;}
        }
        bool effectInspectorOpen,inspectorAllied;
        int inspectorUnit;
        string inspectorEffect="";
        Vector2 effectScroll;
        static float CombatX(bool allied,int index){return allied?180+index*147:1010+index*215;}
        string Signed(int n){return n>=0?"+"+n:n.ToString();}
        string StatName(CoinStat stat)
        {switch(stat){case CoinStat.BasePower:return "初始点数";case CoinStat.ClashCoinPower:return "拼点硬币威力";case CoinStat.AttackCoinPower:return "攻击硬币威力";default:return "每击原始伤害";}}
        List<EffectBadge> UnitEffects(bool allied,int index)
        {
            bool port=adventureMode&&portRules!=null;
            Unit u=(port?(allied?portShown.Heroes:portShown.Enemies):(allied?shown.Heroes:shown.Enemies))[index];
            var list=new List<EffectBadge>();
            if(u.Shield>0)list.Add(new EffectBadge("shield","盾 "+u.Shield,"当前护盾 "+u.Shield+"。先吸收伤害，回合刷新时清除。"));
            foreach(var s in u.Statuses.Where(s=>s.RemainingTurns>0))list.Add(new EffectBadge("status:"+s.Id+":"+s.Stat,s.Id,s.Id+"："+StatName(s.Stat)+Signed(s.Value)+"；剩余 "+s.RemainingTurns+" 回合。"));
            if(port&&allied)
            {
                if(index==0&&!portShown.TouhouTeam)list.Add(new EffectBadge("preparation",portShown.Preparation>0?"准备 "+portShown.Preparation:"蓄势","灰烬拼点获胜获得准备；观察结束或试探获胜也可获得。捕捉破绽在拼点时消耗准备，拼点初始点数 +4。当前准备 "+portShown.Preparation+"。"));
                if(!portShown.TouhouTeam&&!portShown.ZixiTeam&&index==1)list.Add(new EffectBadge("breaker","破阵","使用费用至少 3 的技能拼点时，初始点数 +2；该次拼点失败额外损失 2 生命。"));
                if(!portShown.TouhouTeam&&index==2)list.Add(new EffectBadge("support","援护","防御行动执行时为其他存活队友提供护盾。护阵为 6，守护之光为 8；援火冲击拼赢后为队友提供 4 护盾。"));
            }
            if(port&&allied&&u.Zixi!=null)
            {
                var z=u.Zixi;
                list.Add(new EffectBadge("metaphysics","超形 "+z.Metaphysics,"超形上学 "+z.Metaphysics+" / 6；本回合已获取 "+z.RoundGain+" / 3。强化选中专属行动消耗3层，每回合一次，撤销返还。"));
                list.Add(new EffectBadge("causality","因果 "+z.Causality,"因果律 "+z.Causality+" / 3，加入本角色拼点点数；强化行动结算后增加一层。"));
                if(z.NextClash.Count>0)list.Add(new EffectBadge("zixi-next","下次拼点 +"+z.NextClash.Values.Sum(),"下次实际拼点时消耗全部待触发奖励，不会在普通回合刷新时清除。"));
                if(z.ShieldUntil.Count>0)list.Add(new EffectBadge("zixi-shield","鞅护盾","鞅剩余护盾 "+z.ShieldUntil.Values.Sum()+"；被伤害吸收的部分不会在下一回合重新生成，最长保留至施放后的下一回合结束。"));
            }
            if(port&&portShown.TouhouTeam)
            {
                var watch=portShown.Heroes[1].RoleState;
                if(watch.WatchActive)list.Add(new EffectBadge("watch",allied?"秒表":"速度 −3",allied?"秒表生效：全队每比拼点对手快 2 点，拼点初始 +1，最多 +3。持续至第 "+watch.WatchUntil+" 回合。":"咲夜的秒表生效，速度 −3，已计入本回合行动格速度。持续至第 "+watch.WatchUntil+" 回合。"));
                if(portShown.WorldActive)list.Add(new EffectBadge("world",allied&&index==1?"世界":"时停",allied&&index==1?"当前为时停回合，咲夜可使用三个不限类别的技能槽。":"时间停止，本回合该角色不能行动。"));
                if(allied&&index==0)
                {
                    var m=u.RoleState;
                    list.Add(new EffectBadge("spark","火花 "+m.Spark,"火花 "+m.Spark+" / 10；大于5层时攻击技能拼点+2、每技能每目标增伤+2。极限火花消耗全部火花。"));
                    list.Add(new EffectBadge("steal","偷取cost","费用不足时，每5生命偷取1敌方未预留cost，生命最低保留1。仅在锁定结算时支付，撤销安排不会扣血。"));
                    if(portShown.Heroes[2].Hp>0)list.Add(new EffectBadge("marisa-team","组队增伤","灵梦在队：最终拼点−2，攻击每技能每目标增伤+5，不重复叠加。"));
                    if(m.OrreryUntil>=portShown.Turn)list.Add(new EffectBadge("orrery","天球仪","当前每次所受攻击减伤5，最低降至0，持续至第 "+m.OrreryUntil+" 回合结束。"));
                }
                if(allied&&index==1)
                {
                    list.Add(new EffectBadge("intercept","自由接招","咲夜可以无视速度限制接招；仍需指定有效的敌方行动。"));
                    int knife=TouhouRoles.SilverKnife(portShown.Turn);
                    if(knife>0)list.Add(new EffectBadge("knife","银刀 +"+knife,"银色小刀：本回合每枚攻击硬币的原始伤害 +"+knife+"。第 1～2 回合 +5，第 3 回合 +2，之后不再加成。"));
                    if(watch.SpaceActive||watch.SpacePending)list.Add(new EffectBadge("space",watch.SpaceActive?"私人空间":"空间待发",watch.SpaceActive?"本回合速度 +3，每枚攻击硬币原始伤害 +5。":"下回合速度 +3，每枚攻击硬币原始伤害 +5。"));
                    if(watch.WorldRound>portShown.Turn)list.Add(new EffectBadge("world-pending","时停待发","第 "+watch.WorldRound+" 回合进入咲夜的世界；本场只能使用一次。"));
                    if(!watch.WatchActive&&watch.WatchUntil>portShown.Turn)list.Add(new EffectBadge("watch-pending","秒表待发","接下来两回合降低敌方速度，并使全队按速度差获得拼点加成。"));
                }
                if(allied&&index==2)
                {
                    list.Add(new EffectBadge("exorcism-passive","退治","对幻想乡本土敌人拼点初始 +1。阴阳宝玉和梦想妙珠造成伤害后叠退治，分别每次技能最多 1 层和 2 层；四层引爆。"));
                    if(u.RoleState.DreamDue>0)list.Add(new EffectBadge("dream","宝玉 "+u.RoleState.DreamOrbs,"梦想天生蓄能：宝玉 "+u.RoleState.DreamOrbs+" / 3，第 "+u.RoleState.DreamDue+" 回合结束发动。死亡取消；后续拼赢增加宝玉。"));
                }
                if(!allied)
                {
                    if(u.Exorcism>0)list.Add(new EffectBadge("exorcism","退治 "+u.Exorcism,"退治 "+u.Exorcism+" / 4。满四层后归零，下回合拼点初始 −3，伤害减半。"));
                    if(u.ExorcismActive||u.ExorcismPending)list.Add(new EffectBadge("exorcism-burst",u.ExorcismActive?"退治爆发":"退治待发",u.ExorcismActive?"本回合拼点初始 −3，攻击伤害减半。":"下回合拼点初始 −3，攻击伤害减半。"));
                    if(u.SealActive||u.SealPending)list.Add(new EffectBadge("seal",u.SealActive?"封魔 −2":"封魔待发",u.SealActive?"本回合拼点初始 −2。":"下回合拼点初始 −2。"));
                    if(u.GensokyoNative)list.Add(new EffectBadge("native","本土","幻想乡本土目标：博丽灵梦与其拼点时初始点数 +1。"));
                }
            }
            if(list.Count==0)list.Add(new EffectBadge("none","无状态","当前没有护盾或持续状态。"));
            return list;
        }
        void OpenEffectInspector(bool allied,int index,string effect)
        {inspectorAllied=allied;inspectorUnit=index;inspectorEffect=effect;effectScroll=Vector2.zero;effectInspectorOpen=true;}
        void CloseEffectInspector(){effectInspectorOpen=false;}
        string EffectTraceText(string value)
        {
            string[] terms={"BeforeClashRound","ClashRoundWin","ClashRoundLoss","BeforeAttack","AttackHeads","AttackTails","SkillStart","ClashStart","ClashTie","ClashEnd","SkillEnd","ClashCoinPower","AttackCoinPower","BasePower","RawDamage","ClashRound","Status","Action","Attack","Clash","Hit"};
            string[] names={"每轮拼点前","拼点本轮获胜","拼点本轮失败","每次攻击前","攻击正面","攻击反面","技能开始","拼点开始","拼点平局","拼点结束","技能结束","拼点硬币威力","攻击硬币威力","初始点数","原始伤害","本轮拼点","持续状态","本次技能","本次攻击","本次拼点","命中"};
            for(int i=0;i<terms.Length;i++)value=value.Replace(terms[i],names[i]);return value;
        }
        void DrawUnitEffects(bool allied,int index)
        {
            float x=CombatX(allied,index);var badges=UnitEffects(allied,index);int shownCount=Math.Min(4,badges.Count);
            for(int i=0;i<shownCount;i++)
            {
                bool more=i==3&&badges.Count>4;var badge=badges[i];int rowCount=Math.Min(2,shownCount-(i/2)*2);Rect r=new Rect(x-rowCount*70/2+(i%2)*70+2,462+(i/2)*25,67,22);
                Color color=allied?Cyan:Red;Fill(r,Color.Lerp(Hex("12202A"),color,.10f));
                Label(r.x+1,r.y+1,r.width-2,r.height-2,more?"+"+(badges.Count-3)+" 效果":badge.Label,11,color,TextAnchor.MiddleCenter);
                GUI.enabled=true;
                if(GUI.Button(r,new GUIContent("",more?"查看全部状态":badge.Detail),GUIStyle.none))OpenEffectInspector(allied,index,more?"":badge.Id);
            }
        }
        void DrawEffectInspector()
        {
            bool port=adventureMode&&portRules!=null;
            var units=port?(inspectorAllied?portShown.Heroes:portShown.Enemies):(inspectorAllied?shown.Heroes:shown.Enemies);
            if(inspectorUnit<0||inspectorUnit>=units.Count){CloseEffectInspector();return;}
            var unit=units[inspectorUnit];var badges=UnitEffects(inspectorAllied,inspectorUnit);
            Panel(new Rect(1080,527,330,323),Hex("12202A"),Hex("35474F"));
            Label(1094,537,252,26,unit.Name+" · 状态详情",17,inspectorAllied?Cyan:Red);
            if(Btn(new Rect(1360,535,36,28),"×")){CloseEffectInspector();return;}
            Label(1094,568,300,22,(port?portBusy:busy)?"演出已暂停 · 关闭详情继续":"点击下方状态查看说明",12,Gold);
            var chosen=badges.FirstOrDefault(b=>b.Id==inspectorEffect);
            string detail=chosen==null?"当前生命 "+unit.Hp+" / "+unit.MaxHp+"。状态以正在显示的战斗快照为准。":chosen.Detail;
            var ev=port?portEvent==null?null:portEvent.Coin:current==null?null:current.Coin;
            if(ev!=null&&ev.Effects.Length>0)detail+="\n\n当前事件触发记录（拼点时包含双方）：\n"+string.Join("\n",ev.Effects.Select(EffectTraceText).ToArray());
            text.fontSize=13;float detailHeight=Math.Max(78,text.CalcHeight(new GUIContent(detail),278)+12),listHeight=badges.Count*30;
            effectScroll=GUI.BeginScrollView(new Rect(1090,596,310,242),effectScroll,new Rect(0,0,289,listHeight+detailHeight));
            for(int i=0;i<badges.Count;i++)if(Btn(new Rect(1,i*30,282,26),badges[i].Label,badges[i].Id==inspectorEffect))inspectorEffect=badges[i].Id;
            Label(3,listHeight+6,278,detailHeight,detail,13,Pale);GUI.EndScrollView();
        }
        void DrawCompactCoins(CoinStep c,string type,float animation,int damage)
        {
            bool port=adventureMode&&portRules!=null;
            int hi=port?portEvent.Hero:current.Hero,ei=port?portEvent.Enemy:current.Enemy;
            if(c.Type=="clash")
            {
                if(hi<0||ei<0)return;
                bool done=type=="clash_end";
                DrawClashHead(CombatX(true,hi),c.Left,c.LeftFaces,c.LeftPower,c.LeftRemaining,c.Winner==0,c.Winner==1,done,animation);
                DrawClashHead(CombatX(false,ei),c.Right,c.RightFaces,c.RightPower,c.RightRemaining,c.Winner==1,c.Winner==0,done,animation);
            }
            else if(type=="strike")
            {
                bool allied=port?portEvent.AttackerAllied:current.Allied;
                int actor=allied?(port?hi:current.Source):(port?ei:current.Source);
                int victim=allied?(port?ei:current.Target):(port?hi:current.Target);
                if(actor<0||victim<0)return;
                float x=CombatX(allied,actor),target=CombatX(!allied,victim);
                Label(x-71,166,142,20,c.Left.Name,14,allied?Cyan:Red,TextAnchor.MiddleCenter);
                CoinToken(new Vector2(x,198),c.Heads,21,animation*1.8f);
                Label(x-65,210,130,28,animation<.22f?"…":c.RawDamage.ToString(),26,Gold,TextAnchor.MiddleCenter);
                string message=port?portEvent.Message:current.Result??"";
                string hit=message.Contains("辅助效果")?"辅助":message.Contains("目标已退场")?"已退场":"−"+damage;
                if(animation>=.22f)Label(target-73,210-animation*6,146,32,hit,28,damage>0?Red:Cyan,TextAnchor.MiddleCenter);
            }
        }
        void DrawClashHead(float x,CoinActionSnapshot action,bool[] faces,int power,int remaining,bool winner,bool loser,bool done,float animation)
        {
            if(action==null)return;
            Label(x-71,166,142,20,action.Name,14,Pale,TextAnchor.MiddleCenter);
            if(done)
            {
                Label(x-68,210,136,28,winner?"拼赢":"拼败",24,winner?Gold:Muted,TextAnchor.MiddleCenter);
                return;
            }
            int count=Math.Min(5,faces.Length);float gap=24,start=x-(count-1)*gap/2;
            for(int i=0;i<count;i++)CoinToken(new Vector2(start+i*gap,198),faces[i],19,animation*1.8f,animation>=.22f&&loser&&i==count-1&&faces.Length==count);
            Label(x-67,210,134,28,animation<.22f?"…":power.ToString(),26,animation>=.22f&&winner?Gold:Pale,TextAnchor.MiddleCenter);
            if(faces.Length>5)Label(x+52,187,26,23,"×"+faces.Length,11,Muted,TextAnchor.MiddleCenter);
        }
        IEnumerator CompactCombatSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;speed=1;OpenPortBattle(false);
            yield return Capture(folder,"compact-planning");ArrangePortAutomatically();PreparePortRound();StartPortRound();
            bool sawClash=false,sawAttack=false,sawPause=false;int rounds=0;
            while(rounds<24)
            {
                if(portBusy)
                {
                    var e=portEvent;
                    if(e!=null&&e.Type=="clash"&&portPhase>.4f&&!sawClash)
                    {
                        sawClash=true;yield return Capture(folder,"compact-clash");
                        OpenEffectInspector(true,e.Hero,UnitEffects(true,e.Hero)[0].Id);string state=portRules.State.Fingerprint();float p=portPhase;
                        for(int i=0;i<3;i++)yield return null;
                        SmokeCheck(portRules.State.Fingerprint()==state&&portPhase==p,"viewing effects pauses presentation and rule stream");
                        yield return Capture(folder,"compact-effect-detail");CloseEffectInspector();sawPause=true;
                    }
                    if(e!=null&&e.Type=="strike"&&portPhase>.4f&&!sawAttack){sawAttack=true;yield return Capture(folder,"compact-attack");speed=4;}
                    yield return null;continue;
                }
                if(portRules.State.Outcome!="")break;
                rounds++;AutoPortPlan();yield return null;
            }
            SmokeCheck(sawClash&&sawAttack&&sawPause&&portRules.State.Outcome!="","compact normal battle completes");
            yield return Capture(folder,"compact-result");ReturnPortMap();SmokeCheck(portRules==null,"normal battle returns to forest");
            OpenPortBattle(false,0,true);Screen.SetResolution(1000,650,false);yield return null;yield return null;
            string before=portRules.State.Fingerprint();
            SmokeCheck(UnitEffects(true,1).Any(x=>x.Id=="knife")&&UnitEffects(true,2).Any(x=>x.Id=="exorcism-passive"),"role passives visible under characters");
            OpenEffectInspector(true,1,"knife");yield return Capture(folder,"compact-small-statuses");CloseEffectInspector();
            SmokeCheck(portRules.State.Fingerprint()==before,"status inspection is read only");
            speed=1;ArrangePortAutomatically();PreparePortRound();StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Type!="clash"||portPhase<.4f))yield return null;
            SmokeCheck(portEvent!=null&&portEvent.Type=="clash","small view reaches real clash");
            yield return Capture(folder,"compact-small-clash");SkipPort();while(portBusy)yield return null;
            for(int i=0;i<24&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome!="","Touhou battle still completes with compact presentation");
            File.WriteAllText(Path.Combine(folder,"compact-smoke.txt"),"COMPACT_COMBAT_SMOKE_PASSED\nNormal and Touhou battles, head coins and values, attack damage, visible effects, read-only inspection, pause/resume, skip, map return, 1440x900 and 1000x650.\n");
            Debug.Log("COMPACT_COMBAT_SMOKE_PASSED");Application.Quit(0);
        }
    }
}
