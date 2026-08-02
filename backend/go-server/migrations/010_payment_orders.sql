-- Migration 010: Payment orders (Midtrans integration)
CREATE TABLE IF NOT EXISTS payment_orders (
    order_id    TEXT PRIMARY KEY,              -- GGS-{userId8}-{timestamp}
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    package_id  TEXT NOT NULL,                 -- diamond_100, diamond_500, etc.
    amount      INT  NOT NULL,                 -- price in IDR
    status      TEXT NOT NULL DEFAULT 'pending', -- pending|pending_payment|paid|deny|cancel|expire
    paid_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payment_orders_user ON payment_orders(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status) WHERE status = 'pending';
