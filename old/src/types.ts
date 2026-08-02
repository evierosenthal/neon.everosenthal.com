/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

export interface Point {
  x: number;
  y: number;
}

export interface FloatingText extends Point {
  id: string;
  text: string;
  color: string;
  alpha: number;
  life: number;
  scale: number;
}

export interface Entity extends Point {
  id: string;
  radius: number;
  vx: number;
  vy: number;
  color: string;
  type: 'player' | 'asteroid' | 'particle' | 'collectible' | 'enemy' | 'projectile' | 'powerup';
  life?: number;
  maxLife?: number;
  subType?: string;
  vertices?: number[];
  craters?: { rx: number; ry: number; r: number }[];
  rotation?: number;
  spinSpeed?: number;
}

export type ControlModePreference = 'mouse' | 'keyboard' | 'both';

export interface GameState {
  player: Entity;
  asteroids: Entity[];
  particles: Entity[];
  collectibles: Entity[];
  projectiles: Entity[];
  powerUps: Entity[];
  enemies: Entity[];
  player2?: Entity;
  floatingTexts: FloatingText[];
  score: number;
  health: number;
  isGameOver: boolean;
  isPaused: boolean;
  highScore: number;
  difficulty: number;
  activeEffects: {
    shield: number; // intensity/timer
    speedBoost: number; // intensity/timer
    weaponUpgrade: number; // level/timer
    magnet: number; // magnet timer
  };
}
