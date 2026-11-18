using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class ForestRandomGenerator
    {
        public static ForestMapDefinition Generate(int seed)
        {
            var r=new Random(seed);var m=new ForestMapDefinition{Seed=seed};int[] sizes={1,r.Next(2,4),r.Next(3,5),r.Next(3,5),4,r.Next(3,5),r.Next(2,4),1};
            var layers=new System.Collections.Generic.List<string[]>();int id=0;
            ForestNodeKind[] pool={ForestNodeKind.Battle,ForestNodeKind.Supply,ForestNodeKind.Event,ForestNodeKind.Hideout,ForestNodeKind.Lookout,ForestNodeKind.Danger,ForestNodeKind.Camp,ForestNodeKind.Shop,ForestNodeKind.Elite};
            for(int layer=0;layer<sizes.Length;layer++)
            {
                var names=new string[sizes[layer]];
                for(int j=0;j<names.Length;j++)
                {
                    string key="r"+id++;names[j]=key;var kind=layer==0?ForestNodeKind.Spawn:layer==7?ForestNodeKind.Exit:pool[r.Next(pool.Length)];
                    float x=.065f+layer*.123f+(float)(r.NextDouble()-.5)*.028f,y=names.Length==1?.51f:.12f+.76f*j/(names.Length-1)+(float)(r.NextDouble()-.5)*.06f;
                    m.Nodes.Add(new ForestNode(key,x,y,kind,Title(kind,r.Next(4))));
                }
                layers.Add(names);
            }
            m.StartId=layers[0][0];Set(m,layers[1][0],ForestNodeKind.Supply);Set(m,layers[1][1],ForestNodeKind.Battle);
            Set(m,layers[2][0],ForestNodeKind.Lookout);Set(m,layers[2][1],ForestNodeKind.Event);Set(m,layers[3][0],ForestNodeKind.Hideout);Set(m,layers[3][1],ForestNodeKind.Danger);
            Set(m,layers[4][1],ForestNodeKind.Center);Set(m,layers[5][0],ForestNodeKind.Elite);Set(m,layers[5][1],ForestNodeKind.Shop);Set(m,layers[6][0],ForestNodeKind.Camp);
            for(int layer=1;layer<layers.Count;layer++)
            {
                var prev=layers[layer-1];var next=layers[layer];int mainPrev=layer-1==4?1:0,mainNext=layer==4?1:0;
                Add(m,prev[mainPrev],next[mainNext],ForestRouteKind.Main,r);
                foreach(string n in next)if(!m.Links(n).Any())Add(m,prev[r.Next(prev.Length)],n,ForestRouteKind.Branch,r);
                foreach(string p in prev)if(!m.Links(p).Any(e=>next.Contains(e.Other(p))))Add(m,p,next[r.Next(next.Length)],ForestRouteKind.Branch,r);
                for(int j=0;j<next.Length;j++)if(r.NextDouble()<.65)Add(m,prev[r.Next(prev.Length)],next[j],ForestRouteKind.Loop,r);
                if(next.Length>2)Add(m,next[0],next[1],ForestRouteKind.Loop,r);
            }
            // An ordinary four-edge cycle also gives the environmental patrol a valid closed route.
            string a=layers[3][0],b=layers[4][0],c=layers[3][1],d=layers[4][1];Add(m,a,b,ForestRouteKind.Loop,r);Add(m,b,c,ForestRouteKind.Loop,r);Add(m,c,d,ForestRouteKind.Loop,r);Add(m,d,a,ForestRouteKind.Loop,r);m.PatrolRoute.AddRange(new[]{a,b,c,d});
            string from=layers[2].Last(),to=layers[6].Last();Add(m,from,to,ForestRouteKind.Shortcut,r);var shortcut=m.Edge(from,to);shortcut.Hidden=true;shortcut.ActionCost=2;shortcut.IntelCost=1;
            m.Validate();return m;
        }
        static void Set(ForestMapDefinition m,string id,ForestNodeKind kind){m.Node(id).Kind=kind;m.Node(id).Name=Title(kind,0);}
        static void Add(ForestMapDefinition m,string a,string b,ForestRouteKind kind,Random r){if(a==b||m.Edge(a,b)!=null)return;m.Edges.Add(new ForestEdge{Id="random-edge-"+m.Edges.Count,From=a,To=b,Kind=kind,Bend=(r.Next(2)==0?-1:1)*(.025f+(float)r.NextDouble()*.04f)});}
        static string Title(ForestNodeKind k,int variant){string[] prefixes={"焦木","迷雾","余烬","残月"};string suffix=k==ForestNodeKind.Spawn?"入口":k==ForestNodeKind.Exit?"归途":k==ForestNodeKind.Supply?"行囊":k==ForestNodeKind.Battle?"伏击地":k==ForestNodeKind.Event?"残碑":k==ForestNodeKind.Hideout?"树洞":k==ForestNodeKind.Lookout?"高台":k==ForestNodeKind.Danger?"险地":k==ForestNodeKind.Center?"烬心祭坛":k==ForestNodeKind.Elite?"追猎者":k==ForestNodeKind.Camp?"营火":"行商";return prefixes[variant%4]+suffix;}
    }
}
