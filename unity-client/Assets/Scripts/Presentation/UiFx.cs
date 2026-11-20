using System;
using System.Collections.Generic;
using UnityEngine;

namespace ClashRoguelike
{
    /// 界面反馈的 Unity 侧：指针换算、自绘按钮、卡片、数值滚动。
    ///
    /// 规矩：
    /// - 动画状态只在 Update() 里推进。OnGUI 每帧要跑 Layout / Repaint 两遍，
    ///   在 OnGUI 里累加时间会让速度翻倍。
    /// - 缩放只作用在绘制上，热区永远用原矩形。
    /// - 自绘按钮自己拿 control id，不套 GUI.Button，否则同帧触发两次。
    /// - 不调用 evt.Use()。拖拽连线那条链还要用同一个 MouseDown。
    public sealed partial class BattleGame
    {
        readonly UiFeedback uiFx=new UiFeedback();
        readonly Dictionary<string,UiNumber> uiNumbers=new Dictionary<string,UiNumber>();
        readonly Dictionary<string,UiPulse> uiPulses=new Dictionary<string,UiPulse>();
        readonly Dictionary<string,int> uiCountLast=new Dictionary<string,int>();
        float uiTime;
        Vector2 uiProbeMarker;
        bool uiProbeMarkerVisible;
        AudioSource uiAudio;
        AudioClip uiPressClip,uiConfirmClip,uiDenyClip,uiSegmentClip,uiHoverClip;

        /// 实测用：在指针位置画一块洋红标记，截像素看它落在哪。
        void DrawUiProbeMarker()
        {
            Fill(new Rect(uiProbeMarker.x-6f,uiProbeMarker.y-6f,12f,12f),new Color(1f,0f,1f,1f));
        }

        /// 动效强度：0 关 / 1 标准 / 2 丰富。0 档只换颜色，不缩放不抖动。
        public int UiMotionLevel
        {
            get { return uiFx.MotionLevel; }
            set
            {
                uiFx.MotionLevel=value;
                if(!uiFx.MotionEnabled)StopImpactShake();
            }
        }

        public static float UiDesignScale()
        {
            return Mathf.Min(Screen.width/CanvasWidth,Screen.height/CanvasHeight);
        }

        /// 动画推进。只在 Update() 里调。
        void UiTick(float dt)
        {
            if(dt>0.1f) dt=0.1f;
            if(dt<0f) dt=0f;
            uiTime+=dt;
            uiFx.Tick(dt);
            ShakeTick(dt);
            foreach(KeyValuePair<string,UiNumber> pair in uiNumbers) pair.Value.Tick(dt);
            foreach(KeyValuePair<string,UiPulse> pair in uiPulses) pair.Value.Tick(dt);
            foreach(KeyValuePair<string,UiFlash> pair in uiFlashes) pair.Value.Tick(dt);
            foreach(KeyValuePair<string,UiEntrance> pair in uiEntrances) pair.Value.Tick(dt);
            if(uiLastKeyFlashTime>0f) uiLastKeyFlashTime-=dt;
            if(uiClashSweep>0f) uiClashSweep-=dt;
        }

        // ── 设置项 ──────────────────────────────────────────────────────────
        public const string UiPrefsPrefix="clash.ui.";

        /// 读取存档里的界面设置。声音档为 0 时战斗音也一起关。
        public void UiLoadSettings()
        {
            uiFx.MotionLevel=PlayerPrefs.GetInt(UiPrefsPrefix+"motion",1);
            if(uiFx.MotionLevel<0||uiFx.MotionLevel>2) uiFx.MotionLevel=1;
            uiFx.UiSoundLevel=PlayerPrefs.GetInt(UiPrefsPrefix+"sound",1);
            if(uiFx.UiSoundLevel<0||uiFx.UiSoundLevel>2) uiFx.UiSoundLevel=1;
            uiFx.SoundTier=PlayerPrefs.GetInt(UiPrefsPrefix+"tier",2);
            if(uiFx.SoundTier<0||uiFx.SoundTier>2) uiFx.SoundTier=2;
            muted=uiFx.SoundTier==0;
            if(audioSource!=null) audioSource.mute=muted;
        }

        public void UiSaveSettings()
        {
            PlayerPrefs.SetInt(UiPrefsPrefix+"motion",uiFx.MotionLevel);
            PlayerPrefs.SetInt(UiPrefsPrefix+"sound",uiFx.UiSoundLevel);
            PlayerPrefs.SetInt(UiPrefsPrefix+"tier",uiFx.SoundTier);
            PlayerPrefs.Save();
        }

        /// 顶栏设置条：动效强度 / 界面音效 / 声音档。
        void DrawUiSettingsStrip()
        {
            string motion=uiFx.MotionLevel<=0?"关":uiFx.MotionLevel==1?"标准":"丰富";
            if(UiButton("settings.motion",new Rect(36,26,116,28),"动效 "+motion,false,true))
            {
                UiMotionLevel=(UiMotionLevel+1)%3;
                UiSaveSettings();
            }
            string uiSound=uiFx.UiSoundLevel<=0?"关":uiFx.UiSoundLevel==1?"按键":"全开";
            if(UiButton("settings.sound",new Rect(162,26,100,28),"音效 "+uiSound,false,true))
            {
                uiFx.UiSoundLevel=(uiFx.UiSoundLevel+1)%3;
                UiSaveSettings();
            }
            string tier=uiFx.SoundTier<=0?"全关":uiFx.SoundTier==1?"仅战斗":"全开";
            if(UiButton("settings.tier",new Rect(272,26,132,28),"声音 "+tier,false,true))
            {
                uiFx.SoundTier=(uiFx.SoundTier+1)%3;
                muted=uiFx.SoundTier==0;
                if(audioSource!=null) audioSource.mute=muted;
                UiSaveSettings();
            }
        }

        // ── 界面音 ──────────────────────────────────────────────────────────
        // 独立声源，不跟战斗音共用 0.25 的总音量。
        public void UiInitAudio()
        {
            if(uiAudio==null)
            {
                uiAudio=gameObject.AddComponent<AudioSource>();
                uiAudio.playOnAwake=false;
                uiAudio.volume=1f;
            }
            if(uiPressClip==null) uiPressClip=UiTone("ui press",760f,0.045f);
            if(uiConfirmClip==null) uiConfirmClip=UiSweep("ui confirm",660f,990f,0.12f);
            if(uiDenyClip==null) uiDenyClip=UiTone("ui deny",180f,0.12f);
            if(uiSegmentClip==null) uiSegmentClip=UiTone("ui segment",520f,0.03f);
            if(uiHoverClip==null) uiHoverClip=UiTone("ui hover",880f,0.02f);
        }

        /// 单音。短促、带衰减，避免和战斗音混成一团。
        static AudioClip UiTone(string name,float frequency,float length)
        {
            const int rate=22050;
            var data=new float[(int)(rate*length)];
            for(int i=0;i<data.Length;i++)
            {
                float t=(float)i/rate;
                data[i]=Mathf.Sin(2f*Mathf.PI*frequency*t)*Mathf.Exp(-30f*t)*0.45f;
            }
            var clip=AudioClip.Create(name,data.Length,1,rate,false);
            clip.SetData(data,0);
            return clip;
        }

        /// 双音上行，用来做「确认」。
        static AudioClip UiSweep(string name,float from,float to,float length)
        {
            const int rate=22050;
            var data=new float[(int)(rate*length)];
            for(int i=0;i<data.Length;i++)
            {
                float t=(float)i/rate;
                float u=(float)i/data.Length;
                float frequency=from+(to-from)*u;
                data[i]=Mathf.Sin(2f*Mathf.PI*frequency*t)*Mathf.Exp(-12f*t)*0.45f;
            }
            var clip=AudioClip.Create(name,data.Length,1,rate,false);
            clip.SetData(data,0);
            return clip;
        }

        void UiPlay(AudioClip clip,float volume)
        {
            if(clip==null||uiAudio==null||!uiFx.UiSoundAllowed)return;
            uiAudio.PlayOneShot(clip,volume);
        }

        public void UiSoundPress(){ UiPlay(uiPressClip,0.14f); }
        public void UiSoundConfirm(){ UiPlay(uiConfirmClip,0.16f); }
        public void UiSoundDeny(){ UiPlay(uiDenyClip,0.16f); }
        public void UiSoundSegment(){ UiPlay(uiSegmentClip,0.10f); }

        /// 悬停音比按键音轻，比按键音高一档才响。
        void UiSoundHover()
        {
            if(!uiFx.HoverSoundAllowed||uiHoverClip==null||uiAudio==null)return;
            uiAudio.PlayOneShot(uiHoverClip,0.07f);
        }

        // ── 指针 ────────────────────────────────────────────────────────────
        // IMGUI 的 Event 坐标跟着 GUI.matrix 走，和设计空间是同一套坐标。
        // 解析换算是给 OnGUI 外面用的兜底（拖拽连线、探针）。
        public Vector2 uiProbeEventPointer,uiProbeAnalyticPointer,uiProbeGuiPoint;
        public bool uiProbePointerValid;
        public string uiProbeEventType="none";
        public int uiPointerCalls;
        public int uiMouseDowns,uiMouseUps,uiClicksFired;

        /// 指针在 1440×900 设计空间里的位置。
        public Vector2 UiPointer()
        {
            Vector2 analytic=UiAnalyticPointer();
            Event current=Event.current;
            uiPointerCalls++;
            if(current!=null)
            {
                uiProbeEventPointer=current.mousePosition;
                uiProbeAnalyticPointer=analytic;
                uiProbeGuiPoint=GUIUtility.ScreenToGUIPoint(Input.mousePosition);
                uiProbeEventType=current.type.ToString();
                uiProbePointerValid=true;
                // Layout and repaint events may carry an unset pointer even with a valid native cursor.
                if(current.isMouse)return current.mousePosition;
            }
            return analytic;
        }

        /// 屏幕像素（左下原点）换算到设计空间（左上原点）。
        public Vector2 UiAnalyticPointer()
        {
            var layout=UiContentBounds();
            float scale=layout.width/CanvasWidth;
            Vector2 mouse=Input.mousePosition;
            float offX=layout.x,offY=layout.y;
            return new Vector2((mouse.x-offX)/scale,(Screen.height-mouse.y-offY)/scale);
        }

        // ── 按钮 ────────────────────────────────────────────────────────────
        /// 自绘按钮。返回这一帧有没有被点中。
        bool UiButton(string id,Rect r,string label,bool primary,bool enabled,bool busy=false)
        {
            UiWidget widget=uiFx.Widget(id);
            widget.Enabled=enabled;
            if(!widget.LabelReady) widget.SetLabelInstant(label); else widget.SetLabel(label);
            int controlId=GUIUtility.GetControlID(FocusType.Passive);
            bool over=enabled&&r.Contains(UiPointer());
            widget.SetHover(over);
            if(widget.HoverEntered){ widget.HoverEntered=false; UiSoundHover(); }
            UiPointerButton(widget,r,enabled,controlId);
            DrawUiButton(r,widget,primary,busy);
            return widget.TakeClick();
        }

        void UiPointerButton(UiWidget widget,Rect r,bool enabled,int controlId)
        {
            Event e=Event.current;
            if(e==null) return;
            if(e.type==EventType.MouseDown&&e.button==0)
            {
                uiMouseDowns++;
                if(enabled&&r.Contains(UiPointer()))
                {
                    widget.SetPressed(true);
                    GUIUtility.hotControl=controlId;
                    UiSoundPress();
                }
            }
            else if(e.type==EventType.MouseUp&&e.button==0)
            {
                uiMouseUps++;
                if(GUIUtility.hotControl==controlId||widget.Pressed)
                {
                    bool inside=r.Contains(UiPointer());
                    if(GUIUtility.hotControl==controlId) GUIUtility.hotControl=0;
                    widget.SetPressed(false);
                    if(inside&&enabled){widget.FireClick();uiClicksFired++;}
                }
            }
            else if(e.type==EventType.MouseLeaveWindow)
            {
                if(GUIUtility.hotControl==controlId) GUIUtility.hotControl=0;
                widget.SetPressed(false);
            }
        }

        void DrawUiButton(Rect r,UiWidget widget,bool primary,bool busy)
        {
            float hover=widget.Hover;
            float press=widget.Press;
            float disable=widget.Disable;
            float scale=1f;
            if(uiFx.MotionLevel>0)
            {
                float depth=1f-UiMath.PressScale(r.height);
                scale=1f-press*depth;
            }
            Rect draw=UiScaled(r,scale);
            if(widget.Shake!=0f) draw=new Rect(draw.x+widget.Shake,draw.y,draw.width,draw.height);

            Color fill,border,fg;
            if(primary)
            {
                fill=Color.Lerp(UiActionFill,Pale,hover);
                border=UiHoverLine;
                fg=UiActionInk;
            }
            else
            {
                fill=Color.Lerp(Hex("56232E"),Hex("78303C"),hover);
                border=Color.Lerp(Hex("80414B"),UiHoverLine,hover);
                fg=Color.Lerp(Pale,Gold,hover);
            }
            if(busy)
            {
                fill=Color.Lerp(fill,Hex("4B3038"),0.55f);
                fg=Color.Lerp(fg,Muted,0.55f);
            }
            if(press>0f)
            {
                float p=Mathf.Min(1f,press);
                fill=Color.Lerp(fill,Color.Lerp(fill,Hex("210B11"),0.30f),p);
                border=Color.Lerp(border,fg,p*0.35f);
            }
            if(disable>0f)
            {
                fill=Color.Lerp(fill,Hex("34161F"),disable*0.55f);
                border=Color.Lerp(border,Hex("4B3038"),disable*0.60f);
                fg=Color.Lerp(fg,Muted,disable*0.85f);
            }
            if(widget.Deny>0f) border=Red;

            float borderWidth=(1f+Mathf.Max(0f,press))/UiStrokeScale();
            Fill(draw,border);
            Fill(new Rect(draw.x+borderWidth,draw.y+borderWidth,draw.width-2*borderWidth,draw.height-2*borderWidth),fill);
            if(primary) Outline(new Rect(draw.x+1,draw.y+1,draw.width-2,draw.height-2),Color.Lerp(fill,Pale,0.22f),1f);
            if(widget.Focus>0.01f) Outline(new Rect(draw.x-2,draw.y-2,draw.width+4,draw.height+4),Color.Lerp(fill,Cyan,widget.Focus),2f);
            if(widget.Confirm>0f&&uiFx.MotionEnabled)
            {
                float t=1f-widget.Confirm/UiMath.ConfirmLength;
                float radius=t*6f;
                Outline(new Rect(draw.x-radius,draw.y-radius,draw.width+2*radius,draw.height+2*radius),Color.Lerp(fill,Gold,t),2f);
            }

            Color textColor=fg;
            textColor.a*=widget.LabelAlpha;
            float textWidth=busy?draw.width-30f:draw.width;
            Label(draw.x,draw.y,textWidth,draw.height,widget.ShownLabel,15,textColor,TextAnchor.MiddleCenter);
            if(busy) DrawUiPulseDots(draw);
        }

        void DrawUiPulseDots(Rect draw)
        {
            for(int i=0;i<3;i++)
            {
                float phase=Mathf.Sin(uiTime*3f-i*0.9f)*0.5f+0.5f;
                Fill(new Rect(draw.xMax-24f+i*7f,draw.y+draw.height/2f-2f,4f,4f),Color.Lerp(Muted,Pale,phase*0.8f));
            }
        }

        static Rect UiScaled(Rect r,float scale)
        {
            float w=r.width*scale,h=r.height*scale;
            return new Rect(r.x+(r.width-w)/2f,r.y+(r.height-h)/2f,w,h);
        }

        /// 画布缩放比。描边宽度按它补偿，屏幕上才是恒定的 1 像素。
        float UiStrokeScale()
        {
            float scale=UiContentBounds().width/CanvasWidth;
            if(scale<0.05f) scale=0.05f;
            return scale;
        }

        // ── 卡片 ────────────────────────────────────────────────────────────
        /// 悬停抬起量。热区是 base 矩形，不跟着抬。
        float UiCardLift(string id,Rect baseRect,bool available)
        {
            UiWidget widget=uiFx.Widget(id);
            widget.Enabled=available;
            widget.SetHover(available&&baseRect.Contains(UiPointer()));
            return uiFx.RichMotion?widget.Hover*3f:0f;
        }

        Color UiCardFill(bool available,bool selected,float hover)
        {
            Color fill=available?Color.Lerp(Hex("49202A"),Hex("562833"),hover):Hex("2B121A");
            if(selected) fill=Color.Lerp(fill,Hex("742E3D"),0.65f);
            return fill;
        }

        Color UiCardBorder(bool available,bool selected,float hover)
        {
            if(selected)return UiHoverLine;
            return available?Color.Lerp(Hex("703843"),UiHoverLine,hover):Hex("4B3038");
        }

        // ── 数值 ────────────────────────────────────────────────────────────
        UiNumber UiNumberFor(string id)
        {
            UiNumber number;
            if(!uiNumbers.TryGetValue(id,out number))
            {
                number=new UiNumber();
                uiNumbers.Add(id,number);
            }
            return number;
        }

        UiPulse UiPulseFor(string id)
        {
            UiPulse pulse;
            if(!uiPulses.TryGetValue(id,out pulse))
            {
                pulse=new UiPulse();
                uiPulses.Add(id,pulse);
            }
            return pulse;
        }

        /// 变化的数字：320ms 滚动，上升闪金、下降闪红。
        void UiNumberLabel(string id,Rect r,string prefix,int value,int size,Color color,TextAnchor align=TextAnchor.UpperLeft)
        {
            UiNumber number=UiNumberFor(id);
            if(uiFx.MotionEnabled) number.Set(value); else number.SetInstant(value);
            Color c=color;
            if(number.Flash>0f) c=Color.Lerp(c,number.FlashUp?Gold:Red,number.Flash*0.85f);
            Label(r.x,r.y,r.width,r.height,prefix+number.Display,size,c,align);
        }

        /// 计数：增加时 1.15→1 弹跳并闪金。
        void UiCountLabel(string id,Rect r,int value,int size,Color color,TextAnchor align=TextAnchor.UpperLeft)
        {
            UiPulse pulse=UiPulseFor(id);
            int last;
            if(!uiCountLast.TryGetValue(id,out last)) last=value;
            if(value!=last)
            {
                if(value>last) pulse.Trigger();
                uiCountLast[id]=value;
            }
            float bounce=uiFx.RichMotion?pulse.Scale:1f;
            Rect draw=UiScaled(r,bounce);
            Color c=pulse.Active?Color.Lerp(color,Gold,pulse.Scale-1f):color;
            Label(draw.x,draw.y,draw.width,draw.height,value.ToString(),size,c,align);
        }

        // ── 键盘 / 事件反馈 ────────────────────────────────────────────────
        /// 键盘触发的等价按钮：走同一套按下反馈，并接住焦点环。
        void UiKeyPress(string id)
        {
            uiFx.SetFocus(id);
            uiFx.Widget(id).TriggerPress();
            UiFlashFor(id).Trigger();
            uiLastKeyFlashed=id;
            uiLastKeyFlashTime=UiMath.ConfirmLength;
            UiSoundPress();
        }

        void UiConfirm(string id)
        {
            uiFx.SetFocus(id);
            uiFx.Widget(id).TriggerConfirm();
            UiSoundConfirm();
        }

        void UiDeny(string id)
        {
            uiFx.Widget(id).TriggerDeny();
            UiSoundDeny();
        }

        // ── 快捷键提示行 ────────────────────────────────────────────────────
        /// 控件 id → 快捷键。绘制时登记，提示行悬停时取用。
        readonly Dictionary<string,string> uiShortcuts=new Dictionary<string,string>();
        readonly Dictionary<string,UiFlash> uiFlashes=new Dictionary<string,UiFlash>();
        string uiLastKeyFlashed="";
        float uiLastKeyFlashTime;
        /// 连线扫光：确认后沿线跑一道亮光，400ms。
        float uiClashSweep;

        /// 触发连线扫光。
        public void UiTriggerClashSweep()
        {
            uiClashSweep=0.4f;
        }

        /// 扫光进度 0..1，没在扫时返回 -1。
        public float UiClashSweepProgress
        {
            get { return uiClashSweep>0f?1f-uiClashSweep/0.4f:-1f; }
        }

        /// 颜色乘上透明度。入场淡出用。
        public static Color UiAlpha(Color color,float alpha)
        {
            color.a*=alpha;
            return color;
        }

        Color UiBattleClockColor(double seconds,Color normal)
        {
            if(seconds>10||seconds<0)return normal;
            Color warning=Hex("FF8992");
            float pulse=uiFx.MotionEnabled?.18f*(.5f+.5f*Mathf.Sin(uiTime*2*Mathf.PI)):0f;
            return Color.Lerp(warning,Pale,pulse);
        }

        /// 合法目标的描边呼吸：1.2 秒一个周期，幅度 15%。
        public Color UiBreathingBorder(Color color,float phase)
        {
            if(!uiFx.RichMotion)return color;
            float wave=(float)Math.Sin(phase/1.2f*Math.PI*2f)*0.5f+0.5f;
            return Color.Lerp(color,Color.white,0.15f*wave);
        }

        /// 登记一个控件的快捷键。键帽文字用得短最好，最多两三个字符。
        public void UiSetShortcut(string id,string keys)
        {
            if(string.IsNullOrEmpty(id))return;
            uiShortcuts[id]=keys??"";
        }

        public string UiShortcut(string id)
        {
            string keys;
            if(string.IsNullOrEmpty(id))return "";
            return uiShortcuts.TryGetValue(id,out keys)?keys:"";
        }

        UiFlash UiFlashFor(string id)
        {
            UiFlash flash;
            if(!uiFlashes.TryGetValue(id,out flash))
            {
                flash=new UiFlash();
                uiFlashes.Add(id,flash);
            }
            return flash;
        }

        // ── 翻页入场 ──────────────────────────────────────────────────────────
        readonly Dictionary<string,UiEntrance> uiEntrances=new Dictionary<string,UiEntrance>();
        int uiLastPortPage=-1;

        UiEntrance UiEntranceFor(string id)
        {
            UiEntrance entrance;
            if(!uiEntrances.TryGetValue(id,out entrance))
            {
                entrance=new UiEntrance();
                uiEntrances.Add(id,entrance);
            }
            return entrance;
        }

        /// 翻页时把新一页的卡片按顺序错开触发入场。direction=1 前进，-1 后退。
        public void UiTriggerPageEntrance(int direction,System.Collections.Generic.IList<string> cardIds)
        {
            for(int i=0;i<cardIds.Count;i++)
            {
                UiEntrance entrance=UiEntranceFor(cardIds[i]);
                entrance.Trigger(i*0.045f,direction);
            }
        }

        /// 记录当前页。返回 0 表示没翻页，返回 ±1 表示翻页方向（绕回也算前进）。
        public int UiPortPageChanged(int page,int pageCount)
        {
            if(uiLastPortPage==page) return 0;
            bool first=uiLastPortPage<0;
            int dir=1;
            if(!first&&pageCount>0)
            {
                int delta=(page-uiLastPortPage+pageCount*2)%pageCount;
                dir=delta>pageCount/2?-1:1;
            }
            uiLastPortPage=page;
            return first?0:dir;
        }

        /// 当前悬停控件的快捷键。没有就空。
        public string UiHoverShortcut()
        {
            return UiShortcut(uiFx.HoveredId);
        }

        /// 提示行：左侧原有说明，右侧贴一枚键帽。键帽在快捷键按下时闪一下。
        public void UiHintLine(Rect r,string text,int size=12)
        {
            Label(r.x,r.y,r.width,r.height,text,size,Muted);
            string shortcut=UiHoverShortcut();
            float flash=0f;
            if(uiLastKeyFlashed!=""&&uiLastKeyFlashTime>0f)
            {
                string flashed=UiShortcut(uiLastKeyFlashed);
                if(flashed!=""){ shortcut=flashed; flash=1f-uiLastKeyFlashTime/UiMath.ConfirmLength; }
            }
            if(shortcut=="")return;
            float keyWidth=shortcut.Length*(size+2)+14f;
            Rect key=new Rect(r.xMax-keyWidth-2f,r.y+1f,keyWidth,r.height-2f);
            Color ink=Color.Lerp(Gold,Color.white,flash);
            Fill(key,Color.Lerp(new Color(0f,0f,0f,0.35f),Gold,0.22f+flash*0.45f));
            Outline(key,ink,1f);
            Label(key.x,key.y,key.width,key.height,shortcut,size,ink,TextAnchor.MiddleCenter);
        }
    }
}
