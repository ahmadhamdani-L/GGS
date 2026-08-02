-- ============================================================
-- GGS Werewolf - Consolidated PostgreSQL Database Schema
-- Generated from migrations 001 through 013
-- Target Database Engine: PostgreSQL 14+ / PostgreSQL 15 (Docker)
-- ============================================================

-- Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── 1. USERS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  password_hash TEXT,
  is_guest BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 2. PASSWORD RESET TOKENS ──────────────────────────────
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '5 minutes'),
  used BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prt_expires_at ON password_reset_tokens (expires_at);

-- ─── 3. FCM TOKENS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fcm_tokens (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 4. AVATAR UPLOADS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS avatar_uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  file_size INT NOT NULL,
  mime_type TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  moderated BOOLEAN NOT NULL DEFAULT false,
  rejected BOOLEAN NOT NULL DEFAULT false,
  reject_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_avatar_uploads_user ON avatar_uploads(user_id, uploaded_at DESC);

-- ─── 5. GUILDS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS guilds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  tag VARCHAR(6) UNIQUE NOT NULL,
  description TEXT DEFAULT '',
  leader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  avatar_url TEXT,
  level INT NOT NULL DEFAULT 1,
  xp BIGINT NOT NULL DEFAULT 0,
  max_members INT NOT NULL DEFAULT 30,
  is_public BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 6. GUILD MEMBERS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS guild_members (
  guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (guild_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_guild_members_user ON guild_members(user_id);

-- ─── 7. GUILD INVITES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS guild_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (guild_id, invitee_id)
);

-- ─── 8. GUILD CHAT ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS guild_chat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES guilds(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guild_chat_guild ON guild_chat(guild_id, created_at DESC);

-- ─── 9. PROFILES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT 'Player',
  avatar_id INTEGER NOT NULL DEFAULT 1 CHECK (avatar_id BETWEEN 1 AND 12),
  coins BIGINT DEFAULT 100,
  level INTEGER DEFAULT 1,
  xp BIGINT DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  games_won INTEGER DEFAULT 0,
  charm INTEGER DEFAULT 300,
  popularity INTEGER DEFAULT 150,
  diamonds BIGINT NOT NULL DEFAULT 0,
  chibi_config JSONB,
  avatar_url TEXT DEFAULT NULL,
  guild_id UUID REFERENCES guilds(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_avatar_url ON profiles(avatar_url) WHERE avatar_url IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_chibi ON profiles USING GIN (chibi_config);

-- ─── 10. PLAYER STATS ──────────────────────────────────────
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
  gifts_sent INT NOT NULL DEFAULT 0,
  gifts_received INT NOT NULL DEFAULT 0,
  curses_sent INT NOT NULL DEFAULT 0,
  legendary_gifts_sent INT NOT NULL DEFAULT 0,
  diamonds_spent BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 11. SHOP ITEMS ────────────────────────────────────────
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

-- Seed Shop Items
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

-- ─── 12. EQUIPPED ITEMS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS equipped_items (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  frame_id VARCHAR(50) REFERENCES shop_items(id),
  title_id VARCHAR(50),
  emote_set_id VARCHAR(50) REFERENCES shop_items(id),
  bubble_id VARCHAR(50),
  theme_id VARCHAR(50) REFERENCES shop_items(id),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 13. GAME ROOMS ────────────────────────────────────────
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

CREATE INDEX IF NOT EXISTS idx_game_rooms_code ON game_rooms(code);
CREATE INDEX IF NOT EXISTS idx_game_rooms_status ON game_rooms(status);

-- ─── 14. ROOM PLAYERS ──────────────────────────────────────
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

-- ─── 15. MATCH HISTORY ─────────────────────────────────────
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

CREATE INDEX IF NOT EXISTS idx_match_history_user ON match_history(user_id, played_at DESC);
CREATE INDEX IF NOT EXISTS idx_match_history_match ON match_history(match_id);

-- ─── 16. MATCH EVENTS ──────────────────────────────────────
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

-- ─── 17. GAME ROUNDS ───────────────────────────────────────
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

-- ─── 18. GAME SNAPSHOTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS game_snapshots (
  room_id TEXT PRIMARY KEY,
  state_json TEXT NOT NULL,
  saved_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_game_snapshots_saved ON game_snapshots(saved_at);

-- ─── 19. GAME ACTION LOG (REPLAY) ──────────────────────────
CREATE TABLE IF NOT EXISTS game_action_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id TEXT NOT NULL,
  round INT NOT NULL DEFAULT 0,
  phase TEXT NOT NULL,
  action_type TEXT NOT NULL,
  actor_id TEXT,
  target_id TEXT,
  data JSONB NOT NULL DEFAULT '{}',
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_action_log_game ON game_action_log(game_id, timestamp ASC);

-- ─── 20. FRIENDSHIPS ───────────────────────────────────────
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

-- ─── 21. REPORTS ───────────────────────────────────────────
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

-- ─── 22. PLAYER REPORTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS player_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  reported_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  game_id TEXT,
  reason VARCHAR(50) NOT NULL CHECK (reason IN ('toxic', 'cheating', 'afk', 'inappropriate_name', 'spam', 'other')),
  description TEXT,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES users(id),
  CONSTRAINT unique_report UNIQUE (reporter_id, reported_id, game_id)
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON player_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_player_reports_reported ON player_reports(reported_id);

-- ─── 23. PLAYER BLOCKS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS player_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON player_blocks(blocker_id);

-- ─── 24. PENALTIES ─────────────────────────────────────────
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

-- ─── 25. CHAT LOGS ─────────────────────────────────────────
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

-- ─── 26. AUDIT LOGS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id VARCHAR(50),
  action VARCHAR(50) NOT NULL,
  target_user_id UUID,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 27. SEASONS ───────────────────────────────────────────
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

-- ─── 28. SEASON HISTORY ────────────────────────────────────
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

-- ─── 29. LEADERBOARD ───────────────────────────────────────
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

CREATE INDEX IF NOT EXISTS idx_leaderboard_rating ON leaderboard(rating DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_xp ON leaderboard(xp DESC);

-- ─── 30. USER PURCHASES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  item_id VARCHAR(50) REFERENCES shop_items(id) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_user_purchases_user ON user_purchases(user_id);

-- ─── 31. PAYMENT ORDERS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
  order_id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  package_id TEXT NOT NULL,
  amount INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_user ON payment_orders(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status) WHERE status = 'pending';

-- ─── 32. DIAMOND BALANCE ───────────────────────────────────
CREATE TABLE IF NOT EXISTS diamond_balance (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL DEFAULT 0 CHECK (amount >= 0),
  total_spent BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 33. DIAMOND TRANSACTIONS ──────────────────────────────
CREATE TABLE IF NOT EXISTS diamond_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  reason TEXT NOT NULL,
  ref_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diamond_tx_user ON diamond_transactions(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_diamond_tx_ref ON diamond_transactions(ref_id) WHERE ref_id IS NOT NULL;

-- ─── 34. GIFT CATALOG ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_catalog (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'standard',
  type TEXT NOT NULL DEFAULT 'gift',
  diamond_price INT NOT NULL CHECK (diamond_price > 0),
  charm_delta INT NOT NULL,
  popularity_delta INT NOT NULL DEFAULT 0,
  animation_key TEXT NOT NULL DEFAULT 'default',
  broadcast_type TEXT NOT NULL DEFAULT 'none',
  rarity TEXT NOT NULL DEFAULT 'common',
  is_limited BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 100,
  description TEXT,
  available_from TIMESTAMPTZ,
  available_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed Standard Gifts
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, sort_order, description) VALUES
('rose',         'Rose',         '🌹', 'standard',  'gift',  20,    5,    1,    'rose_bloom',      'none',   'common',    10,  'Bunga mawar yang indah'),
('bouquet',      'Bouquet',      '💐', 'standard',  'gift',  50,    15,   3,    'bouquet_burst',   'none',   'common',    20,  'Rangkaian bunga'),
('cake',         'Cake',         '🍰', 'standard',  'gift',  100,   30,   6,    'cake_pop',        'none',   'common',    30,  'Sepotong kue manis'),
('birthday_cake','Birthday Cake','🎂', 'standard',  'gift',  150,   50,   10,   'birthday_burst',  'none',   'rare',      40,  'Kue ulang tahun spesial'),
('teddy_bear',   'Teddy Bear',   '🐻', 'standard',  'gift',  200,   70,   15,   'teddy_bounce',    'none',   'rare',      50,  'Boneka beruang lucu'),
('diamond_ring', 'Diamond Ring', '💍', 'premium',   'gift',  500,   200,  40,   'ring_sparkle',    'none',   'epic',      60,  'Cincin berlian mewah'),
('crown',        'Crown',        '👑', 'premium',   'gift',  800,   350,  70,   'crown_glow',      'room',   'epic',      70,  'Mahkota kebesaran'),
('rocket',       'Rocket',       '🚀', 'premium',   'gift',  1000,  500,  100,  'rocket_launch',   'room',   'epic',      80,  'Meluncur ke bintang'),
('castle',       'Castle',       '🏰', 'premium',   'gift',  2000,  500,  150,  'castle_rise',     'room',   'epic',      90,  'Istana megah'),
('rainbow',      'Rainbow',      '🌈', 'premium',   'gift',  1500,  400,  80,   'rainbow_arc',     'room',   'epic',      95,  'Pelangi keberuntungan'),
('unicorn',      'Unicorn',      '🦄', 'legendary', 'gift',  3000,  1000, 300,  'unicorn_gallop',  'room',   'legendary', 100, 'Unicorn ajaib'),
('whale',        'Whale',        '🐳', 'legendary', 'gift',  5000,  2000, 600,  'whale_splash',    'global', 'legendary', 110, 'Paus raksasa'),
('phoenix',      'Phoenix',      '🔥', 'legendary', 'gift',  7000,  2500, 800,  'phoenix_rise',    'global', 'legendary', 120, 'Phoenix yang bangkit'),
('angel',        'Angel',        '👼', 'legendary', 'gift',  8000,  2800, 900,  'angel_descend',   'global', 'legendary', 130, 'Malaikat pelindung'),
('royal_throne', 'Royal Throne', '👑', 'legendary', 'gift',  10000, 3000, 1000, 'throne_legendary','global', 'legendary', 140, 'Tahta kerajaan tertinggi')
ON CONFLICT (id) DO NOTHING;

-- Seed Curses
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, sort_order, description) VALUES
('tomato',    'Tomato',    '🍅', 'standard', 'curse',  20,   -5,   2,  'tomato_throw',   'none',   'common',    10, 'Lempar tomat segar'),
('poop',      'Poop',      '💩', 'standard', 'curse',  30,   -8,   3,  'poop_drop',      'none',   'common',    20, 'Hadiah tak terduga'),
('chicken',   'Chicken',   '🐔', 'standard', 'curse',  50,   -12,  5,  'chicken_run',    'none',   'common',    30, 'Ayam kabur'),
('frog',      'Frog',      '🐸', 'standard', 'curse',  80,   -20,  8,  'frog_hop',       'none',   'common',    40, 'Katak hijau melompat'),
('potato',    'Potato',    '🥔', 'standard', 'curse',  50,   -15,  6,  'potato_bounce',  'none',   'common',    45, 'Kentang terbang'),
('garlic',    'Garlic',    '🧄', 'standard', 'curse',  60,   -18,  7,  'garlic_puff',    'none',   'common',    50, 'Bau bawang putih'),
('ghost',     'Ghost',     '👻', 'premium',  'curse',  300,  -50,  15, 'ghost_haunt',    'none',   'rare',      60, 'Hantu bergentayangan (24 jam)'),
('spider',    'Spider',    '🕷',  'premium',  'curse',  200,  -35,  12, 'spider_crawl',   'none',   'rare',      70, 'Laba-laba mengerikan'),
('zombie',    'Zombie',    '🧟', 'premium',  'curse',  400,  -70,  20, 'zombie_shuffle', 'none',   'rare',      80, 'Zombie gentayangan'),
('bat_swarm', 'Bat Swarm', '🦇', 'premium',  'curse',  500,  -100, 30, 'bat_swarm_fly',  'none',   'epic',      90, 'Kawanan kelelawar'),
('witch_hex', 'Witch Hex', '🧙', 'premium',  'curse',  600,  -120, 35, 'witch_hex_cast', 'room',   'epic',      100,'Sihir penyihir jahat'),
('coffin',    'Coffin',    '🪦', 'premium',  'curse',  700,  -150, 40, 'coffin_open',    'room',   'epic',      110,'Peti mati menakutkan'),
('skull',     'Skull',     '💀', 'legendary','curse',  2000, -300, 100,'skull_explode',  'room',   'legendary', 120,'Tengkorak menakutkan'),
('rain_cloud','Rain Cloud','🌧', 'premium',  'curse',  400,  -80,  25, 'rain_pour',      'none',   'rare',      115,'Hujan lebat'),
('bad_luck',  'Bad Luck',  '⚡', 'legendary','curse',  3000, -500, 150,'lightning_strike','global','legendary', 130,'Petir sial!')
ON CONFLICT (id) DO NOTHING;

-- Seed Seasonal Gifts
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, is_limited, sort_order, description, available_from, available_until) VALUES
('valentine_heart',   'Valentine Heart',   '💖', 'seasonal', 'gift',  150,  80,   20, 'heart_burst',    'none',   'rare',      true, 200, 'Hati Valentine spesial', '2027-02-01','2027-02-28'),
('valentine_roses',   'Valentine Roses',   '🌹', 'seasonal', 'gift',  500,  300,  80, 'roses_rain',     'room',   'epic',      true, 201, 'Hujan mawar Valentine',  '2027-02-01','2027-02-28'),
('valentine_cupid',   'Cupid Arrow',       '💘', 'seasonal', 'gift',  2000, 1000, 300,'cupid_fly',      'global', 'legendary', true, 202, 'Panah Cupid legendaris', '2027-02-01','2027-02-28'),
('halloween_pumpkin', 'Pumpkin',           '🎃', 'seasonal', 'curse', 100,  -30,  10, 'pumpkin_bounce', 'none',   'rare',      true, 210, 'Labu Halloween',         '2027-10-15','2027-11-05'),
('halloween_skull',   'Spooky Skull',      '💀', 'seasonal', 'curse', 500,  -150, 40, 'skull_spin',     'room',   'epic',      true, 211, 'Tengkorak menakutkan!',  '2027-10-15','2027-11-05'),
('halloween_reaper',  'Grim Reaper',       '⚰️', 'seasonal', 'curse', 3000, -500, 200,'reaper_swing',   'global', 'legendary', true, 212, 'Malaikat maut datang!',  '2027-10-15','2027-11-05'),
('xmas_tree',         'Christmas Tree',    '🎄', 'seasonal', 'gift',  200,  100,  25, 'tree_glow',      'none',   'rare',      true, 220, 'Pohon Natal bercahaya',  '2027-12-01','2028-01-05'),
('xmas_santa',        'Santa Gift',        '🎅', 'seasonal', 'gift',  800,  400,  100,'santa_fly',      'room',   'epic',      true, 221, 'Hadiah dari Santa!',     '2027-12-01','2028-01-05'),
('xmas_star',         'Star of Bethlehem', '⭐', 'seasonal', 'gift',  5000, 2500, 800,'star_descend',   'global', 'legendary', true, 222, 'Bintang langka Natal',   '2027-12-01','2028-01-05'),
('ramadan_crescent',  'Crescent Moon',     '🌙', 'seasonal', 'gift',  150,  70,   18, 'crescent_glow',  'none',   'rare',      true, 230, 'Bulan sabit Ramadan',    '2027-03-01','2027-04-01'),
('ramadan_lantern',   'Ramadan Lantern',   '🏮', 'seasonal', 'gift',  600,  350,  90, 'lantern_float',  'room',   'epic',      true, 231, 'Lentera Ramadan',        '2027-03-01','2027-04-01'),
('ramadan_mosque',    'Golden Mosque',     '🕌', 'seasonal', 'gift',  4000, 2000, 600,'mosque_rise',    'global', 'legendary', true, 232, 'Masjid emas legendaris', '2027-03-01','2027-04-01')
ON CONFLICT (id) DO NOTHING;

-- ─── 35. GIFT TRANSACTIONS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key TEXT UNIQUE NOT NULL,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gift_id TEXT NOT NULL REFERENCES gift_catalog(id),
  gift_type TEXT NOT NULL,
  diamond_spent INT NOT NULL,
  charm_delta INT NOT NULL,
  popularity_delta INT NOT NULL,
  message TEXT,
  animation_played BOOLEAN NOT NULL DEFAULT false,
  broadcast_done BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_tx_sender ON gift_transactions(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_tx_receiver ON gift_transactions(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_tx_gift_id ON gift_transactions(gift_id, created_at DESC);

-- ─── 36. CHARM LEDGER ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS charm_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta INT NOT NULL,
  balance BIGINT NOT NULL,
  reason TEXT NOT NULL,
  ref_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_charm_ledger_user ON charm_ledger(user_id, created_at DESC);

-- ─── 37. POPULARITY LEDGER ─────────────────────────────────
CREATE TABLE IF NOT EXISTS popularity_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta INT NOT NULL,
  balance BIGINT NOT NULL,
  reason TEXT NOT NULL,
  ref_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_popularity_ledger_user ON popularity_ledger(user_id, created_at DESC);

-- ─── 38. SOCIAL STATS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS social_stats (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  charm BIGINT NOT NULL DEFAULT 0,
  popularity BIGINT NOT NULL DEFAULT 0,
  gifts_sent INT NOT NULL DEFAULT 0,
  gifts_received INT NOT NULL DEFAULT 0,
  curses_sent INT NOT NULL DEFAULT 0,
  curses_received INT NOT NULL DEFAULT 0,
  diamonds_spent_gifts BIGINT NOT NULL DEFAULT 0,
  legendary_gifts_sent INT NOT NULL DEFAULT 0,
  legendary_gifts_received INT NOT NULL DEFAULT 0,
  total_gift_value_sent BIGINT NOT NULL DEFAULT 0,
  total_gift_value_received BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 39. GIFT COMBO EVENTS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_combo_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_id TEXT NOT NULL REFERENCES gift_catalog(id),
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_ids TEXT[] NOT NULL DEFAULT '{}',
  combo_count INT NOT NULL DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  window_end TIMESTAMPTZ NOT NULL,
  triggered BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_combo_receiver ON gift_combo_events(receiver_id, window_end);
CREATE INDEX IF NOT EXISTS idx_gift_combo_gift ON gift_combo_events(gift_id, window_end);

-- ─── 40. SOCIAL ACTIVITY FEED ──────────────────────────────
CREATE TABLE IF NOT EXISTS social_activity_feed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  receiver_id UUID REFERENCES users(id) ON DELETE SET NULL,
  gift_id TEXT REFERENCES gift_catalog(id),
  sender_name TEXT,
  receiver_name TEXT,
  gift_name TEXT,
  gift_emoji TEXT,
  broadcast_type TEXT NOT NULL DEFAULT 'none',
  message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_created ON social_activity_feed(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_receiver ON social_activity_feed(receiver_id, created_at DESC);

-- ─── 41. GIFT STREAKS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_streaks (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_gift_date DATE,
  streak_bonus_multiplier FLOAT NOT NULL DEFAULT 1.0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 42. GIFT ALBUM ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_album (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gift_id TEXT NOT NULL REFERENCES gift_catalog(id),
  role TEXT NOT NULL,
  first_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  count INT NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, gift_id, role)
);

-- ─── 43. GIFT RATE LIMIT ───────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_rate_limit (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  window_key TEXT NOT NULL,
  count INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, window_key)
);

-- ─── 44. GIFT ABUSE LOG ────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_abuse_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  detail JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 45. GIFT ANALYTICS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_date DATE NOT NULL DEFAULT CURRENT_DATE,
  gift_id TEXT NOT NULL REFERENCES gift_catalog(id),
  gift_type TEXT NOT NULL,
  transaction_count INT NOT NULL DEFAULT 0,
  diamond_revenue BIGINT NOT NULL DEFAULT 0,
  unique_senders INT NOT NULL DEFAULT 0,
  unique_receivers INT NOT NULL DEFAULT 0,
  CONSTRAINT unique_daily_gift_analytics UNIQUE (event_date, gift_id)
);

-- ─── 46. SOCIAL LEADERBOARD ────────────────────────────────
CREATE TABLE IF NOT EXISTS social_leaderboard (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  board_type TEXT NOT NULL,
  period TEXT NOT NULL,
  score BIGINT NOT NULL DEFAULT 0,
  rank INT,
  display_name TEXT,
  avatar_id INT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, board_type, period)
);

CREATE INDEX IF NOT EXISTS idx_social_lb_type_period ON social_leaderboard(board_type, period, score DESC);

-- ─── 47. GIFT WISHLIST ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_wishlist (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gift_id TEXT NOT NULL REFERENCES gift_catalog(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, gift_id)
);

-- ─── 48. DAILY MISSIONS ────────────────────────────────────
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

CREATE INDEX IF NOT EXISTS idx_daily_missions_user_id ON daily_missions(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_missions_expires_at ON daily_missions(expires_at);
CREATE INDEX IF NOT EXISTS idx_daily_missions_user_active ON daily_missions(user_id, expires_at) WHERE is_claimed = FALSE;

-- ─── 49. NOTIFICATIONS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(100) PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

-- ─── 50. PLAYER ACHIEVEMENTS ───────────────────────────────
CREATE TABLE IF NOT EXISTS player_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  achievement_id VARCHAR(50) NOT NULL,
  unlocked_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_player_achievements_user ON player_achievements(user_id);

-- ─── 51. SERVER SETTINGS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS server_settings (
  key VARCHAR(50) PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed Server Settings
INSERT INTO server_settings (key, value) VALUES
  ('max_rooms', '100'),
  ('max_players_per_room', '16'),
  ('maintenance_message', ''),
  ('min_app_version', '1.0.0')
ON CONFLICT (key) DO NOTHING;

-- ─── 52. FEATURE FLAGS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS feature_flags (
  key VARCHAR(50) PRIMARY KEY,
  enabled BOOLEAN DEFAULT false,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed Feature Flags
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

-- End of Consolidated PostgreSQL Migration File
