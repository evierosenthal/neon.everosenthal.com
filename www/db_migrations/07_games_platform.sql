-- Online lobbies remember which client opened and joined them. The web game
-- links browsers over WebRTC and the iOS app links devices over Game Center,
-- so a web host and an iOS guest can never actually connect: games.php
-- refuses a join whose platform differs from the host's.
--
-- Conditional on the current shape of the database, so this is a no-op on an
-- installation that is already current (including one created fresh from
-- schema.sql) and safe to re-run.

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'games'
      AND column_name = 'host_platform') = 0,
  'ALTER TABLE games ADD COLUMN host_platform ENUM(''web'',''ios'') NOT NULL DEFAULT ''web'' AFTER mode',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'games'
      AND column_name = 'guest_platform') = 0,
  'ALTER TABLE games ADD COLUMN guest_platform ENUM(''web'',''ios'') NULL AFTER host_platform',
  'DO 0'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
