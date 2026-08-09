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

// Append a timestamped line to www/logs/app.log (gitignored; .htaccess denies
// web access). Also mirrored to error_log so nothing is lost if the write fails.
function neon_log(string $channel, string $message): void
{
    $line = '[' . date('Y-m-d H:i:s') . "] [$channel] $message";
    $dir = dirname(__DIR__) . '/logs';
    if (!is_dir($dir)) {
        @mkdir($dir, 0775, true);
    }
    if (@file_put_contents($dir . '/app.log', $line . "\n", FILE_APPEND | LOCK_EX) === false) {
        error_log('neon_log fallback: ' . $line);
    }
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(DB_DSN, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        // Strict mode: shared-host MySQL otherwise coerces bad values (e.g. an
        // enum the schema doesn't know yet) into silent garbage instead of
        // erroring — we want those failures loud.
        try {
            $pdo->exec("SET SESSION sql_mode = CONCAT(@@sql_mode, ',STRICT_ALL_TABLES')");
        } catch (PDOException $e) {
            error_log('could not enable strict sql_mode: ' . $e->getMessage());
        }
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

// Solo tiers plus their two-player counterparts (tracked separately).
const GAME_MODES = ['easy', 'medium', 'hard', 'super', '2p_easy', '2p_medium', '2p_hard', '2p_super'];

function current_user(): ?array
{
    if (empty($_SESSION['user_id'])) {
        return null;
    }
    $stmt = db()->prepare('SELECT id, username, email, password_hash, google_sub, role FROM users WHERE id = ?');
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

// Apply any migrations in www/db_migrations/ that have not run yet. Applied
// names are tracked in schema_migrations; the files are idempotent by
// convention, so a re-run is safe even if tracking is ever lost.
function apply_all_migrations(): array
{
    $db = db();
    $db->exec('CREATE TABLE IF NOT EXISTS schema_migrations (
        name VARCHAR(80) PRIMARY KEY,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');
    $done = $db->query('SELECT name FROM schema_migrations')->fetchAll(PDO::FETCH_COLUMN);

    $results = [];
    $files = glob(dirname(__DIR__) . '/db_migrations/*.sql') ?: [];
    sort($files);
    foreach ($files as $file) {
        $name = basename($file);
        if (in_array($name, $done, true)) {
            $results[$name] = 'already applied';
            continue;
        }
        // Strip "--" comment lines, then split into statements at semicolons
        // (our migrations never quote a semicolon).
        $lines = [];
        foreach (explode("\n", (string)file_get_contents($file)) as $line) {
            if (!preg_match('/^\s*--/', $line)) {
                $lines[] = $line;
            }
        }
        $statements = array_values(array_filter(array_map('trim', explode(';', implode("\n", $lines)))));
        foreach ($statements as $statement) {
            $db->exec($statement);
        }
        $db->prepare('INSERT IGNORE INTO schema_migrations (name) VALUES (?)')->execute([$name]);
        $results[$name] = 'applied';
        neon_log('db', "migration applied: $name");
    }
    return $results;
}

function user_payload(array $user): array
{
    // Self-healing schema: the first login of a session applies any pending
    // migrations, so a deploy never leaves the database behind the code.
    if (empty($_SESSION['migrations_checked'])) {
        $_SESSION['migrations_checked'] = 1;
        try {
            apply_all_migrations();
        } catch (PDOException $e) {
            neon_log('db', 'auto-migration failed: ' . $e->getMessage());
        }
    }

    // Configured lead developers / developers get their role on any login, so
    // the very first sign-in with a listed email already carries the role.
    $leads = defined('LEAD_DEVELOPER_EMAILS') ? LEAD_DEVELOPER_EMAILS : [];
    $devs = defined('DEVELOPER_EMAILS') ? DEVELOPER_EMAILS : [];
    $role = $user['role'] ?? 'normal';
    $email = strtolower($user['email']);
    if ($role !== 'lead_developer' && in_array($email, array_map('strtolower', $leads), true)) {
        db()->prepare("UPDATE users SET role = 'lead_developer' WHERE id = ?")
            ->execute([(int)$user['id']]);
        $role = 'lead_developer';
    } elseif ($role === 'normal' && in_array($email, array_map('strtolower', $devs), true)) {
        db()->prepare("UPDATE users SET role = 'developer' WHERE id = ?")
            ->execute([(int)$user['id']]);
        $role = 'developer';
    }

    $bests = array_fill_keys(GAME_MODES, 0);
    $stmt = db()->prepare('SELECT mode, best_score FROM scores WHERE user_id = ?');
    $stmt->execute([(int)$user['id']]);
    foreach ($stmt->fetchAll() as $row) {
        $bests[$row['mode']] = (int)$row['best_score'];
    }
    return [
        'id' => (int)$user['id'],
        'username' => $user['username'],
        'role' => $role,
        'bestScores' => $bests,
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

function leaderboard_rows(string $mode): array
{
    $stmt = db()->prepare(
        'SELECT u.username, s.best_score FROM scores s JOIN users u ON u.id = s.user_id
         WHERE s.mode = ? AND s.best_score > 0
         ORDER BY s.best_score DESC, s.best_score_at ASC LIMIT 10'
    );
    $stmt->execute([$mode]);
    $out = [];
    foreach ($stmt->fetchAll() as $i => $row) {
        $out[] = [
            'rank' => $i + 1,
            'username' => $row['username'],
            'score' => (int)$row['best_score'],
        ];
    }
    return $out;
}

function all_leaderboards(): array
{
    $out = [];
    foreach (GAME_MODES as $mode) {
        $out[$mode] = leaderboard_rows($mode);
    }
    return $out;
}
