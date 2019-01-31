using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiscoFloorScript : MonoBehaviour {

    Renderer rend;
    Color RandoColo;

	void Start ()
    {
        RandoColo = Random.ColorHSV(0f, 1f, 1f, 1f, 0.5f, 1f);
        rend = GetComponent<Renderer>();
        rend.material.SetColor("_Color", RandoColo);
        rend.material.SetColor("_EmissionColor", RandoColo);
	}

    public void ColorChange()
    {
        RandoColo = Random.ColorHSV(0f, 1f, 1f, 1f, 0.5f, 1f);
        rend = GetComponent<Renderer>();
        rend.material.SetColor("_Color", RandoColo);
        rend.material.SetColor("_EmissionColor", RandoColo);
    }
	
}
