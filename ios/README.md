# Nitro Nebula for iOS

Native Swift port of the web game in `../www/`. SwiftUI shell, Core Graphics
game view, and a Foundation-only simulation package (`NeonEngine`) that is a
line-for-line port of `www/game.js`. Landscape only, iPhone and iPad, iOS 17+.

## Layout

| Path | Contents |
| --- | --- |
| `NeonNebula.xcodeproj` | Xcode project (Xcode 16+ synchronized folders: every file under `NeonNebula/` and `NeonNebulaTests/` is in the target automatically) |
| `Config/` | `Info.plist`, entitlements, `ExportOptions.plist` |
| `NeonEngine/` | Swift package: physics, spawning, collisions, CPU wingman, online snapshot codec, tests (`swift test` runs on macOS) |
| `NeonNebula/App` | App entry, `AppState` (port of `ui.js` state), root screen stack |
| `NeonNebula/Model` | Game modes, ranks, catalog wrappers, `LocalStore` (UserDefaults with the same keys and formats as the web's localStorage), economy |
| `NeonNebula/Game`, `Input`, `Render` | `GameView` + display link loop, floating joystick touch controller, Core Graphics renderer (port of `draw()` in `game.js`) |
| `NeonNebula/Audio` | Music loops and sound effects (AVAudioPlayer, `.ambient` session) |
| `NeonNebula/Net` | API client for `www/api/*.php`, Google Sign-In, Sign in with Apple, Game Center matchmaking and the GameKit transport |
| `NeonNebula/UI` | Theme, home screen, HUD, modals |
| `NeonNebula/Resources` | Fonts (Orbitron, Inter), sounds, asset catalog, privacy manifest |
| `scripts/set-build-number.sh` | Sets the build number to the git commit count before archiving |

## Build and run

```sh
# Simulator build (no signing)
xcodebuild -project ios/NeonNebula.xcodeproj -scheme NeonNebula \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build

# Engine tests (fast, no simulator)
cd ios/NeonEngine && swift test

# App tests
xcodebuild -project ios/NeonNebula.xcodeproj -scheme NeonNebula \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Or open `ios/NeonNebula.xcodeproj` in Xcode, pick a simulator or device, and run.
For a device build set your team under Signing & Capabilities (the project
leaves `DEVELOPMENT_TEAM` empty).

## How the port stays faithful

- The simulation ticks exactly 60 times a second (fixed accumulator on a
  `CADisplayLink`), so every frame-count timer in `game.js` is unchanged.
- Coordinates are top-left, y-down, in points, like the canvas. Nothing is
  flipped or scaled; the world is the view's size.
- Every `Math.random()` call maps to one `RandomSource.next()` in the same
  order. `NeonEngineTests/OracleParityTests` runs the real `www/game.js` in
  JavaScriptCore with a seeded generator and asserts the Swift engine produces
  the same positions and score frame by frame.
- Persistence uses the same `neon_nebula_*` keys and string formats as the web.
- Gear ids, prices and colors are transcribed verbatim (`GearCatalog.swift`);
  the server and the web share the same ids.

Deliberate differences: touch steering is a floating joystick that feeds the
web's keyboard thrust math; local two-player uses two sticks (left half /
right half); online play uses Game Center instead of WebRTC, so an iOS lobby
can only pair with another iOS player (the server refuses mixed lobbies);
wall-clock timers (fire rate, wobble, tutorial fade) use simulation time so
pausing does not advance them. The Magnet Muzzle fire power, which was inert
on the web because of an effect-timer ordering bug, is fixed on both sides.

## Accounts and networking

The app talks to the same PHP endpoints as the browser (`https://neon.everosenthal.com/api/`).
It fetches `session.php` at launch (cookie + CSRF token), sends
`X-CSRF-Token` on every POST, and never sets an `Origin` header. Google
Sign-In uses the GoogleSignIn-iOS SDK; Sign in with Apple uses
AuthenticationServices and the new `api/apple.php`; account deletion calls
`api/delete-account.php`. Online two-player uses the `api/games.php` lobby for
codes and invites and a `GKMatch` (Game Center) for the connection.

## One-time setup you must do in the consoles

1. **Apple Developer Program**: enroll (Account Holder must accept the current
   agreement before uploads).
2. **Identifiers**: App ID `com.everosenthal.nitronebula` with capabilities
   *Sign in with Apple* and *Game Center*. Xcode's automatic signing adds
   them once you add the capabilities in Signing & Capabilities.
3. **Sign in with Apple key**: Keys → create a key with Sign in with Apple,
   bound to the App ID. Download `AuthKey_<KEYID>.p8` once. On the server put it
   outside the web root and add to `www/config.local.php`:
   `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH` (see
   `www/config.local.example.php`). Without them Apple login still works; the
   key is only needed to revoke tokens when an account is deleted.
4. **Email relay**: Certificates, Identifiers & Profiles → Services → Sign in
   with Apple → Email sources: register `everosenthal.com` and the sender
   address used by `SMTP_FROM_EMAIL`, so password-reset mail reaches
   Hide-My-Email relay addresses.
5. **Google Cloud Console** (the project that owns the web client in
   `www/config.php`): Credentials → Create OAuth client ID → *iOS*, bundle id
   `com.everosenthal.nitronebula`. Put the new client id in
   `Config/Info.plist` (`GIDClientID`) and its reversed form in the URL scheme
   (`CFBundleURLSchemes`), and in `www/config.php` (`GOOGLE_IOS_CLIENT_ID`).
   The OAuth consent screen must be *In production* with the privacy policy
   URL `https://neon.everosenthal.com/privacy.php`.
6. **App Store Connect**: create the app (name "Nitro Nebula", bundle id above,
   SKU `neon-nebula-ios`). App Information: category Games / Arcade; Privacy
   Policy URL `https://neon.everosenthal.com/privacy.php`; Support URL
   `https://neon.everosenthal.com/support.php`. Enable Game Center for the app
   and tick it on the version page (no leaderboards/achievements are needed;
   the game uses its own). Age rating questionnaire (no gambling, no
   unrestricted web; user names appear on a public leaderboard). App Privacy:
   Email Address, Name, User ID, Gameplay Content — all linked to the user,
   none used for tracking, purpose App Functionality. Content rights: you own
   or license everything (see notices below). Digital Services Act trader
   status. App Review notes: online two-player needs two iOS devices signed
   into different Game Center accounts and pairs by lobby code; coins are
   earned in play and nothing is sold; Sign in with Apple, Google and email
   are all offered; include a demo account.
7. **Deploy the backend** (`git push` triggers the server webhook), then log
   into the web game once or press Settings → RUN DB MIGRATIONS so migrations
   06 and 07 apply before the first Apple login.
8. **Devices**: two physical iPhones/iPads with different Apple IDs for
   Game Center testing. The simulator cannot run GKMatch matchmaking; Sign in
   with Apple in the simulator needs an iCloud account and a signed build.

## Release

```sh
ios/scripts/set-build-number.sh            # CFBundleVersion = git commit count
xcodebuild -project ios/NeonNebula.xcodeproj -scheme NeonNebula -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/NeonNebula.xcarchive \
  DEVELOPMENT_TEAM=<TEAMID> -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/NeonNebula.xcarchive \
  -exportOptionsPlist ios/Config/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
```

Or Product → Archive in Xcode and distribute to App Store Connect. Use
TestFlight (internal group) for the two-device online test. Screenshots:
iPhone 6.9" 2868×1320 (iPhone 17 Pro Max simulator, landscape) and iPad 13"
2752×2064 (iPad Pro 13-inch simulator), via `xcrun simctl io booted screenshot`.

## Third-party notices

- **Orbitron** by Matt McInerney and **Inter** by Rasmus Andersson — SIL Open
  Font License 1.1 (`NeonNebula/Resources/Fonts/OFL-*.txt`).
- Sound effects from Pixabay (Pixabay Content License): "You Win Sequence 3"
  by floraphonic (#183950), "Spacecraft crashing" by freesound_community
  (#88048), "Cinematic designed sci-fi whoosh spectral glide" by Rescopic
  Sound (#228310).
- `background-music.m4a` and `home-music.m4a` are original compositions for
  this game.
- GoogleSignIn-iOS, AppAuth-iOS, GTMAppAuth, GTMSessionFetcher,
  GoogleUtilities, Promises, AppCheckCore — Apache License 2.0.
