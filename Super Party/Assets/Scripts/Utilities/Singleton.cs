using UnityEngine;

public class Singleton<T> : MonoBehaviour where T : MonoBehaviour {

	#region Class members
	private static T instance;
	#endregion

	#region Class accesors
	public static T Instance {
		get {
			if (instance == null)
				instance = FindObjectOfType<T> ();

			return instance;
		}
	}
	#endregion

	#region Class overrides
	public virtual void Awake () {
		instance = FindObjectOfType<T> ();
	}
	#endregion
}