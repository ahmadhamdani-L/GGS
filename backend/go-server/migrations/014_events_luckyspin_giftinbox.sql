-- GGS Werewolf - Migration 014: Events, Lucky Spin, Gift Inbox
-- Run: psql -U postgres -d ggs_werewolf -f migrations/014_events_luckyspin_giftinbox.sql

-- ═══════════════════════════════════════════════════════════
-- EVENTS SYSTEM
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    event_type VARCHAR(30) NOT NULL DEFAULT 'special', -- special, seasonal, weekly
    banner_emoji VARCHAR(10) DEFAULT '🎃',
    rewards JSONB DEFAULT '[]'::jsonb,  -- [{type: "coins", amount: 500}, {type: "diamonds", amount: 50}]
    requirements JSONB DEFAULT '{}',    -- {games_played: 5, wins: 2}
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    progress JSONB DEFAULT '{}',  -- {games_played: 3, wins: 1}
    claimed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active, start_at, end_at);
CREATE INDEX IF NOT EXISTS idx_event_progress_user ON event_progress(user_id);

-- ═══════════════════════════════════════════════════════════
-- LUCKY SPIN SYSTEM
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lucky_spin_prizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    prize_type VARCHAR(30) NOT NULL, -- coins, diamonds, xp, item, empty
    amount INT DEFAULT 0,
    item_id VARCHAR(50),             -- for item prizes
    weight INT NOT NULL DEFAULT 10,  -- higher = more common
    rarity VARCHAR(20) DEFAULT 'common', -- common, rare, epic, legendary
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS lucky_spin_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prize_id UUID REFERENCES lucky_spin_prizes(id),
    prize_name VARCHAR(100),
    prize_type VARCHAR(30),
    amount INT DEFAULT 0,
    spun_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lucky_spin_daily (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    free_spins_remaining INT DEFAULT 1,
    last_reset_at TIMESTAMPTZ DEFAULT now(),
    total_spins INT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_spin_history_user ON lucky_spin_history(user_id, spun_at DESC);

-- Default prizes
INSERT INTO lucky_spin_prizes (name, prize_type, amount, weight, rarity) VALUES
    ('100 Coins', 'coins', 100, 30, 'common'),
    ('250 Coins', 'coins', 250, 20, 'common'),
    ('500 Coins', 'coins', 500, 12, 'rare'),
    ('1000 Coins', 'coins', 1000, 5, 'rare'),
    ('10 Diamonds', 'diamonds', 10, 10, 'common'),
    ('50 Diamonds', 'diamonds', 50, 5, 'rare'),
    ('100 Diamonds', 'diamonds', 100, 2, 'epic'),
    ('500 Diamonds', 'diamonds', 500, 1, 'legendary'),
    ('50 XP', 'xp', 50, 25, 'common'),
    ('200 XP', 'xp', 200, 8, 'rare'),
    ('Tidak Beruntung', 'empty', 0, 15, 'common')
ON CONFLICT DO NOTHING;

-- Default event
INSERT INTO events (name, description, event_type, banner_emoji, rewards, requirements, start_at, end_at) VALUES
    ('Werewolf Night Festival', 'Mainkan 5 game dan menangkan 2 untuk mendapatkan hadiah spesial!', 'special', '🎃',
     '[{"type": "coins", "amount": 1000}, {"type": "diamonds", "amount": 100}, {"type": "xp", "amount": 500}]'::jsonb,
     '{"games_played": 5, "wins": 2}'::jsonb,
     now(), now() + INTERVAL '7 days')
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════
-- GIFT INBOX (received gifts awaiting claim)
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS gift_inbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
    sender_name VARCHAR(50),
    gift_type VARCHAR(30) NOT NULL, -- coins, diamonds, xp, item
    amount INT DEFAULT 0,
    item_id VARCHAR(50),
    message VARCHAR(200),
    claimed BOOLEAN DEFAULT false,
    claimed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_inbox_recipient ON gift_inbox(recipient_id, claimed, expires_at);

-- ═══════════════════════════════════════════════════════════
-- GLOBAL CHAT
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS global_chat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(50),
    message VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_global_chat_recent ON global_chat(created_at DESC);

-- Keep only last 500 messages (cleanup function)
CREATE OR REPLACE FUNCTION cleanup_global_chat() RETURNS void AS $$
BEGIN
    DELETE FROM global_chat WHERE id NOT IN (
        SELECT id FROM global_chat ORDER BY created_at DESC LIMIT 500
    );
END;
$$ LANGUAGE plpgsql;
