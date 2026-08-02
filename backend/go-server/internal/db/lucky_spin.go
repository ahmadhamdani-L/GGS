package db

import (
	"errors"
	"math/rand"
	"time"
)

// SpinPrize represents a prize in the lucky spin wheel
type SpinPrize struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	PrizeType string `json:"prizeType"` // coins, diamonds, xp, item, empty
	Amount    int    `json:"amount"`
	ItemID    string `json:"itemId,omitempty"`
	Weight    int    `json:"weight"`
	Rarity    string `json:"rarity"` // common, rare, epic, legendary
}

// SpinResult is the outcome of a spin
type SpinResult struct {
	Prize     SpinPrize `json:"prize"`
	IsFreeSpin bool     `json:"isFreeSpin"`
	SpinsLeft  int      `json:"freeSpinsRemaining"`
}

// SpinStatus shows user's spin state
type SpinStatus struct {
	FreeSpinsRemaining int       `json:"freeSpinsRemaining"`
	TotalSpins         int       `json:"totalSpins"`
	LastResetAt        time.Time `json:"lastResetAt"`
	Prizes             []SpinPrize `json:"prizes"`
	SpinCostDiamonds   int       `json:"spinCostDiamonds"`
}

// SpinHistoryEntry is one spin record
type SpinHistoryEntry struct {
	ID        string    `json:"id"`
	PrizeName string    `json:"prizeName"`
	PrizeType string    `json:"prizeType"`
	Amount    int       `json:"amount"`
	SpunAt    time.Time `json:"spunAt"`
}

const spinCostDiamonds = 50

// GetSpinStatus returns the user's spin state and available prizes
func GetSpinStatus(userID string) (*SpinStatus, error) {
	prizes := getSpinPrizes()
	status := &SpinStatus{
		FreeSpinsRemaining: 1,
		TotalSpins:         0,
		LastResetAt:        time.Now(),
		Prizes:             prizes,
		SpinCostDiamonds:   spinCostDiamonds,
	}

	if DB == nil {
		return status, nil
	}

	// Get or create daily spin record
	var freeSpins, totalSpins int
	var lastReset time.Time
	err := DB.QueryRow(`
		INSERT INTO lucky_spin_daily (user_id, free_spins_remaining, last_reset_at, total_spins)
		VALUES ($1, 1, now(), 0)
		ON CONFLICT (user_id) DO UPDATE SET
			free_spins_remaining = CASE
				WHEN lucky_spin_daily.last_reset_at::date < CURRENT_DATE THEN 1
				ELSE lucky_spin_daily.free_spins_remaining
			END,
			last_reset_at = CASE
				WHEN lucky_spin_daily.last_reset_at::date < CURRENT_DATE THEN now()
				ELSE lucky_spin_daily.last_reset_at
			END
		RETURNING free_spins_remaining, total_spins, last_reset_at
	`, userID).Scan(&freeSpins, &totalSpins, &lastReset)
	if err != nil {
		return status, nil
	}

	status.FreeSpinsRemaining = freeSpins
	status.TotalSpins = totalSpins
	status.LastResetAt = lastReset
	return status, nil
}

// DoSpin performs a lucky spin
func DoSpin(userID string) (*SpinResult, error) {
	if DB == nil {
		return doMemorySpin(), nil
	}

	// Check free spins first
	var freeSpins int
	err := DB.QueryRow(`SELECT free_spins_remaining FROM lucky_spin_daily WHERE user_id = $1`, userID).Scan(&freeSpins)
	if err != nil {
		// First spin — create record
		freeSpins = 1
		DB.Exec(`INSERT INTO lucky_spin_daily (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, userID)
	}

	isFreeSpin := freeSpins > 0

	if !isFreeSpin {
		// Deduct diamonds
		var balance int64
		err = DB.QueryRow(`
			UPDATE diamond_balance SET amount = amount - $2, total_spent = total_spent + $2, updated_at = now()
			WHERE user_id = $1 AND amount >= $2
			RETURNING amount
		`, userID, spinCostDiamonds).Scan(&balance)
		if err != nil {
			return nil, errors.New("diamond tidak cukup untuk spin")
		}
	} else {
		// Use free spin
		DB.Exec(`UPDATE lucky_spin_daily SET free_spins_remaining = free_spins_remaining - 1 WHERE user_id = $1`, userID)
	}

	// Increment total spins
	DB.Exec(`UPDATE lucky_spin_daily SET total_spins = total_spins + 1 WHERE user_id = $1`, userID)

	// Roll prize
	prize := rollPrize()

	// Grant reward
	grantSpinReward(userID, prize)

	// Record history
	DB.Exec(`
		INSERT INTO lucky_spin_history (user_id, prize_name, prize_type, amount)
		VALUES ($1, $2, $3, $4)
	`, userID, prize.Name, prize.PrizeType, prize.Amount)

	// Get remaining spins
	remainingSpins := 0
	if isFreeSpin {
		remainingSpins = freeSpins - 1
	}

	return &SpinResult{
		Prize:      prize,
		IsFreeSpin: isFreeSpin,
		SpinsLeft:  remainingSpins,
	}, nil
}

func grantSpinReward(userID string, prize SpinPrize) {
	switch prize.PrizeType {
	case "coins":
		DB.Exec(`UPDATE profiles SET coins = coins + $2 WHERE user_id = $1`, userID, prize.Amount)
	case "diamonds":
		DB.Exec(`UPDATE diamond_balance SET amount = amount + $2, updated_at = now() WHERE user_id = $1`, userID, prize.Amount)
	case "xp":
		DB.Exec(`UPDATE profiles SET xp = xp + $2 WHERE user_id = $1`, userID, prize.Amount)
	case "empty":
		// Nothing
	}
}

func rollPrize() SpinPrize {
	prizes := getSpinPrizes()
	totalWeight := 0
	for _, p := range prizes {
		totalWeight += p.Weight
	}
	roll := rand.Intn(totalWeight)
	cumulative := 0
	for _, p := range prizes {
		cumulative += p.Weight
		if roll < cumulative {
			return p
		}
	}
	return prizes[len(prizes)-1]
}

func getSpinPrizes() []SpinPrize {
	if DB != nil {
		rows, err := DB.Query(`
			SELECT id, name, prize_type, amount, COALESCE(item_id, ''), weight, rarity
			FROM lucky_spin_prizes WHERE is_active = true ORDER BY weight DESC
		`)
		if err == nil {
			defer rows.Close()
			var prizes []SpinPrize
			for rows.Next() {
				var p SpinPrize
				rows.Scan(&p.ID, &p.Name, &p.PrizeType, &p.Amount, &p.ItemID, &p.Weight, &p.Rarity)
				prizes = append(prizes, p)
			}
			if len(prizes) > 0 {
				return prizes
			}
		}
	}
	// Fallback defaults
	return []SpinPrize{
		{ID: "1", Name: "100 Coins", PrizeType: "coins", Amount: 100, Weight: 30, Rarity: "common"},
		{ID: "2", Name: "250 Coins", PrizeType: "coins", Amount: 250, Weight: 20, Rarity: "common"},
		{ID: "3", Name: "500 Coins", PrizeType: "coins", Amount: 500, Weight: 12, Rarity: "rare"},
		{ID: "4", Name: "1000 Coins", PrizeType: "coins", Amount: 1000, Weight: 5, Rarity: "rare"},
		{ID: "5", Name: "10 Diamonds", PrizeType: "diamonds", Amount: 10, Weight: 10, Rarity: "common"},
		{ID: "6", Name: "50 Diamonds", PrizeType: "diamonds", Amount: 50, Weight: 5, Rarity: "rare"},
		{ID: "7", Name: "100 Diamonds", PrizeType: "diamonds", Amount: 100, Weight: 2, Rarity: "epic"},
		{ID: "8", Name: "500 Diamonds", PrizeType: "diamonds", Amount: 500, Weight: 1, Rarity: "legendary"},
		{ID: "9", Name: "50 XP", PrizeType: "xp", Amount: 50, Weight: 25, Rarity: "common"},
		{ID: "10", Name: "200 XP", PrizeType: "xp", Amount: 200, Weight: 8, Rarity: "rare"},
		{ID: "11", Name: "Tidak Beruntung", PrizeType: "empty", Amount: 0, Weight: 15, Rarity: "common"},
	}
}

func doMemorySpin() *SpinResult {
	prize := rollPrize()
	return &SpinResult{Prize: prize, IsFreeSpin: true, SpinsLeft: 0}
}

// GetSpinHistory returns recent spin history
func GetSpinHistory(userID string, limit int) ([]SpinHistoryEntry, error) {
	if DB == nil {
		return nil, nil
	}
	if limit <= 0 {
		limit = 20
	}
	rows, err := DB.Query(`
		SELECT id, prize_name, prize_type, amount, spun_at
		FROM lucky_spin_history
		WHERE user_id = $1
		ORDER BY spun_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var history []SpinHistoryEntry
	for rows.Next() {
		var h SpinHistoryEntry
		rows.Scan(&h.ID, &h.PrizeName, &h.PrizeType, &h.Amount, &h.SpunAt)
		history = append(history, h)
	}
	return history, nil
}
