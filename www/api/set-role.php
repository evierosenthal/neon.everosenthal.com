<?php
// POST {username, role}: promote or demote a pilot's account type.
// Lead developers only. Roles grantable here: 'developer' and 'normal' —
// lead_developer is assigned via config (LEAD_DEVELOPER_EMAILS), not the API,
// and lead accounts cannot be changed from here.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
$me = require_user();

if (($me['role'] ?? 'normal') !== 'lead_developer') {
    json_error('forbidden', 'Only the lead developer can change account types.', 403);
}

$in = json_input();
$username = trim((string)($in['username'] ?? ''));
$role = (string)($in['role'] ?? '');

if (!in_array($role, ['developer', 'normal'], true)) {
    json_error('bad_role', "Role must be 'developer' or 'normal'.");
}
if ($username === '') {
    json_error('bad_request', 'Give the pilot username to change.');
}

try {
    $db = db();
    $stmt = $db->prepare('SELECT id, username, role FROM users WHERE username = ?');
    $stmt->execute([$username]);
    $target = $stmt->fetch();

    if (!$target) {
        json_error('not_found', 'No pilot with that username.', 404);
    }
    if ($target['role'] === 'lead_developer') {
        json_error('forbidden', 'Lead developer accounts cannot be changed here.', 403);
    }

    $db->prepare('UPDATE users SET role = ? WHERE id = ?')->execute([$role, (int)$target['id']]);
    json_out(['ok' => true, 'username' => $target['username'], 'role' => $role]);
} catch (PDOException $e) {
    error_log('set-role.php db error: ' . $e->getMessage());
    json_error('server_error', 'Account change is unavailable right now.', 500);
}
