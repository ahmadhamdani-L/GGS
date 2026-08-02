-- Migration 017: Performance indexes + UUID extension safety
-- P2-35: Add missing indexes for common queries
-- P2-36: Ensure UUID extension is available
-- ═══════════════════════════════════════════════════════════

-- Ensure gen_random_uuid() works (PostgreSQL 13+ has it built-in, but just in case)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Daily missions: queried by user_id + expires_at on every home page load
CREATE INDEX IF NOT EXISTS idx_daily_missions_user_expires 
ON daily_missions(user_id, expires_at) WHERE NOT is_claimed;

-- Gift transactions: queried for history by receiver
CREATE INDEX IF NOT EXISTS idx_gift_tx_receiver 
ON gift_transactions(receiver_id, created_at DESC);

-- Profiles: queried for leaderboard by games_won
CREATE INDEX IF NOT EXISTS idx_profiles_games_won 
ON profiles(games_won DESC) WHERE games_played > 0;

-- Refresh tokens: cleanup query
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_cleanup 
ON refresh_tokens(expires_at) WHERE revoked = true;
