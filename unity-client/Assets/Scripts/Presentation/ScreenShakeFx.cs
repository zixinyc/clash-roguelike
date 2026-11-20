using UnityEngine;

namespace ClashRoguelike
{
    /// 震动的 Unity 侧：把 Core/ScreenShake 的纯逻辑变成画面位移。
    ///
    /// 规矩：
    /// - 计时只在 UiTick（Update）里推进，OnGUI 只读位移。
    /// - 位移作用在 GUI.matrix 上，画完必须还原。
    /// - 动效强度 0 档（只换颜色）不抖。
    public sealed partial class BattleGame
    {
        readonly ScreenShake screenShake=new ScreenShake();

        /// 推进震动计时。只在 Update() 里调。
        void ShakeTick(float dt)
        {
            screenShake.Tick(dt);
        }

        /// 拼点落点、拼点落定、攻击命中时起一次震动。
        void TriggerImpactShake(string kind)
        {
            if(string.IsNullOrEmpty(kind)) return;
            if(!uiFx.MotionEnabled) return;
            if(kind=="clash")
                screenShake.Trigger(ScreenShake.ClashAmplitude,ScreenShake.ClashDuration,ScreenShake.ClashFrequency);
            else if(kind=="clash_end")
                screenShake.Trigger(ScreenShake.ClashEndAmplitude,ScreenShake.ClashEndDuration,ScreenShake.ClashEndFrequency);
            else if(kind=="strike")
                screenShake.Trigger(ScreenShake.StrikeAmplitude,ScreenShake.StrikeDuration,ScreenShake.StrikeFrequency);
        }

        void StopImpactShake()
        {
            screenShake.Stop();
            shakeApplied=Vector2.zero;
        }

        /// 当前震动的设计空间位移。没有震动时返回零。
        Vector2 ShakeOffset
        {
            get
            {
                if(!screenShake.Active) return Vector2.zero;
                float x=screenShake.OffsetX,y=screenShake.OffsetY;
                return x==0f&&y==0f?Vector2.zero:new Vector2(x,y);
            }
        }

        /// 当前震动的位移模长。冒烟用它确认实机里真的震了。
        float ShakeMagnitude
        {
            get { return screenShake.Active?screenShake.Magnitude:0f; }
        }

        /// 把震动写进 GUI.matrix。调用方负责画完后还原。
        void ApplyShakeOffset()
        {
            Vector2 offset=ShakeOffset;
            if(Event.current.type!=EventType.Repaint||offset==Vector2.zero)return;
            GUI.matrix=GUI.matrix*Matrix4x4.TRS(new Vector3(offset.x,offset.y,0f),Quaternion.identity,Vector3.one);
            shakeApplied=offset;
        }

        /// 最近一次真正写进矩阵的位移。冒烟用它确认绘制路径确实吃到了震动。
        Vector2 shakeApplied;

        /// 抓一帧到内存。调用方负责 Destroy。
        Texture2D GrabFrameTexture()
        {
            var image=new Texture2D(Screen.width,Screen.height,TextureFormat.RGB24,false);
            image.ReadPixels(new Rect(0,0,Screen.width,Screen.height),0,0); image.Apply();
            return image;
        }

        /// 整幅画面里亮像素的横向重心。用来量"画面整体被推开多少"。
        static float BrightCentroidX(Texture2D image)
        {
            if(image==null) return -1f;
            var pixels=image.GetPixels32();int width=image.width;
            double sum=0,sumX=0;
            for(int i=0;i<pixels.Length;i++)
            {
                var p=pixels[i];
                float l=(p.r+p.g+p.b)/765f;
                if(l<0.55f) continue;
                double weight=l-0.55;
                sum+=weight;sumX+=weight*(i%width);
            }
            return sum>0?(float)(sumX/sum):-1f;
        }
    }
}
