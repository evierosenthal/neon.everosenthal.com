<?php
// POST {identityToken, authorizationCode?, nonce?, fullName?: {givenName, familyName}}
// Sign in with Apple from the iOS app. Apple has no tokeninfo endpoint, so
// the identity token's RS256 signature is verified here against Apple's JWKS
// (api/_jwt.php) and the claims are checked one by one, mirroring google.php.
//
// The one-time authorizationCode is optional: when the server has the Sign in
// with Apple key configured (config.local.php) it is swapped for a refresh
// token, kept only so delete-account.php can revoke Apple's grant.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';
require __DIR__ . '/_jwt.php';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const APPLE_JWKS_MAX_AGE_SEC = 86400;
const APPLE_IAT_WINDOW_SEC = 600; // tokens older than this are replays, not logins

require_post_with_csrf();
rate_limit('apple', 10, 600);

$in = json_input();
$identityToken = (string)($in['identityToken'] ?? '');
if ($identityToken === '' || strlen($identityToken) > 4096) {
    json_error('bad_request', 'Missing Apple identity token.');
}
$authorizationCode = (string)($in['authorizationCode'] ?? '');
$nonce = (string)($in['nonce'] ?? '');
$fullName = is_array($in['fullName'] ?? null) ? $in['fullName'] : [];

// --- Signature ---------------------------------------------------------------

$parts = jwt_split($identityToken);
if (!$parts) {
    neon_log('apple', 'sign-in rejected (malformed identity token)');
    json_error('apple_failed', 'Apple sign-in was rejected.', 401);
}
if (($parts[0]['alg'] ?? '') !== 'RS256') {
    neon_log('apple', 'sign-in rejected (alg ' . ($parts[0]['alg'] ?? '(missing)') . ', expected RS256)');
    json_error('apple_failed', 'Apple sign-in was rejected.', 401);
}

$cacheFile = jwt_cache_path('apple-jwks');
$jwks = jwks_fetch_cached(APPLE_JWKS_URL, $cacheFile, APPLE_JWKS_MAX_AGE_SEC);
if ($jwks === null) {
    json_error('apple_failed', 'Apple sign-in could not be verified — try again.', 502);
}
$kid = (string)($parts[0]['kid'] ?? '');
if ($kid !== '' && !jwks_find($jwks, $kid)) {
    // Apple rotates keys; an unknown kid means our cached document is stale.
    $jwks = jwks_fetch_cached(APPLE_JWKS_URL, $cacheFile, APPLE_JWKS_MAX_AGE_SEC, true) ?? $jwks;
}
$claims = jwt_verify_rs256($identityToken, $jwks);
if ($claims === null) {
    neon_log('apple', 'sign-in rejected (signature did not verify, kid ' . ($kid !== '' ? $kid : '(missing)') . ')');
    json_error('apple_failed', 'Apple sign-in was rejected.', 401);
}

// --- Claims ------------------------------------------------------------------

// Check each claim separately so the log says exactly why a login was rejected.
$now = time();
$emailVerified = $claims['email_verified'] ?? null;
$email = strtolower(trim((string)($claims['email'] ?? '')));
$reject = '';
if (($claims['iss'] ?? '') !== APPLE_ISSUER) {
    $reject = 'bad iss: ' . ($claims['iss'] ?? '(missing)');
} elseif (!in_array($claims['aud'] ?? '', APPLE_ALLOWED_AUDIENCES, true)) {
    $reject = 'aud mismatch: token is for ' . ($claims['aud'] ?? '(missing)') . ', expected one of ' . implode(', ', APPLE_ALLOWED_AUDIENCES);
} elseif ((int)($claims['exp'] ?? 0) <= $now) {
    $reject = 'token expired at ' . ($claims['exp'] ?? '(missing)');
} elseif ((int)($claims['iat'] ?? 0) < $now - APPLE_IAT_WINDOW_SEC || (int)($claims['iat'] ?? 0) > $now + 60) {
    $reject = 'iat outside the last 10 minutes: ' . ($claims['iat'] ?? '(missing)');
} elseif ($nonce !== '' && (($claims['nonce'] ?? '') !== hash('sha256', $nonce))) {
    // The app sends Apple the SHA-256 of a random nonce and us the raw one.
    $reject = 'nonce mismatch';
} elseif (empty($claims['sub']) || !is_string($claims['sub'])) {
    $reject = 'missing sub claim';
} elseif ($email !== '' && $emailVerified !== true && $emailVerified !== 'true') {
    // Required: the email-linking below is only safe with a verified email.
    // (Apple's private relay addresses arrive verified like any other.)
    $reject = 'email not verified';
} elseif ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    $reject = 'email claim is not an email address';
}
if ($reject !== '') {
    neon_log('apple', 'sign-in rejected (' . $reject . ') for ' . ($email !== '' ? $email : 'unknown email'));
    json_error('apple_failed', 'Apple sign-in was rejected.', 401);
}

$sub = (string)$claims['sub'];
$givenName = trim((string)($fullName['givenName'] ?? ''));
$familyName = trim((string)($fullName['familyName'] ?? ''));
$profileName = trim($givenName . ' ' . $familyName);

// --- Account -----------------------------------------------------------------

try {
    $db = db();

    // The apple_sub column arrives with migration 06. Migrations otherwise run
    // only inside user_payload(), i.e. after a login succeeded — too late for
    // the very first Apple login on an upgraded database.
    try {
        apply_all_migrations();
        $_SESSION['migrations_checked'] = 1;
    } catch (PDOException $e) {
        neon_log('db', 'apple.php auto-migration failed: ' . $e->getMessage());
    }

    $user = find_user('apple_sub = ?', [$sub]);

    if (!$user && $email === '') {
        // Apple sends the email in every identity token; a token without one
        // can only be a returning user we already know by sub.
        neon_log('apple', 'sign-in rejected (no email claim and unknown sub)');
        json_error('apple_failed', 'Apple sign-in was rejected.', 401);
    }

    if (!$user) {
        // Link to an existing password/Google account with the same (verified) email.
        $user = find_user('email = ?', [$email]);
        if ($user) {
            $db->prepare('UPDATE users SET apple_sub = ? WHERE id = ?')->execute([$sub, (int)$user['id']]);
            $user['apple_sub'] = $sub;
        }
    }

    if (!$user) {
        $username = derive_username($db, $profileName, $email);
        $db->prepare('INSERT INTO users (username, email, apple_sub) VALUES (?, ?, ?)')
            ->execute([$username, $email, $sub]);
        $user = find_user('id = ?', [(int)$db->lastInsertId()]);
    }

    // Optional: keep a refresh token so account deletion can revoke the grant.
    if ($authorizationCode !== '' && strlen($authorizationCode) <= 2048) {
        if (!apple_server_credentials_ready()) {
            neon_log('apple', 'authorization code not exchanged: APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY_PATH not configured');
        } else {
            $secret = apple_client_secret(APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_BUNDLE_ID, APPLE_PRIVATE_KEY_PATH);
            $tokens = $secret !== null ? apple_token_exchange($authorizationCode, $secret, APPLE_BUNDLE_ID) : null;
            if ($tokens !== null) {
                $db->prepare('UPDATE users SET apple_refresh_token = ? WHERE id = ?')
                    ->execute([substr((string)$tokens['refresh_token'], 0, 1024), (int)$user['id']]);
            }
            // Failure is logged by the helpers; the login itself still succeeds.
        }
    }
} catch (PDOException $e) {
    neon_log('db', 'apple.php db error: ' . $e->getMessage());
    json_error('server_error', 'Login is unavailable right now.', 500);
}

establish_login($user);
neon_log('apple', 'sign-in ok for ' . ($email !== '' ? $email : $user['email']) . ' as ' . $user['username']);
json_out([
    'loggedIn' => true,
    'user' => user_payload($user),
    'csrf' => $_SESSION['csrf'],
]);
