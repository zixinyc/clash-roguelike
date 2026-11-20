using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public static class ForestRandomGenerator
    {
        public const int PvpRoadColumns=13, PvpRoadRows=9;
        public const int PvpOpeningStairDistance=10;

        public static ForestMapDefinition Generate(int seed) { return GenerateFloor(seed, 1, 5); }

        public static ForestMapDefinition[] GenerateFloors(int seed, bool pvp)
        {
            int count = pvp ? 4 : 5;
            return Enumerable.Range(1, count).Select(floor => GenerateFloor(seed, floor, count)).ToArray();
        }

        public static ForestMapDefinition GenerateFloor(int seed, int floor, int total)
        {
            for (int attempt = 0; attempt < 128; attempt++)
            {
                var random = new Random(unchecked(seed * 31337 + floor * 7919 + total * 48611 + attempt * 104729));
                var map = new FloorBuilder(seed, floor, total, random).Build();
                if (map == null || !Playable(map,floor,total)) continue;
                map.Validate();
                return map;
            }
            throw new InvalidOperationException("Cannot generate forest road network: seed " + seed + ", floor " + floor);
        }

        static bool Playable(ForestMapDefinition map,int floor,int total)
        {
            var goals=map.Nodes.Where(n=>n.Kind==ForestNodeKind.DownwardTransition||n.Kind==ForestNodeKind.MutationStone).ToArray();
            if(map.Nodes.Count(n=>n.Kind==ForestNodeKind.Eientei)!=1||
                map.Nodes.Count(n=>n.Kind==ForestNodeKind.UpwardEntrance)!=(floor>1?1:0)||
                map.Nodes.Count(n=>n.Kind==ForestNodeKind.MutationStone)!=(floor==total?1:0)||
                map.Nodes.Count(n=>n.Kind==ForestNodeKind.DownwardTransition)!=(floor==total?0:goals.Length)||
                goals.Length==0||map.Edges.Count(e=>!e.Hidden)-map.Nodes.Count+1<3) return false;
            var starts=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Spawn||n.Kind==ForestNodeKind.UpwardEntrance);
            if(starts.Any(start=>goals.Any(goal=>Path(map,start.Id,goal.Id,n=>!Risk(n.Kind)).Count==0)))return false;
            if(total==4&&floor==1)
            {
                var spawns=starts.ToArray();
                if(spawns.Length!=2||map.Distance(spawns[0].Id,spawns[1].Id)<=ForestCampaign.PvpOpeningTurns*6||
                    spawns.Any(start=>goals.Any(goal=>map.Distance(start.Id,goal.Id)<PvpOpeningStairDistance)))return false;
            }
            var recovery=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Camp||n.Kind==ForestNodeKind.Supply).ToArray();
            if(map.Nodes.Where(n=>n.Kind==ForestNodeKind.Elite).Any(elite=>
                !recovery.Any(stop=>map.Distance(elite.Id,stop.Id,false)<=2)))return false;
            var shortcuts=map.Edges.Where(e=>e.Hidden&&e.Kind==ForestRouteKind.Shortcut).ToArray();
            if(shortcuts.Any(e=>map.Distance(e.From,e.To,false)<=e.ActionCost))return false;
            return map.Nodes.Where(n=>n.Kind==ForestNodeKind.Danger).All(danger=>
                shortcuts.Any(e=>Math.Min(map.Distance(danger.Id,e.From,false),map.Distance(danger.Id,e.To,false))<=3));
        }

        sealed class Corridor
        {
            public int A, B;
            public int Mid { get { return (A+B)/2; } }
        }

        sealed class FloorBuilder
        {
            int Width {get{return map.RoadColumns;}}
            int Height {get{return map.RoadRows;}}
            bool Larger {get{return total==4;}}
            readonly int floor, total;
            readonly Random random;
            readonly ForestMapDefinition map;
            readonly Dictionary<int, ForestNode> cells = new Dictionary<int, ForestNode>();
            readonly List<Corridor> unused = new List<Corridor>();
            readonly List<ForestNode> reservedRecovery = new List<ForestNode>();

            public FloorBuilder(int seed, int floor, int total, Random random)
            {
                this.floor = floor;
                this.total = total;
                this.random = random;
                map = new ForestMapDefinition { Seed = seed, FormatVersion = 2, RoadGrid = true };
                if(Larger){map.RoadColumns=PvpRoadColumns;map.RoadRows=PvpRoadRows;}
            }

            public ForestMapDefinition Build()
            {
                BuildRoads();
                var shortcut = TakeCorridor();
                var danger = Tile(shortcut.Mid);
                Set(danger, ForestNodeKind.Danger);
                Connect(cells[shortcut.A], danger, ForestRouteKind.Branch);
                Connect(danger, cells[shortcut.B], ForestRouteKind.Shortcut);
                var hidden = map.Edge(danger.Id, cells[shortcut.B].Id);
                hidden.Hidden = true;
                hidden.ActionCost = 2;


                if ((floor == 1 || floor == total-1) && AddSpur(ForestNodeKind.Elite, true) == null) return null;
                bool patrol = floor == 1 || floor == total - 1;
                if (patrol && !BuildPatrol()) return null;
                if ((floor == 1 || floor == total) && AddSpur(ForestNodeKind.Anomaly, false) == null) return null;
                if (floor > 1 && !patrol && random.Next(3) < floor-1 && AddSpur(ForestNodeKind.Battle, false) == null) return null;

                var free = map.Nodes.Where(n => n.Kind == ForestNodeKind.Road).ToList();
                free.RemoveAll(reservedRecovery.Contains);
                ForestNode start;
                if(Larger&&floor==1)
                {
                    start=PlaceOppositeSpawns(free);
                    if(start==null)return null;
                }
                else
                {
                    start=Draw(free, ForestNodeKind.Spawn);
                    Draw(free, ForestNodeKind.Spawn);
                    Draw(free, ForestNodeKind.Spawn);
                }
                map.StartId = start.Id;
                var goals = new List<ForestNode>();
                int goalCount = floor == total ? 1 : random.Next(1,3);
                for (int i = 0; i < goalCount; i++)
                {
                    var candidates = free.Where(n => n.Kind == ForestNodeKind.Road&&
                        (!(Larger&&floor==1)||OpeningStair(n))).ToArray();
                    if (candidates.Length == 0) return null;
                    var goal = candidates[random.Next(candidates.Length)];
                    Set(goal, floor == total ? ForestNodeKind.MutationStone : ForestNodeKind.DownwardTransition);
                    free.Remove(goal);
                    goals.Add(goal);
                }
                if (floor > 1)
                {
                    var arrivals = free.Where(n => goals.All(g => map.Distance(n.Id,g.Id,false) >= 3)).ToArray();
                    if (arrivals.Length == 0) return null;
                    var arrival = arrivals[random.Next(arrivals.Length)];
                    Set(arrival, ForestNodeKind.UpwardEntrance);
                    free.Remove(arrival);
                }
                Draw(free, ForestNodeKind.Eientei);
                foreach (var node in reservedRecovery) Set(node, floor % 2 == 0 ? ForestNodeKind.Camp : ForestNodeKind.Supply);

                // Keep the opening floor's existing inventory of activities. Later floors
                // use fewer stops, with the stage weighting the extra optional destination.
                if (floor == 1)
                {
                    foreach (var kind in new[] { ForestNodeKind.Camp, ForestNodeKind.Shop, ForestNodeKind.Lookout,
                        ForestNodeKind.Hideout, ForestNodeKind.Event, ForestNodeKind.Center, ForestNodeKind.Encounter })
                        Draw(free, kind);
                }
                else
                {
                    Draw(free, floor % 2 == 0 ? ForestNodeKind.Lookout : ForestNodeKind.Hideout);
                    if(reservedRecovery.Count==0 && floor==2)Draw(free,ForestNodeKind.Camp);
                    Draw(free, floor == total ? ForestNodeKind.Shop : ForestNodeKind.Encounter);
                    var pool = floor >= total-1
                        ? new[] { ForestNodeKind.Event, ForestNodeKind.Camp, ForestNodeKind.Camp, ForestNodeKind.Lookout }
                        : new[] { ForestNodeKind.Supply, ForestNodeKind.Shop, ForestNodeKind.Encounter };
                    Draw(free, pool[random.Next(pool.Length)]);
                }

                foreach (var goal in goals)
                    foreach (var edge in Path(map, start.Id, goal.Id, n => !Risk(n.Kind))) edge.Kind = ForestRouteKind.Main;
                return map;
            }


            ForestNode PlaceOppositeSpawns(List<ForestNode> free)
            {
                var pairs=new[]{new[]{0,Width*Height-1},new[]{Width-1,(Height-1)*Width}}
                    .Where(pair=>pair.All(cell=>free.Contains(cells[cell]))).ToArray();
                if(pairs.Length==0)return null;
                var selected=pairs[random.Next(pairs.Length)];
                var start=cells[selected[0]];
                foreach(int cell in selected)
                {
                    var spawn=cells[cell];
                    Set(spawn,ForestNodeKind.Spawn);
                    free.Remove(spawn);
                }
                return start;
            }

            bool OpeningStair(ForestNode node)
            {
                return map.Nodes.Where(n=>n.Kind==ForestNodeKind.Spawn)
                    .All(spawn=>Math.Abs(map.RoadColumn(spawn)-map.RoadColumn(node))+
                        Math.Abs(map.RoadRow(spawn)-map.RoadRow(node))>=PvpOpeningStairDistance);
            }

            void BuildRoads()
            {
                var vertices = new List<int>();
                for (int y = 0; y < Height; y += 2)
                    for (int x = 0; x < Width; x += 2)
                    {
                        int cell = y*Width+x;
                        vertices.Add(cell);
                        Tile(cell);
                        if (x+2 < Width) unused.Add(new Corridor { A=cell, B=cell+2 });
                        if (y+2 < Height) unused.Add(new Corridor { A=cell, B=cell+2*Width });
                    }
                var reached = new HashSet<int> { vertices[random.Next(vertices.Count)] };
                while (reached.Count < vertices.Count)
                {
                    var frontier = unused.Where(e => reached.Contains(e.A) != reached.Contains(e.B)).ToArray();
                    var edge = frontier[random.Next(frontier.Length)];
                    unused.Remove(edge);
                    AddCorridor(edge, ForestRouteKind.Branch);
                    reached.Add(edge.A);
                    reached.Add(edge.B);
                }
                int loopCount = Larger?random.Next(8,13):random.Next(4,7);
                for (int i=0; i<loopCount; i++) AddCorridor(TakeCorridor(), ForestRouteKind.Loop);
            }

            Corridor TakeCorridor()
            {
                int i = random.Next(unused.Count);
                var result = unused[i];
                unused.RemoveAt(i);
                return result;
            }

            void AddCorridor(Corridor corridor, ForestRouteKind kind)
            {
                var tile = Tile(corridor.Mid);
                Connect(cells[corridor.A], tile, kind);
                Connect(tile, cells[corridor.B], kind);
            }

            ForestNode AddSpur(ForestNodeKind kind, bool recovery)
            {
                var exits = unused.Where(e => !cells.ContainsKey(e.Mid) &&
                    (!recovery || cells[e.A].Kind == ForestNodeKind.Road || cells[e.B].Kind == ForestNodeKind.Road)).ToArray();
                if (exits.Length == 0) return null;
                var corridor = exits[random.Next(exits.Length)];
                unused.Remove(corridor);
                var node = Tile(corridor.Mid);
                Set(node, kind);
                Connect(cells[corridor.A], node, ForestRouteKind.Branch);
                Connect(node, cells[corridor.B], ForestRouteKind.Branch);
                if (recovery) reservedRecovery.Add(cells[corridor.A].Kind == ForestNodeKind.Road ? cells[corridor.A] : cells[corridor.B]);
                return node;
            }

            bool BuildPatrol()
            {
                // Two connected battle tiles outside the safe skeleton keep the patrol
                // present without placing it on a compulsory route.
                var pairs = from row in Enumerable.Range(0,Height/2)
                            from col in Enumerable.Range(0,Width/2)
                            let y=2*row+1
                            let x=2*col+1
                            let pocket = y*Width+x
                            from first in unused
                            where map.RoadAdjacent(first.Mid,pocket)
                            from second in unused
                            where first != second && map.RoadAdjacent(second.Mid,pocket)
                            select new { Pocket=pocket, First=first, Second=second };
                var options = pairs.ToArray();
                if (options.Length == 0) return false;
                var pair = options[random.Next(options.Length)];
                var firstTile = Tile(pair.First.Mid);
                var secondTile = Tile(pair.Pocket);
                var access = Tile(pair.Second.Mid);
                unused.Remove(pair.First);
                unused.Remove(pair.Second);
                Set(firstTile, ForestNodeKind.Battle);
                Set(secondTile, ForestNodeKind.Battle);
                Connect(cells[pair.First.A], firstTile, ForestRouteKind.Branch);
                Connect(firstTile, secondTile, ForestRouteKind.Branch);
                Connect(secondTile, access, ForestRouteKind.Branch);
                Connect(access, cells[pair.Second.B], ForestRouteKind.Branch);
                map.PatrolRoute.Add(firstTile.Id);
                map.PatrolRoute.Add(secondTile.Id);
                return true;
            }

            ForestNode Tile(int cell)
            {
                var node = new ForestNode("f"+floor+"c"+cell, map.RoadX(cell%Width),
                    map.RoadY(cell/Width), ForestNodeKind.Road, Name(ForestNodeKind.Road))
                    { FloorIndex = floor-1 };
                cells.Add(cell,node);
                map.Nodes.Add(node);
                return node;
            }

            ForestNode Draw(List<ForestNode> free, ForestNodeKind kind)
            {
                int index = random.Next(free.Count);
                var node = free[index];
                free.RemoveAt(index);
                Set(node,kind);
                return node;
            }

            void Connect(ForestNode a, ForestNode b, ForestRouteKind kind)
            {
                map.Edges.Add(new ForestEdge { Id="f"+floor+"e"+map.Edges.Count, From=a.Id, To=b.Id, Kind=kind });
            }
        }

        public static bool Risk(ForestNodeKind kind)
        {
            return kind == ForestNodeKind.Battle || kind == ForestNodeKind.Elite ||
                kind == ForestNodeKind.Danger || kind == ForestNodeKind.Anomaly;
        }

        public static List<ForestEdge> Path(ForestMapDefinition map,string from,string to,Func<ForestNode,bool> allowed)
        {
            var queue = new List<string>();
            var previous = new Dictionary<string,ForestEdge>();
            queue.Add(from);
            previous[from] = null;
            int head = 0;
            while (head < queue.Count)
            {
                string current = queue[head++];
                if (current == to) break;
                foreach (var edge in map.Links(current).Where(e => !e.Hidden))
                {
                    string next = edge.Other(current);
                    if (previous.ContainsKey(next) || !allowed(map.Node(next))) continue;
                    previous[next] = edge;
                    queue.Add(next);
                }
            }
            var result = new List<ForestEdge>();
            if (!previous.ContainsKey(to)) return result;
            for (string node = to; node != from;)
            {
                var edge = previous[node];
                result.Add(edge);
                node = edge.Other(node);
            }
            result.Reverse();
            return result;
        }

        static void Set(ForestNode node, ForestNodeKind kind) { node.Kind = kind; node.Name = Name(kind); }
        public static string Name(ForestNodeKind kind)
        {
            switch(kind)
            {
                case ForestNodeKind.Road:return "竹林石径";
                case ForestNodeKind.Spawn:return "竹林入口";
                case ForestNodeKind.Eientei:return "永远亭";
                case ForestNodeKind.DownwardTransition:return "下层传送";
                case ForestNodeKind.UpwardEntrance:return "上层入口";
                case ForestNodeKind.MutationStone:return "异动石";
                case ForestNodeKind.Anomaly:return "异变妖群";
                case ForestNodeKind.Battle:return "妖怪遭遇";
                case ForestNodeKind.Elite:return "精英试炼";
                case ForestNodeKind.Supply:return "旅途补给";
                case ForestNodeKind.Camp:return "篝火小憩";
                case ForestNodeKind.Shop:return "林间行商";
                case ForestNodeKind.Lookout:return "月见台";
                case ForestNodeKind.Hideout:return "隐竹丛";
                case ForestNodeKind.Danger:return "瘴气竹径";
                case ForestNodeKind.Center:return "奉纳祭坛";
                case ForestNodeKind.Exit:return "逃亡出口";
                case ForestNodeKind.Encounter:return "竹影奇遇";
                default:return "竹林事件";
            }
        }
    }
}
