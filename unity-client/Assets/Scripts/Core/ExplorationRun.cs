using System;
using System.Collections.Generic;
using System.Linq;
namespace ClashRoguelike
{
    // Translated from exploration_map.gd: fixed 6x4 map, one-shot nodes and carried wallet/HP.
    public sealed class ExplorationRun
    {
        public const int Width=6,Height=4;
        public int X=0,Y=1; public readonly ExpeditionResources Resources=new ExpeditionResources(); public int Cost { get { return Resources.Cost; } set { Resources.Cost=value; } }
        public int[] Hp { get { return Resources.Hp; } set { Resources.Hp=value; } }
        public int[] MaxHp { get { return Resources.MaxHp; } }
        public HashSet<int> Seen=new HashSet<int>(),Cleared=new HashSet<int>();
        public string Pending="",Message="点击相邻格移动；进入敌人格将开始战斗。";
        public bool Finished,InBattle;
        public int Encounter;
        public ExplorationRun() { Reveal(); }
        public static string Node(int x,int y)
        {
            int id=y*6+x;
            switch(id){case 2+6:return "battle";case 4+12:return "elite";case 5+6:return "exit";case 1:return "supply";case 3:return "event";case 5:return "elite";case 4+6:return "camp";case 1+12:return "event";case 3+12:return "shop";case 2+18:return "treasure";case 4+18:return "battle";default:return "";}
        }
        public bool CanMove(int x,int y) {return !Finished&&!InBattle&&Pending==""&&x>=0&&x<6&&y>=0&&y<4&&Math.Abs(x-X)+Math.Abs(y-Y)==1;}
        void Reveal(){Seen.Add(Y*6+X);foreach(var p in new[]{new[]{X+1,Y},new[]{X-1,Y},new[]{X,Y+1},new[]{X,Y-1}})if(p[0]>=0&&p[0]<6&&p[1]>=0&&p[1]<4)Seen.Add(p[1]*6+p[0]);}
        public bool Move(int x,int y)
        {
            if(!CanMove(x,y))return false;X=x;Y=y;Reveal();int id=Y*6+X;string kind=Node(x,y);
            if(Cleared.Contains(id)){Message="已清理的地点，可以通过。";return true;}
            if(kind=="battle"||kind=="elite"){InBattle=true;Encounter=kind=="elite"?1:0;Message="遭遇敌人。";}
            else if(kind=="exit"){Finished=true;Message="已抵达出口，本次探索完成。";}
            else if(kind=="supply"||kind=="treasure"){int reward=kind=="supply"?4:8;Cost+=reward;Cleared.Add(id);Message="找到补给，获得 "+reward+" cost。";}
            else if(kind!=""){Pending=kind;Message="选择该地点的行动。";}else Message="继续探索相邻格。";
            return true;
        }
        void Heal(int amount){for(int i=0;i<3;i++)if(Hp[i]>0)Hp[i]=Math.Min(MaxHp[i],Hp[i]+amount);}
        public bool Choose(int choice)
        {
            if(Pending==""||choice<0||choice>1||Finished||InBattle)return false;
            if(!Resources.ApplyChoice(Pending,choice))return false;
            Cleared.Add(Y*6+X);Pending="";Message="地点已完成，继续探索。";return true;
        }
        public bool LeaveShop(){if(Pending!="shop")return false;Pending="";Message="已离开商店，可以稍后再来。";return true;}
        public PortBattleRules CreateBattle()
        {
            if(!InBattle)throw new InvalidOperationException("No pending encounter");return Resources.CreateBattle(Encounter);
        }
        public bool FinishBattle(PortState state)
        {
            if(!InBattle||state.Outcome=="")return false;Resources.ApplyBattleResult(state,Encounter);
            if(state.Outcome=="victory"){Cleared.Add(Y*6+X);Message="战斗胜利，生命与 cost 带回地图。";}
            else{Finished=true;Message="小队战败，本次探索结束。";}InBattle=false;return true;
        }
    }
}

