-- Online two-player games: a host opens a lobby under a game code, invites a
-- friend by username (or the friend types the code in), and the two browsers
-- exchange WebRTC signaling through game_signals before playing peer-to-peer.
--
-- IF NOT EXISTS keeps this a no-op on an installation that is already current
-- (including one created fresh from schema.sql) and safe to re-run.

CREATE TABLE IF NOT EXISTS games (
  code          VARCHAR(12)  NOT NULL PRIMARY KEY,     -- A-Z 0-9, chosen by the host
  host_user_id  INT UNSIGNED NOT NULL,
  guest_user_id INT UNSIGNED NULL,
  mode          ENUM('easy','medium','hard') NOT NULL,
  status        ENUM('open','started','finished') NOT NULL DEFAULT 'open',
  host_seen_at  DATETIME     NOT NULL,                 -- lobby polling heartbeat
  guest_seen_at DATETIME     NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_games_host (host_user_id),
  KEY idx_games_guest (guest_user_id),
  CONSTRAINT fk_games_host FOREIGN KEY (host_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_games_guest FOREIGN KEY (guest_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS game_invites (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code         VARCHAR(12)  NOT NULL,
  from_user_id INT UNSIGNED NOT NULL,
  to_user_id   INT UNSIGNED NOT NULL,
  status       ENUM('pending','accepted','declined') NOT NULL DEFAULT 'pending',
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_invites_to (to_user_id, status),
  KEY idx_invites_code (code),
  CONSTRAINT fk_invites_from FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_invites_to FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS game_signals (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code       VARCHAR(12) NOT NULL,
  from_role  ENUM('host','guest') NOT NULL,
  payload    MEDIUMTEXT  NOT NULL,                     -- JSON: WebRTC offer / answer
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_signals_code (code, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
