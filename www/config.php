<?php
// Non-secret application configuration. Secrets (database, SMTP, webhook)
// live in config.local.php, which is gitignored — see config.local.example.php.

// Google Identity Services OAuth client ID (public by design). This is the
// "Web application" client the browser game uses.
define('GOOGLE_CLIENT_ID', '48815681108-3tt7h00u6lf3gvcdge4kfr0ugip8uh9t.apps.googleusercontent.com');

// The iOS app signs in with its own "iOS" OAuth client (same Google Cloud
// project, bundle id com.everosenthal.nitronebula) and its ID tokens carry that
// client as the audience. Create it in Google Cloud Console → Credentials and
// paste the ID here — see docs/leaderboard-setup.md. Public by design.
define('GOOGLE_IOS_CLIENT_ID', '48815681108-n7ijolk9g7b2706fd8hd1jed720jo31i.apps.googleusercontent.com');

// Every audience api/google.php accepts.
define('GOOGLE_ALLOWED_CLIENT_IDS', [GOOGLE_CLIENT_ID, GOOGLE_IOS_CLIENT_ID]);

// Sign in with Apple (iOS app). The identity token's audience is the app's
// bundle id. Team id, key id and the .p8 path are secrets → config.local.php.
define('APPLE_BUNDLE_ID', 'com.everosenthal.nitronebula');
define('APPLE_ALLOWED_AUDIENCES', [APPLE_BUNDLE_ID]);

define('APP_BASE_URL', 'https://neon.everosenthal.com');

// These emails are granted the lead_developer role automatically at login.
define('LEAD_DEVELOPER_EMAILS', ['eve.esther.rosenthal@gmail.com']);

// These emails are granted the developer role automatically at login
// (all skins and other purchasables free). Add Dean Wong's email here.
define('DEVELOPER_EMAILS', []);

define('MAIL_SUBJECT_PREFIX', 'Nitro Nebula');

// Score submission sanity limits.
define('SCORE_MAX', 50000000);
define('SCORE_MIN_INTERVAL_SEC', 10);

// Password reset tokens expire after an hour.
define('RESET_TOKEN_TTL_SEC', 3600);

require __DIR__ . '/config.local.php';
