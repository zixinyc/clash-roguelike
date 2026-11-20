using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        static readonly Vector2 RoadColumnFace = new Vector2(42,7);
        static readonly Vector2 RoadRowFace = new Vector2(10.5f,26);
        static readonly Vector2 RoadDepth = new Vector2(0,9);
        static readonly Vector2[] RoadTop = {
            -RoadColumnFace-RoadRowFace, RoadColumnFace-RoadRowFace,
            RoadColumnFace+RoadRowFace, -RoadColumnFace+RoadRowFace
        };
        static Texture2D roadTopMask, roadEastMask, roadSouthMask;
        string pressedRoadTile;

        Vector2 RoadScale
        {
            get
            {
                int columns=forest.Map.RoadColumns-1,rows=forest.Map.RoadRows-1;
                return new Vector2(914f/(columns*97+rows*23),518f/(columns*16+rows*65));
            }
        }

        Vector2 RoadProjected(ForestNode node)
        {
            int column=forest.Map.RoadColumn(node),row=forest.Map.RoadRow(node);
            var scale=RoadScale;
            return new Vector2((55+(column*97+row*23)*scale.x)/1028f,(69+(column*16+row*65)*scale.y)/664f);
        }

        static string RoadCoordinate(ForestMapDefinition map,ForestNode node)
        {
            return (map.RoadColumn(node)+1)+"列 "+(map.RoadRow(node)+1)+"行";
        }

        static string CompactRoadName(ForestNode tile)
        {
            if(tile.Name.Length<=3)return tile.Name;
            switch(tile.Kind)
            {
                case ForestNodeKind.Spawn:return "出生点";
                case ForestNodeKind.UpwardEntrance:return "上层";
                case ForestNodeKind.DownwardTransition:return "下层";
                case ForestNodeKind.MutationStone:return "异动石";
                case ForestNodeKind.Danger:return "险地";
                case ForestNodeKind.Center:return "祭坛";
                case ForestNodeKind.Anomaly:return "异变";
                case ForestNodeKind.Eientei:return "永远亭";
                case ForestNodeKind.Encounter:return "奇遇";
                case ForestNodeKind.Lookout:return "观察";
                case ForestNodeKind.Hideout:return "隐蔽";
                case ForestNodeKind.Camp:return "营地";
                case ForestNodeKind.Shop:return "行商";
                case ForestNodeKind.Supply:return "补给";
                case ForestNodeKind.Battle:return "战斗";
                case ForestNodeKind.Elite:return "精英";
                case ForestNodeKind.Exit:return "出口";
                default:return "事件";
            }
        }

        Vector2 LayerPoint(ForestNode node)
        {
            if (!forest.Map.RoadGrid) return ForestPoint(node);
            var p = RoadProjected(node);
            return new Vector2(forestRect.x+p.x*forestRect.width,forestRect.y+p.y*forestRect.height);
        }

        static bool InsideFace(Vector2 point,Vector2[] vertices)
        {
            for(int i=0;i<4;i++)
            {
                var a=vertices[i];
                var edge=vertices[(i+1)%4]-a;
                var offset=point-a;
                if(edge.x*offset.y-edge.y*offset.x<0) return false;
            }
            return true;
        }

        static Texture2D RoadMask(Vector2[] vertices)
        {
            const int width=108,height=86;
            var texture=new Texture2D(width,height,TextureFormat.RGBA32,false);
            texture.hideFlags=HideFlags.HideAndDontSave;
            texture.filterMode=FilterMode.Bilinear;
            texture.wrapMode=TextureWrapMode.Clamp;
            var pixels=new Color32[width*height];
            for(int y=0;y<height;y++)
                for(int x=0;x<width;x++)
                    pixels[(height-1-y)*width+x]=InsideFace(new Vector2(x+.5f-54,y+.5f-39),vertices)
                        ?new Color32(255,255,255,255):new Color32(255,255,255,0);
            texture.SetPixels32(pixels);
            texture.Apply(false,true);
            return texture;
        }

        static void EnsureRoadMasks()
        {
            if(roadTopMask!=null)return;
            roadTopMask=RoadMask(RoadTop);
            roadEastMask=RoadMask(new[]{RoadTop[2],RoadTop[1],RoadTop[1]+RoadDepth,RoadTop[2]+RoadDepth});
            roadSouthMask=RoadMask(new[]{RoadTop[3],RoadTop[2],RoadTop[2]+RoadDepth,RoadTop[3]+RoadDepth});
        }

        static void PaintRoadMask(Texture2D mask,Rect bounds,Color color)
        {
            var previous=GUI.color;
            GUI.color=color;
            GUI.DrawTexture(bounds,mask);
            GUI.color=previous;
        }

        void DrawRoadTiles(ForestIntel intel)
        {
            EnsureRoadMasks();
            var scale=RoadScale;
            var depth=Vector2.Scale(RoadDepth,scale);
            var topFace=RoadTop.Select(point=>Vector2.Scale(point,scale)).ToArray();
            bool compact=forest.Map.RoadColumns>ForestMapDefinition.DefaultRoadColumns;
            var shown=forest.Map.Nodes.Where(n=>intel.Known.Contains(n.Id)).OrderBy(n=>LayerPoint(n).y).ToArray();
            var edges=forest.Map.Edges.Where(e=>intel.Known.Contains(e.From)&&intel.Known.Contains(e.To)&&
                (!e.Hidden||intel.KnownEdges.Contains(e.Id))).ToArray();
            foreach(var edge in edges)
            {
                var from=forest.Map.Node(edge.From);
                var to=forest.Map.Node(edge.To);
                var a=LayerPoint(from);
                var b=LayerPoint(to);
                bool danger=from.Kind==ForestNodeKind.Danger||to.Kind==ForestNodeKind.Danger;
                Color color=edge.Hidden?Hex("AD86C2"):danger?Hex("A77667"):intel.Travelled.Contains(edge.Id)?Hex("B3975E"):Hex("546F66");
                Line(a+depth,b+depth,Hex("101D1D"),13*scale.x);
                Line(a,b,color,(edge.Kind==ForestRouteKind.Main?11:8)*scale.x);
            }

            ForestNode hovered=null;
            foreach(var tile in shown.Select(forest.PresentTile))
            {
                var point=LayerPoint(tile);
                if(InsideFace(Event.current.mousePosition-point,topFace))hovered=tile;
                bool visible=intel.Visible.Contains(tile.Id);
                bool here=tile.Id==forest.Position, selected=tile.Id==forest.Selected;
                bool recruit=TrialActive&&forestCampaign.RecruitAvailable(tile.Id,forest.FloorIndex);
                bool move=forest.CanMove(tile.Id), road=tile.Kind==ForestNodeKind.Road&&!recruit;
                Color accent=road?Hex("92ABA0"):LayerColor(tile.Kind);
                Color top=visible?TrialAmbient():Color.Lerp(Hex("1D3030"),TrialAmbient(),.28f);
                if(!road)top=Color.Lerp(top,accent,visible?.25f:.15f);
                if(here)top=Hex("48665A");
                Color rim=here?Cyan:selected?Hex("E9CB91"):move?Gold:tile.Kind==ForestNodeKind.Exit?Gold:Hex("58756A");
                var bounds=new Rect(point.x-54*scale.x,point.y-39*scale.y,108*scale.x,86*scale.y);
                PaintRoadMask(roadEastMask,bounds,Hex("132323"));
                PaintRoadMask(roadSouthMask,bounds,Hex("182C29"));
                PaintRoadMask(roadTopMask,bounds,top);
                for(int index=0;index<4;index++)
                    Line(point+topFace[index],point+topFace[(index+1)%4],rim,here||selected||move?2:1);

                foreach(var edge in edges.Where(e=>e.From==tile.Id||e.To==tile.Id))
                {
                    var delta=LayerPoint(forest.Map.Node(edge.Other(tile.Id)))-point;
                    Color seam=edge.Hidden?Hex("BA99CD"):intel.Travelled.Contains(edge.Id)?Gold:accent;
                    Line(point+delta*.32f,point+delta*.43f,seam,road?4:3);
                }
                if(!road)
                {
                    string recruitId=recruit?forestCampaign.RecruitIdentity(tile.Id,forest.FloorIndex):"";
                    string name=!recruit?tile.Name:recruitId==PatchouliSkills.Id?"红魔馆图书馆":recruitId==RemiliaSkills.Id?"红魔馆主厅":recruitId=="flandre"?"异常声响":"咲夜挑战";
                    if(compact)name=CompactRoadName(tile);
                    Label(point.x-40*scale.x,point.y-13*scale.y,80*scale.x,24*scale.y,name,compact?13:14,visible?Pale:Muted,TextAnchor.MiddleCenter);
                    if((!forest.PvpFog||visible)&&forest.Cleared.Contains(tile.Id))
                        Label(point.x-28,point.y+7*scale.y,56,14,"已结算",10,accent,TextAnchor.MiddleCenter);
                }
                else if(here||selected)
                    Label(point.x-31,point.y-12*scale.y,62,23*scale.y,here?"所在格":"石径",12,here?Cyan:Pale,TextAnchor.MiddleCenter);
            }

            var input=Event.current;
            if(input.button!=0||input.type!=EventType.MouseDown&&input.type!=EventType.MouseUp)return;
            bool available=!forestSettings&&forest.Pending==""&&!forest.Finished;
            if(input.type==EventType.MouseDown)
            {
                pressedRoadTile=available&&hovered!=null?hovered.Id:null;
                if(pressedRoadTile!=null)input.Use();
            }
            else
            {
                string pressed=pressedRoadTile;
                pressedRoadTile=null;
                if(!available||pressed==null||hovered==null||hovered.Id!=pressed)return;
                input.Use();
                ForestClick(hovered.Id);
            }
        }
    }
}
