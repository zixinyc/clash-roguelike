using System;
using System.Collections.Generic;
using System.Linq;

namespace ClashRoguelike
{
    public enum ForestTheme { ScarletMansion, YoukaiMountain, BambooForest, EarthPalace, MagicForest }

    public sealed class ForestTrialOptions
    {
        public int TurnSeconds,PlanSeconds=20,TeamA=1,TeamB=2;
        public bool RecruitedSakuya,RecruitedFlandre,RecruitedRemilia,RecruitedPatchouli;
        public string[] CompositionA,CompositionB;
    }

    public sealed partial class ForestCampaign
    {
        public ForestTrialOptions Trial {get;private set;}
        public ForestTheme[] Themes {get;private set;}
        public CampaignDuel Duel {get;private set;}
        public double TurnTimeLeft {get;private set;}
        public bool RecruitLost {get;private set;}
        public string RecruitNode {get;private set;}
        public string FlandreNode {get;private set;}
        public bool FlandreChallengeLost {get;private set;}
        public string RemiliaNode {get;private set;}
        public bool RemiliaChallengeLost {get;private set;}
        public string PatchouliNode {get;private set;}
        public bool PatchouliChallengeLost {get;private set;}
        int encounterNumber;
        Random retreatRandom;

        void EnableTrial(ForestTrialOptions options)
        {
            if(options==null)return;
            if(!new[]{0,60,120,180}.Contains(options.TurnSeconds)||!new[]{20,30}.Contains(options.PlanSeconds))
                throw new ArgumentException("Unsupported trial timers");
            Trial=options;
            var themes=(ForestTheme[])Enum.GetValues(typeof(ForestTheme));
            var rng=new Random(unchecked(Seed*7937+11));
            if(Pvp)for(int i=themes.Length-1;i>0;i--)
            {
                int j=rng.Next(i+1);var item=themes[i];themes[i]=themes[j];themes[j]=item;
            }
            Themes=themes.Take(Floors.Length).ToArray();
            for(int floor=0;floor<Floors.Length;floor++)
                foreach(var node in Floors[floor].Nodes)ApplyTheme(node,Themes[floor]);
            retreatRandom=new Random(unchecked(Seed*4259+91));
            if(!Pvp)
            {
                var map=Floors[0];
                RecruitNode=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road)
                    .OrderBy(n=>Math.Abs(map.Distance(map.StartId,n.Id,false)-4)).ThenBy(n=>n.Id,StringComparer.Ordinal).First().Id;
                var route=ForestRandomGenerator.Path(map,Current.Position,RecruitNode,n=>!ForestRandomGenerator.Risk(n.Kind));
                var reserved=new HashSet<string>(route.SelectMany(e=>new[]{e.From,e.To}));
                var candidates=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road&&n.Id!=RecruitNode&&!reserved.Contains(n.Id)&&
                    ForestRandomGenerator.Path(map,Current.Position,n.Id,t=>t.Id!=RecruitNode&&!ForestRandomGenerator.Risk(t.Kind)).Count>0)
                    .OrderBy(n=>n.Id,StringComparer.Ordinal).ToArray();
                if(candidates.Length==0)candidates=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road&&n.Id!=RecruitNode).ToArray();
                FlandreNode=candidates[rng.Next(candidates.Length)].Id;
                var flandreRoute=ForestRandomGenerator.Path(map,Current.Position,FlandreNode,n=>n.Id!=RecruitNode&&!ForestRandomGenerator.Risk(n.Kind));
                var occupied=new HashSet<string>(reserved.Concat(flandreRoute.SelectMany(e=>new[]{e.From,e.To})));
                RemiliaNode=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road&&n.Id!=RecruitNode&&n.Id!=FlandreNode&&
                    ForestRandomGenerator.Path(map,Current.Position,n.Id,t=>t.Id!=RecruitNode&&t.Id!=FlandreNode&&!ForestRandomGenerator.Risk(t.Kind)).Count>0)
                    .OrderBy(n=>occupied.Contains(n.Id)).ThenBy(n=>Math.Abs(map.Distance(map.StartId,n.Id,false)-6))
                    .ThenBy(n=>n.Id,StringComparer.Ordinal).Select(n=>n.Id).FirstOrDefault()??
                    map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road&&n.Id!=RecruitNode&&n.Id!=FlandreNode)
                    .OrderBy(n=>occupied.Contains(n.Id)).ThenBy(n=>n.Id,StringComparer.Ordinal).Select(n=>n.Id).FirstOrDefault();
                var remiliaRoute=ForestRandomGenerator.Path(map,Current.Position,RemiliaNode,n=>n.Id!=RecruitNode&&n.Id!=FlandreNode&&!ForestRandomGenerator.Risk(n.Kind));
                occupied.UnionWith(remiliaRoute.SelectMany(e=>new[]{e.From,e.To}));
                var library=map.Nodes.Where(n=>n.Kind==ForestNodeKind.Road&&n.Id!=RecruitNode&&n.Id!=FlandreNode&&n.Id!=RemiliaNode)
                    .OrderBy(n=>occupied.Contains(n.Id)).ThenBy(n=>Math.Abs(map.Distance(map.StartId,n.Id,false)-5))
                    .ThenBy(n=>n.Id,StringComparer.Ordinal).ToArray();
                PatchouliNode=(library.FirstOrDefault(n=>ForestRandomGenerator.Path(map,Current.Position,n.Id,t=>t.Id!=RecruitNode&&
                    t.Id!=FlandreNode&&t.Id!=RemiliaNode&&!ForestRandomGenerator.Risk(t.Kind)).Count>0)??library.First()).Id;
            }
            ResetTurnClock();
            foreach(var player in Players)
            {
                var composition=player.PlayerId==0?Trial.CompositionA:Trial.CompositionB;
                if(composition!=null)
                {
                    if(composition.Any(id=>!CharacterRoster.Available(id,!Pvp,Trial.RecruitedSakuya,Trial.RecruitedFlandre,Trial.RecruitedRemilia,Trial.RecruitedPatchouli)))
                        throw new ArgumentException("The team contains a locked character.");
                    player.Party.ConfigureTeam(composition);
                }
                else if(!Pvp&&!Trial.RecruitedSakuya)
                {player.Party.SuspendSakuya();if(Trial.RecruitedFlandre)player.Party.SelectCompanion(true);}
                player.Record("进入第1层 "+ThemeName(Themes[0])+"。");
            }
        }

        public static string ThemeName(ForestTheme theme)
        {
            switch(theme)
            {
                case ForestTheme.ScarletMansion:return "红魔馆";
                case ForestTheme.YoukaiMountain:return "妖怪之山";
                case ForestTheme.BambooForest:return "迷途竹林";
                case ForestTheme.EarthPalace:return "地灵殿";
                default:return "魔法森林";
            }
        }

        public string ThemeNameAt(int floor){return Trial==null?"迷途竹林":ThemeName(Themes[floor]);}

        static void ApplyTheme(ForestNode node,ForestTheme theme)
        {
            if(theme==ForestTheme.BambooForest)return;
            string location=theme==ForestTheme.ScarletMansion?"洋馆":theme==ForestTheme.YoukaiMountain?"山间":
                theme==ForestTheme.EarthPalace?"地底":"魔法森林";
            switch(node.Kind)
            {
                case ForestNodeKind.Spawn:node.Name=location+"入口";break;
                case ForestNodeKind.Road:node.Name=location+"通路";break;
                case ForestNodeKind.Danger:node.Name=location+"险路";break;
                case ForestNodeKind.Lookout:node.Name=location+"望台";break;
                case ForestNodeKind.Hideout:node.Name=location+"藏身处";break;
                case ForestNodeKind.Event:node.Name=location+"异闻";break;
                case ForestNodeKind.Encounter:node.Name=location+"奇遇";break;
                case ForestNodeKind.Shop:node.Name=location+"行商";break;
            }
        }
        public bool RecruitAvailable(string id,int floor)
        {return RecruitIdentity(id,floor)!="";}
        public string RecruitIdentity(string id,int floor)
        {
            if(Trial==null||Pvp||floor!=0||string.IsNullOrEmpty(id))return "";
            if(!Trial.RecruitedSakuya&&!RecruitLost&&id==RecruitNode)return "sakuya";
            if(!Trial.RecruitedFlandre&&!FlandreChallengeLost&&id==FlandreNode)return "flandre";
            if(!Trial.RecruitedRemilia&&!RemiliaChallengeLost&&id==RemiliaNode)return RemiliaSkills.Id;
            if(!Trial.RecruitedPatchouli&&!PatchouliChallengeLost&&id==PatchouliNode)return PatchouliSkills.Id;
            return "";
        }
        public bool SelectTrialCompanion(bool flandre)
        {
            if(Trial==null||Pvp||Duel!=null||Current.InBattle||Finished||Current.Party.HasComposition||
                (flandre?!Trial.RecruitedFlandre:!Trial.RecruitedSakuya))return false;
            Current.Party.SelectCompanion(flandre);
            Current.Record("同行者切换为"+(flandre?"芙兰朵露":"咲夜")+"。");
            return true;
        }

        public void ResetTurnClock()
        {if(Trial!=null)TurnTimeLeft=Trial.TurnSeconds;}

        public bool TickTurnClock(double delta)
        {
            if(Trial==null||Trial.TurnSeconds==0||Finished||double.IsNaN(delta)||delta<=0||TurnTimeLeft<=0)return false;
            TurnTimeLeft=Math.Max(0,TurnTimeLeft-delta);
            return TurnTimeLeft==0;
        }

        internal bool TryTrialEncounter(ForestRun actor)
        {
            if(Trial==null||Duel!=null||Finished||Current!=actor)return false;
            if(!Pvp)
            {
                string identity=RecruitIdentity(actor.Position,actor.FloorIndex);
                if(identity=="")return false;
                var recruit=new TrialDuelSide(new[]{CharacterRoster.Create(identity)},identity==PatchouliSkills.Id?20:identity==RemiliaSkills.Id?24:identity=="flandre"?14:8);
                Duel=new CampaignDuel(TrialSideFor(actor),recruit,DuelSeed(),Trial.PlanSeconds,true,actor.FloorIndex);
                actor.Record(identity==PatchouliSkills.Id?"红魔馆图书馆中，帕秋莉提出以元素符卡检验来客。":identity==RemiliaSkills.Id?"红魔馆主厅的钟声响起，蕾米莉亚提出一场符卡挑战。":identity=="flandre"?"红魔馆的暗廊尽头，芙兰朵露提出一场符卡挑战。":"红魔馆走廊传来脚步声。咲夜提议以一场符卡挑战决定是否同行。");
                return true;
            }
            if(PvpOpeningProtected||actor.InBattle)return false;
            var other=Players[1-actor.PlayerId];
            if(other.FloorIndex!=actor.FloorIndex||other.Position!=actor.Position||other.InBattle)return false;
            Duel=new CampaignDuel(TrialSideFor(Players[0]),TrialSideFor(Players[1]),DuelSeed(),Trial.PlanSeconds,false,actor.FloorIndex);
            foreach(var player in Players)player.Record("两支队伍在同一格相遇，进入对战。");
            return true;
        }

        uint DuelSeed(){return unchecked((uint)(Seed*2551+ ++encounterNumber*7919));}
        static TrialDuelSide TrialSideFor(ForestRun player)
        {
            var side=player.Party.TrialSide(player.PreviewMapModifier());
            player.NextBattle.Clear();
            return side;
        }

        public bool FinishTrialDuel()
        {
            if(Duel==null||Duel.Stage!=TrialDuelStage.Finished)return false;
            var battle=Duel;
            Duel=null;
            if(battle.Recruitment)
            {
                Current.Party.ApplyTrialSide(battle.Sides[0]);
                var opponent=battle.Sides[1].Units[0];
                string identity=opponent.CharacterId,name=opponent.Name;
                bool flandre=identity=="flandre",remilia=identity==RemiliaSkills.Id,patchouli=identity==PatchouliSkills.Id;
                if(battle.Winner==0)
                {
                    if(patchouli)Trial.RecruitedPatchouli=true;
                    else if(remilia)Trial.RecruitedRemilia=true;
                    else if(flandre)Trial.RecruitedFlandre=true;
                    else Trial.RecruitedSakuya=true;
                    if(Current.Party.HasComposition)
                    {
                        bool joined=Current.Party.AddRecruited(identity);
                        Current.Record("击败"+name+"，角色已解锁。"+(joined?"已加入队伍。":"队伍已满，下次开局可为她配队。"));
                    }
                    else if(!remilia&&!patchouli)
                    {
                        if(flandre)Current.Party.SelectCompanion(true);else Current.Party.UnlockSakuya();
                        Current.Record("击败"+name+"。她同意同行，已加入普通模式角色库。");
                    }
                }
                else
                {
                    if(patchouli)PatchouliChallengeLost=true;
                    else if(remilia)RemiliaChallengeLost=true;
                    else if(flandre)FlandreChallengeLost=true;
                    else RecruitLost=true;
                    Current.Revive();
                    Current.Record("挑战失败。"+name+"暂时离开，重新开局可以再次挑战。");
                }
                return true;
            }
            var winner=Players[battle.Winner];
            var loser=Players[1-battle.Winner];
            winner.Party.ApplyTrialSide(battle.Sides[battle.Winner]);
            loser.Party.ApplyTrialSide(battle.Sides[1-battle.Winner]);
            bool movingWinner=winner==Current;
            bool capturedStone=StoneHolder==loser.PlayerId;
            if(capturedStone)SetStoneHolder(winner);
            loser.Revive();
            winner.Record("对战胜利。保留所在格，继续探索。");
            loser.Record("对战失败，返回第"+(loser.FloorIndex+1)+"层永远亭。");
            if(capturedStone)
                foreach(var player in Players)player.Record("异动石已转交给胜利方玩家"+(winner.PlayerId+1)+"，追踪目标随之更新。");
            if(!movingWinner)AdvancePlayer();
            if(AtExit(winner))Escape(winner);
            else if(movingWinner)winner.ResumeTrialArrival();
            return true;
        }

        public void AbortTrialDuel(bool timeout=true)
        {
            if(Duel==null)return;
            var battle=Duel;
            Duel=null;
            Current.Party.ApplyTrialSide(battle.Sides[battle.Recruitment?0:ActivePlayer]);
            if(battle.Recruitment)
            {
                if(Current.Party.Hp.All(h=>h<=0))Current.Revive();
                Current.Record(timeout?"地图回合超时，角色挑战中止。":"已退出角色挑战，回到探索。");
                return;
            }
            var other=Players[1-ActivePlayer];
            other.Party.ApplyTrialSide(battle.Sides[other.PlayerId]);
            foreach(var player in Players)
                player.RetreatTrial(retreatRandom,Players[1-player.PlayerId].Position);
        }
    }

    public sealed partial class ForestRun
    {
        readonly Dictionary<int,string> priorTrialTile=new Dictionary<int,string>();
        internal void RememberTrialOrigin(string previous)
        {if(Campaign!=null&&Campaign.Trial!=null)priorTrialTile[FloorIndex]=previous;}

        internal void ResumeTrialArrival()
        {
            EnterNode();
        }

        internal void RetreatTrial(Random rng,string occupied)
        {
            string preferred;
            priorTrialTile.TryGetValue(FloorIndex,out preferred);
            string previous=null;
            int count=0;
            for(int i=0;i<2;i++)
            {
                var candidates=Map.Links(Position).Where(e=>!e.Hidden||knownEdges.Contains(e.Id))
                    .Select(e=>e.Other(Position)).Where(id=>id!=previous&&id!=occupied)
                    .OrderBy(id=>id,StringComparer.Ordinal).ToArray();
                if(candidates.Length==0)break;
                if(i==0)
                {
                    var twoSteps=candidates.Where(id=>Map.Links(id).Any(e=>(!e.Hidden||knownEdges.Contains(e.Id))&&
                        e.Other(id)!=Position&&e.Other(id)!=occupied)).ToArray();
                    if(twoSteps.Length>0)candidates=twoSteps;
                }
                string next=i==0&&preferred!=null&&candidates.Length<=2&&candidates.Contains(preferred)?
                    preferred:candidates[rng.Next(candidates.Length)];
                previous=Position;Position=next;visited.Add(next);count++;
            }
            Selected=Position;
            Reveal();
            Record("对战随地图回合超时中止，安全后退 "+count+" 格。");
        }

        public void AbortTrialMobBattle(PortState state)
        {
            if(Campaign==null||Campaign.Trial==null||!InBattle)return;
            LeaveMapBattle(state,false);
            Record("地图回合超时，遭遇结束。保留已结算的生命与费用。");
        }

        public void LeaveMapBattle(PortState state,bool forfeit)
        {
            if(!InBattle)return;
            if(state!=null)
            {
                Party.Cost=state.Cost;
                Party.ApplyMembers(state.Heroes);
            }
            InBattle=false;activeMapBattle=null;NextBattle.Clear();
            if(forfeit||Party.Hp.All(h=>h<=0))Revive();
            else Record("已退出战斗，回到探索。");
        }

        public void SkipTrialChoice()
        {if(Campaign!=null&&Campaign.Trial!=null&&Pending!=""){Pending="";Record("地图回合超时，未结算地点选择。");}}
    }
}
