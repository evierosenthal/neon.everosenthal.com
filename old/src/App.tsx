/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { GameCanvas } from './components/GameCanvas';
import { Trophy, Play, RotateCcw, Shield, Heart, Zap, Pause, Home, Users, ArrowLeft, Settings, MousePointer, Keyboard, Sliders, X, Check } from 'lucide-react';
import { ControlModePreference } from './types';

export default function App() {
  const [gameState, setGameState] = useState<'START' | 'PLAYING' | 'GAMEOVER'>('START');
  const [menuMode, setMenuMode] = useState<'MAIN' | 'TWO_PLAYER' | 'CPU'>('MAIN');
  const [isLocalMultiplayer, setIsLocalMultiplayer] = useState(false);
  const [isCPUMultiplayer, setIsCPUMultiplayer] = useState(false);
  const [score, setScore] = useState(0);
  const [highScore, setHighScore] = useState(0);
  const [health, setHealth] = useState(100);
  const [isPaused, setIsPaused] = useState(false);
  const [difficulty, setDifficulty] = useState(1);
  const [controlModePreference, setControlModePreference] = useState<ControlModePreference>('both');
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem('neon_nebula_highscore');
    if (saved) setHighScore(parseInt(saved, 10));

    const savedControl = localStorage.getItem('neon_nebula_control_mode') as ControlModePreference | null;
    if (savedControl && (savedControl === 'mouse' || savedControl === 'keyboard' || savedControl === 'both')) {
      setControlModePreference(savedControl);
    }
  }, []);

  const handleControlChange = (mode: ControlModePreference) => {
    setControlModePreference(mode);
    localStorage.setItem('neon_nebula_control_mode', mode);
  };

  const handleGameOver = (finalScore: number) => {
    setGameState('GAMEOVER');
    if (finalScore > highScore) {
      setHighScore(finalScore);
      localStorage.setItem('neon_nebula_highscore', finalScore.toString());
    }
  };

  const startGame = (diff: number, localMultiplayer: boolean = false, cpuMultiplayer: boolean = false) => {
    setScore(0);
    setHealth(100);
    setDifficulty(diff);
    setIsLocalMultiplayer(localMultiplayer);
    setIsCPUMultiplayer(cpuMultiplayer);
    setGameState('PLAYING');
    setIsPaused(false);
  };

  const returnToStart = () => {
    setGameState('START');
    setMenuMode('MAIN');
    setIsPaused(false);
  };

  return (
    <div className="relative w-full h-screen bg-slate-950 overflow-hidden select-none touch-none">
      {/* Background Nebula Gradients */}
      <div className="absolute inset-0 opacity-40 pointer-events-none">
        <div className="absolute top-[-10%] left-[-10%] w-[60%] h-[60%] bg-indigo-600 rounded-full mix-blend-screen filter blur-[120px]"></div>
        <div className="absolute bottom-[10%] right-[-5%] w-[50%] h-[50%] bg-purple-700 rounded-full mix-blend-screen filter blur-[120px]"></div>
        <div className="absolute top-[40%] left-[30%] w-[40%] h-[40%] bg-emerald-800 rounded-full mix-blend-screen filter blur-[120px]"></div>
      </div>

      {/* HUD Layer */}
      {gameState === 'PLAYING' && (
        <div className="absolute inset-0 pointer-events-none z-10 p-6">
          <div className="max-w-7xl mx-auto flex flex-col h-full justify-between">
            <div className="h-20 flex items-center justify-between px-8 frosted-glass rounded-2xl pointer-events-auto">
              <div className="flex items-center gap-8">
                <div className="flex flex-col">
                  <span className="text-[10px] uppercase tracking-widest text-indigo-300 font-bold">Commander Terminal</span>
                  <span className="text-2xl font-display font-black tracking-tighter text-white">NEBULA PRIME</span>
                </div>
                <div className="h-8 w-[1px] bg-white/10"></div>
                <div className="flex gap-8">
                  <div className="flex flex-col">
                    <span className="text-[10px] text-slate-400 uppercase font-bold tracking-widest">Score</span>
                    <span className="text-xl font-display text-cyan-400 neon-text-cyan">{score.toLocaleString()}</span>
                  </div>
                  <div className="flex flex-col text-right md:text-left">
                    <span className="text-[10px] text-slate-400 uppercase font-bold tracking-widest">High Score</span>
                    <span className="text-sm font-display text-amber-400">{highScore.toLocaleString()}</span>
                  </div>
                </div>
              </div>
              
              <div className="flex items-center gap-6">
                <div className="flex flex-col items-end gap-2 w-48">
                  <div className="flex justify-between w-full text-[10px] text-slate-400 font-bold uppercase tracking-widest">
                    <span>Hull Integrity</span>
                    <span className={health > 30 ? 'text-emerald-400' : 'text-rose-500'}>{health}%</span>
                  </div>
                  <div className="w-full h-2 bg-white/5 rounded-full border border-white/10 overflow-hidden">
                    <motion.div 
                      initial={{ width: '100%' }}
                      animate={{ width: `${health}%` }}
                      className={`h-full ${health > 30 ? 'bg-gradient-to-r from-emerald-500 to-cyan-500' : 'bg-rose-500'} transition-all duration-300`}
                    />
                  </div>
                </div>
                
                <button 
                  onClick={() => setIsPaused(!isPaused)}
                  className="bg-white/10 p-3 rounded-xl border border-white/10 text-white hover:bg-white/20 transition-all shadow-xl"
                >
                  <Pause className="w-5 h-5 fill-current" />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Persistent Top Left Settings Button */}
      <button 
        onClick={() => setIsSettingsOpen(true)}
        className="fixed top-5 left-5 z-40 flex items-center gap-2 bg-slate-900/80 hover:bg-slate-800 text-slate-200 hover:text-white px-3.5 py-2.5 rounded-xl border border-white/10 shadow-xl backdrop-blur-md transition-all group pointer-events-auto"
        title="Flight Control Settings"
      >
        <Settings className="w-4.5 h-4.5 text-cyan-400 group-hover:rotate-45 transition-transform duration-300" />
        <span className="text-xs font-bold tracking-wider uppercase font-mono hidden sm:inline">Settings</span>
      </button>

      {/* Game Layer */}
      {gameState === 'PLAYING' && (
        <GameCanvas 
          onGameOver={handleGameOver}
          onScoreUpdate={setScore}
          onHealthUpdate={setHealth}
          isPaused={isPaused}
          initialDifficulty={difficulty}
          isLocalMultiplayer={isLocalMultiplayer}
          isCPUMultiplayer={isCPUMultiplayer}
          controlModePreference={controlModePreference}
        />
      )}

      {/* Overlay Screens */}
      <AnimatePresence>
        {gameState === 'START' && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 z-50 flex items-center justify-center bg-slate-950/60 backdrop-blur-md"
          >
            <div className="text-center flex flex-col items-center max-w-xl p-12 frosted-glass rounded-[3rem] mx-4 relative overflow-hidden">
              {/* Background accent in panel */}
              <div className="absolute top-0 right-0 w-32 h-32 bg-cyan-500/20 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2"></div>
              
              {menuMode === 'MAIN' && (
                <>
                  <motion.div
                    initial={{ scale: 0.9, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    className="relative"
                  >
                    <motion.h1 
                      className="text-7xl md:text-8xl font-display font-black text-white mb-2 tracking-tighter leading-none"
                    >
                      NEON<br/>NEBULA
                    </motion.h1>
                    <div className="h-1 w-24 bg-gradient-to-r from-cyan-500 to-indigo-600 mx-auto mb-6"></div>
                  </motion.div>
                  
                  <p className="text-slate-400 font-sans tracking-[0.3em] mb-12 uppercase text-xs font-bold">
                    Galactic Tactical System // 4.0
                  </p>
                  
                  <div className="grid grid-cols-3 gap-6 mb-16 w-full px-4">
                    {[
                      { icon: Shield, label: 'Guard', color: 'text-indigo-400', bg: 'bg-indigo-500/10' },
                      { icon: Heart, label: 'Persist', color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
                      { icon: Zap, label: 'Ascend', color: 'text-amber-400', bg: 'bg-amber-500/10' },
                    ].map((item, i) => (
                      <motion.div 
                        key={item.label}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.2 + i * 0.1 }}
                        className="flex flex-col items-center gap-3"
                      >
                        <div className={`p-5 rounded-2xl ${item.bg} border border-white/5 ${item.color} shadow-lg backdrop-blur-md`}>
                          <item.icon className="w-8 h-8" />
                        </div>
                        <span className="text-[10px] uppercase tracking-widest text-slate-500 font-black">{item.label}</span>
                      </motion.div>
                    ))}
                  </div>

                  <div className="flex flex-col gap-4 w-full">
                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(16, 185, 129, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.3)}
                      className="group relative px-10 py-4 bg-emerald-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-emerald-950/30 flex items-center justify-center gap-4 border border-emerald-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      EASY MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(79, 70, 229, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.85)}
                      className="group relative px-10 py-5 bg-indigo-600 text-white font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-indigo-950/50 flex items-center justify-center gap-4 border border-indigo-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      MEDIUM MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(225, 29, 72, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(1.2)}
                      className="group relative px-10 py-4 bg-rose-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-rose-950/30 flex items-center justify-center gap-4 border border-rose-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      HARD MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.05, backgroundColor: 'rgba(30, 0, 0, 1)' }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => startGame(6.0)}
                      className="group relative px-10 py-4 bg-zinc-950 text-rose-600 font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-rose-900/50 flex items-center justify-center gap-4 border-2 border-rose-600 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-rose-600/10 group-hover:bg-rose-600/30 transition-colors"></div>
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                      SUPER HARD
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(99, 102, 241, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setMenuMode('TWO_PLAYER')}
                      className="group relative px-10 py-4 bg-indigo-500/20 text-indigo-400 font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-indigo-950/20 flex items-center justify-center gap-4 border border-indigo-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      <Users className="w-5 h-5" />
                      TWO PLAYER MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(244, 63, 94, 0.9)', color: '#ffffff' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setMenuMode('CPU')}
                      className="group relative px-10 py-4 bg-rose-500/20 text-rose-400 font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-rose-950/20 flex items-center justify-center gap-4 border border-rose-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      <Zap className="w-5 h-5" />
                      CPU CO-PILOT MODE
                    </motion.button>
                  </div>
                </>
              )}

              {menuMode === 'TWO_PLAYER' && (
                <motion.div 
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="flex flex-col items-center w-full"
                >
                  <button 
                    onClick={() => setMenuMode('MAIN')}
                    className="self-start flex items-center gap-2 text-slate-400 hover:text-white transition-colors mb-6 text-xs font-bold tracking-widest uppercase bg-white/5 px-4 py-2 rounded-xl border border-white/10"
                  >
                    <ArrowLeft className="w-4 h-4" /> MAIN MENU
                  </button>

                  <motion.div className="relative mb-2">
                    <motion.h1 className="text-5xl md:text-6xl font-display font-black text-white tracking-tighter leading-none">
                      TWO PLAYER MODE
                    </motion.h1>
                    <div className="h-1 w-24 bg-gradient-to-r from-indigo-500 to-purple-500 mx-auto mt-4 mb-2"></div>
                  </motion.div>

                  <p className="text-slate-400 font-sans tracking-[0.25em] mb-10 uppercase text-xs font-bold">
                    SELECT CO-OP DIFFICULTY
                  </p>

                  <div className="flex flex-col gap-4 w-full">
                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(16, 185, 129, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.3, true, false)}
                      className="group relative px-10 py-4 bg-emerald-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-emerald-950/30 flex items-center justify-center gap-4 border border-emerald-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      EASY MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(79, 70, 229, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.85, true, false)}
                      className="group relative px-10 py-5 bg-indigo-600 text-white font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-indigo-950/50 flex items-center justify-center gap-4 border border-indigo-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      MEDIUM MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(225, 29, 72, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(1.2, true, false)}
                      className="group relative px-10 py-4 bg-rose-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-rose-950/30 flex items-center justify-center gap-4 border border-rose-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      HARD MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.05, backgroundColor: 'rgba(30, 0, 0, 1)' }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => startGame(6.0, true, false)}
                      className="group relative px-10 py-4 bg-zinc-950 text-rose-600 font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-rose-900/50 flex items-center justify-center gap-4 border-2 border-rose-600 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-rose-600/10 group-hover:bg-rose-600/30 transition-colors"></div>
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                      SUPER HARD
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                    </motion.button>
                  </div>
                </motion.div>
              )}

              {menuMode === 'CPU' && (
                <motion.div 
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="flex flex-col items-center w-full"
                >
                  <button 
                    onClick={() => setMenuMode('MAIN')}
                    className="self-start flex items-center gap-2 text-slate-400 hover:text-white transition-colors mb-6 text-xs font-bold tracking-widest uppercase bg-white/5 px-4 py-2 rounded-xl border border-white/10"
                  >
                    <ArrowLeft className="w-4 h-4" /> MAIN MENU
                  </button>

                  <motion.div className="relative mb-2">
                    <motion.h1 className="text-5xl md:text-6xl font-display font-black text-white tracking-tighter leading-none">
                      CPU CO-PILOT MODE
                    </motion.h1>
                    <div className="h-1 w-24 bg-gradient-to-r from-rose-500 to-amber-500 mx-auto mt-4 mb-2"></div>
                  </motion.div>

                  <p className="text-slate-400 font-sans tracking-[0.25em] mb-10 uppercase text-xs font-bold">
                    SELECT AI COMPANION DIFFICULTY
                  </p>

                  <div className="flex flex-col gap-4 w-full">
                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(16, 185, 129, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.3, false, true)}
                      className="group relative px-10 py-4 bg-emerald-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-emerald-950/30 flex items-center justify-center gap-4 border border-emerald-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      EASY MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(79, 70, 229, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(0.85, false, true)}
                      className="group relative px-10 py-5 bg-indigo-600 text-white font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-indigo-950/50 flex items-center justify-center gap-4 border border-indigo-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      MEDIUM MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.02, backgroundColor: 'rgba(225, 29, 72, 0.9)' }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => startGame(1.2, false, true)}
                      className="group relative px-10 py-4 bg-rose-600 text-white font-display font-black text-lg rounded-2xl transition-all shadow-xl shadow-rose-950/30 flex items-center justify-center gap-4 border border-rose-400/30 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                      HARD MODE
                    </motion.button>

                    <motion.button
                      whileHover={{ scale: 1.05, backgroundColor: 'rgba(30, 0, 0, 1)' }}
                      whileTap={{ scale: 0.95 }}
                      onClick={() => startGame(6.0, false, true)}
                      className="group relative px-10 py-4 bg-zinc-950 text-rose-600 font-display font-black text-xl rounded-2xl transition-all shadow-2xl shadow-rose-900/50 flex items-center justify-center gap-4 border-2 border-rose-600 overflow-hidden"
                    >
                      <div className="absolute inset-0 bg-rose-600/10 group-hover:bg-rose-600/30 transition-colors"></div>
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                      SUPER HARD
                      <Zap className="w-5 h-5 fill-current text-rose-500 animate-pulse" />
                    </motion.button>
                  </div>
                </motion.div>
              )}
            </div>
          </motion.div>
        )}

        {gameState === 'GAMEOVER' && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="absolute inset-0 z-50 flex items-center justify-center bg-slate-950/80 backdrop-blur-2xl px-4"
          >
            <div className="text-center p-12 frosted-glass rounded-[2.5rem] border border-rose-500/30 max-w-lg w-full relative overflow-hidden">
              <div className="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-transparent via-rose-500/50 to-transparent"></div>
              
              <h2 className="text-5xl font-display font-black text-white mb-2 leading-none">SECTOR LOST</h2>
              <p className="text-rose-400/80 uppercase tracking-[0.4em] text-[10px] font-bold mb-10">Critical Hull Failure Detected</p>
              
              <div className="bg-white/5 rounded-3xl p-8 mb-10 border border-white/5 backdrop-blur-sm shadow-inner">
                <div className="text-slate-500 text-[10px] uppercase tracking-widest font-bold mb-2">Efficiency Rating</div>
                <div className="text-6xl font-display font-black text-transparent bg-clip-text bg-gradient-to-b from-white to-slate-500 mb-6">{score.toLocaleString()}</div>
                
                <div className="h-px bg-white/10 w-full mb-6" />
                
                <div className="flex justify-between items-center text-xs font-display tracking-widest">
                  <span className="text-slate-500 font-bold">HISTORICAL PEAK</span>
                  <span className="text-cyan-400 neon-text-cyan font-black">{highScore.toLocaleString()}</span>
                </div>
              </div>

              <div className="flex gap-4">
                <button
                  onClick={returnToStart}
                  className="flex-1 px-6 py-4 bg-white/5 text-slate-400 font-display font-bold rounded-2xl border border-white/10 hover:bg-white/10 hover:text-white transition-all flex items-center justify-center gap-3"
                >
                  <Home className="w-5 h-5" />
                  COMMAND
                </button>
                <button
                  onClick={() => startGame(difficulty, isLocalMultiplayer, isCPUMultiplayer)}
                  className="flex-[2] px-6 py-4 bg-indigo-600 text-white font-display font-black rounded-2xl hover:bg-indigo-500 transition-all flex items-center justify-center gap-3 shadow-xl shadow-indigo-900/40 border border-indigo-400/30"
                >
                  <RotateCcw className="w-5 h-5" />
                  RESTART MISSION
                </button>
              </div>
            </div>
          </motion.div>
        )}

        {isPaused && gameState === 'PLAYING' && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="absolute inset-0 z-40 flex items-center justify-center bg-slate-950/60 backdrop-blur-xl"
          >
            <div className="text-center p-16 frosted-glass rounded-[3rem] border border-white/10">
              <h2 className="text-7xl font-display font-black text-white mb-4 tracking-tighter">SUSPENDED</h2>
              <p className="text-indigo-300 uppercase tracking-widest text-[10px] font-bold mb-12 italic">Awaiting Further Orders</p>
              
              <div className="flex flex-col gap-4">
                <button
                  onClick={() => setIsPaused(false)}
                  className="px-16 py-5 bg-indigo-600 text-white font-display font-black text-xl rounded-2xl hover:bg-indigo-500 transition-all shadow-2xl shadow-indigo-900/40 border border-indigo-400/30"
                >
                  RESUME MISSION
                </button>
                <button
                  onClick={returnToStart}
                  className="px-16 py-4 bg-white/5 text-slate-400 font-display font-bold rounded-2xl border border-white/10 hover:bg-white/10 hover:text-white transition-all flex items-center justify-center gap-3"
                >
                  <Home className="w-5 h-5" />
                  RETURN TO HOME
                </button>
              </div>
            </div>
          </motion.div>
        )}

        {isSettingsOpen && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/75 backdrop-blur-xl p-4"
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.9, y: 20 }}
              className="frosted-glass rounded-3xl border border-white/10 p-8 max-w-lg w-full relative overflow-hidden shadow-2xl"
            >
              <div className="flex justify-between items-center mb-6 border-b border-white/10 pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400">
                    <Sliders className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-xl font-display font-black text-white tracking-tight">GAME SETTINGS</h3>
                    <p className="text-[10px] uppercase tracking-widest text-slate-400 font-bold">Flight Control Configuration</p>
                  </div>
                </div>
                <button
                  onClick={() => setIsSettingsOpen(false)}
                  className="p-2 rounded-xl bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="mb-8">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-300 mb-3 block">
                  Player 1 Input Controls
                </label>
                <div className="grid grid-cols-1 gap-3">
                  {[
                    {
                      id: 'both' as const,
                      title: 'Both (Mouse & Keyboard)',
                      desc: 'Tracks mouse cursor + WASD/Arrow keys for instant thrust',
                      icon: Sliders,
                      badge: 'Recommended'
                    },
                    {
                      id: 'mouse' as const,
                      title: 'Mouse Only',
                      desc: 'Ship smoothly tracks mouse position across space',
                      icon: MousePointer
                    },
                    {
                      id: 'keyboard' as const,
                      title: 'Keyboard Only',
                      desc: 'Manual WASD or Arrow keys vector thrust control',
                      icon: Keyboard
                    }
                  ].map((option) => {
                    const isSelected = controlModePreference === option.id;
                    const Icon = option.icon;
                    return (
                      <button
                        key={option.id}
                        onClick={() => handleControlChange(option.id)}
                        className={`flex items-center justify-between p-4 rounded-2xl border text-left transition-all ${
                          isSelected
                            ? 'bg-cyan-500/15 border-cyan-400 text-white shadow-lg shadow-cyan-950/40 ring-1 ring-cyan-400/50'
                            : 'bg-white/5 border-white/5 text-slate-400 hover:bg-white/10 hover:text-slate-200'
                        }`}
                      >
                        <div className="flex items-center gap-4">
                          <div className={`p-3 rounded-xl ${isSelected ? 'bg-cyan-500 text-slate-950 font-black' : 'bg-white/5 text-slate-400'}`}>
                            <Icon className="w-5 h-5" />
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="font-bold text-sm text-white">{option.title}</span>
                              {option.badge && (
                                <span className="text-[9px] font-black uppercase px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
                                  {option.badge}
                                </span>
                              )}
                            </div>
                            <p className="text-xs text-slate-400 mt-0.5">{option.desc}</p>
                          </div>
                        </div>
                        {isSelected && (
                          <div className="w-6 h-6 rounded-full bg-cyan-400 text-slate-950 flex items-center justify-center font-bold">
                            <Check className="w-4 h-4 stroke-[3]" />
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="flex justify-end">
                <button
                  onClick={() => setIsSettingsOpen(false)}
                  className="px-6 py-3 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-display font-black text-sm rounded-xl transition-all shadow-lg shadow-cyan-950/50"
                >
                  DONE
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Subtle Grid Overlay */}
      <div className="absolute inset-0 pointer-events-none opacity-[0.03]" style={{ 
        backgroundImage: 'radial-gradient(circle, #ffffff 1px, transparent 1px)',
        backgroundSize: '40px 40px'
      }} />
    </div>
  );
}
