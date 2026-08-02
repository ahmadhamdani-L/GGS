-- H-04 FIX: Password reset token table for secure two-step reset flow.
-- Token is stored as a bcrypt hash. Each user can only have one active token at a time.
-- TTL is enforced via expires_at; expired or used tokens cannot reset passwords.

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    user_id    UUID        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT        NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    used       BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cleanup index: speed up expired token cleanup
CREATE INDEX IF NOT EXISTS idx_prt_expires_at ON password_reset_tokens (expires_at);

-- Remove expired/used tokens automatically (pg_cron or application-level cleanup)
-- Application should call: DELETE FROM password_reset_tokens WHERE expires_at < NOW() OR used = true;
