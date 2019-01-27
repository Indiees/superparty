using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class PartyManager : Singleton<PartyManager> {

	#region Class members
	public PartyBooster[] partyBoosters;
	public List<NPC> npcs;

	public NPC test;
	public int partyIndex;
	#endregion

	#region Class accesors
	#endregion

	#region Class overrides
	#endregion

	#region Class implementation
	[ContextMenu ("AAA")]
	public void Check () {
		float aaa = 0;
		Debug.Log (partyBoosters[partyIndex].AlikePersonality (test.data.personality, out aaa));
	}

	public void AddNPC (NPC npc) {
		foreach (NPC currentNPC in npcs) {
			if (currentNPC.avaliable) {
				if (npc.data.personality.MatchValue () >= currentNPC.data.personality.MatchValue ()) {
					npc.SetDestination (currentNPC.transform.position);
					npcs.Add (npc);
					return;
				}
			}
		}

		PartyBooster alikeBooster = null;
		float maxAlikePersonalityPercent = 0;
		for (int i = 0; i < partyBoosters.Length; i++) {
			PartyBooster booster = partyBoosters[i];

			float alikePercent = 0;
			if (booster.AlikePersonality (npc.data.personality, out alikePercent)) {
				if (alikePercent >= maxAlikePersonalityPercent) {
					maxAlikePersonalityPercent = alikePercent;
					alikeBooster = booster;
				}
			}
		}

		if (alikeBooster != null) {
			npc.SetDestination (alikeBooster.GetRandomPointInStayArea ());
		}
		else {
			npc.SetRandomDestination ();
			npc.avaliable = true;
		}

		npcs.Add (npc);
	}
	#endregion

	#region Interface implementation
	#endregion
}