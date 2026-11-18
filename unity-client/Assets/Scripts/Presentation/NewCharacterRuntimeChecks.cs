using System;
using System.IO;
using System.Linq;
using UnityEngine;
namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        void CheckNewCharacterEntrances(string path)
        {
            try
            {
                int count=NewCharacterChecks.Run();int old=TouhouChecks.Run()+PortChecks.Run()+ForestChecks.Run()+CoinChecks.Run()+BattleRuleChecks.Run()+InteractionChecks.Run()+PanelChecks.Run();
                selectedRoster=1;InitializeAdventure();SmokeCheck(forest.Party.CreateBattle(0).State.Heroes[0].Name=="雾雨魔理沙","formal forest uses Marisa");
                OpenPortBattle(false,0,true);SelectPortHero(0);SmokeCheck(VisiblePortCards().Length==4&&VisiblePortCards().All(x=>TouhouRoles.MarisaCards.Contains(x.Id)),"Marisa four cards visible in actual selection flow");
                SelectPortCard("marisa_stars");CommitPortTarget(DefaultTarget(0));SmokeCheck(portShown.HeroSlots.Any(x=>x.Key=="marisa_stars"&&x.Active),"Marisa plans through UI handlers");
                OpenPortBattle(false,0,false,true);SelectPortHero(1);SmokeCheck(VisiblePortCards().Length==4&&VisiblePortCards().All(x=>ZixiRole.Keys.Contains(x.Id)),"ZiXi separate roster and hand");
                SelectPortCard("zixi_central_limit");CommitPortTarget(DefaultTarget(0));SmokeCheck(portShown.HeroSlots.Any(x=>x.Key=="zixi_central_limit"&&x.Active),"ZiXi plans through UI handlers");
                OpenPortBattle(false,0,false,true);FillPortPlans();SmokeCheck(portRules.State.HeroSlots.Any(x=>x.Active&&x.Unit==1&&ZixiRole.Keys.Contains(x.Key)),"ZiXi automatic arrangement uses his own cards");
                selectedRoster=2;InitializeAdventure();SmokeCheck(forest.Party.CreateBattle(0).State.Heroes[1].Name=="ZiXi","formal forest retains ZiXi roster");
                selectedRoster=0;InitializeAdventure();SmokeCheck(forest.Party.CreateBattle(0).State.Heroes[0].Name=="灰烬","original forest retained");
                Directory.CreateDirectory(path);File.WriteAllText(Path.Combine(path,"characters-runtime.txt"),"UNITY_FORMAL_CHARACTERS_PASSED\nModel checks: "+count+"\nExisting checks: "+old+"\nFormal forest roster, Marisa hand/plan, ZiXi hand/plan, original roster verified in Unity player. No screenshot or physical mouse verification claimed.\n");
                Debug.Log("UNITY_FORMAL_CHARACTERS_PASSED");Application.Quit(0);
            }
            catch(Exception e){Debug.LogException(e);Directory.CreateDirectory(path);File.WriteAllText(Path.Combine(path,"characters-failed.txt"),e.ToString());Application.Quit(1);}
        }
    }
}
