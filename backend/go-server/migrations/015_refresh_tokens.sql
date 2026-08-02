-- Migration 015: Move refresh tokens from in-memory to PostgreSQL
-- This ensures tokens persist across server restarts/deploys.
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          TEXT PRIMARY KEY,                -- JWT token ID (jti claim)
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at  TIMESTAMPTZ NOT NULL,
    issued_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked     BOOLEAN NOT NULL DEFAULT false,
    user_agent  TEXT,                            -- optional: track device
    ip_address  TEXT                             -- optional: track origin
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE NOT revoked;
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at) WHERE NOT revoked;

-- Cleanup function: remove expired/revoked tokens older than 14 days
-- Run periodically via db.StartCleanupJobs()
