using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        string PortAllyStatus()
        {
            if(portShown.Outcome!="")return portShown.Outcome=="victory"?"我方 · 胜利":"我方 · 败北";
            if(portBusy)return "我方 · 交锋中    行动已锁定";
            if(portPrepared)return "我方 · 已准备    已锁定 "+portShown.PlanCount+" 项行动";
            return "我方 · 规划中    已安排 "+portShown.PlanCount+" / "+(portShown.WorldActive?2:6)+" 项行动";
        }
        string PortEnemyStatus()
        {
            if(portShown.Outcome!="")return portShown.Outcome=="victory"?"敌方 · 已击败":"敌方 · 获胜";
            if(portShown.WorldActive)return "敌方 · 时间停止    本回合不攻击、不防御";return portBusy?"敌方 · 交锋中    技能已揭晓":"敌方 · 已锁定    目标公开 / 技能隐藏";
        }
        string PortGuide()
        {
            if(portShown.Outcome!="")return "战斗结束 · 点击「返回地图」继续，或按 R 重新探索。";
            if(portBusy)return "双方已锁定，按速度依次交锋；可点击「跳过演出」。";
            if(portPrepared)return "安排已锁定，点击「演示一回合」开始；需要修改请点击「调整安排」。";
            if(portCard!="")return "② 已选「"+PortContent.Card(portCard).Name+"」→ 点击敌方角色或行动格完成目标指定；Esc 取消选牌。";
            if(portShown.PlanCount>0)return "已安排 "+portShown.PlanCount+" 项行动 · 可继续选角色与技能，或点击「准备交锋」；未安排的行动待机。";
            return portHero<0?"① 点击己方角色 → ② 选择技能与目标 → ③ 准备交锋，再演示一回合。":"② 为「"+PortHeroName(portHero)+"」选择技能并指定目标；守夜对自身，定向防御需选择敌方行动。";
        }
        string PortHandPlaceholder()
        {
            if(portShown.Outcome!="")return "战斗结束 · 返回地图继续探索";
            if(portBusy)return "按速度执行行动";
            if(portPrepared)return "已准备 "+portShown.PlanCount+" 项行动，点击「演示一回合」执行。";
            if(portShown.PlanCount>0)return "已安排 "+portShown.PlanCount+" 项行动，可选择角色检查或继续安排。";
            return "① 点击己方角色 → ② 技能与目标 → ③ 准备交锋";
        }
        void DrawPortStatuses()
        {
            DrawPortStatus(new Rect(30,103,675,48),Cyan,PortAllyStatus());
            DrawPortStatus(new Rect(735,103,675,48),Red,PortEnemyStatus());
        }
        void DrawPortStatus(Rect r,Color accent,string value)
        {
            Fill(r,Color.Lerp(Hex("12202A"),accent,0.12f));Fill(new Rect(r.x,r.y,4,r.height),accent);
            Label(r.x+17,r.y+8,r.width-30,34,value,20,accent,TextAnchor.MiddleLeft);
        }
        void ArrangePortAutomatically()
        {
            if(portBusy||portPrepared||portRules.State.Outcome!="")return;
            portCard="";FillPortPlans();portShown=portRules.Snapshot();
            portNotice=portShown.PlanCount>0?"已自动安排，可继续修改；准备交锋后仍需点击演示。":"当前没有可安排的技能或费用不足。";Log(portNotice);
        }
        void DrawPortCenteredActions()
        {
            bool planning=!portBusy&&!portPrepared&&portShown.Outcome=="";
            GUI.enabled=planning;
            if(Btn(new Rect(430,566,160,38),"自动安排"))ArrangePortAutomatically();
            GUI.enabled=portShown.Outcome==""&&(CanPreparePort||portPrepared&&!portBusy);
            if(Btn(new Rect(605,566,230,38),portBusy?"交锋进行中":portPrepared?"演示一回合 · Enter":"准备交锋 · Enter",true))
            {if(portPrepared)StartPortRound();else PreparePortRound();}
            GUI.enabled=true;
            if(portBusy){if(Btn(new Rect(850,566,160,38),"跳过演出"))SkipPort();}
            else if(portPrepared){if(Btn(new Rect(850,566,160,38),"调整安排"))portPrepared=false;}
            else
            {
                GUI.enabled=planning&&portSlot>=0&&portShown.HeroSlots[portSlot].Active;
                if(Btn(new Rect(850,566,160,38),"撤销当前行动"))CancelPortSlot();GUI.enabled=true;
            }
        }
        IEnumerator GuidanceSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;speed=4;OpenPortBattle(false);
            yield return Capture(folder,"guidance-initial");
            SmokeCheck(PortAllyStatus().Contains("规划中")&&PortEnemyStatus().Contains("隐藏"),"initial guidance statuses");
            SelectPortHero(0);SelectPortCard("probe");
            SmokeCheck(PortGuide().Contains("完成目标指定")&&!CanPreparePort,"pending target guidance");
            yield return Capture(folder,"guidance-target");
            CommitPortTarget(DefaultTarget(0));int balance=portRules.State.Cost;
            ArrangePortAutomatically();
            SmokeCheck(portShown.PlanCount>0&&!portBusy&&!portPrepared&&portRules.State.Cost==balance,"auto arrange must not execute or spend");
            yield return Capture(folder,"guidance-arranged");
            string plans=portRules.State.Fingerprint();double remaining=portRules.State.Remaining;
            PreparePortRound();
            SmokeCheck(portPrepared&&portRules.State.Fingerprint()==plans&&portRules.State.Cost==balance,"ready locks without spending");
            SmokeCheck(PortHandPlaceholder().Contains("演示一回合"),"prepared empty hand must not ask for disabled character selection");
            yield return Capture(folder,"guidance-prepared");
            SmokeCheck(portRules.State.Remaining==remaining&&PortEnemyStatus().Contains("隐藏"),"prepared countdown pauses and enemy stays hidden");
            portPrepared=false;portSlot=portShown.HeroSlots.First(x=>x.Active).Id;CancelPortSlot();
            SmokeCheck(!portPrepared&&portShown.PlanCount>0&&PortAllyStatus().Contains("规划中"),"adjust and cancel restore planning status");
            ArrangePortAutomatically();PreparePortRound();StartPortRound();
            SmokeCheck(portBusy&&PortEnemyStatus().Contains("揭晓"),"resolve status reveals skills only after execution");
            yield return Capture(folder,"guidance-resolve");
            while(portBusy)yield return null;
            for(int i=0;i<24&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portShown.Outcome=="victory"&&PortAllyStatus().Contains("胜利")&&PortGuide().Contains("返回地图"),"full battle result guide");
            yield return Capture(folder,"guidance-victory");ReturnPortMap();
            SmokeCheck(portRules==null&&forestMode,"result returns to retained forest map");
            yield return Capture(folder,"guidance-forest-return");
            OpenPortBattle(false);Screen.SetResolution(1000,650,false);yield return null;yield return null;
            yield return Capture(folder,"guidance-small-initial");
            ArrangePortAutomatically();PreparePortRound();SmokeCheck(PortHandPlaceholder().Contains("演示一回合"),"small prepared view points to current available action");yield return Capture(folder,"guidance-small-prepared");
            File.WriteAllText(Path.Combine(folder,"guidance-smoke.txt"),"GUIDANCE_SMOKE_PASSED\nInitial, target, auto arrange, lock/no payment, paused clock, edit/cancel, reveal, complete victory, forest return, 1440x900 and 1000x650.\n");
            Debug.Log("GUIDANCE_SMOKE_PASSED");Application.Quit(0);
        }
    }
}
