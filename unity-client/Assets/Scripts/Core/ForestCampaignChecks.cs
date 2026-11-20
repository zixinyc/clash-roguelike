using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class ForestCampaignChecks
    {
        static int checks;static void Check(bool ok,string text){checks++;if(!ok)throw new Exception("Layered forest: "+text);}
        static void Choices(ForestRun run)
        {if(run.Pending=="shop")run.LeaveShop();else if(run.Pending!=""){int choice=run.Pending=="camp"||run.Pending=="altar"?1:run.Pending=="event"&&run.EventVariant==0?1:0;Check(run.Choose(choice),"real location choice");}}
        public static void Walk(ForestRun run,string target)
        {
            var path=ForestRandomGenerator.Path(run.Map,run.Position,target,n=>n.Id==target||!ForestRandomGenerator.Risk(n.Kind));
            if(run.Position!=target&&path.Count==0)throw new Exception("No safe path to "+target);
            foreach(var edge in path){Choices(run);while(run.ActionsLeft<edge.ActionCost||run.RecoveryTurns>0)run.EndTurn();string next=edge.Other(run.Position);if(!run.Move(next))throw new Exception(run.MoveError(next));if(run.InBattle)throw new Exception("Safe test route unexpectedly meets patrol");Choices(run);}
        }
        internal static void Descend(ForestRun run)
        {var down=run.Map.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition).OrderBy(n=>ForestRandomGenerator.Path(run.Map,run.Position,n.Id,x=>!ForestRandomGenerator.Risk(x.Kind)).Count).First();Walk(run,down.Id);if(run.ActionsLeft==0)run.EndTurn();Check(run.Transition(),"normal downward transition");}
        public static int Run()
        {
            checks=0;int multiple=0,adjacentSpawn=0;for(int seed=0;seed<100;seed++)foreach(bool pvp in new[]{false,true})
            {
                var maps=ForestRandomGenerator.GenerateFloors(seed,pvp);Check(maps.Length==(pvp?4:5),"correct macro floor count");
                var repeated=ForestRandomGenerator.GenerateFloors(seed,pvp);Check(maps.Select(m=>m.Serialize()).SequenceEqual(repeated.Select(m=>m.Serialize())),"whole seed reproducible");
                for(int tier=0;tier<maps.Length;tier++)
                {
                    var m=maps[tier];m.Validate();Check(m.Nodes.All(n=>n.Tier==0&&n.FloorIndex==tier)&&m.Nodes.Count>24,"independent tier default and readable new floor size");
                    Check(m.Nodes.Count(n=>n.Kind==ForestNodeKind.Eientei)==1,"one Eientei every floor");Check(!m.Nodes.Any(n=>n.Kind==ForestNodeKind.Passage||n.Kind==ForestNodeKind.Exit),"no generated legacy passage or premature exit");
                    Check(m.Nodes.Count(n=>n.Kind==ForestNodeKind.MutationStone)==(tier==maps.Length-1?1:0),"stone only on final floor");
                    var downs=m.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition).ToArray();Check(tier==maps.Length-1?downs.Length==0:downs.Length>=1,"non-final floor downward route");if(downs.Length>1)multiple++;
                    Check(m.Nodes.Any(n=>n.Kind==ForestNodeKind.UpwardEntrance)==(tier>0),"up and down semantics distinct");
                    Check(m.Nodes.Where(n=>n.Kind==ForestNodeKind.UpwardEntrance).All(entry=>m.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition||n.Kind==ForestNodeKind.MutationStone).All(goal=>m.Distance(entry.Id,goal.Id,false)>=3)),"arrival entrance also cannot skip the floor directly to its goal");
                    foreach(var spawn in m.Nodes.Where(n=>n.Kind==ForestNodeKind.Spawn))
                    {
                        Check(!downs.Any(n=>n.Id==spawn.Id)&&downs.All(n=>m.Distance(spawn.Id,n.Id,false)>0),"spawn cannot occupy stairs");
                        if(downs.Any(n=>m.Distance(spawn.Id,n.Id,false)==1))adjacentSpawn++;
                    }
                    Check(m.Nodes.All(n=>m.Distance(m.StartId,n.Id,false)!=int.MaxValue),"explicit ordinary graph reaches all locations");
                    Check(m.Edges.Count-m.Nodes.Count+1>=3&&m.Nodes.Any(n=>m.Links(n.Id).Count()>=3)&&m.Edges.Any(e=>e.Kind==ForestRouteKind.Main),"routes contain loops branches merges and main path");
                    Check(m.Nodes.Count(n=>n.Kind==ForestNodeKind.Elite)<=2&&m.Nodes.Count(n=>n.Kind==ForestNodeKind.Danger)<=2,"elite and danger quota");
                    foreach(var elite in m.Nodes.Where(n=>n.Kind==ForestNodeKind.Elite))Check(m.Nodes.Where(n=>n.Kind==ForestNodeKind.Camp||n.Kind==ForestNodeKind.Supply||n.Kind==ForestNodeKind.Eientei).Any(n=>m.Distance(elite.Id,n.Id,false)<=2),"elite recovery within two steps");
                    Check(m.Nodes.Where(n=>n.Kind==ForestNodeKind.Elite).All(elite=>m.Nodes
                        .Any(n=>(n.Kind==ForestNodeKind.Camp||n.Kind==ForestNodeKind.Supply)&&m.Distance(elite.Id,n.Id,false)<=2)),
                        "elite reaches camp or supply by two actual road steps");
                    foreach(var danger in m.Nodes.Where(n=>n.Kind==ForestNodeKind.Danger))Check(m.Edges.Where(e=>e.Hidden&&e.Kind==ForestRouteKind.Shortcut).Any(e=>Math.Min(m.Distance(danger.Id,e.From,false),m.Distance(danger.Id,e.To,false))<=3),"danger reveals a nearby shortcut");
                    foreach(var goal in m.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition||n.Kind==ForestNodeKind.MutationStone))Check(ForestRandomGenerator.Path(m,m.StartId,goal.Id,n=>!ForestRandomGenerator.Risk(n.Kind)).Count>0,"ordinary elite and danger can be bypassed");
                    Check(ForestMapDefinition.Parse(m.Serialize()).Serialize()==m.Serialize(),"v2 roundtrip");
                    Check(m.Nodes.Select(n=>new { Column=m.RoadColumn(n),Row=m.RoadRow(n) }).Distinct().Count()==m.Nodes.Count,
                        "one interactive tile per coordinate");
                    Check(m.RoadColumns==(pvp?13:9)&&m.RoadRows==(pvp?9:7),"grid has the expected dimensions by mode");
                    if(pvp)
                    {
                        Check(m.Nodes.Count>=78,"large PVP floor has at least 78 traversable tiles");
                        if(tier==0)
                        {
                            var starts=m.Nodes.Where(n=>n.Kind==ForestNodeKind.Spawn).ToArray();
                            Check(starts.Length==2&&m.Distance(starts[0].Id,starts[1].Id)>6*ForestCampaign.PvpOpeningTurns,
                                "even paths using hidden connections exceed the combined opening movement budget");
                            Check(starts.All(start=>downs.All(down=>m.Distance(start.Id,down.Id)>=ForestRandomGenerator.PvpOpeningStairDistance)),
                                "neither player can bypass the opening floor with three maximum rolls");
                        }
                    }
                    Check(m.RoadGrid&&m.Nodes.Any(n=>n.Kind==ForestNodeKind.Road)&&m.Nodes.All(n=>n.FloorIndex==tier),"ordinary road tiles and independent floor metadata");
                    Check(m.Edges.All(e=>{
                        var from=m.Node(e.From);var to=m.Node(e.To);
                        return Math.Abs(m.RoadColumn(from)-m.RoadColumn(to))+
                               Math.Abs(m.RoadRow(from)-m.RoadRow(to))==1;
                    }),"all displayed road links are one cardinal step");
                    Check(m.Edges.Where(e=>e.Hidden).All(e=>m.Distance(e.From,e.To,false)>e.ActionCost),"paid hidden tiles shorten real movement");
                }
            }
            Check(multiple>100,"multiple stairs supported, not always a unique ladder");
            Check(adjacentSpawn>0,"compact maps and later floors retain optional nearby stairs");
            var old=ForestMapDefinition.Generate(73129,false);var v1=ForestMapDefinition.Parse(old.Serialize());Check(v1.FormatVersion==1&&v1.Nodes.Any(n=>n.Kind==ForestNodeKind.Passage)&&v1.Edges.All(e=>e.HpCost==0)&&v1.Nodes.All(n=>n.Tier==0),"legacy defaults and Passage retained");
            var minimal=ForestMapDefinition.Parse(old.Serialize().Replace("FOREST|1|","FOREST|2|"));Check(minimal.Nodes.All(n=>n.Tier==0)&&minimal.Edges.All(e=>e.HpCost==0),"v2 optional fields defaults");
            Check(v1.Nodes.All(n=>n.FloorIndex==0)&&minimal.Nodes.All(n=>n.FloorIndex==0),"v1 and v2 default floor independently of tier");
            var sample=ForestRandomGenerator.GenerateFloor(42,3,5);
            sample.Nodes[0].Tier=7;
            var grid = ForestMapDefinition.Parse(sample.Serialize());
            Check(grid.RoadGrid&&grid.Nodes.All(n=>n.FloorIndex==2)&&grid.Nodes[0].Tier==7&&grid.Nodes[1].Tier==0,"v2 preserves grid, floor index, and tier independently");
            var constrained = new ForestRun(grid);
            var invalidTarget = grid.Nodes.First(n=>n.Id!=grid.StartId&&grid.Edge(n.Id,grid.StartId)==null);
            int budget=constrained.ActionsLeft;
            Check(!constrained.Move(invalidTarget.Id)&&constrained.ActionsLeft==budget,
                "road click cannot jump or spend resources on failure");
            var small=ForestMapDefinition.Generate(73129,false);small.Edges[0].HpCost=9;var hp=new ForestRun(small);hp.Party.Hp=new[]{3,0,12};Check(hp.Move("n1")&&hp.Party.Hp.SequenceEqual(new[]{1,0,3}),"edge HP cost only living members and minimum one");
            var campaign=new ForestCampaign(37,false);var run=campaign.Current;string firstPosition=run.Position;Descend(run);int cost=run.Party.Cost;string below=run.Position;if(run.ActionsLeft==0)run.EndTurn();Check(run.Transition()&&run.FloorIndex==0&&run.Party.Cost==cost,"upward return keeps resources and stays upper floor");if(run.ActionsLeft==0)run.EndTurn();Check(run.Transition()&&run.FloorIndex==1&&run.Position==below,"return route remembers entry");
            for(int f=run.FloorIndex;f<4;f++)Descend(run);Walk(run,run.Map.Nodes.First(n=>n.Kind==ForestNodeKind.MutationStone).Id);Check(campaign.Finished&&run.Finished&&campaign.Winner==0,"single ends immediately at stone after all five floors");
            var duel=new ForestCampaign(53,true);var a=duel.Players[0];var b=duel.Players[1];Check(a.Position!=b.Position&&a.Map.Node(a.Position).Kind==ForestNodeKind.Spawn&&b.Map.Node(b.Position).Kind==ForestNodeKind.Spawn,"PVP legal random unique spawns");
            Check(duel.ExitTier==-1&&duel.Floors.All(f=>!f.Nodes.Any(n=>n.Kind==ForestNodeKind.Exit)),"no exit before stone");for(int i=0;i<3;i++){Descend(a);Descend(b);}a.Party.Hp[0]=1;Walk(a,a.Map.Nodes.First(n=>n.Kind==ForestNodeKind.MutationStone).Id);
            Check(!duel.Finished&&duel.StoneHolder==0&&duel.ExitTier>=2&&duel.ExitTier<=3&&duel.ExitNode!="","stone changes phase and deterministically generates legal exit");Check(a.Party.Hp.SequenceEqual(a.Party.MaxHp),"holder restored to existing maxima");Check(b.CanSeePlayer(a)&&!b.CanSeeTile(a.Position),"other player sees the carrier without revealing terrain");
            Check(duel.Floors[duel.ExitTier].Node(duel.ExitNode).Kind==ForestNodeKind.Road,"hidden exit leaves the shared road data untouched");
            var stoneModifier=a.PreviewMapModifier();Check(stoneModifier.ClashBonus==a.NextBattle.ClashBonus+1&&stoneModifier.DamageBonus==a.NextBattle.DamageBonus+5,"holder adds map-side bonuses without overwriting queued event preparation");
            var replay=new ForestCampaign(53,true);for(int i=0;i<3;i++){Descend(replay.Players[0]);Descend(replay.Players[1]);}replay.Players[0].Party.Hp[0]=1;Walk(replay.Players[0],replay.Floors[3].Nodes.Single(n=>n.Kind==ForestNodeKind.MutationStone).Id);Check(replay.ExitNode==duel.ExitNode&&replay.ExitTier==duel.ExitTier,"same seed and action state reproduce the dynamic exit");
            if(duel.ExitTier==2){Walk(a,a.Map.Nodes.First(n=>n.Kind==ForestNodeKind.UpwardEntrance).Id);if(a.ActionsLeft==0)a.EndTurn();Check(a.Transition(),"holder can return upward for escape");}CheckExitDiscovery(duel,a,b);
            Walk(a,duel.ExitNode);Check(duel.Finished&&duel.Winner==0,"PVP actual escape destination completes game");
            CheckPvpFog();
            var dead=new ForestCampaign(9,false).Current;dead.Party.Hp=new[]{0,0,0};dead.Revive();Check(dead.FloorIndex==0&&dead.Map.Node(dead.Position).Kind==ForestNodeKind.Eientei&&dead.RecoveryTurns==1&&!dead.Finished,"first floor death returns first floor Eientei");Check(!dead.CanMove(dead.Map.Links(dead.Position).First().Other(dead.Position))&&!dead.UseSupply(),"death cannot act immediately");dead.EndTurn();Check(dead.RecoveryTurns==0&&dead.ActionsLeft>0,"one map turn rest then resumes");
            var eco=new ForestCampaign(10,false).Current;Walk(eco,eco.Map.Nodes.First(n=>n.Kind==ForestNodeKind.Lookout).Id);int trackers=eco.Trackers;for(int i=0;i<5;i++){eco.EndTurn();eco.Observe();}Check(eco.Trackers==trackers&&eco.NextBattle.RevealEnemyCards==1,"observation refresh no resource farm and nonstacking reveal");
            Walk(eco,eco.Map.Nodes.First(n=>n.Kind==ForestNodeKind.Hideout).Id);eco.EndTurn();eco.Hide();eco.EndTurn();eco.Hide();Check(eco.HiddenTurns==2&&eco.Alert>=0&&eco.NextBattle.EnemySlotsFirstTurn==-1,"hiding refresh capped and nonstacking action penalty");
            var battle=new PortBattleRules(77);var initial=battle.State.EnemySlots.Count(s=>s.Active);battle.ApplyMapPreparation(new BattleModifier{RevealEnemyCards=1,EnemySlotsFirstTurn=-1,ClashBonus=1,DamageBonus=5});Check(battle.State.EnemySlots.Count(s=>s.Active)==initial-1&&battle.State.EnemySlots.Count(s=>s.Active&&battle.EnemySkillVisible(s.Id))==1,"first-turn slot/reveal adapter");battle.Resolve();battle.NextRound();Check(!battle.State.EnemySlots.Any(s=>battle.EnemySkillVisible(s.Id)),"reveal expires after first turn");
            var anomaly=new PortBattleRules(77);anomaly.ApplyMapPreparation(new BattleModifier(),5);Check(anomaly.State.Enemies.Count==5&&anomaly.State.EnemySlots.Count==15&&anomaly.State.Enemies.All(u=>u.MaxHp==58||u.MaxHp==65),"anomaly uses five existing enemies without weakening stats");
            CheckEconomy();CheckModifierMath();
            CheckRoadEconomy();
            CheckRecoveryOnEveryFloor();
            var linked=new ForestCampaign(37,false);Check(linked.FloorLinks.Count==linked.Floors.Sum(f=>f.Nodes.Count(n=>n.Kind==ForestNodeKind.DownwardTransition))&&linked.FloorLinks.All(l=>l.Lower==l.Upper+1&&linked.Floors[l.Upper].Node(l.DownNode).Kind==ForestNodeKind.DownwardTransition&&linked.Floors[l.Lower].Node(l.UpNode).Kind==ForestNodeKind.UpwardEntrance),"floor transitions are explicit validated links");var runner=linked.Current;Walk(runner,runner.Map.Nodes.First(n=>n.Kind==ForestNodeKind.DownwardTransition).Id);if(runner.ActionsLeft==0)runner.EndTurn();int remaining=runner.ActionsLeft;linked.FloorLinks.Clear();Check(!runner.Transition()&&runner.FloorIndex==0&&runner.ActionsLeft==remaining,"no implicit transition without an explicit floor link");
            var hiddenPlayers=new ForestCampaign(8,true);hiddenPlayers.Players[1].HiddenTurns=2;Check(!hiddenPlayers.Players[0].CanSeePlayer(hiddenPlayers.Players[1]),"ordinary hiding suppresses player markers before public stone lock");
            foreach(bool hpField in new[]{false,true}){var invalid=ForestMapDefinition.Generate(73129,false);if(hpField)invalid.Edges[0].HpCost=-1;else invalid.Nodes[0].Tier=-1;bool rejected=false;try{invalid.Validate();}catch(InvalidOperationException){rejected=true;}Check(rejected,"negative new format field rejected");}
            return checks;
        }
        static void CheckRecoveryOnEveryFloor()
        {
            foreach(bool pvp in new[]{false,true})
            {
                var campaign=new ForestCampaign(31,pvp);
                foreach(var player in campaign.Players)
                    for(int floor=0;floor<campaign.Floors.Length;floor++)
                    {
                        string position=player.Position;
                        int currency=player.Party.Cost,supplies=player.Supply,turn=player.Turn;
                        player.Party.Hp=new[]{0,0,0};
                        player.Revive();
                        Check(player.Map.Node(player.Position).Kind==ForestNodeKind.Eientei&&player.FloorIndex==floor&&
                            player.Intel().Visited.Contains(position)&&player.Party.Cost==currency&&player.Supply==supplies,
                            "same-floor revival preserves map exploration and the real wallet on every floor");
                        string adjacent=player.Map.Links(player.Position).First(e=>!e.Hidden).Other(player.Position);
                        Check(!player.CanMove(adjacent)&&!player.Transition(),"recovery forbids movement and floor switching");
                        Check(player.EndTurn()&&player.Turn==turn+1&&player.CanMove(adjacent),"after one map turn the revived player can act");
                        if(floor<campaign.Floors.Length-1)Descend(player);
                    }
            }
        }
        static void CheckRoadEconomy()
        {
            var run=new ForestCampaign(10,false).Current;
            var hideout=run.Map.Nodes.First(n=>n.Kind==ForestNodeKind.Hideout);
            Walk(run,hideout.Id);
            run.EndTurn();
            run.Alert=4;
            Check(run.Hide()&&run.Alert==4&&run.HiddenTurns==2,"repeated hiding refreshes but grants no further alert reduction");
            var neighbor=run.Map.Links(hideout.Id).Select(e=>e.Other(hideout.Id)).First(id=>!ForestRandomGenerator.Risk(run.Map.Node(id).Kind));
            Walk(run,neighbor);
            Walk(run,hideout.Id);
            Check(run.Alert==4,"a road loop cannot farm the same hideout's alert reduction");

            var rewards=Point(ForestNodeKind.Event,true);
            rewards.Relics.Add("灵符·锐");
            Check(rewards.PreviewMapModifier().DamageBonus==0,"new road campaign records relic effects as unconfirmed");
            int wallet=rewards.Party.Cost;
            Check(rewards.Pending=="event"&&rewards.EventChoice(0)!=rewards.EventChoice(1),"event presents two actual road choices");
            Check(rewards.Choose(1)&&rewards.Party.Cost-wallet>=5&&rewards.Party.Cost-wallet<=10&&rewards.NextBattle.DamageBonus==0,
                "event uses the documented currency band without a numeric battle bonus");
        }
        static ForestRun Point(ForestNodeKind kind,bool roadGrid=false)
        {
            var m=new ForestMapDefinition{FormatVersion=2,StartId="a"};m.Nodes.Add(new ForestNode("a",.1f,.2f,ForestNodeKind.Spawn,"入口"));m.Nodes.Add(new ForestNode("b",.3f,.2f,kind,"被测地点"));m.Nodes.Add(new ForestNode("c",.5f,.2f,ForestNodeKind.Event,"转折"));m.Nodes.Add(new ForestNode("d",.7f,.2f,ForestNodeKind.Event,"转折"));m.Nodes.Add(new ForestNode("e",.9f,.2f,ForestNodeKind.Eientei,"永远亭"));for(int i=0;i<4;i++)m.Edges.Add(new ForestEdge{Id="e"+i,From="abcde"[i].ToString(),To="abcde"[i+1].ToString()});m.Edges.Add(new ForestEdge{Id="hidden",From="b",To="e",Kind=ForestRouteKind.Shortcut,Hidden=true,ActionCost=2});var r=new ForestRun(m);m.RoadGrid=roadGrid;Check(r.Move("b"),"isolated economic fixture uses normal move API");return r;
        }

        static void CheckExitDiscovery(ForestCampaign campaign,ForestRun hunter,ForestRun rival)
        {
            string exit=campaign.ExitNode;
            var route=ForestRandomGenerator.Path(hunter.Map,hunter.Position,exit,n=>!ForestRandomGenerator.Risk(n.Kind));
            if(route.Count<=1)throw new Exception("Exit fog fixture must start away from the exit");
            Check(!hunter.CanSeeTile(exit)&&hunter.KnownExitNode==null&&hunter.KnownExitFloor==-1&&rival.KnownExitNode==null,
                "the new exit is not publicly discovered by either team");
            Check(hunter.PresentTile(hunter.Map.Node(exit)).Kind==ForestNodeKind.Road,
                "unseen exit looks like its original road");
            var adjacent=route.Last().Other(exit);
            Walk(hunter,adjacent);
            Check(hunter.Position!=exit&&hunter.CanSeeTile(exit)&&hunter.KnownExitNode==exit&&hunter.KnownExitFloor==hunter.FloorIndex&&
                hunter.PresentTile(hunter.Map.Node(exit)).Kind==ForestNodeKind.Exit,
                "a single ordinary edge of distance adds the exit label before entering");
            Check(rival.KnownExitNode==null,"the other team does not inherit this discovery");
            var away=route[route.Count-2].Other(adjacent);
            Walk(hunter,away);
            Check(!hunter.CanSeeTile(exit)&&hunter.KnownExitNode==exit&&hunter.Intel().Known.Contains(exit),
                "a found exit remains a remembered landmark when the current view moves away");
        }

        static void CheckPvpFog()
        {
            var campaign=new ForestCampaign(53,true);
            var scout=campaign.Current;
            var rival=campaign.Players[1];
            var path=ForestRandomGenerator.Path(scout.Map,scout.Position,rival.Position,n=>!ForestRandomGenerator.Risk(n.Kind));
            string old=scout.Position,between=path[0].Other(old),twoAway=path[1].Other(between);
            Walk(scout,twoAway);
            Walk(rival,old);
            var intel=scout.Intel();
            Check(intel.Known.Contains(old)&&intel.Visited.Contains(old)&&intel.KnownEdges.Contains(path[0].Id),
                "previously explored tiles and their roads stay mapped");
            Check(!intel.Visible.Contains(old)&&!scout.CanSeePlayer(rival),"opponent standing on a remembered tile is not exposed");
            Walk(rival,between);
            Check(scout.CanSeePlayer(rival),"an exposed opponent in the adjacent road tile can be seen");
            if(rival.ActionsLeft==0)rival.EndTurn(true);
            Check(rival.UseSmoke()&&!scout.CanSeePlayer(rival),"smoke still hides an adjacent opponent");

            Walk(scout,scout.Map.Nodes.Single(n=>n.Kind==ForestNodeKind.Lookout).Id);
            var neighbors=scout.Map.Links(scout.Position).Where(e=>!e.Hidden||scout.Intel().KnownEdges.Contains(e.Id))
                .Select(e=>e.Other(scout.Position)).Concat(new[]{scout.Position});
            Check(scout.Intel().Visible.SetEquals(neighbors),"observation discovers terrain without expanding one-tile PVP visibility");
        }

        static void CheckEconomy()
        {
            var supply=Point(ForestNodeKind.Supply);Check(supply.Pending=="supply"&&supply.Party.Cost==30&&supply.Supply==1,"supply does not automatically grant both choices");Check(supply.Choose(0)&&supply.Party.Cost==33&&supply.Supply==1,"supply cost choice exactly three");supply.Move("a");supply.EndTurn();supply.Move("b");Check(supply.Pending==""&&!supply.Choose(1)&&supply.Supply==1,"supply cannot pay twice");var other=Point(ForestNodeKind.Supply);Check(other.Choose(1)&&other.Supply==2&&other.Party.Cost==30,"supply item choice only");
            var camp=Point(ForestNodeKind.Camp);camp.Party.Hp[0]=30;Check(camp.Choose(0)&&camp.Party.Hp[0]==40,"camp heals ten HP");camp=Point(ForestNodeKind.Camp);Check(camp.Choose(1)&&camp.Party.Cost==35,"camp awards five cost");
            var shop=Point(ForestNodeKind.Shop);Check(shop.ShopPrice(0)==4&&shop.ShopPrice(1)==6&&!shop.Choose(2),"candidate merchant prices");int health=shop.Party.Hp[0];Check(shop.Choose(0)&&shop.ShopPrice(0)==6&&shop.Party.Cost==26,"same item increases by two");shop.LeaveShop();shop.Move("a");shop.EndTurn();shop.Move("b");Check(shop.Pending=="shop"&&shop.ShopPrice(0)==6&&shop.Party.Hp[0]==health,"merchant persists on re-entry and never heals");Check(shop.Choose(1)&&shop.Supply==2&&shop.ShopPrice(1)==8,"supplies keep their own price and purchase count");
            var danger=Point(ForestNodeKind.Danger);Check(danger.Alert==2&&danger.Party.Hp[0]==46&&danger.Intel().KnownEdges.Contains("hidden"),"danger still costs HP and reveals the shortcut");for(int i=0;i<5;i++){if(danger.ActionsLeft==0)danger.EndTurn();danger.Move("a");if(danger.ActionsLeft==0)danger.EndTurn();danger.Move("b");}Check(danger.Party.Hp.All(h=>h>=1),"repeated danger cannot kill the party");while(danger.ActionsLeft<2)danger.EndTurn();int beforeShortcut=danger.ActionsLeft;Check(danger.Move("e")&&danger.ActionsLeft==beforeShortcut-2,"revealed route only costs two action points");
            var lookout=Point(ForestNodeKind.Lookout);Check(lookout.NextBattle.RevealEnemyCards==1&&lookout.Trackers==2,"lookout first reward and queued reveal");lookout.EndTurn();lookout.Observe();Check(lookout.Trackers==2&&lookout.NextBattle.RevealEnemyCards==1,"repeated lookout is not an income loop");
            lookout=Point(ForestNodeKind.Lookout);Check(lookout.Intel().Visible.Contains("d"),"observation reveals two-hop area now");lookout.EndTurn();Check(lookout.Intel().Visible.Contains("d"),"observation persists next round");lookout.EndTurn();Check(!lookout.Intel().Visible.Contains("d")&&lookout.Intel().Known.Contains("d"),"two-round vision expires without erasing exploration");
            var hide=Point(ForestNodeKind.Hideout);hide.EndTurn();hide.Hide();Check(hide.HiddenTurns==2&&hide.NextBattle.EnemySlotsFirstTurn==-1&&hide.Alert==0,"hide duration and first-turn enemy reduction capped");
            var revive=new ForestCampaign(71,false).Current;Descend(revive);revive.Revive();Check(revive.FloorIndex==1&&revive.Map.Node(revive.Position).Kind==ForestNodeKind.Eientei&&revive.Map.Node(revive.Position).FloorIndex==1,"second-floor death returns second-floor anchor");
            var cross=new ForestMapDefinition{StartId="b"};cross.Nodes.Add(new ForestNode("a",.1f,.1f,ForestNodeKind.Spawn,"A"));cross.Nodes.Add(new ForestNode("b",.9f,.9f,ForestNodeKind.Spawn,"B"));cross.Nodes.Add(new ForestNode("c",.1f,.9f,ForestNodeKind.Spawn,"C"));cross.Nodes.Add(new ForestNode("d",.9f,.1f,ForestNodeKind.Spawn,"D"));cross.Edges.Add(new ForestEdge{Id="ab",From="a",To="b"});cross.Edges.Add(new ForestEdge{Id="bc",From="b",To="c"});cross.Edges.Add(new ForestEdge{Id="cd",From="c",To="d"});var crossing=new ForestRun(cross);crossing.UseTracker();crossing.Move("a");crossing.EndTurn();int ap=crossing.ActionsLeft;Check(crossing.Intel().Known.Contains("d")&&!crossing.Move("d")&&crossing.ActionsLeft==ap,"visual line crossing never grants a non-edge movement");
        }
        sealed class Heads:PortBattleRules {public Heads(bool touhou=false):base(9,0,touhou){}protected override bool FlipCoin(double chance){return true;}}
        static void CheckModifierMath()
        {
            var plain=new Heads();var buffed=new Heads();buffed.ApplyMapPreparation(new BattleModifier{ClashBonus=1,DamageBonus=5});
            foreach(var b in new PortBattleRules[]{plain,buffed}){foreach(var slot in b.State.EnemySlots)slot.Active=false;b.State.EnemySlots[0].Active=true;b.State.EnemySlots[0].Key="needle";b.State.EnemySlots[0].Target=0;b.State.HeroSlots[0].Speed=20;b.Assign("probe",0,0);}
            var first=plain.Resolve();var second=buffed.Resolve();var a=first.First(e=>e.Type=="clash").Coin;var b2=second.First(e=>e.Type=="clash").Coin;Check(b2.LeftPower==a.LeftPower+1&&b2.RightPower==a.RightPower,"map clash bonus through scoped existing effects");var hit1=first.First(e=>e.Type=="strike");var hit2=second.First(e=>e.Type=="strike");Check(hit2.Damage==hit1.Damage+5&&hit2.Coin.RawDamage==hit1.Coin.RawDamage&&hit2.Coin.AttackBase==hit1.Coin.AttackBase&&hit2.Coin.AttackBudget==hit1.Coin.AttackBudget,"final map damage bonus does not change raw attack base, count or coin formula");
            plain=new Heads();buffed=new Heads();buffed.ApplyMapPreparation(new BattleModifier{DamageBonus=5});foreach(var rules in new[]{plain,buffed}){foreach(var s in rules.State.EnemySlots)s.Active=false;rules.State.Enemies[0].Shield=100;rules.Assign("probe",0,0);}var shield1=plain.Resolve().First(e=>e.Type=="strike");var shield2=buffed.Resolve().First(e=>e.Type=="strike");Check(shield1.Damage==0&&shield2.Damage==5&&plain.State.Enemies[0].Shield==buffed.State.Enemies[0].Shield,"final damage bonus applies after original shield without changing shield consumption");
            var support=new Heads(true);support.ApplyMapPreparation(new BattleModifier{DamageBonus=5});foreach(var s in support.State.EnemySlots)s.Active=false;support.Assign("the_world",1,0);Check(support.Resolve().Where(e=>e.Type=="strike").All(e=>e.Damage==0),"non-damaging skills never gain fake damage from map bonus");
            plain=new Heads(true);buffed=new Heads(true);buffed.ApplyMapPreparation(new BattleModifier{DamageBonus=5});foreach(var rules in new[]{plain,buffed}){foreach(var s in rules.State.EnemySlots)s.Active=false;rules.State.Heroes[0].RoleState.Spark=1;rules.Assign("marisa_spark",0,0);}var special1=plain.Resolve().First(e=>e.Type=="strike");var special2=buffed.Resolve().First(e=>e.Type=="strike");Check(special2.Hits.Zip(special1.Hits,(hit,plainHit)=>hit.Damage==plainHit.Damage+5).All(x=>x)&&special2.Coin.RawDamage==special1.Coin.RawDamage,"each target receives external final map bonus without changing the raw formula");
        }
    }
}
