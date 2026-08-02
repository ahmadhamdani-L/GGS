    -- Migration 008: User-uploaded avatar support
-- avatar_url stores the path to user-uploaded photo.
-- If NULL, the client falls back to preset avatar (avatar_id 1-12).

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT NULL;

-- Index for fast lookup when serving/validating avatar URLs
CREATE INDEX IF NOT EXISTS idx_profiles_avatar_url ON profiles(avatar_url) WHERE avatar_url IS NOT NULL;

-- Track upload history for moderation / abuse detection
CREATE TABLE IF NOT EXISTS avatar_uploads (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    filename    TEXT NOT NULL,
    file_size   INT  NOT NULL,
    mime_type   TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active   BOOLEAN NOT NULL DEFAULT true,
    moderated   BOOLEAN NOT NULL DEFAULT false,
    rejected    BOOLEAN NOT NULL DEFAULT false,
    reject_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_avatar_uploads_user ON avatar_uploads(user_id, uploaded_at DESC);

-- FCM push notification tokens (one per user, latest device wins)
CREATE TABLE IF NOT EXISTS fcm_tokens (
    user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT NOT NULL,
    platform   TEXT NOT NULL DEFAULT 'android', -- android | ios
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
