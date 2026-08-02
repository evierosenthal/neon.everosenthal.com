/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useEffect, useRef, useState } from 'react';
import { Entity, GameState, ControlModePreference } from '../types';

interface GameCanvasProps {
  onGameOver: (score: number) => void;
  onScoreUpdate: (score: number) => void;
  onHealthUpdate: (health: number) => void;
  isPaused: boolean;
  initialDifficulty: number;
  isLocalMultiplayer: boolean;
  isCPUMultiplayer?: boolean;
  controlModePreference?: ControlModePreference;
}

const PLAYER_RADIUS = 15;
const ASTEROID_MIN_RADIUS = 10;
const ASTEROID_MAX_RADIUS = 30;
const BASE_SPEED = 2;
const SPAWN_RATE = 0.03; // Increased base spawn rate for more action
const STAR_COUNT = 50;

export const GameCanvas: React.FC<GameCanvasProps> = ({ 
  onGameOver, 
  onScoreUpdate, 
  onHealthUpdate,
  isPaused,
  initialDifficulty,
  isLocalMultiplayer,
  isCPUMultiplayer = false,
  controlModePreference = 'both'
}) => {
  const propsRef = useRef({ 
    onGameOver, 
    onScoreUpdate, 
    onHealthUpdate,
    isLocalMultiplayer,
    isCPUMultiplayer,
    initialDifficulty,
    controlModePreference
  });
  
  useEffect(() => {
    propsRef.current = { 
      onGameOver, 
      onScoreUpdate, 
      onHealthUpdate,
      isLocalMultiplayer,
      isCPUMultiplayer,
      initialDifficulty,
      controlModePreference
    };
  }, [onGameOver, onScoreUpdate, onHealthUpdate, isLocalMultiplayer, isCPUMultiplayer, initialDifficulty, controlModePreference]);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stateRef = useRef<GameState>({
    player: { id: 'player1', x: 0, y: 0, vx: 0, vy: 0, radius: PLAYER_RADIUS, color: '#00ffff', type: 'player' },
    asteroids: [],
    particles: [],
    collectibles: [],
    projectiles: [],
    powerUps: [],
    enemies: [],
    floatingTexts: [],
    score: 0,
    health: 100,
    isGameOver: false,
    isPaused: false,
    highScore: 0,
    difficulty: initialDifficulty,
    activeEffects: {
      shield: 0,
      speedBoost: 0,
      weaponUpgrade: 0,
      magnet: 0,
    },
  });

  const keysPressed = useRef<Record<string, boolean>>({});
  const controlMode = useRef<'mouse' | 'keyboard'>('mouse');
  const lastShotTime = useRef(0);
  const lastShotTime2 = useRef(0);

  const mousePos = useRef({ x: 0, y: 0 });
  const shakeRef = useRef(0);
  const animationId = useRef<number>(0);
  const starsRef = useRef<{ x: number, y: number, s: number }[]>([]);
  const mountTime = useRef(Date.now());

  // Initialize player positions and background stars
  useEffect(() => {
    const hasPlayer2 = isLocalMultiplayer || isCPUMultiplayer;
    stateRef.current.player.x = window.innerWidth / (hasPlayer2 ? 3 : 2);
    stateRef.current.player.y = window.innerHeight / 2;
    
    if (hasPlayer2) {
      stateRef.current.player2 = { id: 'player2', x: (window.innerWidth / 3) * 2, y: window.innerHeight / 2, vx: 0, vy: 0, radius: PLAYER_RADIUS, color: '#fb7185', type: 'player' };
    } else {
      stateRef.current.player2 = undefined;
    }

    mousePos.current = { x: window.innerWidth / 2, y: window.innerHeight / 2 };

    // Spawn initial 'W' weapon power-up so player can grab it to enable shooting right away
    if (stateRef.current.powerUps.length === 0) {
      stateRef.current.powerUps.push({
        id: 'initial_weapon',
        x: window.innerWidth / 2,
        y: window.innerHeight / 3,
        vx: (Math.random() - 0.5) * 1.5,
        vy: (Math.random() - 0.5) * 1.5,
        radius: 12,
        color: '#ef4444',
        type: 'powerup',
        life: 1800,
        maxLife: 1800,
        subType: 'weapon',
      });
    }

    starsRef.current = Array.from({ length: STAR_COUNT }, () => ({
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      s: Math.random() * 2 + 0.5
    }));

    // Clear keys pressed and reset tutorial timer on mode change
    keysPressed.current = {};
    mountTime.current = Date.now();
  }, [isLocalMultiplayer, isCPUMultiplayer]);

  const createParticle = (x: number, y: number, color: string, isThruster: boolean = false) => {
    const angle = Math.random() * Math.PI * 2;
    const speed = isThruster ? (Math.random() * 2 + 1) : (Math.random() * 3 + 1);
    const life = isThruster ? (8 + Math.random() * 8) : (20 + Math.random() * 10);
    return {
      id: Math.random().toString(36),
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      radius: isThruster ? (Math.random() * 2 + 1) : (Math.random() * 2.5 + 1),
      color,
      type: 'particle' as const,
      life,
      maxLife: life,
    };
  };

  const createCollectible = (width: number, height: number) => {
    return {
      id: Math.random().toString(36),
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 1,
      vy: (Math.random() - 0.5) * 1,
      radius: 9,
      color: '#fbbf24', // Amber
      type: 'collectible' as const,
    };
  };

  const createProjectile = (x: number, y: number, angle: number, color: string = '#00ffff') => {
    const speed = 10;
    return {
      id: Math.random().toString(36),
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      radius: 4,
      color,
      type: 'projectile' as const,
      life: 100,
    };
  };

  const createPowerUp = (width: number, height: number, difficulty: number = propsRef.current.initialDifficulty) => {
    // Magnet is rare (~6% chance) and ONLY spawns in Medium mode (difficulty >= 0.8), Hard mode, and Super Hard mode.
    const isMediumOrHigher = difficulty >= 0.8;
    const rand = Math.random();
    let type: 'shield' | 'speed' | 'weapon' | 'magnet';
    if (isMediumOrHigher && rand < 0.06) {
      type = 'magnet';
    } else {
      const others = ['shield', 'speed', 'weapon'] as const;
      type = others[Math.floor(Math.random() * others.length)];
    }
    const colors = { shield: '#a855f7', speed: '#22c55e', weapon: '#ef4444', magnet: '#c084fc' };
    
    return {
      id: Math.random().toString(36),
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
      radius: 12,
      color: colors[type],
      type: 'powerup' as const,
      life: 1200, // 20 seconds at 60fps
      maxLife: 1200,
      subType: type,
    };
  };

  const addFloatingText = (x: number, y: number, text: string, color: string = '#ffffff', scale: number = 1.0) => {
    stateRef.current.floatingTexts.push({
      id: Math.random().toString(36),
      x,
      y,
      text,
      color,
      alpha: 1.0,
      life: 60,
      scale,
    });
  };

  const createShockwaveRing = (x: number, y: number, color: string, count: number = 8) => {
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2;
      const speed = 3.0;
      const life = 18 + Math.random() * 10;
      stateRef.current.particles.push({
        id: Math.random().toString(36),
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius: 2.5,
        color,
        type: 'particle' as const,
        life,
        maxLife: life,
      });
    }
  };

  const createAsteroid = (width: number, height: number, difficulty: number) => {
    const side = Math.floor(Math.random() * 4);
    let x = 0, y = 0;
    if (side === 0) { x = Math.random() * width; y = -50; }
    else if (side === 1) { x = width + 50; y = Math.random() * height; }
    else if (side === 2) { x = Math.random() * width; y = height + 50; }
    else { x = -50; y = Math.random() * height; }

    const targetX = width / 2 + (Math.random() - 0.5) * width;
    const targetY = height / 2 + (Math.random() - 0.5) * height;
    const angle = Math.atan2(targetY - y, targetX - x) + (Math.random() - 0.5) * 0.2; 
    const superHardSpeedBoost = difficulty >= 4.0 ? 2.5 : 1.0;
    const speed = (Math.random() * 2.5 + 2.0) * difficulty * superHardSpeedBoost; // Extra speed boost for Super Hard mode

    const vertexCount = 8 + Math.floor(Math.random() * 5);
    const vertices: number[] = [];
    for (let i = 0; i < vertexCount; i++) {
      vertices.push(0.85 + Math.random() * 0.3);
    }

    const craterCount = 2 + Math.floor(Math.random() * 2);
    const craters = Array.from({ length: craterCount }, () => ({
      rx: (Math.random() - 0.5) * 0.5,
      ry: (Math.random() - 0.5) * 0.5,
      r: 0.12 + Math.random() * 0.12,
    }));

    return {
      id: Math.random().toString(36),
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      radius: ASTEROID_MIN_RADIUS + Math.random() * (ASTEROID_MAX_RADIUS - ASTEROID_MIN_RADIUS),
      color: `hsl(${280 + Math.random() * 40}, 70%, 50%)`, // Purples/Magentas
      type: 'asteroid' as const,
      vertices,
      craters,
      rotation: Math.random() * Math.PI * 2,
      spinSpeed: (Math.random() - 0.5) * 0.03,
    };
  };

  const update = () => {
    if (isPaused || stateRef.current.isGameOver) return;

    const state = stateRef.current;
    const canvas = canvasRef.current;
    if (!canvas) return;

    // Defensive Player Initializations & Bounds Fallbacks
    const hasPlayer2 = propsRef.current.isLocalMultiplayer || propsRef.current.isCPUMultiplayer;
    if (!state.player) {
      state.player = { 
        id: 'player1', 
        x: canvas.width / (hasPlayer2 ? 3 : 2) || window.innerWidth / 2 || 150, 
        y: canvas.height / 2 || window.innerHeight / 2 || 300, 
        vx: 0, 
        vy: 0, 
        radius: PLAYER_RADIUS, 
        color: '#00ffff', 
        type: 'player' 
      };
    }
    if (hasPlayer2 && !state.player2) {
      state.player2 = { 
        id: 'player2', 
        x: (canvas.width / 3) * 2 || (window.innerWidth / 3) * 2 || 450, 
        y: canvas.height / 2 || window.innerHeight / 2 || 300, 
        vx: 0, 
        vy: 0, 
        radius: PLAYER_RADIUS, 
        color: '#fb7185', 
        type: 'player' 
      };
    } else if (!hasPlayer2 && state.player2) {
      state.player2 = undefined;
    }

    // Background stars parallax
    starsRef.current.forEach(star => {
      star.y += star.s * 0.5;
      if (star.y > canvas.height) star.y = 0;
    });

    // Movement: Player 1 (WASD/Arrows) or Mouse
    const moveSpeed = state.activeEffects.speedBoost > 0 ? 8 : 5;
    const accel = 0.5;
    const friction = 0.92;

    let usingKeyboard = false;
    const keysToCheck = [
      'w', 'a', 's', 'd', 'W', 'A', 'S', 'D', 'KeyW', 'KeyA', 'KeyS', 'KeyD',
      'ArrowUp', 'ArrowLeft', 'ArrowDown', 'ArrowRight', 'Up', 'Left', 'Down', 'Right'
    ];
    for (const key of keysToCheck) {
      if (keysPressed.current[key]) {
        usingKeyboard = true;
        break;
      }
    }

    if (usingKeyboard) {
      controlMode.current = 'keyboard';
    }

    // --- PLAYER 1 MOVEMENT ---
    const userControlMode = propsRef.current.controlModePreference || 'both';
    if (propsRef.current.isLocalMultiplayer) {
      // Local 2P mode: Player 1 uses WASD keyboard controls (so Player 2 can use Arrow keys)
      if (keysPressed.current['KeyW'] || keysPressed.current['w'] || keysPressed.current['W']) state.player.vy -= accel;
      if (keysPressed.current['KeyS'] || keysPressed.current['s'] || keysPressed.current['S']) state.player.vy += accel;
      if (keysPressed.current['KeyA'] || keysPressed.current['a'] || keysPressed.current['A']) state.player.vx -= accel;
      if (keysPressed.current['KeyD'] || keysPressed.current['d'] || keysPressed.current['D']) state.player.vx += accel;

      state.player.vx *= friction;
      state.player.vy *= friction;
      
      const speed1 = Math.sqrt(state.player.vx**2 + state.player.vy**2);
      if (speed1 > moveSpeed) {
        state.player.vx = (state.player.vx / speed1) * moveSpeed;
        state.player.vy = (state.player.vy / speed1) * moveSpeed;
      }
      
      state.player.x += state.player.vx;
      state.player.y += state.player.vy;
    } else {
      // Single Player / CPU mode: obey controlModePreference ('mouse', 'keyboard', or 'both')
      
      // Mouse Follow Component
      if (userControlMode === 'mouse' || userControlMode === 'both') {
        const followSpeed = state.activeEffects.speedBoost > 0 ? 0.15 : 0.08;
        const prevX = state.player.x;
        const prevY = state.player.y;
        state.player.x += (mousePos.current.x - state.player.x) * followSpeed;
        state.player.y += (mousePos.current.y - state.player.y) * followSpeed;
        state.player.vx = state.player.x - prevX;
        state.player.vy = state.player.y - prevY;
      }

      // Keyboard Component
      if (userControlMode === 'keyboard') {
        const allowArrowKeys = true;
        if (keysPressed.current['KeyW'] || keysPressed.current['w'] || keysPressed.current['W'] || (allowArrowKeys && (keysPressed.current['ArrowUp'] || keysPressed.current['Up']))) {
          state.player.vy -= accel;
        }
        if (keysPressed.current['KeyS'] || keysPressed.current['s'] || keysPressed.current['S'] || (allowArrowKeys && (keysPressed.current['ArrowDown'] || keysPressed.current['Down']))) {
          state.player.vy += accel;
        }
        if (keysPressed.current['KeyA'] || keysPressed.current['a'] || keysPressed.current['A'] || (allowArrowKeys && (keysPressed.current['ArrowLeft'] || keysPressed.current['Left']))) {
          state.player.vx -= accel;
        }
        if (keysPressed.current['KeyD'] || keysPressed.current['d'] || keysPressed.current['D'] || (allowArrowKeys && (keysPressed.current['ArrowRight'] || keysPressed.current['Right']))) {
          state.player.vx += accel;
        }
        state.player.vx *= friction;
        state.player.vy *= friction;
        const speed1 = Math.sqrt(state.player.vx**2 + state.player.vy**2);
        if (speed1 > moveSpeed) {
          state.player.vx = (state.player.vx / speed1) * moveSpeed;
          state.player.vy = (state.player.vy / speed1) * moveSpeed;
        }
        state.player.x += state.player.vx;
        state.player.y += state.player.vy;
      } else if (userControlMode === 'both') {
        // In 'both' mode, mouse follows AND keyboard presses directly nudge ship
        const kSpeed = state.activeEffects.speedBoost > 0 ? 7 : 5;
        if (keysPressed.current['KeyW'] || keysPressed.current['w'] || keysPressed.current['W'] || keysPressed.current['ArrowUp'] || keysPressed.current['Up']) {
          state.player.y -= kSpeed;
        }
        if (keysPressed.current['KeyS'] || keysPressed.current['s'] || keysPressed.current['S'] || keysPressed.current['ArrowDown'] || keysPressed.current['Down']) {
          state.player.y += kSpeed;
        }
        if (keysPressed.current['KeyA'] || keysPressed.current['a'] || keysPressed.current['A'] || keysPressed.current['ArrowLeft'] || keysPressed.current['Left']) {
          state.player.x -= kSpeed;
        }
        if (keysPressed.current['KeyD'] || keysPressed.current['d'] || keysPressed.current['D'] || keysPressed.current['ArrowRight'] || keysPressed.current['Right']) {
          state.player.x += kSpeed;
        }
      }

      // Clamp Player 1 within screen boundaries
      state.player.x = Math.max(state.player.radius, Math.min(canvas.width - state.player.radius, state.player.x));
      state.player.y = Math.max(state.player.radius, Math.min(canvas.height - state.player.radius, state.player.y));
    }

    // --- PLAYER 2 MOVEMENT ---
    if (state.player2) {
      if (propsRef.current.isLocalMultiplayer) {
        // Arrow Controls for Player 2 (Local Co-op ONLY)
        if (keysPressed.current['ArrowUp'] || keysPressed.current['Up']) state.player2.vy -= accel;
        if (keysPressed.current['ArrowDown'] || keysPressed.current['Down']) state.player2.vy += accel;
        if (keysPressed.current['ArrowLeft'] || keysPressed.current['Left']) state.player2.vx -= accel;
        if (keysPressed.current['ArrowRight'] || keysPressed.current['Right']) state.player2.vx += accel;

        state.player2.vx *= friction;
        state.player2.vy *= friction;

        const speed2 = Math.sqrt(state.player2.vx**2 + state.player2.vy**2);
        if (speed2 > moveSpeed) {
          state.player2.vx = (state.player2.vx / speed2) * moveSpeed;
          state.player2.vy = (state.player2.vy / speed2) * moveSpeed;
        }

        state.player2.x += state.player2.vx;
        state.player2.y += state.player2.vy;
      } else if (propsRef.current.isCPUMultiplayer) {
        // CPU Wingman AI Controls
        const p2 = state.player2;
        
        // Find closest threat (asteroid) or target (collectibles, powerups)
        let targetAsteroid = null;
        let minDistAsteroid = Infinity;
        for (const ast of state.asteroids) {
          const dx = ast.x - p2.x;
          const dy = ast.y - p2.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < minDistAsteroid) {
            minDistAsteroid = dist;
            targetAsteroid = ast;
          }
        }

        let targetCollectible = null;
        let minDistCollectible = Infinity;
        for (const coll of [...state.collectibles, ...state.powerUps]) {
          const dx = coll.x - p2.x;
          const dy = coll.y - p2.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < minDistCollectible) {
            minDistCollectible = dist;
            targetCollectible = coll;
          }
        }

        // Determine AI steering vectors
        let desiredVx = 0;
        let desiredVy = 0;

        // Threat Mitigation: Evade nearby asteroids (distance threshold < 220)
        if (targetAsteroid && minDistAsteroid < 220) {
          const dx = p2.x - targetAsteroid.x;
          const dy = p2.y - targetAsteroid.y;
          
          if (Math.abs(dx) < 65) {
            // Asteroid is coming right at us. Sidestep horizontally
            desiredVx = dx > 0 ? moveSpeed : -moveSpeed;
          } else {
            desiredVx = Math.sign(dx) * moveSpeed;
          }
          
          if (minDistAsteroid < 110) {
            // Extremum evasive vertical push
            desiredVy = Math.sign(dy) * moveSpeed;
          } else {
            // Smoothly target the lower center combat sector
            const targetY = canvas.height * 0.75;
            desiredVy = (targetY - p2.y) * 0.05;
          }
        } 
        // Resource Collection: Harvest active gold or powerups
        else if (targetCollectible && minDistCollectible < 400) {
          const dx = targetCollectible.x - p2.x;
          const dy = targetCollectible.y - p2.y;
          desiredVx = Math.sign(dx) * moveSpeed * 0.85;
          desiredVy = Math.sign(dy) * moveSpeed * 0.85;
        } 
        // Co-pilot Formation Layer: Hover comfortably in visual range of Player 1
        else {
          const targetX = state.player.x + (p2.x > state.player.x ? 150 : -150);
          const targetY = canvas.height * 0.75;
          desiredVx = (targetX - p2.x) * 0.04;
          desiredVy = (targetY - p2.y) * 0.04;
        }

        // Accelerate with smooth interpolation
        p2.vx += (desiredVx - p2.vx) * 0.12;
        p2.vy += (desiredVy - p2.vy) * 0.12;

        p2.vx *= friction;
        p2.vy *= friction;

        const cpuSpeed = Math.sqrt(p2.vx**2 + p2.vy**2);
        if (cpuSpeed > moveSpeed) {
          p2.vx = (p2.vx / cpuSpeed) * moveSpeed;
          p2.vy = (p2.vy / cpuSpeed) * moveSpeed;
        }

        p2.x += p2.vx;
        p2.y += p2.vy;
      }
    }

    // Shooting
    const now = Date.now();
    const fireRate = state.activeEffects.speedBoost > 0 ? 150 : 300;
    
    // Player 1 Shooting (Requires collecting 'W' Weapon power-up)
    if (state.activeEffects.weaponUpgrade > 0 && now - lastShotTime.current > fireRate) {
      lastShotTime.current = now;
      const angle = -Math.PI / 2;
      
      if (state.activeEffects.weaponUpgrade > 1000) {
        state.projectiles.push(createProjectile(state.player.x - 10, state.player.y, angle));
        state.projectiles.push(createProjectile(state.player.x + 10, state.player.y, angle));
        state.projectiles.push(createProjectile(state.player.x, state.player.y, angle - 0.15));
        state.projectiles.push(createProjectile(state.player.x, state.player.y, angle + 0.15));
      } else {
        state.projectiles.push(createProjectile(state.player.x - 10, state.player.y, angle));
        state.projectiles.push(createProjectile(state.player.x + 10, state.player.y, angle));
      }
    }

    // Player 2 Shooting (Requires collecting 'W' Weapon power-up)
    const hasPlayer2Active = propsRef.current.isLocalMultiplayer || propsRef.current.isCPUMultiplayer;
    if (hasPlayer2Active && state.player2 && state.activeEffects.weaponUpgrade > 0 && now - lastShotTime2.current > fireRate) {
        lastShotTime2.current = now;
        const angle = -Math.PI / 2;
        
        if (state.activeEffects.weaponUpgrade > 1000) {
          state.projectiles.push(createProjectile(state.player2.x - 10, state.player2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(state.player2.x + 10, state.player2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(state.player2.x, state.player2.y, angle - 0.15, '#fb7185'));
          state.projectiles.push(createProjectile(state.player2.x, state.player2.y, angle + 0.15, '#fb7185'));
        } else {
          state.projectiles.push(createProjectile(state.player2.x - 10, state.player2.y, angle, '#fb7185'));
          state.projectiles.push(createProjectile(state.player2.x + 10, state.player2.y, angle, '#fb7185'));
        }
    }

    // Difficulty increases gradually over time and with score up to mode-appropriate caps
    const initDiff = propsRef.current.initialDifficulty;
    let maxDiffCap = 0.85; // Easy mode target cap (reaches start of Medium mode)
    if (initDiff >= 5.0) {
      maxDiffCap = 8.0; // Super Hard mode cap
    } else if (initDiff >= 1.0) {
      maxDiffCap = 2.8; // Hard mode cap (gets significantly harder, but stays well below Super Hard's 6.0)
    } else if (initDiff >= 0.6) {
      maxDiffCap = 1.2; // Medium mode cap (reaches start of Hard mode)
    } else {
      maxDiffCap = 0.85; // Easy mode cap (reaches start of Medium mode)
    }

    const baseGrowthRate = 0.00008; 
    const scoreGrowthRate = (state.score / 25000) * 0.00004;
    const totalGrowth = baseGrowthRate + scoreGrowthRate;

    if (state.difficulty < maxDiffCap) {
      state.difficulty = Math.min(maxDiffCap, state.difficulty + totalGrowth);
    }

    // Update active effects
    Object.keys(state.activeEffects).forEach((key) => {
      const k = key as keyof typeof state.activeEffects;
      if (state.activeEffects[k] > 0) {
        state.activeEffects[k] -= 1;
      }
    });

    // Boundary check players
    [state.player, state.player2].forEach(p => {
      if (!p) return;
      p.x = Math.max(p.radius, Math.min(canvas.width - p.radius, p.x));
      p.y = Math.max(p.radius, Math.min(canvas.height - p.radius, p.y));
    });

    // Spawn asteroids
    let spawnChance = SPAWN_RATE * Math.pow(state.difficulty, 2);
    while (spawnChance > 0) {
      if (Math.random() < Math.min(1, spawnChance)) {
        const asteroid = createAsteroid(canvas.width, canvas.height, state.difficulty);
        state.asteroids.push(asteroid);
      }
      spawnChance -= 1;
    }

    // Spawn collectibles
    if (state.collectibles.length < 12 && Math.random() < 0.02 / Math.sqrt(state.difficulty)) {
      state.collectibles.push(createCollectible(canvas.width, canvas.height));
    }

    // Spawn power-ups (Easy Mode gets most power-ups, Medium slightly less, Hard less than Medium)
    let powerUpChance = 0.010; // Easy Mode (~0.3 difficulty)
    let maxPowerUps = 3;
    if (state.difficulty >= 5.0) {
      powerUpChance = 0.001; // Super Hard Mode (~6.0 difficulty)
      maxPowerUps = 2;
    } else if (state.difficulty >= 1.0) {
      powerUpChance = 0.0028; // Hard Mode (~1.2 difficulty)
      maxPowerUps = 2;
    } else if (state.difficulty >= 0.6) {
      powerUpChance = 0.0045; // Medium Mode (~0.85 difficulty)
      maxPowerUps = 2;
    }

    if (state.powerUps.length < maxPowerUps && Math.random() < powerUpChance) {
      state.powerUps.push(createPowerUp(canvas.width, canvas.height, state.difficulty));
    }

    // Update Projectiles
    for (let i = state.projectiles.length - 1; i >= 0; i--) {
      const p = state.projectiles[i];
      p.x += p.vx;
      p.y += p.vy;
      if (p.y < -50 || p.x < -100 || p.x > canvas.width + 100) {
        state.projectiles.splice(i, 1);
      }
    }

    // Update Power-ups
    for (let i = state.powerUps.length - 1; i >= 0; i--) {
      const pu = state.powerUps[i];
      pu.x += pu.vx;
      pu.y += pu.vy;

      if (pu.life !== undefined) {
        pu.life -= 1;
        if (pu.life <= 0) {
          state.powerUps.splice(i, 1);
          continue;
        }
      }

      if (pu.x < 0 || pu.x > canvas.width) pu.vx *= -1;
      if (pu.y < 0 || pu.y > canvas.height) pu.vy *= -1;

      let collected = false;
      for (const p of [state.player, state.player2]) {
        if (!p) continue;
        const dx = p.x - pu.x;
        const dy = p.y - pu.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        // Expanded pickup radius (+12px) for smooth collection without pixel precision frustration
        if (dist < pu.radius + p.radius + 12) {
          const type = pu.subType;
          let label = "POWER-UP GRABBED";
          if (type === 'shield') {
            state.activeEffects.shield = Math.min(1000, state.activeEffects.shield + 500);
            label = "DEFLECTOR SHIELD ACTIVE";
          } else if (type === 'speed') {
            state.activeEffects.speedBoost = Math.min(1000, state.activeEffects.speedBoost + 500);
            label = "OVERTHRUSTERS BOOTED";
          } else if (type === 'weapon') {
            state.activeEffects.weaponUpgrade = Math.min(2000, state.activeEffects.weaponUpgrade + 1000);
            label = state.activeEffects.weaponUpgrade > 1000 ? "PLASMA OVERDRIVE INITIATED" : "TWIN BLASTER PROTOCOL";
          } else if (type === 'magnet') {
            state.activeEffects.magnet = Math.min(600, state.activeEffects.magnet + 600);
            label = "MAGNET FIELD ACTIVATED!";
          }

          addFloatingText(pu.x, pu.y, label, pu.color, 1.2);
          createShockwaveRing(pu.x, pu.y, pu.color, 24);
          for(let j=0; j<10; j++) state.particles.push(createParticle(pu.x, pu.y, pu.color));
          collected = true;
          break;
        }
      }

      if (collected) {
        state.powerUps.splice(i, 1);
      }
    }

    // Decrement magnet timer
    if (state.activeEffects.magnet > 0) {
      state.activeEffects.magnet -= 1;
    }

    // Update Collectibles
    for (let i = state.collectibles.length - 1; i >= 0; i--) {
      const c = state.collectibles[i];
      
      // Magnetic pull when magnet power-up is active
      if (state.activeEffects.magnet > 0) {
        let closestPlayer: Entity | null = null;
        let minDist = Infinity;
        for (const p of [state.player, state.player2]) {
          if (!p) continue;
          const dx = p.x - c.x;
          const dy = p.y - c.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < minDist) {
            minDist = dist;
            closestPlayer = p;
          }
        }
        if (closestPlayer && minDist < 500) {
          const dx = closestPlayer.x - c.x;
          const dy = closestPlayer.y - c.y;
          // Magnetic suction force towards player
          c.vx += (dx / minDist) * 0.95;
          c.vy += (dy / minDist) * 0.95;
          const coinSpeed = Math.sqrt(c.vx * c.vx + c.vy * c.vy);
          if (coinSpeed > 10) {
            c.vx = (c.vx / coinSpeed) * 10;
            c.vy = (c.vy / coinSpeed) * 10;
          }
        }
      }

      c.x += c.vx;
      c.y += c.vy;

      if (c.x < 0 || c.x > canvas.width) c.vx *= -1;
      if (c.y < 0 || c.y > canvas.height) c.vy *= -1;

      let collected = false;
      for (const p of [state.player, state.player2]) {
        if (!p) continue;
        const dx = p.x - c.x;
        const dy = p.y - c.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        // Expanded pickup radius (+10px) for smooth collection without pixel precision frustration
        if (distance < c.radius + p.radius + 10) {
          state.score += 100;
          const healAmount = (propsRef.current.isLocalMultiplayer || propsRef.current.isCPUMultiplayer) ? 7 : 5;
          state.health = Math.min(100, state.health + healAmount);
          propsRef.current.onScoreUpdate(state.score);
          propsRef.current.onHealthUpdate(state.health);
          addFloatingText(c.x, c.y, `+100`, '#fbbf24', 0.95);
          createShockwaveRing(c.x, c.y, c.color, 10);
          for(let j=0; j<4; j++) state.particles.push(createParticle(c.x, c.y, c.color));
          collected = true;
          break;
        }
      }

      if (collected) {
        state.collectibles.splice(i, 1);
      }
    }

    // Update Asteroids
    for (let i = state.asteroids.length - 1; i >= 0; i--) {
      const asteroid = state.asteroids[i];
      asteroid.x += asteroid.vx;
      asteroid.y += asteroid.vy;
      if (asteroid.rotation !== undefined && asteroid.spinSpeed !== undefined) {
        asteroid.rotation += asteroid.spinSpeed;
      }

      let asteroidDestroyed = false;

      // Check collision with projectile
      for (let j = state.projectiles.length - 1; j >= 0; j--) {
        const p = state.projectiles[j];
        const dx = asteroid.x - p.x;
        const dy = asteroid.y - p.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < asteroid.radius + p.radius) {
          state.score += 20;
          propsRef.current.onScoreUpdate(state.score);
          addFloatingText(asteroid.x, asteroid.y, `+20`, asteroid.color, 0.8);
          createShockwaveRing(asteroid.x, asteroid.y, asteroid.color, 12);
          for(let k=0; k<6; k++) state.particles.push(createParticle(p.x, p.y, asteroid.color));
          
          state.projectiles.splice(j, 1);
          asteroidDestroyed = true;
          break;
        }
      }

      if (asteroidDestroyed) {
        state.asteroids.splice(i, 1);
        continue;
      }

      // Check collision with player
      for (const p of [state.player, state.player2]) {
        if (!p) continue;
        const dx = asteroid.x - p.x;
        const dy = asteroid.y - p.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance < asteroid.radius + p.radius) {
          if (state.activeEffects.speedBoost > 0) {
            const nx = dx / distance;
            const ny = dy / distance;
            const dot = asteroid.vx * nx + asteroid.vy * ny;
            asteroid.vx = (asteroid.vx - 2 * dot * nx) * 1.2;
            asteroid.vy = (asteroid.vy - 2 * dot * ny) * 1.2;
            const overlap = (asteroid.radius + p.radius) - distance;
            asteroid.x += nx * overlap;
            asteroid.y += ny * overlap;
            shakeRef.current = 5;
            for(let k=0; k<8; k++) state.particles.push(createParticle(asteroid.x, asteroid.y, '#22c55e'));
          } else if (state.activeEffects.shield > 0) {
            state.activeEffects.shield = Math.max(0, state.activeEffects.shield - 100);
            shakeRef.current = 6;
            addFloatingText(p.x, p.y, "SHIELD ABSORBED", "#a855f7", 0.95);
            createShockwaveRing(p.x, p.y, '#a855f7', 15);
            for(let k=0; k<10; k++) state.particles.push(createParticle(p.x, p.y, '#a855f7'));
            asteroidDestroyed = true;
            break;
          } else {
            const damage = (propsRef.current.isLocalMultiplayer || propsRef.current.isCPUMultiplayer) ? 18 : 25;
            state.health -= damage;
            propsRef.current.onHealthUpdate(state.health);
            shakeRef.current = 22;
            addFloatingText(p.x, p.y, `-${damage}% HULL DAMAGE`, '#ff0000', 1.25);
            createShockwaveRing(p.x, p.y, '#ff0000', 20);
            for(let k=0; k<12; k++) state.particles.push(createParticle(p.x, p.y, '#ff0000'));
            asteroidDestroyed = true;

            if (state.health <= 0) {
              state.isGameOver = true;
              propsRef.current.onGameOver(state.score);
            }
            break;
          }
        }
      }

      if (asteroidDestroyed) {
        state.asteroids.splice(i, 1);
        continue;
      }

      // Remove off-screen asteroids
      if (asteroid.x < -100 || asteroid.x > canvas.width + 100 || asteroid.y < -100 || asteroid.y > canvas.height + 100) {
        state.asteroids.splice(i, 1);
        state.score += 10;
        propsRef.current.onScoreUpdate(state.score);
      }
    }

    // Update Particles
    for (let i = state.particles.length - 1; i >= 0; i--) {
      const p = state.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      if (p.life !== undefined) {
        p.life--;
        if (p.life <= 0) {
          state.particles.splice(i, 1);
        }
      }
    }
    if (state.particles.length > 80) {
      state.particles.splice(0, state.particles.length - 80);
    }

    if (state.projectiles.length > 30) {
      state.projectiles.splice(0, state.projectiles.length - 30);
    }

    // Update Floating Texts
    for (let i = state.floatingTexts.length - 1; i >= 0; i--) {
      const ft = state.floatingTexts[i];
      ft.y -= 1.2;
      ft.life -= 1;
      ft.alpha = Math.max(0, ft.life / 60);
      if (ft.life <= 0) {
        state.floatingTexts.splice(i, 1);
      }
    }
    if (state.floatingTexts.length > 12) {
      state.floatingTexts.splice(0, state.floatingTexts.length - 12);
    }

    // Handle screen shake
    if (shakeRef.current > 0) shakeRef.current *= 0.9;
  };

  const draw = (ctx: CanvasRenderingContext2D) => {
    const state = stateRef.current;
    
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);

    ctx.save();
    if (shakeRef.current > 1) {
      ctx.translate((Math.random() - 0.5) * shakeRef.current, (Math.random() - 0.5) * shakeRef.current);
    }

    // Draw Static Stars
    ctx.fillStyle = 'white';
    starsRef.current.forEach(star => {
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.s, 0, Math.PI * 2);
      ctx.fill();
    });

    // Draw Background Glow (Atmosphere)
    const gradient = ctx.createRadialGradient(
      state.player.x, state.player.y, 0,
      state.player.x, state.player.y, 400
    );
    gradient.addColorStop(0, 'rgba(0, 255, 255, 0.08)');
    gradient.addColorStop(1, 'transparent');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);

    // Draw Collectibles
    state.collectibles.forEach(c => {
      ctx.beginPath();
      ctx.arc(c.x, c.y, c.radius, 0, Math.PI * 2);
      ctx.fillStyle = c.color;
      ctx.shadowBlur = 15;
      ctx.shadowColor = c.color;
      ctx.fill();
      ctx.shadowBlur = 0;
      
      // Halo
      ctx.beginPath();
      ctx.arc(c.x, c.y, c.radius + 4 + Math.sin(Date.now() / 200) * 2, 0, Math.PI * 2);
      ctx.strokeStyle = c.color;
      ctx.lineWidth = 1;
      ctx.globalAlpha = 0.3;
      ctx.stroke();
      ctx.globalAlpha = 1.0;
    });

    // Draw Power-ups
    state.powerUps.forEach(pu => {
      // Blinking effect when expiring
      if (pu.life !== undefined && pu.life < 300) {
        if (Math.floor(pu.life / 10) % 2 === 0) return;
      }

      ctx.beginPath();
      ctx.arc(pu.x, pu.y, pu.radius, 0, Math.PI * 2);
      ctx.fillStyle = pu.color;
      ctx.shadowBlur = 15;
      ctx.shadowColor = pu.color;
      ctx.fill();
      ctx.shadowBlur = 0;

      // Icon placeholder
      ctx.fillStyle = 'white';
      ctx.font = 'bold 10px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const label = pu.subType === 'shield' ? 'S' : (pu.subType === 'speed' ? 'V' : (pu.subType === 'magnet' ? 'M' : 'W'));
      ctx.fillText(label, pu.x, pu.y);

      // Rotating ring
      ctx.beginPath();
      ctx.arc(pu.x, pu.y, pu.radius + 3, 0, Math.PI * 2);
      ctx.strokeStyle = pu.color;
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 5]);
      ctx.lineDashOffset = -Date.now() / 20;
      ctx.stroke();
      ctx.setLineDash([]);
    });

    // Draw Projectiles
    state.projectiles.forEach(p => {
      ctx.save();
      const angle = Math.atan2(p.vy, p.vx);
      const length = 18;
      
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x - Math.cos(angle) * length, p.y - Math.sin(angle) * length);
      
      ctx.strokeStyle = p.color;
      ctx.lineWidth = 3.5;
      ctx.lineCap = 'round';
      ctx.stroke();
      
      // Draw pristine inner core
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.2;
      ctx.stroke();
      ctx.restore();
    });

    // Draw Particles
    state.particles.forEach(p => {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      ctx.fillStyle = p.color;
      const alpha = p.maxLife ? Math.max(0, p.life / p.maxLife) : Math.max(0, (p.life || 1) / 25);
      ctx.globalAlpha = alpha;
      ctx.fill();
    });
    ctx.globalAlpha = 1;

    // Draw Asteroids
    state.asteroids.forEach(a => {
      ctx.save();
      ctx.beginPath();
      const steps = a.vertices?.length || 10;
      for (let i = 0; i < steps; i++) {
        const angle = (i / steps) * Math.PI * 2;
        const r = a.radius * (a.vertices ? a.vertices[i] : 1.0);
        const vx = a.x + Math.cos(angle + (a.rotation || 0)) * r;
        const vy = a.y + Math.sin(angle + (a.rotation || 0)) * r;
        if (i === 0) ctx.moveTo(vx, vy);
        else ctx.lineTo(vx, vy);
      }
      ctx.closePath();
      ctx.fillStyle = a.color;
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Draw rock textures / craters
      if (a.craters) {
        a.craters.forEach(crater => {
          ctx.beginPath();
          // rotate craters alongside the asteroid body
          const dist = Math.sqrt(crater.rx * crater.rx + crater.ry * crater.ry) * a.radius;
          const initialAngle = Math.atan2(crater.ry, crater.rx);
          const cx = a.x + Math.cos(initialAngle + (a.rotation || 0)) * dist;
          const cy = a.y + Math.sin(initialAngle + (a.rotation || 0)) * dist;
          ctx.arc(cx, cy, crater.r * a.radius, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(0, 0, 0, 0.25)';
          ctx.fill();
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
          ctx.lineWidth = 0.8;
          ctx.stroke();
        });
      }
      ctx.restore();
    });

    // Draw Players
    [state.player, state.player2].forEach(p => {
      if (!p) return;
      
      // Calculate tilt based on horizontal speed
      let tilt = 0;
      if (propsRef.current.isLocalMultiplayer || propsRef.current.isCPUMultiplayer || p.id === 'player2' || controlMode.current === 'keyboard') {
        tilt = p.vx * 0.04;
      } else {
        tilt = (mousePos.current.x - p.x) * 0.01;
      }
      tilt = Math.max(-0.45, Math.min(0.45, tilt));

      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(tilt);

      // Modular space fighter geometry
      ctx.beginPath();
      ctx.moveTo(0, -p.radius * 1.5);
      ctx.lineTo(-p.radius, p.radius);
      ctx.lineTo(0, p.radius * 0.5); // Wing Notch
      ctx.lineTo(p.radius, p.radius);
      ctx.closePath();
      
      ctx.fillStyle = p.color;
      ctx.shadowBlur = 20;
      ctx.shadowColor = p.color;
      ctx.fill();
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.8;
      ctx.stroke();
      ctx.shadowBlur = 0;

      // Pilot Glass Canopy
      ctx.beginPath();
      ctx.moveTo(0, -p.radius * 0.82);
      ctx.lineTo(-p.radius * 0.35, p.radius * 0.1);
      ctx.lineTo(p.radius * 0.35, p.radius * 0.1);
      ctx.closePath();
      ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
      ctx.fill();

      // Shield Effect
      if (state.activeEffects.shield > 0) {
        ctx.beginPath();
        ctx.arc(0, 0, p.radius * 2, 0, Math.PI * 2);
        ctx.strokeStyle = '#a855f7';
        ctx.lineWidth = 3;
        ctx.globalAlpha = Math.min(1, state.activeEffects.shield / 100);
        ctx.setLineDash([10, 5]);
        ctx.lineDashOffset = Date.now() / 10;
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;

        ctx.beginPath();
        ctx.arc(0, 0, p.radius * 2 + 5, 0, Math.PI * 2);
        ctx.strokeStyle = '#a855f7';
        ctx.lineWidth = 1;
        ctx.globalAlpha = 0.2 * Math.min(1, state.activeEffects.shield / 100);
        ctx.stroke();
        ctx.globalAlpha = 1;
      }

      // Force Field Effect
      if (state.activeEffects.speedBoost > 0) {
        ctx.beginPath();
        ctx.arc(0, 0, p.radius * 2.2, 0, Math.PI * 2);
        ctx.strokeStyle = '#22c55e';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.6 * Math.min(1, state.activeEffects.speedBoost / 100);
        const pulse = Math.sin(Date.now() / 100) * 0.2 + 0.8;
        ctx.lineWidth = 2 * pulse;
        ctx.stroke();
        
        ctx.beginPath();
        ctx.arc(0, 0, p.radius * 2.2, 0, Math.PI * 2);
        ctx.fillStyle = '#22c55e';
        ctx.globalAlpha = 0.1 * Math.min(1, state.activeEffects.speedBoost / 100);
        ctx.fill();
        ctx.globalAlpha = 1;
      }

      // Magnet Aura Effect
      if (state.activeEffects.magnet > 0) {
        ctx.beginPath();
        ctx.arc(0, 0, p.radius * 2.5, 0, Math.PI * 2);
        ctx.strokeStyle = '#c084fc';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.8 * Math.min(1, state.activeEffects.magnet / 60);
        ctx.setLineDash([4, 4]);
        ctx.lineDashOffset = -Date.now() / 25;
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;
      }

      ctx.restore();

      // Thruster effect (rendered outside translated context so standard sparks emission triggers correctly)
      if (!isPaused && !state.isGameOver) {
        const thrusterCount = state.activeEffects.speedBoost > 0 ? 2 : 1;
        const thrusterColor = state.activeEffects.speedBoost > 0 ? '#22c55e' : (p.id === 'player1' ? '#ff00ff' : '#fb7185');
        // Thrusters stream from ship tail
        const streamX = p.x - Math.sin(tilt) * (p.radius * 0.8);
        const streamY = p.y + Math.cos(tilt) * p.radius;
        for(let i=0; i<thrusterCount; i++) {
          state.particles.push(createParticle(streamX, streamY, thrusterColor, true));
        }
      }
    });

    // Draw Floating Texts
    state.floatingTexts.forEach(ft => {
      ctx.save();
      ctx.globalAlpha = ft.alpha;
      ctx.fillStyle = ft.color;
      ctx.font = `900 ${Math.round(14 * ft.scale)}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.shadowBlur = 10;
      ctx.shadowColor = ft.color;
      ctx.fillText(ft.text, ft.x, ft.y);
      ctx.restore();
    });

    // Draw HUD for Power-ups
    const effects = [
      { name: 'SHIELD', id: 'S', color: '#a855f7', value: state.activeEffects.shield, max: 1000 },
      { name: 'SPEED', id: 'V', color: '#22c55e', value: state.activeEffects.speedBoost, max: 1000 },
      { name: 'WEAPON', id: 'W', color: '#ef4444', value: state.activeEffects.weaponUpgrade, max: 2000 },
      { name: 'MAGNET', id: 'M', color: '#c084fc', value: state.activeEffects.magnet, max: 600 },
    ].filter(e => e.value > 0);

    effects.forEach((eff, i) => {
      const x = 50 + i * 140;
      const y = ctx.canvas.height - 40;
      
      ctx.save();
      ctx.shadowBlur = 10;
      ctx.shadowColor = eff.color;
      
      ctx.fillStyle = 'rgba(9, 12, 28, 0.75)';
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
      ctx.lineWidth = 1;
      
      const width = 125;
      const height = 30;
      const rx = x - 20;
      const ry = y - 15;
      
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(rx, ry, width, height, 8);
      } else {
        ctx.rect(rx, ry, width, height);
      }
      ctx.fill();
      ctx.stroke();
      
      // Arc meter
      ctx.beginPath();
      ctx.arc(x, y, 10, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
      ctx.lineWidth = 2.5;
      ctx.stroke();
      
      ctx.beginPath();
      ctx.arc(x, y, 10, -Math.PI / 2, -Math.PI / 2 + (Math.PI * 2 * (eff.value / eff.max)));
      ctx.strokeStyle = eff.color;
      ctx.lineWidth = 2.5;
      ctx.stroke();
      
      // Arc center character
      ctx.fillStyle = '#ffffff';
      ctx.font = '900 9px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(eff.id, x, y);
      
      // Label Text Next To It
      ctx.fillStyle = eff.color;
      ctx.font = 'bold 9px monospace';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(eff.name, x + 18, y - 5);
      
      // Remaining Countdown seconds
      ctx.fillStyle = '#ffffff';
      ctx.font = '8px monospace';
      ctx.globalAlpha = 0.6;
      ctx.fillText(`${Math.round(eff.value / 60)}s left`, x + 18, y + 5);
      
      ctx.restore();
    });

    // Draw Missions Controls Help Overlay
    if (Date.now() - mountTime.current < 6000) {
      const elapsed = Date.now() - mountTime.current;
      const alpha = elapsed < 4500 ? 0.9 : Math.max(0, 0.9 - (elapsed - 4500) / 1500);
      
      if (alpha > 0) {
        ctx.save();
        ctx.fillStyle = `rgba(15, 23, 42, ${alpha * 0.9})`;
        ctx.strokeStyle = `rgba(99, 102, 241, ${alpha * 0.55})`;
        ctx.lineWidth = 1.5;
        
        const w = 480;
        const h = 135;
        const x = ctx.canvas.width / 2 - w / 2;
        const y = ctx.canvas.height / 2 - h / 2 - 80;
        
        ctx.beginPath();
        if (ctx.roundRect) {
          ctx.roundRect(x, y, w, h, 20);
        } else {
          ctx.rect(x, y, w, h);
        }
        ctx.fill();
        ctx.stroke();
        
        ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
        ctx.font = 'bold 14px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText("MISSION CONTROL PROTOCOLS", ctx.canvas.width / 2, y + 25);
        
        ctx.lineWidth = 1;
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha * 0.15})`;
        ctx.beginPath();
        ctx.moveTo(x + 30, y + 36);
        ctx.lineTo(x + w - 30, y + 36);
        ctx.stroke();
        
        if (propsRef.current.isLocalMultiplayer) {
          // Player 1 (Cyan)
          ctx.fillStyle = `rgba(0, 255, 255, ${alpha})`;
          ctx.font = '900 12px monospace';
          ctx.textAlign = 'left';
          ctx.fillText("PLAYER 1 (CYAN SHIP)", x + 35, y + 58);
          
          ctx.fillStyle = `rgba(226, 232, 240, ${alpha * 0.9})`;
          ctx.font = '600 11px monospace';
          ctx.fillText("Move: W, A, S, D Keys", x + 35, y + 78);
          ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 35, y + 96);
          
          // Player 2 (Pink)
          ctx.fillStyle = `rgba(251, 113, 133, ${alpha})`;
          ctx.font = '900 12px monospace';
          ctx.textAlign = 'left';
          ctx.fillText("PLAYER 2 (PINK SHIP)", x + 255, y + 58);
          
          ctx.fillStyle = `rgba(226, 232, 240, ${alpha * 0.9})`;
          ctx.font = '600 11px monospace';
          ctx.fillText("Move: ARROW KEYS", x + 255, y + 78);
          ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 255, y + 96);
        } else if (propsRef.current.isCPUMultiplayer) {
          // Player 1 (Cyan)
          ctx.fillStyle = `rgba(0, 255, 255, ${alpha})`;
          ctx.font = '900 12px monospace';
          ctx.textAlign = 'left';
          ctx.fillText("PLAYER 1 (CYAN SHIP)", x + 35, y + 58);
          
          ctx.fillStyle = `rgba(226, 232, 240, ${alpha * 0.9})`;
          ctx.font = '600 11px monospace';
          ctx.fillText("Controls: MOUSE / WASD", x + 35, y + 78);
          ctx.fillText("Weapons: GRAB 'W' ORB TO SHOOT", x + 35, y + 96);
          
          // CPU Co-pilot (Pink)
          ctx.fillStyle = `rgba(251, 113, 133, ${alpha})`;
          ctx.font = '900 12px monospace';
          ctx.textAlign = 'left';
          ctx.fillText("NEURAL CO-PILOT (AI)", x + 255, y + 58);
          
          ctx.fillStyle = `rgba(226, 232, 240, ${alpha * 0.9})`;
          ctx.font = '600 11px monospace';
          ctx.fillText("Strategy: DODGE & ASSIST", x + 255, y + 78);
          ctx.fillText("System: AUTONOMOUS", x + 255, y + 96);
        } else {
          // Single player help
          ctx.fillStyle = `rgba(0, 255, 255, ${alpha})`;
          ctx.font = '900 12px monospace';
          ctx.textAlign = 'center';
          ctx.fillText("SINGLE PLAYER STATUS: READY", ctx.canvas.width / 2, y + 58);
          
          ctx.fillStyle = `rgba(226, 232, 240, ${alpha * 0.9})`;
          ctx.font = '600 11px monospace';
          ctx.fillText("Controls: MOVE MOUSE or keys W, A, S, D", ctx.canvas.width / 2, y + 78);
          ctx.fillText("Seamless auto-switching on key down", ctx.canvas.width / 2, y + 96);
        }
        
        ctx.fillStyle = `rgba(99, 102, 241, ${alpha * 0.95})`;
        ctx.font = 'italic bold 9px monospace';
        ctx.textAlign = 'center';
        ctx.fillText("CLICK THE SCREEN IF CONTROLS DO NOT PERSIST", ctx.canvas.width / 2, y + h - 14);
        
        ctx.restore();
      }
    }

    ctx.restore();
  };

  const loop = () => {
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) {
        update();
        draw(ctx);
      }
    }
    animationId.current = requestAnimationFrame(loop);
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    // Reset keys to clear stuck button states when pausing or resuming
    keysPressed.current = {};

    const handleResize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };

    window.addEventListener('resize', handleResize);
    handleResize();

    animationId.current = requestAnimationFrame(loop);

    const handleMouseMove = (e: MouseEvent) => {
      mousePos.current = { x: e.clientX, y: e.clientY };
      controlMode.current = 'mouse';
    };
    const handleTouchMove = (e: TouchEvent) => {
      if (e.touches[0]) {
        mousePos.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
        controlMode.current = 'mouse';
      }
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('touchmove', handleTouchMove);

    const handleKeyDown = (e: KeyboardEvent) => {
      // Prevent browser default actions (scrolling) for game-critical keys
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', ' ', 'Up', 'Down', 'Left', 'Right'].includes(e.key)) {
        e.preventDefault();
      }
      keysPressed.current[e.key] = true;
      keysPressed.current[e.code] = true;
    };
    const handleKeyUp = (e: KeyboardEvent) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', ' ', 'Up', 'Down', 'Left', 'Right'].includes(e.key)) {
        e.preventDefault();
      }
      keysPressed.current[e.key] = false;
      keysPressed.current[e.code] = false;
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    // Track Canvas clicks to force focus inside the iframe environment
    const handleCanvasClick = () => {
      if (canvas) canvas.focus();
    };
    canvas.addEventListener('click', handleCanvasClick);

    // Initial focus call
    setTimeout(() => {
      if (canvasRef.current) canvasRef.current.focus();
    }, 100);

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      if (canvas) canvas.removeEventListener('click', handleCanvasClick);
      cancelAnimationFrame(animationId.current);
    };
  }, [isPaused]); // Restart loop on pause/resume if needed, though update() handles it

  return (
    <canvas 
      ref={canvasRef} 
      tabIndex={0}
      className="block w-full h-full bg-zinc-950 cursor-none outline-none"
    />
  );
};
