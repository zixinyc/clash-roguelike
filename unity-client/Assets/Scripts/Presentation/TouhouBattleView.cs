using System;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        string PortHeroName(int i){return portShown!=null?portShown.Heroes[i].Name:heroNames[i];}
        string PortRoleSummary(int i)
        {
            if(portShown.ZixiTeam&&i==1){var z=portShown.Heroes[1].Zixi;return "超形上学 "+z.Metaphysics+"/6 · 因果 "+z.Causality+"/3";}
            if(!portShown.TouhouTeam)return i==0?"准备 "+portShown.Preparation:i==1?"高费拼点 +2 / 失败 −2 HP":"防御援护队友";
            if(i==0)return "火花 "+portShown.Heroes[0].RoleState.Spark+"/10 · 生命5换1敌方cost";
            if(i==1)return "无视速度接招 · 银刀 +"+TouhouRoles.SilverKnife(portShown.Turn)+(portShown.Heroes[1].RoleState.SpaceActive?" / 空间 +5":"");
            var r=portShown.Heroes[2].RoleState;return r.DreamDue>0?"宝玉 "+r.DreamOrbs+"/3 · 第 "+r.DreamDue+" 回合末结算":"对本土目标拼点 +1 · 退治四层引爆";
        }
        void DrawRosterSwitch()
        {
            if(fromMap)return;GUI.enabled=!portBusy;
            if(Btn(new Rect(437,25,215,35),portShown.TouhouTeam?"东方三人 → ZiXi":portShown.ZixiTeam?"ZiXi → 原小队":"原小队 → 东方三人"))OpenPortBattle(false,portRules.State.Kinds[0]=="priest"?1:0,portShown.TouhouTeam?false:!portShown.ZixiTeam,portShown.TouhouTeam);GUI.enabled=true;
        }
        void DrawPortFigure(bool allied,int index,float x,float y,Color tint)
        {
            if(allied&&DrawCharacterPortrait(portShown.Heroes[index],x,y))return;
            bool special=allied&&portShown.TouhouTeam&&index>0;bool reimu=special&&index==2;
            Color cloth=special?(reimu?Hex("A94448"):Hex("587A9E")):Color.Lerp(tint,Hex("192630"),.65f),skin=special?Hex("DDC3A2"):tint;
            Fill(new Rect(x-15,y-119,31,32),skin);Fill(new Rect(x-25,y-81,51,66),cloth);
            Line(new Vector2(x-10,y-22),new Vector2(x-22,y+27),special?Hex("D6D5CF"):tint,12);Line(new Vector2(x+10,y-22),new Vector2(x+27,y+27),special?Hex("D6D5CF"):tint,12);
            Line(new Vector2(x-21,y-69),new Vector2(x-43,y-16),special?Pale:tint,9);Line(new Vector2(x+21,y-69),new Vector2(x+46,y-38),special?Pale:tint,9);
            if(special)
            {
                Fill(new Rect(x-17,y-124,35,13),reimu?Hex("372C31"):Hex("BCC5CD"));Fill(new Rect(x-13,y-78,27,46),Pale);
                if(reimu){Line(new Vector2(x-19,y-126),new Vector2(x+18,y-116),Red,9);Line(new Vector2(x-19,y-116),new Vector2(x+18,y-126),Red,9);Line(new Vector2(x+37,y-50),new Vector2(x+57,y-116),Gold,3);}
                else{Fill(new Rect(x-23,y-126,47,5),Pale);for(int n=0;n<3;n++)Line(new Vector2(x+34+n*7,y-42),new Vector2(x+48+n*7,y-84),Pale,2);}
            }
            else Line(new Vector2(x+40,y-25),new Vector2(x+(allied?81:-42),y-103),Pale,4);
            if(allied&&portShown.TouhouTeam&&index==0){Fill(new Rect(x-32,y-124,64,7),Hex("DCCAA3"));Line(new Vector2(x-23,y-129),new Vector2(x,y-158),Hex("332E38"),17);Line(new Vector2(x,y-158),new Vector2(x+18,y-127),Hex("332E38"),17);Fill(new Rect(x-23,y-75,47,48),Hex("363342"));}
            if(allied&&portShown.ZixiTeam&&index==1){Fill(new Rect(x-25,y-81,51,66),Hex("68527C"));Line(new Vector2(x-25,y-90),new Vector2(x+25,y-90),Cyan,3);}
        }
        void FillTouhouPlans()
        {
            string[][] options=portRules.State.ZixiTeam?new string[][]{new[]{"probe","nova","guard"},new[]{"zixi_central_limit","zixi_almost_sure","zixi_martingale","zixi_convergence"},new[]{"support_strike","light_guard","cover"}}:new string[][]{new[]{"marisa_stars","marisa_spark","marisa_orrery","marisa_laser","guard"},portRules.State.WorldActive?new[]{"murder_doll","murder_doll","guard"}:new[]{"murder_doll",portRules.State.Heroes[1].RoleState.WorldUsed?"private_square":"the_world","stopwatch","private_square","guard"},new[]{"yin_yang_orb","demon_seal","fantasy_seal","guard"}};
            for(int hero=0;hero<3;hero++)
            {
                if(portRules.State.Heroes[hero].Hp<=0||portRules.State.HeroSlots[hero*3].Frozen)continue;
                foreach(string key in options[hero])
                {
                    if(!portRules.State.WorldActive&&portRules.State.HeroSlots.Any(s=>s.Active&&s.Key==key))continue;var card=PortContent.Card(key);int slot=portRules.SlotFor(hero,key);
                    if(portRules.State.HeroSlots[slot].Active)continue;
                    if(!card.TargetsEnemy){portRules.Assign(key,hero,-1);continue;}
                    var targets=portRules.State.EnemySlots.OrderBy(s=>portRules.State.HeroSlots.Any(h=>h.Active&&h.Unit==hero&&h.Target==s.Id)?1:0).ThenBy(s=>portRules.PairFor(s.Id)>=0?1:0);
                    foreach(var target in targets)if(portRules.CanAssign(key,slot,target.Id)==""){portRules.Assign(key,hero,target.Id,slot);break;}
                }
            }
            portShown=portRules.Snapshot();
        }
    }
}
