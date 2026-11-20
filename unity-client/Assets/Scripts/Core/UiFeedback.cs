using System;
using System.Collections.Generic;

namespace ClashRoguelike
{
    /// 界面反馈的纯逻辑层：插值、弹簧、缩放公式、按钮状态机、数值滚动、标签淡入淡出。
    ///
    /// 这里刻意不引用 UnityEngine。Tools/BuildLocalPlayer.ps1 会在播放器之外用
    /// Assembly.LoadFrom + 反射调用各 *Checks.Run()，那条探测路径上找不到 UnityEngine 程序集，
    /// 只要检查链路里出现一个 UnityEngine 类型，反射就会 FileNotFound。
    /// 所以纯逻辑住 Core/，Unity 侧的绘制住 Presentation/UiFx.cs。
    public static class UiMath
    {
        public const float HoverIn=0.09f;
        public const float HoverOut=0.14f;
        public const float PressIn=0.04f;
        public const float DisableFade=0.18f;
        public const float DenyLength=0.18f;
        public const float ConfirmLength=0.22f;
        public const float RollLength=0.32f;
        public const float BounceLength=0.18f;
        public const float LabelFade=0.12f;
        /// 过冲比 Mp=exp(-PI*z/sqrt(1-z*z))=0.04，对应 z=0.716。
        public const float SpringZeta=0.716f;
        /// 稳定时间 4/(z*wn)≈0.12s。
        public const float SpringOmega=46.6f;
        /// 目标视觉下沉量恒定 1.6px，按按钮高度归一。
        public const float PressDepth=1.6f;
        public const float PressScaleMin=0.940f;
        public const float PressScaleMax=0.965f;

        /// 帧率无关的指数逼近：95% 到位耗时 = duration。
        public static float Approach(float value,float target,float dt,float duration)
        {
            if(duration<=0f) return target;
            if(dt<=0f) return value;
            return value+(target-value)*(1f-(float)Math.Exp(-3f*dt/duration));
        }

        /// 同上，但从 from 出发、经过 elapsed 秒后的值。
        public static float ApproachElapsed(float from,float target,float elapsed,float duration)
        {
            if(duration<=0f) return target;
            if(elapsed<=0f) return from;
            return from+(target-from)*(1f-(float)Math.Exp(-3f*elapsed/duration));
        }

        /// 二阶阻尼弹簧的解析解。z<1 时过冲量精确可控。
        public static float Spring(float t,float z,float wn,float from,float to)
        {
            if(t<=0f) return from;
            if(z>=1f)
            {
                float critical=(float)Math.Exp(-wn*t);
                return to+(from-to)*(1f+wn*t)*critical;
            }
            float wd=wn*(float)Math.Sqrt(1f-z*z);
            float decay=(float)Math.Exp(-z*wn*t);
            return to+(from-to)*decay*((float)Math.Cos(wd*t)+(z*wn/wd)*(float)Math.Sin(wd*t));
        }

        /// 缩放幅度：目标视觉下沉量恒定 1.6px，再夹到 [0.940,0.965]。
        public static float PressScale(float height)
        {
            if(height<=0f) return 1f;
            float scale=1f-PressDepth/height;
            if(scale<PressScaleMin) scale=PressScaleMin;
            if(scale>PressScaleMax) scale=PressScaleMax;
            return scale;
        }

        /// 拒绝抖动：6px 横向、3 个来回、180ms 衰减到 0（末端严格为 0，不留跳变）。
        public static float DenyShake(float elapsed)
        {
            if(elapsed<0f||elapsed>=DenyLength) return 0f;
            float fade=1f-elapsed/DenyLength;
            return 6f*(float)Math.Sin(2f*Math.PI*3f*elapsed/DenyLength)*fade*fade;
        }

        public static float EaseOutCubic(float t)
        {
            if(t<=0f) return 0f;
            if(t>=1f) return 1f;
            float u=1f-t;
            return 1f-u*u*u;
        }

        public static float Clamp(float value,float min,float max)
        {
            if(value<min) return min;
            if(value>max) return max;
            return value;
        }
    }

    /// 一个可交互控件的反馈状态。按调用点 id 存在 UiFeedback 里，跨帧保持。
    public sealed class UiWidget
    {
        public string Id="";
        public bool Enabled=true;
        public bool Selected;
        public bool Focused;

        public bool Hovered;
        /// 本帧刚进入悬停。只在 false→true 的那一帧为真，用完要自己清掉。
        public bool HoverEntered;
        public bool Pressed;
        public bool Clicked;

        public float Hover;
        /// 按下深度 0..1；回弹阶段会短暂越过 0 变成负数，那就是过冲。
        public float Press;
        public float Disable;
        public float Deny;
        public float Confirm;
        public float Shake;
        public float Focus;

        public string ShownLabel="";
        public string PendingLabel="";
        public int LabelPhase;
        public float LabelFade;
        public bool LabelReady;

        int pressPhase;
        float pressTime;
        float pressFrom;
        bool autoRelease;

        public void SetHover(bool over)
        {
            if(over&&!Hovered) HoverEntered=true;
            Hovered=over;
        }

        public void SetPressed(bool down)
        {
            if(down&&!Pressed)
            {
                Pressed=true;
                autoRelease=false;
                if(Enabled){ pressPhase=1; pressTime=0f; pressFrom=Press; }
            }
            else if(!down&&Pressed)
            {
                Pressed=false;
                autoRelease=false;
                if(Enabled&&pressPhase!=2){ pressPhase=2; pressTime=0f; pressFrom=Press; }
            }
        }

        public void FireClick()
        {
            if(Enabled) Clicked=true;
        }

        /// 键盘触发的按下：走同一套反馈，40ms 下沉后自己回弹。
        public void TriggerPress()
        {
            if(!Enabled) return;
            pressPhase=1;
            pressTime=0f;
            pressFrom=Press;
            Pressed=true;
            autoRelease=true;
        }

        public bool TakeClick()
        {
            bool taken=Clicked;
            Clicked=false;
            return taken;
        }

        public void TriggerDeny()
        {
            Deny=UiMath.DenyLength;
        }

        public void TriggerConfirm()
        {
            Confirm=UiMath.ConfirmLength;
        }

        /// 文字切换：120ms 淡出 → 换字 → 120ms 淡入，位置不动。
        public void SetLabel(string value)
        {
            if(value==null) value="";
            if(value==PendingLabel) return;
            if(value==ShownLabel&&LabelPhase==0) return;
            PendingLabel=value;
            LabelPhase=1;
            LabelFade=0f;
        }

        /// 首次出现时直接摆好，不走淡入。
        public void SetLabelInstant(string value)
        {
            ShownLabel=value==null?"":value;
            PendingLabel=ShownLabel;
            LabelPhase=0;
            LabelFade=0f;
            LabelReady=true;
        }

        public float LabelAlpha
        {
            get
            {
                if(LabelPhase==1) return 1f-UiMath.Clamp(LabelFade/UiMath.LabelFade,0f,1f);
                if(LabelPhase==2) return UiMath.Clamp(LabelFade/UiMath.LabelFade,0f,1f);
                return 1f;
            }
        }

        public void Tick(float dt)
        {
            Tick(dt,true);
        }

        /// spring = 标准档起带过冲回弹；关档只平滑回位。
        public void Tick(float dt,bool spring)
        {
            if(dt<0f) dt=0f;
            float hoverTarget=(Enabled&&Hovered)?1f:0f;
            float hoverDuration=hoverTarget>Hover?UiMath.HoverIn:UiMath.HoverOut;
            Hover=UiMath.Approach(Hover,hoverTarget,dt,hoverDuration);
            Disable=UiMath.Approach(Disable,Enabled?0f:1f,dt,UiMath.DisableFade);
            Focus=UiMath.Approach(Focus,Focused?1f:0f,dt,0.10f);

            if(pressPhase==1)
            {
                pressTime+=dt;
                Press=UiMath.ApproachElapsed(pressFrom,1f,pressTime,UiMath.PressIn);
                if(autoRelease&&pressTime>=UiMath.PressIn)
                {
                    pressPhase=2;
                    pressTime=0f;
                    pressFrom=Press;
                    Pressed=false;
                    autoRelease=false;
                }
            }
            else if(pressPhase==2)
            {
                pressTime+=dt;
                Press=spring
                    ?UiMath.Spring(pressTime,UiMath.SpringZeta,UiMath.SpringOmega,pressFrom,0f)
                    :UiMath.ApproachElapsed(pressFrom,0f,pressTime,0.12f);
                if(pressTime>=0.40f||Math.Abs(Press)<0.001f){ Press=0f; pressPhase=0; }
            }

            if(Deny>0f)
            {
                Deny-=dt;
                if(Deny<0f) Deny=0f;
            }
            Shake=UiMath.DenyShake(UiMath.DenyLength-Deny);
            if(Confirm>0f)
            {
                Confirm-=dt;
                if(Confirm<0f) Confirm=0f;
            }

            if(LabelPhase==1)
            {
                LabelFade+=dt;
                if(LabelFade>=UiMath.LabelFade){ ShownLabel=PendingLabel; LabelPhase=2; LabelFade=0f; LabelReady=true; }
            }
            else if(LabelPhase==2)
            {
                LabelFade+=dt;
                if(LabelFade>=UiMath.LabelFade){ LabelPhase=0; LabelFade=0f; }
            }
        }
    }

    /// 控件注册表。按显式 id 取，同一 id 跨帧复用同一份状态。
    public sealed class UiFeedback
    {
        readonly Dictionary<string,UiWidget> widgets=new Dictionary<string,UiWidget>();
        /// 0 关 / 1 标准 / 2 丰富。0 档只换颜色，不缩放不抖动。
        public int MotionLevel=1;

        /// 声音档：0 全部关 / 1 仅战斗 / 2 全部开。
        public int SoundTier=2;
        /// 界面音档：0 关 / 1 按键（按下、确认、拒绝、分段）/ 2 全开（再加悬停）。
        public int UiSoundLevel=1;

        string focusOwner="";
        string hoveredId="";

        /// 当前悬停的控件 id。提示行靠它显示快捷键。
        public string HoveredId
        {
            get { return hoveredId; }
        }

        /// 丰富档才有过冲、确认扩散、数字滚动、卡片抬起。
        public bool RichMotion
        {
            get { return MotionLevel>=2; }
        }

        /// 标准档起才有缩放、回弹、数字滚动、确认扩散。0 档只换颜色。
        public bool MotionEnabled
        {
            get { return MotionLevel>=1; }
        }

        /// 战斗音（命中、交锋）是否放行。
        public bool BattleSoundAllowed
        {
            get { return SoundTier>=1; }
        }

        /// 界面音（按键、确认、拒绝）是否放行。
        public bool UiSoundAllowed
        {
            get { return UiSoundLevel>=1&&SoundTier>=2; }
        }

        /// 悬停音比按键音再高一档，默认不响。
        public bool HoverSoundAllowed
        {
            get { return UiSoundLevel>=2&&SoundTier>=2; }
        }

        /// 键盘焦点只有一个拥有者，换焦点时旧的那圈环自己淡掉。
        public string FocusOwner
        {
            get { return focusOwner; }
        }

        public void SetFocus(string id)
        {
            if(string.IsNullOrEmpty(id)) id="";
            focusOwner=id;
            if(id!="") Widget(id);
            foreach(KeyValuePair<string,UiWidget> pair in widgets) pair.Value.Focused=pair.Key==id;
        }

        public int WidgetCount
        {
            get { return widgets.Count; }
        }

        public UiWidget Widget(string id)
        {
            if(string.IsNullOrEmpty(id)) id="_";
            UiWidget widget;
            if(!widgets.TryGetValue(id,out widget))
            {
                widget=new UiWidget();
                widget.Id=id;
                widgets.Add(id,widget);
            }
            return widget;
        }

        public void Tick(float dt)
        {
            bool spring=MotionEnabled;
            string top="";
            float topHover=0.5f;
            foreach(KeyValuePair<string,UiWidget> pair in widgets)
            {
                pair.Value.Tick(dt,spring);
                if(pair.Value.Enabled&&pair.Value.Hover>topHover){ topHover=pair.Value.Hover; top=pair.Key; }
            }
            hoveredId=top;
        }

        public void Clear()
        {
            widgets.Clear();
        }
    }

    /// 数值滚动：目标变化时从旧值滚到新值，320ms ease-out cubic。
    public sealed class UiNumber
    {
        public float Value;
        public float Target;
        public float From;
        public float Timer;
        public bool Rolling;
        public bool Initialized;
        public float Flash;
        public bool FlashUp;

        public void Init(float value)
        {
            Value=value;
            Target=value;
            From=value;
            Timer=0f;
            Rolling=false;
            Initialized=true;
            Flash=0f;
        }

        public void Set(float value)
        {
            if(!Initialized){ Init(value); return; }
            if(value==Target) return;
            From=Value;
            Target=value;
            Timer=0f;
            Rolling=true;
            FlashUp=value>From;
            Flash=1f;
        }

        /// 不滚动，直接换数。闪色照旧。
        public void SetInstant(float value)
        {
            if(!Initialized){ Init(value); return; }
            if(value==Target) return;
            From=Value;
            Target=value;
            Value=value;
            Timer=0f;
            Rolling=false;
            FlashUp=value>From;
            Flash=1f;
        }

        public void Tick(float dt)
        {
            if(!Initialized) return;
            if(Rolling)
            {
                Timer+=dt;
                if(Timer>=UiMath.RollLength)
                {
                    Value=Target;
                    Rolling=false;
                }
                else Value=From+(Target-From)*UiMath.EaseOutCubic(Timer/UiMath.RollLength);
            }
            else Value=Target;
            if(Flash>0f)
            {
                Flash-=dt/0.30f;
                if(Flash<0f) Flash=0f;
            }
        }

        public int Display
        {
            get { return (int)Math.Round(Value,MidpointRounding.AwayFromZero); }
        }
    }

    /// 翻页入场：卡片从行进方向外侧滑进来，带一点淡入。
    public sealed class UiEntrance
    {
        public const float Length=0.26f;
        public float Timer;
        public bool Active;
        public float Delay;
        /// +1 从右往左进场，-1 从左往右进场。
        public int Direction=1;

        public void Trigger(float delay,int direction)
        {
            Timer=-delay;
            Active=true;
            Delay=delay;
            Direction=direction>=0?1:-1;
        }

        public void Tick(float dt)
        {
            if(!Active) return;
            Timer+=dt;
            if(Timer>=Length) Active=false;
        }

        public float Progress
        {
            get
            {
                if(!Active||Timer<0f) return 0f;
                return UiMath.Clamp(Timer/Length,0f,1f);
            }
        }

        /// 位移比例：1 → 0。
        public float Offset
        {
            get
            {
                if(!Active) return 0f;
                if(Timer<0f) return Direction;
                return Direction*(1f-UiMath.EaseOutCubic(Progress));
            }
        }

        public float Alpha
        {
            get
            {
                if(!Active) return 1f;
                if(Timer<0f) return 0f;
                return UiMath.Clamp(Progress*1.5f,0f,1f);
            }
        }
    }

    /// 键位闪一下：按下快捷键时提示行上的那个键帽亮一下，220ms 衰减。
    public sealed class UiFlash
    {
        public float Timer;
        public bool Active;

        public void Trigger()
        {
            Timer=0f;
            Active=true;
        }

        public void Tick(float dt)
        {
            if(!Active) return;
            Timer+=dt;
            if(Timer>=UiMath.ConfirmLength) Active=false;
        }

        /// 1 → 0 的衰减。
        public float Value
        {
            get
            {
                if(!Active) return 0f;
                float t=UiMath.Clamp(Timer/UiMath.ConfirmLength,0f,1f);
                return 1f-t;
            }
        }
    }

    /// 计数弹跳：1.15 → 1，180ms。
    public sealed class UiPulse    {
        public float Timer;
        public bool Active;

        public void Trigger()
        {
            Timer=0f;
            Active=true;
        }

        public void Tick(float dt)
        {
            if(!Active) return;
            Timer+=dt;
            if(Timer>=UiMath.BounceLength) Active=false;
        }

        public float Scale
        {
            get
            {
                if(!Active) return 1f;
                float t=UiMath.Clamp(Timer/UiMath.BounceLength,0f,1f);
                return 1f+0.15f*(1f-UiMath.EaseOutCubic(t));
            }
        }
    }
}
