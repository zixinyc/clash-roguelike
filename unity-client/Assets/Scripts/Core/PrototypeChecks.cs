using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class PrototypeChecks
    {
        static int checks;static void Check(bool ok,string message){checks++;if(!ok)throw new Exception("Prototype: "+message);}
        public static int Run()
        {
            checks=0;var topologies=new System.Collections.Generic.HashSet<string>();var places=new System.Collections.Generic.HashSet<string>();
            for(int seed=0;seed<100;seed++)
            {
                var m=ForestRandomGenerator.Generate(seed);m.Validate();Check(m.Serialize()==ForestRandomGenerator.Generate(seed).Serialize(),"seed reproducibility");
                Check(m.Nodes.All(n=>m.Distance(m.StartId,n.Id,false)!=int.MaxValue),"every location reachable without paid shortcuts");
                Check(m.Edges.Count-m.Nodes.Count+1>=3&&m.Edges.Any(e=>e.Kind==ForestRouteKind.Main)&&m.Edges.Any(e=>e.Kind==ForestRouteKind.Branch),"main route branches and cycles");
                Check(m.Edges.Where(e=>e.Kind==ForestRouteKind.Shortcut).All(e=>e.Hidden&&e.ActionCost==2&&e.IntelCost==1&&m.Distance(e.From,e.To,false)>=3),"limited meaningful hidden shortcut");
                foreach(var kind in new[]{ForestNodeKind.Spawn,ForestNodeKind.Exit,ForestNodeKind.Center,ForestNodeKind.Battle,ForestNodeKind.Elite,ForestNodeKind.Supply,ForestNodeKind.Event,ForestNodeKind.Lookout,ForestNodeKind.Hideout,ForestNodeKind.Danger})Check(m.Nodes.Any(n=>n.Kind==kind),"mandatory point "+kind);
                Check(m.Nodes.All(n=>m.Nodes.All(other=>n==other||Math.Abs(n.X-other.X)>.07||Math.Abs(n.Y-other.Y)>.10)),"click targets remain separated");
                topologies.Add(string.Join(";",m.Edges.Select(e=>e.From+"-"+e.To).ToArray()));places.Add(string.Join(";",m.Nodes.Select(n=>n.Kind.ToString()).ToArray()));
                Check(ForestMapDefinition.Parse(m.Serialize()).Serialize()==m.Serialize(),"random map can be stored as preset");
            }
            Check(topologies.Count>60&&places.Count>60,"topology and node types genuinely vary");
            Check(ClashForecast.Classify(2)=="平衡"&&ClashForecast.Classify(-2)=="平衡"&&ClashForecast.Classify(2.1)=="优势"&&ClashForecast.Classify(-2.1)=="劣势","three risk thresholds");
            var forecast=ClashForecast.Create(PortContent.Card("probe"),new[]{PortContent.Card("needle")},false);Check(forecast.OwnMin==5&&forecast.OwnMax==9&&forecast.EnemyMin==3&&forecast.EnemyMax==7&&forecast.Risk=="优势","independent basic clash ranges and expected difference");
            var zixi=ClashForecast.Create(PortContent.Card("zixi_central_limit"),new[]{PortContent.Card("needle")},true);Check(zixi.OwnMin==11&&zixi.OwnMax==15,"forecast uses ZiXi clash base rather than separate attack base");
            var groups=new SkillGroups();var skills=TouhouRoles.MarisaCards;string first="marisa",second="zixi";
            Check(groups.Cards(first,skills).Length==4,"A defaults all existing skills");groups.Select(first,skills,1);var b=groups.Cards(first,skills);Check(b.Length==2,"B starts attack subset");groups.Toggle(first,skills,b[0]);Check(groups.Cards(first,skills).Length==1&&!groups.Toggle(first,skills,b[1]),"cannot deselect last exclusive skill");groups.Select(first,skills,0);Check(groups.Cards(first,skills).Length==4,"A and B remain independent");Check(groups.Cards(second,ZixiRole.Keys).Length==4,"different characters isolated");Check(!groups.Toggle(first,skills,"not-a-skill"),"unknown skill rejected");
            var rules=new PortBattleRules(73129,0,true);var chosen=rules.State.Hand.Where(k=>PortContent.Card(k).Owner<0).Concat(new[]{TouhouRoles.MarisaCards[0],TouhouRoles.SakuyaCards[0],TouhouRoles.ReimuCards[0]}).ToArray();
            Check(!rules.ConfigureLoadout(new[]{"unknown"})&&!rules.LoadoutLocked,"invalid selection does not lock");Check(rules.ConfigureLoadout(chosen)&&rules.LoadoutLocked,"valid battle configuration locks");
            Check(!rules.ConfigureLoadout(chosen)&&!rules.State.Hand.Contains("the_world")&&rules.State.Hand.Contains("guard"),"locked and universal cards preserved");
            Check(rules.CanAssign("the_world",4,0)!="","excluded skills cannot be used");
            rules.Resolve();rules.NextRound();Check(!rules.State.Hand.Contains("the_world")&&rules.State.Hand.Contains(TouhouRoles.MarisaCards[0]),"loadout persists across rounds");
            var control=new PortBattleRules(81);var filtered=new PortBattleRules(81);var all=(string[])filtered.State.Hand.Clone();Check(filtered.ConfigureLoadout(all),"original team supported");
            control.Assign("probe",0,0);filtered.Assign("probe",0,0);var ev1=control.Resolve();var ev2=filtered.Resolve();Check(ev1.Where(e=>e.Coin!=null).Select(e=>CoinLog.Fingerprint(e.Coin)).SequenceEqual(ev2.Where(e=>e.Coin!=null).Select(e=>CoinLog.Fingerprint(e.Coin))),"preparation consumes no battle randomness");
            return checks;
        }
    }
}
