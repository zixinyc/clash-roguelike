using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        enum TeamMode { Normal, Pvp, Demo }
        bool teamSetup,teamInitial;
        TeamMode teamMode;
        string[] activeTeam,activeRivalTeam;
        readonly List<string>[] teamDraft={new List<string>(),new List<string>()};
        int teamSeat;
        string teamFocus="marisa";
        Vector2 teamDetailScroll,teamCatalogScroll;

        bool TeamUnlocked(string key)
        {return !trialSkipSave&&PlayerPrefs.GetInt(key,0)==1;}

        bool TeamAvailable(string id)
        {return CharacterRoster.Available(id,teamMode==TeamMode.Normal,TeamUnlocked(TrialRecruitKey),TeamUnlocked(TrialFlandreKey),TeamUnlocked(TrialRemiliaKey),TeamUnlocked(TrialPatchouliKey));}

        void ConfigureAdventureParty(ExpeditionResources party)
        {
            if(activeTeam==null)party.ConfigureRoster(selectedRoster);
            else party.ConfigureTeam(activeTeam);
        }

        string ActiveTeamName()
        {
            if(!forest.Party.HasComposition)return MainRosterName(forest.Party.Roster);
            return string.Join(" / ",forest.Party.Members().Where(u=>u.MaxHp>0).Select(u=>u.Name).ToArray());
        }

        void OpenTeamSetup(TeamMode mode,bool initial)
        {
            teamSetup=true;
            teamInitial=initial;
            SelectTeamMode(mode);
        }

        void CloseTeamSetup(){if(!teamInitial)teamSetup=false;}

        void SelectTeamMode(TeamMode mode)
        {
            teamMode=mode;
            teamSeat=0;
            teamDetailScroll=Vector2.zero;
            teamCatalogScroll=Vector2.zero;
            var current=activeTeam??CharacterRoster.Team(selectedRoster).Select(u=>u.CharacterId).ToArray();
            var rival=activeRivalTeam??CharacterRoster.Team(2).Select(u=>u.CharacterId).ToArray();
            for(int i=0;i<2;i++)
            {
                var draft=teamDraft[i];
                draft.Clear();
                draft.AddRange((i==0?current:rival).Where(TeamAvailable));
                if(draft.Count==0)draft.AddRange(new[]{"marisa","reimu"});
            }
            teamFocus=teamDraft[0][0];
        }

        bool AddTeamMember(string id)
        {
            var draft=teamDraft[teamSeat];
            if(!TeamAvailable(id)||draft.Count>=CharacterRoster.Capacity||draft.Contains(id))return false;
            draft.Add(id);
            return true;
        }

        bool ReadyToStart()
        {return teamDraft[0].Count>0&&(teamMode!=TeamMode.Pvp||teamDraft[1].Count>0);}

        void ConfirmTeamSetup()
        {
            if(!ReadyToStart())return;
            activeTeam=teamDraft[0].ToArray();
            activeRivalTeam=teamMode==TeamMode.Pvp?teamDraft[1].ToArray():null;
            teamSetup=false;
            forestSettings=false;
            if(teamMode==TeamMode.Demo)
            {
                forestTrialMode=false;
                forestPvpMode=false;
                InitializeAdventure();
            }
            else StartTrial(teamMode==TeamMode.Pvp);
        }

        static string TeamPassive(string id)
        {
            switch(id)
            {
                case "marisa":return "火花最多10层，超过5层时强化攻击技能。极限火花消耗全部火花。费用不足时，每3生命可换1点敌方未预留 cost。与灵梦等特定队友同队时，最终拼点−2，每个攻击技能对每名目标增伤5。";
                case "reimu":return "对幻想乡本土敌人的拼点初始点数+1。符卡命中可叠加退治，4层引爆，使该敌人下回合拼点−3、伤害减半。梦想天生蓄力期间可累积到6层。";
                case "sakuya":return "可以无视速度限制接招，按领先速度获得最多3点拼点加成。银色小刀在前两回合额外+5伤害，第3回合+2。时停由符卡发动。";
                case "flandre":return "四重存在抵挡致命伤，回合末回满并加1层，达到4层永久退场。被她击杀的敌人成为人偶，每名让她本场最终拼点+1，最多+3。常规治疗减半。";
                case PatchouliSkills.Id:return "知识和避世的少女：来袭点数不超过5时闪避。元素之石：主副手各提供属性增益。姆Q：每枚攻击硬币使自身失去2 HP。";
                case RemiliaSkills.Id:return "永远鲜红的幼月：按实际伤害吸血并增加绯红之主。最有威严之人：每局一次，消耗10 cost免于致命伤。昆古尼尔：每回合锁定一敌，拼点触发伤害翻倍与过热。";
                case "zixi":return "拼点获胜积累超形上学，强化一次专属行动消耗3层。强化结算增加因果，因果可提高拼点。部分符卡效果跨回合保留。";
                case "ash":return "拼点获胜或使用观察后获得准备。捕捉破绽消耗准备，使拼点初始点数+4。";
                case "breaker":return "使用费用至少3的技能拼点时，初始点数+2。该次拼点失败时额外损失2生命。";
                default:return "防御行动为其他存活队友提供护盾。援护量随使用的技能变化。";
            }
        }

        void DrawTeamSetup()
        {
            Fill(new Rect(0,0,1440,900),Hex("210B11"));
            Fill(new Rect(0,0,1440,115),Hex("4B1C28"));
            Label(35,19,400,46,"出征编队",31,Gold);
            Label(37,66,405,31,"选择 1–3 名不同角色 · 名单顺序即出战顺序",14,Muted);
            if(Btn(new Rect(461,29,277,42),"普通探索",teamMode==TeamMode.Normal)&&teamMode!=TeamMode.Normal)SelectTeamMode(TeamMode.Normal);
            if(Btn(new Rect(753,29,277,42),"PVP 人机试玩",teamMode==TeamMode.Pvp)&&teamMode!=TeamMode.Pvp)SelectTeamMode(TeamMode.Pvp);
            if(Btn(new Rect(1045,29,350,42),"自由演练",teamMode==TeamMode.Demo)&&teamMode!=TeamMode.Demo)SelectTeamMode(TeamMode.Demo);
            if(teamMode==TeamMode.Pvp)
            {
                for(int i=0;i<2;i++)
                    if(Btn(new Rect(460+i*142,78,135,28),i==0?"我的队伍":"人机对手",teamSeat==i)){teamSeat=i;teamDetailScroll=Vector2.zero;}
                if(Btn(new Rect(754,78,278,28),"地图 · "+(trialTimeIndex==0?"不限时":trialTimeOptions[trialTimeIndex]+" 秒")))trialTimeIndex=(trialTimeIndex+1)%trialTimeOptions.Length;
                if(Btn(new Rect(1045,78,350,28),"选技 · "+trialSkillSeconds+" 秒"))trialSkillSeconds=trialSkillSeconds==20?30:20;
            }
            else Label(463,77,930,26,teamMode==TeamMode.Normal?"初始开放灵梦和魔理沙。其他东方角色通过红魔馆挑战解锁。":"全部角色可用，适合测试跨队混编与战斗。",14,Muted);

            DrawTeamCatalog();
            DrawTeamDetail();
            DrawTeamSlots();
        }

        void DrawTeamCatalog()
        {
            Panel(new Rect(35,129,444,596),Hex("351720"),Hex("723947"));
            Label(52,144,411,37,"角色名册",20,Cyan);
            var draft=teamDraft[teamSeat];
            var ids=teamMode==TeamMode.Normal?CharacterRoster.Ids.TakeWhile(id=>id!="zixi").ToArray():CharacterRoster.Ids;
            teamCatalogScroll=GUI.BeginScrollView(new Rect(50,190,416,520),teamCatalogScroll,new Rect(0,0,393,ids.Length*64));
            for(int i=0;i<ids.Length;i++)
            {
                string id=ids[i];
                var unit=CharacterRoster.Create(id);
                bool available=TeamAvailable(id);
                int slot=draft.IndexOf(id);
                float y=64*i;
                string status=!available?"未招募":slot>=0?"位置 "+(slot+1):"可加入";
                if(Btn(new Rect(1,y,392,53),"",teamFocus==id))
                {teamFocus=id;teamDetailScroll=Vector2.zero;}
                DrawCharacterPortrait(unit,new Rect(8,y+3,43,47));
                Label(61,y+2,230,48,unit.Name,17,available?Pale:Muted);
                Label(291,y+2,90,48,status,14,slot>=0?Gold:Muted,TextAnchor.MiddleRight);
            }
            GUI.EndScrollView();
        }

        void DrawTeamDetail()
        {
            var unit=CharacterRoster.Create(teamFocus);
            var draft=teamDraft[teamSeat];
            var skills=CharacterRoster.Skills(teamFocus);
            if(teamFocus==PatchouliSkills.Id)
                skills=skills.Concat(Enumerable.Range(1,5).Select(i=>PatchouliSkills.Variant((ElementStone)i,ElementStone.None))).ToArray();
            Panel(new Rect(496,129,899,596),Hex("351720"),Hex("723947"));
            Panel(new Rect(516,150,263,552),Hex("281219"),Hex("6D3541"));
            if(!DrawCharacterPortrait(unit,new Rect(526,167,243,477)))
                Label(536,271,223,98,unit.Name+"\n暂无立绘",20,Muted,TextAnchor.MiddleCenter);
            Label(524,645,247,46,"HP "+unit.MaxHp+"   速度 "+unit.MinSpeed+"–"+unit.MaxSpeed,17,Gold,TextAnchor.MiddleCenter);
            Label(801,146,573,44,unit.Name,25,Gold);
            Label(802,196,573,24,"被动",16,Cyan);
            Label(802,225,572,73,TeamPassive(teamFocus),15,Pale,TextAnchor.UpperLeft);
            if(teamMode==TeamMode.Pvp)
                Label(801,291,573,41,"对战进入后为己方角色挑选专属牌，通用牌始终可用。",13,Muted,TextAnchor.UpperLeft);

            Label(802,334,573,26,"专属技能",16,Cyan);
            var trial=CampaignDuel.SupportedExclusive(teamFocus);
            teamDetailScroll=GUI.BeginScrollView(new Rect(801,365,574,280),teamDetailScroll,new Rect(0,0,551,skills.Length*64));
            for(int i=0;i<skills.Length;i++)
            {
                var card=PortContent.Card(skills[i]);float y=i*64;
                Fill(new Rect(0,y,549,60),Hex("48202A"));
                string badge=teamMode==TeamMode.Pvp&&trial.Contains(PatchouliSkills.LoadoutKey(card.Id))?" · 对战":"";
                Label(10,y+1,524,22,card.Name+" · "+card.Cost+" cost"+badge,15,Gold);
                Label(10,y+24,525,34,card.Description,13,Pale,TextAnchor.UpperLeft);
            }
            GUI.EndScrollView();

            bool assigned=draft.Contains(teamFocus);
            GUI.enabled=TeamAvailable(teamFocus)&&(assigned||draft.Count<CharacterRoster.Capacity);
            string label=!TeamAvailable(teamFocus)?"红魔馆挑战胜利后解锁":assigned?"从队伍移除":draft.Count==3?"三个位置已满":"加入队伍";
            if(Btn(new Rect(801,655,574,45),label,!assigned))
            {if(assigned)draft.Remove(teamFocus);else AddTeamMember(teamFocus);}
            GUI.enabled=true;
        }

        void DrawTeamSlots()
        {
            var draft=teamDraft[teamSeat];
            Label(36,730,1010,27,(teamMode==TeamMode.Pvp?(teamSeat==0?"我的队伍 · ":"人机对手 · "):"")+"出战名单 "+draft.Count+"/3",17,Cyan);
            for(int i=0;i<CharacterRoster.Capacity;i++)
            {
                float x=35+i*342;bool filled=i<draft.Count;
                Panel(new Rect(x,764,328,53),Hex("391820"),filled?Gold:Hex("723947"));
                Label(x+12,765,187,50,(i+1)+"  "+(filled?CharacterRoster.Create(draft[i]).Name:"空位"),16,filled?Pale:Muted);
                if(filled&&i>0&&Btn(new Rect(x+198,771,43,37),"左移"))
                {
                    var moved=draft[i];draft[i]=draft[i-1];draft[i-1]=moved;
                }
                if(filled&&Btn(new Rect(x+250,771,66,37),"移除")){draft.RemoveAt(i);break;}
            }
            if(!teamInitial&&Btn(new Rect(35,834,235,38),"取消 · 返回"))CloseTeamSetup();
            if(!teamInitial)Label(289,837,742,33,"确认后开始新一局，当前探索会结束。",14,Muted);
            GUI.enabled=ReadyToStart();
            if(Btn(new Rect(1073,764,322,53),teamMode==TeamMode.Pvp?"确认双方队伍 · 开始":"确认队伍 · 开始",true))ConfirmTeamSetup();
            GUI.enabled=true;
        }

        void FillCustomPlans()
        {
            var state=portRules.State;
            for(int actor=0;actor<state.Heroes.Count;actor++)
            {
                if(!FlandreSkills.MemberCanAct(state.Heroes[actor]))continue;
                var cards=state.Hand.Select(key=>PortContent.Card(PatchouliSkills.EquippedKey(state.Heroes[actor],key))).Where(c=>state.Owns(actor,c))
                    .OrderByDescending(c=>c.TargetsEnemy).ThenBy(c=>c.Cost)
                    .Concat(new[]{PortContent.Card("probe"),PortContent.Card("guard")});
                foreach(var card in cards)
                {
                    if(!state.WorldActive&&state.HeroSlots.Any(s=>s.Unit==actor&&s.Active))break;
                    int slot=portRules.SlotFor(actor,card.Id);
                    if(state.HeroSlots[slot].Active)continue;
                    if(!card.TargetsEnemy){portRules.Assign(card.Id,actor,-1,slot);continue;}
                    var targets=state.EnemySlots.OrderByDescending(e=>portRules.CanClash(state.HeroSlots[slot],e)&&portRules.PairFor(e.Id)<0);
                    foreach(var target in targets)
                        if(portRules.Assign(card.Id,actor,target.Id,slot))break;
                }
            }
            portShown=portRules.Snapshot();
        }

        IEnumerator TeamSetupSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            while(!UnityEngine.Rendering.SplashScreen.isFinished)yield return null;
            yield return null;yield return null;
            trialSkipSave=true;
            OpenTeamSetup(TeamMode.Normal,true);
            SmokeCheck(teamDraft[0].SequenceEqual(new[]{"marisa","reimu"})&&!AddTeamMember("flandre"),"new ordinary profile starts with two characters");
            yield return Capture(folder,"team-normal");
            SelectTeamMode(TeamMode.Demo);
            teamDraft[0].Clear();
            SmokeCheck(!ReadyToStart()&&AddTeamMember("flandre")&&AddTeamMember("zixi")&&AddTeamMember("sakuya")&&!AddTeamMember("flandre"),"distinct mixed team");
            teamFocus="flandre";
            yield return Capture(folder,"team-mixed");
            ConfirmTeamSetup();
            SmokeCheck(forest.Party.Members().Select(u=>u.CharacterId).SequenceEqual(new[]{"flandre","zixi","sakuya"}),"setup creates the actual exploration party");
            var combat=forest.Party.CreateBattle(0);
            SmokeCheck(combat.State.Owns(0,PortContent.Card(FlandreSkills.Charge))&&combat.State.Owns(1,PortContent.Card("zixi_central_limit"))&&combat.State.Owns(2,PortContent.Card("the_world")),"mixed character cards follow their owners");
            SmokeCheck(combat.Assign(FlandreSkills.Charge,0,-1)&&combat.Assign("the_world",2,0),"actual character actions can both be assigned");
            combat.Resolve();combat.NextRound();
            SmokeCheck(combat.State.Heroes[0].Flandre.ChargeTurn==1&&combat.State.Hand.Contains(FlandreSkills.Release),"Flandre charge state survives changed position");
            SmokeCheck(combat.State.WorldActive&&combat.State.HeroSlots.Where(s=>s.Flexible).All(s=>s.Unit==2)&&combat.State.HeroSlots.Count(s=>s.Flexible)==3,"World opens slots for Sakuya in position three");
            var support=new PortBattleRules(73129,0,CharacterRoster.Compose(new[]{"support","ash","reimu"}));
            SmokeCheck(support.Assign("light_guard",0,-1),"support skill follows its character");
            SmokeCheck(support.Resolve().Any(e=>e.Hero==0&&e.Snapshot.Heroes[1].Shield>0&&e.Snapshot.Heroes[2].Shield>0&&e.Message.StartsWith("织火 · 援护")),"moved support shields the other two positions");
            OpenTeamSetup(TeamMode.Pvp,false);
            teamDraft[0].Clear();AddTeamMember("zixi");
            teamSeat=1;teamDraft[1].Clear();AddTeamMember("reimu");AddTeamMember("flandre");
            teamFocus="reimu";
            Screen.SetResolution(1000,650,false);yield return null;yield return null;
            yield return Capture(folder,"team-pvp-small");
            ConfirmTeamSetup();
            SmokeCheck(forestCampaign.Pvp&&forestCampaign.Players[0].Party.Hp.SequenceEqual(new[]{50,0,0})&&forestCampaign.Players[1].Party.Hp.SequenceEqual(new[]{50,20,0}),"PVP starts each player's distinct selected composition");
            var solo=forest.Party.CreateBattle(0);
            SmokeCheck(solo.State.EnemySlots.Where(e=>e.Active&&e.Category!=2).All(e=>e.Target==0),"solo party never targeted in an empty slot");
            File.WriteAllText(Path.Combine(folder,"team-setup-smoke.txt"),"TEAM_SETUP_SMOKE_PASSED\nOrdinary profile lock, mixed loadout, Sakuya in third position, Flandre in first position and separately composed local PvP parties.");
            Application.Quit(0);
        }
    }
}
