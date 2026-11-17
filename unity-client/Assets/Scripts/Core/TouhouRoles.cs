using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    [Serializable] public sealed class TouhouRoleState
    {
        public int Spark,OrreryUntil;public bool WorldUsed,WatchActive,SpacePending,SpaceActive;public int WorldRound,WatchUntil,DreamOrbs,DreamDue;
        public TouhouRoleState Copy(){return (TouhouRoleState)MemberwiseClone();}
        public string Fingerprint(){return Spark+":"+OrreryUntil+":"+WorldUsed+":"+WorldRound+":"+WatchUntil+":"+WatchActive+":"+SpacePending+":"+SpaceActive+":"+DreamOrbs+":"+DreamDue;}
    }
    public static partial class TouhouRoles
    {
        public static readonly string[] SakuyaCards={"murder_doll","stopwatch","private_square","the_world"};
        public static readonly string[] ReimuCards={"yin_yang_orb","fantasy_seal","demon_seal","fantasy_nature"};
        public static PortCard[] Cards()
        {return new[]{
            new PortCard("murder_doll","杀人玩偶","咲夜专属",2,5,3,3,1,"单币突刺 · 反面5 / 正面8，再结算银色小刀","银刃落下。",1,"attack"),
            new PortCard("stopwatch","咲夜特制秒表","咲夜专属",4,5,15,15,1,"辅助无伤害 · 接下来两回合敌速−3；全队每快2点拼点+1，最多+3","时间由我掌握。",1,"ultimate",noDamage:true),
            new PortCard("private_square","私人空间","咲夜专属",3,5,10,10,1,"定向防御拼点 · 无伤害/护盾；下回合自身速度+3，每击原始+5","留下属于自己的空间。",1,"guard",targeted:true,noDamage:true),
            new PortCard("the_world","咲夜的世界","咲夜专属",5,5,20,20,1,"辅助无伤害 · 下回合仅咲夜行动，三个不限类别技能槽；每场一次","世界，静止吧。",1,"ultimate",noDamage:true),
            new PortCard("yin_yang_orb","阴阳宝玉","灵梦专属",1,3,2,2,2,"初始3 · 正面攻币+2，逐币累计 · 伤害后退治+1，每次技能最多1层","退治开始。",2,"attack"),
            new PortCard("fantasy_seal","梦想妙珠","灵梦专属",2,1,2,2,5,"五币 · 初始1，正面攻币+2逐币累计 · 伤害后叠退治，每次技能最多2层","让宝玉追逐目标。",2,"attack"),
            new PortCard("demon_seal","封魔阵","灵梦专属",4,5,5,5,1,"必须拼点 · 无伤害/护盾；获胜使目标和左侧最近存活敌人下回合拼点−2","封魔之阵。",2,"guard",targeted:true,requiresClash:true,noDamage:true),
            new PortCard("fantasy_nature","梦想天生","灵梦专属",5,10,10,10,1,"必须拼赢 · 无直接伤害；宝玉1层，后续拼赢至多3层；三回合后按宝玉×退治×5结算，灵梦退场","短暂离开现世。",2,"ultimate",requiresClash:true,noDamage:true)
        }.Concat(MarisaDefinitions()).ToArray();}
        public static Unit Sakuya(){return new Unit{Name="十六夜咲夜",Role="时停",CharacterId="sakuya",Hp=40,MaxHp=40,MinSpeed=5,MaxSpeed=9,RoleState=new TouhouRoleState()};}
        public static Unit Reimu(){return new Unit{Name="博丽灵梦",Role="退治",CharacterId="reimu",Hp=50,MaxHp=50,MinSpeed=5,MaxSpeed=7,RoleState=new TouhouRoleState()};}
        public static int SilverKnife(int turn){return turn<=2?5:turn==3?2:0;}
    }
    public partial class PortBattleRules
    {
        void PrepareTouhouRound()
        {
            State.WorldActive=false;if(!State.TouhouTeam)return;var s=State.Heroes[1].RoleState;
            s.WatchActive=State.Turn<=s.WatchUntil;s.SpaceActive=s.SpacePending;s.SpacePending=false;State.WorldActive=State.Heroes[1].Hp>0&&State.Turn==s.WorldRound;
            foreach(var enemy in State.Enemies){enemy.ExorcismActive=enemy.ExorcismPending;enemy.ExorcismPending=false;enemy.SealActive=enemy.SealPending;enemy.SealPending=false;}
        }
        int TouhouSpeed(bool allied,int unit)
        {if(!State.TouhouTeam)return 0;var s=State.Heroes[1].RoleState;return !allied?(s.WatchActive?-3:0):unit==1&&s.SpaceActive?3:0;}
        int TouhouHeroClash(PortSlot hero,PortSlot enemy)
        {if(!State.TouhouTeam)return 0;var s=State.Heroes[1].RoleState;return (s.WatchActive?Math.Max(0,Math.Min(3,(hero.Speed-enemy.Speed)/2)):0)+(hero.Unit==2&&State.Enemies[enemy.Unit].GensokyoNative?1:0);}
        int TouhouEnemyClash(int unit)
        {var e=State.Enemies[unit];return State.TouhouTeam?-(e.ExorcismActive?3:0)-(e.SealActive?2:0):0;}
        IEnumerable<CoinEffect> TouhouAttackEffects(bool allied,int unit)
        {
            if(State.TouhouTeam&&allied&&unit==1){var s=State.Heroes[1].RoleState;int bonus=TouhouRoles.SilverKnife(State.Turn)+(s.SpaceActive?5:0);if(bonus!=0)yield return new CoinEffect("银色小刀/私人空间",CoinTrigger.SkillStart,CoinStat.RawDamage,bonus);}
        }
        void ReleaseTouhou(List<PortEvent> events,PortSlot slot,bool wonClash)
        {
            if(!State.TouhouTeam)return;string key=slot.Key;
            if(slot.Unit==1)
            {
                var s=State.Heroes[1].RoleState;
                if(key=="stopwatch"){s.WatchUntil=State.Turn+2;Emit(events,"ability","咲夜特制秒表：接下来两回合敌速−3，全队按速度差强化拼点",1);}
                if(key=="private_square"){s.SpacePending=true;Emit(events,"ability","私人空间：下回合自身速度+3，每枚攻击硬币原始伤害+5",1);}
                if(key=="the_world"){s.WorldRound=State.Turn+1;Emit(events,"ability","咲夜的世界：下回合仅咲夜行动，三个独立技能槽",1);}
            }
            if(slot.Unit!=2||!wonClash)return;var r=State.Heroes[2].RoleState;
            if(r.DreamDue>0&&r.DreamOrbs<3){r.DreamOrbs++;Emit(events,"ability","梦想宝玉："+r.DreamOrbs+" / 3",2);}
            if(key=="demon_seal")
            {
                int target=State.EnemySlots[slot.Target].Unit;State.Enemies[target].SealPending=true;
                for(int left=target-1;left>=0;left--)if(State.Enemies[left].Hp>0){State.Enemies[left].SealPending=true;break;}
                Emit(events,"ability","封魔阵：目标与左侧最近存活敌人，下回合拼点初始−2",2,target);
            }
            if(key=="fantasy_nature"){r.DreamOrbs=1;r.DreamDue=State.Turn+3;Emit(events,"ability","梦想天生蓄能：第 "+r.DreamDue+" 回合结束发动，死亡则取消",2);}
        }
        void MarkTouhouHit(List<PortEvent> events,string key,int source,int target,int damage,ref int marks)
        {
            if(!State.TouhouTeam||source!=2||damage<=0||marks<=0||State.Enemies[target].Hp<=0)return;
            marks--;var e=State.Enemies[target];e.Exorcism++;
            if(e.Exorcism>=4){e.Exorcism=0;e.ExorcismPending=true;Emit(events,"ability",e.Name+" 退治引爆：下回合拼点初始−3，伤害减半",2,target);}else Emit(events,"ability",e.Name+" 退治 "+e.Exorcism+" / 4",2,target);
        }
        void ResolveDream(List<PortEvent> events)
        {
            if(!State.TouhouTeam||State.Outcome!="")return;var hero=State.Heroes[2];var r=hero.RoleState;
            if(hero.Hp<=0){r.DreamDue=0;r.DreamOrbs=0;return;}if(r.DreamDue!=State.Turn)return;
            Emit(events,"ability","梦想天生：持续状态结算，不产生额外攻击或硬币",2);
            for(int i=0;i<State.Enemies.Count;i++)
            {
                var e=State.Enemies[i];int raw=5*r.DreamOrbs*e.Exorcism;if(e.Hp<=0||raw<=0)continue;int blocked=Math.Min(e.Shield,raw),damage=raw-blocked;e.Shield-=blocked;e.Hp=Math.Max(0,e.Hp-damage);
                var ev=Emit(events,"status_damage",e.Name+" 梦想天生状态伤害 "+damage+"（原始 "+raw+"）",2,i);ev.Damage=damage;
            }
            hero.Hp=0;r.DreamDue=0;r.DreamOrbs=0;Emit(events,"ability","博丽灵梦因梦想天生退场",2);
        }
    }
}

