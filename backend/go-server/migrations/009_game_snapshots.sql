-- Migration 009: Game state snapshots for crash recovery
-- Active game states are serialised to this table on graceful shutdown
-- and restored on the next server startup (up to 2 hours old).
CREATE TABLE IF NOT EXISTS game_snapshots (
    room_id    TEXT PRIMARY KEY,
    state_json TEXT NOT NULL,
    saved_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_game_snapshots_saved ON game_snapshots(saved_at);
