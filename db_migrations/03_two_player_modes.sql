-- Two-player records are tracked separately from solo: the scores.mode enum
-- gains a 2p_<tier> value for each difficulty tier.
--
-- Conditional on the current shape of the database, so this is a no-op on an
-- installation that is already current (including one created fresh from
-- schema.sql) and safe to re-run.

-- Rows written before this migration on a non-strict server were coerced to a
-- blank mode and are unusable — clear them first so the ALTER can't complain.
DELETE FROM scores WHERE mode = '';

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'scores'
      AND column_name = 'mode' AND column_type LIKE '%2p_easy%') = 0,
  'ALTER TABLE scores MODIFY COLUMN mode ENUM(''easy'',''medium'',''hard'',''super'',''2p_easy'',''2p_medium'',''2p_hard'',''2p_super'') NOT NULL',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
