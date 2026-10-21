-- One row per issued password-reset token. Only the SHA-256 hash is stored,
-- never the raw token — same reasoning as refresh_tokens: a database leak
-- should not hand out usable reset links. The raw token only ever exists in
-- the email sent to the user and in the request that confirms the reset.
--
-- A token is single-use (used_at) and short-lived (expires_at); see
-- PasswordResetService for the lifetime (default 30 minutes).
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS password_reset_tokens_user_id_idx
  ON password_reset_tokens (user_id);

-- Token hashes are looked up directly (not scanned), and must be unique so a
-- hash collision can never resolve to the wrong user's token.
CREATE UNIQUE INDEX IF NOT EXISTS password_reset_tokens_token_hash_idx
  ON password_reset_tokens (token_hash);
