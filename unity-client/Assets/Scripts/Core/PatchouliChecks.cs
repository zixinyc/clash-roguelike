using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class PatchouliChecks
    {
        static int checks;
        static void Check(bool ok,string message)
        {if(!ok)throw new InvalidOperationException("Patchouli: "+message);checks++;}

        sealed class Tails : PortBattleRules
        {
            public Tails():base(31,0,CharacterRoster.Compose(new[]{PatchouliSkills.Id,"reimu"})){}
            protected override bool FlipCoin(double chance){return false;}
        }

        public static int Run()
        {
            checks=0;
            var unit=PatchouliSkills.Create();
            Check(unit.Hp==40&&unit.MinSpeed==3&&unit.MaxSpeed==5,"original stats");
            var rng=new BattleRandom(123);
            PatchouliSkills.DrawStone(unit,rng);
            Check(unit.Patchouli.Main!=ElementStone.None&&unit.Patchouli.Off==ElementStone.None,"first roll fills only the main hand");
            PatchouliSkills.DrawStone(unit,rng);
            var previousOff=unit.Patchouli.Off;
            PatchouliSkills.DrawStone(unit,rng);
            Check(previousOff!=ElementStone.None&&unit.Patchouli.Main==previousOff,"third roll advances the off hand");
            unit.Patchouli.Main=ElementStone.Fire;unit.Patchouli.Off=ElementStone.Water;
            var card=PortContent.Card(PatchouliSkills.EquippedKey(unit,PatchouliSkills.Element));
            Check(card.Cost==1&&card.Coins==3&&card.Name.Contains("火·水")&&PatchouliSkills.Has(unit,ElementStone.Water),"derived water offhand price");
            string earthMetal=PatchouliSkills.Variant(ElementStone.Earth,ElementStone.Metal);
            string earthGold=PatchouliSkills.Variant(ElementStone.Metal,ElementStone.Earth);
            Check(PortContent.Card(earthMetal).AttackCoinPower==13&&PortContent.Card(earthMetal).ClashCoinPower==12&&
                PortContent.Card(earthGold).ClashCoinPower==7&&PortContent.Card(earthGold).AttackCoinPower==6,"coin bonuses stay independent");
            var foes=new[]{Enemy("甲"),Enemy("乙"),Enemy("丙")};
            unit.Patchouli.Off=ElementStone.Wood;
            var fire=new PatchouliStrike(unit,PatchouliSkills.EquippedKey(unit,PatchouliSkills.Element),0,foes);
            Check(fire.Targets.Length==3,"wood stone raises the natural fire capacity of two");
            var earth=new PatchouliStrike(unit,PatchouliSkills.Variant(ElementStone.Earth,ElementStone.Fire),0,foes);
            Check(earth.Raw(new CoinStep{RawDamage=5})==23,"earth multiplication and ceil fire bonus");
            var fireCard=new PatchouliStrike(unit,PatchouliSkills.Variant(ElementStone.Fire,ElementStone.None),0,foes);
            fireCard.OnHit(foes[0]);PatchouliSkills.StartRound(foes[0]);
            Check(foes[0].PatchouliBurn==5,"fire stages real next-round burn");
            Check(PatchouliSkills.Evades(unit,5)&&!PatchouliSkills.Evades(unit,6),"evasion threshold 5");
            unit.Hp=20;
            PatchouliSkills.Utility(unit,PatchouliSkills.Variant(ElementStone.Water,ElementStone.Fire),1,null,new[]{unit},foes,log=>{});
            Check(unit.Hp==35&&PatchouliSkills.Asthma(unit)==2&&unit.Hp==33,"fire-enhanced water healing and asthma");
            PatchouliSkills.Utility(unit,PatchouliSkills.Moon,1,null,new[]{unit},foes,log=>{});
            Check(PatchouliSkills.Speed(foes[0],7,1)==7&&PatchouliSkills.Speed(foes[0],7,2)==4&&
                PatchouliSkills.Speed(foes[0],5,3)==3&&PatchouliSkills.Speed(foes[0],7,4)==7,"moon lasts exactly two following rounds");

            var port=new Tails();
            var actor=port.State.Heroes[0];
            foreach(var enemy in port.State.EnemySlots)enemy.Active=false;
            var first=port.State.EnemySlots[0];first.Active=true;first.Target=0;first.Key="nova";
            Check(port.Assign(PatchouliSkills.Draw,0,0),"stone draw plans a real clash");
            var events=port.Resolve();
            Check(events.Any(e=>e.Type=="clash_end"&&e.Coin.FinalWinner==1)&&actor.Patchouli.Main!=ElementStone.None,"draws even after losing a genuine clash");
            port.NextRound();
            Check(port.State.Owns(0,PortContent.Card(PatchouliSkills.EquippedKey(actor,PatchouliSkills.Element))),"derived card remains owned");
            Check(port.Assign(PatchouliSkills.Sage,0,-1),"ordinary battle plans Sage without enemy");
            port.Resolve();
            var sage=port.State.Heroes.Single(PatchouliSkills.IsSummon);
            Check(sage.MaxHp==15&&sage.SageReadyTurn==3&&sage.Hp==15,"actual summoned unit with delayed activation");
            port.NextRound();
            Check(!port.Assign(PatchouliSkills.Sage,0,-1)&&!port.Assign("needle",3,0),"one living summon and no manual control");
            foreach(var enemy in port.State.EnemySlots)enemy.Active=false;
            Check(port.Resolve().Count(e=>e.Message.Contains("贤者之石 · 自动施放"))==1,"ordinary sage acts once");
            var resources=new ExpeditionResources();
            resources.ConfigureTeam(new[]{PatchouliSkills.Id,"reimu"});
            resources.ApplyMembers(port.State.Heroes);
            Check(resources.Hp.Length==3&&resources.TrialSide().Units.Single(PatchouliSkills.IsSummon).Hp==0,"no summoned unit leaks onto map");

            var duel=new CampaignDuel(new TrialDuelSide(new[]{PatchouliSkills.Create()},60),new TrialDuelSide(new[]{Enemy("敌方")},40),31,20,false,0);
            Check(duel.Toggle(0,PatchouliSkills.Sage)&&duel.Toggle(0,PatchouliSkills.Draw),"local PvP equips spell and summon");
            duel.SetReady(0);duel.SetReady(1);
            Check(duel.Plan(0,PatchouliSkills.Sage,-1),"local PvP summons using the no-target action");
            duel.SetReady(0);duel.SetReady(1);
            var stone=duel.Sides[0].Units[1];
            Check(stone.Hp==15&&!duel.Log.Any(x=>x.Contains("自动施放")),"sage does not cast in summoning round");
            duel.NextRound();duel.SetReady(0);
            Check(duel.Plan(1,0,"needle",1),"opponent can select the actual summon target");
            duel.SetReady(1);
            Check(stone.Hp<15&&duel.Log.Count(x=>x.Contains("自动施放"))<=1,"hits damage the summon without giving it extra actions");

            for(int seed=0;seed<48;seed++)
            {
                var game=new ForestCampaign(seed,false,1,new ForestTrialOptions{CompositionA=new[]{"marisa","reimu"}});
                Check(game.PatchouliNode!=game.RecruitNode&&game.PatchouliNode!=game.FlandreNode&&game.PatchouliNode!=game.RemiliaNode&&
                    game.RecruitIdentity(game.PatchouliNode,0)==PatchouliSkills.Id,"a separate library in seed "+seed);
            }
            return checks;
        }

        static Unit Enemy(string name)
        {return new Unit{Name=name,Hp=90,MaxHp=90,MinSpeed=3,MaxSpeed=3};}
    }
}
