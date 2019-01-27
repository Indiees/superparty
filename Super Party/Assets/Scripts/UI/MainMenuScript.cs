using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine;

public class MainMenuScript : MonoBehaviour {

    [SerializeField] Button Play;
    [SerializeField] Button Option;
    [SerializeField] Button Exit;

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
