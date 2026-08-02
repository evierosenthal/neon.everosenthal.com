<?php
// POST {score}: record a logged-in player's score if it beats their best.
// Scores are client-computed — the cap/throttle only deter casual abuse.
define('NEON_API', 1);
require __DIR__ . '/_bootstrap.php';

require_post_with_csrf();
$user = require_user();

$last = (int)($_SESSION['last_score_submit'] ?? 0);
if (time() - $last < SCORE_MIN_INTERVAL_SEC) {
    json_error('rate_limited', 'Scores can only be submitted every few seconds.', 429);
}

$in = json_input();
$score = $in['score'] ?? null;
if (!is_int($score) && !(is_float($score) && floor($score) === $score)) {
    json_error('bad_score', 'Score must be an integer.');
}
$score = (int)$score;
if ($score < 1 || $score > SCORE_MAX) {
    json_error('bad_score', 'Score out of range.');
}

try {
    $db = db();
    $stmt = $db->prepare(
        'UPDATE users SET best_score = ?, best_score_at = NOW() WHERE id = ? AND best_score < ?'
    );
    $stmt->execute([$score, (int)$user['id'], $score]);
    $improved = $stmt->rowCount() > 0;
    $_SESSION['last_score_submit'] = time();

    $best = $improved ? $score : (int)$user['best_score'];
    $stmt = $db->prepare('SELECT COUNT(*) + 1 FROM users WHERE best_score > ?');
    $stmt->execute([$best]);
    $rank = (int)$stmt->fetchColumn();

    json_out([
        'bestScore' => $best,
        'improved' => $improved,
        'rank' => $rank,
        'leaderboard' => leaderboard_rows(),
    ]);
} catch (PDOException $e) {
    error_log('submit-score.php db error: ' . $e->getMessage());
    json_error('server_error', 'Score could not be saved — try again.', 500);
}
