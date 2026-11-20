using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class ForestTrialChecks
    {
        static int checks;
        static void Check(bool ok,string why){checks++;if(!ok)throw new Exception("Trial campaign: "+why);}

        public static int Run()
        {
            checks=RemiliaChecks.Run()+PatchouliChecks.Run();
            for(int face=1;face<=6;face++)Check(ForestCampaign.ActionsForDie(face)==(face<=2?1:face<=4?2:3),"D6 pairs have the intended movement");
            var normal=new ForestCampaign(48,false,1,new ForestTrialOptions());
            Check(normal.Themes.SequenceEqual(new[]{ForestTheme.ScarletMansion,ForestTheme.YoukaiMountain,ForestTheme.BambooForest,
                ForestTheme.EarthPalace,ForestTheme.MagicForest}),"normal themes use fixed order");
            Check(normal.Current.Party.Hp.SequenceEqual(new[]{45,0,50})&&normal.Current.Party.MaxHp[1]==0,"ordinary fresh party has only the two starting members");
            var mobs=normal.Current.Party.CreateBattle(0);
            Check(mobs.State.RecruitLockedSakuya&&!TouhouRoles.SakuyaCards.Any(mobs.State.Hand.Contains),"unrecruited Sakuya cannot equip exclusive cards in environmental battle");
            Check(mobs.ConfigureLoadout(new[]{"marisa_stars","yin_yang_orb"}),"two available members can lock loadout");
            var routeSets=Enumerable.Range(0,12).Select(seed=>string.Join(",",new ForestCampaign(seed,true,1,new ForestTrialOptions()).Themes)).Distinct().Count();
            Check(routeSets>2,"different seeds sample and reorder themes");
            var pvp=new ForestCampaign(48,true,1,new ForestTrialOptions{TurnSeconds=60,PlanSeconds=30});
            var repeat=new ForestCampaign(48,true,1,new ForestTrialOptions{TurnSeconds=60,PlanSeconds=30});
            Check(pvp.Themes.Length==4&&pvp.Themes.Distinct().Count()==4&&pvp.Themes.SequenceEqual(repeat.Themes),"pvp draws four unique reproducible themes");
            Check(pvp.Players.All(u=>u.LastDie>=1&&u.LastDie<=6&&u.ActionsLeft==ForestCampaign.ActionsForDie(u.LastDie))&&
                pvp.Players.Select(u=>u.LastDie).SequenceEqual(repeat.Players.Select(u=>u.LastDie)),"dice are deterministic and initialized for each team");
            var standard=new ForestCampaign(48,true);
            var acting=standard.Current;
            var waiting=standard.Players[1];
            int waitingDie=waiting.LastDie;
            int waitingPoints=waiting.ActionsLeft;
            var observedBudgets=new System.Collections.Generic.HashSet<int>();
            for(int turn=1;turn<=24;turn++)
            {
                Check(acting.Turn==turn&&acting.ActionsLeft==ForestCampaign.ActionsForDie(acting.LastDie),
                    "standard PVP rolls the same movement rule each round");
                observedBudgets.Add(acting.ActionsLeft);
                Check(acting.EndTurn(true),"ending the map turn refreshes the budget");
            }
            standard.AdvancePlayer();
            Check(observedBudgets.Count==3&&standard.Current==waiting&&waiting.LastDie==waitingDie&&waiting.ActionsLeft==waitingPoints,
                "all three budgets occur and passing does not reroll the waiting player");
            CheckRecruitmentCardSlots();
            CheckPvpOpeningProtection();
            CheckStoneTransfer();
            Check(!normal.TickTurnClock(999)&&normal.TurnTimeLeft==0,"unlimited never expires");
            foreach(int seconds in new[]{60,120,180})
            {
                var c=new ForestCampaign(4,true,1,new ForestTrialOptions{TurnSeconds=seconds});
                Check(!c.TickTurnClock(seconds-1)&&c.TurnTimeLeft==1&&c.TickTurnClock(1)&&!c.TickTurnClock(20),"room threshold fires once");
                c.AdvancePlayer();
                Check(c.TurnTimeLeft==seconds,"next active player receives new map clock");
            }

            Enter(pvp,pvp.Players[1].Position);
            var d=pvp.Duel;
            Check(d!=null&&!d.Recruitment&&pvp.Current.Position==pvp.Players[1].Position&&!pvp.Current.EndTurn(),
                "same tile triggers real duel, locks map");
            Check(d.Toggle(0,"marisa_meteor"),"supported exclusive can be manually selected");
            d.Tick(2);
            Check(d.ChoiceLeft[0]==8&&d.ChoiceLeft[1]==8,"both deck clocks run together");
            Check(d.SetReady(0)&&d.IsReady(0)&&!d.IsReady(1)&&d.WaitingText(0)=="对方出招中"&&
                !d.Toggle(0,"marisa_meteor")&&d.Stage==TrialDuelStage.Deck,"ready locks only the first deck");
            d.Tick(8);
            Check(d.Stage==TrialDuelStage.Plan&&d.Cards(1,0).All(k=>PortContent.Card(k).Owner<0)&&
                d.Cards(0,0).Contains("marisa_meteor"),"empty deck only uses shared skills");
            d.Tick(5);
            Check(d.ChoiceLeft[0]==25&&d.ChoiceLeft[1]==25,"the two skill clocks advance together");
            Check(d.SetReady(0,true)&&d.AutoLog.Count>0&&d.Beats.Count==0&&d.Stage==TrialDuelStage.Plan,
                "early ready can prepare eligible skills without resolving the battle");
            var contact=pvp.Current.Position;
            int cost0=pvp.Players[0].Party.Cost,cost1=pvp.Players[1].Party.Cost;
            Check(pvp.TickTurnClock(60),"outer timer still expires in battle");
            pvp.AbortTrialDuel();
            Check(pvp.Duel==null&&pvp.Players.All(r=>r.FloorIndex==0&&r.Map.Distance(contact,r.Position,false)<=2)&&
                pvp.Players.All(r=>r.Position!=contact)&&pvp.Players[0].Position!=pvp.Players[1].Position,
                "retreat stays on legal connected tiles and avoids immediate repeat collision");
            Check(pvp.Players[0].Party.Cost==cost0&&pvp.Players[1].Party.Cost==cost1,"abort discards unexecuted actions");

            var left=new TrialDuelSide(new[]{TouhouRoles.Marisa()},2);
            var right=new TrialDuelSide(new[]{TouhouRoles.Sakuya()},2);
            var direct=new CampaignDuel(left,right,21,20,false,0);
            direct.SetReady(1);direct.SetReady(0);
            Check(direct.Plan(0,"needle",0),"A enters a common skill with blank deck");
            Check(direct.Plan(1,0,"needle",0),"B enters a common skill before either side is ready");
            Check(direct.SetReady(1)&&direct.WaitingText(1)=="对方出招中"&&direct.Stage==TrialDuelStage.Plan&&
                direct.RoundOpening==null&&direct.Beats.Count==0&&direct.Sides.All(side=>side.Cost==2&&side.Units[0].Hp==side.Units[0].MaxHp),
                "right side can ready first without charging either player or starting a single beat");
            Check(!direct.RemovePlan(1,0)&&!direct.SetReady(1)&&direct.Plan(0,"needle",0),"ready is idempotent and locks only the ready player");
            Check(direct.SetReady(0)&&direct.RoundOpening!=null&&direct.Beats.Any(beat=>beat.Kind=="clash")&&
                direct.Beats.Any(beat=>beat.Kind=="strike"),"second ready records the real clash and strikes");
            Check(direct.Log.Any(s=>s.Contains("赢得拼点"))&&direct.Sides.Count(s=>s.Units[0].Hp<s.Units[0].MaxHp)==1,
                "symmetric duel resolves one clash and only winning attack strikes");
            CheckOneSkillPerActor();
            CheckLastEligibleChallenger();

            var decisive=new ForestCampaign(48,true,1,new ForestTrialOptions());
            Enter(decisive,decisive.Players[1].Position);
            var battle=decisive.Duel;
            foreach(var u in battle.Sides[1].Units)u.Hp=1;
            battle.SetReady(0);battle.SetReady(1);
            for(int actor=0;actor<3;actor++)Check(battle.Plan(actor,"needle",actor),"ready attack against surviving enemy");
            battle.SetReady(0);battle.SetReady(1);
            string occupied=decisive.Current.Position;
            Check(battle.Winner==0&&decisive.FinishTrialDuel()&&decisive.Current.Position==occupied&&
                decisive.Players[1].Map.Node(decisive.Players[1].Position).Kind==ForestNodeKind.Eientei&&decisive.Players[1].FloorIndex==0,
                "winner stays and loser revives at same floor");

            Enter(normal,normal.RecruitNode);
            var challenge=normal.Duel;
            Check(challenge!=null&&challenge.Recruitment&&challenge.Sides[1].Units.Single().Name=="十六夜咲夜","red mansion contains actual character challenge");
            Check(challenge.Exclusive(0,0).SequenceEqual(TouhouRoles.MarisaCards)&&
                challenge.Exclusive(0,2).SequenceEqual(TouhouRoles.ReimuCards),"recruitment uses full allied exclusive hand");
            challenge.Sides[1].Units[0].Hp=1;
            challenge.Confirm();
            Check(challenge.Plan(0,"needle",0)&&challenge.Plan(2,"cleave",0),"recruit can be challenged with an empty exclusive group");
            challenge.Confirm();
            Check(challenge.RoundOpening!=null&&challenge.Beats.Any(beat=>beat.Coin!=null),"recruitment emits live coin playback frames");
            Check(challenge.Winner==0&&normal.FinishTrialDuel()&&normal.Trial.RecruitedSakuya&&normal.Current.Party.MaxHp[1]==40,
                "victory unlocks Sakuya and adds her to trial party");
            Check(!normal.RecruitAvailable(normal.RecruitNode,0),"unlocked character cannot farm recruit event");
            var recruitGuard=new CampaignDuel(new TrialDuelSide(new[]{TouhouRoles.Reimu()},30),
                new TrialDuelSide(new[]{TouhouRoles.Sakuya()},8),49,20,true,0);
            Check(recruitGuard.Toggle(0,"eight_way_bind"),"previously absent recruit spell equips");
            recruitGuard.Confirm();
            Check(recruitGuard.Plan(0,"eight_way_bind",0),"previously absent recruit spell can target");
            recruitGuard.Confirm();
            Check(recruitGuard.Beats.Any(beat=>beat.Message.Contains("八方鬼缚阵"))&&
                recruitGuard.Sides[1].Units[0].BindingTurn==2,"recruitment resolves the exclusive's real effect");
            var unlocked=new ForestCampaign(48,false,1,new ForestTrialOptions{RecruitedSakuya=true});
            Check(unlocked.Current.Party.MaxHp[1]==40,"re-entering with stored unlock restores full party");
            var failed=new ForestCampaign(48,false,1,new ForestTrialOptions());
            Enter(failed,failed.RecruitNode);
            challenge=failed.Duel;
            foreach(var unit in challenge.Sides[0].Units.Where(u=>u.Hp>0))unit.Hp=1;
            challenge.Confirm();
            for(int turn=0;turn<3&&challenge.Winner<0;turn++)
            {
                challenge.Confirm();
                if(challenge.Winner<0)challenge.NextRound();
            }
            Check(challenge.Winner==1&&failed.FinishTrialDuel()&&failed.RecruitLost&&
                !failed.RecruitAvailable(failed.RecruitNode,0)&&!failed.Trial.RecruitedSakuya,"defeat hides encounter and grants no character");
            var retry=new ForestCampaign(48,false,1,new ForestTrialOptions());
            Check(retry.RecruitAvailable(retry.RecruitNode,0),"new run restores missed recruit opportunity");
            return checks;
        }

        static void CheckLastEligibleChallenger()
        {
            foreach(int attacking in new[]{0,1})foreach(int speed in new[]{5,6})
            {
                var earlier=new Unit{Name="先指定",Hp=200,MaxHp=200,MinSpeed=9,MaxSpeed=9};
                var later=new Unit{Name="后指定",Hp=200,MaxHp=200,MinSpeed=speed,MaxSpeed=speed};
                var foe=new Unit{Name="共同目标",Hp=200,MaxHp=200,MinSpeed=6,MaxSpeed=6};
                var attackSide=new TrialDuelSide(new[]{earlier,later},20);
                var defendSide=new TrialDuelSide(new[]{foe},20);
                var duel=attacking==0?new CampaignDuel(attackSide,defendSide,21,20,false,0):
                    new CampaignDuel(defendSide,attackSide,21,20,false,0);
                duel.SetReady(0);duel.SetReady(1);
                for(int seat=0;seat<2;seat++)
                {
                    Check(duel.Plan(seat,0,"needle",0),"first attack can be assigned");
                    if(seat==attacking)Check(duel.Plan(seat,1,"needle",0),"second attack aims at the same unit");
                    duel.SetReady(seat);
                }
                var matchup=duel.Log.Single(line=>line.StartsWith("拼点："));
                string paired=speed==6?later.Name:earlier.Name;
                string solo=speed==6?earlier.Name:later.Name;
                Check(matchup.Contains(paired)&&!matchup.Contains(solo)&&duel.Log.Any(line=>line.StartsWith(solo+" · ")),
                    "latest eligible attacker clashes and the other retains its solo attack on either seat");
            }
        }

        static void CheckOneSkillPerActor()
        {
            var left=new TrialDuelSide(new[]{TouhouRoles.Sakuya(),TouhouRoles.Reimu()},2);
            var right=new TrialDuelSide(new[]{TouhouRoles.Sakuya(),TouhouRoles.Reimu()},2);
            var duel=new CampaignDuel(left,right,21,20,false,0);
            duel.SetReady(0);duel.SetReady(1);
            for(int seat=0;seat<2;seat++)
            {
                Check(duel.Plan(seat,0,"needle",0)&&!duel.Plan(seat,0,"cleave",0)&&duel.Planned(seat,0).Key=="needle",
                    "unaffordable replacement preserves old plan for either side");
                Check(duel.Plan(seat,0,"needle",1)&&duel.Planned(seat,0).Target==1,"retarget overwrites the previous target");
                Check(duel.Plan(seat,1,"guard",-1)&&duel.RemovePlan(seat,0)&&duel.Planned(seat,0)==null&&duel.Planned(seat,1).Key=="guard",
                    "cancellation frees only the selected character's action and cost");
                Check(duel.Plan(seat,0,"needle",0)&&duel.Plan(seat,0,"guard",-1),"one reserved action can change categories at the budget limit");
                duel.SetReady(seat,true);
            }
            Check(duel.Stage==TrialDuelStage.Reveal&&duel.Sides.All(side=>side.Cost==0&&side.Units.All(unit=>unit.Shield==9&&unit.Hp==unit.MaxHp))&&
                duel.Log.Count(row=>row.Contains("获得9护盾"))==4&&!duel.Log.Any(row=>row.Contains("自动安排")),
                "only the four final skills resolve and charge, even when both sides time out");

            duel.NextRound();
            for(int seat=0;seat<2;seat++)
            {
                Check(duel.Planned(seat,0)==null&&duel.Planned(seat,1)==null&&duel.Plan(seat,0,"guard",-1),"both sides get fresh slots each round");
                duel.SetReady(seat,true);
                Check(duel.Planned(seat,0).Key=="guard"&&duel.Planned(seat,1)!=null,"timeout fills the empty slot without replacing the manual skill");
            }
            Check(duel.Log.Count(row=>row.Contains("自动安排"))==2,"exactly one timeout skill selected per unplanned character");
        }




        static void CheckRecruitmentCardSlots()
        {
            string[] ids={"marisa","reimu","sakuya"};
            foreach(string opponent in new[]{"sakuya","flandre",RemiliaSkills.Id,PatchouliSkills.Id})
            {
                var duel=new CampaignDuel(new TrialDuelSide(CharacterRoster.Compose(new[]{"patchouli"}),30),
                    new TrialDuelSide(new[]{CharacterRoster.Create(opponent)},30),49,20,true,0);
                Check(duel.Exclusive(1,0).Length==6&&duel.Cards(1,0).Count()==6&&
                    duel.VisibleSkillCatalog(1,0).SequenceEqual(duel.Cards(1,0)),
                    "six real opponent cards are visible for "+opponent);
                Check(duel.Slots(1,0)==1,"empty seats and Patchouli's summon do not grant more actions");
            }
            for(int count=1;count<=3;count++)
            {
                var heroes=CharacterRoster.Compose(ids.Take(count).ToArray());
                foreach(var hero in heroes.Where(unit=>unit.MaxHp>0))
                {hero.Hp=200;hero.MaxHp=200;hero.MinSpeed=10;hero.MaxSpeed=10;}
                var foe=TouhouRoles.Sakuya();foe.Hp=200;foe.MaxHp=200;
                var duel=new CampaignDuel(new TrialDuelSide(heroes,30),new TrialDuelSide(new[]{foe},2*count),49,20,true,0);
                foreach(string key in TouhouRoles.MarisaCards.Take(4))
                    Check(duel.Toggle(0,key),"human can equip four distinct cards");
                Check(!duel.Toggle(0,TouhouRoles.MarisaCards[4]),"fifth human exclusive is rejected");
                duel.Confirm();
                Check(duel.Slots(1,0)==count&&!duel.CanPlan(1,0,"murder_doll",0,count),
                    "recruit gets exactly as many slots as deployed heroes");
                for(int actor=0;actor<count;actor++)Check(duel.Plan(actor,"needle",0),"one target per hero in test round");
                duel.Confirm();
                Check(duel.PlannedCount(1)==count&&Enumerable.Range(0,count).All(slot=>duel.Planned(1,0,slot).Key=="murder_doll"),
                    "repeated card occupies separate recruit slots");
                Check(duel.Log.Count(line=>line.StartsWith("拼点："))==count&&duel.Sides[1].Cost<=1,
                    "repeated cards each spend cost and clash independently");
            }
            var pvp=new CampaignDuel(new TrialDuelSide(CharacterRoster.Compose(ids),30),
                new TrialDuelSide(new[]{TouhouRoles.Sakuya()},8),49,20,false,0);
            Check(pvp.Slots(1,0)==1&&pvp.Cards(1,0).All(k=>PortContent.Card(k).Owner<0)&&
                TouhouRoles.SakuyaCards.All(pvp.VisibleSkillCatalog(1,0).Contains),
                "PvP catalog is inspectable without changing action count or revealing the actual deck");
        }

        static void CheckStoneTransfer()
        {
            var campaign=new ForestCampaign(53,true,1,new ForestTrialOptions
                {CompositionA=new[]{"marisa"},CompositionB=new[]{"reimu"}});
            var carrier=campaign.Current;
            var challenger=campaign.Players[1];
            while(carrier.FloorIndex<3)ForestCampaignChecks.Descend(carrier);
            string stone=carrier.Map.Nodes.Single(n=>n.Kind==ForestNodeKind.MutationStone).Id;
            ForestCampaignChecks.Walk(carrier,stone);
            Check(campaign.StoneHolder==0&&carrier.EmberCore&&!challenger.EmberCore,"real stone pickup gives only the first carrier possession");
            int exitFloor=campaign.ExitTier;
            string exit=campaign.ExitNode;

            while(challenger.FloorIndex<3)ForestCampaignChecks.Descend(challenger);
            var route=ForestRandomGenerator.Path(challenger.Map,challenger.Position,stone,n=>!ForestRandomGenerator.Risk(n.Kind));
            ForestCampaignChecks.Walk(challenger,route.Last().Other(stone));
            if(challenger.ActionsLeft==0)challenger.EndTurn(true);
            campaign.AdvancePlayer();
            Check(challenger.Move(stone)&&campaign.Duel!=null,"challenger reaches the real holder using a connected tile");
            var battle=campaign.Duel;
            battle.Sides[0].Units[0].Hp=1;
            battle.Sides[1].Units[0].Hp=19;
            battle.SetReady(0);battle.SetReady(1);
            Check(battle.Plan(1,0,"needle",0),"challenger plans a real attack");
            battle.SetReady(0);battle.SetReady(1);
            Check(battle.Winner==1&&campaign.FinishTrialDuel(),"real finished PVP applies the result");
            Check(campaign.StoneHolder==1&&!carrier.EmberCore&&challenger.EmberCore&&challenger.Party.Hp[0]==19,
                "only the winner holds the stone and keeps the settled HP");
            Check(campaign.ExitTier==exitFloor&&campaign.ExitNode==exit&&campaign.LockNode==challenger.Position&&
                campaign.LockFloor==challenger.FloorIndex&&carrier.Map.Node(carrier.Position).Kind==ForestNodeKind.Eientei&&
                carrier.CanSeePlayer(challenger),"exit stays put and tracking follows the winner after loser revives");
            var buff=challenger.PreviewMapModifier();
            var loser=carrier.PreviewMapModifier();
            Check(buff.ClashBonus==1&&buff.DamageBonus==5&&loser.ClashBonus==0&&loser.DamageBonus==0,
                "the stone modifiers follow possession into the next battle");
        }

        static void CheckPvpOpeningProtection()
        {
            var campaign=new ForestCampaign(48,true,1,new ForestTrialOptions());
            // Both revivals use the same tile. Early co-location must not start or reveal a duel.
            foreach(var player in campaign.Players)player.Revive();
            var first=campaign.Players[0];
            var second=campaign.Players[1];
            Check(first.Position==second.Position&&campaign.PvpOpeningProtected&&
                !first.CanSeePlayer(second)&&!campaign.TryTrialEncounter(first),"opening protection covers shared revival tiles");
            for(int turn=0;turn<ForestCampaign.PvpOpeningTurns*2;turn++)
            {
                Check(campaign.PvpOpeningProtected&&campaign.Duel==null,"both sides get the full opening without PVP");
                Check(campaign.Current.EndTurn(true),"teams can keep ending turns during protection");
                campaign.AdvancePlayer();
            }
            Check(!campaign.PvpOpeningProtected&&first.CanSeePlayer(second)&&campaign.Duel!=null,
                "the final protected handoff detects teams still occupying the same tile");
        }

        static void Enter(ForestCampaign c,string target)
        {
            while(c.PvpOpeningProtected)
            {
                Check(c.Current.EndTurn(true),"waiting team completes an ordinary opening turn");
                c.AdvancePlayer();
            }
            var run=c.Current;
            while(run.Position!=target)
            {
                var edge=ForestRandomGenerator.Path(run.Map,run.Position,target,n=>!ForestRandomGenerator.Risk(n.Kind)).First();
                if(run.Pending=="shop")run.LeaveShop();
                else if(run.Pending!="")run.Choose(0);
                while(run.ActionsLeft<edge.ActionCost)Check(run.EndTurn(true),"trial fixture ends map turn");
                Check(run.Move(edge.Other(run.Position)),"walk through ordinary tile in trial");
            }
        }
    }
}
