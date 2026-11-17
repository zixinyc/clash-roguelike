using System;
using System.Linq;
using System.Collections.Generic;
namespace ClashRoguelike
{
    [Serializable] public sealed class ZixiState
    {
        public int Metaphysics,Causality,RoundGain,EnhancedSlot=-1,NoMarginRound;
        public Dictionary<string,int> NextClash=new Dictionary<string,int>();
        public SortedDictionary<int,int> ShieldUntil=new SortedDictionary<int,int>();
        public ZixiState Copy(){var c=(ZixiState)MemberwiseClone();c.NextClash=new Dictionary<string,int>(NextClash);c.ShieldUntil=new SortedDictionary<int,int>(ShieldUntil);return c;}
        public string Fingerprint(){return Metaphysics+":"+Causality+":"+RoundGain+":"+EnhancedSlot+":"+NoMarginRound+":"+string.Join(",",NextClash.OrderBy(x=>x.Key).Select(x=>x.Key+"="+x.Value).ToArray())+":"+string.Join(",",ShieldUntil.Select(x=>x.Key+"="+x.Value).ToArray());}
    }
    public static class ZixiRole
    {
        public static readonly PortCard[] Cards={
            new PortCard("zixi_central_limit","中心极限定理","ZiXi专属",1,3,2,2,2,"拼初11 / 攻初3；需拼点。赢后下次拼点+1。强化：拼点+2、每击+4。","正态近似",1,"attack",requiresClash:true),
            new PortCard("zixi_convergence","几乎处处收敛","ZiXi专属",2,2,3,3,3,"拼初12 / 攻初2；赢后下次拼点+2。强化：本技能首次反面转正，攻击三枚自然正面额外+3。","收敛极限",1,"attack",requiresClash:true),
            new PortCard("zixi_martingale","鞅","ZiXi专属",4,15,4,0,1,"需拼点、无伤害。赢8盾/输4盾，留至下回合末。强化：拼点+3，赢12盾，输后下次拼点+3。","公平博弈",1,"guard",targeted:true,requiresClash:true,noDamage:true),
            new PortCard("zixi_almost_sure","几乎必然","ZiXi专属",5,5,5,4,2,"拼初17 / 攻初5；赢后每层因果每击+2。强化：全体轰炸6+5×新因果层数后清空，下回合暂停分差奖励。","概率一事件",1,"ultimate",requiresClash:true)
        };
        public static readonly string[] Keys=Cards.Select(x=>x.Id).ToArray();
        public static Unit Create(){return new Unit{Name="ZiXi",Role="几乎必然的观测者",CharacterId="zixi",Hp=50,MaxHp=50,MinSpeed=3,MaxSpeed=5,Zixi=new ZixiState()};}
        public static int ClashBase(string id){return id=="zixi_central_limit"?11:id=="zixi_convergence"?12:id=="zixi_almost_sure"?17:15;}
    }
    public sealed class ZixiContext
    {
        public string Key;public bool Enhanced,TailAvailable,Won;public int StartCausality,NaturalAttackHeads,Blast;
    }
    public partial class PortBattleRules
    {
        void PrepareZixiRound()
        {
            foreach(var u in State.Heroes.Where(x=>x.Zixi!=null))
            {var z=u.Zixi;z.RoundGain=0;z.EnhancedSlot=-1;foreach(int key in z.ShieldUntil.Keys.Where(k=>k<State.Turn).ToArray())z.ShieldUntil.Remove(key);u.Shield=z.ShieldUntil.Values.Sum();}
        }
        public string ZixiEnhancementError(int slotId)
        {
            if(State.Phase!="response"||slotId<0||slotId>=State.HeroSlots.Count)return "当前不能强化";var slot=State.HeroSlots[slotId];var z=State.Heroes[slot.Unit].Zixi;
            if(z==null||!slot.Active||!ZixiRole.Keys.Contains(slot.Key))return "先安排ZiXi专属技能";if(z.EnhancedSlot==slotId)return "";if(z.EnhancedSlot>=0)return "本回合已安排一次强化";return z.Metaphysics<3?"强化需要3层超形上学":"";
        }
        public bool ToggleZixiEnhancement(int slotId)
        {
            if(ZixiEnhancementError(slotId)!="")return false;var slot=State.HeroSlots[slotId];if(slot.Enhanced){UnreserveZixi(slot);return true;}var z=State.Heroes[slot.Unit].Zixi;z.Metaphysics-=3;z.EnhancedSlot=slotId;slot.Enhanced=true;return true;
        }
        void UnreserveZixi(PortSlot slot)
        {
            var z=State.Heroes[slot.Unit].Zixi;if(z==null||!slot.Enhanced||z.EnhancedSlot!=slot.Id)return;z.Metaphysics=Math.Min(6,z.Metaphysics+3);z.EnhancedSlot=-1;slot.Enhanced=false;
        }
        ZixiContext BeginZixiClash(PortSlot slot,PortCard card,List<CoinEffect> effects)
        {
            var z=State.Heroes[slot.Unit].Zixi;if(z==null)return null;
            var ctx=new ZixiContext{Key=card.Id,Enhanced=slot.Enhanced,StartCausality=z.Causality,TailAvailable=slot.Enhanced&&card.Id=="zixi_convergence"};
            int bonus=z.Causality+z.NextClash.Values.Sum();z.NextClash.Clear();
            if(slot.Enhanced)bonus+=card.Id=="zixi_central_limit"?2:card.Id=="zixi_martingale"?3:0;
            if(ZixiRole.Keys.Contains(card.Id))bonus+=ZixiRole.ClashBase(card.Id)-card.Base;
            if(bonus!=0)effects.Add(new CoinEffect("ZiXi因果/下次拼点/独立初始值",CoinTrigger.ClashStart,CoinStat.BasePower,bonus,CoinEffectScope.Clash));return ctx;
        }
        void AttachZixiTransforms(CoinAction action,ZixiContext ctx)
        {
            if(ctx==null)return;
            action.FaceTransform=(heads,clash)=>{if(!clash&&heads)ctx.NaturalAttackHeads++;if(!heads&&ctx.TailAvailable){ctx.TailAvailable=false;return true;}return heads;};
            action.AttackAdjustment=index=>!ctx.Won?0:ctx.Key=="zixi_central_limit"&&ctx.Enhanced?4:ctx.Key=="zixi_convergence"&&ctx.Enhanced&&index==3&&ctx.NaturalAttackHeads==3?3:ctx.Key=="zixi_almost_sure"?2*ctx.StartCausality:0;
        }
        void FinishZixiClash(List<PortEvent> events,PortSlot slot,PortCard card,ZixiContext ctx,int winner,CoinStep last)
        {
            if(ctx==null)return;var u=State.Heroes[slot.Unit];var z=u.Zixi;ctx.Won=winner==0;
            if(ctx.Won)
            {
                if(card.Id=="zixi_central_limit")z.NextClash[card.Id]=1;if(card.Id=="zixi_convergence")z.NextClash[card.Id]=2;
                int reward=last.LeftPower-last.RightPower>=5&&z.NoMarginRound!=State.Turn?2:1;int gain=Math.Max(0,Math.Min(reward,Math.Min(3-z.RoundGain,6-z.Metaphysics)));z.RoundGain+=gain;z.Metaphysics+=gain;
                Emit(events,"ability","ZiXi超形上学 +"+gain+"，现有 "+z.Metaphysics+" / 6",slot.Unit);
            }
            if(card.Id=="zixi_martingale")
            {int amount=ctx.Won?(ctx.Enhanced?12:8):4;int until=State.Turn+1;if(!z.ShieldUntil.ContainsKey(until))z.ShieldUntil[until]=0;z.ShieldUntil[until]+=amount;u.Shield+=amount;if(!ctx.Won&&ctx.Enhanced)z.NextClash[card.Id]=3;Emit(events,"ability","鞅：获得 "+amount+" 跨回合护盾",slot.Unit);}
            if(ctx.Enhanced)z.Causality=Math.Min(3,z.Causality+1);
            if(ctx.Enhanced&&card.Id=="zixi_almost_sure"&&ctx.Won){ctx.Blast=6+5*z.Causality;z.Causality=0;z.NoMarginRound=State.Turn+1;}
        }
        void AttackZixi(List<PortEvent> events,PortSlot slot,int target,CoinAction action,PortCard card,ZixiContext ctx)
        {
            if(ctx!=null&&ctx.Blast>0)
            {while(action.NextAttack(new CoinRandomSource(FlipCoin))!=null){}action.CompleteAttack();for(int i=0;i<State.Enemies.Count;i++)DealNewHit(events,slot.Unit,i,ctx.Blast,"status_damage");Emit(events,"ability","概率一事件：轰炸全体 "+ctx.Blast+"，因果清空；消耗原技能硬币",slot.Unit);return;}
            Attack(events,true,slot.Unit,target,action,card);
        }
        void AbsorbZixiShield(Unit victim,int blocked)
        {
            var z=victim.Zixi;if(z==null||blocked<=0)return;int carried=z.ShieldUntil.Values.Sum(),needed=Math.Max(0,blocked-Math.Max(0,victim.Shield-carried));
            foreach(int key in z.ShieldUntil.Keys.ToArray()){int used=Math.Min(needed,z.ShieldUntil[key]);needed-=used;z.ShieldUntil[key]-=used;if(z.ShieldUntil[key]==0)z.ShieldUntil.Remove(key);if(needed==0)break;}
        }
    }
}
