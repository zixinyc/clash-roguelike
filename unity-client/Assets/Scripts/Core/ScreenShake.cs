using System;

namespace ClashRoguelike
{
    /// 震动：拼点与攻击的冲击反馈。纯 .NET 实现，不引用 UnityEngine。
    ///
    /// 规矩（与 UI_FEEDBACK_DESIGN.md 同一套）：
    /// - 状态只在 Update() 里推进，OnGUI 只读值，不在绘制里累加。
    /// - 末端严格归零，不留跳变。
    /// - 两轴频率不同，整块画面不会绕着圈转。
    ///
    /// 幅度是「单轴峰值」，按设计空间像素算。组合后的位移模长最大约 1.14 倍。
    public sealed class ScreenShake
    {
        /// 拼点：两枚硬币撞在一起的那一下。
        public const float ClashAmplitude=9.0f;
        public const float ClashDuration=0.28f;
        public const float ClashFrequency=19f;
        /// 拼点落定：胜负分出来的那一下，比单轮更重。
        public const float ClashEndAmplitude=12.0f;
        public const float ClashEndDuration=0.34f;
        public const float ClashEndFrequency=15f;
        /// 攻击：命中只给轻微震动，不抢拼点的戏。
        public const float StrikeAmplitude=3.2f;
        public const float StrikeDuration=0.13f;
        public const float StrikeFrequency=26f;

        public float Amplitude;
        public float Duration;
        public float Frequency;
        public float Elapsed;
        public bool Active;

        /// 起一次震动。幅度或时长为 0 等于不动。
        public void Trigger(float amplitude,float duration,float frequency)
        {
            Amplitude=amplitude;
            Duration=duration;
            Frequency=frequency;
            Elapsed=0f;
            Active=amplitude>0f&&duration>0f;
        }

        /// 立刻收手，不留残余。
        public void Stop()
        {
            Active=false;
            Elapsed=0f;
            Amplitude=0f;
        }

        /// 推进计时。只在 Update() 里调。
        public void Tick(float dt)
        {
            if(!Active) return;
            if(dt<0f) dt=0f;
            Elapsed+=dt;
            if(Elapsed>=Duration)
            {
                Active=false;
                Elapsed=0f;
            }
        }

        public float OffsetX
        {
            get { return Active?Wave(Elapsed,Duration,Amplitude,Frequency,0):0f; }
        }

        public float OffsetY
        {
            get { return Active?Wave(Elapsed,Duration,Amplitude,Frequency,1):0f; }
        }

        /// 当前位移的模长。
        public float Magnitude
        {
            get { return (float)Math.Sqrt(OffsetX*OffsetX+OffsetY*OffsetY); }
        }

        /// 每轴的权重：横向给满，纵向只给一半，免得画面斜着飘。
        public static float AxisScale(int axis)
        {
            return axis==0?1f:0.55f;
        }

        /// 包络 × 波形。elapsed 到达 duration 时严格返回 0。
        public static float Wave(float elapsed,float duration,float amplitude,float frequency,int axis)
        {
            if(duration<=0f||amplitude<=0f||elapsed<0f||elapsed>=duration) return 0f;
            float t=elapsed/duration;
            float fade=(1f-t)*(1f-t);
            double phase=2.0*Math.PI*frequency*elapsed;
            double wave=axis==0?Math.Sin(phase):Math.Sin(phase*1.37+1.1);
            return amplitude*fade*AxisScale(axis)*(float)wave;
        }
    }
}
