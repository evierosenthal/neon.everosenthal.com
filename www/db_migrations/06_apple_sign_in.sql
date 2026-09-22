-- Sign in with Apple (iOS app): users.apple_sub is Apple's stable user id for
-- this app (the JWT "sub" claim), unique like google_sub. apple_refresh_token
-- is the token from the one-time authorization-code exchange, kept only so
-- account deletion can revoke Apple's grant as App Store review requires.
--
-- Conditional on the current shape of the database, so this is a no-op on an
-- installation that is already current (including one created fresh from
-- schema.sql) and safe to re-run.

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users'
      AND column_name = 'apple_sub') = 0,
  'ALTER TABLE users ADD COLUMN apple_sub VARCHAR(255) NULL UNIQUE AFTER google_sub',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'users'
      AND column_name = 'apple_refresh_token') = 0,
  'ALTER TABLE users ADD COLUMN apple_refresh_token VARCHAR(1024) NULL AFTER apple_sub',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
