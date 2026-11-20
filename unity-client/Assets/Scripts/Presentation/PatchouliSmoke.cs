using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator PatchouliSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            trialSkipSave=true;
            OpenTeamSetup(TeamMode.Normal,true);
            SmokeCheck(!AddTeamMember(PatchouliSkills.Id),"ordinary mode starts with Patchouli locked");
            SelectTeamMode(TeamMode.Demo);
            teamDraft[0].Clear();
            AddTeamMember(PatchouliSkills.Id);AddTeamMember("reimu");AddTeamMember(RemiliaSkills.Id);
            teamFocus=PatchouliSkills.Id;
            var portrait=FindPortrait(PatchouliSkills.Create());
            SmokeCheck(portrait!=null&&portrait.width==768&&portrait.height==1344&&portrait.GetPixel(0,0).a<.01f,
                "the supplied transparent portrait appears");
            yield return Capture(folder,"patchouli-team");
            ConfirmTeamSetup();
            InitializeForest(73129,false);
            ForestClick("n1");ForestClick("n2");
            SmokeCheck(portRules!=null&&portRules.State.Heroes[0].Patchouli!=null,"forest battle uses the selected character");
            var skills=ActorSkills(0);
            SmokeCheck(skills.SequenceEqual(PatchouliSkills.Deck),"loadout exposes the five base entries");
            skillGroups.Toggle(PatchouliSkills.Id,skills,PatchouliSkills.Sun);
            skillGroups.Toggle(PatchouliSkills.Id,skills,PatchouliSkills.Sage);
            SmokeCheck(ConfirmSkillGroups(),"Sage slot can be configured with Element and Moon");
            SelectPortHero(0);
            SelectPortCard(PatchouliSkills.Draw);
            CommitPortTarget(portRules.State.EnemySlots.First(s=>!s.Active&&PortTargetLegal(s.Id)).Id);
            SelectPortCard(PatchouliSkills.Sage);
            SmokeCheck(portRules.State.PlanCount==1&&portRules.State.HeroSlots.Any(s=>s.Active&&s.Key==PatchouliSkills.Draw),"ordinary planning cannot add a second skill in another category");
            PreparePortRound();speed=4;StartPortRound();
            while(portBusy)yield return null;
            SmokeCheck(portShown.Heroes[0].Patchouli.Main!=ElementStone.None,"first round draws a stone");
            SelectPortHero(0);
            SmokeCheck(VisiblePortCards().Any(c=>PatchouliSkills.IsElement(c.Id)),"hand shows the actual derived elemental card");
            yield return Capture(folder,"patchouli-stone");
            SelectPortCard(PatchouliSkills.Sage);
            PreparePortRound();StartPortRound();while(portBusy)yield return null;
            SmokeCheck(portShown.Heroes.Single(PatchouliSkills.IsSummon).Hp==15,"the following round summons the ally");
            SelectPortHero(0);
            SelectPortCard(PatchouliSkills.Moon);
            PreparePortRound();StartPortRound();while(portBusy)yield return null;
            SmokeCheck(log.Any(x=>x.Contains("贤者之石 · 自动施放"))&&portShown.Enemies.Any(e=>e.PatchouliMoonFrom==4&&e.PatchouliMoonUntil==5),
                "summon casts once and moon persists across the round boundary");
            yield return Capture(folder,"patchouli-moon");

            InitializeAdventure();
            drivePvpOpponent=false;
            OpenTeamSetup(TeamMode.Pvp,false);
            teamDraft[0].Clear();AddTeamMember(PatchouliSkills.Id);AddTeamMember("reimu");
            teamSeat=1;teamDraft[1].Clear();AddTeamMember("sakuya");AddTeamMember("marisa");
            ConfirmTeamSetup();InitializeForest(48);
            yield return TrialWalk(forestCampaign.Players[1].Position);
            var duel=forestCampaign.Duel;
            SmokeCheck(duel.Exclusive(0,0).Contains(PatchouliSkills.Sage)&&duel.Toggle(0,PatchouliSkills.Sage),"actual PvP deck allows Sage");
            OpenTrialPlanning(duel);
            SmokeCheck(duel.Plan(0,PatchouliSkills.Sage,-1),"ordinary PvP planning can summon");
            duel.SetReady(0);duel.SetReady(1);
            int sage=duel.Sides[0].Units.Length-1;
            SmokeCheck(duel.Sides[0].Units[sage].Hp==15,"summon present on player side");
            duel.NextRound();duel.SetReady(0);
            SmokeCheck(duel.CanPlan(1,0,"needle",sage),"opponent can target the summon");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            PickPvpActor(duel,1,0);PickPvpCard(duel,1,"needle");
            yield return Capture(folder,"patchouli-duel-small");
            duel.Plan(1,0,"needle",sage);duel.SetReady(1);
            SmokeCheck(duel.Sides[0].Units[sage].Hp<15,"normal PvP attacks hurt Sage");

            OpenTeamSetup(TeamMode.Normal,false);
            teamDraft[0].Clear();AddTeamMember("marisa");AddTeamMember("reimu");
            ConfirmTeamSetup();InitializeForest(48);
            string library=forestCampaign.PatchouliNode;
            int steps=0;
            while(forest.Position!=library&&steps++<90)
            {
                if(forest.Pending=="shop")forest.LeaveShop();
                else if(forest.Pending!="")forest.Choose(0);
                if(forest.ActionsLeft<=0)ForestEndTurn(true);
                var edge=ForestRandomGenerator.Path(forest.Map,forest.Position,library,n=>!ForestRandomGenerator.Risk(n.Kind)&&
                    n.Id!=forestCampaign.RecruitNode&&n.Id!=forestCampaign.FlandreNode&&n.Id!=forestCampaign.RemiliaNode).First();
                ForestClick(edge.Other(forest.Position));yield return null;
            }
            duel=forestCampaign.Duel;
            SmokeCheck(duel!=null&&duel.Recruitment&&duel.Sides[1].Units[0].Patchouli!=null,"actual library challenge opens");
            yield return Capture(folder,"patchouli-library-small");
            OpenTrialPlanning(duel);
            for(int round=0;round<18&&duel.Winner<0;round++)
            {
                foreach(int actor in new[]{0,1})
                    if(!duel.Plan(actor,"nova",0))duel.Plan(actor,"needle",0);
                duel.Confirm();
                if(duel.Winner<0)duel.NextRound();
                yield return null;
            }
            SmokeCheck(duel.Winner==0,"ordinary opening party can win the library challenge");
            FinishTrialBattle();
            SmokeCheck(forestCampaign.Trial.RecruitedPatchouli&&forest.Party.Members()[2].Patchouli!=null&&forest.Party.Hp[2]==40,
                "victory recruits Patchouli into the empty slot");
            File.WriteAllText(Path.Combine(folder,"patchouli-smoke.txt"),"PATCHOULI_UNITY_SMOKE_PASSED\nPortrait and lineup, actual elemental card, Sage and Moon, PvP targetable summon, library recruitment. Both window sizes and untouched unlock save.\n");
            Debug.Log("PATCHOULI_UNITY_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
