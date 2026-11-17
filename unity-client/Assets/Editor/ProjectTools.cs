using System;
using System.IO;
using ClashRoguelike;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ProjectTools
{
    public const string ScenePath="Assets/Scenes/Battle.unity";
    [MenuItem("Clash Roguelike/Run rule checks")]
    public static void Validate()
    {
        int newChecks=NewCharacterChecks.Run();
        Debug.Log("UNITY_NEW_CHARACTER_CHECKS_PASSED checks="+newChecks);
        int count=BattleRuleChecks.Run();
        int clickChecks=InteractionChecks.Run();
        int panelChecks=PanelChecks.Run();
        int portChecks=PortChecks.Run();
        int forestChecks=ForestChecks.Run();
        int coinChecks=CoinChecks.Run();
        int roleChecks=TouhouChecks.Run();Debug.Log("UNITY_TOUHOU_CHECKS_PASSED checks="+roleChecks);
        Debug.Log("UNITY_COIN_CHECKS_PASSED checks="+coinChecks);
        Debug.Log("UNITY_FOREST_CHECKS_PASSED checks="+forestChecks);
        Debug.Log("UNITY_GODOT_PORT_CHECKS_PASSED checks="+portChecks);
        Debug.Log("UNITY_PANEL_CHECKS_PASSED checks="+panelChecks);
        Debug.Log("UNITY_CLICK_CHECKS_PASSED checks="+clickChecks);
        Debug.Log("UNITY_RULE_CHECKS_PASSED checks="+count);
        Directory.CreateDirectory("TestResults");
        File.WriteAllText("TestResults/rules.txt","UNITY_RULE_CHECKS_PASSED checks="+count+Environment.NewLine+"UNITY_CLICK_CHECKS_PASSED checks="+clickChecks+Environment.NewLine+"UNITY_PANEL_CHECKS_PASSED checks="+panelChecks+Environment.NewLine+"UNITY_PORT_CHECKS_PASSED checks="+portChecks+Environment.NewLine+"UNITY_FOREST_CHECKS_PASSED checks="+forestChecks+Environment.NewLine+"UNITY_COIN_CHECKS_PASSED checks="+coinChecks+Environment.NewLine+"UNITY_TOUHOU_CHECKS_PASSED checks="+roleChecks+Environment.NewLine);
    }
    [MenuItem("Clash Roguelike/Open battle scene")]
    public static void OpenBattle() { EditorSceneManager.OpenScene(ScenePath); }
    [MenuItem("Clash Roguelike/Build Windows game")]
    public static void BuildWindows()
    {
        Validate();
        PlayerSettings.companyName="Clash Roguelike"; PlayerSettings.productName="余烬交锋 Unity";
        PlayerSettings.defaultScreenWidth=1440; PlayerSettings.defaultScreenHeight=900;
        PlayerSettings.fullScreenMode=FullScreenMode.Windowed; PlayerSettings.resizableWindow=true;
        PlayerSettings.runInBackground=true;
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone,ScriptingImplementation.Mono2x);
        EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(ScenePath,true)};
        Directory.CreateDirectory("Builds/Windows");
        var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions { scenes=new[]{ScenePath},locationPathName="Builds/Windows/ClashRoguelike.exe",target=BuildTarget.StandaloneWindows64,options=BuildOptions.None });
        if(report.summary.result!=BuildResult.Succeeded) throw new Exception("Windows build failed: "+report.summary.result);
        Debug.Log("UNITY_WINDOWS_BUILD_PASSED "+report.summary.outputPath);
    }
}
