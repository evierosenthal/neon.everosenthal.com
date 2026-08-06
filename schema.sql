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
  mode          ENUM('easy','medium','hard','super') NOT NULL,
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

-- Upgrading an existing database instead of creating a fresh one? Run the
-- numbered migrations in db_migrations/ (see db_migrations/README.md).
