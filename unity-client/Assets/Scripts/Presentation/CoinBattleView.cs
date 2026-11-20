using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        Texture2D coinDisc;
        bool battleJournalOpen,battleJournalScrollToEnd;
        Vector2 battleJournalScroll;
        Action battleExit;
        string battleExitPrompt;
        bool BattleOverlayOpen {get{return battleJournalOpen||battleExit!=null;}}

        void CloseBattleOverlay(){battleJournalOpen=false;battleExit=null;CloseEnemySkillDetails();}

        void OpenBattleJournal()
        {
            CancelTargetLine();
            battleJournalScrollToEnd=true;
            battleJournalOpen=true;
        }

        void RequestBattleExit(Action exit,string confirmation)
        {
            CancelTargetLine();
            if(confirmation==null)exit();
            else{battleExitPrompt=confirmation;battleExit=exit;}
        }

        void ConfirmBattleExit()
        {
            var confirm=battleExit;
            CloseBattleOverlay();
            if(confirm!=null)confirm();
        }

        void DrawBattleButtons(Action exit,string confirmation=null,bool allowSpeed=true)
        {
            if(allowSpeed&&Btn(new Rect(1124,25,103,33),"演出 ×"+speed))speed=speed==1?2:speed==2?4:1;
            if(Btn(new Rect(1236,25,80,33),"记录"))OpenBattleJournal();
            if(Btn(new Rect(1325,25,85,33),"退出"))RequestBattleExit(exit,confirmation);
        }
        string CoinHint(CoinStep c,string type)
        {
            if(type=="clash_end")return "最终拼点胜者："+(c.FinalWinner==0?c.Left.Name:c.Right.Name)+"。只有胜方以余币攻击。";
            if(type=="attack_end")return c.Left.Name+"："+c.AttackIndex+" 次攻击结束，累计原始伤害 "+c.TotalRawDamage+"，硬币已用尽。";
            if(c.Type=="clash")return "第 "+c.Round+" 轮："+c.LeftPower+" 对 "+c.RightPower+"；"+(c.Winner<0?"平局，不损币，全部重投。":c.Winner==0?"敌方失去 1 枚硬币。":"我方失去 1 枚硬币。");
            return c.Left.Name+" 第 "+c.AttackIndex+" / "+c.AttackBudget+" 击 · "+(c.Heads?"正面":"反面")+" · 硬币累计 +"+c.AttackAccumulated+" · 本次原始 "+c.RawDamage+" · 余币 "+c.RemainingAttackCoins;
        }
        void CoinToken(Vector2 p,bool heads,float size,float animation,bool lost=false)
        {
            if(coinDisc==null)
            {
                const int n=64;var pixels=new Color[n*n];for(int y=0;y<n;y++)for(int x=0;x<n;x++){float d=new Vector2(x-31.5f,y-31.5f).magnitude;pixels[y*n+x]=new Color(1,1,1,Mathf.Clamp01(31-d));}
                coinDisc=new Texture2D(n,n,TextureFormat.RGBA32,false);coinDisc.SetPixels(pixels);coinDisc.Apply();
            }
            bool rolling=animation<.38f;float width=size*(rolling?Mathf.Max(.12f,Mathf.Abs(Mathf.Cos(animation*24))):1);
            Color c=lost?Red:rolling?Gold:heads?Gold:Hex("A66D78");Color previous=GUI.color;GUI.color=c;GUI.DrawTexture(new Rect(p.x-width/2,p.y-size/2,width,size),coinDisc);GUI.color=previous;
            if(width>size*.65f)Label(p.x-size/2,p.y-size*.38f,size,size*.8f,rolling?"?":heads?"正":"反",(int)(size*.43f),Hex("271017"),TextAnchor.MiddleCenter);
            if(lost&&!rolling){Line(p+new Vector2(-size*.45f,-size*.45f),p+new Vector2(size*.45f,size*.45f),Red,2);Line(p+new Vector2(-size*.45f,size*.45f),p+new Vector2(size*.45f,-size*.45f),Red,2);}
        }
        void CoinFaces(bool[] faces,float x,float y,float width,float animation,bool lose)
        {
            int count=Math.Min(8,faces.Length);float size=25,gap=29,start=x+(width-count*gap)/2;
            for(int i=0;i<count;i++)CoinToken(new Vector2(start+i*gap+gap/2,y),faces[i],size,animation,lose&&i==faces.Length-1);
            if(faces.Length>count)Label(x,y+17,width,20,"共 "+faces.Length+" 枚 · 正面 "+faces.Count(z=>z),11,Muted,TextAnchor.MiddleCenter);
        }
        void DrawCoinPanel(CoinStep c,string type,float animation,int damage)
        { DrawCompactCoins(c,type,animation,damage); }
        bool DrawBattleOverlay(System.Collections.Generic.IEnumerable<string> history)
        {
            if(!BattleOverlayOpen)return false;
            if(battleExit!=null)
            {
                Panel(new Rect(435,286,570,250),Hex("4A202A"),Gold);
                Label(464,310,512,39,"退出战斗？",23,Gold);
                Label(464,369,512,66,battleExitPrompt,17,Pale);
                if(Btn(new Rect(464,464,210,42),"取消"))CloseBattleOverlay();
                if(Btn(new Rect(705,464,270,42),"确认退出",true))ConfirmBattleExit();
                return true;
            }
            Panel(new Rect(200,89,1040,704),Hex("2B121A"),Hex("703541"));
            Label(225,111,800,40,"战斗记录",24,Gold);
            if(Btn(new Rect(1325,25,85,33),"关闭"))CloseBattleOverlay();
            var rows=history.ToArray();
            if(rows.Length==0)Label(225,171,900,36,"暂无战斗记录",15,Muted);
            text.fontSize=15;
            var heights=rows.Select(line=>Math.Max(30,text.CalcHeight(new GUIContent(line),960)+8)).ToArray();
            float total=heights.Sum();
            if(battleJournalScrollToEnd){battleJournalScroll=new Vector2(0,Math.Max(0,total-590));battleJournalScrollToEnd=false;}
            battleJournalScroll=GUI.BeginScrollView(new Rect(225,171,982,590),battleJournalScroll,new Rect(0,0,961,Math.Max(590,total)));
            float y=0;
            for(int i=0;i<rows.Length;i++)
            {
                Label(0,y,960,heights[i],rows[i],15,i==rows.Length-1?Pale:Muted);
                y+=heights[i];
            }
            GUI.EndScrollView();
            return true;
        }
    }
}

