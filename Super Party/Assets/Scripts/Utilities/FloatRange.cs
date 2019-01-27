using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[System.Serializable]
public class FloatRange {

	#region Class members
	public float min;
	public float max;
	#endregion

	#region Class accesors
	public float Value {
		get { return Random.Range (min, max); }
	}
	#endregion

	#region Class overrides
	#endregion

	#region Class implementation
	#endregion

	#region Interface implementation
	#endregion
}