-- Migration 016: Prevent duplicate match history records
-- P1-16 FIX: If server crashes mid-game-end and replays on reconnect,
-- the UNIQUE constraint prevents double-recording stats.
-- ═══════════════════════════════════════════════════════════

CREATE UNIQUE INDEX IF NOT EXISTS idx_match_history_user_match 
ON match_history(user_id, match_id);
