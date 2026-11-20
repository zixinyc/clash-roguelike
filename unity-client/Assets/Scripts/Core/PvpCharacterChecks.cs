
using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class PvpCharacterChecks
    {
        static int checks;
        static void Check(bool pass,string message)
        {
            checks++;
            if(!pass)throw new InvalidOperationException("PVP characters: "+message);
        }

        static CampaignDuel Duel(string left,string right,int cost=30)
        {
            return new CampaignDuel(new TrialDuelSide(new[]{CharacterRoster.Create(left)},cost),
                new TrialDuelSide(new[]{CharacterRoster.Create(right)},cost),49,20,false,0);
        }

        static void Resolve(CampaignDuel duel){duel.SetReady(0);duel.SetReady(1);}

        public static int Run()
        {
            checks=0;
            foreach(string id in CharacterRoster.Ids)
            {
                var duel=Duel(id,id);
                var catalog=duel.Exclusive(0,0);
                Check(catalog.SequenceEqual(CharacterRoster.Skills(id))&&catalog.Length>0,"complete exclusive catalog: "+id);
                foreach(string key in catalog.Take(4))Check(duel.Toggle(0,key),"can equip "+key);
                if(catalog.Length>4)Check(!duel.Toggle(0,catalog[4]),"enforce four-card cap for "+id);
                duel.ReadyLocalOpponent();
                Check(duel.Stage==TrialDuelStage.Deck&&duel.IsReady(1)&&duel.Sides[1].Equipped[0].Count==Math.Min(4,catalog.Length),
                    "local opponent locks its own deck: "+id);
                duel.SetReady(0);
                Check(duel.Stage==TrialDuelStage.Plan&&duel.Cards(0,0).Count(k=>PortContent.Card(k).Owner>=0)==Math.Min(4,catalog.Length),
                    "only equipped exclusive skills are available: "+id);
            }

            var match=Duel("reimu","zixi");
            match.SetReady(0);match.ReadyLocalOpponent();
            Check(match.Sides[0].Equipped[0].Count==0&&match.Cards(0,0).All(k=>PortContent.Card(k).Owner<0),"an empty human deck stays empty");
            match.ReadyLocalOpponent();
            Check(match.IsReady(1)&&match.Planned(1,0)!=null&&match.Log.Count==0&&match.Beats.Count==0,
                "opponent plans never enter the visible log before both are ready");
            match.SetReady(0);
            Check(!match.Log.Any(row=>row.Contains("自动安排")),"the local opponent's private plan is excluded from the public transcript");

            var sakuya=Duel("sakuya","reimu");
            sakuya.Toggle(0,"the_world");Resolve(sakuya);
            Check(sakuya.Plan(0,"the_world",0),"equip and select the World");
            Resolve(sakuya);sakuya.NextRound();
            Check(sakuya.Slots(0,0)==3&&!sakuya.CanPlan(1,0,"needle",0),"time stop opens three Sakuya actions and freezes opponent");
            Check(sakuya.Plan(0,0,"guard",-1,0)&&sakuya.Plan(0,0,"guard",-1,1)&&sakuya.Plan(0,0,"guard",-1,2),
                "three independent slots are legal while time has stopped");
            Check(!sakuya.CanPlan(0,0,"the_world",0),"the World is available once per fight");
            Resolve(sakuya);
            Check(sakuya.Sides[0].Units[0].Shield==27,"all three time-stop actions resolve");
            sakuya.NextRound();
            Check(sakuya.Slots(0,0)==1&&sakuya.CanPlan(1,0,"needle",0),"normal actions resume after one round");

            var reimu=Duel("reimu","ash");
            reimu.Toggle(0,"eight_way_bind");Resolve(reimu);
            Check(reimu.Plan(0,"eight_way_bind",0),"Reimu can plan a targeted guard");
            Resolve(reimu);
            Check((reimu.Sides[0].Units[0].Shield==6||reimu.Sides[0].Units[0].Shield==16)&&
                reimu.Sides[1].Units[0].BindingTurn==2&&reimu.Sides[1].Units[0].Exorcism==1,
                "binding applies the original shield, slowing and exorcism rule");

            var marisa=Duel("marisa","sakuya");
            marisa.Toggle(0,"marisa_orrery");Resolve(marisa);
            Check(marisa.Plan(0,"marisa_orrery",-1),"Marisa can plan Orrery");
            Resolve(marisa);
            Check(marisa.Sides[0].Units[0].RoleState.Spark==1&&marisa.Sides[0].Units[0].RoleState.OrreryUntil==2,
                "Orrery grants spark and stores its active window");

            var zixi=Duel("zixi","ash");
            zixi.Toggle(0,"zixi_central_limit");Resolve(zixi);
            var z=zixi.Sides[0].Units[0].Zixi;
            z.Metaphysics=3;
            Check(zixi.Plan(0,"zixi_central_limit",0)&&zixi.Plan(1,0,"needle",0)&&zixi.ToggleEnhancement(0,0,0),
                "ZiXi can reserve enhancement on an equipped skill");
            zixi.SetReady(0);
            Check(z.Metaphysics==3&&zixi.Beats.Count==0,"private preparation spends no metaphysics before resolution");
            zixi.SetReady(1);
            var clash=zixi.Beats.First(beat=>beat.Kind=="clash");
            Check(clash.Coin.LeftBase==13&&z.Causality==1&&z.NextClash["zixi_central_limit"]==1&&z.Metaphysics>0,
                "enhanced ZiXi uses the separate clash base and grants after-clash statuses");
            Check(zixi.Beats.Any(beat=>beat.Kind=="strike"&&beat.Coin.RawModifier==4),"ZiXi enhanced per-hit damage is used");

            var team=new CampaignDuel(new TrialDuelSide(CharacterRoster.Compose(new[]{"support","ash"}),30),
                new TrialDuelSide(CharacterRoster.Compose(new[]{"marisa"}),30),49,20,false,0);
            team.Toggle(0,"light_guard");Resolve(team);
            Check(team.Plan(0,"light_guard",-1),"support can use her exclusive guard");
            Resolve(team);
            Check(team.Sides[0].Units[0].Shield==9&&team.Sides[0].Units[1].Shield==8,"exclusive guard shields the team");
            return checks;
        }
    }
}
