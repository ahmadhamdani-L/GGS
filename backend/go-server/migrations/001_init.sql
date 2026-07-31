-- GGS Werewolf - PostgreSQL Schema (Go Backend)
-- Run: psql -U postgres -d ggs_werewolf -f migrations/001_init.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── USERS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  password_hash TEXT,
  is_guest BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── PROFILES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player',
  avatar_id INTEGER NOT NULL DEFAULT 1 CHECK (avatar_id BETWEEN 1 AND 12),
  coins BIGINT DEFAULT 100,
  level INTEGER DEFAULT 1,
  xp BIGINT DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── GAME ROOMS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS game_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(6) UNIQUE NOT NULL,
  host_id UUID REFERENCES users(id) NOT NULL,
  status VARCHAR(20) DEFAULT 'waiting' CHECK (status IN ('waiting', 'playing', 'finished')),
  config JSONB NOT NULL DEFAULT '{}',
  max_players INTEGER DEFAULT 8 CHECK (max_players BETWEEN 8 AND 16),
  current_players INTEGER DEFAULT 0,
  room_name TEXT DEFAULT 'Room',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── ROOM PLAYERS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS room_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  slot INTEGER NOT NULL,
  is_ready BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(room_id, user_id),
  UNIQUE(room_id, slot)
);

-- ─── PLAYER STATS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS player_stats (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  games_as_werewolf INTEGER DEFAULT 0,
  games_as_seer INTEGER DEFAULT 0,
  games_as_doctor INTEGER DEFAULT 0,
  games_as_witch INTEGER DEFAULT 0,
  games_as_villager INTEGER DEFAULT 0,
  wolves_found INTEGER DEFAULT 0,
  players_protected INTEGER DEFAULT 0,
  poisons_used INTEGER DEFAULT 0,
  heals_used INTEGER DEFAULT 0,
  total_kills INTEGER DEFAULT 0,
  total_votes_correct INTEGER DEFAULT 0,
  current_win_streak INTEGER DEFAULT 0,
  longest_win_streak INTEGER DEFAULT 0,
  mvp_count INTEGER DEFAULT 0,
  rating INTEGER DEFAULT 1000,
  rank_tier VARCHAR(20) DEFAULT 'bronze',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── MATCH HISTORY ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS match_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  match_id TEXT NOT NULL,
  played_at TIMESTAMPTZ DEFAULT now(),
  duration_sec INTEGER DEFAULT 0,
  total_rounds INTEGER DEFAULT 1,
  role VARCHAR(20) NOT NULL,
  team VARCHAR(10) NOT NULL,
  won BOOLEAN DEFAULT false,
  survived BOOLEAN DEFAULT false,
  xp_earned INTEGER DEFAULT 0,
  coins_earned INTEGER DEFAULT 0,
  player_count INTEGER DEFAULT 8
);

-- ─── LEADERBOARD ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leaderboard (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player',
  avatar_id INTEGER DEFAULT 1,
  level INTEGER DEFAULT 1,
  xp BIGINT DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  rating INTEGER DEFAULT 1000,
  rank_tier VARCHAR(20) DEFAULT 'bronze',
  win_rate REAL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── INDEXES ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_match_history_user ON match_history(user_id, played_at DESC);
CREATE INDEX IF NOT EXISTS idx_match_history_match ON match_history(match_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_rating ON leaderboard(rating DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_xp ON leaderboard(xp DESC);
CREATE INDEX IF NOT EXISTS idx_game_rooms_code ON game_rooms(code);
CREATE INDEX IF NOT EXISTS idx_game_rooms_status ON game_rooms(status);

-- ─── PLAYER ACHIEVEMENTS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS player_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  achievement_id VARCHAR(50) NOT NULL,
  unlocked_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_player_achievements_user ON player_achievements(user_id);

-- ─── SHOP ITEMS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shop_items (
  id VARCHAR(50) PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  emoji VARCHAR(10),
  category VARCHAR(30) NOT NULL,
  price INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── USER PURCHASES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  item_id VARCHAR(50) REFERENCES shop_items(id) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_user_purchases_user ON user_purchases(user_id);

-- ─── DAILY MISSIONS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  mission_type VARCHAR(50) NOT NULL,
  title TEXT NOT NULL,
  target INTEGER NOT NULL DEFAULT 1,
  progress INTEGER NOT NULL DEFAULT 0,
  reward_coins INTEGER NOT NULL DEFAULT 10,
  reward_xp INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  assigned_at DATE DEFAULT CURRENT_DATE,
  UNIQUE(user_id, mission_type, assigned_at)
);

CREATE INDEX IF NOT EXISTS idx_daily_missions_user ON daily_missions(user_id, assigned_at);

-- ─── NOTIFICATIONS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  type VARCHAR(30) NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  icon VARCHAR(10),
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

-- ─── SEED SHOP ITEMS ─────────────────────────────────────
INSERT INTO shop_items (id, name, description, emoji, category, price) VALUES
  ('border_gold', 'Gold Border', 'Border emas untuk avatar', '✨', 'borders', 200),
  ('border_fire', 'Fire Border', 'Border api untuk avatar', '🔥', 'borders', 300),
  ('border_ice', 'Ice Border', 'Border es untuk avatar', '❄️', 'borders', 300),
  ('emote_laugh', 'Emote: Laugh', 'Emote tertawa in-game', '😂', 'emotes', 100),
  ('emote_think', 'Emote: Think', 'Emote berpikir in-game', '🤔', 'emotes', 100),
  ('emote_sus', 'Emote: Sus', 'Emote curiga in-game', '🧐', 'emotes', 150),
  ('theme_blood', 'Blood Moon', 'Tema gelap blood moon', '🌑', 'themes', 500),
  ('theme_forest', 'Enchanted Forest', 'Tema hutan mistis', '🌲', 'themes', 500)
ON CONFLICT (id) DO NOTHING;

-- ─── FRIENDSHIPS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  friend_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id, status);

-- ─── REPORTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  reported_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  reason VARCHAR(50) NOT NULL,
  details TEXT,
  match_id TEXT,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_reported ON reports(reported_id);

-- ─── SEASONS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS seasons (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT false
);

INSERT INTO seasons (name, start_date, end_date, is_active) VALUES
  ('Season 1', '2026-07-01', '2026-09-30', true)
ON CONFLICT DO NOTHING;

-- ─── SEASON HISTORY (player rank per season) ─────────────
CREATE TABLE IF NOT EXISTS season_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  season_id INTEGER REFERENCES seasons(id) NOT NULL,
  final_rating INTEGER NOT NULL DEFAULT 1000,
  final_tier VARCHAR(20) NOT NULL DEFAULT 'bronze',
  games_played INTEGER DEFAULT 0,
  reward_claimed BOOLEAN DEFAULT false,
  UNIQUE(user_id, season_id)
);

-- ─── MATCH EVENTS (game action log) ─────────────────────
CREATE TABLE IF NOT EXISTS match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL,
  round INTEGER NOT NULL DEFAULT 1,
  phase VARCHAR(20) NOT NULL,
  event_type VARCHAR(30) NOT NULL,
  player_id UUID,
  target_id UUID,
  data JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_match_events_match ON match_events(match_id, round);

-- ─── GAME ROUNDS (round summary) ────────────────────────
CREATE TABLE IF NOT EXISTS game_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT NOT NULL,
  round_number INTEGER NOT NULL,
  night_kill UUID,
  day_elimination UUID,
  alive_count INTEGER,
  phase_durations JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_game_rounds_match ON game_rounds(match_id);

-- ─── CHAT LOGS (moderation) ─────────────────────────────
CREATE TABLE IF NOT EXISTS chat_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id TEXT,
  sender_id UUID REFERENCES users(id),
  content TEXT NOT NULL,
  phase VARCHAR(20),
  flagged BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_logs_match ON chat_logs(match_id);
CREATE INDEX IF NOT EXISTS idx_chat_logs_flagged ON chat_logs(flagged) WHERE flagged = true;

-- ─── AUDIT LOGS (admin actions) ──────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id VARCHAR(50),
  action VARCHAR(50) NOT NULL,
  target_user_id UUID,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── EQUIPPED ITEMS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS equipped_items (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  frame_id VARCHAR(50) REFERENCES shop_items(id),
  title_id VARCHAR(50),
  emote_set_id VARCHAR(50) REFERENCES shop_items(id),
  bubble_id VARCHAR(50),
  theme_id VARCHAR(50) REFERENCES shop_items(id),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── SERVER SETTINGS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS server_settings (
  key VARCHAR(50) PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO server_settings (key, value) VALUES
  ('max_rooms', '100'),
  ('max_players_per_room', '16'),
  ('maintenance_message', ''),
  ('min_app_version', '1.0.0')
ON CONFLICT (key) DO NOTHING;

-- ─── FEATURE FLAGS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS feature_flags (
  key VARCHAR(50) PRIMARY KEY,
  enabled BOOLEAN DEFAULT false,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO feature_flags (key, enabled, description) VALUES
  ('maintenance_mode', false, 'Server in maintenance'),
  ('ranked_enabled', true, 'Ranked matchmaking available'),
  ('shop_enabled', true, 'Shop accessible'),
  ('friends_enabled', true, 'Friends system active'),
  ('push_notifications', false, 'Push notifications enabled'),
  ('chat_enabled', true, 'In-game chat active'),
  ('bots_enabled', true, 'Bot fill enabled'),
  ('daily_missions', true, 'Daily missions system')
ON CONFLICT (key) DO NOTHING;

-- ─── PENALTIES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS penalties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('warning', 'mute', 'chat_ban', 'temp_ban', 'perma_ban')),
  reason TEXT NOT NULL,
  issued_by VARCHAR(50) DEFAULT 'system',
  starts_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_penalties_user ON penalties(user_id, is_active);
