package db

import (
	"log"
)

// XP thresholds per level (cumulative XP needed for each level)
// Level 1 = 0 XP, Level 2 = 100 XP, Level 3 = 250 XP, etc.
var levelThresholds = []int{
	0,     // Level 1
	100,   // Level 2
	250,   // Level 3
	500,   // Level 4
	850,   // Level 5
	1300,  // Level 6
	1900,  // Level 7
	2600,  // Level 8
	3500,  // Level 9
	4600,  // Level 10
	5900,  // Level 11
	7500,  // Level 12
	9400,  // Level 13
	11600, // Level 14
	14200, // Level 15
	17200, // Level 16
	20700, // Level 17
	24700, // Level 18
	29300, // Level 19
	34500, // Level 20
}

// CalculateXPReward computes XP earned for a match.
// Base: 20 XP per game, +30 if won, +10 if survived, +5 per round played.
// Role bonuses: seer +10 (found wolf), doctor +10 (saved someone), wolf +5 (kill).
func CalculateXPReward(won, survived bool, rounds int, role string) int {
	xp := 20 // base participation

	if won {
		xp += 30
	}
	if survived {
		xp += 10
	}

	xp += rounds * 5

	// Role-specific bonus
	switch role {
	case "werewolf":
		xp += 5
	case "seer":
		xp += 10
	case "doctor":
		xp += 10
	case "witch":
		xp += 8
	}

	return xp
}

// CalculateCoinReward computes coins earned.
// Base: 10 coins, +15 if won, +5 if survived.
func CalculateCoinReward(won, survived bool) int {
	coins := 10
	if won {
		coins += 15
	}
	if survived {
		coins += 5
	}
	return coins
}

// GetLevelForXP returns the level for a given total XP amount.
func GetLevelForXP(totalXP int) int {
	level := 1
	for i, threshold := range levelThresholds {
		if totalXP >= threshold {
			level = i + 1
		} else {
			break
		}
	}
	return level
}

// GetXPForNextLevel returns XP needed for the next level.
func GetXPForNextLevel(level int) int {
	if level >= len(levelThresholds) {
		return levelThresholds[len(levelThresholds)-1] + (level-len(levelThresholds))*5000
	}
	return levelThresholds[level] // threshold for level+1 (0-indexed means level index = next level threshold)
}

// CheckAndApplyLevelUp checks if the user has leveled up after XP gain and updates profile.
func CheckAndApplyLevelUp(userID string) (int, bool) {
	if DB == nil {
		return 0, false
	}

	var currentXP int
	var currentLevel int
	err := DB.QueryRow(`SELECT xp, level FROM profiles WHERE user_id = $1`, userID).Scan(&currentXP, &currentLevel)
	if err != nil {
		log.Printf("CheckAndApplyLevelUp: failed to get profile: %v", err)
		return currentLevel, false
	}

	newLevel := GetLevelForXP(currentXP)
	if newLevel > currentLevel {
		_, err := DB.Exec(`UPDATE profiles SET level = $2 WHERE user_id = $1`, userID, newLevel)
		if err != nil {
			log.Printf("CheckAndApplyLevelUp: failed to update level: %v", err)
		}
		// Also update leaderboard level
		DB.Exec(`UPDATE leaderboard SET level = $2 WHERE user_id = $1`, userID, newLevel)
		return newLevel, true
	}

	return currentLevel, false
}

// RecordMatchWithXP is a higher-level function that calculates rewards and records the match.
func RecordMatchWithXP(userID, matchID, role, team string, won, survived bool, rounds, duration, playerCount int) (xp int, coins int, newLevel int, leveledUp bool, err error) {
	xp = CalculateXPReward(won, survived, rounds, role)
	coins = CalculateCoinReward(won, survived)

	err = RecordMatch(userID, matchID, role, team, won, survived, rounds, duration, xp, coins, playerCount)
	if err != nil {
		return
	}

	newLevel, leveledUp = CheckAndApplyLevelUp(userID)
	return
}
