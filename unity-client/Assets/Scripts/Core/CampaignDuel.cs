using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public enum TrialDuelStage { Deck, Plan, Reveal, Finished }

    public sealed class TrialDuelSide
    {
        public readonly Unit[] Units;
        public readonly HashSet<string>[] Equipped;
        public int Cost,Preparation;
        public readonly BattleModifier Modifier;
        public TrialDuelSide(Unit[] units,int cost,BattleModifier modifier=null)
        {
            Units=units.Select(u=>u.Copy()).Concat(units.Any(u=>u.Patchouli!=null)?new[]{PatchouliSkills.SummonSlot()}:new Unit[0]).ToArray();Modifier=modifier??new BattleModifier();Cost=cost+Modifier.CostBonus;
            Equipped=Units.Select(u=>new HashSet<string>()).ToArray();
        }
    }

    public sealed class TrialDuelAction
    {
        public readonly int Actor,Target;
        public readonly string Key;
        internal readonly int Order;
        internal bool Enhanced;

        internal TrialDuelAction(int actor,string key,int target,int order)
        {
            Actor=actor;
            Key=key;
            Target=target;
            Order=order;
        }
    }

    public sealed class TrialDuelBeat
    {
        public readonly string Kind,Message;
        public readonly int Seat,Actor,Target;
        public readonly CoinStep Coin;
        public readonly PortHit[] Hits;
        public readonly Unit[][] Units;

        public TrialDuelBeat(string kind,string message,int seat,int actor,int target,CoinStep coin,PortHit[] hits,Unit[][] units)
        {Kind=kind;Message=message;Seat=seat;Actor=actor;Target=target;Coin=coin;Hits=hits;Units=units;}
    }

    public sealed partial class CampaignDuel
    {
        static readonly string[] Shared=PortContent.Hand.Where(k=>PortContent.Card(k).Owner<0).ToArray();
        static readonly string[] PatchouliChallengeDeck=PatchouliSkills.Deck.Concat(new[]{"guard"}).ToArray();
        public readonly TrialDuelSide[] Sides;
        public readonly double[] ChoiceLeft=new double[2];
        public readonly List<string> Log=new List<string>();
        public readonly List<string> AutoLog=new List<string>();
        public int MusicCues {get;private set;}
        public readonly bool Recruitment;
        public TrialDuelStage Stage {get;private set;}
        public int Round {get;private set;}
        public int Winner {get;private set;}
        public int Floor {get;private set;}
        // Each character normally owns one slot. Sakuya has two additional slots during time stop.
        readonly TrialDuelAction[][] plans;
        readonly bool[] ready=new bool[2];
        readonly List<TrialDuelBeat> beats=new List<TrialDuelBeat>();
        public IReadOnlyList<TrialDuelBeat> Beats {get{return beats;}}
        public Unit[][] RoundOpening {get;private set;}
        int nextOrder;
        bool opponentIsLocal;
        readonly int[][] speed=new int[2][];
        readonly bool[] repaid=new bool[2];
        readonly BattleRandom random,opponentDeckRandom;
        readonly int planSeconds,recruitSlots;

        public CampaignDuel(TrialDuelSide left,TrialDuelSide right,uint seed,int seconds,bool recruitment,int floor)
        {
            if(seconds!=20&&seconds!=30)throw new ArgumentOutOfRangeException("seconds");
            Sides=new[]{left,right};
            plans=Sides.Select(side=>new TrialDuelAction[side.Units.Length+TouhouRoles.WorldActionSlots-1]).ToArray();
            random=new BattleRandom(seed);
            opponentDeckRandom=new BattleRandom(seed^0x8A381B65u);
            planSeconds=seconds;
            Recruitment=recruitment;
            Floor=floor;
            Winner=-1;
            Round=1;
            Stage=TrialDuelStage.Deck;
            ResetClocks(10);
            if(recruitment)
            {
                recruitSlots=Math.Min(CharacterRoster.Capacity,left.Units.Count(u=>u.MaxHp>0&&!PatchouliSkills.IsSummon(u)));
                right.Equipped[0].UnionWith(Exclusive(1,0));
            }
        }

        public static string[] SupportedExclusive(string id){return CharacterRoster.Skills(id);}
        public string[] Exclusive(int seat,int actor)
        {
            string id=Sides[seat].Units[actor].CharacterId;
            if(Recruitment&&seat==1&&id==PatchouliSkills.Id)return PatchouliChallengeDeck;
            return SupportedExclusive(id);
        }

        public IEnumerable<string> Cards(int seat,int actor)
        {
            var side=Sides[seat];var unit=side.Units[actor];var equipped=side.Equipped[actor];
            var prepared=Exclusive(seat,actor).Where(equipped.Contains).Select(key=>
                key==FlandreSkills.Charge&&unit.Flandre.ChargeTurn>0?FlandreSkills.Release:PatchouliSkills.EquippedKey(unit,key));
            return Recruitment&&seat==1?prepared:Shared.Concat(prepared);
        }

        public IEnumerable<string> VisibleSkillCatalog(int seat,int actor)
        {
            var unit=Sides[seat].Units[actor];
            if(PatchouliSkills.IsSummon(unit))return Enumerable.Range(1,5).Select(i=>PatchouliSkills.Variant((ElementStone)i,ElementStone.None));
            return Recruitment&&seat==1?Cards(seat,actor):SupportedExclusive(unit.CharacterId).Concat(Shared);
        }

        public int Slots(int seat,int actor)
        {
            if(Recruitment&&seat==1&&actor==0)return recruitSlots;
            return actor>=0&&WorldActor(seat)==actor?TouhouRoles.WorldActionSlots:1;
        }
        int SlotIndex(int seat,int actor,int slot){return slot==0?actor:Sides[seat].Units.Length+slot-1;}
        public TrialDuelAction Planned(int seat,int actor,int slot=0){return plans[seat][SlotIndex(seat,actor,slot)];}
        public int PlannedCount(int seat){return plans[seat].Count(a=>a!=null);}
        public int Speed(int seat,int actor){return speed[seat]==null?0:speed[seat][actor];}
        public bool IsReady(int seat){return seat>=0&&seat<2&&ready[seat];}
        public bool CanEdit(int seat)
        {return seat>=0&&seat<2&&!ready[seat]&&(!Recruitment||seat==0);}
        public string WaitingText(int seat)
        {return !Recruitment&&IsReady(seat)&&!IsReady(1-seat)?"对方出招中":"";}

        public bool Toggle(int actor,string key){return Toggle(0,actor,key);}
        public bool Toggle(int seat,int actor,string key)
        {
            if(Stage!=TrialDuelStage.Deck||!CanEdit(seat)||actor<0||actor>=Sides[seat].Units.Length||
                !FlandreSkills.MemberCanAct(Sides[seat].Units[actor])||!Exclusive(seat,actor).Contains(key))return false;
            var equipped=Sides[seat].Equipped[actor];
            if(equipped.Remove(key))return true;
            if(equipped.Count>=4)return false;
            return equipped.Add(key);
        }

        public bool CanPlan(int seat,int actor,string key,int target,int slot=0)
        {
            if(Stage!=TrialDuelStage.Plan||seat<0||seat>=Sides.Length||IsReady(seat)||
                actor<0||actor>=Sides[seat].Units.Length||
                slot<0||slot>=Slots(seat,actor)||Frozen(seat,actor)||
                !FlandreSkills.MemberCanAct(Sides[seat].Units[actor])||!Cards(seat,actor).Contains(key))return false;
            var card=PortContent.Card(key);
            var unit=Sides[seat].Units[actor];
            if(key=="the_world"&&unit.RoleState.WorldUsed||key=="fantasy_nature"&&unit.RoleState.DreamDue>0)return false;
            if(card.RequiresClash&&target<0)return false;
            if(Recruitment&&seat==1&&!CanRepeatRecruitAction(card,SlotIndex(seat,actor,slot)))return false;
            if(PatchouliSkills.IsSummon(unit)||PatchouliSkills.Limit(unit,key,Sides[seat].Units.Any(u=>PatchouliSkills.IsSummon(u)&&u.Hp>0))!="")return false;
            bool validTarget=!card.TargetsEnemy||target>=0&&target<Sides[1-seat].Units.Length&&Sides[1-seat].Units[target].Hp>0||
                target<=-2&&target>=-1-Sides[seat].Units.Length&&Sides[seat].Units[-target-2].Puppet;
            return validTarget&&FlandreSkills.Limit(unit,card,Round)==""&&
                CanAfford(seat,actor,key,SlotIndex(seat,actor,slot));
        }

        public bool Plan(int actor,string key,int target){return Plan(0,actor,key,target);}
        public bool Plan(int seat,int actor,string key,int target,int slot=0)
        {return CanEdit(seat)&&TryPlan(seat,actor,key,target,slot);}

        bool TryPlan(int seat,int actor,string key,int target,int slot=0)
        {
            if(!CanPlan(seat,actor,key,target,slot))return false;
            var card=PortContent.Card(key);
            plans[seat][SlotIndex(seat,actor,slot)]=new TrialDuelAction(actor,key,card.TargetsEnemy?target:-1,nextOrder++);
            return true;
        }

        public bool RemovePlan(int actor){return RemovePlan(0,actor);}
        public bool RemovePlan(int seat,int actor,int slot=0)
        {
            if(Stage!=TrialDuelStage.Plan||!CanEdit(seat)||actor<0||actor>=Sides[seat].Units.Length||slot<0||slot>=Slots(seat,actor)||Planned(seat,actor,slot)==null)return false;
            plans[seat][SlotIndex(seat,actor,slot)]=null;
            return true;
        }

        public void Tick(double delta)
        {
            if(Recruitment||double.IsNaN(delta)||delta<=0||Stage!=TrialDuelStage.Deck&&Stage!=TrialDuelStage.Plan)return;
            var startingStage=Stage;
            for(int seat=0;seat<2&&Stage==startingStage;seat++)
            {
                if(IsReady(seat))continue;
                ChoiceLeft[seat]=Math.Max(0,ChoiceLeft[seat]-delta);
                if(ChoiceLeft[seat]==0)SetReady(seat,true);
            }
        }

        public void Confirm(){SetReady(0);}
        public bool SetReady(int seat,bool timeout=false)
        {
            if(!CanEdit(seat)||Stage!=TrialDuelStage.Deck&&Stage!=TrialDuelStage.Plan)return false;
            if(Stage==TrialDuelStage.Plan&&timeout)AutoPlan(seat);
            ready[seat]=true;
            if(!Recruitment&&!ready[1-seat])return true;
            if(Stage==TrialDuelStage.Deck)StartRound();
            else
            {
                if(Recruitment)AutoPlanRecruit();
                Resolve();
            }
            return true;
        }

        public void NextRound()
        {
            if(Stage!=TrialDuelStage.Reveal)return;
            Round++;
            foreach(var side in Sides)side.Cost+=8;
            StartRound();
        }

        public bool Forfeit(int seat)
        {
            if(Recruitment||seat<0||seat>=Sides.Length||Stage==TrialDuelStage.Finished)return false;
            Winner=1-seat;
            Stage=TrialDuelStage.Finished;
            return true;
        }

        void ResetClocks(int seconds){ChoiceLeft[0]=seconds;ChoiceLeft[1]=seconds;}

        void StartRound()
        {
            Stage=TrialDuelStage.Plan;
            Array.Clear(ready,0,ready.Length);
            beats.Clear();
            RoundOpening=null;
            nextOrder=0;
            ResetClocks(planSeconds);
            for(int seat=0;seat<2;seat++)
            {
                Array.Clear(plans[seat],0,plans[seat].Length);repaid[seat]=false;
                foreach(var u in Sides[seat].Units)
                {
                    u.Shield=0;u.ExorcismActive=u.ExorcismPending;u.ExorcismPending=false;
                    PrepareUniqueStatus(u);
                    RemiliaSkills.BeginRound(u,Sides[1-seat].Units,random);
                    PatchouliSkills.StartRound(u);
                    if(PatchouliSkills.Has(u,ElementStone.Water))PatchouliSkills.Heal(u,5);
                    if(u.Remilia!=null&&u.Remilia.LockedTarget>=0)
                        Log.Add(u.Name+" · 昆古尼尔锁定 "+Sides[1-seat].Units[u.Remilia.LockedTarget].Name);
                }
                speed[seat]=Sides[seat].Units.Select(u=>UniqueSpeed(seat,u,u.MinSpeed+random.Range(Math.Max(1,u.MaxSpeed-u.MinSpeed+1)))).ToArray();
            }
        }


        bool CanRepeatRecruitAction(PortCard card,int skipSlot)
        {
            return !plans[1].Where((plan,index)=>index!=skipSlot&&plan!=null).Any(plan=>
                card.Id==plan.Key&&(card.Id=="the_world"||card.Id==PatchouliSkills.Sage||
                    card.Id==FlandreSkills.Charge||card.Id==FlandreSkills.Release||card.Id==FlandreSkills.Nobody)||
                card.Id==FlandreSkills.Charge&&PortContent.Card(plan.Key).TargetsEnemy||
                plan.Key==FlandreSkills.Charge&&card.TargetsEnemy);
        }

        void AutoPlanRecruit()
        {
            const int seat=1,actor=0;
            if(!PatchouliSkills.LivingFighter(Sides[seat].Units[actor])||Frozen(seat,actor))return;
            int budget=Sides[seat].Cost;
            var options=Cards(seat,actor).Select(PortContent.Card).SelectMany(card=>
                (card.TargetsEnemy?Enumerable.Range(0,Sides[0].Units.Length):new[]{-1})
                .Select(target=>new { Card=card,Target=target })).ToArray();

            for(int slot=0;slot<recruitSlots;slot++)
            {
                var legal=options.Where(option=>CanPlan(seat,actor,option.Card.Id,option.Target,slot)).ToArray();
                if(legal.Length==0)break;
                int minimum=legal.Min(option=>option.Card.Cost);
                // Reserve enough for the remaining slots when the cheapest action can be repeated.
                int allowance=Math.Max(minimum,budget-minimum*(recruitSlots-slot-1));
                var choice=legal.Where(option=>option.Card.Cost<=allowance).OrderByDescending(option=>
                    Score(seat,actor,option.Card,option.Target)-
                    (option.Target<0?0:2*plans[seat].Count(plan=>plan!=null&&plan.Target==option.Target))).First();
                if(!TryPlan(seat,actor,choice.Card.Id,choice.Target,slot))break;
                budget-=choice.Card.Cost;
                AutoLog.Add(Sides[seat].Units[actor].Name+" · 行动 "+(slot+1)+" · "+choice.Card.Name);
            }
        }

        void AutoPlan(int seat)
        {
            for(int actor=0;actor<Sides[seat].Units.Length;actor++)
            {
                var own=Sides[seat].Units[actor];
                if(!PatchouliSkills.LivingFighter(own)||Frozen(seat,actor))continue;
                for(int slot=0;slot<Slots(seat,actor);slot++)
                {
                if(Planned(seat,actor,slot)!=null)continue;
                double best=double.NegativeInfinity;
                string winner=null;
                int target=-1;
                foreach(string key in Cards(seat,actor))
                {
                    var card=PortContent.Card(key);
                    for(int foe=card.TargetsEnemy?0:-1;foe<(card.TargetsEnemy?Sides[1-seat].Units.Length:0);foe++)
                    {
                        if(!CanPlan(seat,actor,key,foe,slot))continue;
                        double score=Score(seat,actor,card,foe);
                        if(score>best){best=score;winner=key;target=foe;}
                    }
                }
                if(winner!=null&&TryPlan(seat,actor,winner,target,slot))
                {
                    if(seat==1&&own.Zixi!=null)ToggleEnhancement(seat,actor,slot);
                    if(seat==0||!opponentIsLocal)
                        AutoLog.Add("玩家"+(seat+1)+" "+own.Name+"：自动安排 "+PortContent.Card(winner).Name);
                }
                }
            }
        }

        double Score(int seat,int actor,PortCard card,int target)
        {
            var own=Sides[seat].Units[actor];
            double liquidity=Sides[seat].Cost<=4?1.8:0.7;
            if(target<0)
            {
                if(card.Id==FlandreSkills.Release)return 18+own.Hp*.5;
                if(card.Id==FlandreSkills.Charge)return own.Hp>=15?13-card.Cost*liquidity:0;
                if(card.Id==FlandreSkills.Nobody)return own.Hp<10?9-card.Cost*liquidity:0;
                return (own.Hp<=12?11:2)-card.Cost*liquidity;
            }
            var foe=Sides[1-seat].Units[target];
            double clash=card.Base+.65*card.ClashCoinPower*card.Coins+RemiliaSkills.ClashBonus(own,card.Id);
            double damage=card.Id=="marisa_meteor"?10:(card.CoinData.SplitAttackPower?
                card.Base+.65*card.AttackCoinPower*card.Coins:
                card.Base*card.Coins+.65*card.AttackCoinPower*card.Coins*(card.Coins+1)/2);
            if(card.Id=="murder_doll")damage+=TouhouRoles.SilverKnife(Round);
            if(own.Remilia!=null)
            {
                if(card.Id==RemiliaSkills.Fantasy)damage+=own.Remilia.Scarlet/2;
                damage=Math.Max(0,damage-10*own.Remilia.Overheat);
                if(RemiliaSkills.IsLocked(own,target))damage*=1.5;
                if(card.Id==RemiliaSkills.Curse)damage=(own.Remilia.CurseUntil<Round?8:2);
            }
            if(card.NoDamage)damage=card.Id=="the_world"?30:card.Id=="danmaku_barrier"?16:card.Id=="fantasy_nature"?12:card.Id=="zixi_martingale"?8:4;
            if(!Recruitment&&card.Id=="marisa_spark")damage=10*own.RoleState.Spark;
            if(!Recruitment&&card.Id=="marisa_blazing_star")damage*=own.RoleState.Spark;
            if(own.Zixi!=null&&ZixiRole.Keys.Contains(card.Id))clash+=ZixiRole.ClashBase(card.Id)-card.Base+own.Zixi.Causality;
            double marks=card.Id=="fantasy_seal"&&foe.Exorcism>=2?3:card.Id=="yin_yang_orb"&&foe.Exorcism>=3?3:0;
            return clash*.33+damage*.52+(damage>=foe.Hp?5:0)+marks+(card.Id=="marisa_meteor"?2:0)+
                (Speed(seat,actor)>=Speed(1-seat,target)?1:0)-card.Cost*liquidity;
        }

        sealed class QueueItem
        {
            public TrialDuelAction A,B;
            public int Side,Speed,Sage=-1;
        }

        Unit[][] CopyUnits(){return Sides.Select(side=>side.Units.Select(u=>u.Copy()).ToArray()).ToArray();}

        void RecordBeat(string kind,string message,int seat,int actor,int target=-1,CoinStep coin=null,PortHit[] hits=null)
        {
            Log.Add(message);
            beats.Add(new TrialDuelBeat(kind,message,seat,actor,target,coin,hits,CopyUnits()));
        }

        bool ClashAttack(int seat,TrialDuelAction action)
        {
            if(action.Target<0||!FlandreSkills.MemberCanAct(Sides[seat].Units[action.Actor]))return false;
            var card=PortContent.Card(action.Key);
            return card.TargetsEnemy&&card.AllowsClash;
        }

        bool CanIntercept(int seat,TrialDuelAction attacker,TrialDuelAction opponent)
        {
            return opponent.Target==attacker.Actor||Speed(seat,attacker.Actor)>=Speed(1-seat,opponent.Actor)||
                Sides[seat].Units[attacker.Actor].CharacterId=="sakuya"||PatchouliSkills.Off(attacker.Key)==ElementStone.Wood;
        }

        List<QueueItem> BuildActionQueue(TrialDuelAction[][] locked)
        {
            var candidates=new List<QueueItem>();
            var contested=new HashSet<QueueItem>();
            var mutual=new HashSet<QueueItem>();
            for(int defending=0;defending<2;defending++)
            {
                int attacking=1-defending;
                foreach(var opponent in locked[defending].Where(a=>ClashAttack(defending,a)))
                {
                    var challengers=locked[attacking].Where(a=>a.Target==opponent.Actor&&ClashAttack(attacking,a)).ToArray();
                    var latest=challengers.LastOrDefault(a=>CanIntercept(attacking,a,opponent));
                    if(latest==null)continue;
                    var left=defending==0?opponent:latest;
                    var right=defending==1?opponent:latest;
                    var candidate=new QueueItem{A=left,B=right,Side=0,Speed=Math.Max(Speed(0,left.Actor),Speed(1,right.Actor))};
                    candidates.Add(candidate);
                    if(challengers.Length>1)contested.Add(candidate);
                    if(opponent.Target==latest.Actor)mutual.Add(candidate);
                }
            }

            var queue=new List<QueueItem>();
            var paired=new HashSet<TrialDuelAction>();
            // Honor contested targets before a reciprocal pairing that would take the same action.
            foreach(var candidate in candidates.OrderByDescending(contested.Contains).ThenByDescending(mutual.Contains).ThenByDescending(item=>item.Speed))
            {
                if(paired.Contains(candidate.A)||paired.Contains(candidate.B))continue;
                paired.Add(candidate.A);
                paired.Add(candidate.B);
                queue.Add(candidate);
            }
            if(Recruitment)PairRemainingRecruitClashes(locked,queue,paired);
            for(int seat=0;seat<2;seat++)
                foreach(var action in locked[seat].Where(a=>!paired.Contains(a)))
                    queue.Add(new QueueItem{A=action,Side=seat,Speed=Speed(seat,action.Actor)});
            return queue;
        }


        void PairRemainingRecruitClashes(TrialDuelAction[][] locked,List<QueueItem> queue,HashSet<TrialDuelAction> paired)
        {
            // Different cards from the same recruit are different actions. Try other eligible cards
            // if the normal priority pass already used the originally selected one.
            foreach(var right in locked[1].Where(action=>!paired.Contains(action)&&ClashAttack(1,action)))
            {
                var left=locked[0].LastOrDefault(action=>!paired.Contains(action)&&ClashAttack(0,action)&&
                    (action.Target==right.Actor&&CanIntercept(0,action,right)||
                     right.Target==action.Actor&&CanIntercept(1,right,action)));
                if(left==null)continue;
                paired.Add(left);paired.Add(right);
                queue.Add(new QueueItem{A=left,B=right,Side=0,Speed=Math.Max(Speed(0,left.Actor),Speed(1,right.Actor))});
            }
        }

        void Resolve()
        {
            RoundOpening=CopyUnits();
            AutoLog.ForEach(Log.Add);AutoLog.Clear();
            var locked=plans.Select(side=>side.Where(action=>action!=null).OrderBy(action=>action.Order).ToArray()).ToArray();
            PayLockedPlans(locked);
            var queue=BuildActionQueue(locked);
            for(int seat=0;seat<Sides.Length;seat++)
            {
                int sage=Array.FindIndex(Sides[seat].Units,u=>PatchouliSkills.SageCanAct(u,Round));
                if(sage>=0&&!TimeStopped)queue.Add(new QueueItem{Side=seat,Sage=sage,Speed=Speed(seat,sage)});
            }
            foreach(var item in queue.OrderByDescending(q=>q.Speed).ThenBy(q=>q.Side==Round%2?0:1).ThenBy(q=>q.A==null?int.MaxValue:q.A.Order))
            {
                if(item.Sage>=0)
                {
                    PlaySage(item.Side,item.Sage);
                    if(Sides.Any(side=>!side.Units.Any(PatchouliSkills.LivingFighter)))break;
                    continue;
                }
                var actor=Sides[item.Side].Units[item.A.Actor];
                var other=item.B==null?null:Sides[1].Units[item.B.Actor];
                bool first=FlandreSkills.MemberCanAct(actor)&&AllowUniqueAction(item.Side,item.A.Actor);
                bool second=other!=null&&FlandreSkills.MemberCanAct(other)&&AllowUniqueAction(1,item.B.Actor);
                bool firstLast=first&&actor.Flandre!=null&&actor.Flandre.LastAct;
                bool secondLast=second&&other.Flandre!=null&&other.Flandre.LastAct;
                if(first&&second)Clash(item.A,item.B);
                else if(first)Perform(item.Side,item.A,null);
                else if(second)Perform(1,item.B,null);
                FlandreSkills.EndAction(actor,firstLast,Report);
                if(other!=null)FlandreSkills.EndAction(other,secondLast,Report);
                if(Sides.Any(side=>!side.Units.Any(PatchouliSkills.LivingFighter)))break;
            }
            foreach(var side in Sides)foreach(var unit in side.Units)
            {
                if(unit.PatchouliBurn>0&&unit.Hp>0)
                {
                    int lost=Damage(unit,null,unit.PatchouliBurn,ignoreShield:true);
                    Log.Add(unit.Name+" · 燃烧 −"+lost+" HP");
                }
                FlandreSkills.EndRound(unit,Report);
                if(RemiliaSkills.EndRound(unit))Log.Add(unit.Name+" · 昆古尼尔冷却，过热 "+unit.Remilia.Overheat);
            }
            ResolveUniqueRoundEnd();
            if(!Sides[0].Units.Any(PatchouliSkills.LivingFighter))Winner=1;
            else if(!Sides[1].Units.Any(PatchouliSkills.LivingFighter))Winner=0;
            Stage=Winner<0?TrialDuelStage.Reveal:TrialDuelStage.Finished;
        }

        CoinAction Action(int seat,TrialDuelAction plan,int opponent=-1,ZixiContext zixi=null)
        {
            var unit=Sides[seat].Units[plan.Actor];
            var card=PortContent.Card(plan.Key);
            var effects=new List<CoinEffect>();
            int modifier=(unit.ExorcismActive?-3:0)+Sides[seat].Modifier.ClashBonus+UniqueClashBonus(seat,plan,opponent,zixi);
            if(unit.Flandre!=null)modifier+=unit.Flandre.PuppetPower;
            modifier+=RemiliaSkills.ClashBonus(unit,card.Id);
            if(PatchouliSkills.Has(unit,ElementStone.Metal))modifier+=2;
            if(modifier!=0)effects.Add(new CoinEffect("回合拼点状态",CoinTrigger.ClashStart,CoinStat.BasePower,modifier,CoinEffectScope.Clash));
            var action=new CoinAction(card.CoinData,.65,additionalEffects:effects);
            if(unit.CharacterId=="sakuya")action.AttackAdjustment=i=>i==1?TouhouRoles.SilverKnife(Round)+(unit.RoleState.SpaceActive?5:0):0;
            SetZixiTransforms(action,zixi);
            return action;
        }

        void Clash(TrialDuelAction a,TrialDuelAction b)
        {
            Log.Add("拼点："+Sides[0].Units[a.Actor].Name+" ↔ "+Sides[1].Units[b.Actor].Name);
            var zixiLeft=NewZixiContext(0,a);var zixiRight=NewZixiContext(1,b);
            var left=Action(0,a,b.Actor,zixiLeft);var right=Action(1,b,a.Actor,zixiRight);
            var clash=new CoinClash(left,right,new CoinRandomSource(random.Flip));
            CoinStep last=null;
            while(!clash.Complete)
            {
                last=clash.Step();
                RecordBeat("clash",CoinLog.Clash(last),0,a.Actor,b.Actor,last);
            }
            int seat=clash.Winner;
            Log.Add("玩家"+(seat+1)+" 赢得拼点");
            if(!repaid[seat]){Sides[seat].Cost++;repaid[seat]=true;}
            FinishUniqueClash(0,a,zixiLeft,seat==0,last.LeftPower-last.RightPower);
            FinishUniqueClash(1,b,zixiRight,seat==1,last.RightPower-last.LeftPower);
            var winner=seat==0?a:b;
            int target=seat==0?b.Actor:a.Actor;
            Perform(seat,new TrialDuelAction(winner.Actor,winner.Key,target,winner.Order),seat==0?left:right,
                zixi:seat==0?zixiLeft:zixiRight);
            if(seat!=0)DrawStone(0,a);
            if(seat!=1)DrawStone(1,b);
            ReportRemiliaClash(Sides[0].Units[a.Actor],b.Actor);
            ReportRemiliaClash(Sides[1].Units[b.Actor],a.Actor);
        }

        void DrawStone(int seat,TrialDuelAction plan)
        {
            var actor=Sides[seat].Units[plan.Actor];
            if(plan.Key==PatchouliSkills.Draw&&actor.Patchouli!=null)Log.Add(PatchouliSkills.DrawStone(actor,random));
        }

        void PlaySage(int seat,int index)
        {
            if(!PatchouliSkills.SageCanAct(Sides[seat].Units[index],Round))return;
            var enemies=Sides[1-seat].Units;
            var targets=Enumerable.Range(0,enemies.Length).Where(i=>enemies[i].Hp>0).ToArray();
            if(targets.Length==0)return;
            int target=targets[random.Range(targets.Length)];
            string key=PatchouliSkills.Variant((ElementStone)(random.Range(5)+1),ElementStone.None);
            Log.Add("贤者之石 · 自动施放 "+PortContent.Card(key).Name);
            Perform(seat,new TrialDuelAction(index,key,target,-1),null);
        }

        void ReportRemiliaClash(Unit actor,int target)
        {
            if(RemiliaSkills.CompleteClash(actor,target))Log.Add(actor.Name+" · 昆古尼尔，过热 "+actor.Remilia.Overheat);
        }

        void TryRemiliaCounter(int attackingSeat,int attacker)
        {
            int seat=1-attackingSeat;
            if(!FlandreSkills.MemberCanAct(Sides[attackingSeat].Units[attacker]))return;
            int actor=Array.FindIndex(Sides[seat].Units,u=>u.Remilia!=null);
            if(actor<0||!RemiliaSkills.SpendCounter(Sides[seat].Units[actor],Round))return;
            Log.Add(Sides[seat].Units[actor].Name+" · 诅咒反击 · 大卫之星");
            Perform(seat,new TrialDuelAction(actor,RemiliaSkills.Star,attacker,-1),null,true);
        }

        void Perform(int seat,TrialDuelAction plan,CoinAction action,bool counter=false,ZixiContext zixi=null)
        {
            var card=PortContent.Card(plan.Key);
            var own=Sides[seat].Units[plan.Actor];
            var enemies=Sides[1-seat].Units;
            if(FlandreSkills.Limit(own,card,Round)!="")return;
            if(card.RequiresClash&&action==null)
            {RecordBeat("ability",card.Name+" · 未形成拼点，行动取消",seat,plan.Actor);return;}
            if(PerformUnique(seat,plan,card,action,zixi))return;
            if((own.Patchouli!=null||PatchouliSkills.IsSummon(own))&&PatchouliSkills.Utility(own,card.Id,Round,
                Sides[seat].Units.FirstOrDefault(PatchouliSkills.IsSummon),Sides[seat].Units,enemies,message=>RecordBeat("ability",message,seat,plan.Actor)))return;
            if(RemiliaSkills.CastCurse(own,card.Id,Round))
            {
                RecordBeat("ability",own.Name+" · 弗拉德·采佩什的诅咒：敌方全体受诅咒，持续至下回合末。",seat,plan.Actor);
                return;
            }
            if(FlandreSkills.UseSupport(own,card.Id,Round,power=>
            {
                var hits=enemies.Where(target=>target.Hp>0).Select(target=>DamageText(target,Damage(target,own,power))).ToArray();
                if(hits.Length>0)
                {
                    RecordBeat("ability",own.Name+" · "+card.Name+" → "+string.Join("、",hits),seat,plan.Actor);
                    TryRemiliaCounter(seat,plan.Actor);
                }
            },Report))return;
            if(!card.TargetsEnemy)
            {own.Shield+=9;SupportGuard(seat,plan.Actor,card.Id);RecordBeat("ability",own.Name+" · "+card.Name+"获得9护盾",seat,plan.Actor);return;}
            bool ownPuppet=plan.Target<=-2;
            if(!ownPuppet&&enemies[plan.Target].Hp<=0&&!FlandreSkills.HitsAllEnemies(card.Id))return;
            var strike=own.Remilia!=null&&!ownPuppet?new RemiliaStrike(own,card.Id,plan.Target,enemies,action!=null):null;
            var elemental=!ownPuppet&&(own.Patchouli!=null||PatchouliSkills.IsSummon(own))?
                new PatchouliStrike(own,card.Id,plan.Target,enemies):null;
            if(action==null)action=Action(seat,plan,-1);
            bool attacked=false;
            if(card.Id=="marisa_meteor")Sides[seat].Cost+=2;
            int marks=card.Id=="fantasy_seal"?2:card.Id=="yin_yang_orb"?1:0;
            var rng=new CoinRandomSource(random.Flip);
            for(CoinStep step;own.Hp>0&&(step=action.NextAttack(rng))!=null;)
            {
                if(ownPuppet)
                {
                    Damage(Sides[seat].Units[-plan.Target-2],null,Math.Max(1,step.RawDamage));
                    continue;
                }
                int raw=card.Id=="marisa_meteor"?(step.AttackIndex==1?10:0):Math.Max(0,step.RawDamage);
                if(card.Id==FlandreSkills.Ripple)raw=FlandreSkills.RipplePower(own,Report);
                if(own.ExorcismActive)raw/=2;
                var hits=new List<string>();
                var beatHits=new List<PortHit>();
                if(elemental!=null)raw=elemental.Raw(step);
                var targets=elemental!=null?elemental.Targets:strike!=null?strike.Targets:FlandreSkills.Targets(card.Id,plan.Target,enemies);
                foreach(int index in targets)
                {
                    var target=enemies[index];
                    if(target.Hp<=0)continue;
                    int bonus=card.Id=="marisa_meteor"?0:Sides[seat].Modifier.DamageBonus;
                    int before=target.Hp;
                    int strikeRaw=strike==null?raw:strike.Raw(index,step)/(own.ExorcismActive?2:1);
                    int damage=Damage(target,own,strikeRaw,bonus,elemental!=null&&elemental.IgnoresShield);
                    if(elemental!=null)elemental.OnHit(target);
                    if(strike!=null)strike.RecordHit(index,before-target.Hp);
                    if(card.Id==FlandreSkills.Clock&&FlandreSkills.MemberCanAct(target))target.FlandreDamageDownTurn=Round+1;
                    if(marks>0&&FlandreSkills.MemberCanAct(target))
                    {
                        marks--;AddExorcism(seat,index,plan.Actor);
                    }
                    hits.Add(DamageText(target,damage));
                    beatHits.Add(new PortHit(seat==1,index,strikeRaw,Math.Max(0,before-target.Hp)));
                }
                if(card.Id==FlandreSkills.Ripple)
                    foreach(var ally in Sides[seat].Units.Where(u=>u!=own&&u.Hp>0))
                        hits.Add(DamageText(ally,Damage(ally,null,raw)));
                if(hits.Count>0)
                {
                    attacked=true;
                    RecordBeat("strike",own.Name+" · "+card.Name+" "+(step.Heads?"正":"反")+" → "+string.Join("、",hits),
                        seat,plan.Actor,plan.Target,step,beatHits.ToArray());
                }
                action.NotifyHit(step.Heads);
                if(elemental!=null&&PatchouliSkills.Asthma(own)>0)Log.Add(own.Name+" · 姆Q −2 HP");
            }
            action.CompleteAttack();
            if(strike!=null)Log.Add(strike.Finish(enemies));
            DrawStone(seat,plan);
            if(card.Id=="observe")PrepareAsh(seat,plan.Actor);
            if(attacked&&!counter&&!card.NoDamage)TryRemiliaCounter(seat,plan.Actor);
        }
        static string DamageText(Unit target,int damage){return target.Name+" −"+damage+"HP";}
        int Damage(Unit target,Unit source,int amount,int bonus=0,bool ignoreShield=false)
        {
            if(source!=null&&target.CharacterId=="sakuya"&&target.RoleState.DodgeTurn==Round&&amount>0&&amount<=target.RoleState.DodgePower)
            {
                Log.Add(target.Name+" · 误导闪避");
                if(target.RoleState.DodgePower==15)Damage(source,null,5);
                return 0;
            }
            if(source!=null&&target.CharacterId=="marisa"&&target.RoleState.OrreryUntil>=Round)amount=Math.Max(0,amount-5);
            if(source!=null&&PatchouliSkills.Evades(target,amount))
            {Log.Add(target.Name+" · 知识和避世的少女：闪避");return 0;}
            int blocked=ignoreShield?0:Math.Min(amount,target.Shield);
            ConsumeZixiShield(target,blocked);
            target.Shield-=blocked;
            int damage=Math.Max(0,amount-blocked+bonus-(source!=null&&source.FlandreDamageDownTurn==Round?2:0)-(source==null?0:2*source.RedMist));
            damage=PatchouliSkills.AdjustDamage(source,target,damage);
            if(target.Remilia!=null)
            {
                var side=Sides.First(team=>team.Units.Contains(target));
                int before=target.Hp;
                if(RemiliaSkills.PreventDefeat(target,damage,ref side.Cost))
                {
                    Log.Add(target.Name+" · 最有威严之人：消耗 10 cost，保留 1 HP");
                    return before-1;
                }
            }
            return FlandreSkills.Receive(target,source,damage,Report);
        }
        void Report(string message,bool music){Log.Add(message);if(music)MusicCues++;}
    }
}
