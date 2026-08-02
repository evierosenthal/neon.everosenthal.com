<?php
// POST {email}: email a password-reset link. Always answers with the same
// generic success so account existence can't be probed.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';
require __DIR__ . '/_mailer.php';

require_post_with_csrf();
rate_limit('reset_request', 3, 3600);

$in = json_input();
$email = trim((string)($in['email'] ?? ''));
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_error('bad_email', 'Enter a valid email address.');
}

$genericResponse = ['ok' => true, 'message' => 'If that email has an account, a reset link is on its way.'];

try {
    $stmt = db()->prepare('SELECT id, username FROM users WHERE email = ? AND password_hash IS NOT NULL');
    $stmt->execute([$email]);
    $user = $stmt->fetch();
} catch (PDOException $e) {
    error_log('request-reset.php db error: ' . $e->getMessage());
    json_out($genericResponse);
}

if ($user) {
    $token = bin2hex(random_bytes(32));
    try {
        db()->prepare('INSERT INTO password_resets (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))')
            ->execute([(int)$user['id'], hash('sha256', $token), RESET_TOKEN_TTL_SEC]);

        $link = APP_BASE_URL . '/?reset=' . $token;
        $safeLink = htmlspecialchars($link, ENT_QUOTES, 'UTF-8');
        $safeName = htmlspecialchars($user['username'], ENT_QUOTES, 'UTF-8');
        $html = '<p>Hello ' . $safeName . ',</p>'
            . '<p>You requested a password reset for your Neon Nebula account.</p>'
            . '<p><a href="' . $safeLink . '">' . $safeLink . '</a></p>'
            . '<p>This link expires in 1 hour. If you did not request this reset, you can safely ignore this email.</p>';

        $error = '';
        if (!send_smtp_mail($email, $user['username'], MAIL_SUBJECT_PREFIX . ' password reset', $html, $error)) {
            error_log('request-reset.php mail error: ' . $error);
        }
    } catch (PDOException $e) {
        error_log('request-reset.php db error: ' . $e->getMessage());
    }
}

json_out($genericResponse);
