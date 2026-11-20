
using System;
using System.IO;
using UnityEngine;

namespace ClashRoguelike
{
    public sealed partial class BattleGame
    {
        enum OuterFrame { None, Exploration, Battle }

        const float CanvasWidth=1440f,CanvasHeight=900f;
        static readonly Rect DesignCanvas=new Rect(0,0,CanvasWidth,CanvasHeight);
        readonly Texture2D[] screenFrameTextures=new Texture2D[3];
        readonly bool[] screenFrameTried=new bool[3];

        OuterFrame CurrentOuterFrame()
        {
            if(!adventureMode)return OuterFrame.Battle;
            if(teamSetup)return OuterFrame.None;
            if(TrialActive&&forestCampaign.Duel!=null)return OuterFrame.Battle;
            if(LocalOpponentTurn)return OuterFrame.Exploration;
            return portRules==null?OuterFrame.Exploration:OuterFrame.Battle;
        }

        static Rect CenterUiBounds(float scale)
        {
            float width=CanvasWidth*scale,height=CanvasHeight*scale;
            return new Rect((Screen.width-width)/2,(Screen.height-height)/2,width,height);
        }

        Rect UiContentBounds()
        {
            return FramedContentBounds(CurrentOuterFrame());
        }

        static Rect FramedContentBounds(OuterFrame frame)
        {
            float margin=frame==OuterFrame.Exploration?35f:frame==OuterFrame.Battle?28f:0f;
            return CenterUiBounds(UiDesignScale()*(CanvasHeight-2f*margin)/CanvasHeight);
        }

        static Matrix4x4 UiCanvasMatrix(Rect pixels)
        {
            return Matrix4x4.TRS(new Vector3(pixels.x,pixels.y,0),Quaternion.identity,
                new Vector3(pixels.width/CanvasWidth,pixels.height/CanvasHeight,1));
        }

        void BeginScreenFrame()
        {
            var style=CurrentOuterFrame();
            GUI.matrix=UiCanvasMatrix(CenterUiBounds(UiDesignScale()));
            Fill(DesignCanvas,Hex("210B11"));
            if(style!=OuterFrame.None&&Event.current.type==EventType.Repaint)
            {
                var image=LoadScreenFrame(style);
                if(image!=null)DrawScreenFrameArt(image,style);
            }
            GUI.matrix=UiCanvasMatrix(FramedContentBounds(style));
        }

        Texture2D LoadScreenFrame(OuterFrame style)
        {
            int index=(int)style;
            if(screenFrameTried[index])return screenFrameTextures[index];
            screenFrameTried[index]=true;
            bool exploration=style==OuterFrame.Exploration;
            string file=exploration?"frame_panel.png":"btn_hover.png";
            var path=Path.Combine(Application.streamingAssetsPath,"ui",file);
            Texture2D image=null;
            try
            {
                image=new Texture2D(2,2,TextureFormat.RGBA32,true);
                if(!image.LoadImage(File.ReadAllBytes(path),false))
                    throw new IOException("PNG decoding failed");
                if(exploration)PreparePortraitEdges(image,true);
                image.name=file;
                image.wrapMode=TextureWrapMode.Clamp;
                image.filterMode=FilterMode.Trilinear;
                screenFrameTextures[index]=image;
            }
            catch(Exception error)
            {
                if(image!=null)Destroy(image);
                Debug.LogWarning("Screen frame could not load: "+file+" / "+error.Message);
            }
            return screenFrameTextures[index];
        }

        static void DrawScreenFrameArt(Texture2D image,OuterFrame style)
        {
            // Preserve the four corners; stretch only the straight spans between them.
            float cut=style==OuterFrame.Exploration?136f:112f;
            float cap=cut*(style==OuterFrame.Exploration?.28f:.30f);
            float[] x={4,4+cap,CanvasWidth-4-cap,CanvasWidth-4};
            float[] y={4,4+cap,CanvasHeight-4-cap,CanvasHeight-4};
            float[] u={0,cut/image.width,1-cut/image.width,1};
            float[] v={1,1-cut/image.height,cut/image.height,0};
            for(int row=0;row<3;row++)
                for(int column=0;column<3;column++)
                {
                    if(row==1&&column==1)continue;
                    var dest=new Rect(x[column],y[row],x[column+1]-x[column],y[row+1]-y[row]);
                    var uv=new Rect(u[column],v[row+1],u[column+1]-u[column],v[row]-v[row+1]);
                    GUI.DrawTextureWithTexCoords(dest,image,uv,true);
                }
        }

        void DisposeScreenFrames()
        {
            foreach(var image in screenFrameTextures)
                if(image!=null)Destroy(image);
        }
    }
}
