using System;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        // Presentation time only: impact pauses never alter the rule stream or RNG.
        IEnumerator PlayBattleBeat(string kind,CoinStep coin,float duration,Action<float> setPhase,Func<bool> skipped)
        {
            bool contact=kind=="clash"||kind=="strike",played=false;
            bool decisive=coin!=null&&(coin.LeftRemaining==0||coin.RightRemaining==0);
            float p=0;
            while(p<1&&!skipped())
            {
                float next=p+Time.unscaledDeltaTime*speed/duration;
                if(contact&&!played&&next>=.45f)
                {
                    played=true;p=.45f;setPhase(p);
                    if(!muted)audioSource.PlayOneShot(kind=="strike"||decisive?hitClip:clashClip);
                    float hold=kind=="clash"?(decisive?.30f:.18f):(coin!=null&&coin.RemainingAttackCoins==0?.28f:.17f);
                    while(hold>0&&!skipped()){hold-=Time.unscaledDeltaTime*speed;yield return null;}
                }
                else {p=next;setPhase(Mathf.Clamp01(p));yield return null;}
            }
            setPhase(1);if(skipped())yield return null;
        }
        static float ImpactTravel(float p)
        {
            if(p<.18f)return -14*Mathf.Sin(p/.18f*Mathf.PI*.5f);
            if(p<.45f)return Mathf.Lerp(-14,90,(p-.18f)/.27f);
            if(p<.58f)return 90;
            return Mathf.Lerp(90,0,Mathf.Clamp01((p-.58f)/.42f));
        }
        static float ImpactRecoil(float p)
        {return p<.45f?0:p<.65f?Mathf.Lerp(0,26,(p-.45f)/.2f):Mathf.Lerp(26,0,Mathf.Clamp01((p-.65f)/.35f));}
        void DrawImpactBurst(string kind,float p)
        {
            if((kind!="clash"&&kind!="strike")||p<.45f||p>.72f)return;
            float strength=1-Mathf.Clamp01((p-.45f)/.27f);Color c=Gold;c.a=strength;
            for(int i=0;i<10;i++){float a=i*Mathf.PI/5;var v=new Vector2(Mathf.Cos(a),Mathf.Sin(a));Line(new Vector2(720,375)+v*16,new Vector2(720,375)+v*(35+60*(1-strength)),c,2);}
        }
    }
}
