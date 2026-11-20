
using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        sealed class InspectedSkill
        {
            public string Name,Stats,Description;
        }

        InspectedSkill[] enemySkillDetails;
        string enemySkillName,enemySkillCaption;
        Vector2 enemySkillScroll;

        void CloseEnemySkillDetails(){enemySkillDetails=null;}

        void InspectSkills(string enemyName,string caption,IEnumerable<InspectedSkill> skills)
        {
            enemySkillName=enemyName;
            enemySkillCaption=caption;
            enemySkillDetails=skills.ToArray();
            enemySkillScroll=Vector2.zero;
        }

        static InspectedSkill PreviewSkill(PortCard card)
        {
            string coins=card.Coins==0?"":CoinPreview(card.CoinData);
            return new InspectedSkill{Name=card.Name,Stats=card.Cost+" cost"+coins,Description=card.Description};
        }

        static string CoinPreview(CoinSkill coin)
        {
            return " · 初始 "+coin.BasePower+" · "+coin.CoinCount+" 币"+
                " · 拼 "+coin.ClashCoinPower+" / 攻 "+coin.AttackCoinPower;
        }

        void ShowCampaignEnemySkills(CampaignDuel duel,int seat,int actor)
        {
            var unit=duel.Sides[seat].Units[actor];
            var keys=duel.VisibleSkillCatalog(seat,actor).ToArray();
            string caption=PatchouliSkills.IsSummon(unit)?"自动施放的单元素技能":
                duel.Recruitment?keys.Length+" 张符卡 · 每回合最多 "+duel.Slots(seat,actor)+" 张":"角色资料 · 专属与通用技能";
            InspectSkills(unit.Name,caption,keys.Select(PortContent.Card).Select(PreviewSkill));
        }

        void ShowPortEnemySkills(int index)
        {
            var enemy=portShown.Enemies[index];
            var cards=Enumerable.Range(0,3).Select(category=>PreviewSkill(PortContent.Card(portRules.EnemySkillForCategory(index,category)))).ToArray();
            if(portShown.Kinds[index]=="warden")cards[2].Description="自身获得 14 护盾。";
            if(portShown.Kinds[index]=="priest")cards[2].Description="自身获得 9 护盾，其他存活队友各获得 6 护盾。";
            InspectSkills(enemy.Name,"可能使用的技能",cards);
        }

        void ShowLegacyEnemySkill(Unit enemy)
        {
            var coin=new CoinSkill(enemy.Intent,enemy.Base,enemy.ClashCoinPower,enemy.AttackCoinPower,enemy.Coins);
            InspectSkills(enemy.Name,"攻击技能",new[]{new InspectedSkill{Name=coin.Name,Stats=CoinPreview(coin).TrimStart(' ','·'),Description=""}});
        }

        bool DrawEnemySkillDetails(Rect panel)
        {
            var rows=enemySkillDetails;
            if(rows==null)return false;
            Panel(panel,Hex("2B121A"),Hex("703541"));
            Label(panel.x+12,panel.y+9,panel.width-82,28,enemySkillName,17,Pale);
            if(Btn(new Rect(panel.xMax-58,panel.y+8,49,28),"关闭")){CloseEnemySkillDetails();return true;}
            Label(panel.x+12,panel.y+38,panel.width-24,26,enemySkillCaption,13,Muted);
            float width=panel.width-44,height=panel.height-73;
            text.fontSize=13;
            var heights=rows.Select(row=>Math.Max(14,text.CalcHeight(new GUIContent(row.Description),width-16))+53).ToArray();
            enemySkillScroll=GUI.BeginScrollView(new Rect(panel.x+10,panel.y+63,panel.width-20,height),
                enemySkillScroll,new Rect(0,0,width,Math.Max(height-1,heights.Sum())));
            float y=0;
            for(int i=0;i<rows.Length;i++)
            {
                var row=rows[i];
                Fill(new Rect(0,y,width,heights[i]-4),Hex("48202A"));
                Label(8,y+3,width-16,24,row.Name,15,Pale);
                Label(8,y+25,width-16,21,row.Stats,12,Cyan);
                Label(8,y+45,width-16,heights[i]-49,row.Description,13,Muted);
                y+=heights[i];
            }
            GUI.EndScrollView();
            return true;
        }
    }
}
