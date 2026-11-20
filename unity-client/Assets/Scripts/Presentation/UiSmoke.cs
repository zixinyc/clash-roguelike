using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using UnityEngine;

namespace ClashRoguelike
{
    /// 指针坐标实测。--ui-smoke=<folder>
    ///
    /// 要回答三个问题：
    /// 1. Event.current.mousePosition 落在哪套坐标里（设计空间 / 屏幕像素）。
    /// 2. 解析换算出来的指针，是不是真的在系统光标底下。
    /// 3. 悬停和点击走的是不是同一套坐标。
    ///
    /// 办法：不碰系统光标，直接往游戏窗口发鼠标消息，
    /// 固定把指针按到已知的设计坐标上，截像素看洋红标记落在哪，再按一次左键。
    public sealed partial class BattleGame
    {
        [StructLayout(LayoutKind.Sequential)] struct UiPoint { public int x,y; }
        [StructLayout(LayoutKind.Sequential)] struct UiRect { public int left,top,right,bottom; }
        [DllImport("user32.dll")] static extern IntPtr GetActiveWindow();
        [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hWnd,out UiRect rect);
        [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hWnd,ref UiPoint point);
        [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hWnd,uint msg,IntPtr wParam,IntPtr lParam);
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);

        const uint UiMouseLeftDown=0x0002,UiMouseLeftUp=0x0004;
        const uint UiWmMouseMove=0x0200,UiWmLeftButtonDown=0x0201,UiWmLeftButtonUp=0x0202;
        Color32[] uiProbePixels;
        int uiProbeWidth,uiProbeHeight;
        int uiProbeClientX,uiProbeClientY;

        IEnumerator UiSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            var report=new StringBuilder();
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;speed=4;
            Screen.SetResolution(1440,900,false);
            yield return null;yield return null;yield return null;
            OpenPortBattle(false);
            ConfirmSkillGroups();
            yield return null;yield return null;
            UiFocusWindow();
            for(int i=0;i<8;i++){UiTick(0.03f);yield return null;}

            yield return Capture(folder,"ui-frame-battle-large");
            report.AppendLine(UiPointerSpaceReport("idle"));
            bool moved=false;
            for(int attempt=0;attempt<3&&!moved;attempt++)
            {moved=UiPointTo(510f,585f);yield return null;yield return null;}
            if(moved)
            {
                for(int i=0;i<12;i++){UiTick(0.05f);yield return null;}
                report.AppendLine(UiPointerSpaceReport("hover"));
                yield return UiProbeCapture(folder,"ui-probe-hover");
                report.AppendLine(UiProbeMarkerReport());
                report.AppendLine(UiProbeHoverReport());
                int before=portShown.PlanCount;
                yield return UiSyntheticClick();
                for(int i=0;i<6;i++){UiTick(0.05f);yield return null;}
                report.AppendLine("CLICK planCount before="+before+" after="+portShown.PlanCount);
                SmokeCheck(portShown.PlanCount>before,"a synthetic click must trigger the button under the cursor");
                yield return UiProbeCapture(folder,"ui-probe-clicked");

                // 设置条：点一下「动效」，档位应该转一档。
                int motionBefore=UiMotionLevel;
                bool settingsMoved=false;
                for(int attempt=0;attempt<3&&!settingsMoved;attempt++)
                {settingsMoved=UiPointTo(94f,40f);yield return null;yield return null;}
                if(settingsMoved)
                {
                    yield return UiSyntheticClick();yield return null;yield return null;
                    report.AppendLine("SETTINGS motion before="+motionBefore+" after="+UiMotionLevel);
                    SmokeCheck(UiMotionLevel!=motionBefore,"the motion setting must cycle when clicked");
                    UiMotionLevel=motionBefore;UiSaveSettings();

                    // 提示行：悬停主按钮，右侧该出现 Enter 键帽。
                    bool hintMoved=false;
                    for(int attempt=0;attempt<3&&!hintMoved;attempt++)
                    {hintMoved=UiPointTo(720f,585f);yield return null;yield return null;}
                    if(hintMoved)
                    {
                        for(int i=0;i<12;i++){UiTick(0.05f);yield return null;}
                        report.AppendLine("HINT shortcut='"+UiHoverShortcut()+"'");
                        SmokeCheck(UiHoverShortcut()=="Enter","hovering the primary button must show its shortcut");
                        yield return UiProbeCapture(folder,"ui-probe-hint");
                    }
                    else report.AppendLine("HINT_UNAVAILABLE the primary button could not be reached");
                }
                else report.AppendLine("SETTINGS_UNAVAILABLE the settings strip could not be reached");
            }
            else report.AppendLine("POINTER_UNAVAILABLE the pointer probe could not reach the game window");

            Screen.SetResolution(1000,650,false);
            yield return null;yield return null;yield return null;
            uiProbeMarkerVisible=false;
            OpenPortBattle(false);ConfirmSkillGroups();yield return null;
            yield return Capture(folder,"ui-frame-battle-small");
            report.AppendLine(UiPointerSpaceReport("small-idle"));
            bool movedSmall=false;
            for(int attempt=0;attempt<3&&!movedSmall;attempt++)
            {movedSmall=UiPointTo(510f,585f);yield return null;yield return null;}
            if(movedSmall)
            {
                for(int i=0;i<12;i++){UiTick(0.05f);yield return null;}
                report.AppendLine(UiPointerSpaceReport("small-hover"));
                yield return UiProbeCapture(folder,"ui-probe-small");
                report.AppendLine(UiProbeMarkerReport());
                int before=portShown.PlanCount;
                yield return UiSyntheticClick();yield return null;yield return null;
                SmokeCheck(portShown.PlanCount>before,"the framed battle button accepts a click at the small window size");
                report.AppendLine("SMALL_CLICK planCount before="+before+" after="+portShown.PlanCount);
            }
            else report.AppendLine("POINTER_UNAVAILABLE small");

            uiProbeMarkerVisible=false;
            var portrait=PortPortraitRect(PortActorX(false,0)).center;
            bool enemyReached=false;
            for(int attempt=0;attempt<3&&!enemyReached;attempt++)
            {enemyReached=UiPointTo(portrait.x,portrait.y);yield return null;yield return null;}
            if(enemyReached)
            {
                yield return UiSyntheticClick();yield return null;yield return null;
                SmokeCheck(enemySkillDetails!=null&&enemySkillDetails.Length==3,"plain battle portrait opens its possible enemy skill list");
                report.AppendLine("ENVIRONMENT_ENEMY_SKILL_CLICK passed");
                uiProbeMarkerVisible=false;
                yield return Capture(folder,"ui-environment-enemy-skills");
                CloseEnemySkillDetails();
            }
            portRules=null;
            InitializeForest(48);
            yield return null;yield return null;
            var next=forest.Map.Links(forest.Position).Select(edge=>edge.Other(forest.Position)).First(forest.CanMove);
            var tile=LayerPoint(forest.Map.Node(next));
            bool tileReached=false;
            for(int attempt=0;attempt<3&&!tileReached;attempt++)
            {tileReached=UiPointTo(tile.x,tile.y);yield return null;yield return null;}
            if(tileReached)
            {
                yield return UiSyntheticClick();yield return null;yield return null;
                SmokeCheck(forest.Position==next,"the framed exploration tile accepts a click at the small window size");
                report.AppendLine("EXPLORATION_CLICK moved to "+next);
            }
            else report.AppendLine("POINTER_UNAVAILABLE exploration");
            uiProbeMarkerVisible=false;
            yield return Capture(folder,"ui-frame-exploration-small");

            File.WriteAllText(Path.Combine(folder,"ui-smoke.txt"),report.ToString());
            Debug.Log("UI_SMOKE_PASSED");
            Debug.Log(report.ToString());
            Application.Quit(0);
        }

        // ── 坐标空间：Event 到底给的是哪套 ──────────────────────────────────
        string UiPointerSpaceReport(string tag)
        {
            var bounds=UiContentBounds();
            float scale=bounds.width/CanvasWidth,offX=bounds.x,offY=bounds.y;
            var text=new StringBuilder();
            text.AppendLine("POINTER "+tag+" screen="+Screen.width+"x"+Screen.height+" scale="+scale+" off="+offX+","+offY);
            text.AppendLine("  state adventure="+adventureMode+" portRules="+(portRules!=null)+" shown="+(shown!=null)+" teamSetup="+teamSetup+" loadout="+loadoutSelecting+" pointerCalls="+uiPointerCalls);
            text.AppendLine("  event="+uiProbeEventPointer+" type="+uiProbeEventType+" valid="+uiProbePointerValid);
            text.AppendLine("  events down="+uiMouseDowns+" up="+uiMouseUps+" clicks="+uiClicksFired);
            text.AppendLine("  analytic="+uiProbeAnalyticPointer);
            text.AppendLine("  screenToGui="+uiProbeGuiPoint);
            float dx=uiProbeEventPointer.x-uiProbeAnalyticPointer.x,dy=uiProbeEventPointer.y-uiProbeAnalyticPointer.y;
            text.AppendLine("  eventMinusAnalytic="+dx+","+dy);
            text.AppendLine("  eventIsDesignSpace="+(uiProbePointerValid&&Mathf.Abs(dx)<=2f&&Mathf.Abs(dy)<=2f));
            text.AppendLine("  screenToGuiIsDesignSpace="+(uiProbePointerValid&&Mathf.Abs(uiProbeGuiPoint.x-uiProbeAnalyticPointer.x)<=2f&&Mathf.Abs(uiProbeGuiPoint.y-uiProbeAnalyticPointer.y)<=2f));
            Debug.Log(text.ToString());
            return text.ToString();
        }

        // ── 把指针按到设计坐标上 ────────────────────────────────────────────
        // 先发窗口消息，再试系统光标。两条路都记下来，看哪条能真的推动指针。
        bool UiPointTo(float designX,float designY)
        {
            var bounds=UiContentBounds();
            float scale=bounds.width/CanvasWidth,offX=bounds.x,offY=bounds.y;
            uiProbeClientX=(int)Mathf.Round(offX+designX*scale);
            uiProbeClientY=(int)Mathf.Round(offY+designY*scale);
            IntPtr pos=UiLParam(uiProbeClientX,uiProbeClientY);
            var handles=UiCandidateWindows();
            for(int attempt=0;attempt<handles.Count;attempt++)
            {
                IntPtr handle=handles[attempt];
                PostMessage(handle,UiWmMouseMove,IntPtr.Zero,pos);
                for(int i=0;i<3;i++)UiTick(0.03f);
                Vector2 analytic=UiAnalyticPointer();
                bool matched=Mathf.Abs(analytic.x-designX)<=6f&&Mathf.Abs(analytic.y-designY)<=6f;
                Debug.Log("POINTER_ATTEMPT mode=message handle="+handle+" index="+attempt+" analytic="+analytic+" matched="+matched);
                if(matched){uiProbeMarker=analytic;uiProbeMarkerVisible=true;return true;}
            }
            // 系统光标那条路
            IntPtr active=GetActiveWindow();
            UiRect client;
            UiPoint origin=new UiPoint();
            if(active!=IntPtr.Zero&&GetClientRect(active,out client)&&ClientToScreen(active,ref origin))
            {
                int screenX=origin.x+uiProbeClientX,screenY=origin.y+uiProbeClientY;
                for(int attempt=0;attempt<5;attempt++)
                {
                    SetForegroundWindow(active);
                    SetCursorPos(screenX,screenY);
                    for(int i=0;i<5;i++)UiTick(0.03f);
                    Vector2 analytic=UiAnalyticPointer();
                    bool matched=Mathf.Abs(analytic.x-designX)<=6f&&Mathf.Abs(analytic.y-designY)<=6f;
                    Debug.Log("POINTER_ATTEMPT mode=cursor attempt="+attempt+" screen="+screenX+","+screenY+" analytic="+analytic+" matched="+matched);
                    if(matched){uiProbeMarker=analytic;uiProbeMarkerVisible=true;return true;}
                }
            }
            else Debug.Log("POINTER_ATTEMPT mode=cursor unavailable");
            return false;
        }

        /// 把游戏窗口拉到前台。Unity 只有在窗口有焦点时才更新鼠标位置。
        void UiFocusWindow()
        {
            IntPtr active=GetActiveWindow();
            if(active==IntPtr.Zero)return;
            SetForegroundWindow(active);
            for(int i=0;i<10;i++)UiTick(0.05f);
        }

        static System.Collections.Generic.List<IntPtr> UiCandidateWindows()
        {
            var handles=new System.Collections.Generic.List<IntPtr>();
            try
            {
                using(var process=System.Diagnostics.Process.GetCurrentProcess())
                {
                    IntPtr main=process.MainWindowHandle;
                    if(main!=IntPtr.Zero) handles.Add(main);
                }
            }
            catch { }
            IntPtr active=GetActiveWindow();
            if(active!=IntPtr.Zero&&!handles.Contains(active)) handles.Add(active);
            return handles;
        }

        IEnumerator UiSyntheticClick()
        {
            // 两条路都发：窗口消息（不靠焦点）+ 系统鼠标事件（靠焦点）。
            IntPtr pos=UiLParam(uiProbeClientX,uiProbeClientY);
            foreach(IntPtr handle in UiCandidateWindows())
            {
                PostMessage(handle,UiWmMouseMove,IntPtr.Zero,pos);
                PostMessage(handle,UiWmLeftButtonDown,IntPtr.Zero,pos);
            }
            yield return null;yield return null;
            foreach(IntPtr handle in UiCandidateWindows())
            {
                PostMessage(handle,UiWmLeftButtonUp,IntPtr.Zero,pos);
            }
            yield return null;yield return null;
            mouse_event(UiMouseLeftDown,0,0,0,UIntPtr.Zero);
            yield return null;
            mouse_event(UiMouseLeftUp,0,0,0,UIntPtr.Zero);
            yield return null;yield return null;
        }

        static IntPtr UiWindowHandle()
        {
            try
            {
                using(var process=System.Diagnostics.Process.GetCurrentProcess()) return process.MainWindowHandle;
            }
            catch { return IntPtr.Zero; }
        }

        static IntPtr UiLParam(int x,int y)
        {
            return new IntPtr((y<<16)|(x&0xFFFF));
        }

        // ── 截图 + 找标记 ──────────────────────────────────────────────────
        IEnumerator UiProbeCapture(string folder,string name)
        {
            yield return new WaitForEndOfFrame();
            var image=new Texture2D(Screen.width,Screen.height,TextureFormat.RGB24,false);
            image.ReadPixels(new Rect(0,0,Screen.width,Screen.height),0,0);image.Apply();
            uiProbePixels=image.GetPixels32();uiProbeWidth=Screen.width;uiProbeHeight=Screen.height;
            int stride=(Screen.width*3+3)&~3;
            using(var writer=new BinaryWriter(File.Create(Path.Combine(folder,name+".bmp"))))
            {
                writer.Write((ushort)0x4d42);writer.Write(54+stride*Screen.height);writer.Write(0);writer.Write(54);
                writer.Write(40);writer.Write(Screen.width);writer.Write(Screen.height);writer.Write((ushort)1);writer.Write((ushort)24);
                writer.Write(0);writer.Write(stride*Screen.height);writer.Write(0);writer.Write(0);writer.Write(0);writer.Write(0);
                for(int y=0;y<Screen.height;y++)
                {
                    for(int x=0;x<Screen.width;x++){var p=uiProbePixels[y*Screen.width+x];writer.Write(p.b);writer.Write(p.g);writer.Write(p.r);}
                    for(int x=Screen.width*3;x<stride;x++)writer.Write((byte)0);
                }
            }
            Destroy(image);
        }

        int UiFindColor(Color32 target,out float centerX,out float centerY)
        {
            centerX=0f;centerY=0f;
            if(uiProbePixels==null)return 0;
            int count=0;
            for(int y=0;y<uiProbeHeight;y++)
            {
                for(int x=0;x<uiProbeWidth;x++)
                {
                    Color32 p=uiProbePixels[y*uiProbeWidth+x];
                    if(Math.Abs(p.r-target.r)<30&&Math.Abs(p.g-target.g)<30&&Math.Abs(p.b-target.b)<30)
                    {
                        centerX+=x;
                        centerY+=uiProbeHeight-1-y;
                        count++;
                    }
                }
            }
            if(count>0){centerX/=count;centerY/=count;}
            return count;
        }

        /// 洋红标记应该落在系统光标底下。
        string UiProbeMarkerReport()
        {
            float x,y;
            int count=UiFindColor(new Color32(255,0,255,255),out x,out y);
            var bounds=UiContentBounds();
            float scale=bounds.width/CanvasWidth,offX=bounds.x,offY=bounds.y;
            float expectX=offX+uiProbeMarker.x*scale,expectY=offY+uiProbeMarker.y*scale;
            var text=new StringBuilder();
            text.AppendLine("MARKER pixels="+count+" found="+x+","+y+" expect="+expectX+","+expectY);
            if(count>0)
            {
                float drift=Mathf.Sqrt((x-expectX)*(x-expectX)+(y-expectY)*(y-expectY));
                text.AppendLine("  drift="+drift);
                SmokeCheck(drift<=3f,"the pointer marker must land where the cursor is");
            }
            else text.AppendLine("  MARKER_NOT_FOUND the cursor is probably outside the window");
            return text.ToString();
        }

        /// 悬停时「自动安排」的描边会变成浅红色。
        string UiProbeHoverReport()
        {
            var bounds=UiContentBounds();
            float scale=bounds.width/CanvasWidth,offX=bounds.x,offY=bounds.y;
            int px=(int)Mathf.Round(offX+436f*scale),py=(int)Mathf.Round(offY+566f*scale);
            var text=new StringBuilder();
            bool highlighted=false;
            for(int dy=-2;dy<=2;dy++)
            {
                int row=uiProbeHeight-1-py-dy;
                if(uiProbePixels==null||row<0||row>=uiProbeHeight||px<0||px>=uiProbeWidth)continue;
                Color32 p=uiProbePixels[row*uiProbeWidth+px];
                if(p.r<=195||p.g<=130||p.b<=130||p.r-p.g<=22)continue;
                highlighted=true;
                text.AppendLine("HOVER pixel="+p.r+","+p.g+","+p.b+" highlighted=True");
                break;
            }
            SmokeCheck(highlighted,"hovering a button changes its border to the red and white highlight");
            return text.ToString();
        }
    }
}
