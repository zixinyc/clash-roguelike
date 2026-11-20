using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class RemiliaChecks
    {
        static int checks;
        static void Check(bool test,string message)
        {if(!test)throw new InvalidOperationException("Remilia: "+message);checks++;}

        public static int Run()
        {
            checks=0;
            var actor=RemiliaSkills.Create();
            Check(actor.Hp==35&&actor.MinSpeed==6&&actor.MaxSpeed==8,"source stats");
            Check(CharacterRoster.Skills(RemiliaSkills.Id).SequenceEqual(RemiliaSkills.Cards),"all six in exploration");
            Check(CampaignDuel.SupportedExclusive(RemiliaSkills.Id).SequenceEqual(RemiliaSkills.Cards),"all six in local PvP");
            Check(!CharacterRoster.Available(RemiliaSkills.Id,true,true,true)&&
                CharacterRoster.Available(RemiliaSkills.Id,true,false,false,true),"ordinary recruitment gate");
            actor.Remilia.Scarlet=20;
            Check(RemiliaSkills.ClashBonus(actor,RemiliaSkills.Star)==0,"only above 20 Scarlet");
            actor.Remilia.Scarlet=21;
            actor.Remilia.Overheat=1;
            Check(RemiliaSkills.ClashBonus(actor,RemiliaSkills.Star)==-1,"star plus overheat combine");
            var foes=new[]{Foe("甲"),Foe("乙"),Foe("丙"),Foe("丁")};
            RemiliaSkills.BeginRound(actor,foes,new BattleRandom(19));
            int target=actor.Remilia.LockedTarget;
            Check(target>=0&&target<foes.Length,"lock chooses a living opponent");
            var strike=new RemiliaStrike(actor,RemiliaSkills.Needles,target,foes,true);
            Check(strike.Targets.Length==3&&strike.Targets[0]==target,"needle capacity and primary target");
            var step=new CoinStep{RawDamage=16,AttackIndex=1};
            Check(strike.Raw(target,step)==22&&strike.Raw(target,step)==32,"locked clash doubles then spends one damage budget");
            Check(strike.Raw(strike.Targets[1],step)==6,"collateral is not doubled");
            strike.RecordHit(target,4);
            Check(RemiliaSkills.CompleteClash(actor,target)&&actor.Remilia.Overheat==2&&!RemiliaSkills.EndRound(actor),"clash gains heat and recent attack prevents cooling");
            RemiliaSkills.BeginRound(actor,foes,new BattleRandom(19));
            Check(RemiliaSkills.EndRound(actor)&&actor.Remilia.Overheat==1,"idle round cools once");
            Check(RemiliaSkills.CastCurse(actor,RemiliaSkills.Curse,1)&&RemiliaSkills.SpendCounter(actor,1)&&
                !RemiliaSkills.SpendCounter(actor,1)&&RemiliaSkills.SpendCounter(actor,2)&&!RemiliaSkills.SpendCounter(actor,3),"curse duration and shared counter limit");
            actor.Hp=8;actor.Remilia.Scarlet=0;
            RemiliaSkills.CompleteAttack(actor,RemiliaSkills.Shoot,4);
            Check(actor.Hp==12&&actor.Remilia.Scarlet==12,"actual HP and shoot stacks");
            actor.Remilia.Scarlet=99;
            RemiliaSkills.CompleteAttack(actor,RemiliaSkills.Star,5);
            Check(actor.Remilia.Scarlet==100,"scarlet cap");
            actor.Remilia.Overheat=0;actor.Remilia.Scarlet=41;
            strike=new RemiliaStrike(actor,RemiliaSkills.Fantasy,0,foes,false);
            Check(strike.Raw(0,step)==36,"fantasy extra damage rounds down");
            strike.Finish(foes);
            Check(actor.Remilia.Scarlet==0,"fantasy clears stacks");

            var duel=new CampaignDuel(new TrialDuelSide(new[]{RemiliaSkills.Create()},40),new TrialDuelSide(foes,40),19,20,false,0);
            Check(duel.Toggle(0,RemiliaSkills.Curse)&&duel.Toggle(0,RemiliaSkills.Magic),"choose actual duel cards");
            duel.SetReady(0);duel.SetReady(1);
            Check(duel.Plan(0,RemiliaSkills.Curse,0),"curse can target and be planned");
            duel.SetReady(0);
            Check(duel.Plan(1,1,"needle",0)&&duel.Plan(1,2,"needle",0),"several opponents can attack");
            duel.SetReady(1);
            Check(duel.Log.Count(x=>x.Contains("诅咒反击 · 大卫之星"))==1&&duel.Sides[0].Units[0].Remilia.Scarlet>0,"duel resolves a single genuine counter and lifesteal");
            duel.NextRound();
            Check(duel.Plan(0,RemiliaSkills.Magic,0),"red magic can be planned");
            duel.SetReady(0);duel.SetReady(1);
            Check(duel.Sides[1].Units.Take(2).All(u=>u.PendingRedMist==2)&&duel.Sides[1].Units.Skip(2).All(u=>u.PendingRedMist==0),"red magic actually hits exactly two opponents");
            duel.NextRound();
            Check(duel.Sides[1].Units.Take(2).All(u=>u.RedMist==2)&&duel.Speed(1,0)==1,"mist applies next round and respects minimum speed");

            var port=new PortBattleRules(19,0,CharacterRoster.Compose(new[]{RemiliaSkills.Id,"reimu"}));
            var initial=port.State.Heroes[0];
            Check(port.State.Owns(0,PortContent.Card(RemiliaSkills.Curse))&&initial.Remilia.LockedTarget>=0,"ordinary battle equips the character and selects a lock");
            foreach(var e in port.State.EnemySlots){e.Active=false;}
            Check(port.Assign(RemiliaSkills.Magic,0,0),"red magic uses ordinary skill planning");
            var events=port.Resolve();
            Check(events.Any(e=>e.Hits!=null&&e.Hits.Length==2)&&port.State.Enemies.All(u=>u.PendingRedMist==2||u.Hp==0),
                "ordinary battle resolves multi-hit and mist");
            var party=new ExpeditionResources();
            party.ConfigureTeam(new[]{"marisa",RemiliaSkills.Id});
            var result=party.TrialSide();
            var member=result.Units[1];
            result.Cost=10;
            Check(RemiliaSkills.PreventDefeat(member,member.Hp,ref result.Cost)&&member.Hp==1&&result.Cost==0,"lethal damage saves once and consumes ten cost");
            party.ApplyTrialSide(result);
            Check(party.CreateBattle(0).State.Heroes[1].Remilia.SavedFromDefeat&&party.TrialSide().Units[1].Remilia.SavedFromDefeat,"survival use persists across encounter engines");

            for(int seed=0;seed<48;seed++)
            {
                var game=new ForestCampaign(seed,false,1,new ForestTrialOptions{CompositionA=new[]{"marisa","reimu"}});
                Check(game.RemiliaNode!=null&&game.RemiliaNode!=game.RecruitNode&&game.RemiliaNode!=game.FlandreNode&&
                    game.RecruitIdentity(game.RemiliaNode,0)==RemiliaSkills.Id&&game.RecruitIdentity(game.RemiliaNode,1)=="",
                    "the main hall has its own encounter in seed "+seed);
            }
            return checks;
        }

        static Unit Foe(string name)
        {return new Unit{Name=name,Hp=120,MaxHp=120,MinSpeed=2,MaxSpeed=2};}
    }
}
