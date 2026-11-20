using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    // One procedurally painted terrain texture plus a state-derived fog mask; no screenshot background.
    public sealed class ForestMapArt
    {
        public Texture2D Terrain,Glow,Ring,Fog;
        int fogVersion=-1;
        static Color32 Shade(int r,int g,int b){return new Color32((byte)r,(byte)g,(byte)b,255);}
        public ForestMapArt(int seed)
        {
            const int w=1280,h=840;var pixels=new Color32[w*h];
            for(int y=0;y<h;y++)for(int x=0;x<w;x++)
            {
                uint n=(uint)(x*73856093^y*19349663^seed);n=(n^(n>>13))*1274126177u;int v=(int)(n&7);float dx=(x-w*.5f)/w,dy=(y-h*.5f)/h;int edge=(int)((dx*dx+dy*dy)*19);
                pixels[y*w+x]=Shade(Math.Max(7,23+v-edge),Math.Max(8,25+v-edge),Math.Max(7,23+v-edge));
            }
            var random=new System.Random(seed);
            for(int i=0;i<70;i++)
            {
                int x=random.Next(w),y=random.Next(h),len=random.Next(12,70);Color32 c=Shade(31,32,28);
                Stroke(pixels,w,h,x,y,x+len,y+random.Next(-10,11),c,random.Next(2,6));
            }
            for(int i=0;i<170;i++)
            {
                int x=random.Next(-20,w+20),y=random.Next(40,h+120),height=random.Next(55,150);int lean=random.Next(-18,19);Color32 c=Shade(9+random.Next(8),12+random.Next(8),11+random.Next(6));
                int topX=x+lean,topY=y+height;Stroke(pixels,w,h,x-3,y,x+lean/2,y+height/2,c,4);Stroke(pixels,w,h,x+lean/2,y+height/2,topX,topY,c,3);
                for(int branch=0;branch<5;branch++)
                {
                    int sy=y+height*(3+branch)/8,sx=x+lean*(sy-y)/height,dir=(branch%2==0?1:-1),length=random.Next(15,43),ex=sx+dir*length,ey=sy+random.Next(12,38);
                    Stroke(pixels,w,h,sx,sy,ex,ey,c,2);Stroke(pixels,w,h,ex,ey,ex+dir*random.Next(3,12),ey+random.Next(8,22),c,1);
                    if(branch%2==0)Stroke(pixels,w,h,ex-dir*8,ey-6,ex+dir*9,ey-2,c,1);
                }
                Stroke(pixels,w,h,x-10,y-3,x,y+14,c,2);Stroke(pixels,w,h,x+13,y-2,x,y+12,c,2);
            }
            for(int ruin=0;ruin<7;ruin++)
            {
                int x=random.Next(70,w-100),y=random.Next(70,h-90),rw=random.Next(30,75),rh=random.Next(22,56);Color32 c=Shade(39,38,32);
                Stroke(pixels,w,h,x,y,x,y+rh,c,5);Stroke(pixels,w,h,x+rw,y,x+rw,y+rh-8,c,5);Stroke(pixels,w,h,x,y+rh,x+rw/2,y+rh+18,c,4);
                Stroke(pixels,w,h,x+rw/2,y+rh+18,x+rw,y+rh-8,c,3);Stroke(pixels,w,h,x,y,x+rw,y,c,4);
                for(int block=0;block<5;block++)Stroke(pixels,w,h,x+random.Next(rw),y+random.Next(rh),x+random.Next(rw),y+random.Next(rh),Shade(23,24,22),3);
            }
            Terrain=new Texture2D(w,h,TextureFormat.RGB24,false);Terrain.SetPixels32(pixels);Terrain.Apply();Terrain.filterMode=FilterMode.Bilinear;
            Glow=Radial(false);Ring=Radial(true);Fog=new Texture2D(320,210,TextureFormat.RGBA32,false);Fog.filterMode=FilterMode.Bilinear;
        }
        static void Stroke(Color32[] pixels,int w,int h,int x0,int y0,int x1,int y1,Color32 c,int radius)
        {
            int steps=Math.Max(Math.Abs(x1-x0),Math.Abs(y1-y0));for(int i=0;i<=steps;i++){float t=steps==0?0:(float)i/steps;int x=(int)(x0+(x1-x0)*t),y=(int)(y0+(y1-y0)*t);for(int yy=y-radius;yy<=y+radius;yy++)for(int xx=x-radius;xx<=x+radius;xx++)if(xx>=0&&xx<w&&yy>=0&&yy<h)pixels[yy*w+xx]=c;}
        }
        static Texture2D Radial(bool ring)
        {
            const int size=64;var colors=new Color[size*size];for(int y=0;y<size;y++)for(int x=0;x<size;x++){float r=new Vector2((x-31.5f)/31.5f,(y-31.5f)/31.5f).magnitude;float a=ring?Mathf.Clamp01(1-Mathf.Abs(r-.77f)*22):Mathf.Pow(Mathf.Clamp01(1-r),2.4f);colors[y*size+x]=new Color(1,1,1,a);}var texture=new Texture2D(size,size,TextureFormat.RGBA32,false);texture.SetPixels(colors);texture.Apply();return texture;
        }
          public void UpdateFog(ForestRun run,ForestIntel intel,Func<ForestNode,Vector2> project=null)
        {
            if(fogVersion==run.Version)return;fogVersion=run.Version;int w=Fog.width,h=Fog.height;var pixels=new Color32[w*h];
              if(project==null)project=n=>new Vector2(n.X,n.Y);
              var known=run.Map.Nodes.Where(n=>intel.Known.Contains(n.Id)).Select(project).ToArray();var visible=run.Map.Nodes.Where(n=>intel.Visible.Contains(n.Id)).Select(project).ToArray();
            float rememberedRadius=run.PvpFog?.014f:.035f,visibleRadius=run.PvpFog?.006f:.019f;
            for(int y=0;y<h;y++)for(int x=0;x<w;x++)
            {
                float u=(float)x/(w-1),v=1-(float)y/(h-1),dk=100,dv=100;
                  foreach(var n in known){float dx=(u-n.x)*1.5f,dy=v-n.y;dk=Math.Min(dk,dx*dx+dy*dy);}
                  foreach(var n in visible){float dx=(u-n.x)*1.5f,dy=v-n.y;dv=Math.Min(dv,dx*dx+dy*dy);}
                float k=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.005f,rememberedRadius,dk)),s=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.002f,visibleRadius,dv));float alpha=Mathf.Lerp(.94f,.63f,k);alpha=Mathf.Lerp(alpha,.08f,s);
                float cloud=Mathf.Sin(u*32+Mathf.Sin(v*17))*Mathf.Sin(v*26+u*11);alpha=Mathf.Clamp01(alpha+cloud*.025f);byte gray=(byte)(20+Math.Max(0,cloud)*10);pixels[y*w+x]=new Color32(gray,(byte)(gray+2),(byte)(gray+4),(byte)(alpha*255));
            }
            Fog.SetPixels32(pixels);Fog.Apply();
        }
        public void Dispose(){if(Terrain!=null)UnityEngine.Object.Destroy(Terrain);if(Glow!=null)UnityEngine.Object.Destroy(Glow);if(Ring!=null)UnityEngine.Object.Destroy(Ring);if(Fog!=null)UnityEngine.Object.Destroy(Fog);}
    }
}
