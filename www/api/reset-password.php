<?php
// POST {token, newPassword}: consume an emailed reset token, set the new
// password and log the user in. Token-authenticated (not session): the email
// link is a cross-site navigation, so the Strict session cookie may be new.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
rate_limit('reset_attempt', 10, 600);

$in = json_input();
$token = (string)($in['token'] ?? '');
$password = (string)($in['newPassword'] ?? '');

if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
    json_error('invalid_token', 'This reset link is not valid.', 400);
}
if (strlen($password) < 8) {
    json_error('bad_password', 'Password must be at least 8 characters.');
}

try {
    $db = db();
    $stmt = $db->prepare(
        'SELECT pr.id AS reset_id, pr.expires_at, pr.used_at,
                u.id, u.username, u.email, u.password_hash, u.google_sub
         FROM password_resets pr JOIN users u ON u.id = pr.user_id
         WHERE pr.token_hash = ?'
    );
    $stmt->execute([hash('sha256', $token)]);
    $row = $stmt->fetch();

    if (!$row || $row['used_at'] !== null) {
        json_error('invalid_token', 'This reset link is not valid or was already used.', 400);
    }
    if (strtotime($row['expires_at']) < time()) {
        json_error('expired_token', 'This reset link has expired — request a new one.', 400);
    }

    $db->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
        ->execute([password_hash($password, PASSWORD_DEFAULT), (int)$row['id']]);
    $db->prepare('UPDATE password_resets SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL')
        ->execute([(int)$row['id']]);
} catch (PDOException $e) {
    error_log('reset-password.php db error: ' . $e->getMessage());
    json_error('server_error', 'Password reset is unavailable right now.', 500);
}

establish_login($row);
json_out([
    'loggedIn' => true,
    'user' => user_payload($row),
    'csrf' => $_SESSION['csrf'],
]);
