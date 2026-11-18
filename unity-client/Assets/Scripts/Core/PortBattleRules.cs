using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    public sealed class PortSlot
    {
        public int Id,Unit,Category,Speed,Card=-1,Target=-1,Order;
        public bool Active,Done,Frozen,Flexible,Enhanced;
        public string Key="";
        public PortSlot Copy() { return (PortSlot)MemberwiseClone(); }
    }
    public sealed class PortState
    {
        public List<Unit> Heroes=new List<Unit>(),Enemies=new List<Unit>();
        public List<PortSlot> HeroSlots=new List<PortSlot>(),EnemySlots=new List<PortSlot>();
        public string[] Kinds;
        public string[] Hand;public bool TouhouTeam,ZixiTeam,WorldActive;public int EnemyCost=30;
        public string Phase="response",Outcome="";
        public int Cost=30,Turn=1,Plays,Preparation,Order;
        public double Remaining=180;
        public bool RewardPaid;
        public int Reserved { get { return Phase=="response"?HeroSlots.Where(x=>x.Active).Sum(x=>PortContent.Card(x.Key).Cost):0; } }
        public int PlanCount { get { return HeroSlots.Count(x=>x.Active); } }
        public PortState Copy(bool hide)
        {
            var s=(PortState)MemberwiseClone(); s.Heroes=Heroes.Select(x=>x.Copy()).ToList();s.Enemies=Enemies.Select(x=>x.Copy()).ToList();
            s.HeroSlots=HeroSlots.Select(x=>x.Copy()).ToList();s.EnemySlots=EnemySlots.Select(x=>x.Copy()).ToList();s.Kinds=(string[])Kinds.Clone();s.Hand=(string[])Hand.Clone();
            if(hide&&Phase=="response") foreach(var slot in s.EnemySlots) { slot.Key="";slot.Card=-1; }
            return s;
        }
        public string Fingerprint()
        { return Phase+"/"+Outcome+"/"+Cost+"/"+Turn+"/"+Preparation+"/"+TouhouTeam+":"+ZixiTeam+":"+EnemyCost+"/"+string.Join(";",Heroes.Concat(Enemies).Select(x=>x.Hp+":"+x.Shield+":"+x.StatusFingerprint()).ToArray())+"/"+string.Join(";",HeroSlots.Concat(EnemySlots).Select(x=>x.Unit+":"+x.Category+":"+x.Speed+":"+x.Active+":"+x.Key+":"+x.Target+":"+x.Order+":"+x.Done).ToArray()); }
    }
    public sealed class PortEvent
    {
        public string Type,Message;
        public int Hero=-1,Enemy=-1,Left,Right,Winner=-1,HeroRemaining,EnemyRemaining,Damage,Speed;
        public PortState Snapshot;
        public CoinStep Coin;
        public bool AttackerAllied;
    }
    public partial class PortBattleRules
    {
        public PortState State { get; private set; }
        BattleRandom rng;
        int currentSpeed;
        public PortBattleRules(uint seed=73129,int encounter=0,bool touhou=false,bool zixi=false) { Start(seed,encounter,touhou,zixi); }
        public void Start(uint seed,int encounter,bool touhou=false,bool zixi=false)
        {
            rng=new BattleRandom(seed);State=new PortState();
            State.Heroes.Add(new Unit{Name="灰烬",Role="蓄势者",Hp=48,MaxHp=48,MinSpeed=3,MaxSpeed=6});
            State.Heroes.Add(new Unit{Name="长锋",Role="破阵者",Hp=42,MaxHp=42,MinSpeed=5,MaxSpeed=8});
            State.Heroes.Add(new Unit{Name="织火",Role="援护者",Hp=46,MaxHp=46,MinSpeed=2,MaxSpeed=5});
            State.TouhouTeam=touhou;State.ZixiTeam=zixi;if(zixi)State.Heroes[1]=ZixiRole.Create();if(touhou){State.Heroes[0]=TouhouRoles.Marisa();State.Heroes[1]=TouhouRoles.Sakuya();State.Heroes[2]=TouhouRoles.Reimu();}
            State.Kinds=encounter==1?new[]{"priest","elite"}:new[]{"scout","warden"};
            State.Enemies.Add(new Unit{Name=encounter==1?"缚咒祭司":"裂影斥候",Hp=encounter==1?52:58,MaxHp=encounter==1?52:58,MinSpeed=encounter==1?3:4,MaxSpeed=encounter==1?6:7});
            State.Enemies.Add(new Unit{Name=encounter==1?"鸣钟行刑者":"守墓盾卫",Hp=encounter==1?95:65,MaxHp=encounter==1?95:65,MinSpeed=2,MaxSpeed=5});
            PrepareRound();
        }
        public PortState Snapshot() { return State.Copy(true); }
        void PrepareRound()
        {
            PrepareTouhouRound();State.Hand=State.TouhouTeam?PortContent.Hand.Where(k=>PortContent.Card(k).Owner<0).Concat(TouhouRoles.MarisaCards).Concat(TouhouRoles.SakuyaCards).Concat(TouhouRoles.ReimuCards).ToArray():State.ZixiTeam?PortContent.Hand.Where(k=>PortContent.Card(k).Owner!=1).Concat(ZixiRole.Keys).ToArray():(string[])PortContent.Hand.Clone();
            if(equippedSkills!=null)State.Hand=State.Hand.Where(equippedSkills.Contains).ToArray();
            State.Phase="response";State.Remaining=180;State.Plays=0;State.Order=0;State.RewardPaid=false;State.HeroSlots.Clear();State.EnemySlots.Clear();
            foreach(var u in State.Heroes.Concat(State.Enemies)) { u.Shield=0;u.Acted=false;u.Spent=false; }
            PrepareZixiRound();
            for(int side=0;side<2;side++)
            {
                var units=side==0?State.Heroes:State.Enemies;var slots=side==0?State.HeroSlots:State.EnemySlots;
                for(int u=0;u<units.Count;u++) for(int c=0;c<3;c++)
                {
                    var slot=new PortSlot{Id=slots.Count,Unit=u,Category=c,Speed=Math.Max(1,units[u].MinSpeed+rng.Range(units[u].MaxSpeed-units[u].MinSpeed+1)+TouhouSpeed(side==0,u)),Frozen=side==0&&State.WorldActive&&u!=1,Flexible=side==0&&State.WorldActive&&u==1};
                    if(side==1&&units[u].Hp>0&&!State.WorldActive)
                    {
                        slot.Active=c==0||c==((State.Turn+u)%2==0?1:2);
                        if(slot.Active)
                        {
                            slot.Key=new[]{"ember","nova","guard"}[c];
                            if(c==0&&State.Kinds[u]=="scout") slot.Key="needle";
                            if(c==0&&State.Kinds[u]=="elite") slot.Key="cleave";
                            slot.Target=c==2?u:Living((State.Turn+u+c-1)%3);
                        }
                    }
                    slots.Add(slot);
                }
            }
            if(State.TouhouTeam){int available=State.EnemyCost;foreach(var e in State.EnemySlots.Where(x=>x.Active)){int price=PortContent.Card(e.Key).Cost;if(price>available)e.Active=false;else available-=price;}}
        }
        public int SlotFor(int hero,string key,int preferred=-1)
        {
            if(State.WorldActive&&hero==1){if(preferred>=3&&preferred<6)return preferred;var previous=State.HeroSlots.FirstOrDefault(x=>x.Unit==hero&&x.Active&&x.Key==key);if(previous!=null)return previous.Id;var free=State.HeroSlots.FirstOrDefault(x=>x.Unit==hero&&!x.Active);return free==null?3:free.Id;}
            return hero*3+PortContent.Card(key).Category;
        }
        public string CanAssign(string key,int slotId,int target)
        {
            if(State.Phase!="response"||State.Outcome!="") return "当前不能修改行动";
            var skill=PortContent.Cards.FirstOrDefault(x=>x.Id==key);
            if(skill==null||!State.Hand.Contains(key)||slotId<0||slotId>=State.HeroSlots.Count) return "请选择技能和行动格";
            var slot=State.HeroSlots[slotId];if(State.Heroes[slot.Unit].Hp<=0) return "该成员已退场";
            if(slot.Frozen)return "时间停止，本回合只有咲夜可以行动";
            if(key=="the_world"&&State.Heroes[1].RoleState.WorldUsed)return "咲夜的世界本场已经使用";
            if(key=="fantasy_nature"&&State.Heroes[2].RoleState.DreamDue>0)return "梦想天生已经开始蓄能";
            if(skill.Owner>=0&&skill.Owner!=slot.Unit) return "这是其他角色的专属技能";
            if(!slot.Flexible&&skill.Category!=slot.Category) return "技能与行动格类别不符";
            if(State.HeroSlots.Any(x=>x.Id!=slotId&&x.Active&&x.Key==key)) return "技能已被其他行动预留";
            if(State.HeroSlots.Count(x=>x.Id!=slotId&&x.Active&&x.Unit==slot.Unit)>=(slot.Flexible?3:2)) return "本回合该成员行动槽已满";
            if(!CanFundMarisa(skill,slotId)) return "可用 cost 不足";
            if(skill.TargetsEnemy&&(target<0||target>=State.EnemySlots.Count||State.Enemies[State.EnemySlots[target].Unit].Hp<=0)) return "请选择存活敌人的行动格";
            if(skill.RequiresClash&&!CanClashSkill(slot,State.EnemySlots[target],skill))return "这张牌需要合法的敌方拼点行动";
            return "";
        }
        public bool Assign(string key,int hero,int target,int preferredSlot=-1)
        {
            if(hero<0||hero>=3) return false;int id=SlotFor(hero,key,preferredSlot);if(CanAssign(key,id,target)!="") return false;
            var slot=State.HeroSlots[id];UnreserveZixi(slot);slot.Active=true;slot.Card=Array.IndexOf(State.Hand,key);slot.Key=key;slot.Enhanced=false;slot.Target=PortContent.Card(key).TargetsEnemy?target:hero;slot.Order=++State.Order;return true;
        }
        public bool Cancel(int id)
        { if(State.Phase!="response"||id<0||id>=State.HeroSlots.Count||!State.HeroSlots[id].Active)return false;var s=State.HeroSlots[id];UnreserveZixi(s);s.Active=false;s.Key="";s.Card=-1;s.Target=-1;return true; }
        public bool Tick(double delta) { if(State.Phase!="response") return false;State.Remaining=Math.Max(0,State.Remaining-Math.Max(0,delta));return State.Remaining<=0; }
        public bool CanClash(PortSlot h,PortSlot e)
        {return CanClashSkill(h,e,h.Key==""?null:PortContent.Card(h.Key));}
        bool CanClashSkill(PortSlot h,PortSlot e,PortCard skill)
        {return (skill==null?h.Category!=2:skill.TargetsEnemy)&&!h.Frozen&&e.Active&&e.Category!=2&&State.Heroes[h.Unit].Hp>0&&State.Enemies[e.Unit].Hp>0&&(h.Speed>=e.Speed||e.Target==h.Unit||State.TouhouTeam&&h.Unit==1);}
        public int PairFor(int enemySlot)
        {
            var e=State.EnemySlots[enemySlot];var h=State.HeroSlots.Where(x=>x.Active&&x.Target==e.Id&&CanClash(x,e)).OrderByDescending(x=>x.Order).FirstOrDefault();return h==null?-1:h.Id;
        }
        sealed class Entry { public int H=-1,E=-1,Speed,Order; }
        public List<PortEvent> Resolve()
        {return ResolveStream().ToList();}
        public IEnumerable<PortEvent> ResolveStream()
        {
            var events=new List<PortEvent>();if(State.Phase!="response"||State.Outcome!="")yield break;
            var pairs=State.EnemySlots.Where(x=>x.Active&&x.Category!=2).ToDictionary(x=>x.Id,x=>PairFor(x.Id));
            State.Phase="resolve";currentSpeed=0;PayMarisaFunding(events);
            foreach(var h in State.HeroSlots.Where(x=>x.Active)) { State.Cost-=PortContent.Card(h.Key).Cost;State.Plays++;if(h.Key=="the_world")State.Heroes[1].RoleState.WorldUsed=true; }
            Emit(events,"reveal","双方锁定，揭晓技能；支付全部预留费用");
            foreach(var ev in events)yield return ev;events.Clear();
            var queue=new List<Entry>();
            foreach(var h in State.HeroSlots.Where(x=>x.Active&&!pairs.Values.Contains(x.Id))) queue.Add(new Entry{H=h.Id,Speed=h.Speed,Order=h.Id});
            foreach(var e in State.EnemySlots.Where(x=>x.Active)) { int h=pairs.ContainsKey(e.Id)?pairs[e.Id]:-1;queue.Add(new Entry{H=h,E=e.Id,Speed=h>=0?Math.Max(e.Speed,State.HeroSlots[h].Speed):e.Speed,Order=h>=0?State.HeroSlots[h].Id:9+e.Id}); }
            foreach(var a in queue.OrderByDescending(x=>x.Speed).ThenBy(x=>x.Order))
            {
                if(State.Outcome!="")break; currentSpeed=a.Speed;var h=a.H>=0?State.HeroSlots[a.H]:null;var e=a.E>=0?State.EnemySlots[a.E]:null;
                bool ha=h!=null&&State.Heroes[h.Unit].Hp>0,ea=e!=null&&State.Enemies[e.Unit].Hp>0;
                if(ha&&ea){foreach(var ev in Clash(events,h,e))yield return ev;}else { if(ha)Solo(events,h,true);if(ea)Solo(events,e,false); }
                if(h!=null)h.Done=true;if(e!=null)e.Done=true;CheckOutcome(events);
                foreach(var ev in events)yield return ev;events.Clear();
            }
            ResolveDream(events);if(State.Outcome=="")CheckOutcome(events);State.Phase=State.Outcome==""?"finished":"outcome";Emit(events,"round_end",State.Outcome==""?"本回合结束":"战斗结束");foreach(var ev in events)yield return ev;
        }
        public void NextRound() { if(State.Phase!="finished")return;State.Turn++;State.Cost+=8;if(State.TouhouTeam)State.EnemyCost+=8;foreach(var unit in State.Heroes.Concat(State.Enemies))CoinStatus.NextRound(unit.Statuses);PrepareRound(); }
        protected virtual bool FlipCoin(double chance) {return rng.Flip(chance);}
        CoinAction CoinRuntime(PortCard skill,bool allied,int source,int target,IEnumerable<CoinEffect> extra=null)
        {return new CoinAction(skill.CoinData,allied?.65:.5,(allied?State.Heroes:State.Enemies)[source].Statuses,(allied?State.Enemies:State.Heroes)[target].Statuses,(extra??new CoinEffect[0]).Concat(TouhouAttackEffects(allied,source)));}
        void Solo(List<PortEvent> events,PortSlot slot,bool allied)
        {
            var skill=PortContent.Card(slot.Key);var units=allied?State.Heroes:State.Enemies;
            if(allied&&slot.Key=="marisa_orrery"){State.Heroes[0].RoleState.OrreryUntil=State.Turn+1;GainSpark(events,1);Emit(events,"ability","天球仪：本回合及下回合每次攻击减伤5",0);return;}
            if(!skill.TargetsEnemy)
            {
                new CoinAction(skill.CoinData,allied?.65:.5,units[slot.Unit].Statuses).NextAttack(new CoinRandomSource(FlipCoin));
                int amount=!allied&&State.Kinds[slot.Unit]=="warden"?14:9;units[slot.Unit].Shield+=amount;
                if(allied&&slot.Unit==2&&!State.TouhouTeam) AllyShield(skill.Id=="light_guard"?8:skill.Id=="cover"?6:4,events,"织火 · 援护");
                if(!allied&&State.Kinds[slot.Unit]=="priest") { for(int i=0;i<State.Enemies.Count;i++)if(i!=slot.Unit&&State.Enemies[i].Hp>0)State.Enemies[i].Shield+=6; }
                Emit(events,"guard",units[slot.Unit].Name+" 获得 "+amount+" 护盾",allied?slot.Unit:-1,allied?-1:slot.Unit);return;
            }
            int target=allied?State.EnemySlots[slot.Target].Unit:slot.Target;var victims=allied?State.Enemies:State.Heroes;
            if(allied&&skill.RequiresClash){Emit(events,"cancelled",skill.Name+" 未形成拼点，行动取消且不转移目标",slot.Unit,target);return;}
            if(target<0||target>=victims.Count||victims[target].Hp<=0) { Emit(events,"cancelled","目标已退场，行动取消");return; }
            Emit(events,"unopposed",units[slot.Unit].Name+" · "+skill.Name+" → "+victims[target].Name,allied?slot.Unit:target,allied?target:slot.Unit);
            if(allied)ReleaseTouhou(events,slot,false);if(allied&&IsMarisa(slot.Unit))AttackMarisa(events,slot,target,CoinRuntime(skill,true,slot.Unit,target),skill,false);else Attack(events,allied,slot.Unit,target,CoinRuntime(skill,allied,slot.Unit,target),skill);
            Observe(events,skill,allied);
        }
        void Observe(List<PortEvent> events,PortCard skill,bool allied)
        { if(allied&&skill.Id=="observe"&&State.Heroes[0].Hp>0) { State.Preparation=1;Emit(events,"ability","灰烬 · 观察：获得 1 层准备",0); } }
        void AllyShield(int amount,List<PortEvent> events,string message)
        { for(int i=0;i<2;i++)if(State.Heroes[i].Hp>0)State.Heroes[i].Shield+=amount;Emit(events,"ability",message+"：其他存活队友获得 "+amount+" 护盾",2); }
        IEnumerable<PortEvent> Clash(List<PortEvent> events,PortSlot h,PortSlot e)
        {
            var left=PortContent.Card(h.Key);var right=PortContent.Card(e.Key);int bonus=left.Id=="exploit"&&State.Preparation>0?4:!State.TouhouTeam&&!State.ZixiTeam&&h.Unit==1&&left.Cost>=3?2:0;
            bool breaker=!State.TouhouTeam&&!State.ZixiTeam&&h.Unit==1&&bonus>0;
            if(left.Id=="exploit"&&bonus>0) {State.Preparation=0;Emit(events,"ability","灰烬 · 捕捉破绽：消耗准备，拼点威力 +4",0);}
            if(breaker)Emit(events,"ability","长锋 · 破阵：拼点威力 +2，失败损失 2 生命",1);
            var extra=new List<CoinEffect>();if(bonus!=0)extra.Add(new CoinEffect(breaker?"破阵":"捕捉破绽",CoinTrigger.ClashStart,CoinStat.BasePower,bonus,CoinEffectScope.Clash));
            var zctx=BeginZixiClash(h,left,extra);int heroBonus=TouhouHeroClash(h,e)+MarisaClashBonus(h,left);if(heroBonus!=0)extra.Add(new CoinEffect("秒表/灵梦被动",CoinTrigger.ClashStart,CoinStat.BasePower,heroBonus,CoinEffectScope.Clash));
            var enemyExtra=new List<CoinEffect>();int penalty=TouhouEnemyClash(e.Unit);if(penalty!=0)enemyExtra.Add(new CoinEffect("退治/封魔",CoinTrigger.ClashStart,CoinStat.BasePower,penalty,CoinEffectScope.Clash));
            var ha=CoinRuntime(left,true,h.Unit,e.Unit,extra);var ea=CoinRuntime(right,false,e.Unit,h.Unit,enemyExtra);AttachZixiTransforms(ha,zctx);var session=new CoinClash(ha,ea,new CoinRandomSource(FlipCoin));
            CoinStep finalStep=null;while(!session.Complete)
            {
                var step=session.Step();finalStep=step;var ev=Emit(events,"clash",CoinLog.Clash(step),h.Unit,e.Unit);
                ev.Coin=step;ev.Left=step.LeftPower;ev.Right=step.RightPower;ev.Winner=step.Winner;ev.HeroRemaining=step.LeftRemaining;ev.EnemyRemaining=step.RightRemaining;
                foreach(var item in events)yield return item;events.Clear();
            }
            var final=Emit(events,"clash_end","最终拼点胜者："+(session.Winner==0?left.Name:right.Name),h.Unit,e.Unit);final.Coin=new CoinStep{Type="clash",FinalWinner=session.Winner,Winner=session.Winner,Round=ha.ClashRound,Left=ha.Snapshot(),Right=ea.Snapshot(),LeftRemaining=ha.RemainingCoins,RightRemaining=ea.RemainingCoins};
            FinishZixiClash(events,h,left,zctx,session.Winner,finalStep);
            if(session.Winner==0)
            {
                ReleaseTouhou(events,h,true);if(h.Key=="marisa_stars")GainSpark(events,1);
                if(h.Unit==0&&!State.TouhouTeam){State.Preparation=1;Emit(events,"ability","灰烬 · 蓄势：获得 1 层准备",0);}
                if(left.Id=="support_strike")AllyShield(4,events,"织火 · 援火冲击");
                if(!State.RewardPaid){State.RewardPaid=true;State.Cost++;Emit(events,"reward","本回合首次拼点获胜 +1 cost");}
                AttackNewHero(events,h,e.Unit,ha,left,zctx);
            }
            else
            {
                if(breaker){State.Heroes[1].Hp=Math.Max(0,State.Heroes[1].Hp-2);Emit(events,"ability","长锋 · 破阵失败，损失 2 生命",1);}
                State.Cost+=left.Cost/2;Emit(events,"refund","拼点失败，退款 +"+left.Cost/2+" cost",h.Unit);
                Attack(events,false,e.Unit,h.Unit,ea,right);
            }
            Observe(events,left,true);
        }
        void Attack(List<PortEvent> events,bool allied,int source,int target,CoinAction action,PortCard skill)
        {
            var victim=(allied?State.Enemies:State.Heroes)[target];CoinStep step,last=null;var gameRandom=new CoinRandomSource(FlipCoin);int marks=skill.Id=="fantasy_seal"?2:skill.Id=="yin_yang_orb"?1:0;
            while((step=action.NextAttack(gameRandom))!=null)
            {
                bool live=victim.Hp>0&&!skill.NoDamage;int positive=Math.Max(0,step.RawDamage);if(!allied&&State.TouhouTeam&&State.Enemies[source].ExorcismActive)positive/=2;if(!allied&&IsMarisa(target)&&State.Heroes[target].RoleState.OrreryUntil>=State.Turn)positive=Math.Max(0,positive-5);
                int blocked=live?Math.Min(victim.Shield,positive):0,damage=live?positive-blocked:0;AbsorbZixiShield(victim,blocked);victim.Shield-=blocked;victim.Hp=Math.Max(0,victim.Hp-damage);
                if(allied)MarkTouhouHit(events,skill.Id,source,target,damage,ref marks);
                if(!allied&&State.TouhouTeam&&target==2&&victim.Hp==0){victim.RoleState.DreamDue=0;victim.RoleState.DreamOrbs=0;}
                if(live)action.NotifyHit(step.Heads);step.Effects=step.Effects.Concat(action.DrainEffects()).ToArray();last=step;
                if(!allied&&damage>0&&State.Kinds[source]=="scout"&&target==0&&State.Preparation>0){State.Preparation=0;Emit(events,"ability","裂影斥候命中，移除灰烬准备",0,source);}
                var ev=Emit(events,"strike",CoinLog.Attack(step)+"；"+(skill.NoDamage?"辅助效果不造成直接伤害":live?victim.Name+" 实伤 "+damage+(blocked>0?" / 盾吸收 "+blocked:""):"目标已退场，不再命中"),allied?source:target,allied?target:source);ev.Damage=damage;ev.Coin=step;ev.AttackerAllied=allied;
            }
            action.CompleteAttack();if(last!=null){var end=Emit(events,"attack_end",action.Skill.Name+" 攻击结束："+action.AttackCount+" 次，累计原始 "+action.TotalRawDamage,allied?source:target,allied?target:source);end.Coin=last.Copy();end.Coin.Left=action.Snapshot();end.Coin.Effects=action.DrainEffects();}
        }
        int Living(int preferred) { return preferred>=0&&preferred<3&&State.Heroes[preferred].Hp>0?preferred:State.Heroes.FindIndex(x=>x.Hp>0); }
        void CheckOutcome(List<PortEvent> events)
        { if(State.Enemies.All(x=>x.Hp<=0))State.Outcome="victory";else if(State.Heroes.All(x=>x.Hp<=0))State.Outcome="defeat";if(State.Outcome!="")Emit(events,"outcome",State.Outcome=="victory"?"战斗胜利":"战斗失败"); }
        PortEvent Emit(List<PortEvent> events,string type,string message,int hero=-1,int enemy=-1)
        {var e=new PortEvent{Type=type,Message=message,Hero=hero,Enemy=enemy,Speed=currentSpeed,Snapshot=Snapshot()};events.Add(e);return e;}
    }
}
