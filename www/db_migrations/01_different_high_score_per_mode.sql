-- Per-mode high scores (git c4aa51f: "Different high score for different modes").
--
-- schema.sql moved best_score / best_score_at off the users table into a new
-- scores table keyed (user_id, mode), so each user keeps one best score per
-- difficulty mode and the leaderboard is per-mode.
--
-- Conditional on the current shape of the database, so this is a no-op on an
-- installation that is already current (including one created fresh from
-- schema.sql) and safe to re-run.

-- ===== scores =====

CREATE TABLE IF NOT EXISTS scores (
  user_id       INT UNSIGNED NOT NULL,
  mode          ENUM('easy','medium','hard','super') NOT NULL,
  best_score    INT UNSIGNED NOT NULL DEFAULT 0,
  best_score_at DATETIME     NULL,             -- tiebreak: earlier score wins
  PRIMARY KEY (user_id, mode),
  KEY idx_mode_score (mode, best_score DESC),
  CONSTRAINT fk_scores_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===== users =====

-- Pre-migration global bests are NOT carried over: they can't be attributed to
-- a difficulty mode. If you would rather keep them, run this first, picking
-- the mode to credit them to:
--
--   INSERT INTO scores (user_id, mode, best_score, best_score_at)
--   SELECT id, 'medium', best_score, best_score_at FROM users WHERE best_score > 0;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users'
      AND column_name = 'best_score') = 1,
  'ALTER TABLE users DROP COLUMN best_score',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users'
      AND column_name = 'best_score_at') = 1,
  'ALTER TABLE users DROP COLUMN best_score_at',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
