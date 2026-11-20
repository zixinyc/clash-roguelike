using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {

        static string MainRosterName(int roster){return roster==3?"芙兰朵露队":roster==1?"东方三人队":roster==2?"ZiXi队":"原小队";}
        void OpenMainRosterPicker(){OpenTeamSetup(TrialActive?(forestCampaign.Pvp?TeamMode.Pvp:TeamMode.Normal):TeamMode.Demo,false);}
        void StartMainRoster(int roster)
        {if(roster<0||roster>3)return;teamSetup=false;activeTeam=null;activeRivalTeam=null;selectedRoster=roster;InitializeAdventure();}
        IEnumerator MainRosterSmoke(string folder)
        {
            Directory.CreateDirectory(folder);while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            var reports=new System.Collections.Generic.List<string>();speed=4;
            OpenMainRosterPicker();yield return Capture(folder,"main-roster-picker");forestSettings=false;teamSetup=false;
            foreach(int roster in new[]{1,2,0})
            {
                StartMainRoster(roster);InitializeForest(73129,false);var team=CharacterRoster.Team(roster);var names=team.Select(u=>u.Name).ToArray();
                SmokeCheck(forest.Party.Roster==roster&&heroNames.SequenceEqual(names)&&forest.Party.MaxHp.SequenceEqual(team.Select(u=>u.MaxHp)),"main forest roster and real party data");
                yield return Capture(folder,"main-roster-"+roster+"-forest");
                ForestClick("n1");ForestClick("n2");
                SmokeCheck(fromMap&&forest.InBattle&&portRules.State.Heroes.Select(u=>u.Name).SequenceEqual(names),"actual map encounter preserves roster");
                for(int actor=0;actor<3;actor++){SelectPortHero(actor);int expected=CharacterRoster.Skills(team[actor].CharacterId).Length;SmokeCheck(VisiblePortCards().Length==expected,"main demo displays each member's original exclusive hand");yield return Capture(folder,"main-roster-"+roster+"-hero-"+actor);}
                SmokeCheck(ConfirmSkillGroups(),"legacy preset can lock the current loadout");
                int rounds=0;while(portRules.State.Outcome==""&&rounds++<24){FillPortPlans();SmokeCheck(portRules.State.PlanCount>0,"main demo can arrange real actions");PreparePortRound();StartPortRound();while(portBusy)yield return null;}
                SmokeCheck(portRules.State.Outcome!="","main roster encounter terminates");
                string result=portRules.State.Outcome;int wallet=portRules.State.Cost+(result=="victory"?4:0);var hp=portRules.State.Heroes.Select(u=>u.Hp).ToArray();
                ReturnPortMap();SmokeCheck(portRules==null&&!forest.InBattle&&forest.Party.Hp.SequenceEqual(hp)&&forest.Party.Cost==wallet&&forest.Party.Roster==roster,"actual battle return preserves HP wallet and roster");
                reports.Add(MainRosterName(roster)+": "+string.Join(" / ",names)+"; result="+result+"; map HP/cost return verified");yield return Capture(folder,"main-roster-"+roster+"-return");
            }
            StartMainRoster(2);Screen.SetResolution(1000,650,false);yield return null;yield return null;OpenMainRosterPicker();yield return Capture(folder,"main-roster-picker-small");
            forestSettings=false;teamSetup=false;yield return Capture(folder,"main-zixi-small");
            File.WriteAllLines(Path.Combine(folder,"main-roster-smoke.txt"),new[]{"UNITY_MAIN_ROSTER_SMOKE_PASSED","Original HP, cost, enemies and seeded RNG; no combat fixture overrides. All teams entered normal forest encounters and returned real results.",string.Join("\n",reports.ToArray()),"1440x900 / 1000x650 real player captures. Automated UI handlers; physical mouse acceptance not claimed."});Application.Quit(0);
        }
    }
}
