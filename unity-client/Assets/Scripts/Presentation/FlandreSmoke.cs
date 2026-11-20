using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        IEnumerator FlandreSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;
            forestTrialMode=false;StartMainRoster(3);speed=4;
            SmokeCheck(forest.Party.MaxHp.SequenceEqual(new[]{45,20,50}),"actual four-preset roster has Flandre");
            OpenPortBattle(false,0,true);
            SmokeCheck(ActorSkills(1).SequenceEqual(FlandreSkills.Cards),"six Flandre spells are present in actual preparation");
            yield return Capture(folder,"flandre-loadout");
            SmokeCheck(ConfirmSkillGroups(),"default group can carry the charge card");
            var portrait=FindPortrait(portShown.Heroes[1]);
            SmokeCheck(portrait!=null&&portrait.width==768&&portrait.height==1344&&
                portrait.GetPixel(0,0).a<.01f&&portrait.mipmapCount>1,"Flandre loads the transparent battle portrait");
            SelectPortHero(1);
            SelectPortCard(FlandreSkills.Charge);
            SmokeCheck(portRules.State.PlanCount==1,"charge self-target registers without clicking an enemy");
            PreparePortRound();StartPortRound();while(portBusy)yield return null;
            SmokeCheck(portShown.Hand.Contains(FlandreSkills.Release)&&portShown.Heroes[1].Flandre.ChargeTurn==1&&
                portShown.Turn==2,"second-stage card is ready in the actual battle");
            SelectPortHero(1);
            yield return Capture(folder,"flandre-charge");
            SelectPortCard(FlandreSkills.Release);
            PreparePortRound();speed=1;StartPortRound();
            bool releaseShown=false;
            while(portBusy)
            {
                if(!releaseShown&&portEvent!=null&&portEvent.Hits!=null&&portPhase>.45f)
                {
                    releaseShown=true;
                    SmokeCheck(portEvent.Hits.Length==2&&portEvent.Hits.All(hit=>DuelParticipant(hit.Allied,hit.Target)),
                        "the single release animation includes both targets");
                    yield return Capture(folder,"flandre-release-impact");
                }
                yield return null;
            }
            SmokeCheck(releaseShown&&portShown.Heroes[1].Flandre.ChargeTurn==0&&log.Any(line=>line.Contains("莱万汀释放")),"release resolved and logged in battle");
            yield return Capture(folder,"flandre-release");

            OpenPortBattle(false,0,true);
            SmokeCheck(ConfirmSkillGroups(),"clash groups confirmed");
            SelectPortHero(1);
            SelectPortCard(FlandreSkills.Rainbow);
            var action=portRules.State.HeroSlots[portSlot];
            var clashTarget=portRules.State.EnemySlots.First(slot=>PortTargetLegal(slot.Id)&&portRules.CanClash(action,slot));
            CommitPortTarget(clashTarget.Id);
            SmokeCheck(portRules.PairFor(clashTarget.Id)>=0,"Flandre assigned to an opposed action");
            PreparePortRound();speed=1;StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Type!="clash"||portEvent.Hero!=1||portPhase<.45f))yield return null;
            SmokeCheck(DuelParticipant(true,1)&&ShownCombatX(true,1)!=CombatX(true,1),"Flandre moves with the real clash playback");
            yield return Capture(folder,"flandre-portrait-clash");
            SkipPort();while(portBusy)yield return null;

            trialSkipSave=true;forestTrialMode=true;forestPvpMode=false;selectedRoster=1;InitializeAdventure();InitializeForest(48);
            string target=forestCampaign.FlandreNode;
            int steps=0;
            while(forest.Position!=target&&steps++<90)
            {
                if(forest.Pending=="shop")forest.LeaveShop();
                else if(forest.Pending!="")forest.Choose(0);
                if(forest.ActionsLeft<=0)ForestEndTurn(true);
                var next=ForestRandomGenerator.Path(forest.Map,forest.Position,target,n=>!ForestRandomGenerator.Risk(n.Kind)&&
                    n.Id!=forestCampaign.RecruitNode).First();
                ForestClick(next.Other(forest.Position));
                yield return null;
            }
            var duel=forestCampaign.Duel;
            SmokeCheck(duel!=null&&duel.Recruitment&&duel.Sides[1].Units[0].Flandre!=null,"walking into a seeded red mansion encounter starts Flandre's actual challenge");
            yield return Capture(folder,"flandre-challenge");
            duel.Confirm();
            for(int round=0;round<14&&duel.Winner<0;round++)
            {
                foreach(int actor in new[]{0,2})
                    if(!duel.Plan(actor,"nova",0))duel.Plan(actor,"needle",0);
                duel.Confirm();
                if(duel.Winner<0)duel.NextRound();
                yield return null;
            }
            SmokeCheck(duel.Winner==0&&duel.Sides[1].Units[0].Flandre.Existence==4,"ordinary two-member party wins after the fourth protected life");
            yield return Capture(folder,"flandre-recruit-victory");
            FinishTrialBattle();
            SmokeCheck(forestCampaign.Trial.RecruitedFlandre&&forest.Party.Roster==3&&forest.Party.Hp[1]==20,"victory joins her with a fresh run-state");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            yield return Capture(folder,"flandre-party-small");
            File.WriteAllText(Path.Combine(folder,"flandre-smoke.txt"),"FLANDRE_UNITY_SMOKE_PASSED\nVerified the transparent portrait, its actual clash animation, six cards, charge and release, and a four-life Scarlet Mansion victory and recruitment. Smoke did not change persistent unlock data.\n");
            Debug.Log("FLANDRE_UNITY_SMOKE_PASSED");
            Application.Quit(0);
        }
    }
}
