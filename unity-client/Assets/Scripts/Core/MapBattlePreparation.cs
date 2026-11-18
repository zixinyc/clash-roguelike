using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    public sealed class BattleModifier
    {
        public int RevealEnemyCards,EnemySlotsFirstTurn,CostBonus,ClashBonus,DamageBonus;
        public BattleModifier Copy(){return (BattleModifier)MemberwiseClone();}
        public void Clear(){RevealEnemyCards=0;EnemySlotsFirstTurn=0;CostBonus=0;ClashBonus=0;DamageBonus=0;}
    }
    // Map-side adapter. Existing clash, attack, coin and victory calculations are left intact.
    public partial class PortBattleRules
    {
        BattleModifier mapPreparation;readonly HashSet<int> revealedMapSlots=new HashSet<int>();
        public BattleModifier MapPreparation {get{return mapPreparation==null?new BattleModifier():mapPreparation.Copy();}}
        public void ApplyMapPreparation(BattleModifier modifier,int enemyCount=0)
        {
            if(State.Turn!=1||State.Phase!="response"||State.PlanCount!=0||mapPreparation!=null)throw new InvalidOperationException("Preparation must precede the first action.");
            mapPreparation=modifier.Copy();
            if(enemyCount>2)
            {
                if(enemyCount<4||enemyCount>5)throw new ArgumentOutOfRangeException("enemyCount");var enemies=State.Enemies.ToArray();var kinds=State.Kinds;
                State.Enemies=Enumerable.Range(0,enemyCount).Select(i=>{var unit=enemies[i%enemies.Length].Copy();unit.Name+="·"+(i+1);return unit;}).ToList();State.Kinds=Enumerable.Range(0,enemyCount).Select(i=>kinds[i%kinds.Length]).ToArray();PrepareRound();
            }
            State.Cost+=modifier.CostBonus;
            foreach(var s in State.EnemySlots.Where(s=>s.Active).OrderBy(s=>s.Category==2?1:0).Take(Math.Max(0,-modifier.EnemySlotsFirstTurn)))s.Active=false;
            foreach(var s in State.EnemySlots.Where(s=>s.Active).Take(Math.Max(0,modifier.RevealEnemyCards)))revealedMapSlots.Add(s.Id);
        }
        public bool EnemySkillVisible(int slot){return State.Phase!="response"||State.Turn==1&&revealedMapSlots.Contains(slot);}
        IEnumerable<CoinEffect> MapEffects(bool allied)
        {
            if(!allied||mapPreparation==null)yield break;
            if(mapPreparation.ClashBonus!=0)yield return new CoinEffect("地图战斗修正",CoinTrigger.ClashStart,CoinStat.BasePower,mapPreparation.ClashBonus,CoinEffectScope.Clash);
        }
        // Applied after the original shield/damage calculation. Zero modifier is an identity operation.
        int MapFinalDamage(bool allied,bool damagingHit,int originalDamage)
        {return Math.Max(0,originalDamage+(allied&&damagingHit&&mapPreparation!=null?mapPreparation.DamageBonus:0));}
    }
}
