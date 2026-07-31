package db

import "math"

// RankTier represents competitive rank tiers
type RankTier struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	MinRating int    `json:"minRating"`
	MaxRating int    `json:"maxRating"`
	Icon      string `json:"icon"`
}

// All rank tiers (ascending order)
var RankTiers = []RankTier{
	{ID: "bronze", Name: "Bronze", MinRating: 0, MaxRating: 999, Icon: "🥉"},
	{ID: "silver", Name: "Silver", MinRating: 1000, MaxRating: 1199, Icon: "🥈"},
	{ID: "gold", Name: "Gold", MinRating: 1200, MaxRating: 1399, Icon: "🥇"},
	{ID: "platinum", Name: "Platinum", MinRating: 1400, MaxRating: 1599, Icon: "💎"},
	{ID: "diamond", Name: "Diamond", MinRating: 1600, MaxRating: 1799, Icon: "💠"},
	{ID: "master", Name: "Master", MinRating: 1800, MaxRating: 1999, Icon: "👑"},
	{ID: "grandmaster", Name: "Grandmaster", MinRating: 2000, MaxRating: 9999, Icon: "🏆"},
}

// Season represents a competitive season
type Season struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	StartDate string `json:"startDate"`
	EndDate   string `json:"endDate"`
	IsActive  bool   `json:"isActive"`
}

// SeasonReward is earned at end of season based on rank
type SeasonReward struct {
	RankTier string `json:"rankTier"`
	Coins    int    `json:"coins"`
	XP       int    `json:"xp"`
	Border   string `json:"border"` // cosmetic reward
}

var SeasonRewards = map[string]SeasonReward{
	"bronze":      {RankTier: "bronze", Coins: 50, XP: 100, Border: ""},
	"silver":      {RankTier: "silver", Coins: 100, XP: 200, Border: "border_silver_season"},
	"gold":        {RankTier: "gold", Coins: 200, XP: 400, Border: "border_gold_season"},
	"platinum":    {RankTier: "platinum", Coins: 350, XP: 600, Border: "border_platinum_season"},
	"diamond":     {RankTier: "diamond", Coins: 500, XP: 800, Border: "border_diamond_season"},
	"master":      {RankTier: "master", Coins: 750, XP: 1000, Border: "border_master_season"},
	"grandmaster": {RankTier: "grandmaster", Coins: 1000, XP: 1500, Border: "border_gm_season"},
}

// GetRankTierForRating returns the rank tier for a given MMR
func GetRankTierForRating(rating int) RankTier {
	for i := len(RankTiers) - 1; i >= 0; i-- {
		if rating >= RankTiers[i].MinRating {
			return RankTiers[i]
		}
	}
	return RankTiers[0]
}

// CalculateMMRChange computes rating change after a match.
// Uses a simplified Elo-like system:
//   - K-factor: 32 (standard)
//   - Expected score based on average opponent rating
//   - Win = +K*(1-expected), Lose = -K*(0-expected)
//   - Bonus/penalty for role difficulty
func CalculateMMRChange(playerRating, avgOpponentRating int, won bool, role string) int {
	k := 32.0

	// Expected score (Elo formula)
	expected := 1.0 / (1.0 + math.Pow(10, float64(avgOpponentRating-playerRating)/400.0))

	var actual float64
	if won {
		actual = 1.0
	} else {
		actual = 0.0
	}

	change := k * (actual - expected)

	// Role modifier: harder roles get slight bonus
	switch role {
	case "seer", "doctor":
		if won {
			change += 3
		}
	case "werewolf":
		if won {
			change += 2 // wolf winning is harder in balanced games
		}
	}

	// Minimum change of ±5 to avoid stagnation
	if won && change < 5 {
		change = 5
	}
	if !won && change > -5 {
		change = -5
	}

	return int(math.Round(change))
}

// ApplyMMRChange updates a player's rating in the database.
func ApplyMMRChange(userID string, ratingChange int) (newRating int, newTier string, err error) {
	if DB == nil {
		return 1000, "bronze", nil
	}

	var currentRating int
	err = DB.QueryRow(`SELECT rating FROM player_stats WHERE user_id = $1`, userID).Scan(&currentRating)
	if err != nil {
		return 1000, "bronze", err
	}

	newRating = currentRating + ratingChange
	if newRating < 0 {
		newRating = 0
	}

	tier := GetRankTierForRating(newRating)
	newTier = tier.ID

	DB.Exec(`UPDATE player_stats SET rating = $2, rank_tier = $3 WHERE user_id = $1`, userID, newRating, newTier)
	DB.Exec(`UPDATE leaderboard SET rating = $2 WHERE user_id = $1`, userID, newRating)

	return newRating, newTier, nil
}

// GetCurrentSeason returns the active season
func GetCurrentSeason() (*Season, error) {
	if DB == nil {
		return &Season{ID: 1, Name: "Season 1", IsActive: true}, nil
	}

	var s Season
	err := DB.QueryRow(`SELECT id, name, start_date, end_date, is_active FROM seasons WHERE is_active = true LIMIT 1`).
		Scan(&s.ID, &s.Name, &s.StartDate, &s.EndDate, &s.IsActive)
	if err != nil {
		return &Season{ID: 1, Name: "Season 1", IsActive: true}, nil
	}
	return &s, nil
}
