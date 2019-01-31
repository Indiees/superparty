using System.Collections;
using System.Collections.Generic;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using UnityEngine;

public class MainMenuScript : MonoBehaviour {

    [SerializeField] Button Play;
    [SerializeField] Button Option;
    [SerializeField] Button Exit;

    private void Start()
    {
        StartCoroutine(DISCOMODEENGAGED());
    }

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

    IEnumerator DISCOMODEENGAGED()
    {
        while (3 > 2)
        {
            yield return new WaitForSeconds(1);
            SendColorChange();
        }
    }

    public void SendColorChange()
    {
        GameObject[] DiscoPads = GameObject.FindGameObjectsWithTag("Furniture");
        foreach (GameObject DiscoPad in DiscoPads)
            DiscoPad.GetComponent<DiscoFloorScript>().ColorChange();
    }

}
