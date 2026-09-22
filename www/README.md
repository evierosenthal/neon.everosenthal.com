# Nitro Nebula

A 2D space arcade shooter. Plain HTML, CSS and JavaScript — no TypeScript, no framework,
no build step, no dependencies to install.

## Run it

Serve the folder with PHP (`index.php` computes cachebusting asset URLs):

```sh
cd www
php -S localhost:8000
# then visit http://localhost:8000
```

## Files

| File | Contents |
| --- | --- |
| `index.php` | Markup for the menus, HUD, overlays and the game canvas (icons are inline SVG) |
| `styles.css` | The neon/frosted-glass design system |
| `game.js` | Canvas game engine — physics, spawning, collisions, AI, rendering (`window.NeonNebula`) |
| `auth.js` | Login/leaderboard API client (`window.NeonAuth`) — Google Sign-In, accounts, score submission |
| `net.js` | Online two-player client (`window.NeonNet`) — lobby calls and the WebRTC data channel between host and guest |
| `ui.js` | Screen flow, menus, HUD updates, settings persistence, new-high-score/login flow |
| `api/` | PHP endpoints: sessions, register/login/Google/Apple, account deletion, score submit, top-10 leaderboard, password reset, online lobbies (`games.php`) — see the API table below and `docs/leaderboard-setup.md` |
| `privacy.php`, `support.php` | Standalone privacy policy and support pages (linked from the login and settings modals; also the App Store listing's URLs) |

The native iOS app lives in `../ios/` (its own README) and talks to the same `api/`
endpoints over HTTPS; see "iOS app" below for what differs.

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
- `sounds/background-music.m4a` — original synthwave loop composed for this game
  (8 bars, 112 BPM, Am-F-C-G); loops during gameplay, pauses with the game
- `sounds/home-music.m4a` — original chiptune-pop loop composed for the home screen
  (16 bars, 104 BPM, E-B-C#m-A); loops while the menu is up and stops when a mission starts

Both music loops are decoded once and looped by the Web Audio API (sample-accurate, never
runs out); if that is unavailable they fall back to a looping `<audio>` element with an
"ended" restart. Sound effects stay on plain `<audio>` elements.

## Modes

- **Easy / Medium / Hard / Super Hard** — solo, initial difficulty `0.3 / 0.62 / 1.3 / 6.0`
- **Two Player Mode** — local co-op on one keyboard, shared score and hull
- **Online Two Player** — two accounts on two screens; see "Playing online" below
- **CPU Co-Pilot Mode** — an AI wingman that dodges hazards and harvests pickups

## Playing online

Both players need an account (the server has to know who is who).

1. **Host:** Two Player → **CREATE GAME · PLAY ONLINE**, pick Easy / Medium / Hard, keep or
   edit the game code, **OPEN LOBBY**. The lobby shows the code and who has joined.
2. **Guest:** on the home screen open **FRIENDS & INVITES** and either accept an invite
   (the host sends one from the Friends page by typing your call sign and the code) or type
   the code under *Join with a code*. The guest then waits in the lobby.
3. The host presses **START** once Pilot 2 is seated. The two browsers link peer-to-peer
   over a WebRTC data channel (the server only relays the connection offer and answer),
   then the round begins on both screens.

The host's browser runs the simulation and streams about twenty snapshots a second; the
guest's browser draws them and sends back which way Pilot 2 is steering (keys or mouse,
per its own Settings). Both pilots fly their own equipped skin, trail and fire. Scores count
under the two-player leaderboard for the chosen level. Pausing is disabled online; if the
link drops, the round ends with the score so far.

Server side: `api/games.php` with the `games`, `game_invites` and `game_signals` tables
(migration `05_online_games.sql`, applied automatically on the next login like the others).
Lobbies expire when the host stops polling for 45 seconds. Two players behind very strict
networks (symmetric NAT) may fail to connect, since there is no TURN relay.

**Platform gating.** Every `create` and `join` carries `platform: 'web' | 'ios'` (`net.js`
always sends `web`). The iOS app links its two devices over Game Center instead of WebRTC, so
a browser and an app can never actually connect; the server stores `host_platform` /
`guest_platform` (migration `07_games_platform.sql`) and a `join` from the other platform is
refused with `platform_mismatch` (409) — the Friends page shows the server's message.

## iOS app

`../ios/` is a native Swift client of the same API (persistent cookie jar, `X-CSRF-Token`
header, no `Origin` header — `require_post_with_csrf()` accepts that). What it adds server-side:

- **Sign in with Apple** — `api/apple.php` verifies the identity token against Apple's JWKS
  (`api/_jwt.php`, cached in `cache/`), links or creates the account by verified email like
  Google does, and stores `apple_sub` (migration `06_apple_sign_in.sql`). Google Sign-In from
  the app uses a separate iOS OAuth client, so `google.php` accepts any audience in
  `GOOGLE_ALLOWED_CLIENT_IDS`.
- **Account deletion** — `api/delete-account.php` (App Store guideline 5.1.1(v)); password
  accounts confirm with the password, Apple-linked accounts get their grant revoked when the
  Apple key is configured (see `docs/leaderboard-setup.md`).
- `session.php` reports `apiVersion` so an old app build can tell when the API moved on, and
  `user` payloads carry `email`, `provider` (`password` | `google` | `apple`) and `hasPassword`.

## API

All endpoints are JSON. `GET session.php` first: it returns the CSRF token every POST must send
in `X-CSRF-Token`. Errors are `{error, message}` with a 4xx/5xx status; `message` is safe to
show to the player.

| Endpoint | Method | Body / query | Notes |
| --- | --- | --- | --- |
| `session.php` | GET | | `{loggedIn, user, csrf, googleClientId, apiVersion, offline?}` |
| `register.php` | POST | `{username, email, password}` | Reserved/offensive call signs → `bad_username` |
| `login.php` | POST | `{usernameOrEmail, password}` | Social-only account → `use_google` / `use_apple` |
| `google.php` | POST | `{credential}` | Google ID token (web or iOS client) |
| `apple.php` | POST | `{identityToken, authorizationCode?, nonce?, fullName?}` | Sign in with Apple |
| `logout.php` | POST | `{}` | |
| `delete-account.php` | POST | `{password?, appleAuthorizationCode?}` | Deletes the logged-in account; returns a logged-out session |
| `request-reset.php` | POST | `{email}` | Emails a reset link |
| `reset-password.php` | POST | `{token, newPassword}` | |
| `submit-score.php` | POST | `{score, mode}` | |
| `leaderboard.php` | GET | | Top 10 per mode |
| `games.php` | GET/POST | `action=...` (see file header) | Lobbies, invites, signaling; `platform` on create/join |
| `set-role.php`, `run-migrations.php` | POST | | Lead developer only |

## Controls

| | Player 1 | Player 2 (local co-op) |
| --- | --- | --- |
| Move | Mouse and/or `W` `A` `S` `D` / arrows | Arrow keys |
| Fire | Automatic once the red `W` orb is collected | Automatic once the red `W` orb is collected |
| Pause | Pause button in the HUD, or `Esc` | |

In solo and CPU modes, Player 1's input scheme (mouse, keyboard, or both) is configurable in
Settings and is remembered in `localStorage`. In local co-op, Player 1 is always WASD so the
arrow keys stay free for Player 2.

Settings also has separate Music and Sound Effects sliders (down to off), remembered in
`localStorage`. Music covers the home and gameplay loops; Sound Effects covers hits, the
crash and the high-score fanfare.

## Home screen

- Each difficulty button shows that tier's record; the tier launched most recently wears a
  `LAST` tag and `Enter` replays it (ignored while a modal or text field has focus).
- The pilot tile shows a rank (Cadet → Ensign → Lieutenant → Captain → Commander → Admiral →
  Legend) earned by the all-time best score, with a progress bar to the next rung.
- The loadout strip shows the equipped skin, trail and fire; each chip opens the Tailor on that
  rack. The Tailor button wears a `NEW` badge whenever the wallet can afford an unowned item.
- Two Player has its own home screen with a loadout row per pilot. Pilot 2's skin, trail and
  fire are chosen in the Tailor via a Pilot 1 / Pilot 2 switch (shown only from that menu) and
  remembered separately; coins and ownership are shared. In the engine, pilot 2's gear is drawn
  and the tiny / giant, armor / eggshell and spinning powers apply to that ship. Steering,
  magnet, speed and coin powers stay with Pilot 1.
- The daily bonus chest counts down to local midnight after it has been claimed.
- The backdrop is a layered space scene: nebula clouds, an aurora sweep, a spiral galaxy, a
  banded gas giant with an orbiting moon, a ringed planet, drifting rocks and treats, twinkling
  and flaring stars, shooting stars, comets, and flybys of the equipped rocket. Layers slide
  against the cursor for depth.
- Ambient motion (starfield, parallax, flybys, shooting stars) is disabled under
  `prefers-reduced-motion`.
- On a phone held upright the whole app is rotated a quarter turn so it plays landscape
  (`html.rotated`, set by `game.js`, which also swaps the canvas size and maps touch
  coordinates). The home screen scrolls by touch. Tablets and desktops are never rotated.

## Power-ups

| Orb | Effect |
| --- | --- |
| `S` Shield | Absorbs asteroid impacts instead of taking hull damage |
| `V` Speed | Faster movement and fire rate; ramming knocks asteroids aside |
| `W` Weapon | Enables the blasters; a second pickup upgrades to a 4-shot spread |
| `M` Magnet | Pulls nearby treats toward your ship (Medium difficulty and above only) |

Sundaes and donuts pay 100 points and repair the hull; destroyed asteroids pay 20; asteroids
that drift off screen pay 10. Difficulty climbs with survival time and score up to a per-mode ceiling.
