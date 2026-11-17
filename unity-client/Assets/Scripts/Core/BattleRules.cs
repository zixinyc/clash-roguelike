using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    [Serializable] public sealed class Skill
    {
        public string Id, Name, Tag, Description, Flavor;
        public int Cost;
        public readonly CoinSkill CoinData;
        public int Base {get{return CoinData.BasePower;}}public int BasePower {get{return CoinData.BasePower;}}
        public int ClashCoinPower {get{return CoinData.ClashCoinPower;}}public int AttackCoinPower {get{return CoinData.AttackCoinPower;}}
        public int Coins {get{return CoinData.CoinCount;}}public int CoinCount {get{return CoinData.CoinCount;}}
        public System.Collections.ObjectModel.ReadOnlyCollection<CoinEffect> Effects {get{return CoinData.Effects;}}
        public bool Guard;
        public Skill(string id, string name, string tag, int cost, int basis, int clashPower, int attackPower, int coins, string description, string flavor, bool guard = false,IEnumerable<CoinEffect> effects=null)
        { Id=id; Name=name; Tag=tag; Cost=cost; CoinData=new CoinSkill(name,basis,clashPower,attackPower,coins,effects); Description=description; Flavor=flavor; Guard=guard; }
    }
    [Serializable] public sealed class Unit
    {
        public string Name, Role, Intent;
        public int Hp, MaxHp, Shield, Base, ClashCoinPower, AttackCoinPower, Coins, Target, Speed, MinSpeed, MaxSpeed;
        public List<CoinStatus> Statuses=new List<CoinStatus>();
        public string CharacterId="";public TouhouRoleState RoleState;public ZixiState Zixi;
        public bool GensokyoNative,ExorcismActive,ExorcismPending,SealActive,SealPending;public int Exorcism;
        public string StatusFingerprint(){return string.Join(";",Statuses.Select(x=>x.Id+":"+x.Stat+":"+x.Value+":"+x.RemainingTurns).ToArray())+"/"+CharacterId+":"+GensokyoNative+":"+Exorcism+":"+ExorcismActive+":"+ExorcismPending+":"+SealActive+":"+SealPending+":"+(RoleState==null?"":RoleState.Fingerprint())+"/"+(Zixi==null?"":Zixi.Fingerprint());}
        public bool Acted, Spent;
        public Unit Copy() { var c=(Unit)MemberwiseClone();c.Statuses=Statuses.Select(x=>x.Copy()).ToList();c.RoleState=RoleState==null?null:RoleState.Copy();c.Zixi=Zixi==null?null:Zixi.Copy();return c; }
    }
    [Serializable] public sealed class PlannedAction
    {
        public int Card, Hero, Enemy, Paid, Order;
        public PlannedAction Copy() { return (PlannedAction)MemberwiseClone(); }
    }
    [Serializable] public sealed class BattleState
    {
        public List<Unit> Heroes = new List<Unit>();
        public List<Unit> Enemies = new List<Unit>();
        public List<string> Hand = new List<string>();
        public List<PlannedAction> Plans = new List<PlannedAction>();
        public int[] LockedClashes = new int[0];
        public int Cost=9, Turn=1, Plays, PlanOrder;
        public bool FirstWinPaid, Resolving;
        public int ReservedCost { get { return Resolving ? 0 : Plans.Sum(x=>x.Paid); } }
        public string Outcome="";
        public BattleState Copy()
        {
            var s=(BattleState)MemberwiseClone();
            s.Heroes=Heroes.Select(x=>x.Copy()).ToList(); s.Enemies=Enemies.Select(x=>x.Copy()).ToList(); s.Hand=new List<string>(Hand); s.Plans=Plans.Select(x=>x.Copy()).ToList(); s.LockedClashes=(int[])LockedClashes.Clone(); return s;
        }
        public string Fingerprint()
        {
            return Cost+"/"+Turn+"/"+Plays+"/"+FirstWinPaid+"/"+Outcome+"/"+Resolving+"/"+PlanOrder+"/"+string.Join(",", Hand.ToArray())+"/"+string.Join(",",LockedClashes.Select(x=>x.ToString()).ToArray())+"/"+
                string.Join(";", Plans.Select(x=>x.Card+":"+x.Hero+":"+x.Enemy+":"+x.Paid+":"+x.Order).ToArray())+"/"+
                string.Join(";", Heroes.Concat(Enemies).Select(x=>x.Name+":"+x.Hp+":"+x.MaxHp+":"+x.Shield+":"+x.Acted+":"+x.Spent+":"+x.Target+":"+x.Base+":"+x.ClashCoinPower+":"+x.AttackCoinPower+":"+x.Coins+":"+x.Speed+":"+x.MinSpeed+":"+x.MaxSpeed+":"+x.StatusFingerprint()).ToArray());
        }
    }
    public sealed class BattleEvent
    {
        public string Type, Skill, Result;
        public int Hero, Enemy, Source, Target, Paid, Amount, Left, Right, LeftHeads, RightHeads, HeroCoins, EnemyCoins, HeroRemaining, EnemyRemaining, Winner, Damage, Blocked, Hit, Total, Speed;
        public bool Allied, Decider;
        public CoinStep Coin;
        public BattleState Snapshot;
        public string Fingerprint() { return Type+":"+Skill+":"+Result+":"+Hero+":"+Enemy+":"+Source+":"+Target+":"+Paid+":"+Amount+":"+Left+":"+Right+":"+LeftHeads+":"+RightHeads+":"+HeroCoins+":"+EnemyCoins+":"+HeroRemaining+":"+EnemyRemaining+":"+Winner+":"+Damage+":"+Blocked+":"+Hit+":"+Total+":"+Speed+":"+Allied+":"+Decider+":"+CoinLog.Fingerprint(Coin)+":"+Snapshot.Fingerprint(); }
    }
    // Explicit integer RNG: results stay stable across Unity versions and presentation speeds.
    public sealed class BattleRandom : ICoinRandom
    {
        uint state;
        public BattleRandom(uint seed) { state=seed==0 ? 0x9E3779B9u : seed; }
        public uint Next() { state^=state<<13; state^=state>>17; state^=state<<5; return state; }
        public double Value() { return Next()/4294967296.0; }
        public bool Flip(double headsChance) { return Value()<headsChance; }
        public int Range(int count)
        {
            if(count<=0) throw new ArgumentOutOfRangeException("count");
            uint limit=uint.MaxValue-(uint.MaxValue%(uint)count), value;
            do { value=Next(); } while(value>=limit);
            return (int)(value%(uint)count);
        }
    }
    public class BattleRules
    {
        public const int MaxPlays=3, BaseIncome=3;
        public static readonly Skill[] Skills = {
            new Skill("cleave","断轨","重击",3,5,4,4,2,"高威力 · 两枚硬币","将退路，一并斩断。"),
            new Skill("ember","余烬斩","斩击",2,4,3,3,2,"均衡威力 · 两枚硬币","火熄灭前，再向前一步。"),
            new Skill("needle","穿隙","突刺",1,3,2,2,2,"低费用 · 两枚硬币","裂隙，往往只需一瞬。"),
            new Skill("steady","定锋","稳势",2,7,1,1,2,"稳定威力 · 两枚硬币","让摇摆的，只剩敌人。"),
            new Skill("guard","守夜","防御",1,0,0,0,0,"获得 9 护盾 · 持续本回合","总有人，要守住最后一盏灯。",true),
            new Skill("risk","孤注","搏命",2,2,4,4,3,"波动威力 · 三枚硬币","把最后的余温，押上。")
        };
        protected BattleRandom Rng;
        int resolutionSpeed;
        public BattleState State { get; private set; }
        public BattleRules(uint seed=73129) { Start(seed); }
        public static Skill GetSkill(string id) { return Array.Find(Skills, x=>x.Id==id); }
        public void Start(uint seed=73129)
        {
            Rng=new BattleRandom(seed); State=new BattleState(); resolutionSpeed=0;
            State.Heroes.Add(new Unit {Name="灰烬",Role="前锋",Hp=36,MaxHp=36,MinSpeed=3,MaxSpeed=6});
            State.Heroes.Add(new Unit {Name="长锋",Role="游刃",Hp=32,MaxHp=32,MinSpeed=5,MaxSpeed=8});
            State.Heroes.Add(new Unit {Name="织火",Role="守望",Hp=34,MaxHp=34,MinSpeed=2,MaxSpeed=5});
            State.Enemies.Add(new Unit {Name="锈刃巡卫",Role="重刃",Hp=38,MaxHp=38,Base=4,ClashCoinPower=3,AttackCoinPower=3,Coins=2,Intent="锈蚀挥砍",Target=0,MinSpeed=2,MaxSpeed=5});
            State.Enemies.Add(new Unit {Name="失序哨兵",Role="刺刃",Hp=32,MaxHp=32,Base=3,ClashCoinPower=3,AttackCoinPower=3,Coins=2,Intent="贯穿指令",Target=1,MinSpeed=4,MaxSpeed=7});
            State.Hand.AddRange(new [] {"cleave","ember","needle","steady","guard"});
            RollSpeeds();
        }
        public string CanPlay(int card, int hero, int enemy)
        {
            if(State.Outcome!="") return "战斗已经结束";
            if(State.Resolving) return "正在结算，不能修改安排";
            if(card<0 || card>=State.Hand.Count) return "先选择一张手牌";
            if(hero<0 || hero>=State.Heroes.Count || State.Heroes[hero].Hp<=0) return "请选择仍在场的小队成员";
            var previous=State.Plans.Find(x=>x.Hero==hero);
            if(State.Heroes[hero].Acted) return "这位成员本回合已经行动";
            if(State.Plans.Count>=MaxPlays && previous==null) return "本回合最多安排 3 张牌";
            if(State.Plans.Any(x=>x.Card==card && x.Hero!=hero)) return "这张牌已被其他成员预留，请先撤销其安排";
            Skill skill=GetSkill(State.Hand[card]);
            if(State.Cost-State.ReservedCost+(previous==null?0:previous.Paid)<skill.Cost) return "可用 cost 不足；可撤销或更换其他安排";
            if(!skill.Guard && (enemy<0 || enemy>=State.Enemies.Count || State.Enemies[enemy].Hp<=0)) return "请选择仍在场的敌人";
            return "";
        }
        public List<BattleEvent> Play(int card, int hero, int enemy)
        {
            var events=new List<BattleEvent>();
            if(CanPlay(card,hero,enemy)!="") return events;
            Skill skill=GetSkill(State.Hand[card]);
            State.Plans.RemoveAll(x=>x.Hero==hero);
            State.Plans.Add(new PlannedAction {Card=card,Hero=hero,Enemy=skill.Guard?-1:enemy,Paid=skill.Cost,Order=++State.PlanOrder});
            State.Plays=State.Plans.Count;
            Emit(events,new BattleEvent {Type="planned",Hero=hero,Enemy=enemy,Skill=skill.Name,Paid=skill.Cost});
            return events;
        }
        public bool Cancel(int hero)
        {
            if(State.Outcome!="" || State.Resolving) return false;
            bool removed=State.Plans.RemoveAll(x=>x.Hero==hero)>0; State.Plays=State.Plans.Count; return removed;
        }
        public bool CanClash(int hero,int enemy)
        { return CanClash(State,hero,enemy); }
        public static bool CanClash(BattleState state,int hero,int enemy)
        {
            if(hero<0 || hero>=state.Heroes.Count || enemy<0 || enemy>=state.Enemies.Count) return false;
            Unit h=state.Heroes[hero],e=state.Enemies[enemy];
            return h.Hp>0 && e.Hp>0 && !e.Spent && (h.Speed>=e.Speed || e.Target==hero);
        }
        public int ClashHero(int enemy)
        { return ClashHero(State,enemy); }
        public static int ClashHero(BattleState state,int enemy)
        {
            if(enemy<0 || enemy>=state.Enemies.Count) return -1;
            if(state.Resolving) return !state.Enemies[enemy].Spent && enemy<state.LockedClashes.Length ? state.LockedClashes[enemy] : -1;
            var plan=state.Plans.Where(x=>x.Enemy==enemy && !GetSkill(state.Hand[x.Card]).Guard && CanClash(state,x.Hero,enemy)).OrderByDescending(x=>x.Order).FirstOrDefault();
            return plan==null?-1:plan.Hero;
        }
        IEnumerable<BattleEvent> ResolveAttack(List<BattleEvent> events,PlannedAction plan,bool clash)
        {
            int hero=plan.Hero,enemy=plan.Enemy,paid=plan.Paid;
            Skill skill=GetSkill(State.Hand[plan.Card]);
            if(skill.Guard) { new CoinAction(skill.CoinData,.65,State.Heroes[hero].Statuses).NextAttack(new CoinRandomSource(FlipCoin));State.Heroes[hero].Shield+=9; Emit(events,new BattleEvent {Type="guard",Hero=hero,Amount=9}); yield break; }
            Unit foe=State.Enemies[enemy];
            var ha=new CoinAction(skill.CoinData,.65,State.Heroes[hero].Statuses,foe.Statuses);
            var ea=new CoinAction(EnemySkill(foe),.5,foe.Statuses,State.Heroes[hero].Statuses);
            if(clash)
            {
                foe.Spent=true;var session=new CoinClash(ha,ea,new CoinRandomSource(FlipCoin));
                while(!session.Complete)
                {
                    var step=session.Step();Emit(events,new BattleEvent {Type="clash",Hero=hero,Enemy=enemy,Left=step.LeftPower,Right=step.RightPower,LeftHeads=step.LeftFaces.Count(x=>x),RightHeads=step.RightFaces.Count(x=>x),HeroCoins=step.LeftBefore,EnemyCoins=step.RightBefore,HeroRemaining=step.LeftRemaining,EnemyRemaining=step.RightRemaining,Winner=step.Winner,Coin=step});
                    foreach(var ev in events)yield return ev;events.Clear();
                }
                Emit(events,new BattleEvent {Type="clash_end",Hero=hero,Enemy=enemy,Winner=session.Winner,Coin=new CoinStep{Type="clash",FinalWinner=session.Winner,Winner=session.Winner,Round=ha.ClashRound,Left=ha.Snapshot(),Right=ea.Snapshot(),LeftRemaining=ha.RemainingCoins,RightRemaining=ea.RemainingCoins}});
                if(session.Winner==0)
                {
                    if(!State.FirstWinPaid) { State.Cost++; State.FirstWinPaid=true; Emit(events,new BattleEvent {Type="reward",Hero=hero,Amount=1}); }
                    Attack(events,true,hero,enemy,ha);
                }
                else
                {
                    int refund=paid/2; State.Cost+=refund; Emit(events,new BattleEvent {Type="refund",Hero=hero,Paid=paid,Amount=refund});
                    Attack(events,false,enemy,hero,ea);
                }
            }
            else { Emit(events,new BattleEvent {Type="unopposed",Hero=hero,Enemy=enemy}); Attack(events,true,hero,enemy,ha); }
        }
        sealed class Resolution
        {
            public int Hero=-1,Enemy=-1,Speed,Order;
            public bool Clash;
        }
        public List<BattleEvent> EndTurn()
        {return EndTurnStream().ToList();}
        public IEnumerable<BattleEvent> EndTurnStream()
        {
            var events=new List<BattleEvent>(); if(State.Outcome!="" || State.Resolving) yield break;
            State.LockedClashes=Enumerable.Range(0,State.Enemies.Count).Select(i=>ClashHero(i)).ToArray();
            State.Resolving=true; resolutionSpeed=0;
            foreach(var plan in State.Plans) { State.Cost-=plan.Paid; Emit(events,new BattleEvent {Type="paid",Hero=plan.Hero,Skill=GetSkill(State.Hand[plan.Card]).Name,Paid=plan.Paid}); }
            foreach(var ev in events)yield return ev;events.Clear();
            var queue=new List<Resolution>(); var paired=new HashSet<int>();
            for(int i=0;i<State.Enemies.Count;i++)
            {
                Unit foe=State.Enemies[i]; if(foe.Hp<=0 || foe.Spent) continue;
                int hero=State.LockedClashes[i];
                if(hero>=0) paired.Add(hero);
                queue.Add(new Resolution {Hero=hero,Enemy=i,Clash=hero>=0,Speed=hero>=0?Math.Max(foe.Speed,State.Heroes[hero].Speed):foe.Speed,Order=hero>=0?hero:State.Heroes.Count+i});
            }
            foreach(var plan in State.Plans)
                if(!paired.Contains(plan.Hero)) queue.Add(new Resolution {Hero=plan.Hero,Enemy=plan.Enemy,Speed=State.Heroes[plan.Hero].Speed,Order=plan.Hero});
            foreach(var action in queue.OrderByDescending(x=>x.Speed).ThenBy(x=>x.Order))
            {
                resolutionSpeed=action.Speed;
                if(action.Hero>=0)
                {
                    var plan=State.Plans.Find(x=>x.Hero==action.Hero);
                    Unit h=State.Heroes[action.Hero]; h.Acted=true;
                    if(action.Clash) State.Enemies[action.Enemy].Spent=true;
                    if(h.Hp<=0 || (action.Enemy>=0 && State.Enemies[action.Enemy].Hp<=0))
                        Emit(events,new BattleEvent {Type="cancelled",Hero=action.Hero,Enemy=action.Enemy,Speed=action.Speed,Result="角色或目标已退场，行动取消"});
                    else
                    {
                        Emit(events,new BattleEvent {Type="action",Allied=true,Hero=action.Hero,Enemy=action.Enemy,Speed=action.Speed,Result=action.Clash?"拼点":action.Enemy<0?"防御":"单方面攻击"});
                        foreach(var ev in ResolveAttack(events,plan,action.Clash))yield return ev;
                    }
                }
                else
                {
                    Unit foe=State.Enemies[action.Enemy]; int target=foe.Target; foe.Spent=true;
                    if(foe.Hp<=0 || target<0 || target>=State.Heroes.Count || State.Heroes[target].Hp<=0)
                        Emit(events,new BattleEvent {Type="cancelled",Hero=target,Enemy=action.Enemy,Speed=action.Speed,Result="角色或目标已退场，行动取消"});
                    else
                    {
                        Emit(events,new BattleEvent {Type="action",Allied=false,Enemy=action.Enemy,Hero=target,Speed=action.Speed,Result="单方面攻击"});
                        Attack(events,false,action.Enemy,target,new CoinAction(EnemySkill(foe),.5,foe.Statuses,State.Heroes[target].Statuses));
                    }
                }
                CheckOutcome(events);foreach(var ev in events)yield return ev;events.Clear();if(State.Outcome!="")yield break;
            }
            State.Turn++; State.Plays=0; State.FirstWinPaid=false; State.Cost+=BaseIncome;
            State.Plans.Clear(); State.LockedClashes=new int[0]; State.PlanOrder=0; State.Resolving=false;
            foreach(Unit h in State.Heroes) { h.Acted=false; h.Shield=0; }
            foreach(var unit in State.Heroes.Concat(State.Enemies))CoinStatus.NextRound(unit.Statuses);
            for(int i=0;i<State.Enemies.Count;i++) { State.Enemies[i].Spent=false; State.Enemies[i].Target=LivingTarget((State.Turn+i-1)%State.Heroes.Count); }
            var keys=Skills.Select(x=>x.Id).ToList();
            for(int i=keys.Count-1;i>0;i--) { int j=Rng.Range(i+1); string v=keys[i]; keys[i]=keys[j]; keys[j]=v; }
            State.Hand=keys.Take(5).ToList(); RollSpeeds(); Emit(events,new BattleEvent {Type="new_turn",Amount=BaseIncome});foreach(var ev in events)yield return ev;
        }
        void RollSpeeds()
        { foreach(var unit in State.Heroes.Concat(State.Enemies)) unit.Speed=unit.MinSpeed+Rng.Range(unit.MaxSpeed-unit.MinSpeed+1); }
        protected virtual bool FlipCoin(double chance){return Rng.Flip(chance);}
        CoinSkill EnemySkill(Unit enemy){return new CoinSkill(enemy.Intent,enemy.Base,enemy.ClashCoinPower,enemy.AttackCoinPower,enemy.Coins);}
        void Attack(List<BattleEvent> events,bool allied,int source,int target,CoinAction action)
        {
            Unit victim=(allied?State.Enemies:State.Heroes)[target];CoinStep step,last=null;var gameRandom=new CoinRandomSource(FlipCoin);
            while((step=action.NextAttack(gameRandom))!=null)
            {
                bool live=victim.Hp>0;int positive=Math.Max(0,step.RawDamage),blocked=live?Math.Min(victim.Shield,positive):0,damage=live?positive-blocked:0;
                victim.Shield-=blocked; victim.Hp=Math.Max(0,victim.Hp-damage);
                if(live)action.NotifyHit(step.Heads);step.Effects=step.Effects.Concat(action.DrainEffects()).ToArray();last=step;
                Emit(events,new BattleEvent {Type="strike",Allied=allied,Source=source,Target=target,Damage=damage,Blocked=blocked,Hit=step.AttackIndex,Total=step.AttackBudget,Coin=step});
            }
            action.CompleteAttack();if(last!=null){var completed=last.Copy();completed.Left=action.Snapshot();completed.Effects=action.DrainEffects();Emit(events,new BattleEvent{Type="attack_end",Allied=allied,Source=source,Target=target,Coin=completed});}
        }
        int LivingTarget(int preferred)
        { if(preferred>=0 && preferred<State.Heroes.Count && State.Heroes[preferred].Hp>0) return preferred; return State.Heroes.FindIndex(x=>x.Hp>0); }
        void CheckOutcome(List<BattleEvent> events)
        {
            if(!State.Enemies.Any(x=>x.Hp>0)) State.Outcome="victory";
            else if(!State.Heroes.Any(x=>x.Hp>0)) State.Outcome="defeat";
            if(State.Outcome!="") { State.Plans.Clear(); State.LockedClashes=new int[0]; State.Resolving=false; Emit(events,new BattleEvent {Type="outcome",Result=State.Outcome}); }
        }
        void Emit(List<BattleEvent> events,BattleEvent e) { if(State.Resolving&&e.Speed==0) e.Speed=resolutionSpeed; e.Snapshot=State.Copy(); events.Add(e); }
    }
}
