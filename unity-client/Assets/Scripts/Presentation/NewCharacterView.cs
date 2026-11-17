using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public static class CharacterRoster
    {
        public static Unit[] Team(int roster)
        {
            if(roster==1)return new[]{TouhouRoles.Marisa(),TouhouRoles.Sakuya(),TouhouRoles.Reimu()};
            return new[]{new Unit{Name="灰烬",Hp=48,MaxHp=48,MinSpeed=3,MaxSpeed=6},roster==2?ZixiRole.Create():new Unit{Name="长锋",Hp=42,MaxHp=42,MinSpeed=5,MaxSpeed=8},new Unit{Name="织火",Hp=46,MaxHp=46,MinSpeed=2,MaxSpeed=5}};
        }
    }
    public sealed partial class BattleGame
    {
        void DrawZixiEnhancement()
        {
            if(!portShown.ZixiTeam)return;var z=portShown.Heroes[1].Zixi;
            Label(700,72,420,25,"ZiXi · 超形上学 "+z.Metaphysics+"/6 · 因果 "+z.Causality+"/3",14,Cyan);
            if(portHero!=1)return;string error=portRules.ZixiEnhancementError(portSlot);GUI.enabled=!portBusy&&!portPrepared&&error=="";
            bool enhanced=portSlot>=0&&portSlot<portShown.HeroSlots.Count&&portShown.HeroSlots[portSlot].Enhanced;
            if(Btn(new Rect(1125,72,270,28),enhanced?"撤销强化 · 返还3层":"强化选中行动 · 消耗3层",enhanced))
            {portRules.ToggleZixiEnhancement(portSlot);portShown=portRules.Snapshot();portNotice=enhanced?"已返还强化资源":"此行动已强化；每回合最多强化一个行动";}
            GUI.enabled=true;if(error!="")Label(1125,101,270,22,error,11,Muted);
        }
    }
}
