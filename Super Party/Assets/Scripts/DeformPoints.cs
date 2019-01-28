using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class DeformPoints : MonoBehaviour {
	public Material deformMaterial;
	public string arrayLocation = "DeformPoints";
	public Transform[] transforms;

	private int locationId;

	private void Start() {
		locationId = Shader.PropertyToID(arrayLocation);		
	}
	// Update is called once per frame
	void Update () {
		Vector4[] positions = new Vector4[transforms.Length];

		for (int i = 0; i < transforms.Length; i++) {
			positions[i] = transforms[i].position;
		}

		deformMaterial.SetVectorArray(locationId, positions);
	}
}
