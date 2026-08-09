-- Account roles: normal, developer (all unlockables free), and
-- lead_developer (a developer who can also grant/revoke developer accounts).
--
-- The lead developer is additionally granted automatically at login to the
-- emails listed in config.php's LEAD_DEVELOPER_EMAILS, so the UPDATE below is
-- just a fast-path for accounts that already exist.
--
-- Conditional on the current shape of the database, so this is a no-op on an
-- installation that is already current (including one created fresh from
-- schema.sql) and safe to re-run.

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users'
      AND column_name = 'role') = 0,
  'ALTER TABLE users ADD COLUMN role ENUM(''normal'',''developer'',''lead_developer'') NOT NULL DEFAULT ''normal'' AFTER google_sub',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE users SET role = 'lead_developer' WHERE email = 'eve.esther.rosenthal@gmail.com';
