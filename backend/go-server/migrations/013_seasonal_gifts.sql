-- Migration 013: Seasonal/Event Gift Items
-- Add time-limited fields + seed seasonal items

ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ;
ALTER TABLE gift_catalog ADD COLUMN IF NOT EXISTS available_until TIMESTAMPTZ;

-- Valentine's Day gifts
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, is_limited, sort_order, description, available_from, available_until) VALUES
('valentine_heart',   'Valentine Heart',   '💖', 'seasonal', 'gift',  150,  80,   20, 'heart_burst',    'none',   'rare',      true, 200, 'Hati Valentine spesial', '2027-02-01','2027-02-28'),
('valentine_roses',   'Valentine Roses',   '🌹', 'seasonal', 'gift',  500,  300,  80, 'roses_rain',     'room',   'epic',      true, 201, 'Hujan mawar Valentine',  '2027-02-01','2027-02-28'),
('valentine_cupid',   'Cupid Arrow',       '💘', 'seasonal', 'gift',  2000, 1000, 300,'cupid_fly',      'global', 'legendary', true, 202, 'Panah Cupid legendaris', '2027-02-01','2027-02-28')
ON CONFLICT (id) DO NOTHING;

-- Halloween gifts/curses
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, is_limited, sort_order, description, available_from, available_until) VALUES
('halloween_pumpkin', 'Pumpkin',           '🎃', 'seasonal', 'curse', 100,  -30,  10, 'pumpkin_bounce', 'none',   'rare',      true, 210, 'Labu Halloween',         '2027-10-15','2027-11-05'),
('halloween_skull',   'Spooky Skull',      '💀', 'seasonal', 'curse', 500,  -150, 40, 'skull_spin',     'room',   'epic',      true, 211, 'Tengkorak menakutkan!',  '2027-10-15','2027-11-05'),
('halloween_reaper',  'Grim Reaper',       '⚰️', 'seasonal', 'curse', 3000, -500, 200,'reaper_swing',   'global', 'legendary', true, 212, 'Malaikat maut datang!',  '2027-10-15','2027-11-05')
ON CONFLICT (id) DO NOTHING;

-- Christmas gifts
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, is_limited, sort_order, description, available_from, available_until) VALUES
('xmas_tree',         'Christmas Tree',    '🎄', 'seasonal', 'gift',  200,  100,  25, 'tree_glow',      'none',   'rare',      true, 220, 'Pohon Natal bercahaya',  '2027-12-01','2028-01-05'),
('xmas_santa',        'Santa Gift',        '🎅', 'seasonal', 'gift',  800,  400,  100,'santa_fly',      'room',   'epic',      true, 221, 'Hadiah dari Santa!',     '2027-12-01','2028-01-05'),
('xmas_star',         'Star of Bethlehem', '⭐', 'seasonal', 'gift',  5000, 2500, 800,'star_descend',   'global', 'legendary', true, 222, 'Bintang langka Natal',   '2027-12-01','2028-01-05')
ON CONFLICT (id) DO NOTHING;

-- Ramadan gifts
INSERT INTO gift_catalog (id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta, animation_key, broadcast_type, rarity, is_limited, sort_order, description, available_from, available_until) VALUES
('ramadan_crescent',  'Crescent Moon',     '🌙', 'seasonal', 'gift',  150,  70,   18, 'crescent_glow',  'none',   'rare',      true, 230, 'Bulan sabit Ramadan',    '2027-03-01','2027-04-01'),
('ramadan_lantern',   'Ramadan Lantern',   '🏮', 'seasonal', 'gift',  600,  350,  90, 'lantern_float',  'room',   'epic',      true, 231, 'Lentera Ramadan',        '2027-03-01','2027-04-01'),
('ramadan_mosque',    'Golden Mosque',     '🕌', 'seasonal', 'gift',  4000, 2000, 600,'mosque_rise',    'global', 'legendary', true, 232, 'Masjid emas legendaris', '2027-03-01','2027-04-01')
ON CONFLICT (id) DO NOTHING;
