using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DiscoFloorScript : MonoBehaviour {

    Renderer rend;
    Color RandoColo;
    Light Emit;

	void Start ()
    {
        RandoColo = Random.ColorHSV(0f, 1f, 1f, 1f, 0.5f, 1f);
        rend = GetComponent<Renderer>();
        rend.material.SetColor("_Color", RandoColo);
        Emit = GetComponent<Light>();
        Emit.color = RandoColo;
	}

    public void ColorChange()
    {
        RandoColo = Random.ColorHSV(0f, 1f, 1f, 1f, 0.5f, 1f);
        rend = GetComponent<Renderer>();
        rend.material.SetColor("_Color", RandoColo);
        Emit.color = RandoColo;
        Debug.Log("Color Changed");
    }
	
}
