using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Room{

    string user;
    string roomId;

    public Room(string user, string roomId) {
        this.roomId = roomId;
        this.user = user;
    }
}
