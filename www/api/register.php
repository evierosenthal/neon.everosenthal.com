<?php
// POST {username, email, password}: create an account and log it in.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
rate_limit('register', 5, 600);

$in = json_input();
$username = trim((string)($in['username'] ?? ''));
$email = trim((string)($in['email'] ?? ''));
$password = (string)($in['password'] ?? '');

if (!preg_match('/^[A-Za-z0-9_-]{3,20}$/', $username)) {
    json_error('bad_username', 'Username must be 3-20 characters: letters, numbers, - or _.');
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

    $stmt = $db->prepare('SELECT id, username, email, password_hash, google_sub FROM users WHERE id = ?');
    $stmt->execute([(int)$db->lastInsertId()]);
    $user = $stmt->fetch();
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
