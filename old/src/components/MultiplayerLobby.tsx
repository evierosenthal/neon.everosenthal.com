import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { User, Send, Check, X, Users, Zap } from 'lucide-react';
import { io, Socket } from 'socket.io-client';

interface Player {
  id: string;
  username: string;
  status: 'Lobby' | 'Playing';
}

interface MultiplayerLobbyProps {
  socket: Socket;
  onGameStart: (socket: Socket, roomId: string, players: Player[], isHost: boolean) => void;
  onBack: () => void;
}

export const MultiplayerLobby: React.FC<MultiplayerLobbyProps> = ({ socket, onGameStart, onBack }) => {
  const [players, setPlayers] = useState<Player[]>([]);
  const [invite, setInvite] = useState<{ fromId: string; fromName: string } | null>(null);
  const [statusMessage, setStatusMessage] = useState<string>('Connecting to command center...');

  useEffect(() => {
    if (socket.connected) {
      setStatusMessage('Encryption established. Waiting for other pilots...');
    }

    socket.on('connect', () => {
      setStatusMessage('Encryption established. Waiting for other pilots...');
    });

    socket.on('lobby_players', (playerList: Player[]) => {
      setPlayers(playerList.filter(p => p.id !== socket.id));
    });

    socket.on('invite_received', (data: { fromId: string; fromName: string }) => {
      setInvite(data);
    });

    socket.on('invite_declined', (data: { fromName: string }) => {
      setStatusMessage(`${data.fromName} declined the mission challenge.`);
      setTimeout(() => setStatusMessage('Waiting for other pilots...'), 3000);
    });

    socket.on('game_start', (data: { roomId: string; players: Player[] }) => {
      const isHost = data.players[0].id === socket.id;
      onGameStart(socket, data.roomId, data.players, isHost);
    });

    // Initial request for players if already connected
    socket.emit('request_lobby_players');

    return () => {
      socket.off('connect');
      socket.off('lobby_players');
      socket.off('invite_received');
      socket.off('invite_declined');
      socket.off('game_start');
    };
  }, [socket, onGameStart]);

  const sendInvite = (targetId: string) => {
    if (socket) {
      socket.emit('invite_player', targetId);
      setStatusMessage('Transmission sent. Awaiting response...');
    }
  };

  const acceptInvite = () => {
    if (socket && invite) {
      socket.emit('accept_invite', invite.fromId);
      setInvite(null);
    }
  };

  const declineInvite = () => {
    if (socket && invite) {
      socket.emit('decline_invite', invite.fromId);
      setInvite(null);
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="max-w-2xl w-full frosted-glass rounded-[2.5rem] p-8 border border-white/10 shadow-2xl relative overflow-hidden"
    >
      <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2"></div>
      
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-4">
          <div className="p-3 bg-indigo-500/20 rounded-xl border border-indigo-500/30 text-indigo-400">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <h2 className="text-3xl font-display font-black text-white leading-tight">TACTICAL LOBBY</h2>
            <p className="text-indigo-300/60 uppercase tracking-widest text-[10px] font-bold">Synchronize with other pilots</p>
          </div>
        </div>
        <button 
          onClick={onBack}
          className="px-4 py-2 bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white rounded-xl border border-white/5 transition-all text-sm font-bold"
        >
          DISCONNECT
        </button>
      </div>

      <div className="bg-white/5 rounded-2xl p-4 mb-6 border border-white/5 min-h-[40px] flex items-center justify-center">
        <span className="text-indigo-400 font-mono text-xs tracking-tight animate-pulse">{statusMessage}</span>
      </div>

      <div className="space-y-3 max-h-[300px] overflow-y-auto pr-2 custom-scrollbar mb-8">
        {players.length === 0 ? (
          <div className="text-center py-12 text-slate-500 border border-dashed border-white/10 rounded-2xl">
            <p className="text-sm">No other pilots detected in the surrounding sectors.</p>
          </div>
        ) : (
          players.map(player => (
            <div 
              key={player.id}
              className="flex items-center justify-between p-4 bg-white/5 hover:bg-white/10 rounded-2xl border border-white/5 transition-all group"
            >
              <div className="flex items-center gap-4">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-white shadow-lg ${player.status === 'Playing' ? 'bg-rose-500/20 text-rose-400 border border-rose-500/30' : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'}`}>
                  <User className="w-5 h-5" />
                </div>
                <div>
                  <div className="text-white font-bold">{player.username}</div>
                  <div className={`text-[10px] uppercase font-black ${player.status === 'Playing' ? 'text-rose-500' : 'text-emerald-500'}`}>
                    {player.status === 'Playing' ? 'In Mission' : 'Ready for Deployment'}
                  </div>
                </div>
              </div>
              
              {player.status === 'Lobby' && (
                <button
                  onClick={() => sendInvite(player.id)}
                  className="px-6 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-black rounded-xl transition-all shadow-lg shadow-indigo-900/20 flex items-center gap-2 group-hover:scale-105"
                >
                  <Send className="w-3 h-3" />
                  CHALLENGE
                </button>
              )}
            </div>
          ))
        )}
      </div>

      <AnimatePresence>
        {invite && (
          <motion.div
            initial={{ y: 50, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 50, opacity: 0 }}
            className="absolute bottom-6 left-6 right-6 p-6 bg-slate-900 border-2 border-indigo-500 rounded-3xl shadow-2xl z-50 flex flex-col md:flex-row items-center justify-between gap-4"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-indigo-500 rounded-full flex items-center justify-center animate-pulse">
                <Zap className="w-6 h-6 text-white fill-current" />
              </div>
              <div>
                <div className="text-indigo-400 font-black text-xs uppercase tracking-widest">Incoming Mission Request</div>
                <div className="text-white font-display text-xl font-black">{invite.fromName} has challenged you!</div>
              </div>
            </div>
            <div className="flex gap-3 w-full md:w-auto">
              <button 
                onClick={declineInvite}
                className="flex-1 md:flex-none px-6 py-3 bg-rose-500/10 text-rose-500 rounded-xl hover:bg-rose-500/20 transition-all font-bold flex items-center justify-center gap-2"
              >
                <X className="w-4 h-4" /> IGNORE
              </button>
              <button 
                onClick={acceptInvite}
                className="flex-[2] md:flex-none px-8 py-3 bg-emerald-600 text-white rounded-xl hover:bg-emerald-500 transition-all font-black shadow-lg shadow-emerald-900/40 flex items-center justify-center gap-2"
              >
                <Check className="w-4 h-4" /> JOIN MISSON
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};
