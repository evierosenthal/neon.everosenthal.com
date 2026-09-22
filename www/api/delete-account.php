<?php
// POST {password?, appleAuthorizationCode?}: delete the logged-in account
// (App Store guideline 5.1.1(v): an app that lets people create an account
// must let them delete it in-app). Password accounts must confirm with their
// password; social-only accounts are confirmed by the live session.
//
// Removes the user row and, through the foreign keys, their scores, reset
// tokens, invites and hosted lobbies; a lobby they were merely a guest in
// keeps running with the seat emptied. If the account was linked to Sign in
// with Apple, Apple's grant is revoked first (best effort, never blocking).
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';
require __DIR__ . '/_jwt.php';

require_post_with_csrf();
$user = require_user();
rate_limit('delete_account', 3, 3600);

$in = json_input();
$password = (string)($in['password'] ?? '');
$appleCode = (string)($in['appleAuthorizationCode'] ?? '');
$userId = (int)$user['id'];

if (!empty($user['password_hash'])) {
    if ($password === '' || !password_verify($password, $user['password_hash'])) {
        json_error('bad_credentials', 'Enter your password to delete this account.', 401);
    }
}

// --- Revoke the Sign in with Apple grant (best effort) ----------------------

if (!empty($user['apple_sub'])) {
    if (!apple_server_credentials_ready()) {
        neon_log('apple', "revoke skipped for user id $userId: APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY_PATH not configured");
    } else {
        $secret = apple_client_secret(APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_BUNDLE_ID, APPLE_PRIVATE_KEY_PATH);
        $refreshToken = '';
        if ($secret !== null) {
            // A fresh authorization code from the app beats the stored token,
            // which may have been minted for a login long ago.
            if ($appleCode !== '' && strlen($appleCode) <= 2048) {
                $tokens = apple_token_exchange($appleCode, $secret, APPLE_BUNDLE_ID);
                if ($tokens !== null) {
                    $refreshToken = (string)$tokens['refresh_token'];
                }
            }
            if ($refreshToken === '') {
                try {
                    $stmt = db()->prepare('SELECT apple_refresh_token FROM users WHERE id = ?');
                    $stmt->execute([$userId]);
                    $refreshToken = (string)($stmt->fetchColumn() ?: '');
                } catch (PDOException $e) {
                    neon_log('db', 'delete-account.php could not read apple_refresh_token: ' . $e->getMessage());
                }
            }
            if ($refreshToken === '') {
                neon_log('apple', "revoke skipped for user id $userId: no refresh token on file and no authorization code sent");
            } elseif (apple_token_revoke($refreshToken, $secret, APPLE_BUNDLE_ID)) {
                neon_log('apple', "grant revoked for user id $userId");
            }
            // Revoke failures are logged inside apple_token_revoke().
        }
    }
}

// --- Delete ------------------------------------------------------------------

try {
    $db = db();
    $db->beginTransaction();
    // game_signals has no foreign key (schema.sql), so the relay messages of
    // lobbies this user hosted go explicitly; games (host: CASCADE, guest:
    // SET NULL), scores, password_resets and game_invites (CASCADE) follow
    // the users row.
    $db->prepare('DELETE FROM game_signals WHERE code IN (SELECT code FROM games WHERE host_user_id = ?)')
        ->execute([$userId]);
    $db->prepare("UPDATE games SET status = 'finished' WHERE guest_user_id = ? AND status = 'started'")
        ->execute([$userId]);
    $db->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);
    $db->commit();
} catch (PDOException $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    neon_log('db', 'delete-account.php db error: ' . $e->getMessage());
    json_error('server_error', 'Account deletion is unavailable right now.', 500);
}

neon_log('auth', "account deleted: user id $userId");

// End the session exactly as logout.php does, then hand out a fresh CSRF
// token so the client can carry on logged out.
$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', [
        'expires' => time() - 42000,
        'path' => $p['path'],
        'secure' => $p['secure'],
        'httponly' => $p['httponly'],
        'samesite' => $p['samesite'],
    ]);
}
session_destroy();

session_start();
session_regenerate_id(true);
$_SESSION['csrf'] = bin2hex(random_bytes(32));

json_out(['ok' => true, 'loggedIn' => false, 'user' => null, 'csrf' => $_SESSION['csrf']]);
