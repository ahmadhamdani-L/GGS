-- Daily Missions Table
CREATE TABLE IF NOT EXISTS daily_missions (
    id VARCHAR(100) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    target INT NOT NULL DEFAULT 1,
    progress INT NOT NULL DEFAULT 0,
    xp_reward INT NOT NULL DEFAULT 0,
    coin_reward INT NOT NULL DEFAULT 0,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_claimed BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_daily_missions_user_id ON daily_missions(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_missions_expires_at ON daily_missions(expires_at);
CREATE INDEX IF NOT EXISTS idx_daily_missions_user_active ON daily_missions(user_id, expires_at) WHERE is_claimed = FALSE;
