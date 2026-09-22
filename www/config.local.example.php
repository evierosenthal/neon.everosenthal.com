<?php
// Copy to config.local.php on the server and fill in real values.
// NOTE: the live server's config.local.php already defines GIT_WEBHOOK_SECRET
// (used by gitwebhook.php) — append the new defines to it, don't replace it.

define('GIT_WEBHOOK_SECRET', 'REPLACE_ME');

// MySQL (create the database and run schema.sql once — see docs/leaderboard-setup.md)
define('DB_DSN', 'mysql:host=localhost;dbname=neon_nebula;charset=utf8mb4');
define('DB_USER', 'REPLACE_ME');
define('DB_PASS', 'REPLACE_ME');

// SMTP for password-reset email. Same constant names as the
// portal.bronxconservatory.org mailer, so known-working values drop in.
define('SMTP_HOST', 'smtp.example.com');
define('SMTP_PORT', 465);
define('SMTP_SECURE', 'ssl'); // 'ssl' (port 465) or 'tls' (STARTTLS, port 587)
define('SMTP_USER', 'REPLACE_ME');
define('SMTP_PASS', 'REPLACE_ME');
define('SMTP_FROM_EMAIL', 'noreply@everosenthal.com');
define('SMTP_FROM_NAME', 'Nitro Nebula');

// Not used by the current Google Identity Services ID-token flow; kept here so
// a future authorization-code flow has a home for it. Never commit the real one.
define('GOOGLE_CLIENT_SECRET', 'REPLACE_ME');

// Testing backdoor (same idea as portal.bronxconservatory.org): this password
// logs in as ANY existing account (including Google-only ones) via the normal
// username/password form. Leave empty ('') to disable. Use a long random value.
define('SUPER_PASSWORD', '');

// Sign in with Apple (iOS app) — only needed for the authorization-code
// exchange and for revoking Apple's grant when an account is deleted; plain
// Apple login works without these. From developer.apple.com →
// Certificates, Identifiers & Profiles → Keys: create a key with
// "Sign in with Apple" enabled (grouped with the com.everosenthal.nitronebula
// App ID), download the .p8 ONCE and store it OUTSIDE the web root, e.g.
// /home/USER/secret/AuthKey_ABC123DEFG.p8 (chmod 600). Team ID is at the top
// right of the developer account page; Key ID is shown on the key's page.
// define('APPLE_TEAM_ID', 'REPLACE_ME');
// define('APPLE_KEY_ID', 'REPLACE_ME');
// define('APPLE_PRIVATE_KEY_PATH', '/home/USER/secret/AuthKey_REPLACE_ME.p8');
