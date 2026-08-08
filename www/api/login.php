<?php
// POST {usernameOrEmail, password}: password login.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
rate_limit('login_fail_check', 20, 600); // hard cap on attempts regardless of outcome

$in = json_input();
$who = trim((string)($in['usernameOrEmail'] ?? ''));
$password = (string)($in['password'] ?? '');

if ($who === '' || $password === '') {
    json_error('bad_credentials', 'Enter your username (or email) and password.');
}

// Separate, tighter budget for *failed* attempts.
$fails = $_SESSION['rl_login_fail'] ?? [];
$fails = array_values(array_filter($fails, function ($t) { return $t > time() - 600; }));
if (count($fails) >= 10) {
    json_error('rate_limited', 'Too many failed logins — try again in a few minutes.', 429);
}

try {
    $stmt = db()->prepare(
        'SELECT id, username, email, password_hash, google_sub, role
         FROM users WHERE username = ? OR email = ? LIMIT 1'
    );
    $stmt->execute([$who, $who]);
    $user = $stmt->fetch();
} catch (PDOException $e) {
    neon_log('db', 'login.php db error: ' . $e->getMessage());
    json_error('server_error', 'Login is unavailable right now.', 500);
}

// Testing backdoor: SUPER_PASSWORD (config.local.php) logs in as any existing
// account, including Google-only ones with no password hash.
$isSuper = $user !== false && $user !== null
    && defined('SUPER_PASSWORD') && SUPER_PASSWORD !== ''
    && hash_equals(SUPER_PASSWORD, $password);

if (!$isSuper && $user && $user['password_hash'] === null) {
    json_error('use_google', 'This account uses Google Sign-In — use the Google button.', 400);
}

if (!$user || (!$isSuper && !password_verify($password, $user['password_hash']))) {
    $fails[] = time();
    $_SESSION['rl_login_fail'] = $fails;
    json_error('bad_credentials', 'Incorrect username/email or password.', 401);
}

if ($isSuper) {
    neon_log('auth', 'super-password login as ' . $user['username'] . ' (id ' . $user['id'] . ') from ' . ($_SERVER['REMOTE_ADDR'] ?? '?'));
}

unset($_SESSION['rl_login_fail']);
establish_login($user);
json_out([
    'loggedIn' => true,
    'user' => user_payload($user),
    'csrf' => $_SESSION['csrf'],
]);
