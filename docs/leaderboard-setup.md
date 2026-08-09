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
define('SMTP_FROM_NAME', 'Neon Nebula');
```

The From address should be on a domain whose SPF allows the SMTP host, or the
mail lands in spam.

## 4. HTTPS

The session cookie is set with the `Secure` flag, so the site must be served
over HTTPS (it already is in production). For local testing over plain HTTP,
the API detects the missing HTTPS and drops the Secure flag automatically.

## Local testing

```sh
php -S localhost:8000 -t www
```

The PHP built-in server runs the `www/api/` endpoints; point `DB_DSN` in a
local `www/config.local.php` at any test MySQL database. Without a database the
game still runs — login and the leaderboard just report themselves offline.
