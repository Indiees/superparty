using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class Room{

    public Player player;
    public string roomId;

    public Room(Player player, string roomId) {
        this.roomId = roomId;
        this.player = player;
    }
}
