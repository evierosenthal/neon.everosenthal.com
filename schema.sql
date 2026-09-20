-- Neon Nebula leaderboard schema. Run once against the neon_nebula database:
--   mysql -u USER -p neon_nebula < schema.sql
-- (or paste into phpMyAdmin's SQL tab).

CREATE TABLE users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(20)  NOT NULL UNIQUE,  -- 3-20 chars [A-Za-z0-9_-]; collation makes it case-insensitive unique
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NULL,             -- NULL for Google-only accounts
  google_sub    VARCHAR(64)  NULL UNIQUE,      -- Apple later: add apple_sub the same way
  role          ENUM('normal','developer','lead_developer') NOT NULL DEFAULT 'normal',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One best score per user per difficulty mode.
CREATE TABLE scores (
  user_id       INT UNSIGNED NOT NULL,
  mode          ENUM('easy','medium','hard','super','2p_easy','2p_medium','2p_hard','2p_super') NOT NULL,
  best_score    INT UNSIGNED NOT NULL DEFAULT 0,
  best_score_at DATETIME     NULL,             -- tiebreak: earlier score wins
  PRIMARY KEY (user_id, mode),
  KEY idx_mode_score (mode, best_score DESC),
  CONSTRAINT fk_scores_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_resets (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  token_hash CHAR(64)     NOT NULL UNIQUE,     -- sha256 of the raw token; raw token only ever in the email link
  expires_at DATETIME     NOT NULL,
  used_at    DATETIME     NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Online two-player lobbies (host opens a code, a friend joins by code or
-- invite; WebRTC signaling is relayed through game_signals).
CREATE TABLE games (
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

CREATE TABLE game_invites (
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

CREATE TABLE game_signals (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code       VARCHAR(12) NOT NULL,
  from_role  ENUM('host','guest') NOT NULL,
  payload    MEDIUMTEXT  NOT NULL,                     -- JSON: WebRTC offer / answer
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_signals_code (code, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Upgrading an existing database instead of creating a fresh one? Run the
-- numbered migrations in www/db_migrations/ (see its README; lead developers can also apply them with the RUN DB MIGRATIONS button in Settings).
