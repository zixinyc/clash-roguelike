using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
namespace ClashRoguelike
{
    public enum CoinTrigger { SkillStart,ClashStart,BeforeClashRound,ClashRoundWin,ClashRoundLoss,ClashTie,ClashEnd,BeforeAttack,AttackHeads,AttackTails,Hit,SkillEnd }
    // Deliberately no coin-count, remaining-coins or attack-count targets.
    public enum CoinStat { BasePower,ClashCoinPower,AttackCoinPower,RawDamage }
    public enum CoinEffectScope { Action,Clash,ClashRound,Attack,Status }
    public enum CoinCondition { Always,ClashWon,ClashLost,Heads,Tails,ActualHit }
    public enum CoinStacking { Add,Replace,Refresh,Ignore }
    public enum CoinRecipient { Self,Opponent }
    public sealed class CoinEffect
    {
        public readonly string Id;public readonly CoinTrigger Trigger;public readonly CoinStat Stat;public readonly int Value,Duration;
        public readonly CoinEffectScope Scope;public readonly CoinCondition Condition;public readonly CoinStacking Stacking;public readonly CoinRecipient Recipient;
        public CoinEffect(string id,CoinTrigger trigger,CoinStat stat,int value,CoinEffectScope scope=CoinEffectScope.Action,int duration=1,CoinStacking stacking=CoinStacking.Add,CoinCondition condition=CoinCondition.Always,CoinRecipient recipient=CoinRecipient.Self)
        {
            if(string.IsNullOrEmpty(id)||!Enum.IsDefined(typeof(CoinTrigger),trigger)||!Enum.IsDefined(typeof(CoinStat),stat)||!Enum.IsDefined(typeof(CoinEffectScope),scope)||!Enum.IsDefined(typeof(CoinCondition),condition)||!Enum.IsDefined(typeof(CoinStacking),stacking)||!Enum.IsDefined(typeof(CoinRecipient),recipient)||duration<1||Math.Abs((long)value)>100000)throw new ArgumentException("Invalid coin effect; counters are not effect targets.");
            if(recipient==CoinRecipient.Opponent&&scope!=CoinEffectScope.Status)throw new ArgumentException("Opponent modifiers must be explicit timed statuses.");
            Id=id;Trigger=trigger;Stat=stat;Value=value;Scope=scope;Duration=duration;Stacking=stacking;Condition=condition;Recipient=recipient;
        }
    }
    public sealed class CoinSkill
    {
        public string Name {get;private set;}public int BasePower {get;private set;}public int ClashCoinPower {get;private set;}public int AttackCoinPower {get;private set;}public int CoinCount {get;private set;}
        public ReadOnlyCollection<CoinEffect> Effects {get;private set;}
        public CoinSkill(string name,int basePower,int clashCoinPower,int attackCoinPower,int coinCount,IEnumerable<CoinEffect> effects=null)
        {
            if(string.IsNullOrEmpty(name)||coinCount<0||coinCount>64||Math.Abs((long)basePower)>100000||Math.Abs((long)clashCoinPower)>100000||Math.Abs((long)attackCoinPower)>100000)throw new ArgumentException("Invalid coin skill data.");
            Name=name;BasePower=basePower;ClashCoinPower=clashCoinPower;AttackCoinPower=attackCoinPower;CoinCount=coinCount;
            var copy=effects==null?new List<CoinEffect>():effects.ToList();if(copy.Any(x=>x==null))throw new ArgumentException("Null skill effect.");Effects=copy.AsReadOnly();
        }
    }
    public sealed class CoinStatus
    {
        public string Id {get;private set;}public CoinStat Stat {get;private set;}public int Value {get;private set;}public int RemainingTurns {get;private set;}
        public CoinStatus(string id,CoinStat stat,int value,int turns){Id=id;Stat=stat;Value=value;RemainingTurns=turns;}
        public CoinStatus Copy(){return new CoinStatus(Id,Stat,Value,RemainingTurns);}
        internal void Refresh(int value,int turns,CoinStacking stacking){if(stacking==CoinStacking.Ignore)return;if(stacking==CoinStacking.Add)Value=checked(Value+value);else if(stacking==CoinStacking.Replace)Value=value;RemainingTurns=turns;}
        public static void NextRound(List<CoinStatus> statuses){foreach(var s in statuses)s.RemainingTurns--;statuses.RemoveAll(x=>x.RemainingTurns<=0);}
    }
    public interface ICoinRandom { bool Flip(double headsChance); }
    public sealed class CoinRandomSource : ICoinRandom
    { readonly Func<double,bool> flip;public CoinRandomSource(Func<double,bool> gameFlip){if(gameFlip==null)throw new ArgumentNullException("gameFlip");flip=gameFlip;}public bool Flip(double chance){return flip(chance);} }
    public sealed class CoinActionSnapshot
    {
        public string Name;public int CoinCount,RemainingCoins,ClashRound,ClashWinner,AttackCount,TotalRawDamage,AttackCoinTotal;public string Phase;
    }
    public sealed class CoinStep
    {
        public string Type;public bool[] LeftFaces=new bool[0],RightFaces=new bool[0];
        public int Round,LeftBase,RightBase,LeftClashPower,RightClashPower,LeftPower,RightPower,LeftBefore,RightBefore,LeftRemaining,RightRemaining,Winner=-1,FinalWinner=-1;
        public int AttackBase,AttackCoinPower,AttackCarry,AttackAccumulated,RawModifier,AttackIndex,AttackBudget,RemainingAttackCoins,RawDamage,TotalRawDamage;public bool Heads;
        public CoinActionSnapshot Left,Right;public string[] Effects=new string[0];
        public CoinStep Copy(){var c=(CoinStep)MemberwiseClone();c.LeftFaces=(bool[])LeftFaces.Clone();c.RightFaces=(bool[])RightFaces.Clone();c.Effects=(string[])Effects.Clone();c.Left=Left==null?null:CopyState(Left);c.Right=Right==null?null:CopyState(Right);return c;}
        static CoinActionSnapshot CopyState(CoinActionSnapshot s){return new CoinActionSnapshot{Name=s.Name,CoinCount=s.CoinCount,RemainingCoins=s.RemainingCoins,ClashRound=s.ClashRound,ClashWinner=s.ClashWinner,AttackCount=s.AttackCount,TotalRawDamage=s.TotalRawDamage,AttackCoinTotal=s.AttackCoinTotal,Phase=s.Phase};}
    }
    public sealed class CoinAction
    {
        sealed class Modifier {public string Id;public CoinStat Stat;public CoinEffectScope Scope;public int Value;}
        readonly CoinSkill skill;readonly double chance;readonly List<CoinEffect> effects;readonly List<Modifier> modifiers=new List<Modifier>();
        readonly List<CoinStatus> ownStatuses,opponentStatuses;readonly List<string> trace=new List<string>();
        int remaining,round,winner=-1,attacks,totalRaw,attackBudget,notifiedAttack,attackCoinTotal;string phase="new";bool started,ended;bool? clashWon;
        public Func<bool,bool,bool> FaceTransform;public Func<int,int> AttackAdjustment;
        public CoinSkill Skill {get{return skill;}}public int RemainingCoins {get{return remaining;}}public int ClashRound {get{return round;}}public int ClashWinner {get{return winner;}}
        public int AttackCount {get{return attacks;}}public int TotalRawDamage {get{return totalRaw;}}public int AttackBudget {get{return attackBudget;}}public string Phase {get{return phase;}}
        public CoinAction(CoinSkill definition,double headsChance,List<CoinStatus> statuses=null,List<CoinStatus> opponent=null,IEnumerable<CoinEffect> additionalEffects=null)
        {
            if(definition==null||double.IsNaN(headsChance)||headsChance<0||headsChance>1)throw new ArgumentException("Invalid coin action.");
            skill=definition;chance=headsChance;remaining=skill.CoinCount;ownStatuses=statuses??new List<CoinStatus>();opponentStatuses=opponent??new List<CoinStatus>();effects=skill.Effects.ToList();if(additionalEffects!=null)effects.AddRange(additionalEffects);if(effects.Any(x=>x==null))throw new ArgumentException("Null action effect.");
        }
        public CoinActionSnapshot Snapshot(){return new CoinActionSnapshot{Name=skill.Name,CoinCount=skill.CoinCount,RemainingCoins=remaining,ClashRound=round,ClashWinner=winner,AttackCount=attacks,TotalRawDamage=totalRaw,AttackCoinTotal=attackCoinTotal,Phase=phase};}
        bool Matches(CoinCondition c,bool? heads,bool hit){return c==CoinCondition.Always||c==CoinCondition.ClashWon&&clashWon==true||c==CoinCondition.ClashLost&&clashWon==false||c==CoinCondition.Heads&&heads==true||c==CoinCondition.Tails&&heads==false||c==CoinCondition.ActualHit&&hit;}
        void Trigger(CoinTrigger timing,bool? heads=null,bool hit=false)
        {
            foreach(var e in effects.Where(x=>x.Trigger==timing&&Matches(x.Condition,heads,hit)))
            {
                if(e.Scope==CoinEffectScope.Status)
                {
                    var statuses=e.Recipient==CoinRecipient.Self?ownStatuses:opponentStatuses;var old=statuses.FirstOrDefault(x=>x.Id==e.Id&&x.Stat==e.Stat);
                    if(old==null)statuses.Add(new CoinStatus(e.Id,e.Stat,e.Value,e.Duration));else old.Refresh(e.Value,e.Duration,e.Stacking);
                }
                else
                {
                    var old=modifiers.FirstOrDefault(x=>x.Id==e.Id&&x.Stat==e.Stat&&x.Scope==e.Scope);
                    if(old==null)modifiers.Add(new Modifier{Id=e.Id,Stat=e.Stat,Scope=e.Scope,Value=e.Value});else if(e.Stacking==CoinStacking.Add)old.Value=checked(old.Value+e.Value);else if(e.Stacking==CoinStacking.Replace)old.Value=e.Value;
                }
                trace.Add(e.Id+" / "+timing+" / "+e.Stat+" "+(e.Value>=0?"+":"")+e.Value+(e.Scope==CoinEffectScope.Status?" / "+e.Duration+" 回合":" / "+e.Scope));
            }
        }
        int Value(CoinStat stat,bool clash)
        {
            int basis=stat==CoinStat.BasePower?skill.BasePower:stat==CoinStat.ClashCoinPower?skill.ClashCoinPower:stat==CoinStat.AttackCoinPower?skill.AttackCoinPower:0;
            return checked(basis+ownStatuses.Where(x=>x.Stat==stat&&x.RemainingTurns>0).Sum(x=>x.Value)+modifiers.Where(x=>x.Stat==stat&&(x.Scope==CoinEffectScope.Action||clash&&(x.Scope==CoinEffectScope.Clash||x.Scope==CoinEffectScope.ClashRound)||!clash&&x.Scope==CoinEffectScope.Attack)).Sum(x=>x.Value));
        }
        void Start(){if(started)return;started=true;Trigger(CoinTrigger.SkillStart);}
        internal void StartClash(){if(phase!="new"||remaining==0)throw new InvalidOperationException("This action cannot enter another clash.");Start();phase="clash";Trigger(CoinTrigger.ClashStart);}
        internal void BeforeRound(){if(phase!="clash")throw new InvalidOperationException("Not clashing.");round++;modifiers.RemoveAll(x=>x.Scope==CoinEffectScope.ClashRound);Trigger(CoinTrigger.BeforeClashRound);}
        internal bool[] RollClash(ICoinRandom random,out int basis,out int power,out int result)
        {basis=Value(CoinStat.BasePower,true);power=Value(CoinStat.ClashCoinPower,true);var faces=new bool[remaining];for(int i=0;i<faces.Length;i++){bool face=random.Flip(chance);faces[i]=FaceTransform==null?face:FaceTransform(face,true);}result=checked(basis+faces.Count(x=>x)*power);return faces;}
        internal void RoundResult(int result)
        {if(phase!="clash")throw new InvalidOperationException("Not clashing.");if(result<0)Trigger(CoinTrigger.ClashTie);else if(result==0)Trigger(CoinTrigger.ClashRoundWin);else{remaining--;Trigger(CoinTrigger.ClashRoundLoss);}}
        internal void EndClash(bool won,int globalWinner){winner=globalWinner;clashWon=won;phase=won?"ready":"lost";Trigger(CoinTrigger.ClashEnd);if(!won)Finish();}
        public CoinStep NextAttack(ICoinRandom random)
        {
            if(random==null)throw new ArgumentNullException("random");
            if(phase=="lost"||phase=="complete"||phase=="clash")return null;
            if(phase=="new"){Start();phase="ready";}
            if(phase=="ready"){attackBudget=remaining;phase="attack";}
            if(remaining==0){Finish();return null;}
            modifiers.RemoveAll(x=>x.Scope==CoinEffectScope.Attack);Trigger(CoinTrigger.BeforeAttack);
            bool heads=random.Flip(chance);if(FaceTransform!=null)heads=FaceTransform(heads,false);Trigger(heads?CoinTrigger.AttackHeads:CoinTrigger.AttackTails,heads);
            int basis=Value(CoinStat.BasePower,false),power=Value(CoinStat.AttackCoinPower,false),modifier=checked(Value(CoinStat.RawDamage,false)+(AttackAdjustment==null?0:AttackAdjustment(attacks+1))),carry=attackCoinTotal;
            // Carry only prior attack-coin contributions, never prior base, raw modifiers or clash rolls.
            attackCoinTotal=checked(attackCoinTotal+(heads?power:0));
            int raw=checked(basis+attackCoinTotal+modifier);
            remaining--;attacks++;totalRaw=checked(totalRaw+raw);
            return new CoinStep{Type="attack",Heads=heads,AttackBase=basis,AttackCoinPower=power,AttackCarry=carry,AttackAccumulated=attackCoinTotal,RawModifier=modifier,AttackIndex=attacks,AttackBudget=attackBudget,RemainingAttackCoins=remaining,RawDamage=raw,TotalRawDamage=totalRaw,Left=Snapshot(),Effects=DrainEffects()};
        }
        // Called by the damage adapter only when a live target was actually hit.
        public void NotifyHit(bool heads){if(phase!="attack"||attacks==0||notifiedAttack==attacks)throw new InvalidOperationException("No unreported attack to notify.");notifiedAttack=attacks;Trigger(CoinTrigger.Hit,heads,true);}
        public void CompleteAttack(){if(phase=="attack"&&remaining==0)Finish();}
        void Finish(){if(ended)return;ended=true;phase="complete";Trigger(CoinTrigger.SkillEnd);}
        public string[] DrainEffects(){var copy=trace.ToArray();trace.Clear();return copy;}
    }
    public sealed class CoinClash
    {
        readonly CoinAction left,right;readonly ICoinRandom random;bool started;public bool Complete {get;private set;}public int Winner {get;private set;}
        public CoinClash(CoinAction leftAction,CoinAction rightAction,ICoinRandom gameRandom)
        {if(leftAction==null||rightAction==null||leftAction==rightAction||gameRandom==null||leftAction.Phase!="new"||rightAction.Phase!="new"||leftAction.RemainingCoins==0||rightAction.RemainingCoins==0)throw new ArgumentException("Two unused attacking skills and game RNG are required.");left=leftAction;right=rightAction;random=gameRandom;Winner=-1;}
        // One complete reroll per call. No tie limit, decider, repair or counter injection.
        public CoinStep Step()
        {
            if(Complete)return null;if(!started){left.StartClash();right.StartClash();started=true;}
            left.BeforeRound();right.BeforeRound();int lb,lp,lv,rb,rp,rv;
            var facesL=left.RollClash(random,out lb,out lp,out lv);var facesR=right.RollClash(random,out rb,out rp,out rv);int win=lv==rv?-1:lv>rv?0:1;
            int beforeL=left.RemainingCoins,beforeR=right.RemainingCoins;left.RoundResult(win);right.RoundResult(win<0?-1:1-win);
            if(left.RemainingCoins==0||right.RemainingCoins==0){Complete=true;Winner=left.RemainingCoins>0?0:1;left.EndClash(Winner==0,Winner);right.EndClash(Winner==1,Winner);}
            return new CoinStep{Type="clash",Round=left.ClashRound,LeftFaces=facesL,RightFaces=facesR,LeftBase=lb,RightBase=rb,LeftClashPower=lp,RightClashPower=rp,LeftPower=lv,RightPower=rv,LeftBefore=beforeL,RightBefore=beforeR,LeftRemaining=left.RemainingCoins,RightRemaining=right.RemainingCoins,Winner=win,FinalWinner=Complete?Winner:-1,Left=left.Snapshot(),Right=right.Snapshot(),Effects=left.DrainEffects().Concat(right.DrainEffects()).ToArray()};
        }
    }
}
