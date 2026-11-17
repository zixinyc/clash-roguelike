using System;
using System.Linq;
namespace ClashRoguelike
{
    // Shared by the retained grid and the new node map; original values and battle rules unchanged.
    public sealed class ExpeditionResources
    {
        public int Cost=30;
        public int[] Hp={48,42,46};
        public readonly int[] MaxHp={48,42,46};
        public void Heal(int amount){for(int i=0;i<3;i++)if(Hp[i]>0)Hp[i]=Math.Min(MaxHp[i],Hp[i]+amount);}
        public bool ApplyChoice(string kind,int choice)
        {
            if(choice<0||choice>1)return false;
            if(kind=="shop"){if(choice!=0||Cost<6)return false;Cost-=6;Heal(8);}
            else if(kind=="camp"){if(choice==0)Heal(10);else Cost+=5;}
            else if(kind=="event"){if(choice==0)Cost+=5;else{for(int i=0;i<3;i++)if(Hp[i]>0)Hp[i]=Math.Max(1,Hp[i]-4);Cost+=12;}}
            else return false;return true;
        }
        public PortBattleRules CreateBattle(int encounter,uint seed=73129)
        {
            var b=new PortBattleRules(seed,encounter);b.State.Cost=Cost;for(int i=0;i<3;i++)b.State.Heroes[i].Hp=Hp[i];
            foreach(var s in b.State.EnemySlots)if(s.Active&&s.Category!=2&&(s.Target<0||Hp[s.Target]<=0))s.Target=Array.FindIndex(Hp,h=>h>0);return b;
        }
        public void ApplyBattleResult(PortState state,int encounter)
        {Cost=state.Cost;Hp=state.Heroes.Select(x=>x.Hp).ToArray();if(state.Outcome=="victory")Cost+=encounter==1?8:4;}
    }
}
