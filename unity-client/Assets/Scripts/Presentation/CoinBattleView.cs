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
        { DrawCompactCoins(c,type,animation,damage); }
        void DrawBattleJournal()
        {
            bool port=adventureMode&&portRules!=null;float journalY=port?527:535,journalHeight=port?112:132;
            Panel(new Rect(1080,journalY,330,journalHeight),Hex("111C24"),Hex("35474F"));Label(1094,journalY+6,302,23,"战斗记录 · 可滚动查看",13,Gold);
            text.fontSize=11;text.wordWrap=true;var heights=log.Select(s=>Math.Max(22,text.CalcHeight(new GUIContent(s),283)+6)).ToArray();float total=heights.Sum();string last=log.LastOrDefault()??"";
            if(coinLogCount!=log.Count||coinLogLast!=last){coinLogCount=log.Count;coinLogLast=last;coinLogScroll.y=total;}
            coinLogScroll=GUI.BeginScrollView(new Rect(1090,journalY+34,310,journalHeight-43),coinLogScroll,new Rect(0,0,289,total));float top=0;
            for(int i=0;i<log.Count;i++){Label(1,top,283,heights[i],log[i],11,i==log.Count-1?Pale:Muted);top+=heights[i];}GUI.EndScrollView();
        }
    }
}

