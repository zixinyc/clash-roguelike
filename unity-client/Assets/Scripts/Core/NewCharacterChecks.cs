using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class NewCharacterChecks
    {
        static int checks;static void Check(bool yes,string why){checks++;if(!yes)throw new Exception("New characters: "+why);}
        sealed class Heads:PortBattleRules{public Heads(bool zixi=false):base(73129,0,!zixi,zixi){}protected override bool FlipCoin(double p){return p>.5;}}
        sealed class Tails:PortBattleRules{public Tails(bool zixi=false):base(73129,0,!zixi,zixi){}protected override bool FlipCoin(double p){return p<=.5;}}
        static void Quiet(PortBattleRules b,int active=-1,int target=0)
        {foreach(var e in b.State.Enemies){e.Hp=1000;e.MaxHp=1000;}foreach(var s in b.State.EnemySlots){s.Active=s.Id==active;if(s.Active){s.Key="needle";s.Target=target;}}}
        public static int Run()
        {
            checks=0;var m=new Heads();Check(m.State.Heroes.Select(x=>x.Name).SequenceEqual(new[]{"雾雨魔理沙","十六夜咲夜","博丽灵梦"}),"actual Oriental roster");
            Check(m.State.Hand.Length==24&&TouhouRoles.MarisaCards.All(m.State.Hand.Contains)&&!m.State.Hand.Contains("probe"),"Marisa exclusive hand replaces Ash only in Oriental team");
            Quiet(m);m.Assign("marisa_stars",0,0);Check(m.Resolve().Where(x=>x.Type=="strike").Sum(x=>x.Damage)==13&&m.State.Heroes[0].RoleState.Spark==0,"solo stars damage and clash-only charge");
            m=new Heads();Quiet(m,0,0);m.Assign("marisa_stars",0,0);var ev=m.Resolve();Check(ev.First(x=>x.Type=="clash").Left==6&&m.State.Heroes[0].RoleState.Spark==1,"team penalty, native coin values, win reward");
            m=new Heads();Quiet(m,0,0);m.Assign("marisa_laser",0,0);ev=m.Resolve();Check(m.State.Heroes[0].RoleState.Spark==2&&ev.Where(x=>x.Type=="strike"&&x.AttackerAllied).Sum(x=>x.Damage)==24,"laser two-target hits and unique charge");
            m=new Heads();Quiet(m);m.Assign("marisa_orrery",0,-1);m.Resolve();Check(m.State.Heroes[0].RoleState.Spark==1&&m.State.Heroes[0].Shield==0,"orrery is reduction, not shield");m.NextRound();Quiet(m,0,0);ev=m.Resolve();Check(m.State.Heroes[0].Hp==45,"orrery blocks weak coin hits");
            m=new Heads();Quiet(m);
            for(int i=2;i<5;i++)m.State.Enemies.Add(m.State.Enemies[0].Copy());
            m.State.Enemies[1].Shield=4;
            m.State.Enemies[4].Shield=50;
            m.State.Heroes[0].RoleState.Spark=3;
            m.Assign("marisa_spark",0,0);
            var blast=m.Resolve().Single(x=>x.Type=="strike");
            Check(m.State.Heroes[0].RoleState.Spark==0&&blast.Coin.AttackBudget==1&&
                blast.Hits.Select(x=>x.Target).SequenceEqual(Enumerable.Range(0,5))&&
                blast.Hits.Select(x=>x.Damage).SequenceEqual(new[]{35,31,35,35,0})&&
                blast.Snapshot.Enemies.Select(x=>x.Hp).SequenceEqual(new[]{965,969,965,965,1000}),
                "one Spark event settles five enemies together with separate shields");

            m=new Heads();Quiet(m);
            m.State.Enemies[0].Hp=1;
            m.State.Heroes[0].RoleState.Spark=3;
            m.State.HeroSlots[6].Speed=20;
            m.Assign("yin_yang_orb",2,0);
            m.Assign("marisa_spark",0,0);
            blast=m.Resolve().Single(x=>x.Hits!=null);
            Check(blast.Hits.Length==1&&blast.Hits[0].Target==1&&blast.Snapshot.Enemies[1].Hp==965,
                "full-team attacks still hit remaining enemies if the clash target is defeated first");
            m=new Heads();Quiet(m);m.State.Cost=0;Check(m.Assign("marisa_stars",0,0)&&m.State.Heroes[0].Hp==45,"blood theft only reserved");m.Cancel(0);Check(m.State.Heroes[0].Hp==45,"cancel does not charge HP");m.Assign("marisa_stars",0,0);m.Resolve();Check(m.State.Heroes[0].Hp==39&&m.State.EnemyCost==28,"three HP for one enemy cost");
            m=new Heads();Quiet(m);m.State.Cost=0;m.State.Heroes[0].Hp=6;Check(!m.Assign("marisa_stars",0,0),"theft cannot kill");
            foreach(int sparks in new[]{4,5})
            {
                m=new Heads();Quiet(m);m.State.Heroes[0].RoleState.Spark=sparks;
                foreach(var enemy in m.State.Enemies)enemy.Shield=20;
                Check(m.Assign("marisa_spark",0,0),"spark can be assigned against shielded enemies");
                var hits=m.Resolve().Where(x=>x.Type=="strike").ToArray();
                Check(hits.Length==1&&hits[0].Hits.Length==2&&hits[0].Hits.All(x=>x.Damage==(sparks==4?25:55))&&m.State.Enemies.All(x=>x.Shield==(sparks==4?0:20)),"spark ignores shield only at five or more layers");
            }
            var b=new Heads(true);Check(b.State.ZixiTeam&&!b.State.TouhouTeam&&b.State.Heroes[1].Name=="ZiXi"&&b.State.Heroes[1].Hp==50,"independent ZiXi roster");Check(b.State.Hand.Length==17&&ZixiRole.Keys.All(b.State.Hand.Contains)&&!b.State.Hand.Contains("murder_doll"),"independent ownership and four ZiXi cards");
            Quiet(b);Check(!b.Assign("zixi_central_limit",1,0),"ZiXi spells require opposing action");Quiet(b,0,1);Check(b.Assign("zixi_central_limit",1,0),"ZiXi can answer target action");ev=b.Resolve();Check(ev.First(x=>x.Type=="clash").Left==15,"ZiXi clash base 11 is distinct from attack base 3");Check(ev.Where(x=>x.Type=="strike").Sum(x=>x.Damage)==12,"central limit heads 5 then 7 cumulative hits");Check(b.State.Heroes[1].Zixi.Metaphysics==2&&b.State.Heroes[1].Zixi.NextClash["zixi_central_limit"]==1,"margin reward and next-clash status");b.NextRound();Quiet(b,0,1);b.Assign("zixi_central_limit",1,0);ev=b.Resolve();Check(ev.First(x=>x.Type=="clash").Left==16,"next-clash consumed exactly once");
            b=new Heads(true);Quiet(b,0,1);b.State.Heroes[1].Zixi.Metaphysics=3;b.Assign("zixi_central_limit",1,0);Check(b.ToggleZixiEnhancement(3)&&b.State.Heroes[1].Zixi.Metaphysics==0,"enhancement reserves three layers");Check(b.Cancel(3)&&b.State.Heroes[1].Zixi.Metaphysics==3,"cancel restores layers");b.Assign("zixi_central_limit",1,0);b.ToggleZixiEnhancement(3);ev=b.Resolve();Check(ev.First(x=>x.Type=="clash").Left==17&&ev.Where(x=>x.Type=="strike").Sum(x=>x.Damage)==20,"enhanced central clash +2 and attack +4");Check(b.State.Heroes[1].Zixi.Causality==1,"enhancement increases causality");
            var tails=new Tails(true);Quiet(tails,0,1);tails.State.Heroes[1].Zixi.Metaphysics=3;tails.Assign("zixi_convergence",1,0);tails.ToggleZixiEnhancement(3);ev=tails.Resolve();Check(ev.First(x=>x.Type=="clash").Coin.LeftFaces.Count(x=>x)==1&&ev.Where(x=>x.Type=="clash").Skip(1).All(x=>x.Coin.LeftFaces.All(h=>!h)),"first tail converted once for whole skill");Check(ev.Where(x=>x.Type=="strike").All(x=>!x.Coin.Heads)&&ev.Where(x=>x.Type=="strike").Sum(x=>x.Damage)==6,"converted clash head is not a natural attack head");
            b=new Heads(true);Quiet(b,0,1);b.State.Heroes[1].Zixi.Metaphysics=3;b.Assign("zixi_convergence",1,0);b.ToggleZixiEnhancement(3);ev=b.Resolve();Check(ev.Where(x=>x.Type=="strike").Select(x=>x.Damage).SequenceEqual(new[]{5,8,14}),"three natural attack heads add three only on final original coin");
            b=new Heads(true);Quiet(b,0,1);b.State.EnemySlots[3].Active=true;b.State.EnemySlots[3].Key="needle";b.State.EnemySlots[3].Target=1;b.State.EnemySlots[3].Speed=1;b.State.HeroSlots[5].Speed=20;b.Assign("zixi_martingale",1,0);b.Resolve();Check(b.State.Heroes[1].Shield==2&&b.State.Heroes[1].Hp==50,"carried shield absorbs damage with correct remaining bucket");b.NextRound();Check(b.State.Heroes[1].Shield==2,"only unspent carried shield restored");Quiet(b);b.Resolve();b.NextRound();Check(b.State.Heroes[1].Shield==0,"martingale shield expires after following round");
            tails=new Tails(true);Quiet(tails,0,1);tails.State.EnemySlots[0].Key="nova";tails.State.Enemies[0].Statuses.Add(new CoinStatus("audit clash",CoinStat.ClashCoinPower,1,1));tails.State.Heroes[1].Zixi.Metaphysics=3;tails.Assign("zixi_martingale",1,0);tails.ToggleZixiEnhancement(5);tails.Resolve();Check(tails.State.Heroes[1].Zixi.NextClash["zixi_martingale"]==3&&tails.State.Heroes[1].Zixi.Causality==1,"enhanced losing defense still grants next-clash status and causality");
            b=new Heads(true);Quiet(b,0,1);b.State.Heroes[1].Zixi.Metaphysics=3;b.State.Heroes[1].Zixi.Causality=2;b.Assign("zixi_almost_sure",1,0);b.ToggleZixiEnhancement(4);ev=b.Resolve();Check(ev.Single(x=>x.Type=="status_damage").Hits.Select(x=>x.Damage).SequenceEqual(new[]{21,21})&&!ev.Any(x=>x.Type=="strike"),"enhanced ultimate uses new causality and original budget as one blast");Check(b.State.Heroes[1].Zixi.Causality==0&&b.State.Heroes[1].Zixi.NoMarginRound==2,"ultimate consumes causality and disables next-round margin reward");int meta=b.State.Heroes[1].Zixi.Metaphysics;b.NextRound();Quiet(b,0,1);b.Assign("zixi_central_limit",1,0);b.Resolve();Check(b.State.Heroes[1].Zixi.Metaphysics==meta+1,"next-round reward capped to one despite wide margin");
            b=new Heads(true);Quiet(b,0,1);
            var z=b.State.Heroes[1].Zixi;
            z.RoundGain=2;z.Metaphysics=2;z.ShieldUntil[2]=4;
            Check(b.Assign("zixi_central_limit",1,0)&&!b.Assign("zixi_martingale",1,0),"ZiXi has one planned skill across categories");
            b.Resolve();Check(z.RoundGain==3&&z.Metaphysics==3,"round earning limit three");
            var snap=b.Snapshot();snap.Heroes[1].Zixi.NextClash.Clear();snap.Heroes[1].Zixi.ShieldUntil.Clear();
            Check(z.NextClash.Count>0&&z.ShieldUntil.Count>0,"snapshot deep copies ZiXi dictionaries");
            var party=new ExpeditionResources();party.ConfigureRoster(1);Check(party.CreateBattle(0).State.Heroes[0].Name=="雾雨魔理沙"&&party.MaxHp.SequenceEqual(new[]{45,40,50}),"formal forest carries Oriental roster");party.ConfigureRoster(2);Check(party.CreateBattle(0).State.Heroes[1].Name=="ZiXi"&&party.MaxHp.SequenceEqual(new[]{48,50,46}),"formal forest carries independent ZiXi roster");
            for(uint seed=1;seed<=30;seed++){var x=new PortBattleRules(seed,0,false,true);var y=new PortBattleRules(seed,0,false,true);x.Assign("zixi_central_limit",1,0);y.Assign("zixi_central_limit",1,0);x.Resolve();y.Resolve();Check(x.State.Fingerprint()==y.State.Fingerprint(),"new effects preserve seeded determinism");}
            return checks+FlandreChecks.Run();
        }
    }
}
