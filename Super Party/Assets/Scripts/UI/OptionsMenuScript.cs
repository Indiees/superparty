using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine;

public class OptionsMenuScript : MonoBehaviour {

    int StartingQuality;
    [SerializeField] Dropdown Quality;

    private void Start()
    {
        StartingQuality = QualitySettings.GetQualityLevel();
        Quality.value = StartingQuality;
    }

    public void QualityChange(int Quality)
    {
        QualitySettings.SetQualityLevel(Quality);
        Debug.Log("Quality changed to " + QualitySettings.GetQualityLevel());
    }

    public void ToggleFullscreen()
    {
        Screen.fullScreen = !Screen.fullScreen;
        Debug.Log("Fullscreen toggled");
    }

    public void BackToMainMenu()
    {
        SceneManager.LoadScene("Main Menu");
    }

}
