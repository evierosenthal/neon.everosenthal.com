<?php
// Shared plumbing for the www/api/ endpoints: config, session, PDO, JSON
// helpers, CSRF. Each endpoint defines NEON_API before requiring this file so
// a direct browser hit of _bootstrap.php outputs nothing.
defined('NEON_API') or exit;

require dirname(__DIR__) . '/config.php';

// --- Session ---------------------------------------------------------------

// Secure flag only over HTTPS so `php -S localhost:8000` keeps working.
$neonHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');

ini_set('session.gc_maxlifetime', (string)(60 * 60 * 24 * 30));
session_set_cookie_params([
    'lifetime' => 60 * 60 * 24 * 30,
    'path' => '/',
    'secure' => $neonHttps,
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_name('neon_sid');
session_start();

if (empty($_SESSION['csrf'])) {
    $_SESSION['csrf'] = bin2hex(random_bytes(32));
}

// --- Helpers ---------------------------------------------------------------

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(DB_DSN, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    }
    return $pdo;
}

function json_out(array $data, int $code = 200): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data);
    exit;
}

function json_error(string $error, string $message, int $code = 400): void
{
    json_out(['error' => $error, 'message' => $message], $code);
}

function json_input(): array
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '', true);
    if (!is_array($data)) {
        json_error('bad_request', 'Expected a JSON body.', 400);
    }
    return $data;
}

// POST + same-origin + CSRF token. Layered with the SameSite=Strict cookie.
function require_post_with_csrf(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error('method_not_allowed', 'POST required.', 405);
    }
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    if ($origin !== '' && stripos(APP_BASE_URL, $origin) !== 0 && !preg_match('#^https?://localhost(:\d+)?$#', $origin)) {
        json_error('bad_origin', 'Cross-origin request rejected.', 403);
    }
    $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    if ($token === '' || !hash_equals($_SESSION['csrf'], $token)) {
        json_error('bad_csrf', 'Missing or invalid CSRF token.', 403);
    }
}

function current_user(): ?array
{
    if (empty($_SESSION['user_id'])) {
        return null;
    }
    $stmt = db()->prepare('SELECT id, username, email, password_hash, google_sub, best_score FROM users WHERE id = ?');
    $stmt->execute([(int)$_SESSION['user_id']]);
    $user = $stmt->fetch();
    if (!$user) {
        unset($_SESSION['user_id']);
        return null;
    }
    return $user;
}

function require_user(): array
{
    $user = current_user();
    if (!$user) {
        json_error('unauthorized', 'Log in first.', 401);
    }
    return $user;
}

function user_payload(array $user): array
{
    return [
        'id' => (int)$user['id'],
        'username' => $user['username'],
        'bestScore' => (int)$user['best_score'],
    ];
}

// Log the user in on this session (register, login, google, reset all funnel
// through here). Regenerates the session id against fixation.
function establish_login(array $user): void
{
    session_regenerate_id(true);
    $_SESSION['user_id'] = (int)$user['id'];
    $_SESSION['csrf'] = bin2hex(random_bytes(32));
}

// Session-scoped rate limiting: allow $max events per $windowSec.
function rate_limit(string $key, int $max, int $windowSec): void
{
    $now = time();
    $events = $_SESSION['rl_' . $key] ?? [];
    $events = array_values(array_filter($events, function ($t) use ($now, $windowSec) {
        return $t > $now - $windowSec;
    }));
    if (count($events) >= $max) {
        json_error('rate_limited', 'Too many attempts — try again later.', 429);
    }
    $events[] = $now;
    $_SESSION['rl_' . $key] = $events;
}

function leaderboard_rows(): array
{
    $rows = db()->query(
        'SELECT username, best_score FROM users WHERE best_score > 0
         ORDER BY best_score DESC, best_score_at ASC LIMIT 10'
    )->fetchAll();
    $out = [];
    foreach ($rows as $i => $row) {
        $out[] = [
            'rank' => $i + 1,
            'username' => $row['username'],
            'score' => (int)$row['best_score'],
        ];
    }
    return $out;
}
