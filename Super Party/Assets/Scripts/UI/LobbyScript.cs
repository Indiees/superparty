using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine;

public class LobbyScript : MonoBehaviour {

    public void BackToMain()
    {
        SceneManager.LoadScene("Main Menu");
    }
}
