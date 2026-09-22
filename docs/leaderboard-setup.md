# Leaderboard / login setup

One-time manual steps to bring the login system and leaderboard live.

## 1. MySQL

1. In the hosting control panel, create a database `neon_nebula` and a user with
   SELECT / INSERT / UPDATE / DELETE privileges on it.
2. Run `schema.sql` against the database (phpMyAdmin SQL tab, or
   `mysql -u USER -p neon_nebula < schema.sql`). If the database was created
   from an older schema.sql, run the numbered upgrades in `www/db_migrations/`
   instead (see `www/db_migrations/README.md`).
3. Append to the server's `config.local.php` (in the web root, next to
   `config.php` and `gitwebhook.php` — it already holds `GIT_WEBHOOK_SECRET`):

   ```php
   define('DB_DSN', 'mysql:host=localhost;dbname=neon_nebula;charset=utf8mb4');
   define('DB_USER', '...');
   define('DB_PASS', '...');
   ```

## 2. Google Sign-In

The OAuth client ID is already in `config.php`. In Google Cloud Console →
APIs & Services → Credentials → that OAuth client, make sure **Authorized
JavaScript origins** contains:

- `https://neon.everosenthal.com`
- `http://localhost:8000` (for local testing)

No client secret is needed on the server: the game uses the Google Identity
Services popup, and the ID token is verified server-side against Google's
tokeninfo endpoint.

### Google Sign-In from the iOS app

The app cannot use the web client. In the same Google Cloud project create a
second OAuth client of type **iOS** with bundle id `com.everosenthal.nitronebula`
(and the App Store id once there is one). Put its client ID in `config.php`:

```php
define('GOOGLE_IOS_CLIENT_ID', '48815681108-....apps.googleusercontent.com');
```

`api/google.php` accepts an ID token whose audience is either client
(`GOOGLE_ALLOWED_CLIENT_IDS`). The iOS project needs the same ID (and its
reversed form as a URL scheme) — see `ios/README.md`.

## 2b. Sign in with Apple (iOS app)

Plain Apple login needs nothing on the server: `api/apple.php` verifies the
identity token against Apple's public keys, and the accepted audience is the
bundle id (`APPLE_BUNDLE_ID` in `config.php`).

To also **revoke** Apple's grant when a player deletes their account (App
Store review expects this), the server needs a Sign in with Apple key:

1. developer.apple.com → Certificates, Identifiers & Profiles → **Keys** →
   `+`, tick *Sign in with Apple*, Configure → primary App ID
   `com.everosenthal.nitronebula`. Download the `.p8` (only offered once).
2. Upload it somewhere **outside** the web root, e.g.
   `/home/USER/secret/AuthKey_ABC123DEFG.p8`, `chmod 600`.
3. Append to `config.local.php` (Team ID: top right of the developer account
   page; Key ID: on the key's page):

   ```php
   define('APPLE_TEAM_ID', 'ABCDE12345');
   define('APPLE_KEY_ID', 'ABC123DEFG');
   define('APPLE_PRIVATE_KEY_PATH', '/home/USER/secret/AuthKey_ABC123DEFG.p8');
   ```

With those set, `apple.php` swaps the app's one-time authorization code for a
refresh token (stored in `users.apple_refresh_token`) and
`delete-account.php` revokes it. Without them both endpoints still work; the
revocation step is just logged as skipped.

The server caches Apple's JWKS in `www/cache/apple-jwks.json` (gitignored,
`.htaccess` denies web access); the directory is created on first use, so the
web server user must be able to write under `www/`.

### Deploy order for the iOS release

1. Push (`gitwebhook.php` pulls). The new columns (`apple_sub`,
   `apple_refresh_token`, `host_platform`, `guest_platform`) are added by
   migrations 06 and 07.
2. Log in on the web as the lead developer and press Settings → **RUN DB
   MIGRATIONS** *before the first Apple login*. (The migrations also run on
   their own: at the first login of a session, and `apple.php` /
   `find_user()` apply them defensively if a query hits a missing column —
   but running them by hand keeps the first app login from paying for it.)
3. Fill in `GOOGLE_IOS_CLIENT_ID` and, optionally, the three `APPLE_*`
   constants above.

## 3. SMTP (password-reset email)

Append SMTP credentials to `config.local.php` — same constant names as the
portal.bronxconservatory.org mailer, so its known-working values can be reused:

```php
define('SMTP_HOST', '...');
define('SMTP_PORT', 465);
define('SMTP_SECURE', 'ssl'); // or 'tls' with port 587
define('SMTP_USER', '...');
define('SMTP_PASS', '...');
define('SMTP_FROM_EMAIL', 'noreply@everosenthal.com');
define('SMTP_FROM_NAME', 'Nitro Nebula');
```

The From address should be on a domain whose SPF allows the SMTP host, or the
mail lands in spam.

## 4. HTTPS

The session cookie is set with the `Secure` flag, so the site must be served
over HTTPS (it already is in production). For local testing over plain HTTP,
the API detects the missing HTTPS and drops the Secure flag automatically.

## Online two-player

`api/games.php` (lobbies, invites, WebRTC signaling) needs the tables from
`www/db_migrations/05_online_games.sql`. They are created automatically the
next time someone logs in (the self-healing migration runner), or from
Settings → RUN DB MIGRATIONS. No other server setup: the game data itself
flows browser-to-browser, and the public Google STUN servers handle NAT
discovery. There is no TURN relay, so two players on very strict networks may
not be able to link up.

The iOS app uses the same lobbies but links devices over Game Center, so a
lobby remembers its platform (`07_games_platform.sql`) and a web player
cannot join an app lobby or vice versa (`platform_mismatch`). Game Center
needs nothing on the server beyond enabling the capability in App Store
Connect.

## Local testing

```sh
php -S localhost:8000 -t www
```

The PHP built-in server runs the `www/api/` endpoints; point `DB_DSN` in a
local `www/config.local.php` at any test MySQL database. Without a database the
game still runs — login and the leaderboard just report themselves offline.
