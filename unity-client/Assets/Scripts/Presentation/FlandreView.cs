using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        AudioClip flandreTune;

        void PlayFlandreMusic()
        {
            if(muted||audioSource==null)return;
            if(flandreTune==null)
            {
                const int rate=22050;
                int noteLength=rate*17/100;
                float[] notes={523.25f,659.25f,587.33f,783.99f};
                var data=new float[noteLength*notes.Length];
                for(int note=0;note<notes.Length;note++)
                {
                    for(int frame=0;frame<noteLength;frame++)
                    {
                        float t=(float)frame/rate;
                        float envelope=Mathf.Min(1f,frame/180f)*Mathf.Exp(-20f*t)*
                            Mathf.Min(1f,(noteLength-frame)/280f);
                        float phase=2*Mathf.PI*notes[note]*t;
                        data[note*noteLength+frame]=.32f*envelope*(Mathf.Sin(phase)+.25f*Mathf.Sin(phase*2));
                    }
                }
                flandreTune=AudioClip.Create("Flandre puppet cue",data.Length,1,rate,false);
                flandreTune.SetData(data,0);
            }
            audioSource.PlayOneShot(flandreTune);
        }
    }
}
