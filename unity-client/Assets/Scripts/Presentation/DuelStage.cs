using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        bool DuelParticipant(bool allied,int index)
        {
            if(!portBusy||portEvent==null)return false;
            if(portEvent.Hits!=null)return (allied&&portEvent.Hero==index)||portEvent.Hits.Any(hit=>hit.Allied==allied&&hit.Target==index);
            return (portEvent.Type=="clash"||portEvent.Type=="strike")&&(allied?portEvent.Hero==index:portEvent.Enemy==index);
        }
        static float DuelAdvance(float p)
        {if(p<.18f)return -12*Mathf.Sin(p/.18f*Mathf.PI*.5f);if(p<.45f)return Mathf.Lerp(-12,60,(p-.18f)/.27f);if(p<.58f)return 60;return Mathf.Lerp(60,0,Mathf.Clamp01((p-.58f)/.42f));}
        float PortActorX(bool allied,int index)
        {
            float origin=CombatX(allied,index);if(!DuelParticipant(allied,index))return origin;
            if(portEvent.Hits!=null)
                return allied&&portEvent.Hero==index?origin:origin+(allied?-1:1)*ImpactRecoil(portPhase);
            float hero=CombatX(true,portEvent.Hero),enemy=CombatX(false,portEvent.Enemy),progress=DuelAdvance(portPhase)/60;
            if(progress<0)return origin+(allied?1:-1)*DuelAdvance(portPhase);
            if(portEvent.Type=="clash"){float middle=(hero+enemy)/2;return Mathf.LerpUnclamped(origin,middle+(allied?-74:74),progress);}
            if(portEvent.AttackerAllied==allied)return Mathf.LerpUnclamped(origin,allied?enemy-130:hero+130,progress);
            return origin+(allied?-1:1)*ImpactRecoil(portPhase);
        }
        float ShownCombatX(bool allied,int index){return adventureMode&&portRules!=null?PortActorX(allied,index):CombatX(allied,index);}
        void DrawDuelSpark(float middle,float phase,Color color)
        {
            if(phase<.45f||phase>=.7f)return;
            for(int i=0;i<7;i++)
            {
                Vector2 direction=new Vector2(Mathf.Cos(i*.9f),Mathf.Sin(i*.9f));
                Line(new Vector2(middle,310)+direction*8,new Vector2(middle,310)+direction*(24+35*(phase-.45f)),color,2);
            }
            Line(new Vector2(middle-40,353),new Vector2(middle+40,270),Pale,4);
            Line(new Vector2(middle-40,270),new Vector2(middle+40,353),color,3);
        }
        void DrawDuelStage()
        {
            if(!portBusy||portEvent==null||portEvent.Hero<0||portEvent.Enemy<0||(portEvent.Type!="clash"&&portEvent.Type!="strike"))return;
            float p=portPhase;bool clash=portEvent.Type=="clash";
            float middle=(PortActorX(true,portEvent.Hero)+PortActorX(false,portEvent.Enemy))/2;
            bool contact=p>=.45f&&p<.7f;
            if(contact)
            {
                DrawDuelSpark(middle,p,clash?Gold:Red);
            }
            Label(middle-180,493,360,20,clash?"第 "+portEvent.Coin.Round+" 轮交锋 · "+(p<.45f?"靠近 / 架势":portEvent.Coin.Winner<0?"刀刃相持 · 平局":portEvent.Coin.Winner==0?"我方破币":"敌方破币"):"逐币攻击 · "+(p<.45f?"蓄势":"命中 / 后退"),12,contact?Gold:Muted,TextAnchor.MiddleCenter);
        }
    }
}
