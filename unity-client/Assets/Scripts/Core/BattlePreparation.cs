using System;
using System.Linq;
using System.Collections.Generic;
namespace ClashRoguelike
{
    public sealed class SkillGroups
    {
        readonly Dictionary<string,HashSet<string>[]> groups=new Dictionary<string,HashSet<string>[]>();
        readonly Dictionary<string,int> active=new Dictionary<string,int>();
        void Ensure(string character,string[] available)
        {if(groups.ContainsKey(character))return;var attacks=available.Where(k=>PortContent.Card(k).TargetsEnemy&&!PortContent.Card(k).NoDamage).Take(2).ToArray();groups[character]=new[]{new HashSet<string>(available),new HashSet<string>(attacks.Length>0?attacks:available.Take(1))};active[character]=0;}
        public int Current(string character,string[] available){Ensure(character,available);return active[character];}
        public void Select(string character,string[] available,int index){Ensure(character,available);if(index<0||index>1)throw new ArgumentOutOfRangeException("index");active[character]=index;}
        public string[] Cards(string character,string[] available){Ensure(character,available);return available.Where(k=>groups[character][active[character]].Contains(k)).ToArray();}
        public bool Toggle(string character,string[] available,string key){Ensure(character,available);if(!available.Contains(key))return false;var g=groups[character][active[character]];if(g.Contains(key)){if(g.Count<=1)return false;g.Remove(key);}else g.Add(key);return true;}
        public void Reset(string character,string[] available){Ensure(character,available);groups[character][active[character]]=new HashSet<string>(available);}
    }
    public sealed class ClashForecast
    {
        public double OwnExpected,EnemyExpected;public int OwnMin,OwnMax,EnemyMin,EnemyMax;public bool Estimated;
        public string Risk {get{return Classify(OwnExpected-EnemyExpected);}}
        public static string Classify(double difference){return Math.Abs(difference)<=2?"平衡":difference>0?"优势":"劣势";}
        public static ClashForecast Create(PortCard own,IEnumerable<PortCard> opposition,bool hidden)
        {
            var enemy=opposition.ToArray();if(enemy.Length==0)throw new ArgumentException("No public opponent category candidates");
            int basis=ZixiRole.Keys.Contains(own.Id)?ZixiRole.ClashBase(own.Id):own.Base;
            return new ClashForecast{OwnExpected=basis+own.Coins*own.ClashCoinPower*.65,EnemyExpected=enemy.Average(c=>c.Base+c.Coins*c.ClashCoinPower*.5),OwnMin=basis+Math.Min(0,own.Coins*own.ClashCoinPower),OwnMax=basis+Math.Max(0,own.Coins*own.ClashCoinPower),EnemyMin=enemy.Min(c=>c.Base+Math.Min(0,c.Coins*c.ClashCoinPower)),EnemyMax=enemy.Max(c=>c.Base+Math.Max(0,c.Coins*c.ClashCoinPower)),Estimated=hidden};
        }
    }
    public partial class PortBattleRules
    {
        HashSet<string> equippedSkills;
        public bool LoadoutLocked {get;private set;}
        public bool ConfigureLoadout(IEnumerable<string> keys)
        {
            if(LoadoutLocked||State.Turn!=1||State.Plays!=0||State.PlanCount!=0||State.Phase!="response")return false;
            var chosen=new HashSet<string>(keys??new string[0]);if(chosen.Any(k=>!State.Hand.Contains(k)))return false;
            for(int actor=0;actor<3;actor++)if(!chosen.Any(k=>PortContent.Card(k).Owner==actor))return false;
            foreach(string shared in State.Hand.Where(k=>PortContent.Card(k).Owner<0))chosen.Add(shared);
            equippedSkills=chosen;State.Hand=State.Hand.Where(chosen.Contains).ToArray();LoadoutLocked=true;return true;
        }
    }
}
