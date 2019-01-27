using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[System.Serializable]
public class Personality {

	#region Class members
	public PersonalityTrait[] traits;
	#endregion

	#region Class accesors
	#endregion

	#region Class overrides
	#endregion

	#region Class implementation
	public float MatchValue () {
		float value = 0;
		foreach (PersonalityTrait trait in traits)
			value += 10 - trait.value;

		return value;
	}
	#endregion

	#region Interface implementation
	#endregion
}