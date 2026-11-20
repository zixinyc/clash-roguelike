using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class ForestChecks
    {
        static int checks;
        static void Check(bool ok,string message){checks++;if(!ok)throw new Exception("Forest map: "+message);}
        static ForestRun Enter(ForestNodeKind kind)
        {
            var map=ForestMapDefinition.Generate(73129,false);map.PatrolRoute.Clear();string target=map.Nodes.First(x=>x.Kind==kind).Id;map.StartId=map.Links(target).First(x=>x.Kind!=ForestRouteKind.Shortcut).Other(target);var run=new ForestRun(map);Check(run.Move(target),"enter node "+kind);return run;
        }
        public static int Run()
        {
            checks=0;var map=ForestMapDefinition.Generate(73129,false);map.Validate();
            Check(map.Nodes.Count==28&&map.Edges.Count==42,"preset node and edge data");
            Check(map.Edges.Count-map.Nodes.Count+1>=3&&map.Nodes.Any(n=>map.Links(n.Id).Count()>=3),"cycles branches and merges");
            foreach(var kind in new[]{ForestNodeKind.Battle,ForestNodeKind.Supply,ForestNodeKind.Event,ForestNodeKind.Lookout,ForestNodeKind.Hideout,ForestNodeKind.Danger,ForestNodeKind.Center})Check(map.Nodes.Any(n=>n.Kind==kind),"core node type "+kind);
            foreach(var edge in map.Edges.Where(e=>e.Kind==ForestRouteKind.Shortcut))Check(map.Distance(edge.From,edge.To,false)>=3&&edge.ActionCost==2,"shortcuts save distance and cost two points");
            Check(map.Edges.Any(x=>x.Hidden),"hidden connection");
            string serialized=map.Serialize();var parsed=ForestMapDefinition.Parse(serialized);Check(parsed.Serialize()==serialized&&parsed.PatrolRoute.Count==5,"preset roundtrip including patrol data");
            var bad=ForestMapDefinition.Parse(serialized);bad.Edges.Add(new ForestEdge{Id="bad",From="n0",To="missing"});bool failed=false;try{bad.Validate();}catch(InvalidOperationException){failed=true;}Check(failed,"invalid connections rejected");
            var repeated=ForestMapDefinition.Generate(9).Serialize();Check(repeated==ForestMapDefinition.Generate(9).Serialize()&&repeated!=ForestMapDefinition.Generate(10).Serialize(),"seed generation deterministic and varied");
            for(int seed=1;seed<=30;seed++)
            {
                var generated=ForestMapDefinition.Generate(seed);generated.Validate();Check(generated.Nodes.All(n=>generated.Distance(generated.StartId,n.Id,false)<int.MaxValue),"all seeds connected without shortcut");
                Check(generated.Edges.Count-generated.Nodes.Count+1>=3&&generated.Nodes.Any(n=>n.Kind==ForestNodeKind.Center),"all seeds retain loops and objective");
            }
            var run=new ForestRun(map);int opening=run.ActionBudget;
            Check(run.Position=="n0"&&run.ActionsLeft==ForestCampaign.ActionsForDie(run.LastDie)&&run.Party.Cost==30,"preset forests roll before the first move");
            Check(run.Intel().PatrolNode==null&&!run.Intel().Known.Contains("n11"),"initial fog hides NPC and center node");
            int version=run.Version;Check(!run.Move("n11")&&!run.Move("missing")&&run.ActionsLeft==opening&&run.Version==version,"invalid move does not spend or mutate");
            Check(run.ClickNode("n1")&&run.Position=="n1"&&run.ActionsLeft==opening-1&&run.Party.Cost==34&&run.Supply==2,"connected click updates position and supply");
            Check(!run.ClickNode("n22")&&run.Position=="n1"&&run.ActionsLeft==opening-1&&run.Party.Cost==34,"known disconnected click selects without spending an action");
            Check(run.Move("n8")&&run.ActionsLeft==opening-2,"two moves spend two points");
            var view=run.Intel();Check(view.Known.Contains("n0")&&!view.Visible.Contains("n0")&&view.Visited.Contains("n0")&&view.Travelled.Count==2,"known visited visible and traversed separated");
            Check(run.EndTurn()&&run.Turn==2&&run.ActionsLeft==ForestCampaign.ActionsForDie(run.LastDie)&&run.Party.Cost==38,"next turn rolls a fresh budget without free money");
            run.Move("n1");Check(run.Party.Cost==38&&run.Supply==3,"supplies claimed only once");
            var supply=Enter(ForestNodeKind.Supply);supply.Party.Hp=new[]{40,0,30};int beforeSupply=supply.ActionsLeft;
            Check(supply.UseSupply()&&supply.Party.Hp.SequenceEqual(new[]{46,0,36})&&supply.ActionsLeft==beforeSupply-1,"supply spends one point and heals without revival");
            supply.ActionsLeft=0;Check(!supply.UseSupply(),"no item use without action");
            var smoke=new ForestRun(map);Check(smoke.UseSmoke()&&smoke.Smoke==0&&smoke.HiddenTurns==2&&smoke.Exposure==15,"smoke changes inventory and visibility");Check(!smoke.UseSmoke(),"empty smoke inventory blocked");smoke.EndTurn();Check(smoke.HiddenTurns==1,"hidden duration decreases by map turn");
            var tracker=new ForestRun(map);Check(tracker.UseTracker()&&tracker.Trackers==0&&tracker.ActionsLeft==tracker.ActionBudget-1&&tracker.Intel().PatrolNode==null,"tracker spends one point and gives filtered clues");
            var lookout=Enter(ForestNodeKind.Lookout);Check(lookout.Trackers==2&&lookout.Intel().KnownEdges.Contains("e40")&&lookout.Intel().Known.Contains("n21"),"lookout discovers the shortcut and awards a tracker");
            Check(lookout.Observe()&&lookout.Trackers==2,"repeat observation does not award another tracker");
            var hidden=Enter(ForestNodeKind.Hideout);int beforeHiding=hidden.ActionsLeft;Check(hidden.HiddenTurns==2&&hidden.Hide()&&hidden.ActionsLeft==beforeHiding-1,"hideout spends one point to refresh hiding");
            var danger=Enter(ForestNodeKind.Danger);Check(danger.Party.Hp.SequenceEqual(new[]{46,40,44})&&danger.Alert==2,"danger modifies existing health and alert only");
            var eventRun=Enter(ForestNodeKind.Event);Check(!eventRun.EndTurn()&&!eventRun.Move(eventRun.Map.StartId),"pending event blocks turn and movement");eventRun.EventVariant=0;eventRun.Party.Hp=new[]{2,0,9};Check(eventRun.Choose(1)&&eventRun.Party.Cost==42&&eventRun.Party.Hp.SequenceEqual(new[]{1,0,5}),"reuses original event trade");Check(!eventRun.Choose(1),"event cannot pay twice");
            var shop=Enter(ForestNodeKind.Shop);shop.Party.Cost=5;Check(!shop.Choose(0)&&shop.Pending=="shop"&&shop.Party.Cost==5,"shop affordability");shop.Party.Cost=10;shop.Party.Hp=new[]{40,0,20};Check(shop.Choose(0)&&shop.Party.Cost==4&&shop.Party.Hp.SequenceEqual(new[]{48,0,28}),"source healing price and amount retained");
            var fight=Enter(ForestNodeKind.Battle);Check(fight.InBattle&&!fight.EndTurn()&&!fight.CanMove(fight.Map.StartId),"battle locks map actions");fight.Party.Cost=27;fight.Party.Hp[0]=31;var b=fight.CreateBattle();Check(b.State.Cost==27&&b.State.Heroes[0].Hp==31,"battle receives current wallet and HP");b.State.Cost=19;b.State.Heroes[0].Hp=22;b.State.Outcome="victory";
            Check(fight.FinishBattle(b.State)&&fight.Party.Cost==23&&fight.Party.Hp[0]==22&&!fight.InBattle,"battle return uses existing reward");Check(!fight.FinishBattle(b.State)&&fight.Party.Cost==23,"battle return idempotent");
            var center=Enter(ForestNodeKind.Center);var elite=center.CreateBattle();elite.State.Outcome="victory";Check(center.Encounter==1&&center.FinishBattle(elite.State)&&center.EmberCore&&center.Party.Cost==38,"center is actual elite encounter and objective reward");
            Check(!center.FinishBattle(elite.State)&&center.Party.Cost==38,"central objective cannot repeat");
            var exitMap=ForestMapDefinition.Generate(73129,false);exitMap.PatrolRoute.Clear();exitMap.StartId="n26";var exit=new ForestRun(exitMap);exit.Move("n19");Check(!exit.Finished,"exit requires objective");exit.EmberCore=true;exit.EndTurn();exit.Move("n26");Check(exit.Move("n19")&&exit.Finished,"single player objective and extraction");
            var lost=Enter(ForestNodeKind.Battle);var loss=lost.CreateBattle();loss.State.Outcome="defeat";foreach(var h in loss.State.Heroes)h.Hp=0;Check(lost.FinishBattle(loss.State)&&lost.Finished&&!lost.EndTurn(),"defeat terminates exploration");
            var oldPreset=serialized.Replace("|Shortcut|False|2|0|","|Shortcut|False|2|1|");
            var shortMap=ForestMapDefinition.Parse(oldPreset);shortMap.PatrolRoute.Clear();shortMap.StartId="n9";
            var shortcut=new ForestRun(shortMap);int beforeShortcut=shortcut.ActionsLeft;int beforeCost=shortcut.Party.Cost;
            Check(shortcut.Move("n18")&&shortcut.ActionsLeft==beforeShortcut-2&&shortcut.Party.Cost==beforeCost,"old preset shortcut spends only two points");
            var signals=new ForestRun(map);for(int t=0;t<4;t++){signals.EndTurn();var intel=signals.Intel();Check(intel.Signals.All(s=>intel.Known.Contains(s.NodeId)&&s.ExpiresTurn>=signals.Turn),"signal projection respects fog and expiry");Check(intel.PatrolNode==null||intel.Visible.Contains(intel.PatrolNode),"NPC marker only from current vision");}
            var detached=signals.Intel();detached.Known.Clear();Check(signals.Intel().Known.Count>0,"view cannot mutate authoritative knowledge");
            var contactMap=ForestMapDefinition.Generate(73129,false);contactMap.StartId="n14";var contact=new ForestRun(contactMap);
            Check(contact.Intel().PatrolNode=="n15","patrol marker visible only when adjacent in current vision");contact.EndTurn();
            Check(contact.InBattle&&contact.Encounter==0&&!contact.EndTurn(),"environment patrol entering current node triggers existing encounter");
            var evade=new ForestRun(contactMap);evade.UseSmoke();evade.EndTurn();
            Check(!evade.InBattle&&evade.Intel().PatrolNode=="n14"&&evade.HiddenTurns==1,"smoke prevents same-node patrol encounter");
            evade.EndTurn();evade.EndTurn();Check(evade.Intel().PatrolNode==null&&evade.Intel().Signals.Any(s=>s.Kind=="track"),"patrol leaves current vision while nearby historical traces remain");
            Check(evade.UseTracker()&&evade.Intel().PatrolNode==null&&evade.Intel().Signals.Any(s=>s.Kind=="noise"&&s.NodeId=="n12"),"tracker gives filtered distant clue, never a live hidden patrol marker");
            foreach(int variant in new[]{0,1}){var invalid=ForestMapDefinition.Generate(73129,false);if(variant==0)invalid.Node("n1").X=float.NaN;else invalid.Edges[0].ActionCost=0;bool rejected=false;try{invalid.Validate();}catch(InvalidOperationException){rejected=true;}Check(rejected,"reject invalid configurable coordinates or costs");}
            return checks+ForestCampaignChecks.Run()+ForestTrialChecks.Run()+PvpCharacterChecks.Run();
        }
    }
}
