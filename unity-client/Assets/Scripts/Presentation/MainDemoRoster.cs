using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        bool forestRosterMenu;
        static string MainRosterName(int roster){return roster==1?"东方三人队":roster==2?"ZiXi队":"原小队";}
        void OpenMainRosterPicker(){forestSettings=true;forestRosterMenu=true;}
        void StartMainRoster(int roster)
        {if(roster<0||roster>2)return;selectedRoster=roster;InitializeAdventure();}
        void DrawMainRosterPicker()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.82f));Panel(new Rect(405,200,630,500),Hex("12202A"),Gold);
            Label(435,224,570,44,"选择探索队伍",28,Gold);
            Label(435,275,570,52,"同一主地图、战斗与资源流程。选择队伍将开始新探索，当前进度会重置。",15,Pale);
            int[] rosters={1,2,0};
            for(int i=0;i<rosters.Length;i++)
            {
                int roster=rosters[i];float y=344+i*86;var team=CharacterRoster.Team(roster);
                string names=string.Join(" · ",team.Select(u=>u.Name).ToArray());
                if(Btn(new Rect(435,y,570,43),MainRosterName(roster)+" / 开始新探索",selectedRoster==roster)){StartMainRoster(roster);return;}
                Label(445,y+47,550,25,names+"  |  HP "+string.Join(" / ",team.Select(u=>u.MaxHp.ToString()).ToArray()),13,Muted);
            }
            if(Btn(new Rect(435,622,570,42),"保留当前探索 · 返回")){forestSettings=false;forestRosterMenu=false;}
        }
        IEnumerator MainRosterSmoke(string folder)
        {
            Directory.CreateDirectory(folder);while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            var reports=new System.Collections.Generic.List<string>();speed=4;
            OpenMainRosterPicker();yield return Capture(folder,"main-roster-picker");forestSettings=false;forestRosterMenu=false;
            foreach(int roster in new[]{1,2,0})
            {
                StartMainRoster(roster);var team=CharacterRoster.Team(roster);var names=team.Select(u=>u.Name).ToArray();
                SmokeCheck(forest.Party.Roster==roster&&heroNames.SequenceEqual(names)&&forest.Party.MaxHp.SequenceEqual(team.Select(u=>u.MaxHp)),"main forest roster and real party data");
                yield return Capture(folder,"main-roster-"+roster+"-forest");
                ForestClick("n1");ForestClick("n2");
                SmokeCheck(fromMap&&forest.InBattle&&portRules.State.Heroes.Select(u=>u.Name).SequenceEqual(names),"actual map encounter preserves roster");
                for(int actor=0;actor<3;actor++){SelectPortHero(actor);int expected=roster==1||roster==2&&actor==1?4:actor==0?4:3;SmokeCheck(VisiblePortCards().Length==expected,"main demo displays each member's original exclusive hand");yield return Capture(folder,"main-roster-"+roster+"-hero-"+actor);}
                int rounds=0;while(portRules.State.Outcome==""&&rounds++<24){FillPortPlans();SmokeCheck(portRules.State.PlanCount>0,"main demo can arrange real actions");PreparePortRound();StartPortRound();while(portBusy)yield return null;}
                SmokeCheck(portRules.State.Outcome!="","main roster encounter terminates");
                string result=portRules.State.Outcome;int wallet=portRules.State.Cost+(result=="victory"?4:0);var hp=portRules.State.Heroes.Select(u=>u.Hp).ToArray();
                ReturnPortMap();SmokeCheck(portRules==null&&!forest.InBattle&&forest.Party.Hp.SequenceEqual(hp)&&forest.Party.Cost==wallet&&forest.Party.Roster==roster,"actual battle return preserves HP wallet and roster");
                reports.Add(MainRosterName(roster)+": "+string.Join(" / ",names)+"; result="+result+"; map HP/cost return verified");yield return Capture(folder,"main-roster-"+roster+"-return");
            }
            StartMainRoster(2);Screen.SetResolution(1000,650,false);yield return null;yield return null;OpenMainRosterPicker();yield return Capture(folder,"main-roster-picker-small");
            forestSettings=false;forestRosterMenu=false;yield return Capture(folder,"main-zixi-small");
            File.WriteAllLines(Path.Combine(folder,"main-roster-smoke.txt"),new[]{"UNITY_MAIN_ROSTER_SMOKE_PASSED","Original HP, cost, enemies and seeded RNG; no combat fixture overrides. All teams entered normal forest encounters and returned real results.",string.Join("\n",reports.ToArray()),"1440x900 / 1000x650 real player captures. Automated UI handlers; physical mouse acceptance not claimed."});Application.Quit(0);
        }
    }
}
