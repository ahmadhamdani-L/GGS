-- Migration 012: Game Replay / Action Log
-- Stores every game action for replay viewer
CREATE TABLE IF NOT EXISTS game_action_log (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id    TEXT NOT NULL,                  -- matches GameState.ID
    round      INT NOT NULL DEFAULT 0,
    phase      TEXT NOT NULL,
    action_type TEXT NOT NULL,                 -- night_action, vote, chat, testament, phase_change, death, win
    actor_id   TEXT,                           -- player who performed action (null for system events)
    target_id  TEXT,                           -- target of action (if applicable)
    data       JSONB NOT NULL DEFAULT '{}',    -- extra data (role, message, etc.)
    timestamp  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_action_log_game ON game_action_log(game_id, timestamp ASC);

-- Keep replay data for 30 days (cleanup job will handle)
