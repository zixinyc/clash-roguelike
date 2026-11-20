using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator RemiliaReleaseSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            trialSkipSave=true;
            OpenTeamSetup(TeamMode.Normal,true);
            SmokeCheck(!AddTeamMember(RemiliaSkills.Id),"ordinary mode locks Remilia before the challenge");
            SelectTeamMode(TeamMode.Demo);
            teamDraft[0].Clear();
            AddTeamMember("marisa");AddTeamMember(RemiliaSkills.Id);AddTeamMember("flandre");
            teamFocus=RemiliaSkills.Id;
            var portrait=FindPortrait(RemiliaSkills.Create());
            SmokeCheck(portrait!=null&&portrait.GetPixel(0,0).a<.01f&&portrait.mipmapCount>1,"Remilia's transparent portrait loads");
            yield return Capture(folder,"remilia-team");
            ConfirmTeamSetup();
            InitializeForest(73129,false);
            ForestClick("n1");ForestClick("n2");
            SmokeCheck(fromMap&&portRules.State.Heroes[1].CharacterId==RemiliaSkills.Id&&
                ActorSkills(1).SequenceEqual(RemiliaSkills.Cards),"field encounter shows all six spells");
            var available=ActorSkills(1);
            skillGroups.Toggle(RemiliaSkills.Id,available,RemiliaSkills.Needles);
            skillGroups.Toggle(RemiliaSkills.Id,available,RemiliaSkills.Magic);
            SmokeCheck(ConfirmSkillGroups(),"configured Remilia deck locks");
            SelectPortHero(1);
            SelectPortCard(RemiliaSkills.Magic);
            CommitPortTarget(portRules.State.EnemySlots.First(slot=>!slot.Active&&PortTargetLegal(slot.Id)).Id);
            SmokeCheck(portRules.State.PlanCount==1,"normal UI plans Red Magic");
            yield return Capture(folder,"remilia-plan");
            PreparePortRound();speed=4;StartPortRound();
            while(portBusy)yield return null;
            SmokeCheck(portShown.Enemies.Any(enemy=>enemy.RedMist==2||enemy.PendingRedMist==2||enemy.Hp==0),
                "an actual exploration round applied red mist");
            yield return Capture(folder,"remilia-combat");

            InitializeAdventure();
            drivePvpOpponent=false;
            OpenTeamSetup(TeamMode.Pvp,false);
            teamDraft[0].Clear();AddTeamMember(RemiliaSkills.Id);AddTeamMember("reimu");
            teamSeat=1;teamDraft[1].Clear();AddTeamMember("flandre");AddTeamMember("marisa");
            ConfirmTeamSetup();
            InitializeForest(48);
            yield return TrialWalk(forestCampaign.Players[1].Position);
            var duel=forestCampaign.Duel;
            SmokeCheck(duel.Sides[0].Units[0].Remilia!=null&&duel.Exclusive(0,0).Length==6&&
                duel.Toggle(0,RemiliaSkills.Curse),"same-tile local PvP offers Remilia's full pool");
            Screen.SetResolution(1000,650,false);
            yield return null;yield return null;
            yield return Capture(folder,"remilia-pvp-small");

            OpenTeamSetup(TeamMode.Normal,false);
            teamDraft[0].Clear();AddTeamMember("marisa");AddTeamMember("reimu");
            ConfirmTeamSetup();
            InitializeForest(48);
            yield return TrialWalk(forestCampaign.RemiliaNode);
            duel=forestCampaign.Duel;
            SmokeCheck(duel.Recruitment&&duel.Sides[1].Units[0].Remilia!=null,"main hall actually opens Remilia's challenge");
            yield return Capture(folder,"remilia-challenge-small");
            OpenTrialPlanning(duel);
            for(int round=0;round<20&&duel.Winner<0;round++)
            {
                foreach(int actor in new[]{0,1})
                    if(!duel.Plan(actor,"nova",0))duel.Plan(actor,"needle",0);
                duel.Confirm();
                if(duel.Winner<0)duel.NextRound();
                yield return null;
            }
            SmokeCheck(duel.Winner==0,"the default pair wins the interactable Remilia challenge");
            FinishTrialBattle();
            SmokeCheck(forestCampaign.Trial.RecruitedRemilia&&forest.Party.Members()[2].Remilia!=null&&forest.Party.Hp[2]==35,
                "winning unlocks and fills the open party slot");
            yield return Capture(folder,"remilia-recruited-small");
            File.WriteAllText(Path.Combine(folder,"remilia-release-smoke.txt"),
                "REMILIA_RELEASE_SMOKE_PASSED\nMixing and portrait, six spells, actual red mist, local PvP deck, main hall victory and recruitment. Both window sizes. Save data untouched.\n");
            Debug.Log("REMILIA_RELEASE_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
