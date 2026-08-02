-- ============================================================
-- MIGRATION 007: Social Interaction System
-- Gift, Curse, Charm, Popularity, Activity Feed, Analytics
-- ============================================================

-- ─── DIAMOND BALANCE ────────────────────────────────────────
-- Diamonds are a premium currency, separate from coins.
CREATE TABLE IF NOT EXISTS diamond_balance (
    user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    amount      BIGINT  NOT NULL DEFAULT 0 CHECK (amount >= 0),
    total_spent BIGINT  NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS diamond_transactions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount      BIGINT  NOT NULL,            -- positive = topup, negative = spend
    balance_after BIGINT NOT NULL,
    reason      TEXT NOT NULL,               -- 'gift_rose', 'topup_100', etc.
    ref_id      TEXT,                        -- idempotency key / order ID
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_diamond_tx_user ON diamond_transactions(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_diamond_tx_ref ON diamond_transactions(ref_id) WHERE ref_id IS NOT NULL;

-- ─── GIFT CATALOG ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_catalog (
    id              TEXT PRIMARY KEY,           -- 'rose', 'castle', 'royal_throne'
    name            TEXT NOT NULL,
    emoji           TEXT NOT NULL,
    category        TEXT NOT NULL DEFAULT 'standard',  -- standard|premium|legendary|seasonal|event
    type            TEXT NOT NULL DEFAULT 'gift',       -- gift|curse
    diamond_price   INT  NOT NULL CHECK (diamond_price > 0),
    charm_delta     INT  NOT NULL,              -- +N for gift, -N for curse
    popularity_delta INT NOT NULL DEFAULT 0,   -- sender popularity change
    animation_key   TEXT NOT NULL DEFAULT 'default',
    broadcast_type  TEXT NOT NULL DEFAULT 'none',  -- none|room|global
    rarity          TEXT NOT NULL DEFAULT 'common', -- common|rare|epic|legendary
    is_limited      BOOLEAN NOT NULL DEFAULT false,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    sort_order      INT  NOT NULL DEFAULT 100,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed: Gifts
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

-- Seed: Curses (fun, not toxic)
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

-- ─── GIFT / CURSE TRANSACTIONS ───────────────────────────────
CREATE TABLE IF NOT EXISTS gift_transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key TEXT UNIQUE NOT NULL,          -- prevent replay/double send
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gift_id         TEXT NOT NULL REFERENCES gift_catalog(id),
    gift_type       TEXT NOT NULL,                 -- gift|curse
    diamond_spent   INT  NOT NULL,
    charm_delta     INT  NOT NULL,
    popularity_delta INT NOT NULL,
    message         TEXT,                          -- optional 50-char message
    animation_played BOOLEAN NOT NULL DEFAULT false,
    broadcast_done  BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_gift_tx_sender   ON gift_transactions(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_tx_receiver ON gift_transactions(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_tx_gift_id  ON gift_transactions(gift_id, created_at DESC);

-- ─── CHARM LEDGER ────────────────────────────────────────────
-- Full audit trail of every charm change
CREATE TABLE IF NOT EXISTS charm_ledger (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta       INT  NOT NULL,
    balance     BIGINT NOT NULL,
    reason      TEXT NOT NULL,             -- 'gift_rose', 'curse_tomato', 'frame_equipped', etc.
    ref_id      UUID,                      -- gift_transaction.id if applicable
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_charm_ledger_user ON charm_ledger(user_id, created_at DESC);

-- ─── POPULARITY LEDGER ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS popularity_ledger (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta       INT  NOT NULL,
    balance     BIGINT NOT NULL,
    reason      TEXT NOT NULL,
    ref_id      UUID,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_popularity_ledger_user ON popularity_ledger(user_id, created_at DESC);

-- ─── SOCIAL STATS (denormalized for performance) ─────────────
-- Updated atomically alongside ledger entries
CREATE TABLE IF NOT EXISTS social_stats (
    user_id             UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    charm               BIGINT NOT NULL DEFAULT 0,
    popularity          BIGINT NOT NULL DEFAULT 0,
    gifts_sent          INT    NOT NULL DEFAULT 0,
    gifts_received      INT    NOT NULL DEFAULT 0,
    curses_sent         INT    NOT NULL DEFAULT 0,
    curses_received     INT    NOT NULL DEFAULT 0,
    diamonds_spent_gifts BIGINT NOT NULL DEFAULT 0,
    legendary_gifts_sent INT   NOT NULL DEFAULT 0,
    legendary_gifts_received INT NOT NULL DEFAULT 0,
    total_gift_value_sent    BIGINT NOT NULL DEFAULT 0,
    total_gift_value_received BIGINT NOT NULL DEFAULT 0,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── GIFT COMBO TRACKER ──────────────────────────────────────
-- Tracks when multiple senders send the same gift within 5 minutes
CREATE TABLE IF NOT EXISTS gift_combo_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gift_id     TEXT NOT NULL REFERENCES gift_catalog(id),
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_ids  TEXT[] NOT NULL DEFAULT '{}',  -- array of sender UUIDs
    combo_count INT  NOT NULL DEFAULT 1,
    window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    window_end   TIMESTAMPTZ NOT NULL,         -- window_start + 5 minutes
    triggered   BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_gift_combo_receiver ON gift_combo_events(receiver_id, window_end);
CREATE INDEX IF NOT EXISTS idx_gift_combo_gift     ON gift_combo_events(gift_id, window_end);

-- ─── ACTIVITY FEED ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS social_activity_feed (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type      TEXT NOT NULL,         -- 'gift_sent', 'curse_sent', 'legendary_gift', 'combo'
    sender_id       UUID REFERENCES users(id) ON DELETE SET NULL,
    receiver_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    gift_id         TEXT REFERENCES gift_catalog(id),
    sender_name     TEXT,
    receiver_name   TEXT,
    gift_name       TEXT,
    gift_emoji      TEXT,
    broadcast_type  TEXT NOT NULL DEFAULT 'none',  -- none|room|global
    message         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_feed_created ON social_activity_feed(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_receiver ON social_activity_feed(receiver_id, created_at DESC);
-- TTL: auto-delete feed older than 30 days (run as cron or pg_cron)

-- ─── GIFT STREAK ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_streaks (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_streak  INT  NOT NULL DEFAULT 0,
    longest_streak  INT  NOT NULL DEFAULT 0,
    last_gift_date  DATE,
    streak_bonus_multiplier FLOAT NOT NULL DEFAULT 1.0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── GIFT ALBUM ──────────────────────────────────────────────
-- Tracks which gifts a player has ever sent/received (for collection achievement)
CREATE TABLE IF NOT EXISTS gift_album (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gift_id     TEXT NOT NULL REFERENCES gift_catalog(id),
    role        TEXT NOT NULL,   -- 'sender' | 'receiver'
    first_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    count       INT NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, gift_id, role)
);

-- ─── ANTI-ABUSE: RATE LIMIT LOG ──────────────────────────────
CREATE TABLE IF NOT EXISTS gift_rate_limit (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    window_key  TEXT NOT NULL,   -- 'YYYY-MM-DD-HH' + user_id for hourly window
    count       INT  NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, window_key)
);

-- ─── ANTI-ABUSE: SUSPICIOUS PATTERN LOG ─────────────────────
CREATE TABLE IF NOT EXISTS gift_abuse_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    detail      JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── ANALYTICS: GIFT EVENTS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_analytics (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    gift_id         TEXT NOT NULL REFERENCES gift_catalog(id),
    gift_type       TEXT NOT NULL,
    transaction_count INT NOT NULL DEFAULT 0,
    diamond_revenue BIGINT NOT NULL DEFAULT 0,
    unique_senders  INT NOT NULL DEFAULT 0,
    unique_receivers INT NOT NULL DEFAULT 0,
    PRIMARY KEY (event_date, gift_id)
) WITHOUT OIDS;
-- Upsert on conflict to accumulate daily stats

-- ─── SOCIAL LEADERBOARD CACHE ────────────────────────────────
CREATE TABLE IF NOT EXISTS social_leaderboard (
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    board_type      TEXT NOT NULL,   -- 'charm'|'popularity'|'gift_sent'|'gift_received'|'legendary_sent'|'curse_sent'
    period          TEXT NOT NULL,   -- 'weekly'|'monthly'|'season'|'alltime'
    score           BIGINT NOT NULL DEFAULT 0,
    rank            INT,
    display_name    TEXT,
    avatar_id       INT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, board_type, period)
);
CREATE INDEX IF NOT EXISTS idx_social_lb_type_period ON social_leaderboard(board_type, period, score DESC);

-- ─── WISHLIST ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_wishlist (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gift_id     TEXT NOT NULL REFERENCES gift_catalog(id),
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, gift_id)
);

-- Add charm + popularity + diamonds to profiles if not already present
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS charm      BIGINT NOT NULL DEFAULT 300;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS popularity BIGINT NOT NULL DEFAULT 150;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diamonds   BIGINT NOT NULL DEFAULT 0;

-- Add gift achievement counters to player_stats
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS gifts_sent          INT NOT NULL DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS gifts_received      INT NOT NULL DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS curses_sent         INT NOT NULL DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS legendary_gifts_sent INT NOT NULL DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS diamonds_spent      BIGINT NOT NULL DEFAULT 0;
