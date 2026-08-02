package db

import "fmt"

// PlayerStats holds detailed game statistics
type PlayerStats struct {
	UserID           string `json:"userId"`
	GamesPlayed      int    `json:"gamesPlayed"`
	GamesWon         int    `json:"gamesWon"`
	GamesAsWerewolf  int    `json:"gamesAsWerewolf"`
	GamesAsSeer      int    `json:"gamesAsSeer"`
	GamesAsDoctor    int    `json:"gamesAsDoctor"`
	GamesAsWitch     int    `json:"gamesAsWitch"`
	GamesAsVillager  int    `json:"gamesAsVillager"`
	WolvesFound      int    `json:"wolvesFound"`
	PlayersProtected int    `json:"playersProtected"`
	CurrentWinStreak int    `json:"currentWinStreak"`
	LongestWinStreak int    `json:"longestWinStreak"`
	MVPCount         int    `json:"mvpCount"`
	Rating           int    `json:"rating"`
	RankTier         string `json:"rankTier"`
}

// MatchHistoryEntry represents a single game record
type MatchHistoryEntry struct {
	ID          string `json:"id"`
	MatchID     string `json:"matchId"`
	PlayedAt    string `json:"playedAt"`
	DurationSec int    `json:"durationSec"`
	TotalRounds int    `json:"totalRounds"`
	Role        string `json:"role"`
	Team        string `json:"team"`
	Won         bool   `json:"won"`
	Survived    bool   `json:"survived"`
	XPEarned    int    `json:"xpEarned"`
	CoinsEarned int    `json:"coinsEarned"`
	PlayerCount int    `json:"playerCount"`
}

// LeaderboardEntry represents a leaderboard row
type LeaderboardEntry struct {
	UserID      string  `json:"userId"`
	DisplayName string  `json:"displayName"`
	AvatarID    int     `json:"avatarId"`
	Level       int     `json:"level"`
	XP          int64   `json:"xp"`
	GamesWon    int     `json:"gamesWon"`
	GamesPlayed int     `json:"gamesPlayed"`
	Rating      int     `json:"rating"`
	RankTier    string  `json:"rankTier"`
	WinRate     float32 `json:"winRate"`
}

// GetPlayerStats fetches player statistics
func GetPlayerStats(userID string) (*PlayerStats, error) {
	s := &PlayerStats{}
	err := DB.QueryRow(`
		SELECT user_id, games_played, games_won,
		       games_as_werewolf, games_as_seer, games_as_doctor,
		       games_as_witch, games_as_villager, wolves_found,
		       players_protected, current_win_streak, longest_win_streak,
		       mvp_count, rating, rank_tier
		FROM player_stats WHERE user_id = $1
	`, userID).Scan(
		&s.UserID, &s.GamesPlayed, &s.GamesWon,
		&s.GamesAsWerewolf, &s.GamesAsSeer, &s.GamesAsDoctor,
		&s.GamesAsWitch, &s.GamesAsVillager, &s.WolvesFound,
		&s.PlayersProtected, &s.CurrentWinStreak, &s.LongestWinStreak,
		&s.MVPCount, &s.Rating, &s.RankTier,
	)
	if err != nil {
		return nil, err
	}
	return s, nil
}

// GetMatchHistory fetches recent matches for a user
func GetMatchHistory(userID string, limit int) ([]MatchHistoryEntry, error) {
	if limit <= 0 {
		limit = 20
	}
	rows, err := DB.Query(`
		SELECT id, match_id, played_at, duration_sec, total_rounds,
		       role, team, won, survived, xp_earned, coins_earned, player_count
		FROM match_history
		WHERE user_id = $1
		ORDER BY played_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []MatchHistoryEntry
	for rows.Next() {
		var e MatchHistoryEntry
		if err := rows.Scan(
			&e.ID, &e.MatchID, &e.PlayedAt, &e.DurationSec, &e.TotalRounds,
			&e.Role, &e.Team, &e.Won, &e.Survived, &e.XPEarned, &e.CoinsEarned, &e.PlayerCount,
		); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, nil
}

// GetLeaderboard fetches top players
func GetLeaderboard(sortBy string, limit int) ([]LeaderboardEntry, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100 // Cap maximum to prevent DoS
	}

	// Whitelist allowed sort columns to prevent SQL injection
	orderCol := "rating" // default
	allowedColumns := map[string]string{
		"rating": "rating",
		"xp":     "xp",
		"wins":   "games_won",
		"level":  "level",
	}
	if col, ok := allowedColumns[sortBy]; ok {
		orderCol = col
	}

	// Use prepared statement with parameterized query
	// Note: Column names can't be parameterized, but we've whitelisted them above
	query := fmt.Sprintf(`
		SELECT user_id, display_name, avatar_id, level, xp,
		       games_won, games_played, rating, rank_tier, win_rate
		FROM leaderboard
		ORDER BY %s DESC
		LIMIT $1
	`, orderCol)

	rows, err := DB.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []LeaderboardEntry
	for rows.Next() {
		var e LeaderboardEntry
		if err := rows.Scan(
			&e.UserID, &e.DisplayName, &e.AvatarID, &e.Level, &e.XP,
			&e.GamesWon, &e.GamesPlayed, &e.Rating, &e.RankTier, &e.WinRate,
		); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, nil
}

// RecordMatch inserts a match history entry and updates ALL related stats atomically
// using a single DB transaction.
// #5 FIX: Previously used 7 separate DB.Exec calls — if any failed mid-way,
// the DB would be left in an inconsistent state (e.g. match_history inserted
// but leaderboard not updated). Now wrapped in a transaction so it's all-or-nothing.
// #2 FIX: All DB operations now have error checking and logging.
// #4 FIX: win_rate in leaderboard now computed AFTER incrementing games_played,
//         so the first game always shows the correct rate (not 0%).
func RecordMatch(userID, matchID, role, team string, won, survived bool, rounds, duration, xp, coins, playerCount int) error {
	// Whitelist valid roles to prevent SQL injection
	allowedRoles := map[string]bool{
		"werewolf": true, "seer": true, "doctor": true, "witch": true, "villager": true,
	}
	if !allowedRoles[role] {
		role = "villager"
	}

	roleColumns := map[string]string{
		"werewolf": "games_as_werewolf", "seer": "games_as_seer",
		"doctor": "games_as_doctor", "witch": "games_as_witch",
		"villager": "games_as_villager",
	}
	roleCol := roleColumns[role]

	// Begin transaction — all updates are atomic
	tx, err := DB.Begin()
	if err != nil {
		return fmt.Errorf("RecordMatch: begin tx: %w", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	// 1. Insert match history (idempotent — skip if already recorded)
	if _, err = tx.Exec(`
		INSERT INTO match_history
			(user_id, match_id, role, team, won, survived, total_rounds, duration_sec,
			 xp_earned, coins_earned, player_count)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (user_id, match_id) DO NOTHING
	`, userID, matchID, role, team, won, survived, rounds, duration, xp, coins, playerCount); err != nil {
		return fmt.Errorf("RecordMatch: insert history: %w", err)
	}

	// 2. Update profile (XP + coins + played count)
	if won {
		if _, err = tx.Exec(`
			UPDATE profiles SET
				games_played = games_played + 1,
				games_won    = games_won + 1,
				xp           = xp + $2,
				coins        = coins + $3
			WHERE user_id = $1
		`, userID, xp, coins); err != nil {
			return fmt.Errorf("RecordMatch: update profile (win): %w", err)
		}
	} else {
		if _, err = tx.Exec(`
			UPDATE profiles SET
				games_played = games_played + 1,
				xp           = xp + $2,
				coins        = coins + $3
			WHERE user_id = $1
		`, userID, xp, coins); err != nil {
			return fmt.Errorf("RecordMatch: update profile (loss): %w", err)
		}
	}

	// 3. Update role-specific stats column (safe: roleCol is from whitelist map)
	roleQuery := fmt.Sprintf(`
		UPDATE player_stats SET
			games_played = games_played + 1,
			%s = %s + 1
		WHERE user_id = $1
	`, roleCol, roleCol)
	if _, err = tx.Exec(roleQuery, userID); err != nil {
		return fmt.Errorf("RecordMatch: update player_stats role: %w", err)
	}

	// 4. Update win/loss streak
	if won {
		if _, err = tx.Exec(`
			UPDATE player_stats SET
				games_won            = games_won + 1,
				current_win_streak   = current_win_streak + 1,
				longest_win_streak   = GREATEST(longest_win_streak, current_win_streak + 1)
			WHERE user_id = $1
		`, userID); err != nil {
			return fmt.Errorf("RecordMatch: update streak (win): %w", err)
		}
	} else {
		if _, err = tx.Exec(`
			UPDATE player_stats SET current_win_streak = 0 WHERE user_id = $1
		`, userID); err != nil {
			return fmt.Errorf("RecordMatch: update streak (loss): %w", err)
		}
	}

	// 5. Update leaderboard.
	// #4 FIX: win_rate is computed with (games_played + 1) in the denominator so
	// the very first game shows 100% (won) or 0% (lost) instead of always 0%.
	if _, err = tx.Exec(`
		UPDATE leaderboard SET
			games_played = games_played + 1,
			games_won    = CASE WHEN $2 THEN games_won + 1 ELSE games_won END,
			xp           = xp + $3,
			win_rate     = CASE
				WHEN $2 THEN (games_won + 1)::real / (games_played + 1)::real
				ELSE      games_won::real        / (games_played + 1)::real
			END,
			updated_at   = now()
		WHERE user_id = $1
	`, userID, won, xp); err != nil {
		return fmt.Errorf("RecordMatch: update leaderboard: %w", err)
	}

	// Commit
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("RecordMatch: commit: %w", err)
	}
	return nil
}
