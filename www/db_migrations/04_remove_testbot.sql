-- Remove the diagnostic account used to verify the two-player leaderboard fix
-- (its 1-point 2p_super score was showing on the real board). Deleting the
-- user cascades to its scores and reset tokens.
--
-- Idempotent: deleting an already-deleted account is a no-op.

DELETE FROM users WHERE username = 'testbot-claude';
