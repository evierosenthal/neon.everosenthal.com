<?php
// GET: top 10 best scores for every difficulty mode, keyed by mode.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

try {
    json_out(['leaderboards' => all_leaderboards()]);
} catch (PDOException $e) {
    error_log('leaderboard.php db error: ' . $e->getMessage());
    json_error('server_error', 'Leaderboard unavailable.', 500);
}
