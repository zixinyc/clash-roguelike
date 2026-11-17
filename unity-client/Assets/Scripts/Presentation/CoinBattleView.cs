using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        Texture2D coinDisc;Vector2 coinLogScroll;int coinLogCount;string coinLogLast="";
        string CoinHint(CoinStep c,string type)
        {
            if(type=="clash_end")return "最终拼点胜者："+(c.FinalWinner==0?c.Left.Name:c.Right.Name)+"。只有胜方以余币攻击。";
            if(type=="attack_end")return c.Left.Name+"："+c.AttackIndex+" 次攻击结束，累计原始伤害 "+c.TotalRawDamage+"，硬币已用尽。";
            if(c.Type=="clash")return "第 "+c.Round+" 轮："+c.LeftPower+" 对 "+c.RightPower+"；"+(c.Winner<0?"平局，不损币，全部重投。":c.Winner==0?"敌方失去 1 枚硬币。":"我方失去 1 枚硬币。");
            return c.Left.Name+" 第 "+c.AttackIndex+" / "+c.AttackBudget+" 击 · "+(c.Heads?"正面":"反面")+" · 本次原始 "+c.RawDamage+" · 余币 "+c.RemainingAttackCoins;
        }
        void CoinToken(Vector2 p,bool heads,float size,float animation,bool lost=false)
        {
            if(coinDisc==null)
            {
                const int n=64;var pixels=new Color[n*n];for(int y=0;y<n;y++)for(int x=0;x<n;x++){float d=new Vector2(x-31.5f,y-31.5f).magnitude;pixels[y*n+x]=new Color(1,1,1,Mathf.Clamp01(31-d));}
                coinDisc=new Texture2D(n,n,TextureFormat.RGBA32,false);coinDisc.SetPixels(pixels);coinDisc.Apply();
            }
            bool rolling=animation<.38f;float width=size*(rolling?Mathf.Max(.12f,Mathf.Abs(Mathf.Cos(animation*24))):1);
            Color c=lost?Red:rolling?Gold:heads?Gold:Hex("62757E");Color previous=GUI.color;GUI.color=c;GUI.DrawTexture(new Rect(p.x-width/2,p.y-size/2,width,size),coinDisc);GUI.color=previous;
            if(width>size*.65f)Label(p.x-size/2,p.y-size*.38f,size,size*.8f,rolling?"?":heads?"正":"反",(int)(size*.43f),Hex("101920"),TextAnchor.MiddleCenter);
            if(lost&&!rolling){Line(p+new Vector2(-size*.45f,-size*.45f),p+new Vector2(size*.45f,size*.45f),Red,2);Line(p+new Vector2(-size*.45f,size*.45f),p+new Vector2(size*.45f,-size*.45f),Red,2);}
        }
        void CoinFaces(bool[] faces,float x,float y,float width,float animation,bool lose)
        {
            int count=Math.Min(8,faces.Length);float size=25,gap=29,start=x+(width-count*gap)/2;
            for(int i=0;i<count;i++)CoinToken(new Vector2(start+i*gap+gap/2,y),faces[i],size,animation,lose&&i==faces.Length-1);
            if(faces.Length>count)Label(x,y+17,width,20,"共 "+faces.Length+" 枚 · 正面 "+faces.Count(z=>z),11,Muted,TextAnchor.MiddleCenter);
        }
        void DrawCoinPanel(CoinStep c,string type,float animation,int damage)
        {
            const float x=493,y=120,w=522,h=350;Panel(new Rect(x,y,w,h),Hex("0B1721"),Gold);bool done=type=="clash_end"||type=="attack_end";
            if(c.Type=="clash")
            {
                Label(x+15,y+12,w-30,29,done?"拼点结束 / 最终胜者":"拼点 / 第 "+c.Round+" 轮",20,Gold,TextAnchor.MiddleCenter);
                Label(x+12,y+53,241,30,c.Left.Name,19,Cyan,TextAnchor.MiddleCenter);Label(x+269,y+53,241,30,c.Right.Name,19,Red,TextAnchor.MiddleCenter);
                if(done)
                {
                    string name=c.FinalWinner==0?c.Left.Name:c.Right.Name;Label(x+30,y+122,w-60,55,name+" 获胜",28,c.FinalWinner==0?Gold:Red,TextAnchor.MiddleCenter);
                    Label(x+30,y+199,w-60,32,"剩余硬币  "+c.LeftRemaining+"  /  "+c.RightRemaining,21,Pale,TextAnchor.MiddleCenter);
                    Label(x+30,y+251,w-60,55,"败方不能攻击。\n胜方每枚剩余硬币对应一次攻击。",15,Muted,TextAnchor.MiddleCenter);return;
                }
                Label(x+10,y+86,243,23,"初始 "+c.LeftBase+"   /   拼币 +"+c.LeftClashPower,13,Muted,TextAnchor.MiddleCenter);
                Label(x+269,y+86,243,23,"初始 "+c.RightBase+"   /   拼币 +"+c.RightClashPower,13,Muted,TextAnchor.MiddleCenter);
                CoinFaces(c.LeftFaces,x+7,y+139,249,animation,c.Winner==1);CoinFaces(c.RightFaces,x+266,y+139,249,animation,c.Winner==0);
                Label(x+12,y+169,241,48,animation<.38f?"投掷中":c.LeftPower.ToString(),34,c.Winner==0?Gold:Pale,TextAnchor.MiddleCenter);Label(x+269,y+169,241,48,animation<.38f?"投掷中":c.RightPower.ToString(),34,c.Winner==1?Red:Pale,TextAnchor.MiddleCenter);
                Label(x+12,y+218,241,24,c.LeftBase+" + "+c.LeftFaces.Count(z=>z)+" × "+c.LeftClashPower,13,Muted,TextAnchor.MiddleCenter);
                Label(x+269,y+218,241,24,c.RightBase+" + "+c.RightFaces.Count(z=>z)+" × "+c.RightClashPower,13,Muted,TextAnchor.MiddleCenter);
                Label(x+18,y+254,w-36,30,c.Winner<0?"平局 · 双方均不损币":c.Winner==0?c.Right.Name+" 失败 · 损失 1 枚硬币":c.Left.Name+" 失败 · 损失 1 枚硬币",17,c.Winner<0?Cyan:Gold,TextAnchor.MiddleCenter);
                Label(x+20,y+290,w-40,25,"余币  "+c.LeftBefore+" → "+c.LeftRemaining+"      /      "+c.RightBefore+" → "+c.RightRemaining,15,Pale,TextAnchor.MiddleCenter);
                Label(x+15,y+321,w-30,23,c.FinalWinner>=0?"一方硬币归零，拼点立即结束。":"下一轮：从初始点数重算，重投双方全部余币。",12,Muted,TextAnchor.MiddleCenter);
            }
            else
            {
                Label(x+15,y+12,w-30,29,done?"攻击结束 / 硬币已消耗":"攻击 / 独立投掷一枚硬币",20,Gold,TextAnchor.MiddleCenter);
                Label(x+20,y+54,w-40,30,c.Left.Name+"  ·  第 "+c.AttackIndex+" / "+c.AttackBudget+" 击",20,Pale,TextAnchor.MiddleCenter);
                CoinToken(new Vector2(x+w/2,y+125),c.Heads,47,done?1:animation);
                Label(x+30,y+161,w-60,26,"初始 "+c.AttackBase+"  /  攻击硬币 +"+c.AttackCoinPower+"  /  "+(c.Heads?"正面":"反面"),14,Muted,TextAnchor.MiddleCenter);
                Label(x+15,y+195,w-30,42,"本次原始伤害  "+c.RawDamage,29,Gold,TextAnchor.MiddleCenter);
                Label(x+20,y+240,w-40,24,c.AttackBase+" + "+(c.Heads?c.AttackCoinPower:0)+(c.RawModifier!=0?" + 效果 "+c.RawModifier:"")+" = "+c.RawDamage+(done?"   /   硬币已消耗":"    /    实际伤害 "+damage),13,Muted,TextAnchor.MiddleCenter);
                Label(x+18,y+280,w-36,29,"累计 "+c.AttackIndex+" 次  ·  累计原始 "+c.TotalRawDamage,18,Cyan,TextAnchor.MiddleCenter);
                Label(x+20,y+318,w-40,24,"剩余攻击硬币 "+c.RemainingAttackCoins+"  ·  每击从初始点数重新计算",12,Muted,TextAnchor.MiddleCenter);
            }
        }
        void DrawBattleJournal()
        {
            Panel(new Rect(1080,535,330,132),Hex("111C24"),Hex("35474F"));Label(1094,541,302,23,"战斗记录 · 可滚动查看",13,Gold);
            text.fontSize=11;text.wordWrap=true;var heights=log.Select(s=>Math.Max(22,text.CalcHeight(new GUIContent(s),283)+6)).ToArray();float total=heights.Sum();string last=log.LastOrDefault()??"";
            if(coinLogCount!=log.Count||coinLogLast!=last){coinLogCount=log.Count;coinLogLast=last;coinLogScroll.y=total;}
            coinLogScroll=GUI.BeginScrollView(new Rect(1090,569,310,89),coinLogScroll,new Rect(0,0,289,total));float top=0;
            for(int i=0;i<log.Count;i++){Label(1,top,283,heights[i],log[i],11,i==log.Count-1?Pale:Muted);top+=heights[i];}GUI.EndScrollView();
        }
    }
}
