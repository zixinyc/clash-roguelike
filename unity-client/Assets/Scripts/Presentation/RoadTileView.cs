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

        static Vector2 RoadProjected(ForestNode node)
        {
            int column = ForestMapDefinition.RoadColumn(node);
            int row = ForestMapDefinition.RoadRow(node);
            return new Vector2((55 + column*97 + row*23)/1028f,(69 + column*16 + row*65)/664f);
        }

        static string RoadCoordinate(ForestNode node)
        {
            return (ForestMapDefinition.RoadColumn(node)+1)+"列 "+(ForestMapDefinition.RoadRow(node)+1)+"行";
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
                Line(a+RoadDepth,b+RoadDepth,Hex("101D1D"),13);
                Line(a,b,color,edge.Kind==ForestRouteKind.Main?11:8);
            }

            ForestNode hovered=null;
            foreach(var tile in shown)
            {
                var point=LayerPoint(tile);
                if(InsideFace(Event.current.mousePosition-point,RoadTop))hovered=tile;
                bool visible=intel.Visible.Contains(tile.Id);
                bool here=tile.Id==forest.Position, selected=tile.Id==forest.Selected;
                bool move=forest.CanMove(tile.Id), road=tile.Kind==ForestNodeKind.Road;
                Color accent=road?Hex("92ABA0"):LayerColor(tile.Kind);
                Color top=visible?Hex("2A4542"):Hex("1D3030");
                if(!road)top=Color.Lerp(top,accent,visible?.25f:.15f);
                if(here)top=Hex("48665A");
                Color rim=here?Cyan:selected?Hex("E9CB91"):move?Gold:Hex("58756A");
                var bounds=new Rect(point.x-54,point.y-39,108,86);
                PaintRoadMask(roadEastMask,bounds,Hex("132323"));
                PaintRoadMask(roadSouthMask,bounds,Hex("182C29"));
                PaintRoadMask(roadTopMask,bounds,top);
                for(int index=0;index<4;index++)
                    Line(point+RoadTop[index],point+RoadTop[(index+1)%4],rim,here||selected||move?2:1);

                foreach(var edge in edges.Where(e=>e.From==tile.Id||e.To==tile.Id))
                {
                    var delta=LayerPoint(forest.Map.Node(edge.Other(tile.Id)))-point;
                    Color seam=edge.Hidden?Hex("BA99CD"):intel.Travelled.Contains(edge.Id)?Gold:accent;
                    Line(point+delta*.32f,point+delta*.43f,seam,road?4:3);
                }
                if(!road)
                {
                    Label(point.x-40,point.y-13,80,24,tile.Name,14,visible?Pale:Muted,TextAnchor.MiddleCenter);
                    if(forest.Cleared.Contains(tile.Id))
                        Label(point.x-28,point.y+7,56,14,"已结算",10,accent,TextAnchor.MiddleCenter);
                }
                else if(here||selected)
                    Label(point.x-31,point.y-12,62,23,here?"所在格":"石径",12,here?Cyan:Pale,TextAnchor.MiddleCenter);
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
