using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class FlandreChecks
    {
        static int checks;
        static void Check(bool result,string why){checks++;if(!result)throw new Exception("Flandre: "+why);}
        static readonly Action<string,bool> Silent=(message,music)=>{};
        sealed class Heads:PortBattleRules
        {
            public Heads():base(73129,0,true){ConfigureFlandre(FlandreSkills.Create());}
            protected override bool FlipCoin(double chance){return chance>.5;}
        }
        static void Quiet(PortBattleRules battle)
        {
            battle.State.Cost=100;
            foreach(var enemy in battle.State.Enemies){enemy.Hp=1000;enemy.MaxHp=1000;}
            foreach(var slot in battle.State.EnemySlots)slot.Active=false;
        }
        public static int Run()
        {
            checks=0;
            var unit=FlandreSkills.Create();
            Check(unit.Hp==20&&unit.MinSpeed==5&&unit.MaxSpeed==7&&FlandreSkills.Cards.Length==6,"original health, speed and six deck cards");
            for(int life=1;life<=4;life++)
            {
                FlandreSkills.Receive(unit,null,100,Silent);
                FlandreSkills.Receive(unit,null,100,Silent);
                Check(unit.Hp==1&&unit.Flandre.Existence==life-1,"repeated lethal hits grant at most one life loss that round");
                FlandreSkills.EndRound(unit,Silent);
                Check(unit.Flandre.Existence==life&&unit.Hp==(life<4?20:0),"full recovery or permanent fourth retirement");
            }
            var party=new ExpeditionResources();party.ConfigureRoster(3);
            var ended=party.TrialSide();ended.Units[1]=unit;
            party.ApplyTrialSide(ended);party.RestoreTeam();
            Check(party.Hp[1]==0&&party.CreateBattle(0).State.Heroes[1].Flandre.Retired,"Eientei and a new encounter cannot revive her");
            party=new ExpeditionResources();party.ConfigureRoster(3);party.Hp[1]=10;party.Heal(7);
            Check(party.Hp[1]==13,"healing rounds half downward");
            var side=party.TrialSide();side.Units[1].Flandre.Existence=3;party.ApplyTrialSide(side);party.SelectCompanion(false);party.SelectCompanion(true);
            Check(party.CreateBattle(0).State.Heroes[1].Flandre.Existence==3&&party.Hp[1]==13,"existence and HP persist across battles and lineup swaps");

            var fighter=new Heads();Quiet(fighter);
            Check(fighter.ConfigureLoadout(new[]{"marisa_stars",FlandreSkills.Charge,FlandreSkills.Rainbow,"yin_yang_orb"}),"charge consumes one deck slot");
            Check(fighter.Assign(FlandreSkills.Charge,1,-1)&&!fighter.Assign(FlandreSkills.Rainbow,1,0),"cannot schedule attacks with charging");
            fighter.Resolve();fighter.NextRound();Quiet(fighter);
            Check(fighter.State.Hand.Contains(FlandreSkills.Release)&&!fighter.Assign(FlandreSkills.Rainbow,1,0)&&
                fighter.Assign(FlandreSkills.Release,1,-1),"release available from the chosen card on the next turn");
            var events=fighter.Resolve();
            var release=events.Single(e=>e.Type=="status_damage");
            Check(release.Hits.Select(hit=>hit.Damage).SequenceEqual(new[]{20,20})&&release.Snapshot.Enemies.All(e=>e.Hp==980)&&fighter.State.Heroes[1].Flandre.ChargeTurn==0,"release settles every target in one event");

            fighter=new Heads();Quiet(fighter);
            Check(fighter.Assign(FlandreSkills.Rainbow,1,0),"Rainbow can be equipped and aimed");
            events=fighter.Resolve();
            var rainbow=events.Where(e=>e.Type=="strike").ToArray();
            Check(rainbow.Length==2&&rainbow.All(e=>e.Hits.Length==2)&&
                rainbow.SelectMany(e=>e.Hits).GroupBy(hit=>hit.Target).All(g=>g.Sum(hit=>hit.Damage)==14),"rainbow hits both targets in each of its two rolls");
            fighter=new Heads();Quiet(fighter);fighter.Assign(FlandreSkills.Ricochet,1,0);events=fighter.Resolve();
            Check(events.Where(e=>e.Type=="strike").Sum(e=>e.Damage)==16&&events.Count(e=>e.Type=="strike")==3,"ricochet has 16 total over its original three coins");
            fighter=new Heads();Quiet(fighter);fighter.Assign(FlandreSkills.Clock,1,0);fighter.Resolve();
            Check(fighter.State.Enemies.All(e=>e.Hp==984&&e.FlandreDamageDownTurn==2),"clock deals sixteen to each and sets a one-round final damage penalty");
            fighter.NextRound();Quiet(fighter);
            var foe=fighter.State.EnemySlots[0];foe.Active=true;foe.Key="needle";foe.Target=1;
            fighter.Resolve();Check(fighter.State.Heroes[1].Hp==18,"clock reduces each incoming strike on the scheduled round");

            fighter=new Heads();Quiet(fighter);unit=fighter.State.Heroes[1];unit.Flandre.Existence=2;
            Check(fighter.Assign(FlandreSkills.Nobody,1,-1),"Nobody can be cast without a clash");
            fighter.Resolve();
            Check(unit.Hp==60&&unit.MaxHp==60&&unit.Flandre.Existence==4&&unit.Flandre.LastAct&&!unit.Flandre.Retired,"Nobody turns off revives without immediate retirement");
            fighter.NextRound();Quiet(fighter);fighter.Assign("guard",1,-1);fighter.Resolve();
            Check(unit.Hp==55,"later action spends five HP");
            fighter=new Heads();Quiet(fighter);unit=fighter.State.Heroes[1];unit.Hp=17;unit.Flandre.Existence=2;
            fighter.Assign(FlandreSkills.Ripple,1,0);
            var ripple=fighter.Resolve().Single(e=>e.Type=="strike");
            Check(unit.Hp==9&&fighter.State.Heroes[0].Hp==29&&fighter.State.Heroes[2].Hp==34&&
                fighter.State.Enemies.All(fo=>fo.Hp==984)&&ripple.Hits.Count(hit=>hit.Allied)==2&&ripple.Hits.Count(hit=>!hit.Allied)==2,
                "QED floors sacrifice and settles ally and enemy damage together");

            fighter=new Heads();Quiet(fighter);
            foreach(var foeUnit in fighter.State.Enemies)foeUnit.Hp=1;
            fighter.Assign(FlandreSkills.Rainbow,1,0);events=fighter.Resolve();
            Check(fighter.State.Outcome=="victory"&&fighter.State.Enemies.All(fo=>fo.Puppet&&fo.Hp==1)&&
                fighter.State.Heroes[1].Flandre.PuppetPower==2,"all converted enemies end the battle even while at one HP");
            unit=FlandreSkills.Create();
            int music=0;
            for(int i=0;i<5;i++)
            {
                var puppet=new Unit{Name="测试单位",Hp=1};
                FlandreSkills.Receive(puppet,unit,2,Silent);
                FlandreSkills.Receive(puppet,null,2,(line,sound)=>{if(sound)music++;});
                Check(puppet.Puppet&&!FlandreSkills.MemberCanAct(puppet)&&puppet.Hp==1,"hittable puppet never acts");
            }
            Check(unit.Flandre.PuppetPower==3&&music==5,"puppet clash power caps and each hit cues melody");

            var normal=new ForestCampaign(48,false,1,new ForestTrialOptions());
            var repeat=new ForestCampaign(48,false,1,new ForestTrialOptions());
            Check(normal.FlandreNode!=normal.RecruitNode&&normal.FlandreNode==repeat.FlandreNode&&
                normal.RecruitIdentity(normal.FlandreNode,0)=="flandre","separate reproducible randomized Scarlet Mansion recruit");
            var versus=new ForestCampaign(48,true,1,new ForestTrialOptions{TeamA=3});
            Check(versus.Players[0].Party.Roster==3&&!versus.Trial.RecruitedFlandre,"PvP selection is independent of recruiting");
            var duel=new CampaignDuel(versus.Players[0].Party.TrialSide(),versus.Players[1].Party.TrialSide(),9,20,false,0);
            Check(duel.Exclusive(0,1).SequenceEqual(FlandreSkills.Cards)&&duel.Toggle(1,FlandreSkills.Charge),"PvP exposes all six actual skills");
            duel.SetReady(0);duel.SetReady(1);
            Check(duel.Plan(1,FlandreSkills.Charge,-1),"symmetric charge planning");
            duel.SetReady(0);duel.SetReady(1);duel.NextRound();
            Check(duel.Plan(1,FlandreSkills.Release,-1)&&!duel.CanPlan(0,1,"needle",0),"PvP replacement phase and lock");
            duel.SetReady(0);duel.SetReady(1);
            Check(duel.Sides[1].Units.All(fo=>fo.Hp==fo.MaxHp-20),"same charged power applies against other players");
            return checks;
        }
    }
}
