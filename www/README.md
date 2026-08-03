# Neon Nebula

A 2D space arcade shooter. Plain HTML, CSS and JavaScript — no TypeScript, no framework,
no build step, no dependencies to install.

## Run it

Open `index.html` in a browser, or serve the folder:

```sh
cd www
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Files

| File | Contents |
| --- | --- |
| `index.html` | Markup for the menus, HUD, overlays and the game canvas (icons are inline SVG) |
| `styles.css` | The neon/frosted-glass design system |
| `game.js` | Canvas game engine — physics, spawning, collisions, AI, rendering (`window.NeonNebula`) |
| `auth.js` | Login/leaderboard API client (`window.NeonAuth`) — Google Sign-In, accounts, score submission |
| `ui.js` | Screen flow, menus, HUD updates, settings persistence, new-high-score/login flow |
| `api/` | PHP endpoints: sessions, register/login/Google, score submit, top-10 leaderboard, password reset (see `docs/leaderboard-setup.md`) |

The only external asset is the Orbitron + Inter webfont from Google Fonts; without a network
connection the game still runs and falls back to system fonts.

Sound effects (from [Pixabay](https://pixabay.com/)):

- `sounds/new-high-score.mp3` — "You Win Sequence 3" by
  [floraphonic](https://pixabay.com/users/floraphonic-38928062/) (#183950)
- `sounds/crash-death.mp3` — "Spacecraft crashing" by
  [freesound_community](https://pixabay.com/users/freesound_community-46691455/) (#88048);
  the final 3 seconds play when the ship is destroyed
- `sounds/asteroid-hit.mp3` — "Cinematic designed sci-fi whoosh spectral glide" by
  [Rescopic Sound](https://pixabay.com/users/rescopicsound-45188866/) (#228310);
  the final 2 seconds play on non-fatal asteroid hits

## Modes

- **Easy / Medium / Hard / Super Hard** — solo, initial difficulty `0.3 / 0.77 / 1.2 / 6.0`
- **Two Player Mode** — local co-op on one keyboard, shared score and hull
- **CPU Co-Pilot Mode** — an AI wingman that dodges hazards and harvests pickups

## Controls

| | Player 1 | Player 2 (local co-op) |
| --- | --- | --- |
| Move | Mouse and/or `W` `A` `S` `D` / arrows | Arrow keys |
| Fire | Automatic once the red `W` orb is collected | Automatic once the red `W` orb is collected |
| Pause | Pause button in the HUD, or `Esc` | |

In solo and CPU modes, Player 1's input scheme (mouse, keyboard, or both) is configurable in
Settings and is remembered in `localStorage`. In local co-op, Player 1 is always WASD so the
arrow keys stay free for Player 2.

## Power-ups

| Orb | Effect |
| --- | --- |
| `S` Shield | Absorbs asteroid impacts instead of taking hull damage |
| `V` Speed | Faster movement and fire rate; ramming knocks asteroids aside |
| `W` Weapon | Enables the blasters; a second pickup upgrades to a 4-shot spread |
| `M` Magnet | Pulls nearby treats toward your ship (Medium difficulty and above only) |

Sundaes and donuts pay 100 points and repair the hull; destroyed asteroids pay 20; asteroids
that drift off screen pay 10. Difficulty climbs with survival time and score up to a per-mode ceiling.
