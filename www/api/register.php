<?php
// POST {username, email, password}: create an account and log it in.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
rate_limit('register', 5, 600);

// Call signs appear on the public leaderboard and in lobbies, so a short
// blocklist keeps out impersonation (staff/vendor names) and obvious slurs.
// Deliberately modest: exact matches for reserved names, substrings for the
// rest. Case-insensitive; separators are ignored (a_d-m_i_n).
const USERNAME_RESERVED = [
    'admin', 'administrator', 'moderator', 'mod', 'neonnebula', 'neon_nebula', 'nitronebula', 'nitro_nebula', 'support',
    'apple', 'google', 'staff', 'system', 'official', 'everosenthal',
];
const USERNAME_BLOCKED_SUBSTRINGS = [
    'nigg', 'fagg', 'kike', 'chink', 'retard', 'tranny',
    'cunt', 'fuck', 'shit', 'bitch', 'whore', 'slut', 'nazi', 'hitler', 'penis',
];

function username_blocked(string $username): bool
{
    $lower = strtolower($username);
    $squashed = str_replace(['_', '-'], '', $lower);
    if (in_array($lower, USERNAME_RESERVED, true) || in_array($squashed, USERNAME_RESERVED, true)) {
        return true;
    }
    foreach (USERNAME_BLOCKED_SUBSTRINGS as $bad) {
        if (strpos($squashed, $bad) !== false) {
            return true;
        }
    }
    return false;
}

$in = json_input();
$username = trim((string)($in['username'] ?? ''));
$email = trim((string)($in['email'] ?? ''));
$password = (string)($in['password'] ?? '');

if (!preg_match('/^[A-Za-z0-9_-]{3,20}$/', $username)) {
    json_error('bad_username', 'Username must be 3-20 characters: letters, numbers, - or _.');
}
if (username_blocked($username)) {
    json_error('bad_username', "That call sign isn't available.");
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 255) {
    json_error('bad_email', 'Enter a valid email address.');
}
if (strlen($password) < 8) {
    json_error('bad_password', 'Password must be at least 8 characters.');
}

try {
    $db = db();
    $stmt = $db->prepare('SELECT id FROM users WHERE username = ?');
    $stmt->execute([$username]);
    if ($stmt->fetch()) {
        json_error('username_taken', 'That call sign is taken — pick another.', 409);
    }
    $stmt = $db->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        json_error('email_taken', 'That email is already registered — log in, use Google, or reset your password.', 409);
    }

    $stmt = $db->prepare('INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)');
    $stmt->execute([$username, $email, password_hash($password, PASSWORD_DEFAULT)]);

    $user = find_user('id = ?', [(int)$db->lastInsertId()]);
} catch (PDOException $e) {
    error_log('register.php db error: ' . $e->getMessage());
    json_error('server_error', 'Registration is unavailable right now.', 500);
}

establish_login($user);
json_out([
    'loggedIn' => true,
    'user' => user_payload($user),
    'csrf' => $_SESSION['csrf'],
]);
