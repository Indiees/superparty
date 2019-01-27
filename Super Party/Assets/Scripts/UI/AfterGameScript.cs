using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine;

public class AfterGameScript : MonoBehaviour {

    public void DisconnectFromGame()
    {
        SceneManager.LoadScene("Main Menu");
    }

}
