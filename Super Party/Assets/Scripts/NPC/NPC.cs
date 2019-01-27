using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.UI;

public class NPC : MonoBehaviour {

	#region Class members
	public bool avaliable;
	public NPCData data;

	private NavMeshAgent navAgent;
	#endregion

	#region Class accesors
	#endregion

	#region Class overrides
	private void Awake () {
		navAgent = GetComponent<NavMeshAgent> ();
	}
	#endregion

	#region Class implementation
	public void SetDestination (Vector3 position) {
		navAgent.SetDestination (position);
	}

	public void SetRandomDestination () {

	}

	[ContextMenu ("Add To Manager")]
	public void AddToManager () {
		PartyManager.Instance.AddNPC (this);
	}
	#endregion

	#region Interface implementation
	#endregion
}