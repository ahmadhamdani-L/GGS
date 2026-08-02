-- ============================================================
-- GGS Werewolf - Consolidated MySQL Database Schema
-- Generated from PostgreSQL migrations 001 through 013
-- Target Database Engine: MySQL 8.0+ / MariaDB 10.5+
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET TIME_ZONE = "+00:00";

-- CREATE DATABASE IF NOT EXISTS `ggs_werewolf` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE `ggs_werewolf`;

-- ─── 1. USERS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `email` VARCHAR(255) UNIQUE NULL,
  `password_hash` VARCHAR(255) NULL,
  `is_guest` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 2. PASSWORD RESET TOKENS ──────────────────────────────
CREATE TABLE IF NOT EXISTS `password_reset_tokens` (
  `user_id` VARCHAR(36) NOT NULL UNIQUE,
  `token_hash` TEXT NOT NULL,
  `expires_at` TIMESTAMP NOT NULL,
  `used` BOOLEAN NOT NULL DEFAULT FALSE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_prt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_prt_expires_at` ON `password_reset_tokens` (`expires_at`);

-- ─── 3. FCM TOKENS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `fcm_tokens` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `token` TEXT NOT NULL,
  `platform` VARCHAR(20) NOT NULL DEFAULT 'android',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_fcm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 4. AVATAR UPLOADS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `avatar_uploads` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `filename` VARCHAR(255) NOT NULL,
  `file_size` INT NOT NULL,
  `mime_type` VARCHAR(100) NOT NULL,
  `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `moderated` BOOLEAN NOT NULL DEFAULT FALSE,
  `rejected` BOOLEAN NOT NULL DEFAULT FALSE,
  `reject_reason` TEXT NULL,
  CONSTRAINT `fk_avatar_uploads_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_avatar_uploads_user` ON `avatar_uploads` (`user_id`, `uploaded_at` DESC);

-- ─── 5. GUILDS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `guilds` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `name` VARCHAR(255) UNIQUE NOT NULL,
  `tag` VARCHAR(6) UNIQUE NOT NULL,
  `description` TEXT DEFAULT NULL,
  `leader_id` VARCHAR(36) NOT NULL,
  `avatar_url` TEXT DEFAULT NULL,
  `level` INT NOT NULL DEFAULT 1,
  `xp` BIGINT NOT NULL DEFAULT 0,
  `max_members` INT NOT NULL DEFAULT 30,
  `is_public` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_guilds_leader` FOREIGN KEY (`leader_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 6. GUILD MEMBERS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `guild_members` (
  `guild_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `role` VARCHAR(20) NOT NULL DEFAULT 'member',
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guild_id`, `user_id`),
  CONSTRAINT `fk_gm_guild` FOREIGN KEY (`guild_id`) REFERENCES `guilds` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_guild_members_user` ON `guild_members` (`user_id`);

-- ─── 7. GUILD INVITES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `guild_invites` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `guild_id` VARCHAR(36) NOT NULL,
  `inviter_id` VARCHAR(36) NOT NULL,
  `invitee_id` VARCHAR(36) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_guild_invitee` (`guild_id`, `invitee_id`),
  CONSTRAINT `fk_gi_guild` FOREIGN KEY (`guild_id`) REFERENCES `guilds` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gi_inviter` FOREIGN KEY (`inviter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gi_invitee` FOREIGN KEY (`invitee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 8. GUILD CHAT ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `guild_chat` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `guild_id` VARCHAR(36) NOT NULL,
  `sender_id` VARCHAR(36) NOT NULL,
  `sender_name` VARCHAR(255) NOT NULL,
  `content` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_gc_guild` FOREIGN KEY (`guild_id`) REFERENCES `guilds` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gc_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_guild_chat_guild` ON `guild_chat` (`guild_id`, `created_at` DESC);

-- ─── 9. PROFILES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `profiles` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `display_name` VARCHAR(255) NOT NULL DEFAULT 'Player',
  `avatar_id` INT NOT NULL DEFAULT 1,
  `coins` BIGINT DEFAULT 100,
  `level` INT DEFAULT 1,
  `xp` BIGINT DEFAULT 0,
  `games_played` INT DEFAULT 0,
  `games_won` INT DEFAULT 0,
  `charm` INT DEFAULT 300,
  `popularity` INT DEFAULT 150,
  `diamonds` BIGINT NOT NULL DEFAULT 0,
  `chibi_config` JSON NULL,
  `avatar_url` TEXT DEFAULT NULL,
  `guild_id` VARCHAR(36) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_profiles_guild` FOREIGN KEY (`guild_id`) REFERENCES `guilds` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_avatar_id` CHECK (`avatar_id` BETWEEN 1 AND 12)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_profiles_avatar_url` ON `profiles` (`avatar_url`(255));

-- ─── 10. PLAYER STATS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `player_stats` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `games_played` INT DEFAULT 0,
  `games_won` INT DEFAULT 0,
  `games_as_werewolf` INT DEFAULT 0,
  `games_as_seer` INT DEFAULT 0,
  `games_as_doctor` INT DEFAULT 0,
  `games_as_witch` INT DEFAULT 0,
  `games_as_villager` INT DEFAULT 0,
  `wolves_found` INT DEFAULT 0,
  `players_protected` INT DEFAULT 0,
  `poisons_used` INT DEFAULT 0,
  `heals_used` INT DEFAULT 0,
  `total_kills` INT DEFAULT 0,
  `total_votes_correct` INT DEFAULT 0,
  `current_win_streak` INT DEFAULT 0,
  `longest_win_streak` INT DEFAULT 0,
  `mvp_count` INT DEFAULT 0,
  `rating` INT DEFAULT 1000,
  `rank_tier` VARCHAR(20) DEFAULT 'bronze',
  `gifts_sent` INT NOT NULL DEFAULT 0,
  `gifts_received` INT NOT NULL DEFAULT 0,
  `curses_sent` INT NOT NULL DEFAULT 0,
  `legendary_gifts_sent` INT NOT NULL DEFAULT 0,
  `diamonds_spent` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_player_stats_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 11. SHOP ITEMS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `shop_items` (
  `id` VARCHAR(50) PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `emoji` VARCHAR(10) DEFAULT NULL,
  `category` VARCHAR(30) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `is_active` BOOLEAN DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Shop Items
INSERT IGNORE INTO `shop_items` (`id`, `name`, `description`, `emoji`, `category`, `price`) VALUES
  ('border_gold', 'Gold Border', 'Border emas untuk avatar', '✨', 'borders', 200),
  ('border_fire', 'Fire Border', 'Border api untuk avatar', '🔥', 'borders', 300),
  ('border_ice', 'Ice Border', 'Border es untuk avatar', '❄️', 'borders', 300),
  ('emote_laugh', 'Emote: Laugh', 'Emote tertawa in-game', '😂', 'emotes', 100),
  ('emote_think', 'Emote: Think', 'Emote berpikir in-game', '🤔', 'emotes', 100),
  ('emote_sus', 'Emote: Sus', 'Emote curiga in-game', '🧐', 'emotes', 150),
  ('theme_blood', 'Blood Moon', 'Tema gelap blood moon', '🌑', 'themes', 500),
  ('theme_forest', 'Enchanted Forest', 'Tema hutan mistis', '🌲', 'themes', 500);

-- ─── 12. EQUIPPED ITEMS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `equipped_items` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `frame_id` VARCHAR(50) DEFAULT NULL,
  `title_id` VARCHAR(50) DEFAULT NULL,
  `emote_set_id` VARCHAR(50) DEFAULT NULL,
  `bubble_id` VARCHAR(50) DEFAULT NULL,
  `theme_id` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_equipped_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_equipped_frame` FOREIGN KEY (`frame_id`) REFERENCES `shop_items` (`id`),
  CONSTRAINT `fk_equipped_emote` FOREIGN KEY (`emote_set_id`) REFERENCES `shop_items` (`id`),
  CONSTRAINT `fk_equipped_theme` FOREIGN KEY (`theme_id`) REFERENCES `shop_items` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 13. GAME ROOMS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `game_rooms` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `code` VARCHAR(6) UNIQUE NOT NULL,
  `host_id` VARCHAR(36) NOT NULL,
  `status` VARCHAR(20) DEFAULT 'waiting',
  `config` JSON NOT NULL,
  `max_players` INT DEFAULT 8,
  `current_players` INT DEFAULT 0,
  `room_name` VARCHAR(255) DEFAULT 'Room',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_game_rooms_host` FOREIGN KEY (`host_id`) REFERENCES `users` (`id`),
  CONSTRAINT `chk_gr_status` CHECK (`status` IN ('waiting', 'playing', 'finished')),
  CONSTRAINT `chk_gr_max_players` CHECK (`max_players` BETWEEN 8 AND 16)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_game_rooms_code` ON `game_rooms` (`code`);
CREATE INDEX `idx_game_rooms_status` ON `game_rooms` (`status`);

-- ─── 14. ROOM PLAYERS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `room_players` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `room_id` VARCHAR(36) NOT NULL,
  `user_id` VARCHAR(36) NOT NULL,
  `slot` INT NOT NULL,
  `is_ready` BOOLEAN DEFAULT FALSE,
  `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_room_user` (`room_id`, `user_id`),
  UNIQUE KEY `uk_room_slot` (`room_id`, `slot`),
  CONSTRAINT `fk_rp_room` FOREIGN KEY (`room_id`) REFERENCES `game_rooms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rp_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 15. MATCH HISTORY ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `match_history` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `match_id` VARCHAR(255) NOT NULL,
  `played_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `duration_sec` INT DEFAULT 0,
  `total_rounds` INT DEFAULT 1,
  `role` VARCHAR(20) NOT NULL,
  `team` VARCHAR(10) NOT NULL,
  `won` BOOLEAN DEFAULT FALSE,
  `survived` BOOLEAN DEFAULT FALSE,
  `xp_earned` INT DEFAULT 0,
  `coins_earned` INT DEFAULT 0,
  `player_count` INT DEFAULT 8,
  CONSTRAINT `fk_match_history_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_match_history_user` ON `match_history` (`user_id`, `played_at` DESC);
CREATE INDEX `idx_match_history_match` ON `match_history` (`match_id`);

-- ─── 16. MATCH EVENTS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `match_events` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `match_id` VARCHAR(255) NOT NULL,
  `round` INT NOT NULL DEFAULT 1,
  `phase` VARCHAR(20) NOT NULL,
  `event_type` VARCHAR(30) NOT NULL,
  `player_id` VARCHAR(36) DEFAULT NULL,
  `target_id` VARCHAR(36) DEFAULT NULL,
  `data` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_match_events_match` ON `match_events` (`match_id`, `round`);

-- ─── 17. GAME ROUNDS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `game_rounds` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `match_id` VARCHAR(255) NOT NULL,
  `round_number` INT NOT NULL,
  `night_kill` VARCHAR(36) DEFAULT NULL,
  `day_elimination` VARCHAR(36) DEFAULT NULL,
  `alive_count` INT DEFAULT NULL,
  `phase_durations` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_game_rounds_match` ON `game_rounds` (`match_id`);

-- ─── 18. GAME SNAPSHOTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `game_snapshots` (
  `room_id` VARCHAR(255) PRIMARY KEY,
  `state_json` LONGTEXT NOT NULL,
  `saved_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_game_snapshots_saved` ON `game_snapshots` (`saved_at`);

-- ─── 19. GAME ACTION LOG (REPLAY) ──────────────────────────
CREATE TABLE IF NOT EXISTS `game_action_log` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `game_id` VARCHAR(255) NOT NULL,
  `round` INT NOT NULL DEFAULT 0,
  `phase` VARCHAR(50) NOT NULL,
  `action_type` VARCHAR(50) NOT NULL,
  `actor_id` VARCHAR(36) DEFAULT NULL,
  `target_id` VARCHAR(36) DEFAULT NULL,
  `data` JSON NOT NULL,
  `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_action_log_game` ON `game_action_log` (`game_id`, `timestamp` ASC);

-- ─── 20. FRIENDSHIPS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `friendships` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `friend_id` VARCHAR(36) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_friendship` (`user_id`, `friend_id`),
  CONSTRAINT `fk_friendships_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_friendships_friend` FOREIGN KEY (`friend_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_friendship_status` CHECK (`status` IN ('pending', 'accepted', 'blocked'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_friendships_user` ON `friendships` (`user_id`, `status`);
CREATE INDEX `idx_friendships_friend` ON `friendships` (`friend_id`, `status`);

-- ─── 21. REPORTS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `reports` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `reporter_id` VARCHAR(36) NOT NULL,
  `reported_id` VARCHAR(36) NOT NULL,
  `reason` VARCHAR(50) NOT NULL,
  `details` TEXT DEFAULT NULL,
  `match_id` VARCHAR(255) DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT 'pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_reports_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reports_reported` FOREIGN KEY (`reported_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_reports_status` CHECK (`status` IN ('pending', 'reviewed', 'actioned', 'dismissed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_reports_reported` ON `reports` (`reported_id`);

-- ─── 22. PLAYER REPORTS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `player_reports` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `reporter_id` VARCHAR(36) NOT NULL,
  `reported_id` VARCHAR(36) NOT NULL,
  `game_id` VARCHAR(255) DEFAULT NULL,
  `reason` VARCHAR(50) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT 'pending',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` TIMESTAMP NULL DEFAULT NULL,
  `reviewed_by` VARCHAR(36) DEFAULT NULL,
  CONSTRAINT `unique_report` UNIQUE (`reporter_id`, `reported_id`, `game_id`),
  CONSTRAINT `fk_pr_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pr_reported` FOREIGN KEY (`reported_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pr_reviewed_by` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`),
  CONSTRAINT `chk_pr_reason` CHECK (`reason` IN ('toxic', 'cheating', 'afk', 'inappropriate_name', 'spam', 'other')),
  CONSTRAINT `chk_pr_status` CHECK (`status` IN ('pending', 'reviewed', 'resolved', 'dismissed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_reports_status` ON `player_reports` (`status`, `created_at` DESC);
CREATE INDEX `idx_player_reports_reported` ON `player_reports` (`reported_id`);

-- ─── 23. PLAYER BLOCKS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `player_blocks` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `blocker_id` VARCHAR(36) NOT NULL,
  `blocked_id` VARCHAR(36) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `unique_block` UNIQUE (`blocker_id`, `blocked_id`),
  CONSTRAINT `fk_pb_blocker` FOREIGN KEY (`blocker_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pb_blocked` FOREIGN KEY (`blocked_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_blocks_blocker` ON `player_blocks` (`blocker_id`);

-- ─── 24. PENALTIES ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `penalties` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `type` VARCHAR(20) NOT NULL,
  `reason` TEXT NOT NULL,
  `issued_by` VARCHAR(50) DEFAULT 'system',
  `starts_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `is_active` BOOLEAN DEFAULT TRUE,
  CONSTRAINT `fk_penalties_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_penalties_type` CHECK (`type` IN ('warning', 'mute', 'chat_ban', 'temp_ban', 'perma_ban'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_penalties_user` ON `penalties` (`user_id`, `is_active`);

-- ─── 25. CHAT LOGS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `chat_logs` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `match_id` VARCHAR(255) DEFAULT NULL,
  `sender_id` VARCHAR(36) DEFAULT NULL,
  `content` TEXT NOT NULL,
  `phase` VARCHAR(20) DEFAULT NULL,
  `flagged` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_chat_logs_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_chat_logs_match` ON `chat_logs` (`match_id`);
CREATE INDEX `idx_chat_logs_flagged` ON `chat_logs` (`flagged`);

-- ─── 26. AUDIT LOGS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `admin_id` VARCHAR(50) DEFAULT NULL,
  `action` VARCHAR(50) NOT NULL,
  `target_user_id` VARCHAR(36) DEFAULT NULL,
  `details` JSON DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 27. SEASONS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `seasons` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `start_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `is_active` BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Seasons
INSERT IGNORE INTO `seasons` (`id`, `name`, `start_date`, `end_date`, `is_active`) VALUES
  (1, 'Season 1', '2026-07-01', '2026-09-30', TRUE);

-- ─── 28. SEASON HISTORY ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `season_history` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `season_id` INT NOT NULL,
  `final_rating` INT NOT NULL DEFAULT 1000,
  `final_tier` VARCHAR(20) NOT NULL DEFAULT 'bronze',
  `games_played` INT DEFAULT 0,
  `reward_claimed` BOOLEAN DEFAULT FALSE,
  UNIQUE KEY `uk_user_season` (`user_id`, `season_id`),
  CONSTRAINT `fk_sh_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sh_season` FOREIGN KEY (`season_id`) REFERENCES `seasons` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 29. LEADERBOARD ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS `leaderboard` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `display_name` VARCHAR(255) NOT NULL DEFAULT 'Player',
  `avatar_id` INT DEFAULT 1,
  `level` INT DEFAULT 1,
  `xp` BIGINT DEFAULT 0,
  `games_won` INT DEFAULT 0,
  `games_played` INT DEFAULT 0,
  `rating` INT DEFAULT 1000,
  `rank_tier` VARCHAR(20) DEFAULT 'bronze',
  `win_rate` FLOAT DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_leaderboard_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_leaderboard_rating` ON `leaderboard` (`rating` DESC);
CREATE INDEX `idx_leaderboard_xp` ON `leaderboard` (`xp` DESC);

-- ─── 30. USER PURCHASES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `user_purchases` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `item_id` VARCHAR(50) NOT NULL,
  `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_user_purchase` (`user_id`, `item_id`),
  CONSTRAINT `fk_up_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_up_item` FOREIGN KEY (`item_id`) REFERENCES `shop_items` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_user_purchases_user` ON `user_purchases` (`user_id`);

-- ─── 31. PAYMENT ORDERS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS `payment_orders` (
  `order_id` VARCHAR(100) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `package_id` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL,
  `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_payment_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_payment_orders_user` ON `payment_orders` (`user_id`, `created_at` DESC);
CREATE INDEX `idx_payment_orders_status` ON `payment_orders` (`status`);

-- ─── 32. DIAMOND BALANCE ───────────────────────────────────
CREATE TABLE IF NOT EXISTS `diamond_balance` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `total_spent` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_db_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_db_amount` CHECK (`amount` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 33. DIAMOND TRANSACTIONS ──────────────────────────────
CREATE TABLE IF NOT EXISTS `diamond_transactions` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `amount` BIGINT NOT NULL,
  `balance_after` BIGINT NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `ref_id` VARCHAR(255) UNIQUE DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_dt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_diamond_tx_user` ON `diamond_transactions` (`user_id`, `created_at` DESC);

-- ─── 34. GIFT CATALOG ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_catalog` (
  `id` VARCHAR(50) PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `emoji` VARCHAR(50) NOT NULL,
  `category` VARCHAR(50) NOT NULL DEFAULT 'standard',
  `type` VARCHAR(20) NOT NULL DEFAULT 'gift',
  `diamond_price` INT NOT NULL,
  `charm_delta` INT NOT NULL,
  `popularity_delta` INT NOT NULL DEFAULT 0,
  `animation_key` VARCHAR(100) NOT NULL DEFAULT 'default',
  `broadcast_type` VARCHAR(20) NOT NULL DEFAULT 'none',
  `rarity` VARCHAR(20) NOT NULL DEFAULT 'common',
  `is_limited` BOOLEAN NOT NULL DEFAULT FALSE,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `sort_order` INT NOT NULL DEFAULT 100,
  `description` TEXT DEFAULT NULL,
  `available_from` TIMESTAMP NULL DEFAULT NULL,
  `available_until` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `chk_gc_price` CHECK (`diamond_price` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Standard Gifts
INSERT IGNORE INTO `gift_catalog` (`id`, `name`, `emoji`, `category`, `type`, `diamond_price`, `charm_delta`, `popularity_delta`, `animation_key`, `broadcast_type`, `rarity`, `sort_order`, `description`) VALUES
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
('royal_throne', 'Royal Throne', '👑', 'legendary', 'gift',  10000, 3000, 1000, 'throne_legendary','global', 'legendary', 140, 'Tahta kerajaan tertinggi');

-- Seed Curses
INSERT IGNORE INTO `gift_catalog` (`id`, `name`, `emoji`, `category`, `type`, `diamond_price`, `charm_delta`, `popularity_delta`, `animation_key`, `broadcast_type`, `rarity`, `sort_order`, `description`) VALUES
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
('bad_luck',  'Bad Luck',  '⚡', 'legendary','curse',  3000, -500, 150,'lightning_strike','global','legendary', 130,'Petir sial!');

-- Seed Seasonal Gifts (Valentine, Halloween, Christmas, Ramadan)
INSERT IGNORE INTO `gift_catalog` (`id`, `name`, `emoji`, `category`, `type`, `diamond_price`, `charm_delta`, `popularity_delta`, `animation_key`, `broadcast_type`, `rarity`, `is_limited`, `sort_order`, `description`, `available_from`, `available_until`) VALUES
('valentine_heart',   'Valentine Heart',   '💖', 'seasonal', 'gift',  150,  80,   20, 'heart_burst',    'none',   'rare',      TRUE, 200, 'Hati Valentine spesial', '2027-02-01 00:00:00','2027-02-28 23:59:59'),
('valentine_roses',   'Valentine Roses',   '🌹', 'seasonal', 'gift',  500,  300,  80, 'roses_rain',     'room',   'epic',      TRUE, 201, 'Hujan mawar Valentine',  '2027-02-01 00:00:00','2027-02-28 23:59:59'),
('valentine_cupid',   'Cupid Arrow',       '💘', 'seasonal', 'gift',  2000, 1000, 300,'cupid_fly',      'global', 'legendary', TRUE, 202, 'Panah Cupid legendaris', '2027-02-01 00:00:00','2027-02-28 23:59:59'),
('halloween_pumpkin', 'Pumpkin',           '🎃', 'seasonal', 'curse', 100,  -30,  10, 'pumpkin_bounce', 'none',   'rare',      TRUE, 210, 'Labu Halloween',         '2027-10-15 00:00:00','2027-11-05 23:59:59'),
('halloween_skull',   'Spooky Skull',      '💀', 'seasonal', 'curse', 500,  -150, 40, 'skull_spin',     'room',   'epic',      TRUE, 211, 'Tengkorak menakutkan!',  '2027-10-15 00:00:00','2027-11-05 23:59:59'),
('halloween_reaper',  'Grim Reaper',       '⚰️', 'seasonal', 'curse', 3000, -500, 200,'reaper_swing',   'global', 'legendary', TRUE, 212, 'Malaikat maut datang!',  '2027-10-15 00:00:00','2027-11-05 23:59:59'),
('xmas_tree',         'Christmas Tree',    '🎄', 'seasonal', 'gift',  200,  100,  25, 'tree_glow',      'none',   'rare',      TRUE, 220, 'Pohon Natal bercahaya',  '2027-12-01 00:00:00','2028-01-05 23:59:59'),
('xmas_santa',        'Santa Gift',        '🎅', 'seasonal', 'gift',  800,  400,  100,'santa_fly',      'room',   'epic',      TRUE, 221, 'Hadiah dari Santa!',     '2027-12-01 00:00:00','2028-01-05 23:59:59'),
('xmas_star',         'Star of Bethlehem', '⭐', 'seasonal', 'gift',  5000, 2500, 800,'star_descend',   'global', 'legendary', TRUE, 222, 'Bintang langka Natal',   '2027-12-01 00:00:00','2028-01-05 23:59:59'),
('ramadan_crescent',  'Crescent Moon',     '🌙', 'seasonal', 'gift',  150,  70,   18, 'crescent_glow',  'none',   'rare',      TRUE, 230, 'Bulan sabit Ramadan',    '2027-03-01 00:00:00','2027-04-01 23:59:59'),
('ramadan_lantern',   'Ramadan Lantern',   '🏮', 'seasonal', 'gift',  600,  350,  90, 'lantern_float',  'room',   'epic',      TRUE, 231, 'Lentera Ramadan',        '2027-03-01 00:00:00','2027-04-01 23:59:59'),
('ramadan_mosque',    'Golden Mosque',     '🕌', 'seasonal', 'gift',  4000, 2000, 600,'mosque_rise',    'global', 'legendary', TRUE, 232, 'Masjid emas legendaris', '2027-03-01 00:00:00','2027-04-01 23:59:59');

-- ─── 35. GIFT TRANSACTIONS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_transactions` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `idempotency_key` VARCHAR(255) UNIQUE NOT NULL,
  `sender_id` VARCHAR(36) NOT NULL,
  `receiver_id` VARCHAR(36) NOT NULL,
  `gift_id` VARCHAR(50) NOT NULL,
  `gift_type` VARCHAR(20) NOT NULL,
  `diamond_spent` INT NOT NULL,
  `charm_delta` INT NOT NULL,
  `popularity_delta` INT NOT NULL,
  `message` TEXT DEFAULT NULL,
  `animation_played` BOOLEAN NOT NULL DEFAULT FALSE,
  `broadcast_done` BOOLEAN NOT NULL DEFAULT FALSE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_gt_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gt_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gt_gift` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_gift_tx_sender` ON `gift_transactions` (`sender_id`, `created_at` DESC);
CREATE INDEX `idx_gift_tx_receiver` ON `gift_transactions` (`receiver_id`, `created_at` DESC);
CREATE INDEX `idx_gift_tx_gift_id` ON `gift_transactions` (`gift_id`, `created_at` DESC);

-- ─── 36. CHARM LEDGER ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `charm_ledger` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `delta` INT NOT NULL,
  `balance` BIGINT NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `ref_id` VARCHAR(36) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_cl_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_charm_ledger_user` ON `charm_ledger` (`user_id`, `created_at` DESC);

-- ─── 37. POPULARITY LEDGER ─────────────────────────────────
CREATE TABLE IF NOT EXISTS `popularity_ledger` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `delta` INT NOT NULL,
  `balance` BIGINT NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `ref_id` VARCHAR(36) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_pl_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_popularity_ledger_user` ON `popularity_ledger` (`user_id`, `created_at` DESC);

-- ─── 38. SOCIAL STATS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `social_stats` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `charm` BIGINT NOT NULL DEFAULT 0,
  `popularity` BIGINT NOT NULL DEFAULT 0,
  `gifts_sent` INT NOT NULL DEFAULT 0,
  `gifts_received` INT NOT NULL DEFAULT 0,
  `curses_sent` INT NOT NULL DEFAULT 0,
  `curses_received` INT NOT NULL DEFAULT 0,
  `diamonds_spent_gifts` BIGINT NOT NULL DEFAULT 0,
  `legendary_gifts_sent` INT NOT NULL DEFAULT 0,
  `legendary_gifts_received` INT NOT NULL DEFAULT 0,
  `total_gift_value_sent` BIGINT NOT NULL DEFAULT 0,
  `total_gift_value_received` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_ss_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 39. GIFT COMBO EVENTS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_combo_events` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `gift_id` VARCHAR(50) NOT NULL,
  `receiver_id` VARCHAR(36) NOT NULL,
  `sender_ids` JSON NOT NULL,
  `combo_count` INT NOT NULL DEFAULT 1,
  `window_start` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `window_end` TIMESTAMP NOT NULL,
  `triggered` BOOLEAN NOT NULL DEFAULT FALSE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_gce_gift` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`),
  CONSTRAINT `fk_gce_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_gift_combo_receiver` ON `gift_combo_events` (`receiver_id`, `window_end`);
CREATE INDEX `idx_gift_combo_gift` ON `gift_combo_events` (`gift_id`, `window_end`);

-- ─── 40. SOCIAL ACTIVITY FEED ──────────────────────────────
CREATE TABLE IF NOT EXISTS `social_activity_feed` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `event_type` VARCHAR(50) NOT NULL,
  `sender_id` VARCHAR(36) DEFAULT NULL,
  `receiver_id` VARCHAR(36) DEFAULT NULL,
  `gift_id` VARCHAR(50) DEFAULT NULL,
  `sender_name` VARCHAR(255) DEFAULT NULL,
  `receiver_name` VARCHAR(255) DEFAULT NULL,
  `gift_name` VARCHAR(255) DEFAULT NULL,
  `gift_emoji` VARCHAR(50) DEFAULT NULL,
  `broadcast_type` VARCHAR(20) NOT NULL DEFAULT 'none',
  `message` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_saf_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_saf_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_saf_gift` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_feed_created` ON `social_activity_feed` (`created_at` DESC);
CREATE INDEX `idx_feed_receiver` ON `social_activity_feed` (`receiver_id`, `created_at` DESC);

-- ─── 41. GIFT STREAKS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_streaks` (
  `user_id` VARCHAR(36) PRIMARY KEY,
  `current_streak` INT NOT NULL DEFAULT 0,
  `longest_streak` INT NOT NULL DEFAULT 0,
  `last_gift_date` DATE DEFAULT NULL,
  `streak_bonus_multiplier` FLOAT NOT NULL DEFAULT 1.0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_gs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 42. GIFT ALBUM ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_album` (
  `user_id` VARCHAR(36) NOT NULL,
  `gift_id` VARCHAR(50) NOT NULL,
  `role` VARCHAR(20) NOT NULL,
  `first_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `count` INT NOT NULL DEFAULT 1,
  PRIMARY KEY (`user_id`, `gift_id`, `role`),
  CONSTRAINT `fk_ga_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ga_gift` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 43. GIFT RATE LIMIT ───────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_rate_limit` (
  `user_id` VARCHAR(36) NOT NULL,
  `window_key` VARCHAR(100) NOT NULL,
  `count` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`, `window_key`),
  CONSTRAINT `fk_grl_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 44. GIFT ABUSE LOG ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_abuse_log` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `reason` TEXT NOT NULL,
  `detail` JSON DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_gal_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 45. GIFT ANALYTICS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_analytics` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `event_date` DATE NOT NULL,
  `gift_id` VARCHAR(50) NOT NULL,
  `gift_type` VARCHAR(20) NOT NULL,
  `transaction_count` INT NOT NULL DEFAULT 0,
  `diamond_revenue` BIGINT NOT NULL DEFAULT 0,
  `unique_senders` INT NOT NULL DEFAULT 0,
  `unique_receivers` INT NOT NULL DEFAULT 0,
  UNIQUE KEY `uk_gift_analytics` (`event_date`, `gift_id`),
  CONSTRAINT `fk_ga_gift_id` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 46. SOCIAL LEADERBOARD ────────────────────────────────
CREATE TABLE IF NOT EXISTS `social_leaderboard` (
  `user_id` VARCHAR(36) NOT NULL,
  `board_type` VARCHAR(50) NOT NULL,
  `period` VARCHAR(20) NOT NULL,
  `score` BIGINT NOT NULL DEFAULT 0,
  `rank` INT DEFAULT NULL,
  `display_name` VARCHAR(255) DEFAULT NULL,
  `avatar_id` INT DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `board_type`, `period`),
  CONSTRAINT `fk_sl_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_social_lb_type_period` ON `social_leaderboard` (`board_type`, `period`, `score` DESC);

-- ─── 47. GIFT WISHLIST ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `gift_wishlist` (
  `user_id` VARCHAR(36) NOT NULL,
  `gift_id` VARCHAR(50) NOT NULL,
  `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `gift_id`),
  CONSTRAINT `fk_gw_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gw_gift` FOREIGN KEY (`gift_id`) REFERENCES `gift_catalog` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── 48. DAILY MISSIONS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS `daily_missions` (
  `id` VARCHAR(100) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `template_id` VARCHAR(50) NOT NULL,
  `title` VARCHAR(100) NOT NULL,
  `description` TEXT NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `target` INT NOT NULL DEFAULT 1,
  `progress` INT NOT NULL DEFAULT 0,
  `xp_reward` INT NOT NULL DEFAULT 0,
  `coin_reward` INT NOT NULL DEFAULT 0,
  `is_completed` BOOLEAN NOT NULL DEFAULT FALSE,
  `is_claimed` BOOLEAN NOT NULL DEFAULT FALSE,
  `expires_at` TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_dm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_daily_missions_user_id` ON `daily_missions` (`user_id`);
CREATE INDEX `idx_daily_missions_expires_at` ON `daily_missions` (`expires_at`);
CREATE INDEX `idx_daily_missions_user_active` ON `daily_missions` (`user_id`, `expires_at`, `is_claimed`);

-- ─── 49. NOTIFICATIONS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` VARCHAR(100) PRIMARY KEY,
  `user_id` VARCHAR(36) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `title` VARCHAR(200) NOT NULL,
  `message` TEXT NOT NULL,
  `data` JSON DEFAULT NULL,
  `is_read` BOOLEAN NOT NULL DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_notifications_user_id` ON `notifications` (`user_id`);
CREATE INDEX `idx_notifications_user_unread` ON `notifications` (`user_id`, `is_read`);
CREATE INDEX `idx_notifications_created_at` ON `notifications` (`created_at`);

-- ─── 50. PLAYER ACHIEVEMENTS ───────────────────────────────
CREATE TABLE IF NOT EXISTS `player_achievements` (
  `id` VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` VARCHAR(36) NOT NULL,
  `achievement_id` VARCHAR(50) NOT NULL,
  `unlocked_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_user_achievement` (`user_id`, `achievement_id`),
  CONSTRAINT `fk_pa_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_player_achievements_user` ON `player_achievements` (`user_id`);

-- ─── 51. SERVER SETTINGS ───────────────────────────────────
CREATE TABLE IF NOT EXISTS `server_settings` (
  `key` VARCHAR(50) PRIMARY KEY,
  `value` TEXT NOT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Server Settings
INSERT IGNORE INTO `server_settings` (`key`, `value`) VALUES
  ('max_rooms', '100'),
  ('max_players_per_room', '16'),
  ('maintenance_message', ''),
  ('min_app_version', '1.0.0');

-- ─── 52. FEATURE FLAGS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS `feature_flags` (
  `key` VARCHAR(50) PRIMARY KEY,
  `enabled` BOOLEAN DEFAULT FALSE,
  `description` TEXT DEFAULT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed Feature Flags
INSERT IGNORE INTO `feature_flags` (`key`, `enabled`, `description`) VALUES
  ('maintenance_mode', FALSE, 'Server in maintenance'),
  ('ranked_enabled', TRUE, 'Ranked matchmaking available'),
  ('shop_enabled', TRUE, 'Shop accessible'),
  ('friends_enabled', TRUE, 'Friends system active'),
  ('push_notifications', FALSE, 'Push notifications enabled'),
  ('chat_enabled', TRUE, 'In-game chat active'),
  ('bots_enabled', TRUE, 'Bot fill enabled'),
  ('daily_missions', TRUE, 'Daily missions system');

SET FOREIGN_KEY_CHECKS = 1;

-- End of Consolidated MySQL Migration File
