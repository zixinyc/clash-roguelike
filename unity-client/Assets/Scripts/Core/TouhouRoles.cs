using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    [Serializable] public sealed class TouhouRoleState
    {
        public int Spark,OrreryUntil,WorldRound,WatchUntil,DreamOrbs,DreamDue,DodgeTurn,DodgePower,BarrierFrom,BarrierUntil;
        public bool WorldUsed,WatchActive,SpacePending,SpaceActive;
        public TouhouRoleState Copy(){return (TouhouRoleState)MemberwiseClone();}
        public string Fingerprint(){return Spark+":"+OrreryUntil+":"+WorldUsed+":"+WorldRound+":"+WatchUntil+":"+WatchActive+":"+
            SpacePending+":"+SpaceActive+":"+DreamOrbs+":"+DreamDue+":"+DodgeTurn+":"+DodgePower+":"+BarrierFrom+":"+BarrierUntil;}
    }

    public static partial class TouhouRoles
    {
        public const int WorldActionSlots=3;
        public static readonly string[] SakuyaCards={"murder_doll","stopwatch","private_square","the_world","misdirection","engraved_soul"};
        public static readonly string[] ReimuCards={"yin_yang_orb","fantasy_seal","demon_seal","fantasy_nature","eight_way_bind","danmaku_barrier"};
        public static PortCard[] Cards()
        {
            return new[]{
                new PortCard("murder_doll","杀人玩偶","咲夜专属",2,5,5,5,1,"正面10 / 反面5，再结算银色小刀。","银刃落下。",1,"attack"),
                new PortCard("stopwatch","咲夜特制秒表","咲夜专属",4,5,15,15,1,"无伤害；随后两回合敌方速度−3，我方每快2点拼点+1（最多+3）。","时间由我掌握。",1,"ultimate",noDamage:true),
                new PortCard("private_square","私人空间","咲夜专属",3,5,10,10,1,"防御拼点，无伤害；下回合自身速度+3，每次技能伤害+5。","留下属于自己的空间。",1,"guard",targeted:true,noDamage:true),
                new PortCard("the_world","咲夜的世界","咲夜专属",5,5,20,20,1,"每场一次；下回合仅咲夜行动，开放三个行动槽，敌方不能行动或拼点。","世界，静止吧。",1,"ultimate",noDamage:true),
                new PortCard("misdirection","误导","咲夜专属",2,0,0,0,0,"不拼点；本回合闪避点数10。施放速度≥9时点数15，每次闪避反击5。","踪迹已换。",1,"guard",noDamage:true,allowsClash:false),
                new PortCard("engraved_soul","铭刻血魂","咲夜专属",4,5,4,4,3,"三币，最多3名敌人；全正裸伤17，再结算银色小刀。","刀刃铭下刻痕。",1,"ultimate",splitAttackPower:true),
                new PortCard("yin_yang_orb","阴阳宝玉","灵梦专属",1,3,3,3,2,"两币，全正裸伤9；命中追加1层退治。","退治开始。",2,"attack",splitAttackPower:true),
                new PortCard("fantasy_seal","梦想妙珠","灵梦专属",2,1,3,3,5,"五币，全正裸伤16；按命中数叠退治，每回合最多2层。","让宝玉追逐目标。",2,"attack",splitAttackPower:true),
                new PortCard("demon_seal","封魔阵","灵梦专属",4,5,7,7,1,"拼赢后目标及左侧第一个存活敌人下回合最终拼点−2。","封魔之阵。",2,"guard",targeted:true,requiresClash:true,noDamage:true),
                new PortCard("fantasy_nature","梦想天生","灵梦专属",5,10,10,10,1,"拼赢蓄能3回合；宝玉最多3，退治最多6且不引爆。结算10×宝玉×各敌退治，灵梦退场。","短暂离开现世。",2,"ultimate",requiresClash:true,noDamage:true),
                new PortCard("eight_way_bind","八方鬼缚阵","灵梦专属",5,6,10,10,1,"不拼点；目标退治+1、下回合速度−1；所有存活队友获6或16护盾。","八方锁定。",2,"guard",targeted:true,noDamage:true,allowsClash:false),
                new PortCard("danmaku_barrier","博丽弹幕结界","灵梦专属",8,10,12,12,1,"拼赢布置三回合结界；灵梦速度为1，敌速−1，敌每次行动受5伤并叠退治。","结界展开。",2,"ultimate",requiresClash:true,noDamage:true)
            }.Concat(MarisaDefinitions()).ToArray();
        }
        public static Unit Sakuya(){return new Unit{Name="十六夜咲夜",Role="时停",CharacterId="sakuya",Hp=40,MaxHp=40,MinSpeed=5,MaxSpeed=9,RoleState=new TouhouRoleState()};}
        public static Unit Reimu(){return new Unit{Name="博丽灵梦",Role="退治",CharacterId="reimu",Hp=50,MaxHp=50,MinSpeed=4,MaxSpeed=6,RoleState=new TouhouRoleState()};}
        public static int SilverKnife(int turn){return turn<=2?5:turn==3?2:0;}
    }

    public partial class PortBattleRules
    {
        int SakuyaActor {get{return State.Actor("sakuya");}}
        int ReimuActor {get{return State.Actor("reimu");}}
        TouhouRoleState SakuyaStatus {get{return SakuyaActor<0?null:State.Heroes[SakuyaActor].RoleState;}}
        bool BarrierActive
        {
            get
            {
                if(ReimuActor<0||State.Heroes[ReimuActor].Hp<=0)return false;
                var role=State.Heroes[ReimuActor].RoleState;
                return role.BarrierFrom>0&&State.Turn>=role.BarrierFrom&&State.Turn<=role.BarrierUntil;
            }
        }

        void PrepareTouhouRound()
        {
            State.WorldActive=false;
            if(!State.TouhouTeam)return;
            var s=SakuyaStatus;
            if(s!=null)
            {
                s.WatchActive=State.Turn<=s.WatchUntil;
                s.SpaceActive=s.SpacePending;
                s.SpacePending=false;
                State.WorldActive=State.Heroes[SakuyaActor].Hp>0&&State.Turn==s.WorldRound;
            }
            foreach(var enemy in State.Enemies)
            {
                enemy.ExorcismActive=enemy.ExorcismPending;
                enemy.ExorcismPending=false;
                enemy.SealActive=enemy.SealPending;
                enemy.SealPending=false;
            }
        }

        int TouhouSpeed(bool allied,int unit,int rolled)
        {
            if(!State.TouhouTeam)return rolled;
            var s=SakuyaStatus;
            if(allied)
            {
                if(unit==ReimuActor&&BarrierActive)return 1;
                return rolled+(unit==SakuyaActor&&s.SpaceActive?3:0);
            }
            return rolled-(s!=null&&s.WatchActive?3:0)-(BarrierActive?1:0)-(State.Enemies[unit].BindingTurn==State.Turn?1:0);
        }

        int TouhouHeroClash(PortSlot hero,PortSlot enemy)
        {
            if(!State.TouhouTeam)return 0;
            int gap=Math.Max(0,hero.Speed-enemy.Speed);
            int bonus=SakuyaStatus!=null&&SakuyaStatus.WatchActive?Math.Min(3,gap/2):0;
            if(State.Heroes[hero.Unit].CharacterId=="sakuya")bonus+=Math.Min(3,gap);
            if(hero.Unit==ReimuActor&&State.Enemies[enemy.Unit].GensokyoNative)bonus++;
            return bonus;
        }

        int TouhouEnemyClash(int unit)
        {var e=State.Enemies[unit];return State.TouhouTeam?-(e.ExorcismActive?3:0)-(e.SealActive?2:0):0;}

        int SakuyaSkillDamage()
        {return TouhouRoles.SilverKnife(State.Turn)+(SakuyaStatus.SpaceActive?5:0);}

        bool ActivateNonClashTouhou(List<PortEvent> events,PortSlot slot)
        {
            if(!State.TouhouTeam)return false;
            if(slot.Key=="misdirection")
            {
                var s=SakuyaStatus;
                s.DodgeTurn=State.Turn;
                s.DodgePower=slot.Speed>=9?15:10;
                Emit(events,"ability","误导：本回合闪避点数 "+s.DodgePower,slot.Unit);
                return true;
            }
            if(slot.Key!="eight_way_bind")return false;
            var target=State.EnemySlots[slot.Target].Unit;
            if(State.Enemies[target].Hp<=0)return true;
            var roll=CoinRuntime(PortContent.Card(slot.Key),true,slot.Unit,target).NextAttack(new CoinRandomSource(FlipCoin));
            foreach(var ally in State.Heroes.Where(u=>u.Hp>0))ally.Shield+=roll.RawDamage;
            State.Enemies[target].BindingTurn=State.Turn+1;
            AddExorcism(events,target);
            var signal=Emit(events,"guard","八方鬼缚阵：存活队友获得 "+roll.RawDamage+" 护盾；目标下回合速度−1",slot.Unit,target);
            signal.Coin=roll;
            return true;
        }

        bool SakuyaDodges(List<PortEvent> events,int source,int target,int power)
        {
            if(!State.TouhouTeam||target!=SakuyaActor||power<=0)return false;
            var role=SakuyaStatus;
            if(role.DodgeTurn!=State.Turn||power>role.DodgePower)return false;
            Emit(events,"ability","误导：闪避点数 "+role.DodgePower+"，避开 "+power+" 点攻击",target,source);
            if(role.DodgePower==15)DealNewHit(events,target,source,5,"status_damage",allowMapBonus:false);
            return true;
        }

        void ReleaseTouhou(List<PortEvent> events,PortSlot slot,bool wonClash)
        {
            if(!State.TouhouTeam)return;
            string key=slot.Key;
            if(slot.Unit==SakuyaActor)
            {
                var s=SakuyaStatus;
                if(key=="stopwatch"){s.WatchUntil=State.Turn+2;Emit(events,"ability","咲夜特制秒表：接下来两回合敌速−3，我方按速度差强化拼点",slot.Unit);}
                if(key=="private_square"){s.SpacePending=true;Emit(events,"ability","私人空间：下回合速度+3，技能伤害+5",slot.Unit);}
                if(key=="the_world"){s.WorldRound=State.Turn+1;Emit(events,"ability","咲夜的世界：下回合仅咲夜行动，可安排三次",slot.Unit);}
            }
            if(slot.Unit!=ReimuActor||!wonClash)return;
            var r=State.Heroes[ReimuActor].RoleState;
            if(r.DreamDue>0&&r.DreamOrbs<3){r.DreamOrbs++;Emit(events,"ability","梦想宝玉："+r.DreamOrbs+" / 3",slot.Unit);}
            if(key=="demon_seal")
            {
                int target=State.EnemySlots[slot.Target].Unit;
                State.Enemies[target].SealPending=true;
                for(int left=target-1;left>=0;left--)
                    if(State.Enemies[left].Hp>0){State.Enemies[left].SealPending=true;break;}
                Emit(events,"ability","封魔阵：目标与左侧最近存活敌人，下回合最终拼点−2",slot.Unit,target);
            }
            if(key=="fantasy_nature")
            {
                r.DreamOrbs=1;
                r.DreamDue=State.Turn+3;
                Emit(events,"ability","梦想天生：第 "+r.DreamDue+" 回合末结算，蓄力期间退治最多6层且不引爆",slot.Unit);
            }
            if(key=="danmaku_barrier")
            {
                if(!BarrierActive)r.BarrierFrom=State.Turn+1;
                r.BarrierUntil=State.Turn+3;
                Emit(events,"ability","博丽弹幕结界：接下来三回合敌速−1、行动受5伤并叠退治；灵梦速度为1",slot.Unit);
            }
        }

        void MarkTouhouHit(List<PortEvent> events,int source,int target,ref int marks)
        {
            if(!State.TouhouTeam||source!=ReimuActor||marks<=0||State.Enemies[target].Hp<=0)return;
            marks--;
            AddExorcism(events,target);
        }

        void AddExorcism(List<PortEvent> events,int target)
        {
            var e=State.Enemies[target];
            if(e.Hp<=0)return;
            bool charging=State.Heroes[ReimuActor].RoleState.DreamDue>0;
            e.Exorcism=Math.Min(charging?6:4,e.Exorcism+1);
            if(!charging&&e.Exorcism>=4)
            {
                e.Exorcism=0;
                e.ExorcismPending=true;
                Emit(events,"ability",e.Name+" 退治引爆：下回合拼点−3，伤害减半",ReimuActor,target);
            }
            else Emit(events,"ability",e.Name+" 退治 "+e.Exorcism+" / "+(charging?6:4),ReimuActor,target);
        }

        bool BarrierAllowsAction(List<PortEvent> events,PortSlot enemy)
        {
            if(!BarrierActive)return true;
            DealNewHit(events,ReimuActor,enemy.Unit,5,"status_damage",allowMapBonus:false);
            AddExorcism(events,enemy.Unit);
            return State.Enemies[enemy.Unit].Hp>0;
        }

        void ResolveDream(List<PortEvent> events)
        {
            if(ReimuActor<0||State.Outcome!="")return;
            var hero=State.Heroes[ReimuActor];
            var r=hero.RoleState;
            if(hero.Hp<=0){r.DreamDue=0;r.DreamOrbs=0;return;}
            if(r.DreamDue!=State.Turn)return;
            Emit(events,"ability","梦想天生：按各敌退治层数轰炸",ReimuActor);
            var marked=Enumerable.Range(0,State.Enemies.Count).Where(i=>State.Enemies[i].Exorcism>0&&r.DreamOrbs>0);
            DealGroupHit(events,ReimuActor,"梦想天生",marked,i=>10*r.DreamOrbs*State.Enemies[i].Exorcism);
            hero.Hp=0;
            r.DreamDue=0;
            r.DreamOrbs=0;
            Emit(events,"ability","博丽灵梦因梦想天生退场",ReimuActor);
        }
    }
}
