using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        readonly SkillGroups skillGroups=new SkillGroups();bool loadoutSelecting;string[] battleAvailableSkills;
        string CharacterKey(int actor){var u=portRules.State.Heroes[actor];return string.IsNullOrEmpty(u.CharacterId)?u.Name:u.CharacterId;}
        string[] ActorSkills(int actor){return battleAvailableSkills.Where(k=>portShown.Owns(actor,PortContent.Card(k))).ToArray();}
        void BeginSkillGroupSelection(){battleAvailableSkills=(string[])portRules.State.Hand.Clone();loadoutSelecting=true;}
        bool ConfirmSkillGroups()
        {
            var chosen=battleAvailableSkills.Where(k=>PortContent.Card(k).Owner<0).ToList();
            for(int actor=0;actor<3;actor++)
                if(portShown.Heroes[actor].MaxHp>0&&(!portShown.RecruitLockedSakuya||actor!=1))
                    chosen.AddRange(skillGroups.Cards(CharacterKey(actor),ActorSkills(actor)));
            if(!portRules.ConfigureLoadout(chosen))return false;loadoutSelecting=false;portShown=portRules.Snapshot();portNotice="技能组已锁定，开始安排。";return true;
        }
        void DrawSkillGroupSelection()
        {
            Label(35,24,1200,48,"开战准备 / 角色技能组",30,Gold);
            Label(38,79,1320,48,"每名角色有独立A/B方案，可勾选携带技能；每名角色可带 1–4 张专属技能。通用牌沿用原有手牌。确认后本场锁定。",16,Pale);
            for(int actor=0;actor<3;actor++)
            {
                if(portShown.Heroes[actor].MaxHp<=0||portShown.RecruitLockedSakuya&&actor==1)continue;
                float x=38+actor*460;var available=ActorSkills(actor);string key=CharacterKey(actor);int group=skillGroups.Current(key,available);var selected=skillGroups.Cards(key,available);
                Panel(new Rect(x,155,440,585),Hex("34161F"),HeroPlanColor(actor));Label(x+20,174,400,40,portShown.Heroes[actor].Name,25,HeroPlanColor(actor));
                if(Btn(new Rect(x+20,229,192,37),"方案 A",group==0))skillGroups.Select(key,available,0);
                if(Btn(new Rect(x+224,229,192,37),"方案 B",group==1))skillGroups.Select(key,available,1);
                for(int i=0;i<available.Length;i++)
                {
                    var card=PortContent.Card(available[i]);float y=281+i*Math.Min(89,374f/available.Length);bool equipped=selected.Contains(card.Id);
                    if(Btn(new Rect(x+20,y,396,29),(equipped?"✓ ":"○ ")+card.Name+"  ·  "+card.Cost+" cost",equipped))skillGroups.Toggle(key,available,card.Id);
                    Label(x+25,y+29,388,33,card.Description,12,Muted);
                }
                Label(x+20,666,390,25,"本方案携带 "+selected.Length+" / "+SkillGroups.MaxExclusiveCards+" 张专属技能",14,Cyan);
                if(Btn(new Rect(x+20,700,396,28),"本方案恢复默认技能"))skillGroups.Reset(key,available);
            }
            Label(40,768,900,55,"同一角色的方案跨遭遇保留在本次程序会话中；每次开战都可重新选择。当前未保存到磁盘。选择技能组不消耗生命或cost。",14,Muted);
            if(Btn(new Rect(1020,778,380,54),"确认技能组 · 进入战斗",true))ConfirmSkillGroups();
        }
        static Color HeroPlanColor(int actor){return actor==0?Hex("76CCD7"):actor==1?Hex("E4B66B"):Hex("BBA0E5");}

        object targetLineBattle;
        int targetLineActor;
        string targetLineSkill;

        void CancelTargetLine(){targetLineBattle=null;}
        void OnApplicationFocus(bool focused){if(!focused)CancelTargetLine();}

        bool UpdateTargetLine(Event input,bool pointerFree,object battle,int actor,string skill,Rect source,Rect alternateSource,
            Func<Vector2,bool,int?> targetAt,Action<int> commit)
        {
            if(targetLineBattle!=battle||targetLineActor!=actor||targetLineSkill!=skill)CancelTargetLine();
            if(input.type==EventType.MouseLeaveWindow||input.type==EventType.Ignore)CancelTargetLine();
            if(input.type==EventType.MouseDown&&input.button==0&&pointerFree&&
                (source.Contains(input.mousePosition)||alternateSource.Contains(input.mousePosition)))
            {
                targetLineBattle=battle;
                targetLineActor=actor;
                targetLineSkill=skill;
                input.Use();
            }
            else if(targetLineBattle!=null&&input.type==EventType.MouseDrag)input.Use();
            else if(targetLineBattle!=null&&input.type==EventType.MouseUp&&input.button==0)
            {
                var target=targetAt(input.mousePosition,input.shift);
                CancelTargetLine();
                if(target.HasValue)commit(target.Value);
                input.Use();
            }
            return targetLineBattle!=null;
        }

        static Rect PortPortraitRect(float x){return new Rect(x-67,240,144,174);}
        Rect PortSlotRect(bool allied,float x,int category)
        {
            float width=!allied&&portShown.Enemies.Count>2?130:150;
            return new Rect(x-width/2,168+category*25,width,23);
        }
        int? PortTargetAt(Vector2 pointer,bool unopposed)
        {
            foreach(var slot in portShown.EnemySlots)
                if(slot.Active&&!slot.Done&&PortSlotRect(false,CombatX(false,slot.Unit),slot.Category).Contains(pointer)&&PortTargetLegal(slot.Id))
                    return slot.Id;
            for(int unit=0;unit<portShown.Enemies.Count;unit++)
            {
                if(!PortPortraitRect(CombatX(false,unit)).Contains(pointer))continue;
                int target=PortraitTarget(unit,unopposed);
                if(target>=0)return target;
            }
            return null;
        }

        bool UpdatePortTargetLine(Event input,bool pointerFree)
        {
            if(portCard==""||portHero<0||portBusy||portPrepared||portShown.Outcome!="")
            {CancelTargetLine();return false;}
            float x=CombatX(true,portHero);
            return UpdateTargetLine(input,pointerFree,portRules,portHero,portCard,PortPortraitRect(x),
                PortSlotRect(true,x,portShown.HeroSlots[portSlot].Category),PortTargetAt,CommitPortTarget);
        }

        void DrawPortTargetLine()
        {
            var input=Event.current;
            bool dragging=UpdatePortTargetLine(input,GUIUtility.hotControl==0);
            if(portCard==""||portHero<0||portBusy||portPrepared||portShown.Outcome!="")return;
            float x=CombatX(true,portHero);
            var slot=portShown.HeroSlots[portSlot];
            var source=PortSlotRect(true,x,slot.Category);
            var anchor=new Vector2(source.xMax-10,source.center.y);
            Panel(source,Hex("172630"),Cyan);
            Label(source.x,source.y,source.width,source.height,PortContent.Card(portCard).Name,12,Pale,TextAnchor.MiddleCenter);
            if(!dragging||input.type!=EventType.Repaint)return;
            var pointer=input.mousePosition;
            var target=PortTargetAt(pointer,input.shift);
            var color=Muted;
            if(target.HasValue)
            {
                var enemy=portShown.EnemySlots[target.Value];
                color=portRules.CanClash(slot,enemy,portCard)?Cyan:Gold;
                var hitbox=enemy.Active?PortSlotRect(false,CombatX(false,enemy.Unit),enemy.Category):PortPortraitRect(CombatX(false,enemy.Unit));
                Outline(hitbox,color,3);
                pointer=new Vector2(hitbox.xMin,hitbox.center.y);
            }
            Line(anchor,pointer,color,3);
        }
        PortCard RevealedEnemyCard(PortSlot enemy)
        {
            if(!enemy.Active||!portRules.EnemySkillVisible(enemy.Id))return null;
            string key=portRules.State.EnemySlots[enemy.Id].Key;
            return string.IsNullOrEmpty(key)?null:PortContent.Cards.FirstOrDefault(card=>card.Id==key);
        }
        ClashForecast ForecastFor(PortSlot hero,PortSlot enemy)
        {
            var revealed=RevealedEnemyCard(enemy);
            var candidates=revealed==null?PortContent.Cards.Where(c=>c.Owner<0&&c.Category==enemy.Category&&c.Coins>0):new[]{revealed};
            return ClashForecast.Create(PortContent.Card(hero.Key),candidates,revealed==null);
        }
        void DrawPlannedClashes()
        {
            int lane=0;var badges=new System.Collections.Generic.List<Action>();
            foreach(var hero in portShown.HeroSlots.Where(s=>s.Active&&!string.IsNullOrEmpty(s.Key)&&PortContent.Card(s.Key).TargetsEnemy).OrderBy(s=>s.Unit).ThenBy(s=>s.Category))
            {
                if(hero.Target<0||hero.Target>=portShown.EnemySlots.Count)continue;var enemy=portShown.EnemySlots[hero.Target];bool paired=portRules.PairFor(enemy.Id)==hero.Id;
                Color color=HeroPlanColor(hero.Unit);if(!paired)color.a=.45f;
                Vector2 start=new Vector2(CombatX(true,hero.Unit)+74,180+hero.Category*25),end=new Vector2(CombatX(false,enemy.Unit)-78,180+enemy.Category*25);
                Vector2 c1=start+new Vector2(160,140+lane*13),c2=end+new Vector2(-160,140+lane*13);Vector2 previous=start;
                float sweep=UiClashSweepProgress;
                for(int i=1;i<=36;i++){float t=i/36f,u=1-t;Vector2 next=u*u*u*start+3*u*u*t*c1+3*u*t*t*c2+t*t*t*end;if(paired||i%2==0)Line(previous,next,color,paired?3:2);
                    if(sweep>=0f&&sweep>=t-1f/36f&&sweep<t)Line(previous,next,Color.Lerp(color,Color.white,0.8f),paired?5:4);
                    previous=next;}
                Line(end,end+new Vector2(-11,-5),color,2);Line(end,end+new Vector2(-11,5),color,2);
                bool many=portShown.Enemies.Count>2;Rect badge=many?new Rect(552,250+lane*35,166,33):new Rect(552+(lane%2)*199,255+(lane/2)*63,190,56);
                var forecast=paired?ForecastFor(hero,enemy):null;string risk=paired?forecast.Risk+" · 预估":"单方面";
                badges.Add(()=>{
                Panel(badge,Hex("102029"),color);
                Label(badge.x+6,badge.y+1,badge.width-12,many?15:22,PortHeroName(hero.Unit)+" · "+risk,many?10:12,paired?forecast.Risk=="劣势"?Red:forecast.Risk=="优势"?Cyan:Gold:Muted,TextAnchor.MiddleCenter);
                var revealed=RevealedEnemyCard(enemy);
                string opposing=revealed!=null?revealed.Name:enemy.Active?"未揭示·"+categoryNames[enemy.Category]:"无行动";
                Label(badge.x+4,badge.y+(many?15:25),badge.width-8,many?18:28,PortContent.Card(hero.Key).Name+" → "+opposing,many?9:11,Pale,TextAnchor.MiddleCenter);
                if(forecast!=null){string hint="基础牌面预估，非胜率；未计入被动、状态或后续损币。我方 "+forecast.OwnMin+"–"+forecast.OwnMax+"，敌方公开类别范围 "+forecast.EnemyMin+"–"+forecast.EnemyMax+"。隐藏时不读取具体技能。";GUI.Label(badge,new GUIContent("",hint),GUIStyle.none);}
                });
                lane++;
            }
            foreach(var draw in badges)draw();
            if(lane==0&&portCard=="")Label(550,320,portShown.Enemies.Count>2?180:350,65,"选择技能后，从己方角色拖线到敌人",portShown.Enemies.Count>2?12:15,Muted,TextAnchor.MiddleCenter);
            Label(557,484,380,31,"青 / 金 / 紫：队员 · 虚线：单方面\n风险为基础牌面估计，隐藏对手按类别范围",10,Muted);
        }
    }
}
