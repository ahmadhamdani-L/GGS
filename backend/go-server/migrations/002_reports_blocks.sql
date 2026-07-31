-- GGS Werewolf - Reports & Blocks Schema
-- Run: psql -U postgres -d ggs_werewolf -f migrations/002_reports_blocks.sql

-- ─── PLAYER REPORTS ──────────────────────────────────────
-- Stores player reports for toxic behavior, cheating, etc.
CREATE TABLE IF NOT EXISTS player_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  reported_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  game_id TEXT, -- Optional: game where incident occurred
  reason VARCHAR(50) NOT NULL CHECK (reason IN ('toxic', 'cheating', 'afk', 'inappropriate_name', 'spam', 'other')),
  description TEXT, -- Optional details (max 500 chars)
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES users(id),
  -- Prevent duplicate reports from same reporter for same player in same game
  CONSTRAINT unique_report UNIQUE (reporter_id, reported_id, game_id)
);

-- Index for admin review queries
CREATE INDEX IF NOT EXISTS idx_reports_status ON player_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported ON player_reports(reported_id);

-- ─── PLAYER BLOCKS ───────────────────────────────────────
-- Users can block other players to avoid matching with them
CREATE TABLE IF NOT EXISTS player_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  -- Prevent duplicate blocks
  CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id),
  -- Can't block yourself
  CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

-- Index for quick block list lookup
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON player_blocks(blocker_id);
