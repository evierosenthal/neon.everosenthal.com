<?php
// POST {credential}: Google Identity Services ID token. Verified server-side
// via Google's tokeninfo endpoint (sanctioned for low-volume validation and
// avoids hand-rolling RS256/JWKS). Runs once per login, not per request.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
rate_limit('google', 10, 600);

$in = json_input();
$credential = (string)($in['credential'] ?? '');
if ($credential === '' || strlen($credential) > 4096) {
    json_error('bad_request', 'Missing Google credential.');
}

$ch = curl_init('https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($credential));
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 5,
    CURLOPT_CONNECTTIMEOUT => 5,
]);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
curl_close($ch);

$claims = $response !== false ? json_decode($response, true) : null;
if ($httpCode !== 200 || !is_array($claims)) {
    neon_log('google', "tokeninfo call failed: http $httpCode, body: " . substr((string)$response, 0, 300));
    json_error('google_failed', 'Google sign-in could not be verified — try again.', 502);
}

// Check each claim separately so the log says exactly why a login was rejected.
$reject = '';
if (!in_array($claims['iss'] ?? '', ['https://accounts.google.com', 'accounts.google.com'], true)) {
    $reject = 'bad iss: ' . ($claims['iss'] ?? '(missing)');
} elseif (($claims['aud'] ?? '') !== GOOGLE_CLIENT_ID) {
    $reject = 'aud mismatch: token is for ' . ($claims['aud'] ?? '(missing)') . ', expected ' . GOOGLE_CLIENT_ID;
} elseif ((int)($claims['exp'] ?? 0) < time()) {
    $reject = 'token expired at ' . ($claims['exp'] ?? '(missing)');
} elseif (($claims['email_verified'] ?? '') !== 'true') {
    // Required: the email-linking below is only safe with a verified email.
    $reject = 'email not verified';
} elseif (empty($claims['sub']) || empty($claims['email'])) {
    $reject = 'missing sub or email claim';
}
if ($reject !== '') {
    neon_log('google', 'sign-in rejected (' . $reject . ') for ' . ($claims['email'] ?? 'unknown email'));
    json_error('google_failed', 'Google sign-in was rejected.', 401);
}

$sub = (string)$claims['sub'];
$email = strtolower((string)$claims['email']);
$profileName = (string)($claims['name'] ?? '');

// Derive a unique username from the Google profile name (fallback: email
// prefix), suffixing on collision: brian, brian2, brian3...
function derive_username(PDO $db, string $profileName, string $email): string
{
    $base = preg_replace('/[^A-Za-z0-9_-]/', '', str_replace(' ', '_', $profileName));
    if (strlen($base) < 3) {
        $base = preg_replace('/[^A-Za-z0-9_-]/', '', explode('@', $email)[0]);
    }
    if (strlen($base) < 3) {
        $base = 'pilot';
    }
    $base = substr($base, 0, 17); // leave room for a numeric suffix

    $stmt = $db->prepare('SELECT id FROM users WHERE username = ?');
    $candidate = $base;
    for ($i = 2; $i < 1000; $i++) {
        $stmt->execute([$candidate]);
        if (!$stmt->fetch()) {
            return $candidate;
        }
        $candidate = $base . $i;
    }
    return $base . bin2hex(random_bytes(2));
}

try {
    $db = db();

    $stmt = $db->prepare('SELECT id, username, email, password_hash, google_sub, role FROM users WHERE google_sub = ?');
    $stmt->execute([$sub]);
    $user = $stmt->fetch();

    if (!$user) {
        // Link to an existing password account with the same (verified) email.
        $stmt = $db->prepare('SELECT id, username, email, password_hash, google_sub, role FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if ($user) {
            $db->prepare('UPDATE users SET google_sub = ? WHERE id = ?')->execute([$sub, (int)$user['id']]);
            $user['google_sub'] = $sub;
        }
    }

    if (!$user) {
        $username = derive_username($db, $profileName, $email);
        $db->prepare('INSERT INTO users (username, email, google_sub) VALUES (?, ?, ?)')
            ->execute([$username, $email, $sub]);
        $stmt = $db->prepare('SELECT id, username, email, password_hash, google_sub, role FROM users WHERE id = ?');
        $stmt->execute([(int)$db->lastInsertId()]);
        $user = $stmt->fetch();
    }
} catch (PDOException $e) {
    neon_log('db', 'google.php db error: ' . $e->getMessage());
    json_error('server_error', 'Login is unavailable right now.', 500);
}

establish_login($user);
neon_log('google', 'sign-in ok for ' . $email . ' as ' . $user['username']);
json_out([
    'loggedIn' => true,
    'user' => user_payload($user),
    'csrf' => $_SESSION['csrf'],
]);
