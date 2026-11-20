using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        readonly Dictionary<string,string> portraitFiles=new Dictionary<string,string>{
            {"marisa","雾雨魔理沙.png"},{"sakuya","十六夜咲夜.png"},{"reimu","博丽灵梦.png"},
            {"flandre","芙兰朵露.png"},{RemiliaSkills.Id,"remilia.png"},{PatchouliSkills.Id,"patchouli.png"}
        };
        readonly Dictionary<string,Texture2D> portraits=new Dictionary<string,Texture2D>();
        Texture2D FindPortrait(Unit unit)
        {
            string id=unit.CharacterId;
            if(string.IsNullOrEmpty(id))foreach(var pair in portraitFiles)if(Path.GetFileNameWithoutExtension(pair.Value)==unit.Name){id=pair.Key;break;}
            if(string.IsNullOrEmpty(id)||!portraitFiles.ContainsKey(id))return null;
            Texture2D loaded;if(portraits.TryGetValue(id,out loaded))return loaded;
            loaded=null;
            try
            {
                var path=Path.Combine(Application.streamingAssetsPath,"portraits",portraitFiles[id]);
                if(File.Exists(path))
                {
                    var image=new Texture2D(2,2,TextureFormat.RGBA32,true);
                    if(image.LoadImage(File.ReadAllBytes(path),false)){PreparePortraitEdges(image);image.name="Battle portrait / "+unit.Name;image.filterMode=FilterMode.Trilinear;image.wrapMode=TextureWrapMode.Clamp;loaded=image;}
                    else Destroy(image);
                }
                if(loaded==null)Debug.LogWarning("Portrait not available: "+unit.Name+"; using original figure.");
            }
            catch(Exception e){Debug.LogWarning("Portrait could not load: "+unit.Name+" / "+e.Message);}
            portraits[id]=loaded;return loaded;
        }
        bool DrawCharacterPortrait(Unit unit,Rect bounds,bool mirrored=false)
        {
            var image=FindPortrait(unit);
            if(image==null)return false;
            float scale=Mathf.Min(bounds.width/image.width,bounds.height/image.height);
            float width=image.width*scale,height=image.height*scale;
            var fitted=new Rect(bounds.center.x-width/2,bounds.yMax-height,width,height);
            var before=GUI.color;
            GUI.color=unit.Hp<=0?new Color(.55f,.55f,.55f,.55f*before.a):before;
            GUI.DrawTextureWithTexCoords(fitted,image,mirrored?new Rect(1,0,-1,1):new Rect(0,0,1,1),true);
            GUI.color=before;
            return true;
        }
        void DisposePortraits(){foreach(var image in portraits.Values)if(image!=null)Destroy(image);portraits.Clear();}
        // Import-time texture preparation only; source PNGs are kept byte-for-byte.
        void PreparePortraitEdges(Texture2D image,bool clearWhiteCenter=false)
        {
            int width=image.width,height=image.height;var pixels=image.GetPixels32();var queue=new int[pixels.Length];int read=0,write=0,removed=0;
            for(int i=0;i<pixels.Length;i++)if(pixels[i].a==0)queue[write++]=i;
            if(clearWhiteCenter)RemoveWhiteEdge(pixels,(height/2)*width+width/2,queue,ref write,ref removed);
            while(read<write)
            {
                int i=queue[read++],x=i%width,y=i/width;
                if(x>0)RemoveWhiteEdge(pixels,i-1,queue,ref write,ref removed);
                if(x+1<width)RemoveWhiteEdge(pixels,i+1,queue,ref write,ref removed);
                if(y>0)RemoveWhiteEdge(pixels,i-width,queue,ref write,ref removed);
                if(y+1<height)RemoveWhiteEdge(pixels,i+width,queue,ref write,ref removed);
            }
            // Extend nearby foreground RGB behind alpha0 so downsampling cannot mix in a white matte.
            read=0;write=0;var colored=new bool[pixels.Length];
            for(int i=0;i<pixels.Length;i++)if(pixels[i].a>0){colored[i]=true;queue[write++]=i;}
            while(read<write)
            {
                int i=queue[read++],x=i%width,y=i/width;
                if(x>0)BleedPortraitColor(pixels,colored,i,i-1,queue,ref write);
                if(x+1<width)BleedPortraitColor(pixels,colored,i,i+1,queue,ref write);
                if(y>0)BleedPortraitColor(pixels,colored,i,i-width,queue,ref write);
                if(y+1<height)BleedPortraitColor(pixels,colored,i,i+width,queue,ref write);
            }
            image.SetPixels32(pixels);image.Apply(true,false);
            Debug.Log("PORTRAIT_ALPHA_PREPARED edge_pixels="+removed+" mip_levels="+image.mipmapCount);
        }
        static void RemoveWhiteEdge(Color32[] pixels,int i,int[] queue,ref int write,ref int removed)
        {
            Color32 p=pixels[i];if(p.a==0)return;
            int low=Math.Min(p.r,Math.Min(p.g,p.b)),high=Math.Max(p.r,Math.Max(p.g,p.b));
            if(low<235||high-low>18)return;
            p.a=0;pixels[i]=p;queue[write++]=i;removed++;
        }
        static void BleedPortraitColor(Color32[] pixels,bool[] colored,int source,int target,int[] queue,ref int write)
        {
            if(colored[target])return;colored[target]=true;var p=pixels[target];var color=pixels[source];
            p.r=color.r;p.g=color.g;p.b=color.b;pixels[target]=p;queue[write++]=target;
        }
        IEnumerator PortraitSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;OpenPortBattle(false,0,true);
            SmokeCheck(ConfirmSkillGroups(),"portrait smoke confirms prebattle group choice");
            for(int i=0;i<3;i++)
            {
                var unit=portShown.Heroes[i];var image=FindPortrait(unit);
                SmokeCheck(image!=null&&image.width==768&&image.height==1344,"matched portrait loaded: "+unit.Name);
                SmokeCheck(image.GetPixel(0,0).a<.01f,"portrait preserves transparent background: "+unit.Name);
                SmokeCheck(image.mipmapCount>1&&image.filterMode==FilterMode.Trilinear,"portrait uses minification filtering: "+unit.Name);
            }
            yield return Capture(folder,"portraits-team");
            ArrangePortAutomatically();PreparePortRound();speed=1;StartPortRound();
            while(portBusy&&(portEvent==null||portEvent.Type!="clash"||portPhase<.4f))yield return null;
            SmokeCheck(portEvent!=null&&portEvent.Type=="clash","portrait view reaches real clash");
            yield return Capture(folder,"portraits-clash");SkipPort();while(portBusy)yield return null;
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            yield return Capture(folder,"portraits-small");
            File.WriteAllText(Path.Combine(folder,"portrait-smoke.txt"),"PORTRAIT_SMOKE_PASSED\nMarisa, Sakuya and Reimu matched by character ID/name; original transparent 768x1344 PNGs; team view, actual clash, 1440x900 and 1000x650.\n");
            Debug.Log("PORTRAIT_SMOKE_PASSED");Application.Quit(0);
        }
    }
}
