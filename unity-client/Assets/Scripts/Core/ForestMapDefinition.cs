using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
namespace ClashRoguelike
{
    public enum ForestNodeKind { Spawn,Battle,Elite,Supply,Event,Hideout,Lookout,Danger,Center,Passage,Camp,Shop,Exit }
    public enum ForestRouteKind { Main,Branch,Loop,Shortcut }
    public sealed class ForestNode
    {
        public string Id,Name; public ForestNodeKind Kind; public float X,Y;
        public ForestNode(string id,float x,float y,ForestNodeKind kind,string name){Id=id;X=x;Y=y;Kind=kind;Name=name;}
    }
    public sealed class ForestEdge
    {
        public string Id,From,To;public ForestRouteKind Kind;public bool Hidden;public int ActionCost=1,IntelCost;public float Bend;
        public string Other(string node){return From==node?To:From;}
    }
    public sealed class ForestMapDefinition
    {
        public readonly List<ForestNode> Nodes=new List<ForestNode>();
        public readonly List<ForestEdge> Edges=new List<ForestEdge>();
        public readonly List<string> PatrolRoute=new List<string>();
        public int Seed=73129;public string StartId="n0";
        public ForestNode Node(string id){return Nodes.FirstOrDefault(x=>x.Id==id);}
        public IEnumerable<ForestEdge> Links(string id){return Edges.Where(x=>x.From==id||x.To==id);}
        public ForestEdge Edge(string a,string b){return Edges.FirstOrDefault(x=>(x.From==a&&x.To==b)||(x.From==b&&x.To==a));}
        public int Distance(string a,string b,bool shortcuts=true)
        {
            if(Node(a)==null||Node(b)==null)return int.MaxValue;var q=new Queue<string>();var distances=new Dictionary<string,int>();q.Enqueue(a);distances[a]=0;
            while(q.Count>0){string n=q.Dequeue();if(n==b)return distances[n];foreach(var e in Links(n).Where(x=>shortcuts||x.Kind!=ForestRouteKind.Shortcut)){string next=e.Other(n);if(!distances.ContainsKey(next)){distances[next]=distances[n]+1;q.Enqueue(next);}}}return int.MaxValue;
        }
        public void Validate()
        {
            if(Nodes.Count<2||Nodes.Any(x=>string.IsNullOrEmpty(x.Id)||string.IsNullOrEmpty(x.Name))||Nodes.Select(x=>x.Id).Distinct().Count()!=Nodes.Count||Node(StartId)==null)throw new InvalidOperationException("Invalid map nodes");
            if(Edges.Select(x=>x.Id).Distinct().Count()!=Edges.Count)throw new InvalidOperationException("Duplicate edge IDs");
            var keys=new HashSet<string>();foreach(var e in Edges){if(string.IsNullOrEmpty(e.Id)||e.From==e.To||Node(e.From)==null||Node(e.To)==null||e.ActionCost<1||e.IntelCost<0||float.IsNaN(e.Bend)||float.IsInfinity(e.Bend)||!Enum.IsDefined(typeof(ForestRouteKind),e.Kind))throw new InvalidOperationException("Invalid edge");string key=string.CompareOrdinal(e.From,e.To)<0?e.From+"/"+e.To:e.To+"/"+e.From;if(!keys.Add(key))throw new InvalidOperationException("Duplicate connection");}
            foreach(var n in Nodes)if(float.IsNaN(n.X)||float.IsNaN(n.Y)||n.X<0||n.X>1||n.Y<0||n.Y>1||!Enum.IsDefined(typeof(ForestNodeKind),n.Kind)||Distance(StartId,n.Id,false)==int.MaxValue)throw new InvalidOperationException("Unreachable or invalid node "+n.Id);
            for(int i=0;i<PatrolRoute.Count;i++)if(Node(PatrolRoute[i])==null||Distance(PatrolRoute[i],PatrolRoute[(i+1)%PatrolRoute.Count],false)!=1)throw new InvalidOperationException("Invalid environmental patrol route");
        }
        public static ForestMapDefinition Generate(int seed,bool jitter=true)
        {
            var map=new ForestMapDefinition{Seed=seed};
            float[,] positions={{.08f,.77f},{.19f,.67f},{.12f,.48f},{.08f,.25f},{.26f,.19f},{.32f,.37f},{.24f,.49f},{.37f,.61f},{.31f,.82f},{.49f,.81f},{.54f,.65f},{.56f,.43f},{.46f,.25f},{.54f,.08f},{.69f,.19f},{.74f,.36f},{.73f,.60f},{.84f,.78f},{.94f,.63f},{.92f,.19f},{.86f,.45f},{.88f,.08f},{.10f,.94f},{.68f,.91f},{.93f,.89f},{.37f,.07f},{.95f,.38f},{.40f,.43f}};
            ForestNodeKind[] kinds={ForestNodeKind.Spawn,ForestNodeKind.Supply,ForestNodeKind.Battle,ForestNodeKind.Lookout,ForestNodeKind.Event,ForestNodeKind.Hideout,ForestNodeKind.Passage,ForestNodeKind.Camp,ForestNodeKind.Supply,ForestNodeKind.Danger,ForestNodeKind.Lookout,ForestNodeKind.Center,ForestNodeKind.Elite,ForestNodeKind.Spawn,ForestNodeKind.Supply,ForestNodeKind.Danger,ForestNodeKind.Hideout,ForestNodeKind.Event,ForestNodeKind.Elite,ForestNodeKind.Exit,ForestNodeKind.Shop,ForestNodeKind.Passage,ForestNodeKind.Spawn,ForestNodeKind.Supply,ForestNodeKind.Camp,ForestNodeKind.Danger,ForestNodeKind.Spawn,ForestNodeKind.Battle};
            string[] names={"猎林入口","遗落行囊","焚木哨卡","断枝瞭望","灰碑残迹","寂静树洞","倒悬石门","旧猎人营","余火补给","孢雾沼泽","鸦巢高台","烬心祭坛","行刑者林地","北境旧道","破损货车","咒灰裂地","荆棘暗窝","无名旅人","暮色墓园","归途石门","废林行商","裂隙石门","荒弃入口","猎人藏匣","落叶营火","血棘深处","东境旧道","断墙伏击"};
            var random=new Random(seed);for(int i=0;i<kinds.Length;i++)map.Nodes.Add(new ForestNode("n"+i,positions[i,0]+(jitter?(float)(random.NextDouble()-.5)*.022f:0),positions[i,1]+(jitter?(float)(random.NextDouble()-.5)*.022f:0),kinds[i],names[i]));
            int[,] links={{0,1,0},{1,2,0},{2,3,0},{3,4,0},{4,12,0},{12,11,0},{11,15,0},{15,20,0},{20,19,0},{0,22,1},{1,8,1},{8,7,2},{1,7,0},{2,6,1},{6,5,1},{5,4,2},{5,27,0},{27,7,2},{27,11,0},{7,10,0},{10,9,2},{9,8,2},{9,23,1},{23,24,2},{24,17,1},{17,16,0},{16,10,2},{16,20,0},{15,16,2},{15,14,0},{14,13,1},{13,12,2},{12,25,1},{25,4,2},{14,21,1},{21,19,2},{20,26,1},{26,19,2},{17,18,1},{18,20,2},{6,21,3},{9,18,3}};
            for(int i=0;i<links.GetLength(0);i++)map.Edges.Add(new ForestEdge{Id="e"+i,From="n"+links[i,0],To="n"+links[i,1],Kind=(ForestRouteKind)links[i,2],Bend=(i%2==0?1:-1)*(.035f+(float)random.NextDouble()*.035f),Hidden=i==40,ActionCost=i>=40?2:1,IntelCost=i>=40?1:0});
            if(jitter)
            {
                if(random.Next(2)==1){map.Node("n8").Kind=ForestNodeKind.Event;map.Node("n8").Name="倒塌猎棚";map.Node("n17").Kind=ForestNodeKind.Supply;map.Node("n17").Name="弃置行囊";}
                int[,] variants={{1,6},{7,9},{8,23}};for(int i=0;i<3;i++)if(random.Next(2)==1)map.Edges.Add(new ForestEdge{Id="variant"+i,From="n"+variants[i,0],To="n"+variants[i,1],Kind=ForestRouteKind.Loop,Bend=.05f});
            }
            map.PatrolRoute.AddRange(new[]{"n15","n14","n13","n12","n11"});map.Validate();return map;
        }
        public string Serialize()
        {
            var b=new StringBuilder();b.AppendLine("FOREST|1|"+Seed+"|"+StartId);
            foreach(var n in Nodes)b.AppendLine("N|"+n.Id+"|"+n.X.ToString("R",CultureInfo.InvariantCulture)+"|"+n.Y.ToString("R",CultureInfo.InvariantCulture)+"|"+n.Kind+"|"+n.Name);
            foreach(var e in Edges)b.AppendLine("E|"+e.Id+"|"+e.From+"|"+e.To+"|"+e.Kind+"|"+e.Hidden+"|"+e.ActionCost+"|"+e.IntelCost+"|"+e.Bend.ToString("R",CultureInfo.InvariantCulture));if(PatrolRoute.Count>0)b.AppendLine("P|"+string.Join("|",PatrolRoute.ToArray()));return b.ToString();
        }
        public static ForestMapDefinition Parse(string text)
        {
            var map=new ForestMapDefinition();foreach(string line in text.Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries))
            {
                var p=line.Split('|');if(p[0]=="FOREST"){if(p.Length!=4||p[1]!="1")throw new FormatException("Unsupported forest preset");map.Seed=int.Parse(p[2],CultureInfo.InvariantCulture);map.StartId=p[3];}
                else if(p[0]=="N"&&p.Length==6)map.Nodes.Add(new ForestNode(p[1],float.Parse(p[2],CultureInfo.InvariantCulture),float.Parse(p[3],CultureInfo.InvariantCulture),(ForestNodeKind)Enum.Parse(typeof(ForestNodeKind),p[4]),p[5]));
                else if(p[0]=="E"&&p.Length==9)map.Edges.Add(new ForestEdge{Id=p[1],From=p[2],To=p[3],Kind=(ForestRouteKind)Enum.Parse(typeof(ForestRouteKind),p[4]),Hidden=bool.Parse(p[5]),ActionCost=int.Parse(p[6]),IntelCost=int.Parse(p[7]),Bend=float.Parse(p[8],CultureInfo.InvariantCulture)});
                else if(p[0]=="P"&&p.Length>1)map.PatrolRoute.AddRange(p.Skip(1));
                else throw new FormatException("Invalid forest preset row");
            }map.Validate();return map;
        }
    }
}

