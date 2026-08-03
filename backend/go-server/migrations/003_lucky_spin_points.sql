-- Migration: Add lucky_points to lucky_spin_daily and rarity to lucky_spin_history
-- Run: psql -d ggs_werewolf -f backend/go-server/migrations/003_lucky_spin_points.sql

ALTER TABLE lucky_spin_daily ADD COLUMN IF NOT EXISTS lucky_points INT NOT NULL DEFAULT 0;

ALTER TABLE lucky_spin_history ADD COLUMN IF NOT EXISTS rarity TEXT NOT NULL DEFAULT 'common';
