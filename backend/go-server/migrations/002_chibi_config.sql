  -- GGS Werewolf - Migration 002: Chibi Config
  -- Add chibi customization to profiles table
  -- Run: psql -U postgres -d ggs_werewolf -f migrations/002_chibi_config.sql

  -- Add chibi_config column to profiles (stores full JSON config)
  ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS chibi_config JSONB DEFAULT '{
    "skinColor": 4294961865,
    "hairColor": 4287269688,
    "eyeColor": 4285227043,
    "shirtColor": 4294309365,
    "pantsColor": 4284185507,
    "hairStyle": 0,
    "eyeStyle": 0,
    "expression": 2,
    "shirtStyle": 0,
    "accessory": 0,
    "accessoryColor": null,
    "showBlush": true,
    "version": 1
  }'::jsonb;

  -- Create index for efficient queries
  CREATE INDEX IF NOT EXISTS idx_profiles_chibi ON profiles USING GIN (chibi_config);

  -- Update function to update timestamp
  CREATE OR REPLACE FUNCTION update_profile_timestamp()
  RETURNS TRIGGER AS $$
  BEGIN
    NEW.updated_at = now();
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  -- Trigger to auto-update timestamp
  DROP TRIGGER IF EXISTS trg_profiles_updated ON profiles;
  CREATE TRIGGER trg_profiles_updated
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_profile_timestamp();

  -- Comment for documentation
  COMMENT ON COLUMN profiles.chibi_config IS 'JSON object containing chibi avatar customization settings';
