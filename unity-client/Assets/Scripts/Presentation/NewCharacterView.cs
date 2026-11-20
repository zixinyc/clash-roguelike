using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        void DrawZixiEnhancement()
        {
            int actor=portShown.Actor("zixi");
            if(actor<0)return;
            var z=portShown.Heroes[actor].Zixi;
            Label(700,72,420,25,"ZiXi · 超形上学 "+z.Metaphysics+"/6 · 因果 "+z.Causality+"/3",14,Cyan);
            if(portHero!=actor)return;
            string error=portRules.ZixiEnhancementError(portSlot);
            GUI.enabled=!portBusy&&!portPrepared&&error=="";
            bool enhanced=portSlot>=0&&portSlot<portShown.HeroSlots.Count&&portShown.HeroSlots[portSlot].Enhanced;
            if(Btn(new Rect(1125,72,270,28),enhanced?"撤销强化 · 返还3层":"强化选中行动 · 消耗3层",enhanced))
            {portRules.ToggleZixiEnhancement(portSlot);portShown=portRules.Snapshot();portNotice=enhanced?"已返还强化资源":"此行动已强化；每回合最多强化一个行动";}
            GUI.enabled=true;
            if(error!="")Label(1125,101,270,22,error,11,Muted);
        }
    }
}
