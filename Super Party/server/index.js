const app = require('express')()
const http = require('http').Server(app)
const io = require('socket.io')(http)
const uuid = require('uuid/v4')

const port = process.env.PORT || 8080

const playersPerRoom = 2
const rooms = []

function findRoomIndex(roomId) {
  return rooms.findIndex(room => room.id === roomId)
}

app.get('/', (req, res) => {
  res.sendFile(__dirname + '/index.html')
})

io.on('connection', socket => {
  socket.emit('open')

  socket.on('create room', ({ roomId = '', player = {} }) => {
    console.log({roomId, player})
    if (!roomId.trim()) {
      socket.emit('create room', {
        roomId,
        msgCode: 'noRoomName',
        msg: 'No room name'
      })
    }

    const roomIndex = findRoomIndex(roomId)

    if (roomIndex === -1) {
      const user = { host: true, ...player }

      rooms.push({
        id: roomId,
        players: [user]
      })
  
      socket.join(roomId)
      
      socket.emit('create room', {
        room: rooms[findRoomIndex(roomId)]
      })
    } else {
      socket.emit('create room', {
        roomId,
        msgCode: 'sameRoom',
        msg: 'Room name already exist'
      })
    }
  })

  socket.on('join room', ({ roomId = '', player = {} }) => {
    let roomIndex = findRoomIndex(roomId)
    
    if (roomIndex === -1) {
      socket.emit('join room', {
        joined: false,
        msgCode: 'noRoom',
        msg: 'Room not found'
      })
    } else if ((rooms[roomIndex].players || []).length === playersPerRoom) {
      socket.emit('join room', {
        joined: false,
        msgCode: 'roomFull',
        msg: 'The room is full'
      })
    } else {
      (rooms[roomIndex].players || []).push({ host: false, ...player })

      socket.join(roomId)
      console.log({ players: rooms[roomIndex].players })
      io.to(roomId).emit('join room', {
        joined: true,
        players: rooms[roomIndex].players
      })
    }
  })

  socket.on('leave room', ({ roomId = '', player = {} }) => {
    const roomIndex = findRoomIndex(roomId)
    const userIndex = rooms[roomIndex].players.findIndex(user => user.id === player.id)

    rooms[roomIndex].players.splice(userIndex, 1)
    socket.leave(roomId)

    let roomDisband = false
    const playersInRoom = (rooms[roomIndex].players || []).length

    if (playersInRoom === 0) {
      rooms.splice(roomIndex, 1)
      roomDisband = true
    } else if (playersInRoom === 1) {
      rooms[roomIndex].players[0] = {
        ...rooms[roomIndex].players[0],
        host: true
      }
    }

    io.to(roomId).emit('leave room', {
      roomDisband,
      player: player.id,
      players: rooms[roomIndex].players
    })

    socket.emit('leave room', {
      roomDisband,
      player: player.id,
      players: rooms[roomIndex].players
    })
  })

  socket.on('start game', ({ roomId = '', roomProps = {}, players = [], npcs = [], boosters = [] }) => {
    const roomIndex = findRoomIndex(roomId)

    rooms[roomIndex] = {
      ...roomProps,
      ...rooms[roomIndex],
      players,
      npcs,
      boosters
    }

    io.to(roomId).emit('start game', {
      room: rooms[roomIndex]
    })
  })

  socket.on('end game', ({ roomId = '', player = {}, status }) => {
    const roomIndex = findRoomIndex(roomId)
    const user = rooms[roomIndex].players.find(user => user.id === player.id)

    io.to(roomId).emit('end game', {
      player: user,
      status
    })
  })

  socket.on('update player', ({ roomId = '', player = {} }) => {
    const roomIndex = findRoomIndex(roomId)
    const playerIndex = rooms[roomIndex].players.findIndex(user => user.id === player.id)
    rooms[roomIndex].players[playerIndex] = player

    io.to(roomId).emit('update player', {
      player: rooms[roomIndex].players[playerIndex]
    })
  })

  socket.on('update npc', ({ roomId = '', npc = {} }) => {
    const roomIndex = findRoomIndex(roomId)
    const npcIndex = rooms[roomIndex].npcs.findIndex(pc => pc.id === npc.id)
    rooms[roomIndex].npcs[npcIndex] = npc

    io.to(roomId).emit('update npc', {
      npc: rooms[roomIndex].npcs[npcIndex]
    })
  })

  socket.on('update booster', ({ roomId = '', booster = {} }) => {
    const roomIndex = findRoomIndex(roomId)
    const boosterIndex = rooms[roomIndex].boosters.findIndex(boost => boost.id === booster.id)
    rooms[roomIndex].boosters[boosterIndex] = booster

    io.to(roomId).emit('update booster', {
      booster: rooms[roomIndex].boosters[boosterIndex]
    })
  })
})

http.listen(port, function() {
  console.log('listening on *:' + port)
})