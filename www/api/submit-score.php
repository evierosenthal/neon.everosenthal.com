<?php
// POST {score, mode}: record a logged-in player's score for that difficulty
// mode if it beats their best. Scores are client-computed — the cap/throttle
// only deter casual abuse.
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
$mode = (string)($in['mode'] ?? '');
if (!is_int($score) && !(is_float($score) && floor($score) === $score)) {
    json_error('bad_score', 'Score must be an integer.');
}
$score = (int)$score;
if ($score < 1 || $score > SCORE_MAX) {
    json_error('bad_score', 'Score out of range.');
}
if (!in_array($mode, GAME_MODES, true)) {
    json_error('bad_mode', 'Unknown game mode.');
}

try {
    $db = db();
    $stmt = $db->prepare('SELECT best_score FROM scores WHERE user_id = ? AND mode = ?');
    $stmt->execute([(int)$user['id'], $mode]);
    $prev = (int)$stmt->fetchColumn();

    $improved = $score > $prev;
    if ($improved) {
        $db->prepare(
            'INSERT INTO scores (user_id, mode, best_score, best_score_at) VALUES (?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE best_score = VALUES(best_score), best_score_at = NOW()'
        )->execute([(int)$user['id'], $mode, $score]);
    }
    $_SESSION['last_score_submit'] = time();

    $best = max($prev, $score);
    $stmt = $db->prepare('SELECT COUNT(*) + 1 FROM scores WHERE mode = ? AND best_score > ?');
    $stmt->execute([$mode, $best]);
    $rank = (int)$stmt->fetchColumn();

    json_out([
        'mode' => $mode,
        'bestScore' => $best,
        'improved' => $improved,
        'rank' => $rank,
        'leaderboard' => leaderboard_rows($mode),
    ]);
} catch (PDOException $e) {
    error_log('submit-score.php db error: ' . $e->getMessage());
    json_error('server_error', 'Score could not be saved — try again.', 500);
}
