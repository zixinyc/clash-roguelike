using System;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        const string TrialRecruitKey="forest_trial_sakuya_unlocked";
        const string TrialFlandreKey="forest_trial_flandre_unlocked";
        const string TrialRemiliaKey="forest_trial_remilia_unlocked";
        const string TrialPatchouliKey="forest_trial_patchouli_unlocked";
        bool forestTrialMode,forestTrialSetup,trialSkipSave;
        int trialTimeIndex,trialSkillSeconds=20,trialTeamA=1,trialTeamB=2;
        readonly int[] trialTimeOptions={0,60,120,180};
        Coroutine portPlaybackRoutine;
        CampaignDuel audibleDuel;
        int audibleCues;

        ForestTrialOptions CreateTrialOptions()
        {
            if(!forestTrialMode)return null;
            return new ForestTrialOptions
            {
                TurnSeconds=trialTimeOptions[trialTimeIndex],PlanSeconds=trialSkillSeconds,TeamA=trialTeamA,TeamB=trialTeamB,
                CompositionA=activeTeam,CompositionB=activeRivalTeam,
                RecruitedSakuya=!trialSkipSave&&PlayerPrefs.GetInt(TrialRecruitKey,0)==1,
                RecruitedFlandre=TeamUnlocked(TrialFlandreKey),
                RecruitedRemilia=TeamUnlocked(TrialRemiliaKey),
                RecruitedPatchouli=TeamUnlocked(TrialPatchouliKey)
            };
        }

        bool TrialActive {get{return forestMode&&forestCampaign!=null&&forestCampaign.Trial!=null;}}

        void StartTrial(bool pvp)
        {
            forestTrialMode=true;forestTrialSetup=false;forestPvpMode=pvp;
            InitializeForest();
        }

        bool UpdateTrialFlow()
        {
            if(!TrialActive||(!fromMap&&portRules!=null))return false;
            if(forestCampaign.TickTurnClock(Time.unscaledDeltaTime))
            {
                ExpireTrialTurn();
                return true;
            }
            var duel=forestCampaign.Duel;
            if(duel==null)
            {
                if(!LocalOpponentTurn)return false;
                UpdateLocalOpponentMap();
                return true;
            }
            if(!duel.Recruitment)UpdateLocalOpponentDuel(duel);
            duel.Tick(Time.unscaledDeltaTime);
            UpdatePvpBoard(duel);
            if(Input.GetKeyDown(KeyCode.Escape))pvpSelection[0].Skill="";
            if(audibleDuel!=duel){audibleDuel=duel;audibleCues=0;}
            if(duel.MusicCues>audibleCues){audibleCues=duel.MusicCues;PlayFlandreMusic();}
            return true;
        }

        void ExpireTrialTurn()
        {
            int active=forestCampaign.ActivePlayer;
            if(forestCampaign.Duel!=null)
            {
                StopImpactShake();
                if(forestCampaign.Duel.Stage==TrialDuelStage.Finished)FinishTrialBattle();
                else forestCampaign.AbortTrialDuel();
            }
            if(!forestCampaign.Finished&&forestCampaign.ActivePlayer!=active)return;
            if(portRules!=null&&fromMap)
            {
                if(!portBusy&&portRules.State.Outcome!="")ReturnPortMap();
                else
                {
                    if(portPlaybackRoutine!=null){StopCoroutine(portPlaybackRoutine);portPlaybackRoutine=null;}
                    StopImpactShake();
                    forest.AbortTrialMobBattle(portRules.State);
                    portRules=null;portShown=null;portEvent=null;
                    portBusy=false;portPrepared=false;loadoutSelecting=false;forestPassAfterBattle=false;
                    CloseEffectInspector();
                }
            }
            if(forestCampaign.Finished||forestCampaign.ActivePlayer!=active)return;
            forest.SkipTrialChoice();
            forest.Record("地图计时结束，强制结束本回合。");
            ForestEndTurn(true);
        }

        void FinishTrialBattle()
        {
            var duel=forestCampaign.Duel;
            if(duel==null||!forestCampaign.FinishTrialDuel())return;
            StopImpactShake();
            CloseEnemySkillDetails();
            if(duel.Recruitment&&duel.Winner==0&&!trialSkipSave)
            {
                var identity=duel.Sides[1].Units[0].CharacterId;
                PlayerPrefs.SetInt(identity==PatchouliSkills.Id?TrialPatchouliKey:identity==RemiliaSkills.Id?TrialRemiliaKey:identity=="flandre"?TrialFlandreKey:TrialRecruitKey,1);
                PlayerPrefs.Save();
            }
            forest=forestCampaign.Current;
            UpdateForestNames();
            ForestBattleHook();
        }

        void UpdateForestNames()
        {
            var team=forest.Party.Members();
            heroNames=team.Select((u,i)=>forest.Party.MaxHp[i]>0?u.Name:forest.Party.HasComposition?"空位":"待招募").ToArray();
        }

        string TrialClockText()
        {
            return forestCampaign.Trial.TurnSeconds==0?"地图不限时":
                "地图 "+Math.Max(0,(int)Math.Ceiling(forestCampaign.TurnTimeLeft))+" 秒";
        }

        void DrawTrialSetup()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,.82f));
            Panel(new Rect(360,132,720,625),Hex("461D28"),Gold);
            Label(395,158,650,48,"新规则试验",30,Gold);
            Label(395,215,647,43,"单机顺序探索五大主题，可在红魔馆挑战咲夜、芙兰朵露、蕾米莉亚和帕秋莉。与人机对手轮流探索，相遇后各自安排技能，双方准备后开始交锋。",15,Pale);
            Label(395,274,650,23,"地图回合 · 连续计时，进入战斗后继续",14,Muted);
            for(int i=0;i<trialTimeOptions.Length;i++)
                if(Btn(new Rect(395+i*164,303,155,36),trialTimeOptions[i]==0?"不限时":trialTimeOptions[i]+" 秒",trialTimeIndex==i))trialTimeIndex=i;
            Label(395,359,285,25,"对战独立选技时间",14,Muted);
            if(Btn(new Rect(683,355,167,35),"20 秒",trialSkillSeconds==20))trialSkillSeconds=20;
            if(Btn(new Rect(868,355,167,35),"30 秒",trialSkillSeconds==30))trialSkillSeconds=30;
            Label(395,480,650,45,trialTimeIndex==1?"60 秒地图计时可能早于两人选技结束。卡组可留空，超时仍可用通用牌。":
                "同格触发对战。专属卡组 10 秒，可留空。试验对战支持通用牌与部分专属符卡。",14,Muted);
            if(Btn(new Rect(395,559,310,45),"普通模式 · 配队"))OpenTeamSetup(TeamMode.Normal,false);
            if(Btn(new Rect(722,559,313,45),"PVP 人机试玩 · 配队",true))OpenTeamSetup(TeamMode.Pvp,false);
            if(Btn(new Rect(395,647,640,39),"返回地图设定"))forestTrialSetup=false;
        }

        Color TrialAmbient()
        {
            if(!TrialActive)return Hex("2A4542");
            switch(forestCampaign.Themes[forest.FloorIndex])
            {
                case ForestTheme.ScarletMansion:return Hex("563437");
                case ForestTheme.YoukaiMountain:return Hex("26485C");
                case ForestTheme.EarthPalace:return Hex("4B3730");
                case ForestTheme.MagicForest:return Hex("37445A");
                default:return Hex("2A4542");
            }
        }

        void DrawTrialDecor()
        {
            if(!TrialActive||forestCampaign.Themes[forest.FloorIndex]==ForestTheme.BambooForest)
            {DrawEasternBackdrop();return;}
            var theme=forestCampaign.Themes[forest.FloorIndex];
            Color ink=TrialAmbient();ink.a=.8f;
            for(int i=0;i<10;i++)
            {
                float x=forestRect.x+62+i*96,y=forestRect.y+132+(i%3)*157;
                if(theme==ForestTheme.ScarletMansion)
                {
                    Outline(new Rect(x-23,y,46,75),ink,3);
                    Line(new Vector2(x-24,y),new Vector2(x,y-38),ink,3);
                    Line(new Vector2(x,y-38),new Vector2(x+24,y),ink,3);
                    Line(new Vector2(x,y),new Vector2(x,y+75),ink,3);
                }
                else if(theme==ForestTheme.MagicForest)
                {
                    Fill(new Rect(x-4,y,8,38),ink);
                    Fill(new Rect(x-22,y-9,44,15),ink);
                    Fill(new Rect(x-12,y-17,24,9),ink);
                }
                else
                {
                    Line(new Vector2(x-38,y+37),new Vector2(x,y-30),ink,5);
                    Line(new Vector2(x,y-30),new Vector2(x+38,y+37),ink,5);
                    if(theme==ForestTheme.EarthPalace)Line(new Vector2(x-35,y+49),new Vector2(x+44,y+49),Hex("7C4A36"),5);
                }
            }
        }
    }
}
