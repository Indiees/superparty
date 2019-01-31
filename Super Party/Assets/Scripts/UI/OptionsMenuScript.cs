using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine;

public class OptionsMenuScript : MonoBehaviour {

    Resolution[] resolutions;
    int StartingQuality;
    [SerializeField] Dropdown Quality;
    [SerializeField] Dropdown ResolutionDropDown;

    private void Start()
    {
        resolutions = Screen.resolutions;
        ResolutionDropDown.ClearOptions();
        List<string> ResOpts = new List<string>();
        int CurrentResIndex = 0;
        for (int i = 0; i < resolutions.Length; i++)
        {
            string ResOpt = resolutions[i].width + "x" + resolutions[i].height;
            ResOpts.Add(ResOpt);

            if (resolutions[i].width == Screen.currentResolution.width &&
                resolutions[i].height == Screen.currentResolution.height)
            {
                CurrentResIndex = i;
            }
        }
        ResolutionDropDown.AddOptions(ResOpts);
        ResolutionDropDown.value = CurrentResIndex;
        ResolutionDropDown.RefreshShownValue();
        StartingQuality = QualitySettings.GetQualityLevel();
        Quality.value = StartingQuality;
    }

    public void ResolutionChange(int Resolution)
    {
        Resolution NextRes = resolutions[Resolution];
        Screen.SetResolution(NextRes.width, NextRes.height, Screen.fullScreen);
    }

    public void QualityChange(int Quality)
    {
        QualitySettings.SetQualityLevel(Quality);
        Debug.Log("Quality changed to " + QualitySettings.GetQualityLevel());
    }

    public void ToggleFullscreen(bool IsFullscreen)
    {
        Screen.fullScreen = IsFullscreen;
        Debug.Log("Fullscreen toggled");
    }

    public void BackToMainMenu()
    {
        SceneManager.LoadScene("Main Menu");
    }

}
