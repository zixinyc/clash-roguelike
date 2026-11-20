using System;
using System.Collections;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        // Presentation time only: impact pauses never alter the rule stream or RNG.
        IEnumerator PlayBattleBeat(string kind,CoinStep coin,float duration,Action<float> setPhase,Func<bool> skipped,bool finalClashImpact=false)
        {
            bool contact=kind=="clash"||kind=="strike",played=false;
            float p=0;
            while(p<1&&!skipped())
            {
                if(effectInspectorOpen||BattleOverlayOpen){yield return null;continue;}
                float next=p+Time.unscaledDeltaTime*speed/duration;
                if(!played&&next>=.45f&&(contact||kind=="clash_end"))
                {
                    played=true;p=.45f;setPhase(p);
                    if(contact&&!muted)audioSource.PlayOneShot(kind=="strike"?hitClip:clashClip);
                    // 落点与音效同一帧：拼点重震，攻击轻震。
                    TriggerImpactShake(finalClashImpact?"clash_end":kind);
                    float hold=coin!=null&&coin.FinalWinner>=0?.18f:.11f;
                    while(hold>0&&!skipped()){if(!effectInspectorOpen&&!BattleOverlayOpen)hold-=Time.unscaledDeltaTime*speed;yield return null;}
                }
                else {p=next;setPhase(Mathf.Clamp01(p));yield return null;}
            }
            setPhase(1);if(skipped())yield return null;
        }
        static float ImpactTravel(float p)
        {return 0;}
        static float ImpactRecoil(float p)
        {return p<.45f?0:Mathf.Sin(Mathf.Clamp01((p-.45f)/.55f)*Mathf.PI)*18;}
        void DrawImpactBurst(string kind,float p)
        {
            if((kind!="clash"&&kind!="strike")||p<.45f||p>.72f)return;
            float strength=1-Mathf.Clamp01((p-.45f)/.27f);Color c=Gold;c.a=strength;
            for(int i=0;i<10;i++){float a=i*Mathf.PI/5;var v=new Vector2(Mathf.Cos(a),Mathf.Sin(a));Line(new Vector2(720,375)+v*16,new Vector2(720,375)+v*(35+60*(1-strength)),c,2);}
        }
    }
}
