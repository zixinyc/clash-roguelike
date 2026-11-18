using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class TouhouChecks
    {
        static int checks;static void Check(bool ok,string message){checks++;if(!ok)throw new Exception("Touhou integration: "+message);}
        sealed class Heads:PortBattleRules{public Heads():base(73129,0,true){}protected override bool FlipCoin(double c){return c>.5;}}
        sealed class Faces:PortBattleRules{readonly bool[] faces;int index;public Faces(bool[] f):base(73129,0,true){faces=f;}protected override bool FlipCoin(double c){return c>.5&&faces[index++];}}
        sealed class Tails:PortBattleRules{public Tails():base(73129,0,true){}protected override bool FlipCoin(double c){return c<=.5;}}
        static void Quiet(PortBattleRules b,int active=-1,int target=0)
        {b.State.Cost=100;foreach(var u in b.State.Enemies){u.Hp=1000;u.MaxHp=1000;}foreach(var e in b.State.EnemySlots){e.Active=e.Id==active;if(e.Active){e.Key="needle";e.Target=target;}}}
        public static int Run()
        {
            checks=0;var b=new Heads();Check(b.State.TouhouTeam&&b.State.Heroes[1].Name=="十六夜咲夜"&&b.State.Heroes[1].Hp==40&&b.State.Heroes[2].Name=="博丽灵梦"&&b.State.Heroes[2].Hp==50,"source character roster and HP");
            Check(b.State.Hand.Length==18&&TouhouRoles.SakuyaCards.All(b.State.Hand.Contains)&&TouhouRoles.ReimuCards.All(b.State.Hand.Contains)&&TouhouRoles.MarisaCards.All(b.State.Hand.Contains)&&b.State.Heroes[0].Name=="雾雨魔理沙"&&!b.State.Hand.Contains("all_in"),"exclusive roster replaces old owner-one/two hand");
            Check(b.State.Heroes[1].MinSpeed==5&&b.State.Heroes[1].MaxSpeed==9&&b.State.Heroes[2].MinSpeed==4&&b.State.Heroes[2].MaxSpeed==6,"source speed ranges");
            Check(!b.Assign("murder_doll",0,0)&&!b.Assign("yin_yang_orb",1,0),"character skill ownership");
            Quiet(b,0,0);b.State.HeroSlots[3].Speed=1;b.State.EnemySlots[0].Speed=9;Check(b.Assign("murder_doll",1,0)&&b.PairFor(0)==3,"Sakuya ignores interception speed while keeping last valid designation");
            var events=b.Resolve();var strikes=events.Where(e=>e.Type=="strike").ToArray();Check(strikes.Length==1&&strikes[0].Damage==15&&strikes[0].Coin.RawDamage==15,"Murder Doll one coin plus Silver Knife exactly once");
            Check(events.Any(e=>e.Type=="clash")&&events.Where(e=>e.Type=="clash").All(e=>e.Coin.LeftBefore==1),"single fixed skill coin is not restored during clashes");
            var tails=new Tails();Quiet(tails);tails.Assign("murder_doll",1,0);strikes=tails.Resolve().Where(e=>e.Type=="strike").ToArray();Check(strikes.Length==1&&strikes[0].Damage==10,"old fixed-damage shortcut replaced by tail base plus passive");
            b=new Heads();Quiet(b);Check(b.Assign("stopwatch",1,0)&&b.Assign("private_square",1,0),"targeted utility defense shares round with ultimate");events=b.Resolve();
            Check(events.Where(e=>e.Type=="strike").Count()==2&&events.Where(e=>e.Type=="strike").All(e=>e.Damage==0&&e.Coin.RemainingAttackCoins==0)&&!events.Any(e=>e.Type=="guard"),"utility skills consume original coins but suppress actual hit/damage and shield");
            Check(b.State.Heroes[1].RoleState.WatchUntil==3&&b.State.Heroes[1].RoleState.SpacePending&&!b.State.Heroes[1].RoleState.WatchActive,"utility starts on subsequent rounds");b.NextRound();
            Check(b.State.HeroSlots.Where(s=>s.Unit==1).All(s=>s.Speed>=8&&s.Speed<=12)&&b.State.EnemySlots.Where(s=>s.Unit==1).All(s=>s.Speed>=1&&s.Speed<=2),"space plus three speed; stopwatch enemy speed minus three minimum one");
            Check(b.State.Heroes[1].RoleState.SpaceActive&&b.State.Heroes[1].RoleState.WatchActive,"two utility states active next round");
            Quiet(b);b.Assign("murder_doll",1,0);events=b.Resolve();Check(events.First(e=>e.Type=="strike").Damage==20,"Silver Knife and space each added once per attack");b.NextRound();
            Check(b.State.Heroes[1].RoleState.WatchActive&&!b.State.Heroes[1].RoleState.SpaceActive,"watch lasts two rounds; space one");Quiet(b);b.Assign("murder_doll",1,0);Check(b.Resolve().First(e=>e.Type=="strike").Damage==12,"third-round Silver Knife is plus two");b.NextRound();
            Check(!b.State.Heroes[1].RoleState.WatchActive,"watch expires");Quiet(b);b.Assign("murder_doll",1,0);Check(b.Resolve().First(e=>e.Type=="strike").Damage==10,"opening passive expires after third round");
            b=new Heads();Quiet(b);b.Assign("the_world",1,0);b.Resolve();Check(b.State.Heroes[1].RoleState.WorldUsed&&b.State.Heroes[1].RoleState.WorldRound==2,"world arms once for next round");b.NextRound();
            Check(b.State.WorldActive&&b.State.EnemySlots.All(s=>!s.Active)&&b.State.HeroSlots.Where(s=>s.Unit!=1).All(s=>s.Frozen),"world stops enemy attacks/defenses and other allies");
            Check(!b.Assign("cleave",0,0)&&!b.Assign("yin_yang_orb",2,0)&&!b.Assign("the_world",1,0),"frozen units cannot plan; world cannot repeat");
            int wallet=b.State.Cost=3;
            Check(b.Assign("murder_doll",1,0)&&!b.Assign("murder_doll",1,3)&&b.State.PlanCount==1&&b.State.Cost==3&&b.State.Reserved==2,"insufficient cost cannot add a second world action or alter the first");
            b.State.Cost=wallet=4;
            Check(b.Assign("murder_doll",1,3)&&b.State.PlanCount==2,"world repeat selection fills separate actions without replacing the first");
            Check(b.State.Reserved==4&&!b.Assign("needle",1,0,5),"two independently charged actions and third action rejected");
            Check(b.Assign("murder_doll",1,3,3)&&b.State.PlanCount==2,"explicit slot can retarget without adding an action");
            Check(b.Cancel(4)&&b.State.Reserved==2&&b.Assign("murder_doll",1,0)&&b.State.Reserved==4,"cancel releases exactly one duplicate skill reservation");
            events=b.Resolve();Check(b.State.Plays==2&&b.State.Cost==wallet-4&&!events.Any(e=>e.Type=="clash")&&events.Count(e=>e.Type=="strike")==2,"world resolves two paid independent attacks");
            Check(events.Where(e=>e.Type=="attack_end").All(e=>e.Coin.AttackBudget==1)&&events.Where(e=>e.Type=="strike").All(e=>e.Coin.AttackCarry==0&&e.Damage==15),"repeated world skills reset coin accumulation and apply silver knife separately");
            b.NextRound();Check(!b.State.WorldActive&&b.State.HeroSlots.All(s=>!s.Flexible&&!s.Frozen),"normal slot rules restored after world");
            Quiet(b);Check(b.Assign("murder_doll",1,0)&&b.Assign("murder_doll",1,3)&&b.State.PlanCount==1&&b.CanAssign("murder_doll",4,3)!="","ordinary rounds retarget existing action and retain category restrictions");
            for(int mask=0;mask<32;mask++)
            {
                var faces=Enumerable.Range(0,5).Select(i=>(mask&(1<<i))!=0).ToArray();var mixed=new Faces(faces);Quiet(mixed);mixed.State.Enemies[0].Exorcism=3;mixed.Assign("fantasy_seal",2,0);
                var hits=mixed.Resolve().Where(e=>e.Type=="strike").ToArray();int raw=1;
                for(int hit=0;hit<5;hit++){if(faces[hit])raw+=3;Check(hits[hit].Coin.RawDamage==raw&&hits[hit].Damage==raw&&hits[hit].Snapshot.Enemies[0].Hp==1000-hits.Take(hit+1).Sum(e=>e.Damage),"Fantasy Seal mixed faces: displayed raw, damage and HP snapshot carry prior heads through mark detonation");}
            }
            foreach(string key in new[]{"yin_yang_orb","marisa_stars","marisa_laser","murder_doll"})
            {
                var card=PortContent.Card(key);
                for(int mask=0;mask<(1<<card.Coins);mask++)
                {
                    var faces=Enumerable.Range(0,card.Coins).Select(i=>(mask&(1<<i))!=0).ToArray();var mixed=new Faces(faces);Quiet(mixed);mixed.Assign(key,card.Owner,0);
                    var hits=mixed.Resolve().Where(e=>e.Type=="strike"&&e.Enemy==0).ToArray();int accumulated=0;
                    for(int hit=0;hit<hits.Length;hit++)
                    {
                        if(faces[hit])accumulated+=card.AttackCoinPower;
                        int expected=card.Base+accumulated+(key=="murder_doll"?5:0)+(key.StartsWith("marisa_")&&hit==0?5:0)-(key=="marisa_laser"?4:0);
                        Check(hits[hit].Coin.AttackAccumulated==accumulated&&hits[hit].Coin.RawDamage==expected&&hits[hit].Damage==expected&&hits[hit].Snapshot.Enemies[0].Hp==1000-hits.Take(hit+1).Sum(e=>e.Damage),"other Touhou attacks accumulate heads and update HP: "+key+" mask="+mask+" hit="+hit+" expected="+expected+" actual="+hits[hit].Coin.RawDamage);
                    }
                }
            }

            b=new Heads();Quiet(b);b.Assign("yin_yang_orb",2,3);events=b.Resolve();Check(events.Where(e=>e.Type=="strike").Select(e=>e.Damage).SequenceEqual(new[]{6,9})&&b.State.Enemies[1].Exorcism==1,"orb heads accumulate to six/nine; one mark limit");b.NextRound();
            for(int i=0;i<2;i++){Quiet(b);b.Assign("fantasy_seal",2,0);events=b.Resolve();Check(events.Where(e=>e.Type=="strike").Select(e=>e.Damage).SequenceEqual(new[]{4,7,10,13,16}),"Fantasy Seal five heads accumulate without changing the five-coin budget");Check(b.State.Enemies[0].Exorcism==(i==0?2:0),"seal mark cap two and reset on four");b.NextRound();}
            Check(b.State.Enemies[0].ExorcismActive&&b.State.Enemies[1].Exorcism==1,"detonation next round; marks separate by enemy");Quiet(b,0,2);events=b.Resolve();
            Check(events.Where(e=>e.Type=="strike").All(e=>e.Coin.RawDamage==3&&e.Damage==1),"exorcism halves post-raw enemy damage without changing dice formula");
            b=new Heads();Quiet(b,0,2);b.State.Enemies[0].GensokyoNative=true;b.Assign("yin_yang_orb",2,0);Check(b.Resolve().First(e=>e.Type=="clash").Coin.LeftBase==4,"Reimu gains one only for marked native target");
            b=new Heads();Quiet(b);Check(!b.Assign("demon_seal",2,3)&&!b.Assign("fantasy_nature",2,0),"required-clash skills reject absent opposing actions");Quiet(b,3,2);Check(b.Assign("demon_seal",2,3),"targeted guard uses defense slot and enemy target");events=b.Resolve();
            Check(events.Count(e=>e.Type=="strike")==1&&events.First(e=>e.Type=="strike").Damage==0&&!events.Any(e=>e.Type=="guard")&&b.State.Enemies.All(e=>e.SealPending),"Demon Seal has no hit or shield; marks target and nearest living left");b.NextRound();
            Check(b.State.Enemies.All(e=>e.SealActive),"seal activates next round");Quiet(b,0,0);b.Assign("marisa_stars",0,0);Check(b.Resolve().First(e=>e.Type=="clash").Coin.RightBase==1,"seal reduces current clash base by two");b.NextRound();Check(b.State.Enemies.All(e=>!e.SealActive),"seal expires after one round");
            b=new Heads();Quiet(b,0,2);b.Assign("fantasy_nature",2,0);events=b.Resolve();Check(b.State.Heroes[2].RoleState.DreamDue==4&&b.State.Heroes[2].RoleState.DreamOrbs==1&&events.Where(e=>e.Type=="strike").All(e=>e.Damage==0),"dream arms for third subsequent round without direct damage");b.NextRound();
            Quiet(b,0,2);Check(!b.Assign("fantasy_nature",2,0)&&b.Assign("yin_yang_orb",2,0),"cannot recast while charging");b.Resolve();b.NextRound();Quiet(b,3,2);b.Assign("fantasy_seal",2,3);b.Resolve();b.NextRound();
            Check(b.State.Heroes[2].RoleState.DreamOrbs==3&&b.State.Enemies[0].Exorcism==1&&b.State.Enemies[1].Exorcism==2,"final clash wins charge to three and preserve separate marks");Quiet(b);events=b.Resolve();
            Check(events.Where(e=>e.Type=="status_damage").Select(e=>e.Damage).SequenceEqual(new[]{15,30})&&!events.Any(e=>e.Type=="strike")&&b.State.Heroes[2].Hp==0,"dream is status settlement, not an extra attack, then Reimu leaves");
            b=new Heads();Quiet(b,0,2);b.Assign("fantasy_nature",2,0);b.Resolve();b.NextRound();Quiet(b,0,2);b.State.Heroes[2].Hp=1;b.Resolve();Check(b.State.Heroes[2].Hp==0&&b.State.Heroes[2].RoleState.DreamDue==0,"Reimu death cancels pending dream");
            b=new Heads();var snap=b.Snapshot();snap.Heroes[1].RoleState.WorldUsed=true;snap.Heroes[2].RoleState.DreamDue=99;Check(!b.State.Heroes[1].RoleState.WorldUsed&&b.State.Heroes[2].RoleState.DreamDue==0,"role snapshots deeply isolated");
            var normal=new PortBattleRules();Check(!normal.State.TouhouTeam&&normal.State.Hand.Length==16&&normal.State.Heroes[1].Hp==42&&normal.State.Heroes[2].Hp==46,"original roster and forest party stay unchanged");
            for(uint seed=1;seed<=20;seed++)
            {
                var first=new PortBattleRules(seed,0,true);var second=new PortBattleRules(seed,0,true);first.Assign("murder_doll",1,0);second.Assign("murder_doll",1,0);first.Assign("yin_yang_orb",2,3);second.Assign("yin_yang_orb",2,3);
                var e1=first.Resolve();var e2=second.Resolve();Check(first.State.Fingerprint()==second.State.Fingerprint()&&string.Join("|",e1.Select(e=>e.Message).ToArray())==string.Join("|",e2.Select(e=>e.Message).ToArray()),"role effects retain deterministic seeded RNG");
                Check(e1.Where(e=>e.Coin!=null&&e.Type=="strike").All(e=>e.Coin.AttackIndex+e.Coin.RemainingAttackCoins==e.Coin.AttackBudget),"role attack budgets remain conserved");
            }
            return checks;
        }
    }
}
