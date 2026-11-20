using System;

namespace ClashRoguelike
{
    /// 界面反馈的纯逻辑检查。
    ///
    /// Core/ 里的检查会被 Tools/BuildLocalPlayer.ps1 在播放器之外反射调用，
    /// 那条路径上找不到 UnityEngine 程序集，所以这里只准出现纯 .NET 类型。
    public static class UiChecks
    {
        static int checks;
        static void Check(bool ok,string message)
        {
            checks++;
            if(!ok) throw new Exception("UI feedback check failed: "+message);
        }
        static bool Near(float a,float b,float tolerance)
        {
            return Math.Abs(a-b)<=tolerance;
        }

        public static int Run()
        {
            checks=0;
            ApproachConverges();
            ApproachIsFrameRateIndependent();
            HoverOutIsSlowerThanHoverIn();
            SpringOvershootsFourPercent();
            SpringSettlesInTime();
            PressScaleClamps();
            PressScaleOvershootMatchesDocument();
            DisabledWidgetDoesNotRespond();
            SelectedWidgetStillClicksOnce();
            DenyShakeDecays();
            WidgetsKeepStateById();
            NumbersRoll();
            PulsesReturnToRest();
            LabelsCrossFade();
            KeyPressUsesTheSameFeedback();
            SoundTiersGateAudio();
            FocusBelongsToOneOwner();
            RichMotionAddsOvershoot();
            HoverEntryIsReportedOnce();
            HoveredWidgetIsNamed();
            FlashDecaysToNothing();
            EntranceSlidesAndFades();
            ShakeImpactsDecay();
            return checks;
        }

        static void ShakeImpactsDecay()
        {
            var shake=new ScreenShake();
            Check(!shake.Active,"a quiet screen does not move");
            Check(Near(shake.OffsetX,0f,0.0001f)&&Near(shake.OffsetY,0f,0.0001f),"an idle shake has no offset");

            shake.Trigger(ScreenShake.ClashAmplitude,ScreenShake.ClashDuration,ScreenShake.ClashFrequency);
            Check(shake.Active,"a clash wakes the screen up");
            float clashPeak=0f;
            for(int i=0;i<80;i++)
            {
                shake.Tick(0.005f);
                clashPeak=Math.Max(clashPeak,shake.Magnitude);
            }
            Check(clashPeak>2f,"the clash shake is visible");
            Check(clashPeak<=ScreenShake.ClashAmplitude*1.2f,"the clash shake stays inside its amplitude");
            for(int i=0;i<80;i++) shake.Tick(0.005f);
            Check(!shake.Active,"the shake ends on schedule");
            Check(Near(shake.OffsetX,0f,0.0001f)&&Near(shake.OffsetY,0f,0.0001f),"the shake ends at exactly zero");

            var strike=new ScreenShake();
            strike.Trigger(ScreenShake.StrikeAmplitude,ScreenShake.StrikeDuration,ScreenShake.StrikeFrequency);
            float strikePeak=0f;
            for(int i=0;i<40;i++)
            {
                strike.Tick(0.005f);
                strikePeak=Math.Max(strikePeak,strike.Magnitude);
            }
            Check(strikePeak>0.4f,"an attack still nudges the screen");
            Check(strikePeak<ScreenShake.ClashAmplitude*0.6f,"the attack shake stays lighter than the clash");

            var finish=new ScreenShake();
            finish.Trigger(ScreenShake.ClashEndAmplitude,ScreenShake.ClashEndDuration,ScreenShake.ClashEndFrequency);
            float finishPeak=0f;
            for(int i=0;i<80;i++)
            {
                finish.Tick(0.005f);
                finishPeak=Math.Max(finishPeak,finish.Magnitude);
            }
            Check(finishPeak>clashPeak,"the decisive clash hits harder than a single round");

            var quiet=new ScreenShake();
            quiet.Trigger(0f,ScreenShake.ClashDuration,ScreenShake.ClashFrequency);
            Check(!quiet.Active,"a zero amplitude never moves the screen");
            quiet.Tick(0.1f);
            Check(Near(quiet.Magnitude,0f,0.0001f),"a quiet screen stays quiet");

            var again=new ScreenShake();
            again.Trigger(ScreenShake.ClashAmplitude,ScreenShake.ClashDuration,ScreenShake.ClashFrequency);
            again.Tick(0.05f);
            again.Trigger(ScreenShake.StrikeAmplitude,ScreenShake.StrikeDuration,ScreenShake.StrikeFrequency);
            Check(Near(again.Amplitude,ScreenShake.StrikeAmplitude,0.0001f),"a new impact replaces the old one");
            Check(Near(again.Elapsed,0f,0.0001f),"a new impact restarts the envelope");

            var stopped=new ScreenShake();
            stopped.Trigger(ScreenShake.ClashAmplitude,ScreenShake.ClashDuration,ScreenShake.ClashFrequency);
            stopped.Stop();
            Check(!stopped.Active&&Near(stopped.Magnitude,0f,0.0001f),"a stopped shake leaves nothing behind");
        }

        static void EntranceSlidesAndFades()
        {
            var entrance=new UiEntrance();
            Check(entrance.Alpha==1f&&entrance.Offset==0f,"a card at rest is fully visible");
            entrance.Trigger(0f,1);
            Check(entrance.Offset==1f&&entrance.Alpha==0f,"a triggered entrance starts off screen");
            entrance.Tick(0.13f);
            float mid=entrance.Progress;
            Check(mid>0.4f&&mid<0.6f,"the entrance advances at half its length");
            Check(entrance.Offset>0f&&entrance.Offset<1f,"the card is halfway in");
            Check(entrance.Alpha>0f&&entrance.Alpha<1f,"the card fades while it slides");
            entrance.Tick(0.2f);
            Check(!entrance.Active&&entrance.Offset==0f&&entrance.Alpha==1f,"the entrance ends invisible to the eye");

            var delayed=new UiEntrance();
            delayed.Trigger(0.1f,-1);
            delayed.Tick(0.05f);
            Check(delayed.Progress==0f&&delayed.Offset==-1f,"a delayed entrance waits off screen");
            delayed.Tick(0.1f);
            Check(delayed.Offset<0f,"a backwards entrance slides in from the left");
        }

        static void HoverEntryIsReportedOnce()
        {
            var feedback=new UiFeedback();
            UiWidget widget=feedback.Widget("a");
            widget.SetHover(false);
            Check(!widget.HoverEntered,"a cold widget reports no hover entry");
            widget.SetHover(true);
            Check(widget.HoverEntered,"entering hover is reported");
            widget.SetHover(true);
            Check(widget.HoverEntered,"staying hovered keeps the flag until it is consumed");
            widget.HoverEntered=false;
            widget.SetHover(true);
            Check(!widget.HoverEntered,"a consumed flag is not raised again while hovering");
            widget.SetHover(false);
            widget.SetHover(true);
            Check(widget.HoverEntered,"leaving and re-entering raises the flag again");
        }

        static void HoveredWidgetIsNamed()
        {
            var feedback=new UiFeedback();
            feedback.Widget("a").SetHover(true);
            feedback.Tick(0.05f);
            Check(feedback.HoveredId=="a","the hovered widget is named");
            feedback.Widget("a").SetHover(false);
            feedback.Tick(0.05f);
            Check(feedback.HoveredId=="","nothing is hovered once the pointer leaves");
        }

        static void FlashDecaysToNothing()
        {
            var flash=new UiFlash();
            Check(flash.Value==0f,"a fresh flash is dark");
            flash.Trigger();
            Check(flash.Value>0.9f,"a triggered flash lights up");
            flash.Tick(0.11f);
            float mid=flash.Value;
            Check(mid>0.3f&&mid<0.7f,"the flash fades over its length");
            flash.Tick(0.2f);
            Check(!flash.Active&&flash.Value==0f,"the flash dies out");
        }

        static void SoundTiersGateAudio()
        {
            var feedback=new UiFeedback();
            feedback.SoundTier=0;
            Check(!feedback.BattleSoundAllowed&&!feedback.UiSoundAllowed,"all off silences both channels");
            feedback.SoundTier=1;
            Check(feedback.BattleSoundAllowed&&!feedback.UiSoundAllowed,"battle only keeps battle sound and drops ui sound");
            feedback.SoundTier=2;
            Check(feedback.BattleSoundAllowed&&feedback.UiSoundAllowed,"all on keeps both channels");
            feedback.UiSoundLevel=0;
            Check(!feedback.UiSoundAllowed&&feedback.BattleSoundAllowed,"the ui sound level can shut the ui channel alone");
            feedback.UiSoundLevel=1;
            Check(feedback.UiSoundAllowed&&!feedback.HoverSoundAllowed,"the hover sound waits for the higher ui level");
            feedback.UiSoundLevel=2;
            Check(feedback.UiSoundAllowed&&feedback.HoverSoundAllowed,"the top ui level adds the hover sound");
            feedback.UiSoundLevel=1;
            feedback.SoundTier=3;
            Check(feedback.UiSoundAllowed,"an out of range tier still reads as ui on");
        }

        static void FocusBelongsToOneOwner()
        {
            var feedback=new UiFeedback();
            feedback.SetFocus("port.primary");
            Check(feedback.FocusOwner=="port.primary","the focus owner is recorded");
            Check(feedback.Widget("port.primary").Focused,"the focused widget holds the ring");
            Check(!feedback.Widget("port.auto").Focused,"other widgets do not hold the ring");
            feedback.SetFocus("port.auto");
            Check(!feedback.Widget("port.primary").Focused,"the ring leaves the old owner");
            Check(feedback.Widget("port.auto").Focused,"the ring arrives at the new owner");
            feedback.SetFocus(null);
            Check(feedback.FocusOwner=="","clearing the focus leaves no owner");
            Check(!feedback.Widget("port.auto").Focused,"clearing the focus drops the ring");
        }

        static void RichMotionAddsOvershoot()
        {
            var standard=new UiFeedback();
            standard.MotionLevel=1;
            var standardWidget=standard.Widget("a");
            standardWidget.TriggerPress();
            standard.Tick(0.02f);
            standard.Tick(0.02f);
            float lowest=0f;
            for(int i=0;i<30;i++){ standard.Tick(0.01f); if(standardWidget.Press<lowest) lowest=standardWidget.Press; }
            Check(lowest<-0.01f,"the standard tier overshoots on release");
            Check(lowest>-0.10f,"the overshoot stays around four percent");

            var off=new UiFeedback();
            off.MotionLevel=0;
            var offWidget=off.Widget("a");
            offWidget.TriggerPress();
            off.Tick(0.02f);
            off.Tick(0.02f);
            float offLowest=0f;
            for(int i=0;i<30;i++){ off.Tick(0.01f); if(offWidget.Press<offLowest) offLowest=offWidget.Press; }
            Check(Near(offLowest,0f,0.0001f),"the motion off tier never overshoots");

            var rich=new UiFeedback();
            rich.MotionLevel=2;
            Check(rich.RichMotion&&!off.RichMotion,"the rich tier is a separate switch");
            Check(rich.MotionEnabled&&!off.MotionEnabled,"the motion switch is separate from the rich switch");
        }

        static void ApproachConverges()
        {
            float value=0f;
            value=UiMath.Approach(value,1f,0.09f,UiMath.HoverIn);
            Check(Near(value,0.95021f,0.001f),"hover reaches 95% in one duration");
            value=UiMath.Approach(value,1f,0.30f,UiMath.HoverIn);
            Check(value>0.999f,"hover converges to the target");
            Check(Near(UiMath.Approach(0f,1f,0f,UiMath.HoverIn),0f,0.0001f),"zero dt does not move the value");
            Check(Near(UiMath.Approach(0f,1f,0.1f,0f),1f,0.0001f),"zero duration snaps to the target");
        }

        static void ApproachIsFrameRateIndependent()
        {
            float single=UiMath.Approach(0f,1f,0.09f,UiMath.HoverIn);
            float stepped=0f;
            for(int i=0;i<9;i++) stepped=UiMath.Approach(stepped,1f,0.01f,UiMath.HoverIn);
            Check(Near(single,stepped,0.0005f),"one big step equals nine small steps");
        }

        static void HoverOutIsSlowerThanHoverIn()
        {
            float inProgress=UiMath.Approach(0f,1f,0.09f,UiMath.HoverIn);
            float outProgress=1f-UiMath.Approach(1f,0f,0.09f,UiMath.HoverOut);
            Check(outProgress<inProgress,"hover fades out slower than it fades in");
            Check(Near(outProgress,0.85464f,0.002f),"hover out curve matches the documented duration");
            Check(Near(inProgress,0.95021f,0.002f),"hover in curve matches the documented duration");
        }

        static void SpringOvershootsFourPercent()
        {
            float lowest=0f,lowestAt=0f;
            for(int i=0;i<=400;i++)
            {
                float t=i/1000f;
                float value=UiMath.Spring(t,UiMath.SpringZeta,UiMath.SpringOmega,1f,0f);
                if(value<lowest){ lowest=value; lowestAt=t; }
            }
            Check(lowest<0f,"release spring overshoots past the resting scale");
            Check(Near(lowest,-0.03987f,0.002f),"release overshoot is four percent of the travel");
            Check(Near(lowestAt,0.0966f,0.01f),"release overshoot peaks about 97ms after release");
        }

        static void SpringSettlesInTime()
        {
            float at120=Math.Abs(UiMath.Spring(0.12f,UiMath.SpringZeta,UiMath.SpringOmega,1f,0f));
            float at250=Math.Abs(UiMath.Spring(0.25f,UiMath.SpringZeta,UiMath.SpringOmega,1f,0f));
            Check(at120<0.05f,"spring is close to rest after 120ms");
            Check(at250<0.01f,"spring is at rest after 250ms");
            Check(Near(UiMath.Spring(0f,UiMath.SpringZeta,UiMath.SpringOmega,1f,0f),1f,0.0001f),"spring starts at the value it was released from");
            float critical=UiMath.Spring(0.1f,1f,46.6f,1f,0f);
            Check(critical>0f,"critically damped release never crosses the resting scale");
        }

        static void PressScaleClamps()
        {
            Check(Near(UiMath.PressScale(27f),0.94074f,0.0001f),"27px button scales by 1.6px of travel");
            Check(Near(UiMath.PressScale(28f),0.94286f,0.0001f),"28px button scales by 1.6px of travel");
            Check(Near(UiMath.PressScale(38f),0.95789f,0.0001f),"38px button scales by 1.6px of travel");
            Check(Near(UiMath.PressScale(48f),0.965f,0.0001f),"48px button hits the upper clamp");
            Check(Near(UiMath.PressScale(10f),0.940f,0.0001f),"tiny button hits the lower clamp");
            Check(Near(UiMath.PressScale(0f),1f,0.0001f),"zero height does not divide by zero");
        }

        static void PressScaleOvershootMatchesDocument()
        {
            float depth=1f-UiMath.PressScale(38f);
            float lowest=0f;
            for(int i=0;i<=400;i++) lowest=Math.Min(lowest,UiMath.Spring(i/1000f,UiMath.SpringZeta,UiMath.SpringOmega,1f,0f));
            float peakScale=1f-lowest*depth;
            Check(Near(peakScale,1.00168f,0.0003f),"release pops to about 1.002 before settling");
        }

        static void DisabledWidgetDoesNotRespond()
        {
            UiWidget widget=new UiWidget();
            widget.Enabled=false;
            widget.SetHover(true);
            for(int i=0;i<60;i++) widget.Tick(0.016f);
            Check(widget.Hover<0.001f,"disabled widget never brightens on hover");
            widget.SetPressed(true);
            for(int i=0;i<10;i++) widget.Tick(0.016f);
            Check(Math.Abs(widget.Press)<0.001f,"disabled widget never sinks on press");
            widget.FireClick();
            Check(!widget.TakeClick(),"disabled widget never reports a click");
            widget.SetPressed(false);
            for(int i=0;i<60;i++) widget.Tick(0.016f);
            Check(Math.Abs(widget.Press)<0.001f,"disabled widget stays at rest");
        }

        static void SelectedWidgetStillClicksOnce()
        {
            UiWidget widget=new UiWidget();
            widget.Selected=true;
            widget.SetHover(true);
            widget.SetPressed(true);
            widget.Tick(0.04f);
            Check(widget.Press>0.9f,"press reaches the floor in 40ms");
            widget.FireClick();
            Check(widget.TakeClick(),"selected widget reports its click");
            Check(!widget.TakeClick(),"a click is consumed only once");
            widget.SetPressed(false);
            widget.Tick(0.0966f);
            Check(widget.Press<0f,"release overshoots past the resting scale");
            widget.Tick(0.40f);
            Check(Near(widget.Press,0f,0.0001f),"release settles back to rest");
        }

        static void DenyShakeDecays()
        {
            UiWidget widget=new UiWidget();
            widget.TriggerDeny();
            Check(Near(widget.Deny,UiMath.DenyLength,0.0001f),"deny starts a full length timer");
            float peak=0f;
            for(int i=0;i<20;i++)
            {
                widget.Tick(0.01f);
                peak=Math.Max(peak,Math.Abs(widget.Shake));
            }
            Check(peak>3f,"deny shakes the widget");
            Check(peak<=6.001f,"deny shake never exceeds six pixels");
            for(int i=0;i<20;i++) widget.Tick(0.01f);
            Check(Near(widget.Deny,0f,0.0001f),"deny timer runs out");
            Check(Near(widget.Shake,0f,0.0001f),"deny shake ends at exactly zero");
        }

        static void WidgetsKeepStateById()
        {
            UiFeedback feedback=new UiFeedback();
            UiWidget first=feedback.Widget("port.primary");
            first.Hover=0.5f;
            UiWidget again=feedback.Widget("port.primary");
            Check(ReferenceEquals(first,again),"the same id returns the same widget");
            Check(Near(again.Hover,0.5f,0.0001f),"widget state survives across frames");
            UiWidget other=feedback.Widget("port.card.ember");
            Check(!ReferenceEquals(first,other),"different ids are different widgets");
            Check(feedback.WidgetCount==2,"registry only holds the widgets it was asked for");
            feedback.Tick(0.016f);
            Check(Near(first.Hover,0.5f,0.2f),"tick advances every registered widget");
        }

        static void NumbersRoll()
        {
            UiNumber number=new UiNumber();
            number.Init(0);
            number.Set(10);
            number.Tick(0.16f);
            Check(number.Rolling,"number is still rolling halfway through");
            Check(number.Value>0f&&number.Value<10f,"number travels between the old and the new value");
            number.Tick(0.20f);
            Check(!number.Rolling,"number stops rolling at the end of the duration");
            Check(Near(number.Value,10f,0.0001f),"number lands exactly on the target");
            Check(number.Display==10,"number shows the rounded target");
            Check(number.FlashUp,"a rising number is flagged for the gold flash");
            number.Set(4);
            Check(!number.FlashUp,"a falling number is not flagged as rising");
        }

        static void PulsesReturnToRest()
        {
            UiPulse pulse=new UiPulse();
            Check(Near(pulse.Scale,1f,0.0001f),"idle pulse sits at rest");
            pulse.Trigger();
            Check(Near(pulse.Scale,1.15f,0.0001f),"a triggered pulse starts at 1.15");
            pulse.Tick(0.09f);
            Check(pulse.Scale<1.15f&&pulse.Scale>1f,"pulse falls back toward rest");
            pulse.Tick(0.20f);
            Check(!pulse.Active,"pulse ends on schedule");
            Check(Near(pulse.Scale,1f,0.0001f),"pulse lands back at rest");
        }

        static void LabelsCrossFade()
        {
            UiWidget widget=new UiWidget();
            widget.SetLabelInstant("准备交锋");
            Check(Near(widget.LabelAlpha,1f,0.0001f),"a fresh label is fully visible");
            widget.SetLabel("演示一回合");
            Check(widget.LabelPhase==1,"a changed label starts by fading out");
            widget.Tick(0.12f);
            Check(widget.ShownLabel=="演示一回合","the label swaps after the fade out");
            Check(widget.LabelPhase==2,"the new label fades in after the swap");
            widget.Tick(0.12f);
            Check(Near(widget.LabelAlpha,1f,0.0001f),"the new label ends fully visible");
        }

        static void KeyPressUsesTheSameFeedback()
        {
            UiWidget widget=new UiWidget();
            widget.TriggerPress();
            widget.Tick(0.02f);
            Check(widget.Press>0.5f,"a key press sinks the button like a mouse press");
            Check(widget.Pressed,"a key press is held while it sinks");
            widget.Tick(0.02f);
            Check(!widget.Pressed,"a key press releases itself");
            Check(widget.Press>0.9f,"a key press reaches the floor before it releases");
            widget.Tick(0.0966f);
            Check(widget.Press<0f,"a key press springs back past the resting scale");
            widget.Tick(0.40f);
            Check(Near(widget.Press,0f,0.0001f),"a key press settles back to rest");
        }
    }
}
