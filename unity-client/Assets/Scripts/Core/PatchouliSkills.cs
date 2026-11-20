using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public enum ElementStone { None, Metal, Fire, Water, Wood, Earth }

    [Serializable]
    public sealed class PatchouliState
    {
        public ElementStone Main,Off;
        public PatchouliState Copy(){return (PatchouliState)MemberwiseClone();}
    }

    public static class PatchouliSkills
    {
        public const string Id="patchouli",SummonId="sage_stone";
        public const string Draw="patchouli_draw",Element="patchouli_element",Sun="patchouli_sun",
            Moon="patchouli_moon",Sage="patchouli_sage";
        const string VariantPrefix="patchouli_element_";
        public static readonly string[] Deck={Draw,Element,Sun,Moon,Sage};
        static readonly string[] Names={"无","金","火","水","木","土"};
        static readonly string[] SpellNames={"","金符【金属疲劳】","火符【火神之光】","水符【水精公主】","木符【风精之角】","土符【慵懒三角塔】"};
        static readonly string[] Effects={"","无视护盾，攻击一个敌人。","容量 2，命中的敌人下回合受燃烧伤害。",
            "拼赢或单方面发动时，全体存活队友回复 10 HP。","拼赢或单方面发动时，全体敌人下回合速度 −2。","按投出的点数乘存活敌人数，对敌全体造成伤害。"};
        static readonly string[] OffText={"","攻币 +1。","伤害、回复与减益强度 ×1.5，向上取整。","cost −1，最低 1。","可无视速度差接招。","拼币 +1。"};
        static readonly int[] Bases={0,6,6,6,6,4},Powers={0,6,2,3,3,12},Coins={0,1,3,2,2,1};

        public static Unit Create()
        {return new Unit{CharacterId=Id,Name="帕秋莉·诺雷姬",Role="元素之石",Hp=40,MaxHp=40,MinSpeed=3,MaxSpeed=5,Patchouli=new PatchouliState()};}

        public static Unit SummonSlot()
        {return new Unit{CharacterId=SummonId,Name="贤者之石",MinSpeed=1,MaxSpeed=5};}

        public static bool IsSummon(Unit unit){return unit.CharacterId==SummonId;}
        public static bool LivingFighter(Unit unit){return !IsSummon(unit)&&FlandreSkills.MemberCanAct(unit);}
        public static bool Has(Unit unit,ElementStone stone)
        {return unit.Patchouli!=null&&(unit.Patchouli.Main==stone||unit.Patchouli.Off==stone);}

        public static string StoneName(ElementStone stone){return Names[(int)stone];}

        public static IEnumerable<PortCard> Definitions()
        {
            yield return Card(Draw,"【元素之石】",1,5,5,5,1,"交锋结算后随机抽一颗石头，拼输也会抽。第三颗起依次替换主副手。");
            yield return Card(Element,"【单元素 / 双元素】",2,6,0,0,0,"需要主手元素。派生牌继承主手技能，并附加不同副手元素的增益。");
            yield return Card(Sun,"日符【皇家烈焰】",6,10,4,4,2,"对全体敌人造成投出点数 ×1.5 的伤害，向上取整。","ultimate");
            yield return Card(Moon,"月符【寂静的月神】",5,0,0,0,0,"不拼点。敌方接下来两回合速度减半，向上取整。","guard",true);
            yield return Card(Sage,"火水木金土符【贤者之石】",10,0,0,0,0,"不拼点。召唤 15 HP 的贤者之石，下回合起每回合自动释放一张单元素牌。","ultimate",true);
            for(int main=1;main<=5;main++)
                for(int off=0;off<=5;off++)
                {
                    if(main==off)continue;
                    string name=off==0?SpellNames[main]:Names[main]+"·"+Names[off]+"·"+SpellNames[main];
                    yield return Card(Variant((ElementStone)main,(ElementStone)off),name,off==(int)ElementStone.Water?1:2,Bases[main],
                        Powers[main]+(off==(int)ElementStone.Earth?1:0),Powers[main]+(off==(int)ElementStone.Metal?1:0),
                        Coins[main],Effects[main]+OffText[off],"attack",false,main==3||main==4);
                }
        }

        static PortCard Card(string key,string name,int cost,int basis,int clash,int attack,int coins,string description,
            string kind="attack",bool support=false,bool harmless=false)
        {return new PortCard(key,name,"帕秋莉专属",cost,basis,clash,attack,coins,description,"",0,kind,
            noDamage:support||harmless,allowsClash:!support,selfTarget:support);}

        public static string Variant(ElementStone main,ElementStone off)
        {return VariantPrefix+(int)main+(int)(off==main?ElementStone.None:off);}

        public static string LoadoutKey(string key){return IsElement(key)?Element:key;}
        public static bool IsElement(string key){return key!=null&&key.StartsWith(VariantPrefix,StringComparison.Ordinal);}
        public static ElementStone MainElement(string key){return IsElement(key)?(ElementStone)(key[VariantPrefix.Length]-'0'):ElementStone.None;}
        public static ElementStone Off(string key){return IsElement(key)?(ElementStone)(key[VariantPrefix.Length+1]-'0'):ElementStone.None;}
        public static string EquippedKey(Unit actor,string key)
        {return key==Element&&actor.Patchouli!=null&&actor.Patchouli.Main!=ElementStone.None?
            Variant(actor.Patchouli.Main,actor.Patchouli.Off):key;}
        public static string Limit(Unit actor,string key,bool sageAlive)
        {
            if(key==Element)return "先使用元素之石取得主手元素";
            if(IsElement(key)&&key!=EquippedKey(actor,Element))return "当前元素组合无法使用这张牌";
            return key==Sage&&sageAlive?"已有贤者之石在战场上":"";
        }

        public static string DrawStone(Unit actor,BattleRandom random)
        {
            var state=actor.Patchouli;
            var next=(ElementStone)(1+random.Range(5));
            if(state.Main==ElementStone.None)state.Main=next;
            else
            {
                if(state.Off!=ElementStone.None)state.Main=state.Off;
                state.Off=next;
            }
            return "元素之石 · 抽到"+StoneName(next)+"；主手 "+StoneName(state.Main)+" / 副手 "+StoneName(state.Off);
        }

        public static int Heal(Unit target,int amount)
        {
            if(!FlandreSkills.MemberCanAct(target))return 0;
            int before=target.Hp;
            target.Hp=Math.Min(target.MaxHp,target.Hp+(target.Flandre==null?amount:amount/2));
            return target.Hp-before;
        }

        public static void StartRound(Unit unit)
        {
            unit.PatchouliBurn=unit.PendingPatchouliBurn;unit.PendingPatchouliBurn=0;
            unit.PatchouliWind=unit.PendingPatchouliWind;unit.PendingPatchouliWind=0;
        }

        public static int Speed(Unit unit,int rolled,int turn)
        {
            int speed=Math.Max(1,rolled-unit.PatchouliWind);
            return turn>=unit.PatchouliMoonFrom&&turn<=unit.PatchouliMoonUntil?(speed+1)/2:speed;
        }

        public static bool Evades(Unit unit,int incoming)
        {return unit.Patchouli!=null&&incoming>0&&incoming<=5;}

        public static int AdjustDamage(Unit attacker,Unit target,int damage)
        {
            if(attacker!=null&&Has(attacker,ElementStone.Fire))damage+=5;
            if(Has(target,ElementStone.Earth))damage-=5;
            return Math.Max(0,damage);
        }

        public static int Asthma(Unit actor)
        {
            if(actor.Patchouli==null||actor.Hp<=0)return 0;
            int cost=Math.Min(2,actor.Hp);actor.Hp-=cost;return cost;
        }

        public static int Amplify(int value)
        {return (value*3+1)/2;}

        public static bool Utility(Unit actor,string key,int round,Unit sage,IList<Unit> allies,IList<Unit> enemies,Action<string> report)
        {
            if(key==Moon)
            {
                foreach(var foe in enemies.Where(FlandreSkills.MemberCanAct))
                {foe.PatchouliMoonFrom=round+1;foe.PatchouliMoonUntil=round+2;}
                report("寂静的月神 · 敌方接下来两回合速度减半");
                return true;
            }
            if(key==Sage)
            {
                if(sage.Hp>0)return true;
                sage.Hp=15;sage.MaxHp=15;sage.SageReadyTurn=round+1;
                sage.Shield=0;sage.Puppet=false;sage.Statuses.Clear();
                sage.RedMist=sage.PendingRedMist=sage.PatchouliBurn=sage.PendingPatchouliBurn=0;
                sage.PatchouliWind=sage.PendingPatchouliWind=sage.PatchouliMoonFrom=sage.PatchouliMoonUntil=0;
                report("贤者之石 · 15 HP，下回合起每回合施放一次单元素技能");
                return true;
            }
            var main=MainElement(key);
            bool fiery=Off(key)==ElementStone.Fire;
            if(main==ElementStone.Water)
            {
                int amount=fiery?15:10;
                var healed=allies.Select(a=>new{a.Name,Hp=Heal(a,amount)}).Where(a=>a.Hp>0);
                report("水精公主 · "+string.Join("、",healed.Select(a=>a.Name+" +"+a.Hp+" HP").DefaultIfEmpty("全队生命充足").ToArray()));
                return true;
            }
            if(main!=ElementStone.Wood)return false;
            int penalty=fiery?3:2;
            foreach(var foe in enemies.Where(FlandreSkills.MemberCanAct))
                foe.PendingPatchouliWind=Math.Max(foe.PendingPatchouliWind,penalty);
            report("风精之角 · 敌方全体下回合速度 −"+penalty);
            return true;
        }

        public static bool SageCanAct(Unit unit,int turn)
        {return IsSummon(unit)&&FlandreSkills.MemberCanAct(unit)&&unit.SageReadyTurn<=turn;}
    }

    internal sealed class PatchouliStrike
    {
        readonly string key;
        readonly ElementStone element;
        public readonly int[] Targets;
        public bool IgnoresShield {get{return element==ElementStone.Metal;}}

        public PatchouliStrike(Unit actor,string key,int target,IList<Unit> foes)
        {
            this.key=key;element=PatchouliSkills.MainElement(key);
            int living=foes.Count(u=>u.Hp>0);
            int capacity=key==PatchouliSkills.Sun||element==ElementStone.Earth?living:
                (element==ElementStone.Fire?2:1)+(PatchouliSkills.Has(actor,ElementStone.Wood)?1:0);
            Targets=Enumerable.Range(0,foes.Count).Select(i=>(target+i)%foes.Count)
                .Where(i=>foes[i].Hp>0).Take(capacity).ToArray();
        }

        public int Raw(CoinStep step)
        {
            int raw=Math.Max(0,step.RawDamage);
            if(element==ElementStone.Earth)raw*=Targets.Length;
            if(key==PatchouliSkills.Sun||PatchouliSkills.Off(key)==ElementStone.Fire)raw=PatchouliSkills.Amplify(raw);
            return raw;
        }

        public void OnHit(Unit victim)
        {
            if(element==ElementStone.Fire&&FlandreSkills.MemberCanAct(victim))
                victim.PendingPatchouliBurn=Math.Max(victim.PendingPatchouliBurn,PatchouliSkills.Off(key)==ElementStone.Fire?8:5);
        }
    }
}
