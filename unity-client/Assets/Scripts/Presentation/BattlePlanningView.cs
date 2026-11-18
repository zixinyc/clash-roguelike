using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        readonly SkillGroups skillGroups=new SkillGroups();bool loadoutSelecting;string[] battleAvailableSkills;
        string CharacterKey(int actor){var u=portRules.State.Heroes[actor];return string.IsNullOrEmpty(u.CharacterId)?u.Name:u.CharacterId;}
        string[] ActorSkills(int actor){return battleAvailableSkills.Where(k=>PortContent.Card(k).Owner==actor).ToArray();}
        void BeginSkillGroupSelection(){battleAvailableSkills=(string[])portRules.State.Hand.Clone();loadoutSelecting=true;}
        bool ConfirmSkillGroups()
        {
            var chosen=battleAvailableSkills.Where(k=>PortContent.Card(k).Owner<0).ToList();
            for(int actor=0;actor<3;actor++)chosen.AddRange(skillGroups.Cards(CharacterKey(actor),ActorSkills(actor)));
            if(!portRules.ConfigureLoadout(chosen))return false;loadoutSelecting=false;portShown=portRules.Snapshot();portNotice="技能组已锁定，开始安排。";return true;
        }
        void DrawSkillGroupSelection()
        {
            Label(35,24,1200,48,"开战准备 / 角色技能组",30,Gold);
            Label(38,79,1320,48,"每名角色有独立A/B方案，可勾选携带技能；至少保留一张专属技能。通用牌沿用原有手牌。确认后本场锁定。",16,Pale);
            for(int actor=0;actor<3;actor++)
            {
                float x=38+actor*460;var available=ActorSkills(actor);string key=CharacterKey(actor);int group=skillGroups.Current(key,available);var selected=skillGroups.Cards(key,available);
                Panel(new Rect(x,155,440,585),Hex("12202A"),HeroPlanColor(actor));Label(x+20,174,400,40,portShown.Heroes[actor].Name,25,HeroPlanColor(actor));
                if(Btn(new Rect(x+20,229,192,37),"方案 A",group==0))skillGroups.Select(key,available,0);
                if(Btn(new Rect(x+224,229,192,37),"方案 B",group==1))skillGroups.Select(key,available,1);
                for(int i=0;i<available.Length;i++)
                {
                    var card=PortContent.Card(available[i]);float y=289+i*89;bool equipped=selected.Contains(card.Id);
                    if(Btn(new Rect(x+20,y,396,36),(equipped?"✓ ":"○ ")+card.Name+"  ·  "+card.Cost+" cost",equipped))skillGroups.Toggle(key,available,card.Id);
                    Label(x+27,y+40,382,40,card.Description,12,Muted);
                }
                Label(x+20,666,390,25,"本方案携带 "+selected.Length+" / "+available.Length+" 张专属技能",14,Cyan);
                if(Btn(new Rect(x+20,700,396,28),"本方案恢复全部技能"))skillGroups.Reset(key,available);
            }
            Label(40,768,900,55,"同一角色的方案跨遭遇保留在本次程序会话中；每次开战都可重新选择。当前未保存到磁盘。选择技能组不消耗生命或cost。",14,Muted);
            if(Btn(new Rect(1020,778,380,54),"确认技能组 · 进入战斗",true))ConfirmSkillGroups();
        }
        static Color HeroPlanColor(int actor){return actor==0?Hex("76CCD7"):actor==1?Hex("E4B66B"):Hex("BBA0E5");}
        ClashForecast ForecastFor(PortSlot hero,PortSlot enemy)
        {
            bool hidden=portRules.State.Phase=="response";
            var candidates=hidden?PortContent.Cards.Where(c=>c.Owner<0&&c.Category==enemy.Category&&c.Coins>0):new[]{PortContent.Card(enemy.Key)};
            return ClashForecast.Create(PortContent.Card(hero.Key),candidates,hidden);
        }
        void DrawPlannedClashes()
        {
            int lane=0;var badges=new System.Collections.Generic.List<Action>();
            foreach(var hero in portShown.HeroSlots.Where(s=>s.Active&&PortContent.Card(s.Key).TargetsEnemy).OrderBy(s=>s.Unit).ThenBy(s=>s.Category))
            {
                if(hero.Target<0||hero.Target>=portShown.EnemySlots.Count)continue;var enemy=portShown.EnemySlots[hero.Target];bool paired=portRules.PairFor(enemy.Id)==hero.Id;
                Color color=HeroPlanColor(hero.Unit);if(!paired)color.a=.45f;
                Vector2 start=new Vector2(CombatX(true,hero.Unit)+74,180+hero.Category*25),end=new Vector2(CombatX(false,enemy.Unit)-78,180+enemy.Category*25);
                Vector2 c1=start+new Vector2(160,140+lane*13),c2=end+new Vector2(-160,140+lane*13);Vector2 previous=start;
                for(int i=1;i<=36;i++){float t=i/36f,u=1-t;Vector2 next=u*u*u*start+3*u*u*t*c1+3*u*t*t*c2+t*t*t*end;if(paired||i%2==0)Line(previous,next,color,paired?3:2);previous=next;}
                Line(end,end+new Vector2(-11,-5),color,2);Line(end,end+new Vector2(-11,5),color,2);
                Rect badge=new Rect(552+(lane%2)*199,255+(lane/2)*63,190,56);
                var forecast=paired?ForecastFor(hero,enemy):null;string risk=paired?forecast.Risk+" · 预估":"单方面";
                badges.Add(()=>{
                Panel(badge,Hex("102029"),color);
                Label(badge.x+6,badge.y+2,178,22,PortHeroName(hero.Unit)+" · "+risk,12,paired?forecast.Risk=="劣势"?Red:forecast.Risk=="优势"?Cyan:Gold:Muted,TextAnchor.MiddleCenter);
                string opposing=portShown.Phase=="response"?"未揭示·"+categoryNames[enemy.Category]:PortContent.Card(enemy.Key).Name;
                Label(badge.x+4,badge.y+25,182,28,PortContent.Card(hero.Key).Name+" → "+opposing,11,Pale,TextAnchor.MiddleCenter);
                if(forecast!=null){string hint="基础牌面预估，非胜率；未计入被动、状态或后续损币。我方 "+forecast.OwnMin+"–"+forecast.OwnMax+"，敌方公开类别范围 "+forecast.EnemyMin+"–"+forecast.EnemyMax+"。隐藏时不读取具体技能。";GUI.Label(badge,new GUIContent("",hint),GUIStyle.none);}
                });
                lane++;
            }
            foreach(var draw in badges)draw();
            if(lane==0)Label(560,320,350,65,"选择角色 → 技能 → 敌方行动\n彩色连线将在安排后出现",15,Muted,TextAnchor.MiddleCenter);
            Label(557,484,380,31,"青 / 金 / 紫：队员 · 虚线：单方面\n风险为基础牌面估计，隐藏对手按类别范围",10,Muted);
        }
    }
}
