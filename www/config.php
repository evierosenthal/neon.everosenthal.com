<?php
// Non-secret application configuration. Secrets (database, SMTP, webhook)
// live in config.local.php, which is gitignored — see config.local.example.php.

// Google Identity Services OAuth client ID (public by design).
define('GOOGLE_CLIENT_ID', '48815681108-3tt7h00u6lf3gvcdge4kfr0ugip8uh9t.apps.googleusercontent.com');

define('APP_BASE_URL', 'https://neon.everosenthal.com');

define('MAIL_SUBJECT_PREFIX', 'Neon Nebula');

// Score submission sanity limits.
define('SCORE_MAX', 50000000);
define('SCORE_MIN_INTERVAL_SEC', 10);

// Password reset tokens expire after an hour.
define('RESET_TOKEN_TTL_SEC', 3600);

require __DIR__ . '/config.local.php';
