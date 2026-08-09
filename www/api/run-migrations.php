<?php
// POST (lead developer only): apply every migration in www/db_migrations/, in
// order. All migrations are idempotent by convention (see the README there),
// so re-running is always safe. Returns a per-file report.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
$me = require_user();
if (($me['role'] ?? 'normal') !== 'lead_developer') {
    json_error('forbidden', 'Only the lead developer can run migrations.', 403);
}

$dir = dirname(__DIR__) . '/db_migrations';
$files = glob($dir . '/*.sql') ?: [];
sort($files);
if (!$files) {
    json_error('not_found', 'No migration files found on the server.', 404);
}

$results = [];
foreach ($files as $file) {
    $name = basename($file);
    $sql = (string)file_get_contents($file);

    // Strip "--" comment lines, then split into statements at semicolons.
    // (Our migrations never contain a semicolon inside a quoted string.)
    $lines = [];
    foreach (explode("\n", $sql) as $line) {
        if (!preg_match('/^\s*--/', $line)) {
            $lines[] = $line;
        }
    }
    $statements = array_values(array_filter(array_map('trim', explode(';', implode("\n", $lines)))));

    try {
        foreach ($statements as $statement) {
            db()->exec($statement);
        }
        $results[$name] = 'ok';
        neon_log('db', "migration applied: $name (" . count($statements) . ' statements)');
    } catch (PDOException $e) {
        $results[$name] = 'FAILED: ' . $e->getMessage();
        neon_log('db', "migration FAILED: $name: " . $e->getMessage());
        json_out(['ok' => false, 'results' => $results], 500);
    }
}

json_out(['ok' => true, 'results' => $results]);
