package db

import (
	"time"
)

// AchievementDef defines an achievement
type AchievementDef struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Emoji       string `json:"emoji"`
	Category    string `json:"category"` // general, role, streak, social
	Condition   string `json:"condition"`
	Threshold   int    `json:"threshold"`
}

// PlayerAchievement represents a user's unlocked achievement
type PlayerAchievement struct {
	AchievementID string `json:"achievementId"`
	UnlockedAt    string `json:"unlockedAt"`
}

// All available achievements
var Achievements = []AchievementDef{
	{ID: "first_game", Name: "First Steps", Description: "Mainkan game pertama", Emoji: "🎮", Category: "general", Condition: "games_played", Threshold: 1},
	{ID: "first_win", Name: "Victor", Description: "Menangkan game pertama", Emoji: "🏆", Category: "general", Condition: "games_won", Threshold: 1},
	{ID: "ten_games", Name: "Dedicated", Description: "Mainkan 10 game", Emoji: "⭐", Category: "general", Condition: "games_played", Threshold: 10},
	{ID: "ten_wins", Name: "Champion", Description: "Menangkan 10 game", Emoji: "👑", Category: "general", Condition: "games_won", Threshold: 10},
	{ID: "wolf_master", Name: "Wolf King", Description: "Menang 5x sebagai Werewolf", Emoji: "🐺", Category: "role", Condition: "wolf_wins", Threshold: 5},
	{ID: "seer_master", Name: "True Seer", Description: "Menang 5x sebagai Seer", Emoji: "🔮", Category: "role", Condition: "seer_wins", Threshold: 5},
	{ID: "doctor_master", Name: "Life Saver", Description: "Menang 5x sebagai Doctor", Emoji: "💉", Category: "role", Condition: "doctor_wins", Threshold: 5},
	{ID: "witch_master", Name: "Mystic", Description: "Menang 5x sebagai Witch", Emoji: "🧙", Category: "role", Condition: "witch_wins", Threshold: 5},
	{ID: "streak_3", Name: "On Fire", Description: "Win streak 3 game", Emoji: "🔥", Category: "streak", Condition: "win_streak", Threshold: 3},
	{ID: "streak_5", Name: "Unstoppable", Description: "Win streak 5 game", Emoji: "💫", Category: "streak", Condition: "win_streak", Threshold: 5},
	{ID: "survivor", Name: "Survivor", Description: "Selamat di 10 game", Emoji: "🛡️", Category: "general", Condition: "survived", Threshold: 10},
	{ID: "fifty_games", Name: "Veteran", Description: "Mainkan 50 game", Emoji: "🎖️", Category: "general", Condition: "games_played", Threshold: 50},
}

// GetPlayerAchievements returns unlocked achievements for a user
func GetPlayerAchievements(userID string) ([]PlayerAchievement, error) {
	if DB == nil {
		return []PlayerAchievement{}, nil
	}

	rows, err := DB.Query(`
		SELECT achievement_id, unlocked_at
		FROM player_achievements
		WHERE user_id = $1
		ORDER BY unlocked_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var achievements []PlayerAchievement
	for rows.Next() {
		var a PlayerAchievement
		if err := rows.Scan(&a.AchievementID, &a.UnlockedAt); err != nil {
			continue
		}
		achievements = append(achievements, a)
	}
	return achievements, nil
}

// CheckAndUnlockAchievements checks all achievement conditions and unlocks new ones.
// Returns a list of newly unlocked achievement IDs.
func CheckAndUnlockAchievements(userID string, stats *PlayerStats) []string {
	if DB == nil {
		return nil
	}

	// Get already unlocked
	existing, _ := GetPlayerAchievements(userID)
	unlockedMap := make(map[string]bool)
	for _, a := range existing {
		unlockedMap[a.AchievementID] = true
	}

	var newlyUnlocked []string

	for _, def := range Achievements {
		if unlockedMap[def.ID] {
			continue
		}

		var value int
		switch def.Condition {
		case "games_played":
			value = stats.GamesPlayed
		case "games_won":
			value = stats.GamesWon
		case "wolf_wins":
			value = stats.GamesAsWerewolf // simplified
		case "seer_wins":
			value = stats.GamesAsSeer
		case "doctor_wins":
			value = stats.GamesAsDoctor
		case "witch_wins":
			value = stats.GamesAsWitch
		case "win_streak":
			value = stats.LongestWinStreak
		case "survived":
			value = stats.PlayersProtected // reusing field
		}

		if value >= def.Threshold {
			// Unlock!
			_, err := DB.Exec(`
				INSERT INTO player_achievements (user_id, achievement_id, unlocked_at)
				VALUES ($1, $2, $3)
				ON CONFLICT DO NOTHING
			`, userID, def.ID, time.Now().Format(time.RFC3339))
			if err == nil {
				newlyUnlocked = append(newlyUnlocked, def.ID)
			}
		}
	}

	return newlyUnlocked
}
