using System;
using System.Linq;
using System.Collections.Generic;
namespace ClashRoguelike
{
    public sealed class PortCard
    {
        public string Id,Name,Tag,Description,Flavor,Kind;
        public int Cost,Owner;public readonly CoinSkill CoinData;
        public readonly bool TargetsEnemy,RequiresClash,NoDamage,AllowsClash;
        public int Base {get{return CoinData.BasePower;}}public int BasePower {get{return CoinData.BasePower;}}
        public int ClashCoinPower {get{return CoinData.ClashCoinPower;}}public int AttackCoinPower {get{return CoinData.AttackCoinPower;}}
        public int Coins {get{return CoinData.CoinCount;}}public int CoinCount {get{return CoinData.CoinCount;}}
        public System.Collections.ObjectModel.ReadOnlyCollection<CoinEffect> Effects {get{return CoinData.Effects;}}
        public int Category { get { return Kind=="guard"?2:Kind=="ultimate"?1:0; } }
        public PortCard(string id,string name,string tag,int cost,int basis,int clashPower,int attackPower,int coins,string description,string flavor,int owner,string kind,IEnumerable<CoinEffect> effects=null,bool targeted=false,bool requiresClash=false,bool noDamage=false,bool allowsClash=true,bool splitAttackPower=false,bool selfTarget=false)
        { Id=id;Name=name;Tag=tag;Cost=cost;CoinData=new CoinSkill(name,basis,clashPower,attackPower,coins,effects,splitAttackPower);Description=description;Flavor=flavor;Owner=owner;Kind=kind;TargetsEnemy=!selfTarget&&(kind!="guard"||targeted);RequiresClash=requiresClash;NoDamage=noDamage;AllowsClash=allowsClash; }
    }
    public static class PortContent
    {
        // Data translated from battle-demo/scripts/battle_rules.gd, not invented replacements.
        public static readonly PortCard[] Cards = new PortCard[] {
            new PortCard("cleave","断轨","重击",3,5,4,4,2,"高威力 · 两枚硬币","将退路，一并斩断。",-1,"attack"),
            new PortCard("ember","余烬斩","斩击",2,4,3,3,2,"均衡威力 · 两枚硬币","火熄灭前，再向前一步。",-1,"attack"),
            new PortCard("needle","穿隙","突刺",1,3,2,2,2,"低费用 · 两枚硬币","裂隙，往往只需一瞬。",-1,"attack"),
            new PortCard("steady","定锋","稳势",2,7,1,1,2,"稳定威力 · 两枚硬币","让摇摆的，只剩敌人。",-1,"attack"),
            new PortCard("guard","守夜","防御",1,0,0,0,0,"获得 9 护盾 · 持续本回合","总有人，要守住最后一盏灯。",-1,"guard"),
            new PortCard("nova","破晓","大招",4,6,4,4,3,"三枚硬币 · 爆发","以余火，换黎明。",-1,"ultimate"),
            new PortCard("observe","观察","灰烬专属",2,5,2,2,2,"行动结束获得 1 层准备","等待破绽。",0,"attack"),
            new PortCard("probe","试探","灰烬专属",1,5,2,2,2,"拼点获胜获得 1 层准备","试出敌人的节奏。",0,"attack"),
            new PortCard("exploit","捕捉破绽","灰烬专属",3,6,3,3,2,"拼点时消耗准备，拼点威力 +4","此刻，就是破绽。",0,"attack"),
            new PortCard("follow","余势追击","灰烬专属",3,5,3,3,2,"追加攻击已停用 · 每枚剩余硬币仅攻击一次","不要放过机会。",0,"attack"),
            new PortCard("steady_edge","稳斩","长锋专属",3,9,1,1,2,"稳定拼点；触发长锋高费被动","稳住，再挥剑。",1,"attack"),
            new PortCard("shatter","裂甲强袭","长锋专属",4,5,4,4,3,"三枚硬币；触发长锋高费被动","全力破阵。",1,"ultimate"),
            new PortCard("light_guard","守护之光","织火专属",3,0,0,0,0,"自身获得9护盾；其他存活队友各获得8护盾","光护住同伴。",2,"guard"),
            new PortCard("support_strike","援火冲击","织火专属",2,5,2,2,2,"拼点获胜后，其他存活队友各获得4护盾","以攻守护。",2,"attack"),
            new PortCard("all_in","破阵","长锋专属",3,7,4,4,2,"高威力；触发破阵者被动","赌上这一击。",1,"attack"),
            new PortCard("cover","护阵","织火专属",2,0,0,0,0,"自身获得 9 护盾；其他存活队友获得 6 护盾","火光护住同伴。",2,"guard"),
            new PortCard("risk","孤注","搏命",2,2,4,4,3,"波动威力 · 三枚硬币","把最后的余温，押上。",-1,"attack"),
        }.Concat(TouhouRoles.Cards()).Concat(ZixiRole.Cards).Concat(FlandreSkills.Definitions()).Concat(RemiliaSkills.Definitions()).Concat(PatchouliSkills.Definitions()).ToArray();
        public static PortCard Card(string id) { return Cards.First(x=>x.Id==id); }
        public static readonly string[] Hand={"cleave","ember","needle","steady","guard","nova","observe","all_in","cover","probe","exploit","follow","steady_edge","shatter","light_guard","support_strike"};
    }
}
