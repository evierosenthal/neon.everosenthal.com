import express from "express";
import path from "path";
import { createServer } from "http";
import { Server } from "socket.io";
import { createServer as createViteServer } from "vite";

async function startServer() {
  const app = express();
  const httpServer = createServer(app);
  const io = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"]
    }
  });

  const PORT = 3000;

  // Track connected players
  const players = new Map<string, { id: string; username: string; status: 'Lobby' | 'Playing'; roomId?: string }>();

  io.on("connection", (socket) => {
    console.log("Player connected:", socket.id);
    
    // Initial assignment
    const username = `Pilot-${socket.id.substring(0, 4).toUpperCase()}`;
    players.set(socket.id, { id: socket.id, username, status: 'Lobby' });

    // Sync player list to all in lobby
    const broadcastLobby = () => {
      const lobbyPlayers = Array.from(players.values());
      io.emit("lobby_players", lobbyPlayers);
    };

    broadcastLobby();

    socket.on("request_lobby_players", () => {
      broadcastLobby();
    });

    socket.on("set_username", (newUsername: string) => {
      const player = players.get(socket.id);
      if (player) {
        player.username = newUsername;
        broadcastLobby();
      }
    });

    socket.on("invite_player", (targetId: string) => {
      console.log(`Invite from ${socket.id} to ${targetId}`);
      const inviter = players.get(socket.id);
      if (inviter) {
        io.to(targetId).emit("invite_received", {
          fromId: socket.id,
          fromName: inviter.username
        });
      }
    });

    socket.on("accept_invite", (inviterId: string) => {
      const roomId = `room-${inviterId}-${socket.id}`;
      const player1 = players.get(inviterId);
      const player2 = players.get(socket.id);

      if (player1 && player2) {
        player1.status = 'Playing';
        player1.roomId = roomId;
        player2.status = 'Playing';
        player2.roomId = roomId;

        socket.join(roomId);
        const inviterSocket = io.sockets.sockets.get(inviterId);
        if (inviterSocket) {
          inviterSocket.join(roomId);
        }

        io.to(roomId).emit("game_start", {
          roomId,
          players: [player1, player2]
        });
        
        broadcastLobby();
      }
    });

    socket.on("decline_invite", (inviterId: string) => {
      io.to(inviterId).emit("invite_declined", { fromName: players.get(socket.id)?.username });
    });

    // Game state sync
    socket.on("player_update", (data: any) => {
      const player = players.get(socket.id);
      if (player?.roomId) {
        socket.to(player.roomId).emit("remote_player_update", {
          id: socket.id,
          ...data
        });
      }
    });

    socket.on("game_event", (data: any) => {
        const player = players.get(socket.id);
        if (player?.roomId) {
            if (data.type === 'GAMEOVER') {
                player.status = 'Lobby';
                broadcastLobby();
            }
            socket.to(player.roomId).emit("remote_game_event", data);
        }
    });

    socket.on("disconnect", () => {
      console.log("Player disconnected:", socket.id);
      const player = players.get(socket.id);
      if (player?.roomId) {
        io.to(player.roomId).emit("remote_game_event", { type: 'TEAMMATE_DISCONNECTED' });
      }
      players.delete(socket.id);
      broadcastLobby();
    });
  });

  // API routes
  app.get("/api/health", (req, res) => {
    res.json({ status: "ok" });
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  httpServer.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
