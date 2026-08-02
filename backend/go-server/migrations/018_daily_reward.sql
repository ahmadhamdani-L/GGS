-- Migration 018: Daily Login Reward System
-- 7-day cycle with escalating rewards. Resets after day 7.
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS daily_rewards (
    user_id       UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_day   INT NOT NULL DEFAULT 1 CHECK (current_day BETWEEN 1 AND 7),
    last_claimed  DATE,                          -- date of last claim (NULL = never claimed)
    streak_start  DATE NOT NULL DEFAULT CURRENT_DATE,
    total_claims  INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_daily_rewards_last ON daily_rewards(last_claimed);
