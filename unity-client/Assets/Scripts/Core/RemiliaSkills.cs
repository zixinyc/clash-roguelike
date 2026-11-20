using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    [Serializable]
    public sealed class RemiliaState
    {
        public int Scarlet,Overheat,LockedTarget=-1,CurseUntil,CounterRound;
        public bool SavedFromDefeat,AttackedLocked;
        public RemiliaState Copy(){return (RemiliaState)MemberwiseClone();}
        public string Fingerprint(){return Scarlet+":"+Overheat+":"+LockedTarget+":"+CurseUntil+":"+CounterRound+":"+SavedFromDefeat+":"+AttackedLocked;}
    }

    public static class RemiliaSkills
    {
        public const string Id="remilia";
        public const string Star="remilia_star",Needles="remilia_needles",Curse="remilia_curse",
            Shoot="remilia_shoot",Magic="remilia_magic",Fantasy="remilia_fantasy";
        public static readonly string[] Cards={Star,Needles,Curse,Shoot,Magic,Fantasy};

        public static Unit Create()
        {
            return new Unit{CharacterId=Id,Name="蕾米莉亚·斯卡雷特",Role="永远鲜红的幼月",
                Hp=35,MaxHp=35,MinSpeed=6,MaxSpeed=8,Remilia=new RemiliaState()};
        }

        public static IEnumerable<PortCard> Definitions()
        {
            yield return Card(Star,"天罚【大卫之星】",3,8,2,2,"绯红之主超过20层时，最终拼点+2。");
            yield return Card(Needles,"狱符【千根针的针山】",5,7,6,1,"容量为2＋绯红之主层数÷20，向下取整。");
            yield return Card(Curse,"诅咒【弗拉德·采佩什的诅咒】",5,10,6,1,
                "防御拼点。成功施咒至下回合末；敌方攻击我方后，以大卫之星反击，每回合一次。","guard");
            yield return Card(Shoot,"红符【绯红射击】",4,5,3,3,"攻击后额外叠加实际伤害×2的绯红之主。");
            yield return Card(Magic,"【红色魔法】",8,10,3,4,"容量2。命中目标下回合获得2层红雾，最多4层。","ultimate");
            yield return Card(Fantasy,"【红色的幻想乡】",10,13,13,1,
                "额外造成绯红之主层数的一半的伤害，随后清空层数。","ultimate");
        }

        static PortCard Card(string id,string name,int cost,int basis,int coin,int count,string text,string kind="attack")
        {
            // The source specifies clash power. Attack coins use the same initial value and are rolled independently.
            return new PortCard(id,name,"蕾米莉亚专属",cost,basis,coin,coin,count,text,"",0,kind,
                targeted:kind=="guard",noDamage:kind=="guard");
        }

        internal static void BeginRound(Unit actor,IList<Unit> enemies,BattleRandom random)
        {
            actor.RedMist=actor.PendingRedMist;
            actor.PendingRedMist=0;
            var state=actor.Remilia;
            if(state==null)return;
            var living=Enumerable.Range(0,enemies.Count).Where(i=>FlandreSkills.MemberCanAct(enemies[i])).ToArray();
            state.AttackedLocked=false;
            state.LockedTarget=living.Length==0||!FlandreSkills.MemberCanAct(actor)?-1:living[random.Range(living.Length)];
        }

        internal static bool IsLocked(Unit actor,int target)
        {return actor.Remilia!=null&&target>=0&&actor.Remilia.LockedTarget==target;}

        internal static bool CompleteClash(Unit actor,int target)
        {
            if(!IsLocked(actor,target))return false;
            actor.Remilia.Overheat++;
            return true;
        }

        internal static bool EndRound(Unit actor)
        {
            var state=actor.Remilia;
            if(state==null||state.AttackedLocked||state.Overheat==0)return false;
            state.Overheat--;
            return true;
        }

        internal static int ClashBonus(Unit actor,string key)
        {
            var state=actor.Remilia;
            return state==null?0:(key==Star&&state.Scarlet>20?2:0)-3*state.Overheat;
        }

        internal static IEnumerable<int> Targets(Unit actor,string key,int primary,IList<Unit> enemies)
        {
            int capacity=key==Needles?2+actor.Remilia.Scarlet/20:key==Magic?2:1;
            return Enumerable.Range(0,enemies.Count).Select(offset=>(primary+offset)%enemies.Count)
                .Where(index=>enemies[index].Hp>0).Take(capacity);
        }

        internal static void CompleteAttack(Unit actor,string key,int damage)
        {
            var state=actor.Remilia;
            actor.Hp=Math.Min(actor.MaxHp,actor.Hp+damage);
            state.Scarlet=key==Fantasy?0:Math.Min(100,state.Scarlet+damage*(key==Shoot?3:1));
        }

        internal static bool CastCurse(Unit actor,string key,int round)
        {
            if(actor.Remilia==null||key!=Curse)return false;
            actor.Remilia.CurseUntil=round+1;
            return true;
        }

        internal static bool SpendCounter(Unit actor,int round)
        {
            var state=actor.Remilia;
            if(state==null||!FlandreSkills.MemberCanAct(actor)||state.CurseUntil<round||state.CounterRound==round)return false;
            state.CounterRound=round;
            return true;
        }

        internal static bool PreventDefeat(Unit target,int damage,ref int cost)
        {
            var state=target.Remilia;
            if(state==null||state.SavedFromDefeat||target.Puppet||target.Hp<=0||damage<target.Hp||cost<10)return false;
            cost-=10;
            state.SavedFromDefeat=true;
            target.Hp=1;
            return true;
        }
    }

    // One action tracks its own fixed targets, damage reduction budget and effective HP damage.
    internal sealed class RemiliaStrike
    {
        readonly Unit actor;
        readonly string key;
        readonly int primary;
        readonly bool doubled;
        readonly Dictionary<int,int> reduction=new Dictionary<int,int>();
        readonly HashSet<int> hit=new HashSet<int>();
        int totalDamage;
        public readonly int[] Targets;

        public RemiliaStrike(Unit actor,string key,int primary,IList<Unit> enemies,bool fromClash)
        {
            this.actor=actor;this.key=key;this.primary=primary;
            doubled=fromClash&&RemiliaSkills.IsLocked(actor,primary);
            Targets=RemiliaSkills.Targets(actor,key,primary,enemies).ToArray();
            foreach(int target in Targets)reduction[target]=actor.Remilia.Overheat*10;
        }

        public int Raw(int target,CoinStep step)
        {
            int raw=Math.Max(0,step.RawDamage)+(key==RemiliaSkills.Fantasy&&step.AttackIndex==1?actor.Remilia.Scarlet/2:0);
            if(doubled&&target==primary)raw*=2;
            int deduction=Math.Min(raw,reduction[target]);
            reduction[target]-=deduction;
            return raw-deduction;
        }

        public void RecordHit(int target,int damage)
        {
            hit.Add(target);
            if(RemiliaSkills.IsLocked(actor,target))actor.Remilia.AttackedLocked=true;
            totalDamage+=Math.Max(0,damage);
        }

        public string Finish(IList<Unit> enemies)
        {
            if(key==RemiliaSkills.Magic)
                foreach(int target in hit.Where(i=>FlandreSkills.MemberCanAct(enemies[i])))
                {
                    var enemy=enemies[target];
                    enemy.PendingRedMist=Math.Min(4,Math.Max(enemy.RedMist,enemy.PendingRedMist)+2);
                }
            int before=actor.Hp;
            RemiliaSkills.CompleteAttack(actor,key,totalDamage);
            return actor.Name+" · 恢复 "+(actor.Hp-before)+" HP，绯红之主 "+actor.Remilia.Scarlet+"/100"+
                (key==RemiliaSkills.Magic?"；存活命中目标下回合获得红雾":"");
        }
    }
}
