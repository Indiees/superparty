using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine;

public class MainMenuScript : MonoBehaviour {

    public void PlayButtonPressed()
    {
        SceneManager.LoadScene("Lobby");
    }

    public void OptionsButtonPressed()
    {
        SceneManager.LoadScene("Options Menu");
    }

    public void ExitButtonPressed()
    {
        Application.Quit();
        Debug.Log("Exit requested");
    }

}
