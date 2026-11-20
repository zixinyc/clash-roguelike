using System;
using System.Linq;

namespace ClashRoguelike
{
    public static class CharacterRoster
    {
        public const int Capacity=3;
        public static readonly string[] Ids={"marisa","reimu","sakuya","flandre",RemiliaSkills.Id,PatchouliSkills.Id,"zixi","ash","breaker","support"};
        static readonly string[] Original={"ash","breaker","support"};
        static readonly string[] Oriental={"marisa","sakuya","reimu"};
        static readonly string[] Zixi={"ash","zixi","support"};
        static readonly string[] Flandre={"marisa","flandre","reimu"};

        public static Unit Create(string id)
        {
            switch(id)
            {
                case "marisa":return TouhouRoles.Marisa();
                case "reimu":return TouhouRoles.Reimu();
                case "sakuya":return TouhouRoles.Sakuya();
                case "flandre":return FlandreSkills.Create();
                case RemiliaSkills.Id:return RemiliaSkills.Create();
                case PatchouliSkills.Id:return PatchouliSkills.Create();
                case "zixi":return ZixiRole.Create();
                case "ash":return new Unit{CharacterId=id,Name="灰烬",Role="蓄势者",Hp=48,MaxHp=48,MinSpeed=3,MaxSpeed=6};
                case "breaker":return new Unit{CharacterId=id,Name="长锋",Role="破阵者",Hp=42,MaxHp=42,MinSpeed=5,MaxSpeed=8};
                case "support":return new Unit{CharacterId=id,Name="织火",Role="援护者",Hp=46,MaxHp=46,MinSpeed=2,MaxSpeed=5};
                default:return new Unit{CharacterId="",Name="",Hp=0,MaxHp=0};
            }
        }

        public static Unit[] Team(int preset)
        {return (preset==1?Oriental:preset==2?Zixi:preset==3?Flandre:Original).Select(Create).ToArray();}

        public static Unit[] Compose(string[] ids)
        {
            if(ids==null||ids.Length<1||ids.Length>Capacity||ids.Distinct().Count()!=ids.Length||
                ids.Any(id=>!Ids.Contains(id)))
                throw new ArgumentException("Choose 1–3 distinct available characters.","ids");
            return ids.Select(Create).Concat(Enumerable.Range(ids.Length,Capacity-ids.Length).Select(i=>Create(""))).ToArray();
        }

        public static bool Available(string id,bool restricted,bool sakuya,bool flandre,bool remilia=false,bool patchouli=false)
        {
            return Ids.Contains(id)&&(!restricted||id=="marisa"||id=="reimu"||
                id=="sakuya"&&sakuya||id=="flandre"&&flandre||id==RemiliaSkills.Id&&remilia||id==PatchouliSkills.Id&&patchouli);
        }

        public static string[] Skills(string id)
        {
            switch(id)
            {
                case "marisa":return TouhouRoles.MarisaCards;
                case "reimu":return TouhouRoles.ReimuCards;
                case "sakuya":return TouhouRoles.SakuyaCards;
                case "flandre":return FlandreSkills.Cards;
                case RemiliaSkills.Id:return RemiliaSkills.Cards;
                case PatchouliSkills.Id:return PatchouliSkills.Deck;
                case "zixi":return ZixiRole.Keys;
            }
            int legacy=Array.IndexOf(Original,id);
            return legacy<0?new string[0]:PortContent.Hand.Where(k=>PortContent.Card(k).Owner==legacy).ToArray();
        }
    }
}
