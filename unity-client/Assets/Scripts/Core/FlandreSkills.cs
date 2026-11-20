using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    [Serializable]
    public sealed class FlandreState
    {
        public int Existence,PuppetPower,ChargeTurn;
        public bool LethalPending,LastAct,Retired;
        public FlandreState Copy(){return (FlandreState)MemberwiseClone();}
        public FlandreState NextEncounter()
        {return new FlandreState{Existence=Existence,LastAct=LastAct,Retired=Retired};}
        public override string ToString(){return Existence+":"+PuppetPower+":"+ChargeTurn+":"+LethalPending+":"+LastAct+":"+Retired;}
    }

    public static class FlandreSkills
    {
        public const string Charge="flandre_charge", Release="flandre_release", Rainbow="flandre_rainbow",
            Ricochet="flandre_ricochet", Clock="flandre_clock", Nobody="flandre_nobody", Ripple="flandre_ripple";
        public const string MusicEvent="flandre_music";
        public static readonly string[] Cards={Charge,Rainbow,Ricochet,Clock,Nobody,Ripple};
        public static Unit Create()
        {
            return new Unit{Name="芙兰朵露·斯卡雷特",CharacterId="flandre",Role="四重存在",Hp=20,MaxHp=20,
                MinSpeed=5,MaxSpeed=7,Flandre=new FlandreState(),RoleState=new TouhouRoleState()};
        }
        public static IEnumerable<PortCard> Definitions()
        {
            return new[]{
                new PortCard(Charge,"莱万汀","芙兰朵露专属",5,0,0,0,0,"不拼点，进入蓄力。蓄力中不能攻击或拼点，下回合起可对敌方全体释放。","握住火焰。",1,"ultimate",noDamage:true,allowsClash:false,selfTarget:true),
                new PortCard(Release,"莱万汀释放","芙兰朵露专属",0,0,0,0,0,"释放蓄力，对各敌造成蓄力回合×当前HP的伤害。","火焰出鞘。",1,"ultimate",noDamage:true,allowsClash:false,selfTarget:true),
                new PortCard(Rainbow,"星虹破","芙兰朵露专属",3,6,4,4,2,"两币，最多3名敌人，各自全正裸伤14。","虹光散开。",1,"attack",splitAttackPower:true),
                new PortCard(Ricochet,"折反射","芙兰朵露专属",3,7,3,3,3,"三币，对单个目标全正裸伤16。","折过下一道弧线。",1,"attack",splitAttackPower:true),
                new PortCard(Clock,"铭刻过去的钟","芙兰朵露专属",4,10,6,6,1,"一币，敌方全体各受伤害。命中的敌人下回合最终伤害−2。","停在刻度上。",1,"ultimate"),
                new PortCard(Nobody,"然后谁也不在了","芙兰朵露专属",10,0,0,0,0,"增加当前与上限HP：20×(4−存在)。存在固定为4，失去保命；此后每次行动扣5 HP。","声音消失了。",1,"guard",noDamage:true,allowsClash:false),
                new PortCard(Ripple,"495年的波纹","芙兰朵露专属",10,15,10,10,1,"牺牲当前HP的一半（向下取整），其余所有敌友各受牺牲量×存在层数。","波纹向四周扩散。",1,"ultimate")
            };
        }

        public static bool MemberCanAct(Unit member){return member.Hp>0&&!member.Puppet;}

        public static string Limit(Unit actor,PortCard card,int turn)
        {
            var state=actor.Flandre;if(state==null)return "";
            if(card.Id==Charge&&(state.ChargeTurn>0||state.Existence>=4))return "当前不能开始莱万汀蓄力";
            if(card.Id==Release&&(state.ChargeTurn==0||turn<=state.ChargeTurn||state.Existence>=4))return "下回合起才能释放莱万汀";
            if(card.Id==Nobody&&state.LastAct)return "该状态已生效";
            if(state.ChargeTurn>0&&card.TargetsEnemy)return "莱万汀蓄力中，不能攻击或拼点";
            return "";
        }

        public static int Receive(Unit victim,Unit source,int amount,Action<string,bool> report)
        {
            if(amount<=0||victim.Hp<=0)return 0;
            if(victim.Puppet)
            {
                report(victim.Name+" · 忒乐忒乐邦邦娜巴拉尼",true);
                return 0;
            }
            var role=victim.Flandre;
            if(amount<victim.Hp){victim.Hp-=amount;return amount;}
            int loss=victim.Hp-1;
            if(role!=null&&!role.LastAct&&!role.Retired&&role.Existence<4)
            {
                victim.Hp=1;
                if(!role.LethalPending)report(victim.Name+" · 四重存在挡下致命伤",false);
                role.LethalPending=true;
                return loss;
            }
            if(source!=null&&source.Flandre!=null)
            {
                victim.Hp=1;victim.Puppet=true;
                if(role!=null)role.Retired=true;
                source.Flandre.PuppetPower=Math.Min(3,source.Flandre.PuppetPower+1);
                report(victim.Name+" 进入忒乐忒乐邦邦娜巴拉尼，停止行动",false);
                return loss;
            }
            victim.Hp=0;
            if(role!=null)role.Retired=true;
            return amount;
        }

        public static void EndRound(Unit member,Action<string,bool> report)
        {
            var role=member.Flandre;
            if(role==null||!role.LethalPending||role.LastAct||role.Retired)return;
            role.LethalPending=false;role.Existence++;
            if(role.Existence>=4)
            {
                role.Retired=true;member.Hp=0;
                report(member.Name+" · 四重存在达到4，永久退场",false);
            }
            else
            {
                member.Hp=member.MaxHp;
                report(member.Name+" · 恢复满血，存在 "+role.Existence+"/4",false);
            }
        }

        public static void EndAction(Unit member,bool wasLastAct,Action<string,bool> report)
        {
            if(!wasLastAct||member.Flandre==null||!MemberCanAct(member))return;
            member.Hp=Math.Max(0,member.Hp-5);
            if(member.Hp==0)member.Flandre.Retired=true;
            report(member.Name+" · 终幕行动代价 −5 HP"+(member.Hp==0?"，永久退场":""),false);
        }

        public static bool UseSupport(Unit actor,string key,int turn,Action<int> hitGroup,Action<string,bool> report)
        {
            var state=actor.Flandre;if(state==null)return false;
            if(key==Charge)
            {state.ChargeTurn=turn;report("莱万汀开始蓄力，可在下回合起释放",false);return true;}
            if(key==Release)
            {
                int damage=(turn-state.ChargeTurn)*actor.Hp;
                state.ChargeTurn=0;
                report("莱万汀释放 · 每个敌方目标 "+damage+" 原始伤害",false);
                hitGroup(damage);
                return true;
            }
            if(key!=Nobody)return false;
            int gained=20*(4-state.Existence);
            state.Existence=4;state.LastAct=true;state.LethalPending=false;state.ChargeTurn=0;
            actor.MaxHp+=gained;actor.Hp+=gained;
            report("然后谁也不在了 · 当前与上限HP +"+gained+"；四重存在保命结束",false);
            return true;
        }

        public static int RipplePower(Unit actor,Action<string,bool> report)
        {
            int spent=actor.Hp/2;actor.Hp-=spent;
            int damage=spent*actor.Flandre.Existence;
            report("495年的波纹 · 自身损失 "+spent+" HP，其余每名单位受 "+damage+" 原始伤害",false);
            return damage;
        }

        public static bool HitsAllEnemies(string key){return key==Clock||key==Ripple;}

        public static IEnumerable<int> Targets(string key,int primary,IList<Unit> enemies)
        {
            if(HitsAllEnemies(key))return Enumerable.Range(0,enemies.Count);
            if(key!=Rainbow)return new[]{primary};
            return new[]{primary}.Concat(Enumerable.Range(0,enemies.Count).Where(i=>i!=primary&&enemies[i].Hp>0).Take(2));
        }
    }
}
