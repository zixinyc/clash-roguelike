using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame : MonoBehaviour
    {
        BattleRules rules;
        BattleState shown;
        readonly List<string> log=new List<string>();
        int speed=1;
        int roundPlanCount;
        BattleInteraction selection;
        int hero { get { return selection.Hero; } }
        int card { get { return selection.Card; } }
        bool busy,auto,help,muted,legacySkip;
        string notice="点击己方角色，展开可用技能";
        BattleEvent current;
        float phase;
        Font font;
        GUIStyle text,button;
        AudioSource audioSource;
        AudioClip hitClip,clashClip;
        Coroutine activePlayback;
        static readonly Color Gold=Hex("DFBD83"), Pale=Hex("E7E9E3"), Muted=Hex("82959E"), Cyan=Hex("94C4CA"), Red=Hex("D48178");

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Bootstrap()
        {
            if(FindObjectOfType<BattleGame>()!=null) return;
            new GameObject("Battle Game").AddComponent<BattleGame>();
        }
        void Awake()
        {
            Application.targetFrameRate=60;
            if(Camera.main==null) { var cameraObject=new GameObject("Main Camera"); cameraObject.tag="MainCamera"; var c=cameraObject.AddComponent<Camera>(); c.clearFlags=CameraClearFlags.SolidColor; c.backgroundColor=Hex("0B141C"); }
            if(FindObjectOfType<AudioListener>()==null) gameObject.AddComponent<AudioListener>();
            font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","Arial"},18);
            audioSource=gameObject.AddComponent<AudioSource>(); audioSource.playOnAwake=false; audioSource.volume=0.25f;
            hitClip=Tone("strike",150,0.16f); clashClip=Tone("clash",530,0.12f);
            Restart();
        }
        AudioClip Tone(string name,float frequency,float length)
        {
            const int rate=22050; var data=new float[(int)(rate*length)];
            for(int i=0;i<data.Length;i++) { float t=(float)i/rate; data[i]=Mathf.Sin(2*Mathf.PI*(frequency*t-180*t*t))*Mathf.Exp(-30*t)*0.45f; }
            var clip=AudioClip.Create(name,data.Length,1,rate,false); clip.SetData(data,0); return clip;
        }
        void OnDestroy() { DisposePortraits();if(font!=null) Destroy(font); if(hitClip!=null) Destroy(hitClip); if(clashClip!=null) Destroy(clashClip); if(forestArt!=null)forestArt.Dispose();if(coinDisc!=null)Destroy(coinDisc); }
        void Start()
        {
            string checkPath=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--character-checks="));
            if(checkPath!=null){CheckNewCharacterEntrances(checkPath.Substring("--character-checks=".Length));return;}
            string argument=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--visual-smoke="));
            if(argument!=null) StartCoroutine(VisualSmoke(argument.Substring("--visual-smoke=".Length)));
            else
            {
                selectedRoster=Environment.GetCommandLineArgs().Contains("--zixi")?2:Environment.GetCommandLineArgs().Contains("--original-team")?0:1;
                InitializeAdventure();
                string prototypeSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--prototype-smoke="));
                if(prototypeSmoke!=null)StartCoroutine(PrototypeSmoke(prototypeSmoke.Substring("--prototype-smoke=".Length)));
                string mainRosterSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--main-roster-smoke="));
                if(mainRosterSmoke!=null)StartCoroutine(MainRosterSmoke(mainRosterSmoke.Substring("--main-roster-smoke=".Length)));
                if(Environment.GetCommandLineArgs().Contains("--battle"))OpenPortBattle(false,0,selectedRoster==1,selectedRoster==2);
                string smoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--adventure-smoke="));
                if(smoke!=null){forestMode=false;StartCoroutine(AdventureSmoke(smoke.Substring("--adventure-smoke=".Length)));}
                string forestSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--forest-smoke="));
                if(forestSmoke!=null)StartCoroutine(ForestSmoke(forestSmoke.Substring("--forest-smoke=".Length)));
                string coinSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--coin-smoke="));
                if(coinSmoke!=null)StartCoroutine(CoinSmoke(coinSmoke.Substring("--coin-smoke=".Length)));
                string guidanceSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--guidance-smoke="));
                if(guidanceSmoke!=null)StartCoroutine(GuidanceSmoke(guidanceSmoke.Substring("--guidance-smoke=".Length)));
                string touhouSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--touhou-smoke="));
                if(touhouSmoke!=null)StartCoroutine(TouhouSmoke(touhouSmoke.Substring("--touhou-smoke=".Length)));
                string compactSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--compact-smoke="));
                if(compactSmoke!=null)StartCoroutine(CompactCombatSmoke(compactSmoke.Substring("--compact-smoke=".Length)));
                string portraitSmoke=Environment.GetCommandLineArgs().FirstOrDefault(x=>x.StartsWith("--portrait-smoke="));
                if(portraitSmoke!=null)StartCoroutine(PortraitSmoke(portraitSmoke.Substring("--portrait-smoke=".Length)));
                if(Environment.GetCommandLineArgs().Contains("--grid"))forestMode=false;
                if(Environment.GetCommandLineArgs().Contains("--legacy")) adventureMode=false;
            }
        }
        IEnumerator Capture(string folder,string name)
        {
            yield return new WaitForEndOfFrame();
            var image=new Texture2D(Screen.width,Screen.height,TextureFormat.RGB24,false);
            image.ReadPixels(new Rect(0,0,Screen.width,Screen.height),0,0); image.Apply();
            var pixels=image.GetPixels32(); int stride=(Screen.width*3+3)&~3;
            int darkest=765,brightest=0;
            for(int i=0;i<pixels.Length;i+=127) { int light=pixels[i].r+pixels[i].g+pixels[i].b; darkest=Math.Min(darkest,light); brightest=Math.Max(brightest,light); }
            SmokeCheck(brightest-darkest>100,"render capture must contain visible content: "+name);
            using(var writer=new BinaryWriter(File.Create(Path.Combine(folder,name+".bmp"))))
            {
                writer.Write((ushort)0x4d42); writer.Write(54+stride*Screen.height); writer.Write(0); writer.Write(54);
                writer.Write(40); writer.Write(Screen.width); writer.Write(Screen.height); writer.Write((ushort)1); writer.Write((ushort)24);
                writer.Write(0); writer.Write(stride*Screen.height); writer.Write(0); writer.Write(0); writer.Write(0); writer.Write(0);
                for(int y=0;y<Screen.height;y++) { for(int x=0;x<Screen.width;x++) { var p=pixels[y*Screen.width+x]; writer.Write(p.b); writer.Write(p.g); writer.Write(p.r); } for(int x=Screen.width*3;x<stride;x++) writer.Write((byte)0); }
            }
            Destroy(image);
        }
        void SmokeCheck(bool condition,string message)
        { if(!condition) { Debug.LogError("UNITY_VISUAL_SMOKE_FAILED "+message); Application.Quit(1); throw new InvalidOperationException(message); } }
        IEnumerator VisualSmoke(string folder)
        {
            Directory.CreateDirectory(folder);
            int runtimeChecks=BattleRuleChecks.Run(), clickChecks=InteractionChecks.Run(), panelChecks=PanelChecks.Run();
            Debug.Log("UNITY_PLAYER_RULE_CHECKS_PASSED checks="+runtimeChecks);
            Debug.Log("UNITY_CLICK_CHECKS_PASSED checks="+clickChecks);
            Debug.Log("UNITY_PANEL_CHECKS_PASSED checks="+panelChecks);
            while(!UnityEngine.Rendering.SplashScreen.isFinished) yield return null;
            yield return null; yield return null;
            yield return Capture(folder,"battle-ready");
            string untouched=rules.State.Fingerprint(); PrepareRound();
            SmokeCheck(!selection.Prepared&&rules.State.Fingerprint()==untouched,"empty preparation is blocked");
            SelectHero(0); SelectSkill(0); PrepareRound();
            SmokeCheck(!selection.Prepared&&selection.WaitingForTarget&&rules.State.Plans.Count==0,"pending target cannot prepare");
            SelectEnemy(0); yield return Capture(folder,"panel-arranged");
            string planned=rules.State.Fingerprint(); PrepareRound();
            SmokeCheck(selection.Prepared&&rules.State.Fingerprint()==planned&&rules.State.Cost==9,"ready phase locks plans without spending");
            yield return Capture(folder,"panel-prepared");
            ResumePlanning(); CancelPlan(); SmokeCheck(!selection.CanPrepare&&rules.State.Plans.Count==0,"undo updates panel readiness");
            SelectHero(0); SelectSkill(0); SelectEnemy(0); SelectHero(1); SelectSkill(1); SelectEnemy(1); SelectHero(2); SelectSkill(2); SelectEnemy(0);
            SmokeCheck(selection.AllArranged&&selection.PanelStatus=="全部已安排","all arranged panel phase");
            yield return Capture(folder,"panel-all-arranged");
            PrepareRound(); PlayPreparedRound();
            SmokeCheck(busy&&!selection.Prepared,"demonstration uses existing planned round");
            yield return Capture(folder,"panel-playing"); while(busy) yield return null;
            SmokeCheck(!selection.Prepared&&!selection.CanPrepare&&hero==-1&&rules.State.Turn==2,"next round returns to preparation");
            ResetState();
            string initial=rules.State.Fingerprint(); SelectEnemy(0);
            SmokeCheck(rules.State.Fingerprint()==initial&&hero==-1,"enemy before actor ignored");
            SelectHero(1); yield return Capture(folder,"actor-skills");
            SelectSkill(0); SmokeCheck(selection.WaitingForTarget&&rules.State.Plans.Count==0,"skill waits for target without spending");
            yield return Capture(folder,"legal-targets");
            SelectEnemy(0); SmokeCheck(rules.State.Plans.Count==1&&card==-1,"target click immediately plans action");
            SelectHero(0); SelectSkill(1); SelectEnemy(0);
            SmokeCheck(rules.ClashHero(0)==0&&rules.State.Cost==9&&rules.State.ReservedCost==5,"last slower eligible assignment retains speed rule");
            yield return Capture(folder,"planning-last-assignment");
            CancelPlan(); SmokeCheck(rules.ClashHero(0)==1&&rules.State.ReservedCost==3,"cancellation restores previous pairing");
            SelectHero(2); SelectSkill(2); SelectEnemy(1);
            SmokeCheck(!rules.CanClash(2,1)&&rules.State.Plans.Any(p=>p.Hero==2&&p.Enemy==1),"slower unopposed target is legal");
            yield return Capture(folder,"planning-unopposed");
            ResetState(); SelectHero(0); SelectSkill(4);
            SmokeCheck(rules.State.Heroes[0].Shield==0&&rules.State.Cost==9&&rules.State.ReservedCost==1,"guard skill auto-targets self without resolving");
            yield return Capture(folder,"planning-guard");
            rules.State.Heroes[0].Speed=9; EndTurn(); while(busy) yield return null;
            SmokeCheck(log.Any(x=>x.Contains("获得 9 护盾"))&&rules.State.Cost==11,"guard still resolves by speed");
            ResetState(); SelectHero(0); SelectSkill(0); SelectEnemy(0); EndTurn();
            Skip();while(busy)yield return null;
            SmokeCheck(shown.Fingerprint()==rules.State.Fingerprint()&&!rules.State.Resolving&&hero==-1&&card==-1,"skip drains the same streamed resolution and clears targeting");
            ResetState(); speed=4; SelectHero(0); SelectSkill(0); SelectEnemy(0); EndTurn();
            while(busy && (current==null||current.Type!="clash")) yield return null;
            yield return Capture(folder,"clash"); while(busy) yield return null;
            for(int i=0;i<20&&rules.State.Outcome=="";i++) yield return StartCoroutine(AutoRound());
            SmokeCheck(rules.State.Outcome!="","full battle terminates");
            string outcome=rules.State.Outcome; yield return Capture(folder,"completed-battle");
            ResetState(); SmokeCheck(hero==-1&&card==-1&&shown.Cost==9,"restart clears selections");
            rules.State.Enemies[0].Hp=1; rules.State.Enemies[0].Spent=true; rules.State.Enemies[1].Hp=0;
            SelectHero(0); SelectSkill(0); SelectEnemy(0); EndTurn(); while(busy) yield return null;
            SmokeCheck(shown.Outcome=="victory","victory overlay"); yield return Capture(folder,"victory");
            ResetState(); foreach(var h in rules.State.Heroes) h.Hp=1; foreach(var e in rules.State.Enemies) e.Base=100;
            EndTurn(); while(busy) yield return null;
            if(rules.State.Outcome=="") { EndTurn(); while(busy) yield return null; }
            SmokeCheck(shown.Outcome=="defeat","defeat overlay"); yield return Capture(folder,"defeat");
            ResetState(); SmokeCheck(hero==-1&&card==-1&&shown.Heroes[0].Hp==36,"restart after defeat");
            Screen.SetResolution(1000,650,false); yield return null; yield return null;
            SelectHero(0); SelectSkill(0); yield return Capture(folder,"battle-small");
            string report="UNITY_VISUAL_SMOKE_PASSED\nSpeed rule checks: "+runtimeChecks+"\nClick checks: "+clickChecks+"\nPanel checks: "+panelChecks+"\nFull battle outcome: "+outcome+"\nDynamic phases, pending-target guard, undo, preparation without spending, prepared demonstration, next-round reset, direct targeting, speed pairing, guard, victory/defeat and two sizes verified.\n";
            File.WriteAllText(Path.Combine(folder,"visual-smoke.txt"),report); Debug.Log(report); Application.Quit(0);
        }
        public void Restart()
        {
            StopAllCoroutines(); ResetState();
        }
        void ResetState()
        {
            CloseEffectInspector();
            audioSource.Stop(); rules=new BattleRules(); selection=new BattleInteraction(rules); shown=rules.State.Copy(); busy=false; auto=false; current=null; phase=0; roundPlanCount=0;
            log.Clear(); Log("敌方已锁定目标。双方速度已公开。"); notice=selection.Message;
        }
        void Update()
        {
            if(effectInspectorOpen&&Input.GetKeyDown(KeyCode.Escape)){CloseEffectInspector();return;}
            if(adventureMode) { AdventureUpdate(); return; }
            if(Input.GetKeyDown(KeyCode.R)) Restart();
            if(Input.GetKeyDown(KeyCode.Escape)) { if(selection.WaitingForTarget) { selection.ClearSkill(); notice=selection.Message; } else help=!help; }
            if(busy || auto || help || shown.Outcome!="") return;
            if(Input.GetKeyDown(KeyCode.Return)) { ActivatePrimary(); return; }
            if(selection.Prepared) return;
            for(int i=0;i<5;i++) if(Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1+i)) && i<shown.Hand.Count) SelectSkill(i);
            if(Input.GetKeyDown(KeyCode.Q)) SelectHero(hero<0?2:(hero+2)%3);
            if(Input.GetKeyDown(KeyCode.E)) SelectHero(hero<0?0:(hero+1)%3);
            if(Input.GetKeyDown(KeyCode.A)) SelectEnemy(0);
            if(Input.GetKeyDown(KeyCode.D)) SelectEnemy(1);
            if(Input.GetKeyDown(KeyCode.Delete)) CancelPlan();
        }
        bool Interactive { get { return !busy&&!auto&&!help&&!selection.Prepared&&shown.Outcome==""; } }
        void SelectionChanged()
        {
            shown=rules.State.Copy(); notice=selection.Message;
            if(selection.Committed) Log(notice);
        }
        void SelectHero(int index) { if(!Interactive) return; selection.SelectHero(index); SelectionChanged(); }
        void SelectSkill(int index) { if(!Interactive) return; selection.SelectSkill(index); SelectionChanged(); }
        void SelectEnemy(int index) { if(!Interactive) return; selection.SelectEnemy(index); SelectionChanged(); }
        void CancelPlan()
        {
            if(!Interactive) return;
            if(selection.Cancel()) Log(selection.Message);
            SelectionChanged();
        }
        void PrepareRound()
        {
            if(!Interactive) return;
            selection.Prepare(); SelectionChanged();
        }
        void PlayPreparedRound()
        {
            if(busy||auto||help||!selection.CanPlayPrepared) return;
            EndTurn();
        }
        void ActivatePrimary() { if(selection.Prepared) PlayPreparedRound(); else PrepareRound(); }
        void ResumePlanning()
        { if(busy||auto||help) return; selection.ResumePlanning(); SelectionChanged(); }
        void EndTurn() { roundPlanCount=rules.State.Plans.Count; selection.Clear(); activePlayback=StartCoroutine(Playback(rules.EndTurnStream())); }
        IEnumerator Playback(IEnumerable<BattleEvent> events)
        {
            busy=true;legacySkip=false;
            foreach(var e in events)
            {
                current=e; phase=0;
                // A snapshot belongs to one event; the renderer never resolves damage.
                shown=e.Snapshot.Copy(); string message=Describe(e); if(message!="") { notice=e.Coin==null?message:CoinHint(e.Coin,e.Type); Log(message); }
                float duration=e.Type=="clash"?.65f:e.Type=="strike"?.45f:e.Type=="clash_end"?.4f:e.Type=="attack_end"?.18f:.12f;
                yield return PlayBattleBeat(e.Type,e.Coin,duration,p=>phase=p,()=>legacySkip);
            }
            current=null; shown=rules.State.Copy(); busy=false;
            roundPlanCount=0; selection.Clear(); if(shown.Outcome=="") notice=selection.Message;
        }
        int NextHero() { int index=rules.State.Heroes.FindIndex(x=>x.Hp>0&&!x.Acted&&!rules.State.Plans.Any(p=>p.Hero==rules.State.Heroes.IndexOf(x))); return index<0?hero:index; }
        IEnumerator AutoRound()
        {
            auto=true;
            for(int action=0;action<3 && rules.State.Outcome=="";action++)
            {
                int actor=NextHero();
                if(actor<0 || rules.State.Plans.Any(p=>p.Hero==actor) || rules.State.Heroes[actor].Hp<=0) break;
                int target=rules.State.Enemies.FindIndex(x=>x.Hp>0&&x.Target==actor);
                if(target<0) target=rules.State.Enemies.FindIndex(x=>x.Hp>0&&rules.ClashHero(rules.State.Enemies.IndexOf(x))<0);
                if(target<0) target=rules.State.Enemies.FindIndex(x=>x.Hp>0);
                if(actor<0 || target<0) break;
                int best=-1,score=int.MinValue;
                for(int i=0;i<rules.State.Hand.Count;i++)
                {
                    Skill s=BattleRules.GetSkill(rules.State.Hand[i]);
                    int value=s.Guard?0:s.Base+s.ClashCoinPower*s.Coins;
                    if(rules.CanPlay(i,actor,target)=="" && value>score) { best=i; score=value; }
                }
                if(best<0) break;
                rules.Play(best,actor,target); shown=rules.State.Copy();
            }
            if(rules.State.Outcome=="") { roundPlanCount=rules.State.Plans.Count; yield return StartCoroutine(Playback(rules.EndTurnStream())); }
            auto=false;
        }
        void Skip()
        {
            if(busy){legacySkip=true;notice="快速结算中；平局继续重投。";}
        }
        void SkipDisplay()
        {
            busy=false; auto=false; current=null; shown=rules.State.Copy(); selection.Clear(); roundPlanCount=0;
            notice="已跳过演出；战斗结果保持一致"; Log(notice);
        }
        string Describe(BattleEvent e)
        {
            switch(e.Type)
            {
                case "planned": return shown.Heroes[e.Hero].Name+" 已安排 "+e.Skill+" · 预留 "+e.Paid+" cost；可继续修改";
                case "paid": return shown.Heroes[e.Hero].Name+" · "+e.Skill+"  −"+e.Paid+" cost";
                case "action": return "速度 "+e.Speed+" · "+(e.Allied?shown.Heroes[e.Hero].Name:shown.Enemies[e.Enemy].Name)+" → "+(e.Enemy<0?"自身":e.Allied?shown.Enemies[e.Enemy].Name:shown.Heroes[e.Hero].Name)+" · "+e.Result;
                case "cancelled": return "速度 "+e.Speed+" · "+e.Result;
                case "guard": return shown.Heroes[e.Hero].Name+" 获得 9 护盾";
                case "clash": return CoinLog.Clash(e.Coin);
                case "clash_end": return "最终拼点胜者："+(e.Coin.FinalWinner==0?e.Coin.Left.Name:e.Coin.Right.Name);
                case "attack_end": return e.Coin.Left.Name+" 攻击结束："+e.Coin.AttackIndex+" 次，累计原始 "+e.Coin.TotalRawDamage;
                case "refund": return "拼点失败 · 退款 +"+e.Amount+" cost";
                case "reward": return "本回合首次拼点获胜 · +1 cost";
                case "unopposed": return "未形成拼点 · 单方面攻击";
                case "enemy_turn": return shown.Enemies[e.Enemy].Name+" 执行剩余行动";
                case "strike": return CoinLog.Attack(e.Coin)+"；实伤 "+e.Damage+(e.Blocked>0?" · 盾吸收 "+e.Blocked:"");
                case "new_turn": return "第 "+shown.Turn+" 回合 · 基础收入 +3 cost · 重新抽 5 张";
                case "outcome": return e.Result=="victory"?"战斗胜利 · 钱包余额保留":"小队失去战斗能力";
                default: return "";
            }
        }
        void Log(string line) { log.Add(line); if(log.Count>500) log.RemoveAt(0); }
        void PrepareStyles()
        {
            if(text!=null) return;
            text=new GUIStyle(GUI.skin.label); text.font=font; text.richText=false; text.wordWrap=true; text.normal.textColor=Pale;
            button=new GUIStyle(GUI.skin.button); button.font=font; button.fontSize=15; button.normal.textColor=Pale; button.hover.textColor=Gold;
        }
        void OnGUI()
        {
            if(shown==null) return; PrepareStyles();
            if(adventureMode) { DrawAdventure(); return; }
            float scale=Mathf.Min(Screen.width/1440f,Screen.height/900f);
            GUI.matrix=Matrix4x4.TRS(new Vector3((Screen.width-1440*scale)/2,(Screen.height-900*scale)/2,0),Quaternion.identity,new Vector3(scale,scale,1));
            Fill(new Rect(0,0,1440,900),Hex("0B141C"));
            Label(30,20,320,45,"余烬交锋",32,Gold);
            Label(30,67,480,24,"CLASH ROGUELIKE    /    北境废站 · 接敌",12,Muted);
            Label(380,34,250,30,"SINGLE BATTLE / 单场演示",12,Cyan);
            Label(660,29,180,40,"ROUND  "+shown.Turn.ToString("00"),21,Pale);
            Label(850,24,200,48,"cost   "+shown.Cost.ToString("00"),29,Gold);
            if(Btn(new Rect(1060,29,100,38),"演出 ×"+speed)) speed=speed==1?2:speed==2?4:1;
            if(Btn(new Rect(1170,29,100,38),"规则 ?")) help=!help;
            if(Btn(new Rect(1280,29,120,38),muted?"声音：关":"声音：开")) { muted=!muted; audioSource.mute=muted; }
            DrawStage();
            bool interactive=Interactive;
            Label(34,538,800,32,busy?"本回合演出":selection.Prepared?"行动已锁定":hero<0?"回合规划":shown.Heroes[hero].Name+" / 行动规划",17,Gold);
            Label(904,538,500,32,"已安排 "+shown.Plays+" / 3    预留 "+shown.ReservedCost+"    可用 "+(shown.Cost-shown.ReservedCost)+" cost",15,Gold,TextAnchor.MiddleRight);
            GUI.enabled=true;
            Label(32,585,1000,28,notice,13,selection.WaitingForTarget?Cyan:Muted);
            if(hero>=0)
            {
                Label(32,613,1000,20,shown.Heroes[hero].Name+" / 可用技能 · 共享手牌",12,Gold);
                for(int i=0;i<shown.Hand.Count;i++) DrawCard(i,interactive);
            }
            else
            {
                Panel(new Rect(32,635,1027,215),Hex("12202A"),Hex("35474F"));
                Label(120,711,850,40,busy?"按速度执行本回合行动":"选择一名角色以查看技能",23,Muted,TextAnchor.MiddleCenter);
            }
            if(effectInspectorOpen)DrawEffectInspector();else{DrawBattleJournal();DrawOperationPanel();}
            Label(32,863,1100,25,"点击角色 → 技能 → 敌人   1–5 技能   Q/E 选人   A/D 指定敌人   Delete 撤销   Enter 准备 / 演示",12,Muted);
            if(Btn(new Rect(1180,861,110,29),"重开")) Restart();
            if(Btn(new Rect(1300,861,110,29),"地图探索")) { if(exploration==null) InitializeAdventure(); else adventureMode=true; }
            if(shown.Outcome!=""&&!busy) DrawResult();
            if(help) DrawHelp();
            GUI.matrix=Matrix4x4.identity;
        }
        void DrawOperationPanel()
        {
            Panel(new Rect(1080,680,330,170),Hex("12202A"),Hex("35474F"));
            string status=busy?"演出中":selection.PanelStatus;
            Label(1098,690,152,23,"本回合行动",16,Gold);
            Label(1245,690,147,23,status,13,busy?Muted:Cyan,TextAnchor.MiddleRight);
            string[] labels={"1 角色","2 技能","3 目标"};
            for(int i=0;i<3;i++) Label(1098+i*100,718,90,22,labels[i],13,!busy&&selection.ActiveStep==i?Gold:selection.Prepared||selection.Committed||selection.AllArranged?Cyan:Muted);
            Label(1098,746,294,34,busy?"正在按现有速度规则播放行动。":selection.PanelHint,13,Pale);
            Label(1098,783,294,22,"已完成安排："+(busy?roundPlanCount:shown.Plans.Count)+" 项",12,Muted);
            bool open=!busy&&!auto&&!help&&shown.Outcome=="";
            GUI.enabled=open&&(selection.Prepared?selection.CanPlayPrepared:selection.CanPrepare);
            if(Btn(new Rect(1098,812,188,28),busy?"正在演出":selection.Prepared?"演示一回合":"准备完成",true)) ActivatePrimary();
            GUI.enabled=open;
            if(selection.Prepared) { if(Btn(new Rect(1294,812,98,28),"调整安排")) ResumePlanning(); }
            else if(busy) { GUI.enabled=!help; if(Btn(new Rect(1294,812,98,28),"跳过演出")) Skip(); }
            else if(selection.CanUndo) { if(Btn(new Rect(1294,812,98,28),"撤销安排")) CancelPlan(); }
            GUI.enabled=true;
        }
        void DrawStage()
        {
            Rect stage=new Rect(30,110,1380,407); Panel(stage,Hex("12202A"),Hex("35474F"));
            for(int i=0;i<12;i++) { float x=65+i*113; Fill(new Rect(x,138,38,260),Hex("152630")); Fill(new Rect(x+9,145,3,220),Hex("21333C")); }
            Fill(new Rect(31,378,1378,138),Hex("0D1922"));
            Line(new Vector2(31,414),new Vector2(1408,414),Hex("3F4A47"),2);
            for(int i=0;i<8;i++) Line(new Vector2(50+i*200,516),new Vector2(470+i*70,378),Hex("1C2D34"),1);
            Label(55,126,400,27,"NORTH TERMINAL  /  07",12,Muted);
            Label(1110,126,260,27,current!=null&&current.Speed>0?"当前结算速度  "+current.Speed:"敌方计划行动已公开",12,Muted);
            for(int i=0;i<3;i++) DrawUnit(true,i);
            for(int i=0;i<2;i++) DrawUnit(false,i);

            if(current!=null&&current.Coin!=null)DrawCoinPanel(current.Coin,current.Type,phase,current.Damage);
        }
        void DrawUnit(bool allied,int index)
        {
            Unit u=(allied?shown.Heroes:shown.Enemies)[index];
            float x=CombatX(allied,index), y=370;
            bool selected=allied?hero==index:selection.LastEnemy==index;
            bool validTarget=!allied&&Interactive&&selection.CanTarget(index);
            if(current!=null && ((current.Type=="clash"&&(allied?current.Hero==index:current.Enemy==index)) || (current.Type=="strike"&&current.Allied==allied&&current.Source==index)))
                x+=(allied?1:-1)*ImpactTravel(phase);
            if(current!=null&&current.Type=="strike"&&current.Allied!=allied&&current.Target==index)x+=(allied?-1:1)*ImpactRecoil(phase);
            Color tint=u.Hp<=0?Hex("35414A"):allied?(index==2?Cyan:Gold):Red;
            if(!allied&&Interactive&&selection.WaitingForTarget&&!validTarget) tint=Color.Lerp(tint,Hex("35414A"),0.75f);
            if(allied&&selected) Outline(new Rect(x-61,y-127,128,169),Gold,3);
            if(validTarget)
            {
                Rect targetRect=new Rect(x-66,y-130,140,175);
                bool hover=targetRect.Contains(Event.current.mousePosition);
                Outline(targetRect,hover?Gold:Cyan,hover?4:2);
                Fill(new Rect(x-82,y+29,172,23),Hex("0D1922"));
                Label(x-76,y+29,160,23,BattleRules.CanClash(shown,hero,index)?"点击 · 拼点 / 迎击":"点击 · 单方面攻击",12,hover?Gold:Cyan,TextAnchor.MiddleCenter);
            }
            Fill(new Rect(x-30,y+29,76,8),Hex("071018"));
            if(selected) Line(new Vector2(x-42,y+42),new Vector2(x+44,y+42),tint,3);
            // Original silhouettes assembled from geometric strokes, no third-party art.
            Fill(new Rect(x-15,y-119,31,32),tint);
            Fill(new Rect(x-25,y-81,51,66),Color.Lerp(tint,Hex("192630"),0.65f));
            Line(new Vector2(x-10,y-22),new Vector2(x-22,y+27),tint,12);
            Line(new Vector2(x+10,y-22),new Vector2(x+27,y+27),tint,12);
            Line(new Vector2(x-21,y-69),new Vector2(x-43,y-16),tint,9);
            Line(new Vector2(x+21,y-69),new Vector2(x+46,y-38),tint,9);
            Line(new Vector2(x+40,y-25),new Vector2(x+(allied?81:-42),y-103),Pale,4);
            Label(x-69,401,151,27,u.Name,17,selected?Gold:Pale,TextAnchor.MiddleCenter);
            Fill(new Rect(x-60,432,135,5),Hex("25353D")); Fill(new Rect(x-60,432,135*(float)u.Hp/u.MaxHp,5),allied?Cyan:Red);
            Label(x-70,439,155,20,u.Hp+" / "+u.MaxHp,11,Muted,TextAnchor.MiddleCenter);
            DrawUnitEffects(allied,index);
            if(!busy){
            Label(x-70,150,155,28,"速度 "+u.Speed+"  ["+u.MinSpeed+"–"+u.MaxSpeed+"]",15,allied?Cyan:Gold,TextAnchor.MiddleCenter);
            if(allied)
            {
                var plan=shown.Plans.Find(p=>p.Hero==index);
                string status=u.Hp<=0?"失去战斗能力":u.Acted?"本回合已行动":plan==null?u.Role+" · 待安排":PlanDescription(shown,plan);
                Label(x-78,183,171,62,status,12,u.Acted?Muted:Cyan,TextAnchor.MiddleCenter);
            }
            else
            {
                string intent=u.Hp<=0?"已击败":u.Spent?"行动已消耗":u.Intent+" → "+(u.Target>=0?shown.Heroes[u.Target].Name:"—");
                Label(x-100,182,210,28,intent,13,u.Spent?Muted:Red,TextAnchor.MiddleCenter);
                int receiver=BattleRules.ClashHero(shown,index);
                Label(x-100,211,210,32,u.Hp<=0?"已退场":u.Spent?"本次行动已结束":receiver>=0?"最终拼点 → "+shown.Heroes[receiver].Name:"无人拼点 / 将单方面攻击",12,receiver>=0?Cyan:Muted,TextAnchor.MiddleCenter);
            }
            }
            GUI.enabled=Interactive&&(allied?selection.CanSelectHero(index):validTarget);
            if(GUI.Button(new Rect(x-67,y-130,144,174),GUIContent.none,GUIStyle.none)) { if(allied) SelectHero(index); else SelectEnemy(index); }
            GUI.enabled=true;
        }
        string PlanDescription(BattleState state,PlannedAction plan)
        {
            Skill skill=BattleRules.GetSkill(state.Hand[plan.Card]);
            if(skill.Guard) return skill.Name+"\n防御 +9";
            if(state.Enemies[plan.Enemy].Hp<=0) return skill.Name+"\n目标已退场 / 将取消";
            return skill.Name+" → "+state.Enemies[plan.Enemy].Name+"\n"+(BattleRules.ClashHero(state,plan.Enemy)==plan.Hero?"拼点":"单方面攻击");
        }
        void DrawCard(int index,bool interactive)
        {
            Skill s=BattleRules.GetSkill(shown.Hand[index]); float x=32+index*208,y=card==index?637:645;
            bool available=selection.SkillError(index)=="";
            Rect r=new Rect(x,y,195,205); Panel(r,!available?Hex("111C24"):card==index?Hex("293436"):Hex("192630"),card==index?Gold:Hex("3C4C51"));
            Label(x+14,y+10,115,25,s.Tag.ToUpper(),12,Cyan);
            Label(x+147,y+5,34,36,s.Cost.ToString(),27,Gold,TextAnchor.MiddleCenter);
            Label(x+14,y+45,165,38,s.Name,25,Pale);
            Line(new Vector2(x+15,y+90),new Vector2(x+180,y+90),Hex("415058"),1);
            Label(x+14,y+97,167,30,s.Guard?"盾  +9":"初始 "+s.Base+" · "+s.Coins+" 枚",20,Gold);
            Label(x+14,y+133,170,27,s.Guard?"防御 / 本回合":"拼币 +"+s.ClashCoinPower+" / 攻币 +"+s.AttackCoinPower,12,Cyan);
            var reservation=shown.Plans.Find(p=>p.Card==index);
            string cardNote=selection.Prepared?(reservation==null?"":"已锁定给 "+shown.Heroes[reservation.Hero].Name):!available?selection.SkillError(index):reservation==null?s.Flavor:"已预留给 "+shown.Heroes[reservation.Hero].Name;
            Label(x+14,y+175,167,28,cardNote,11,!available?Muted:reservation==null?Muted:Gold);
            if(!available) Fill(new Rect(x+1,y+1,193,168),new Color(0.03f,0.05f,0.07f,0.48f));
            GUI.enabled=interactive&&available;
            if(GUI.Button(r,new GUIContent("",available?s.Description:selection.SkillError(index)),GUIStyle.none)) SelectSkill(index);
            GUI.enabled=true;
        }
        void DrawResult()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.72f)); Panel(new Rect(450,300,540,300),Hex("12202A"),Gold);
            bool win=shown.Outcome=="victory";
            Label(480,331,480,55,win?"VICTORY / 战斗胜利":"DEFEAT / 战斗失败",30,win?Gold:Red,TextAnchor.MiddleCenter);
            Label(485,403,470,70,"第 "+shown.Turn+" 回合  ·  剩余 "+shown.Cost+" cost\n"+(win?"废站重新归于寂静。小队继续向前。":"余烬未灭，再次整队出发。"),17,Pale,TextAnchor.MiddleCenter);
            if(Btn(new Rect(570,517,300,48),"以相同种子重新开始",true)) Restart();
        }
        void DrawHelp()
        {
            Fill(new Rect(0,0,1440,900),new Color(0,0,0,0.8f)); Panel(new Rect(330,165,780,570),Hex("12202A"),Gold);
            Label(370,193,700,50,"操作与规则",27,Gold);
            Label(370,255,700,390,"点击己方角色 → 技能 → 高亮敌人完成安排。守夜自动对自身安排，切换角色会清除待选技能，Esc 取消目标选择。保留共享手牌与撤销。\n\n至少有一项有效安排且没有待选目标时，点击准备完成锁定；按钮切换为演示一回合，再点击才付费并按速度统一执行。已准备可返回调整，其余成员按原规则待机。\n\n速度不低于敌人可以主动拼点；被敌人点名者可以低速迎击。多人接同一次攻击，以最后一次有效指定为准。低速仍能攻击高速敌人，未配对的攻击单方面执行。\n\n拼点按双方较高速度执行。同速各场战斗独立结算，按我方成员从左到右、再敌方从左到右的固定顺序执行。每次行动仅使用一次。护盾按自身速度生效；角色或目标退场取消后续对应行动，不转移目标、不退费。\n\n初始 9 cost，每人一次、全队最多三张。拼点失败退实付费用的一半，向下取整；首次拼点获胜 +1。回合结束 +3、清盾、刷新速度并抽五张。拼点每轮重投全部余币；平局不破币，直到出现胜负。攻击每币一击；正面币威力逐币累计，反面保留累计值。本次技能结束后清零。",17,Pale);
            if(Btn(new Rect(590,665,260,42),"返回战斗",true)) help=false;
        }
        bool Btn(Rect r,string label,bool selected=false)
        {
            Color old=GUI.backgroundColor; GUI.backgroundColor=selected?Gold:Hex("35474F"); bool pressed=GUI.Button(r,label,button); GUI.backgroundColor=old; return pressed;
        }
        void Label(float x,float y,float w,float h,string value,int size,Color color,TextAnchor align=TextAnchor.UpperLeft)
        { text.fontSize=size; text.normal.textColor=color; text.alignment=align; GUI.Label(new Rect(x,y,w,h),value,text); }
        static Color Hex(string value) { Color c; ColorUtility.TryParseHtmlString("#"+value,out c); return c; }
        static void Fill(Rect r,Color color) { Color old=GUI.color; GUI.color=color; GUI.DrawTexture(r,Texture2D.whiteTexture); GUI.color=old; }
        static void Panel(Rect r,Color fill,Color border) { Fill(r,border); Fill(new Rect(r.x+1,r.y+1,r.width-2,r.height-2),fill); }
        static void Outline(Rect r,Color color,float width)
        { Fill(new Rect(r.x,r.y,r.width,width),color); Fill(new Rect(r.x,r.yMax-width,r.width,width),color); Fill(new Rect(r.x,r.y,width,r.height),color); Fill(new Rect(r.xMax-width,r.y,width,r.height),color); }
        static void Line(Vector2 a,Vector2 b,Color color,float width)
        {
            Matrix4x4 old=GUI.matrix;
            GUI.matrix=old*Matrix4x4.TRS(new Vector3(a.x,a.y,0),Quaternion.Euler(0,0,Mathf.Atan2(b.y-a.y,b.x-a.x)*Mathf.Rad2Deg),Vector3.one);
            Fill(new Rect(0,-width/2,(b-a).magnitude,width),color); GUI.matrix=old;
        }
    }
}




