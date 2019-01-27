using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class PartyBooster : MonoBehaviour {

	#region Class members
	public Personality attractedPersonality;
	[Range (0, 100)] public int alikePercent;

	public FloatRange stayAreaRange;
	#endregion

	#region Class accesors
	#endregion

	#region Class overrides
	private void OnDrawGizmos () {
		Gizmos.DrawWireSphere (transform.position, stayAreaRange.min);
		Gizmos.DrawWireSphere (transform.position, stayAreaRange.max);
	}
	#endregion

	#region Class implementation
	public Vector3 GetRandomPointInStayArea () {
		float angle = Random.Range (0, 360);
		float magnitude = stayAreaRange.Value;

		return transform.position + Quaternion.AngleAxis (angle, Vector3.up) * Vector3.right * magnitude;
	}

	public bool AlikePersonality (Personality personality, out float alikePercent) {
		float absolutePercent = 0;
		for (int i = 0; i < attractedPersonality.traits.Length; i++)
			absolutePercent += personality.traits[i].value / attractedPersonality.traits[i].value * 100;

		alikePercent = absolutePercent / attractedPersonality.traits.Length;
		return alikePercent >= this.alikePercent;
	}
	#endregion

	#region Interface implementation
	#endregion
}