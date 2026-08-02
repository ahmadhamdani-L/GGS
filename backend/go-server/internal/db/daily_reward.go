package db

import (
	"fmt"
	"time"
)

// DailyRewardStatus represents the user's daily reward state
type DailyRewardStatus struct {
	CurrentDay   int    `json:"currentDay"`
	ClaimedToday bool   `json:"claimedToday"`
	LastClaimed  string `json:"lastClaimed,omitempty"`
	TotalClaims  int    `json:"totalClaims"`
}

// DailyRewardResult contains what the user received
type DailyRewardResult struct {
	Day        int    `json:"day"`
	RewardType string `json:"rewardType"` // coins, diamonds, gift_box, special
	Amount     int    `json:"amount"`
}

// Reward definitions per day (7-day cycle)
var dailyRewards = []struct {
	Type   string
	Amount int
}{
	{"coins", 50},      // Day 1
	{"diamonds", 5},    // Day 2
	{"coins", 100},     // Day 3
	{"gift_box", 1},    // Day 4
	{"diamonds", 10},   // Day 5
	{"coins", 200},     // Day 6
	{"diamonds", 20},   // Day 7 (special)
}

// GetDailyRewardStatus returns the user's current daily reward state
func GetDailyRewardStatus(userID string) (*DailyRewardStatus, error) {
	if DB == nil {
		return &DailyRewardStatus{CurrentDay: 1, ClaimedToday: false}, nil
	}

	var currentDay int
	var lastClaimed *time.Time
	var totalClaims int

	err := DB.QueryRow(`
		SELECT current_day, last_claimed, total_claims 
		FROM daily_rewards WHERE user_id = $1
	`, userID).Scan(&currentDay, &lastClaimed, &totalClaims)

	if err != nil {
		// No record yet — first time user
		return &DailyRewardStatus{CurrentDay: 1, ClaimedToday: false, TotalClaims: 0}, nil
	}

	today := time.Now().Truncate(24 * time.Hour)
	claimedToday := lastClaimed != nil && lastClaimed.Truncate(24*time.Hour).Equal(today)

	// Check if streak is broken (missed a day → reset to day 1)
	if lastClaimed != nil && !claimedToday {
		yesterday := today.AddDate(0, 0, -1)
		if lastClaimed.Truncate(24 * time.Hour).Before(yesterday) {
			// Streak broken — reset
			currentDay = 1
			DB.Exec(`UPDATE daily_rewards SET current_day = 1, streak_start = $2 WHERE user_id = $1`, userID, today)
		}
	}

	return &DailyRewardStatus{
		CurrentDay:   currentDay,
		ClaimedToday: claimedToday,
		TotalClaims:  totalClaims,
	}, nil
}

// ClaimDailyReward claims today's reward and advances the day counter
func ClaimDailyReward(userID string) (*DailyRewardResult, error) {
	if DB == nil {
		return nil, fmt.Errorf("database not available")
	}

	status, err := GetDailyRewardStatus(userID)
	if err != nil {
		return nil, err
	}

	if status.ClaimedToday {
		return nil, fmt.Errorf("already claimed today")
	}

	today := time.Now().Truncate(24 * time.Hour)
	rewardIdx := (status.CurrentDay - 1) % len(dailyRewards)
	reward := dailyRewards[rewardIdx]

	// Begin transaction
	tx, err := DB.Begin()
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	// Upsert daily_rewards row
	nextDay := status.CurrentDay + 1
	if nextDay > 7 {
		nextDay = 1 // Reset cycle
	}
	_, err = tx.Exec(`
		INSERT INTO daily_rewards (user_id, current_day, last_claimed, total_claims, streak_start)
		VALUES ($1, $2, $3, 1, $3)
		ON CONFLICT (user_id) DO UPDATE SET
			current_day = $2,
			last_claimed = $3,
			total_claims = daily_rewards.total_claims + 1
	`, userID, nextDay, today)
	if err != nil {
		return nil, fmt.Errorf("update daily_rewards: %w", err)
	}

	// Grant reward
	switch reward.Type {
	case "coins":
		_, err = tx.Exec(`UPDATE profiles SET coins = coins + $2 WHERE user_id = $1`, userID, reward.Amount)
	case "diamonds":
		_, err = tx.Exec(`
			INSERT INTO diamond_balance (user_id, amount) VALUES ($1, $2)
			ON CONFLICT (user_id) DO UPDATE SET amount = diamond_balance.amount + $2
		`, userID, reward.Amount)
	case "gift_box", "special":
		// Add to inventory
		_, err = tx.Exec(`
			INSERT INTO user_inventory (user_id, item_id, quantity)
			VALUES ($1, $2, $3)
			ON CONFLICT (user_id, item_id) DO UPDATE SET quantity = user_inventory.quantity + $3
		`, userID, reward.Type, reward.Amount)
	}
	if err != nil {
		return nil, fmt.Errorf("grant reward: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	return &DailyRewardResult{
		Day:        status.CurrentDay,
		RewardType: reward.Type,
		Amount:     reward.Amount,
	}, nil
}
