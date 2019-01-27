using SocketIO;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Server : MonoBehaviour {

    public static Server Instance;
    private SocketIOComponent socket;
    public GameObject playerPrefab;
    public Dictionary<string, GameObject> players = new Dictionary<string, GameObject>();

    private void Awake()
    {
        Instance = this;
        socket = GetComponent<SocketIOComponent>();
    }

    private void Start()
    {
        socket = GetComponent<SocketIOComponent>();
        socket.On("open", OnConnected);
        socket.On("spawn", OnSpawned);
        socket.On("move", OnMove);
    }

    private void CreateRoom(SocketIOEvent e)
    {
        print("Room Id: " + e.data);
    }

    private void OnConnected(SocketIOEvent e)
    {
        print("Connected");
        Room room = new Room("12345", "2468");
        JSONObject roomToJson = new JSONObject(JsonUtility.ToJson(room));
        socket.Emit("create room", roomToJson);
        socket.On("create room", CreateRoom);
    }

    private void OnSpawned(SocketIOEvent e)
    {
        print("Spawned" + e.data);
        GameObject player = (GameObject)Instantiate(playerPrefab);
        player.name = e.data["id"].ToString();
        players.Add(player.name, player);
        //print("Count:" + players.Count);
    }

    private void OnMove(SocketIOEvent e)
    {
        //Debug.Log("Player moved" + e.data);
        Vector3 position = new Vector3(FloatFromJson(e.data, "x"), FloatFromJson(e.data, "y"), 0);
        GameObject player = players[e.data["id"].ToString()];
        //player.GetComponent<PlayerController>().Movement(position);
    }

    private float FloatFromJson(JSONObject data, string key)
    {
        return float.Parse(data[key].ToString().Replace("\"", ""));
    }
}
