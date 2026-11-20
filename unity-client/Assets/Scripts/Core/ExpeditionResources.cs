using System;
using System.Linq;
namespace ClashRoguelike
{
    // Shared by the retained grid and the new node map; original values and battle rules unchanged.
    public sealed class ExpeditionResources
    {
        public int Cost=30;public int Roster;
        string[] composition;
        bool remiliaSaved;
        public bool HasComposition {get{return composition!=null;}}
        public Unit[] Members(){return composition==null?CharacterRoster.Team(Roster):composition.Select(CharacterRoster.Create).ToArray();}
        public int FlandreIndex {get{return HasComposition?Array.IndexOf(composition,"flandre"):Roster==3?1:-1;}}
        public void ConfigureTeam(string[] ids)
        {
            var members=CharacterRoster.Compose(ids);
            composition=members.Select(u=>u.CharacterId).ToArray();
            for(int i=0;i<members.Length;i++){Hp[i]=members[i].Hp;MaxHp[i]=members[i].MaxHp;}
        }
        public bool AddRecruited(string id)
        {
            int slot=Array.IndexOf(composition,"");
            if(slot<0||composition.Contains(id))return false;
            var unit=CharacterRoster.Create(id);
            composition[slot]=id;Hp[slot]=unit.Hp;MaxHp[slot]=unit.MaxHp;return true;
        }
        public void ConfigureRoster(int roster){composition=null;Roster=roster;var team=CharacterRoster.Team(roster);for(int i=0;i<3;i++){Hp[i]=team[i].Hp;MaxHp[i]=team[i].MaxHp;}}
        public int[] Hp={48,42,46};
        public readonly int[] MaxHp={48,42,46};
        FlandreState flandreProgress=new FlandreState();
        public FlandreState FlandreProgress {get{return flandreProgress;}}
        int savedSakuyaHp=40,savedFlandreHp=20,savedFlandreMax=20;
        public void SuspendSakuya(){if(Roster==1){Hp[1]=0;MaxHp[1]=0;}}
        public void UnlockSakuya(){savedSakuyaHp=40;if(Roster==1){Hp[1]=40;MaxHp[1]=40;}}
        public void SelectCompanion(bool flandre)
        {
            if(flandre&&Roster==1)
            {
                if(MaxHp[1]>0)savedSakuyaHp=Hp[1];
                Roster=3;Hp[1]=savedFlandreHp;MaxHp[1]=savedFlandreMax;
            }
            else if(!flandre&&Roster==3)
            {
                savedFlandreHp=Hp[1];savedFlandreMax=MaxHp[1];
                Roster=1;Hp[1]=savedSakuyaHp;MaxHp[1]=40;
            }
        }
        Unit EnteringFlandre(int slot)
        {
            var unit=FlandreSkills.Create();unit.Flandre=FlandreProgress.NextEncounter();
            unit.Hp=Hp[slot];unit.MaxHp=MaxHp[slot];return unit;
        }
        Unit[] EnteringTeam()
        {
            var units=Members();
            int flandre=FlandreIndex;
            if(flandre>=0)units[flandre]=EnteringFlandre(flandre);
            for(int i=0;i<units.Length;i++)
            {
                units[i].Hp=Hp[i];units[i].MaxHp=MaxHp[i];
                if(units[i].Remilia!=null)units[i].Remilia.SavedFromDefeat=remiliaSaved;
            }
            return units;
        }
        public TrialDuelSide TrialSide(BattleModifier modifier=null)
        {
            return new TrialDuelSide(EnteringTeam(),Cost,modifier);
        }
        public void ApplyTrialSide(TrialDuelSide side){Cost=side.Cost;ApplyMembers(side.Units);}
        public void ApplyMembers(System.Collections.Generic.IEnumerable<Unit> members)
        {
            var units=members.Where(u=>!PatchouliSkills.IsSummon(u)).ToArray();
            var remilia=units.FirstOrDefault(u=>u.Remilia!=null);
            if(remilia!=null)remiliaSaved=remilia.Remilia.SavedFromDefeat;
            int flandre=FlandreIndex;
            if(flandre>=0)
            {
                var member=units[flandre];FlandreSkills.EndRound(member,(message,music)=>{});
                flandreProgress=member.Flandre.NextEncounter();
                MaxHp[flandre]=member.MaxHp;
                if(member.Puppet&&FlandreProgress.Retired)member.Hp=0;
            }
            Hp=units.Select(u=>u.Hp).ToArray();
        }
        public void Heal(int amount){for(int i=0;i<3;i++)if(Hp[i]>0)Hp[i]=Math.Min(MaxHp[i],Hp[i]+(i==FlandreIndex?amount/2:amount));}
        public void RestoreTeam()
        {
            for(int i=0;i<Hp.Length;i++)
            {
                if(i!=FlandreIndex)Hp[i]=MaxHp[i];
                else if(!FlandreProgress.Retired&&Hp[i]>0)Hp[i]+=(MaxHp[i]-Hp[i])/2;
            }
        }
        public bool ApplyChoice(string kind,int choice)
        {
            if(choice<0||choice>1)return false;
            if(kind=="shop"){if(choice!=0||Cost<6)return false;Cost-=6;Heal(8);}
            else if(kind=="camp"){if(choice==0)Heal(10);else Cost+=5;}
            else if(kind=="event"){if(choice==0)Cost+=5;else{for(int i=0;i<3;i++)if(Hp[i]>0)Hp[i]=Math.Max(1,Hp[i]-4);Cost+=12;}}
            else return false;return true;
        }
        public PortBattleRules CreateBattle(int encounter,uint seed=73129)
        {
            PortBattleRules b;
            if(HasComposition)
            {
                b=new PortBattleRules(seed,encounter,EnteringTeam());
            }
            else
            {
                b=new PortBattleRules(seed,encounter,Roster==1||Roster==3,Roster==2);
                if(Roster==3)b.ConfigureFlandre(EnteringFlandre(1));
            }
            b.State.Cost=Cost;for(int i=0;i<3;i++)b.State.Heroes[i].Hp=Hp[i];
            if(!HasComposition&&Roster==1&&MaxHp[1]==0)
            {
                b.State.RecruitLockedSakuya=true;
                b.State.Hand=b.State.Hand.Where(k=>!TouhouRoles.SakuyaCards.Contains(k)).ToArray();
            }
            foreach(var s in b.State.EnemySlots)if(s.Active&&s.Category!=2&&(s.Target<0||Hp[s.Target]<=0))s.Target=Array.FindIndex(Hp,h=>h>0);return b;
        }
        public void ApplyBattleResult(PortState state,int encounter)
        {Cost=state.Cost;ApplyMembers(state.Heroes);if(state.Outcome=="victory")Cost+=encounter==1?8:4;}
    }
}
