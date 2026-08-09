<?php
// POST (lead developer only): apply pending migrations immediately and report
// per-file results. Migrations also auto-apply on login (see _bootstrap.php),
// so this button is mostly a way to see the report / force a re-check.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
$me = require_user();
if (($me['role'] ?? 'normal') !== 'lead_developer') {
    json_error('forbidden', 'Only the lead developer can run migrations.', 403);
}

try {
    json_out(['ok' => true, 'results' => apply_all_migrations()]);
} catch (PDOException $e) {
    neon_log('db', 'migration run failed: ' . $e->getMessage());
    json_error('server_error', 'Migration failed: ' . $e->getMessage(), 500);
}
