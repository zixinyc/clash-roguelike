using System;
using System.IO;
using System.Linq;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        sealed class TouhouSmokeHeads:PortBattleRules
        {public TouhouSmokeHeads():base(73129,0,true){}protected override bool FlipCoin(double chance){return chance>.5;}}
        IEnumerator TouhouDamagePlaybackSmoke(string folder)
        {
            OpenPortBattle(false,0,true);portRules=new TouhouSmokeHeads();
            foreach(var enemy in portRules.State.Enemies){enemy.Hp=1000;enemy.MaxHp=1000;}
            foreach(var slot in portRules.State.EnemySlots)slot.Active=false;
            BeginSkillGroupSelection();ConfirmSkillGroups();SelectPortHero(2);SelectPortCard("fantasy_seal");CommitPortTarget(0);
            SmokeCheck(portShown.PlanCount==1,"dream skill assigned through actual UI handlers");
            PreparePortRound();speed=1;StartPortRound();PortEvent previous=null;int hits=0,total=0;bool capturedFirst=false,capturedLast=false;
            var rows=new System.Collections.Generic.List<string>();
            while(portBusy)
            {
                var ev=portEvent;
                if(ev!=null&&ev!=previous)
                {
                    previous=ev;if(ev.Type=="strike")
                    {
                        hits++;int raw=hits==1?4:3;total+=raw;
                        SmokeCheck(ev.Coin.RawDamage==raw&&ev.Damage==raw&&portShown.Enemies[0].Hp==1000-total,"fantasy seal shows original per-coin distribution and real HP");
                        rows.Add("hit="+hits+" raw="+ev.Coin.RawDamage+" damage="+ev.Damage+" hp="+portShown.Enemies[0].Hp+" accumulated="+ev.Coin.AttackAccumulated);
                    }
                }
                if(ev!=null&&ev.Type=="strike"&&portPhase>.6f)
                {
                    if(hits==1&&!capturedFirst){capturedFirst=true;yield return Capture(folder,"dream-first-hit");}
                    if(hits==5&&!capturedLast){capturedLast=true;yield return Capture(folder,"dream-fifth-hit");}
                }
                yield return null;
            }
            SmokeCheck(hits==5&&total==16&&capturedFirst&&capturedLast,"all five skill strikes render and total sixteen");
            File.WriteAllText(Path.Combine(folder,"dream-playback.txt"),"Controlled all-heads rendering fixture; enemies have 1000 HP and no plans.\n"+string.Join("\n",rows.ToArray()));
        }
        IEnumerator TouhouSmoke(string folder)
        {
            Directory.CreateDirectory(folder);int roleChecks=TouhouChecks.Run();while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;yield return null;yield return null;
            OpenPortBattle(false,0,true);SmokeCheck(Enumerable.Range(0,3).All(actor=>ActorSkills(actor).Length==6),"all six exclusive cards per character appear in preparation");yield return Capture(folder,"touhou-six-card-pools");
            for(int actor=0;actor<3;actor++)
            {
                var available=ActorSkills(actor);string key=CharacterKey(actor);
                SmokeCheck(skillGroups.Toggle(key,available,available[0])&&skillGroups.Toggle(key,available,available[1])&&
                    skillGroups.Toggle(key,available,available[4])&&skillGroups.Toggle(key,available,available[5]),"both revised cards can enter a four-card group");
            }
            SmokeCheck(ConfirmSkillGroups()&&Enumerable.Range(0,3).All(actor=>ActorSkills(actor).Skip(4).All(portShown.Hand.Contains)),"the actual equipped hand includes all six newly selectable cards");
            for(int actor=0;actor<3;actor++)skillGroups.Reset(CharacterKey(actor),ActorSkills(actor));
            yield return TouhouDamagePlaybackSmoke(folder);
            OpenPortBattle(false,0,true);ConfirmSkillGroups();SmokeCheck(portShown.Heroes[1].Hp==40&&portShown.Heroes[2].Hp==50&&portRules.State.Hand.Length==18,"actual test roster source data");yield return Capture(folder,"touhou-roster");
            SelectPortHero(1);SmokeCheck(VisiblePortCards().Length==4,"Sakuya personal cards visible");yield return Capture(folder,"touhou-sakuya-cards");
            SelectPortHero(2);SmokeCheck(VisiblePortCards().Length==4,"Reimu personal cards visible");SelectPortCard("demon_seal");SmokeCheck(portCard=="demon_seal"&&portSlot==8,"targeted guard waits for legal enemy target");yield return Capture(folder,"touhou-reimu-targeted");
            OpenPortBattle(false);ConfirmSkillGroups();SmokeCheck(portRules.State.Hand.Length==16&&portShown.Heroes[1].Name=="长锋","switch restores old team");
            OpenPortBattle(false,0,true);ConfirmSkillGroups();SelectPortHero(1);SelectPortCard("the_world");CommitPortTarget(2);PreparePortRound();speed=4;StartPortRound();while(portBusy)yield return null;
            SmokeCheck(portRules.State.WorldActive&&portShown.EnemySlots.All(x=>!x.Active),"actual World cast starts stopped round");yield return Capture(folder,"touhou-world");
            SelectPortHero(0);SmokeCheck(portHero==-1,"frozen actor cannot be selected");SelectPortHero(1);SelectPortCard("murder_doll");CommitPortTarget(0);SelectPortCard("murder_doll");CommitPortTarget(3);SelectPortCard("murder_doll");CommitPortTarget(0);
            SmokeCheck(portShown.PlanCount==3&&portShown.HeroSlots.Count(x=>x.Active&&x.Unit==1)==3,"three independent repeated World skills");yield return Capture(folder,"touhou-world-planned");
            PreparePortRound();speed=1;StartPortRound();PortEvent previous=null;int skillEnds=0,coinStrikes=0;bool captured=false;
            while(portBusy)
            {
                var e=portEvent;if(e!=null&&e!=previous){previous=e;if(e.Type=="attack_end")skillEnds++;if(e.Type=="strike"){coinStrikes++;SmokeCheck(e.Coin.AttackIndex+e.Coin.RemainingAttackCoins==e.Coin.AttackBudget,"actual World coin budgets");}}
                if(!captured&&e!=null&&e.Type=="strike"&&portPhase>.55f&&coinStrikes==1){captured=true;yield return Capture(folder,"touhou-world-coin");}
                yield return null;
            }
            SmokeCheck(skillEnds==3&&coinStrikes==3&&!portRules.State.WorldActive,"World executes three separate one-coin skills and expires");speed=4;
            for(int i=0;i<20&&portRules.State.Outcome=="";i++){AutoPortPlan();while(portBusy)yield return null;}
            SmokeCheck(portRules.State.Outcome=="victory","actual Touhou roster complete battle victory");yield return Capture(folder,"touhou-victory");
            OpenPortBattle(false,0,true);ConfirmSkillGroups();SelectPortHero(2);SelectPortCard("fantasy_nature");var target=portRules.State.EnemySlots.First(x=>PortTargetLegal(x.Id)).Id;CommitPortTarget(target);PreparePortRound();StartPortRound();while(portBusy)yield return null;
            SmokeCheck(portShown.Heroes[2].RoleState.DreamDue==4&&portShown.Heroes[2].RoleState.DreamOrbs==1,"actual Dream cast arms status without fixture data");SelectPortHero(2);yield return Capture(folder,"touhou-dream-armed");
            Screen.SetResolution(1000,650,false);yield return null;yield return null;yield return Capture(folder,"touhou-small");
            File.WriteAllText(Path.Combine(folder,"touhou-smoke.txt"),"TOUHOU_UNITY_SMOKE_PASSED\nRole model assertions: "+roleChecks+"\nActual six-card pools and equipment across all three heroes, targeted defense, roster switch, three World actions, victory and Dream activation. Five controlled all-heads strikes total 16 and share the actual HP changes. Actual frames at 1440x900 and 1000x650.\n");Debug.Log("TOUHOU_UNITY_SMOKE_PASSED");Application.Quit(0);
        }
    }
}


