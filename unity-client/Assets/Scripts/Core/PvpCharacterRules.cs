
using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public sealed partial class CampaignDuel
    {
        int WorldActor(int seat)
        {
            return Array.FindIndex(Sides[seat].Units,u=>
                u.CharacterId=="sakuya"&&u.RoleState.WorldRound==Round);
        }

        bool TimeStopped {get{return WorldActor(0)>=0||WorldActor(1)>=0;}}
        bool Frozen(int seat,int actor){return TimeStopped&&WorldActor(seat)!=actor;}

        public bool ToggleEnhancement(int seat,int actor,int slot)
        {
            if(Stage!=TrialDuelStage.Plan||!CanEdit(seat)||actor<0||actor>=Sides[seat].Units.Length||slot<0||slot>=Slots(seat,actor))return false;
            var plan=Planned(seat,actor,slot);
            var z=Sides[seat].Units[actor].Zixi;
            if(plan==null||z==null||!ZixiRole.Keys.Contains(plan.Key))return false;
            if(!plan.Enhanced&&(z.Metaphysics<3||plans[seat].Any(a=>a!=null&&a.Actor==actor&&a.Enhanced)))return false;
            plan.Enhanced=!plan.Enhanced;
            return true;
        }

        public bool IsEnhanced(int seat,int actor,int slot)
        {
            var plan=Planned(seat,actor,slot);
            return plan!=null&&plan.Enhanced;
        }

        int Funding(int seat,IEnumerable<TrialDuelAction> orders)
        {
            return orders.Sum(a=>PortContent.Card(a.Key).Cost+(a.Key=="marisa_blazing_star"&&Sides[seat].Units[a.Actor].Hp<10?3:0));
        }

        int BorrowLimit(int seat,IEnumerable<TrialDuelAction> orders)
        {
            if(Recruitment)return 0;
            var marisa=Sides[seat].Units.FirstOrDefault(u=>u.CharacterId=="marisa"&&u.Hp>0);
            if(marisa==null)return 0;
            var acting=orders.Where(a=>Sides[seat].Units[a.Actor]==marisa).ToArray();
            bool blazing=acting.Any(a=>a.Key=="marisa_blazing_star");
            int hp=blazing?marisa.Hp-10:marisa.Hp-1;
            return Math.Max(0,Math.Min(hp/3,acting.Sum(a=>PortContent.Card(a.Key).Cost)));
        }

        bool CanAfford(int seat,int actor,string key,int skip)
        {
            var orders=plans[seat].Where((a,i)=>a!=null&&i!=skip)
                .Concat(new[]{new TrialDuelAction(actor,key,-1,-1)}).ToArray();
            int potential=BorrowLimit(seat,orders);
            if(Recruitment)potential=Math.Min(Sides[1-seat].Cost,potential);
            return Funding(seat,orders)<=Sides[seat].Cost+potential;
        }

        void PayLockedPlans(TrialDuelAction[][] locked)
        {
            // A hidden rival's reservations cannot be consulted during input. Reconcile theft on reveal.
            bool changed;
            do
            {
                changed=false;
                for(int seat=0;seat<2;seat++)
                {
                    int remaining=Sides[seat].Cost-Funding(seat,locked[seat]);
                    int other=Sides[1-seat].Cost-Funding(1-seat,locked[1-seat]);
                    if(-remaining<=Math.Min(Math.Max(0,other),BorrowLimit(seat,locked[seat])))continue;
                    var remove=locked[seat].Last(a=>Sides[seat].Units[a.Actor].CharacterId=="marisa");
                    locked[seat]=locked[seat].Where(a=>a!=remove).ToArray();
                    Log.Add(Sides[seat].Units[remove.Actor].Name+" · 支付未完成，取消 "+PortContent.Card(remove.Key).Name);
                    changed=true;
                }
            } while(changed);
            var payment=new[]{Funding(0,locked[0]),Funding(1,locked[1])};
            for(int seat=0;seat<2;seat++)
            {
                var team=Sides[seat];
                int borrowed=Math.Max(0,payment[seat]-team.Cost);
                if(borrowed>0)
                {
                    team.Units.First(u=>u.CharacterId=="marisa").Hp-=borrowed*3;
                    Sides[1-seat].Cost-=borrowed;
                    team.Cost+=borrowed;
                    Log.Add("魔理沙 · 消耗 "+(borrowed*3)+" HP，偷取 "+borrowed+" cost");
                }
                team.Cost-=locked[seat].Sum(a=>PortContent.Card(a.Key).Cost);
                foreach(var plan in locked[seat])
                {
                    var actor=team.Units[plan.Actor];
                    if(plan.Key=="the_world")actor.RoleState.WorldUsed=true;
                    if(plan.Enhanced)actor.Zixi.Metaphysics-=3;
                }
            }
        }

        void PrepareUniqueStatus(Unit u)
        {
            if(u.CharacterId=="sakuya")
            {
                var role=u.RoleState;
                role.WatchActive=Round<=role.WatchUntil;
                role.SpaceActive=role.SpacePending;
                role.SpacePending=false;
            }
            u.SealActive=u.SealPending;u.SealPending=false;
            if(u.Zixi==null)return;
            u.Zixi.RoundGain=0;
            foreach(int key in u.Zixi.ShieldUntil.Keys.Where(k=>k<Round).ToArray())u.Zixi.ShieldUntil.Remove(key);
            u.Shield=u.Zixi.ShieldUntil.Values.Sum();
        }

        int BarrierCaster(int seat)
        {
            return Array.FindIndex(Sides[seat].Units,u=>u.CharacterId=="reimu"&&u.Hp>0&&
                u.RoleState.BarrierFrom>0&&u.RoleState.BarrierFrom<=Round&&u.RoleState.BarrierUntil>=Round);
        }

        int UniqueSpeed(int seat,Unit u,int rolled)
        {
            if(BarrierCaster(seat)>=0&&u.CharacterId=="reimu")return 1;
            if(BarrierCaster(1-seat)>=0)rolled--;
            if(Sides[1-seat].Units.Any(x=>x.CharacterId=="sakuya"&&Round<=x.RoleState.WatchUntil))rolled-=3;
            if(u.BindingTurn==Round)rolled--;
            if(u.CharacterId=="sakuya"&&u.RoleState.SpaceActive)rolled+=3;
            return PatchouliSkills.Speed(u,rolled-u.RedMist,Round);
        }

        bool AllowUniqueAction(int seat,int actor)
        {
            if(Frozen(seat,actor))return false;
            int caster=BarrierCaster(1-seat);
            if(caster<0)return true;
            var target=Sides[seat].Units[actor];
            int lost=Damage(target,Sides[1-seat].Units[caster],5);
            AddExorcism(1-seat,actor,caster);
            RecordBeat("ability","博丽弹幕结界 · "+DamageText(target,lost),1-seat,caster,actor);
            return FlandreSkills.MemberCanAct(target);
        }

        void ResolveUniqueRoundEnd()
        {
            for(int seat=0;seat<2;seat++)
            {
                int actor=Array.FindIndex(Sides[seat].Units,unit=>unit.CharacterId=="reimu");
                if(actor<0)continue;
                var u=Sides[seat].Units[actor];
                var r=u.RoleState;
                if(u.Hp>0&&r.DreamDue!=Round)continue;
                if(u.Hp>0&&Sides[1-seat].Units.Any(PatchouliSkills.LivingFighter))
                {
                    GroupStrike(seat,new TrialDuelAction(actor,"fantasy_nature",-1,-1),null,
                        Enumerable.Range(0,Sides[1-seat].Units.Length).Where(i=>Sides[1-seat].Units[i].Exorcism>0),
                        i=>10*r.DreamOrbs*Sides[1-seat].Units[i].Exorcism);
                    u.Hp=0;
                    RecordBeat("ability","梦想天生 · 博丽灵梦退场",seat,actor);
                }
                r.DreamDue=0;r.DreamOrbs=0;
            }
        }

        bool MarisaCompanion(int seat)
        {
            return Sides[seat].Units.Any(u=>u.CharacterId=="reimu"||u.CharacterId=="alice"||u.CharacterId==PatchouliSkills.Id);
        }

        int UniqueClashBonus(int seat,TrialDuelAction plan,int opponent,ZixiContext zixi)
        {
            if(opponent<0)return 0;
            var u=Sides[seat].Units[plan.Actor];
            var foe=Sides[1-seat].Units[opponent];
            int gap=Math.Max(0,Speed(seat,plan.Actor)-Speed(1-seat,opponent));
            int bonus=u.CharacterId=="sakuya"?Math.Min(3,gap):0;
            var card=PortContent.Card(plan.Key);
            if(Sides[seat].Units.Any(x=>x.CharacterId=="sakuya"&&x.RoleState.WatchActive))bonus+=Math.Min(3,gap/2);
            if(u.CharacterId=="reimu"&&(foe.GensokyoNative||foe.RoleState!=null||foe.Flandre!=null||foe.Remilia!=null||foe.Patchouli!=null))bonus++;
            if(u.SealActive)bonus-=2;
            if(u.CharacterId=="marisa")bonus+=(MarisaCompanion(seat)?-2:0)+(u.RoleState.Spark>5&&card.Kind!="guard"?2:0);
            if(u.CharacterId=="breaker"&&card.Cost>=3)bonus+=2;
            if(plan.Key=="exploit"&&Sides[seat].Preparation>0)
            {
                Sides[seat].Preparation=0;bonus+=4;
                Log.Add("灰烬 · 消耗准备，拼点 +4");
            }
            if(zixi!=null)
            {
                bonus+=u.Zixi.Causality+u.Zixi.NextClash.Values.Sum();
                u.Zixi.NextClash.Clear();
                if(ZixiRole.Keys.Contains(plan.Key))bonus+=ZixiRole.ClashBase(plan.Key)-card.Base;
                if(zixi.Enhanced)bonus+=plan.Key=="zixi_central_limit"?2:plan.Key=="zixi_martingale"?3:0;
            }
            return bonus;
        }

        ZixiContext NewZixiContext(int seat,TrialDuelAction plan)
        {
            var z=Sides[seat].Units[plan.Actor].Zixi;
            if(z==null)return null;
            return new ZixiContext{Key=plan.Key,Enhanced=plan.Enhanced,StartCausality=z.Causality,
                TailAvailable=plan.Enhanced&&plan.Key=="zixi_convergence"};
        }

        static void SetZixiTransforms(CoinAction action,ZixiContext ctx)
        {
            if(ctx==null)return;
            action.FaceTransform=(heads,clash)=>
            {
                if(!clash&&heads)ctx.NaturalAttackHeads++;
                if(!heads&&ctx.TailAvailable){ctx.TailAvailable=false;return true;}
                return heads;
            };
            action.AttackAdjustment=index=>
            {
                if(!ctx.Won)return 0;
                if(ctx.Key=="zixi_central_limit"&&ctx.Enhanced)return 4;
                if(ctx.Key=="zixi_convergence"&&ctx.Enhanced&&index==3&&ctx.NaturalAttackHeads==3)return 3;
                return ctx.Key=="zixi_almost_sure"?2*ctx.StartCausality:0;
            };
        }

        void PrepareAsh(int seat,int actor)
        {
            if(Sides[seat].Units[actor].CharacterId!="ash")return;
            Sides[seat].Preparation=1;
            Log.Add("灰烬 · 获得 1 层准备");
        }

        void GrantAllyShield(int seat,int actor,int value)
        {
            foreach(var ally in Sides[seat].Units.Where((u,i)=>i!=actor&&u.Hp>0))ally.Shield+=value;
        }

        void SupportGuard(int seat,int actor,string key)
        {
            if(Sides[seat].Units[actor].CharacterId=="support")
                GrantAllyShield(seat,actor,key=="light_guard"?8:key=="cover"?6:4);
        }

        void FinishUniqueClash(int seat,TrialDuelAction plan,ZixiContext ctx,bool won,int margin)
        {
            var u=Sides[seat].Units[plan.Actor];
            if(won)
            {
                PrepareAsh(seat,plan.Actor);
                if(plan.Key=="support_strike")GrantAllyShield(seat,plan.Actor,4);
                if(plan.Key=="marisa_stars")GainSpark(seat,plan.Actor,1);
                if(u.CharacterId=="reimu"&&u.RoleState.DreamDue>0)u.RoleState.DreamOrbs=Math.Min(3,u.RoleState.DreamOrbs+1);
            }
            else if(u.CharacterId=="breaker"&&PortContent.Card(plan.Key).Cost>=3)
            {
                u.Hp=Math.Max(0,u.Hp-2);
                RecordBeat("ability","长锋 · 破阵失败，损失 2 生命",seat,plan.Actor);
            }
            if(!won&&plan.Key=="observe")PrepareAsh(seat,plan.Actor);
            if(ctx==null)return;
            var z=u.Zixi;
            ctx.Won=won;
            if(won)
            {
                if(plan.Key=="zixi_central_limit")z.NextClash[plan.Key]=1;
                if(plan.Key=="zixi_convergence")z.NextClash[plan.Key]=2;
                int reward=margin>=5&&z.NoMarginRound!=Round?2:1;
                int gain=Math.Max(0,Math.Min(reward,Math.Min(3-z.RoundGain,6-z.Metaphysics)));
                z.RoundGain+=gain;z.Metaphysics+=gain;
                RecordBeat("ability","ZiXi · 超形上学 +"+gain+"（"+z.Metaphysics+" / 6）",seat,plan.Actor);
            }
            if(plan.Key=="zixi_martingale")
            {
                int amount=won?(ctx.Enhanced?12:8):4;
                int expiry=Round+1,carried;
                z.ShieldUntil.TryGetValue(expiry,out carried);
                z.ShieldUntil[expiry]=carried+amount;
                u.Shield+=amount;
                if(!won&&ctx.Enhanced)z.NextClash[plan.Key]=3;
                RecordBeat("ability","鞅 · 跨回合护盾 +"+amount,seat,plan.Actor);
            }
            if(ctx.Enhanced)z.Causality=Math.Min(3,z.Causality+1);
            if(ctx.Enhanced&&won&&plan.Key=="zixi_almost_sure")
            {
                ctx.Blast=6+5*z.Causality;
                z.Causality=0;z.NoMarginRound=Round+1;
            }
        }

        static void ConsumeZixiShield(Unit target,int blocked)
        {
            if(target.Zixi==null||blocked<=0)return;
            var store=target.Zixi.ShieldUntil;
            int needed=Math.Max(0,blocked-Math.Max(0,target.Shield-store.Values.Sum()));
            foreach(int key in store.Keys.ToArray())
            {
                if(needed<=0)break;
                int take=Math.Min(needed,store[key]);
                needed-=take;store[key]-=take;
                if(store[key]==0)store.Remove(key);
            }
        }

        void AddExorcism(int seat,int target,int actor)
        {
            var role=Sides[seat].Units[actor].RoleState;
            var foe=Sides[1-seat].Units[target];
            if(foe.Hp<=0)return;
            bool charging=role!=null&&role.DreamDue>0;
            foe.Exorcism=Math.Min(charging?6:4,foe.Exorcism+1);
            if(!charging&&foe.Exorcism>=4)
            {
                foe.Exorcism=0;foe.ExorcismPending=true;
                Log.Add(foe.Name+" · 退治引爆，下回合拼点−3、伤害减半");
            }
        }

        void GainSpark(int seat,int actor,int value)
        {
            var r=Sides[seat].Units[actor].RoleState;
            r.Spark=Math.Min(10,r.Spark+value);
            RecordBeat("ability","魔理沙 · 火花 "+r.Spark+" / 10",seat,actor);
        }

        int[] GroupStrike(int seat,TrialDuelAction plan,CoinStep step,IEnumerable<int> indexes,Func<int,int> raw,
            bool ignoreShield=false,bool mapBonus=true)
        {
            var actor=Sides[seat].Units[plan.Actor];
            var enemies=Sides[1-seat].Units;
            var hits=new List<PortHit>();
            foreach(int i in indexes)
            {
                var target=enemies[i];
                if(target.Hp<=0)continue;
                int power=raw(i);
                if(actor.ExorcismActive)power/=2;
                int before=target.Hp;
                Damage(target,actor,power,mapBonus?Sides[seat].Modifier.DamageBonus:0,ignoreShield);
                hits.Add(new PortHit(seat==1,i,power,Math.Max(0,before-target.Hp)));
            }
            if(hits.Count>0)
            {
                var report=step==null?null:step.Copy();
                if(report!=null){report.RawModifier+=hits[0].Raw-report.RawDamage;report.RawDamage=hits[0].Raw;}
                RecordBeat(step==null?"ability":"strike",actor.Name+" · "+PortContent.Card(plan.Key).Name+" → "+
                    string.Join("、",hits.Select(h=>DamageText(enemies[h.Target],h.Damage)).ToArray()),
                    seat,plan.Actor,hits[0].Target,report,hits.ToArray());
            }
            return hits.Select(h=>h.Target).ToArray();
        }

        void UniqueAttack(int seat,TrialDuelAction plan,CoinAction action,ZixiContext ctx)
        {
            var actor=Sides[seat].Units[plan.Actor];
            var enemies=Sides[1-seat].Units;
            bool marisa=actor.CharacterId=="marisa";
            bool meteor=plan.Key=="marisa_meteor",laser=plan.Key=="marisa_laser",spark=plan.Key=="marisa_spark";
            bool blazing=plan.Key=="marisa_blazing_star",blast=ctx!=null&&ctx.Blast>0;
            int cap=spark||blast?enemies.Length:blazing||laser||plan.Key=="engraved_soul"?3:1;
            var targets=new[]{plan.Target}.Concat(Enumerable.Range(0,enemies.Length)
                .Where(i=>i!=plan.Target&&enemies[i].Hp>0)).Take(cap).ToArray();
            int sparks=marisa?actor.RoleState.Spark:0;
            int bonus=marisa?(MarisaCompanion(seat)?5:0)+(sparks>5?2:0):0;
            if(blazing&&actor.Hp<10)
            {
                if(Sides[seat].Cost<3)
                {
                    RecordBeat("ability","炽热之星 · 低血量时需要额外 3 cost，本次未释放",seat,plan.Actor);
                    return;
                }
                Sides[seat].Cost-=3;
            }
            if(meteor)Sides[seat].Cost+=2;
            if(spark)actor.RoleState.Spark=0;
            bool won=action!=null;
            if(action==null)action=Action(seat,plan);
            var rng=new CoinRandomSource(random.Flip);
            var touched=new HashSet<int>();
            for(CoinStep step;(step=action.NextAttack(rng))!=null;)
            {
                if(blast)continue;
                bool first=step.AttackIndex==1;
                if(meteor&&!first)continue;
                int power=spark?10*sparks:blazing?step.RawDamage*sparks:meteor?10:step.RawDamage-(laser&&first?4:0);
                if(first&&!meteor&&(!(spark||blazing)||sparks>0))power+=bonus;
                var hits=GroupStrike(seat,plan,step,targets,i=>Math.Max(0,power),blazing||spark&&sparks>=5,!meteor);
                if(hits.Length==0)continue;
                touched.UnionWith(hits);
                action.NotifyHit(step.Heads);
            }
            action.CompleteAttack();
            if(blast)touched.UnionWith(GroupStrike(seat,plan,null,targets,i=>ctx.Blast));
            if(won&&laser)GainSpark(seat,plan.Actor,touched.Count);
            if(blazing&&actor.Hp>=10)actor.Hp=10;
            if(touched.Count>0)TryRemiliaCounter(seat,plan.Actor);
        }

        bool PerformUnique(int seat,TrialDuelAction plan,PortCard card,CoinAction action,ZixiContext zixi)
        {
            var u=Sides[seat].Units[plan.Actor];
            var r=u.RoleState;
            var foes=Sides[1-seat].Units;
            string note;
            switch(plan.Key)
            {
                case "misdirection":
                    r.DodgeTurn=Round;r.DodgePower=Speed(seat,plan.Actor)>=9?15:10;
                    note="本回合闪避点数 "+r.DodgePower;break;
                case "private_square":r.SpacePending=true;note="下回合速度 +3，伤害 +5";break;
                case "stopwatch":r.WatchUntil=Round+2;note="接下来两回合敌速 −3，按速度差强化拼点";break;
                case "the_world":r.WorldRound=Round+1;note="下回合时停，咲夜获得三个行动槽";break;
                case "demon_seal":
                    foes[plan.Target].SealPending=true;
                    for(int i=plan.Target-1;i>=0;i--)
                        if(foes[i].Hp>0){foes[i].SealPending=true;break;}
                    note="目标与左侧最近存活角色下回合拼点 −2";break;
                case "fantasy_nature":
                    r.DreamOrbs=1;r.DreamDue=Round+3;note="第 "+r.DreamDue+" 回合末结算";break;
                case "danmaku_barrier":
                    if(BarrierCaster(seat)<0)r.BarrierFrom=Round+1;
                    r.BarrierUntil=Round+3;note="接下来三回合敌速 −1，敌方行动受伤并叠退治";break;
                case "eight_way_bind":
                    if(foes[plan.Target].Hp<=0)return true;
                    var roll=Action(seat,plan).NextAttack(new CoinRandomSource(random.Flip));
                    foreach(var ally in Sides[seat].Units.Where(a=>a.Hp>0))ally.Shield+=roll.RawDamage;
                    foes[plan.Target].BindingTurn=Round+1;
                    AddExorcism(seat,plan.Target,plan.Actor);
                    note="队友获得 "+roll.RawDamage+" 护盾，目标下回合速度 −1";break;
                case "marisa_orrery":
                    r.OrreryUntil=Round+1;GainSpark(seat,plan.Actor,1);
                    note="本回合及下回合每次攻击减伤 5";break;
                case "zixi_martingale":return true;
                default:
                    if(plan.Target<0)return false;
                    if(u.CharacterId!="marisa"&&plan.Key!="engraved_soul"&&(zixi==null||zixi.Blast==0))return false;
                    UniqueAttack(seat,plan,action,zixi);
                    return true;
            }
            RecordBeat("ability",u.Name+" · "+card.Name+" · "+note,seat,plan.Actor,plan.Target);
            return true;
        }

        public void ReadyLocalOpponent()
        {
            const int seat=1;
            if(Recruitment||!CanEdit(seat)||(Stage!=TrialDuelStage.Deck&&Stage!=TrialDuelStage.Plan))return;
            opponentIsLocal=true;
            if(Stage==TrialDuelStage.Deck)
                for(int actor=0;actor<Sides[seat].Units.Length;actor++)
                    foreach(string key in Exclusive(seat,actor).OrderBy(key=>opponentDeckRandom.Range(int.MaxValue)).Take(4))
                        if(!Sides[seat].Equipped[actor].Contains(key))Toggle(seat,actor,key);
            SetReady(seat,true);
        }
    }
}
