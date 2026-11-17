using System;
using System.Linq;
namespace ClashRoguelike
{
    public static class CoinLog
    {
        public static string Faces(bool[] faces){return string.Join("",faces.Select(x=>x?"正":"反").ToArray());}
        public static string Clash(CoinStep s)
        {return "第"+s.Round+"轮 "+s.Left.Name+"["+Faces(s.LeftFaces)+"] "+s.LeftBase+"+"+s.LeftFaces.Count(x=>x)+"×"+s.LeftClashPower+"="+s.LeftPower+" / "+s.Right.Name+"["+Faces(s.RightFaces)+"] "+s.RightBase+"+"+s.RightFaces.Count(x=>x)+"×"+s.RightClashPower+"="+s.RightPower+"；"+(s.Winner<0?"平局，均不损币重投":s.Winner==0?s.Right.Name+" −1币":s.Left.Name+" −1币")+"；余币 "+s.LeftRemaining+"/"+s.RightRemaining;}
        public static string Attack(CoinStep s)
        {return s.Left.Name+" 第"+s.AttackIndex+"/"+s.AttackBudget+"击 "+(s.Heads?"正":"反")+"，原始 "+s.AttackBase+"+"+(s.Heads?s.AttackCoinPower:0)+(s.RawModifier!=0?"+(效果 "+s.RawModifier+")":"")+"="+s.RawDamage+"，余币 "+s.RemainingAttackCoins+"，累计原始 "+s.TotalRawDamage;}
        public static string Fingerprint(CoinStep s)
        {return s==null?"":s.Type+"/"+s.Round+"/"+Faces(s.LeftFaces)+"/"+Faces(s.RightFaces)+"/"+s.LeftPower+"/"+s.RightPower+"/"+s.LeftRemaining+"/"+s.RightRemaining+"/"+s.Winner+"/"+s.FinalWinner+"/"+s.Heads+"/"+s.AttackIndex+"/"+s.AttackBudget+"/"+s.RemainingAttackCoins+"/"+s.RawDamage+"/"+s.TotalRawDamage+"/"+string.Join(";",s.Effects);}
    }
}
