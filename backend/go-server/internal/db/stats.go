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

// RecordMatch inserts a match history entry and updates stats
func RecordMatch(userID, matchID, role, team string, won, survived bool, rounds, duration, xp, coins, playerCount int) error {
	// Whitelist valid roles to prevent SQL injection
	allowedRoles := map[string]bool{
		"werewolf": true,
		"seer":     true,
		"doctor":   true,
		"witch":    true,
		"villager": true,
	}
	if !allowedRoles[role] {
		role = "villager" // default to safe value
	}

	_, err := DB.Exec(`
		INSERT INTO match_history (user_id, match_id, role, team, won, survived, total_rounds, duration_sec, xp_earned, coins_earned, player_count)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, userID, matchID, role, team, won, survived, rounds, duration, xp, coins, playerCount)
	if err != nil {
		return err
	}

	// Update profile stats
	if won {
		DB.Exec(`UPDATE profiles SET games_played = games_played + 1, games_won = games_won + 1, xp = xp + $2, coins = coins + $3 WHERE user_id = $1`, userID, xp, coins)
	} else {
		DB.Exec(`UPDATE profiles SET games_played = games_played + 1, xp = xp + $2, coins = coins + $3 WHERE user_id = $1`, userID, xp, coins)
	}

	// Update role-specific stats using safe column mapping
	roleColumns := map[string]string{
		"werewolf": "games_as_werewolf",
		"seer":     "games_as_seer",
		"doctor":   "games_as_doctor",
		"witch":    "games_as_witch",
		"villager": "games_as_villager",
	}
	roleCol := roleColumns[role]
	query := fmt.Sprintf(`UPDATE player_stats SET games_played = games_played + 1, %s = %s + 1 WHERE user_id = $1`, roleCol, roleCol)
	DB.Exec(query, userID)

	if won {
		DB.Exec(`UPDATE player_stats SET games_won = games_won + 1, current_win_streak = current_win_streak + 1 WHERE user_id = $1`, userID)
		DB.Exec(`UPDATE player_stats SET longest_win_streak = current_win_streak WHERE user_id = $1 AND current_win_streak > longest_win_streak`, userID)
	} else {
		DB.Exec(`UPDATE player_stats SET current_win_streak = 0 WHERE user_id = $1`, userID)
	}

	// Update leaderboard
	DB.Exec(`
		UPDATE leaderboard SET
			games_played = games_played + 1,
			games_won = CASE WHEN $2 THEN games_won + 1 ELSE games_won END,
			xp = xp + $3,
			win_rate = CASE WHEN games_played > 0 THEN (games_won::real / games_played::real) ELSE 0 END,
			updated_at = now()
		WHERE user_id = $1
	`, userID, won, xp)

	return nil
}
