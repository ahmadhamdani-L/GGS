package db

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/lib/pq"
)

// ─── Types ───────────────────────────────────────────────────

type GiftCatalogItem struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Emoji           string  `json:"emoji"`
	Category        string  `json:"category"`
	Type            string  `json:"type"` // "gift" | "curse"
	DiamondPrice    int     `json:"diamondPrice"`
	CharmDelta      int     `json:"charmDelta"`
	PopularityDelta int     `json:"popularityDelta"`
	AnimationKey    string  `json:"animationKey"`
	BroadcastType   string  `json:"broadcastType"` // none|room|global
	Rarity          string  `json:"rarity"`
	IsLimited       bool    `json:"isLimited"`
	IsActive        bool    `json:"isActive"`
	Description     string  `json:"description"`
	SortOrder       int     `json:"sortOrder"`
}

type GiftTransaction struct {
	ID              string    `json:"id"`
	SenderID        string    `json:"senderId"`
	ReceiverID      string    `json:"receiverId"`
	GiftID          string    `json:"giftId"`
	GiftType        string    `json:"giftType"`
	DiamondSpent    int       `json:"diamondSpent"`
	CharmDelta      int       `json:"charmDelta"`
	PopularityDelta int       `json:"popularityDelta"`
	Message         string    `json:"message"`
	CreatedAt       time.Time `json:"createdAt"`
	// Joined fields
	SenderName    string `json:"senderName,omitempty"`
	ReceiverName  string `json:"receiverName,omitempty"`
	GiftName      string `json:"giftName,omitempty"`
	GiftEmoji     string `json:"giftEmoji,omitempty"`
}

type SocialStats struct {
	UserID                  string `json:"userId"`
	Charm                   int64  `json:"charm"`
	Popularity              int64  `json:"popularity"`
	GiftsSent               int    `json:"giftsSent"`
	GiftsReceived           int    `json:"giftsReceived"`
	CursesSent              int    `json:"cursesSent"`
	CursesReceived          int    `json:"cursesReceived"`
	DiamondsSpentGifts      int64  `json:"diamondsSpentGifts"`
	LegendaryGiftsSent      int    `json:"legendaryGiftsSent"`
	LegendaryGiftsReceived  int    `json:"legendaryGiftsReceived"`
	TotalGiftValueSent      int64  `json:"totalGiftValueSent"`
	TotalGiftValueReceived  int64  `json:"totalGiftValueReceived"`
}

type DiamondBalance struct {
	UserID     string `json:"userId"`
	Amount     int64  `json:"amount"`
	TotalSpent int64  `json:"totalSpent"`
}

type ActivityFeedItem struct {
	ID            string    `json:"id"`
	EventType     string    `json:"eventType"`
	SenderID      string    `json:"senderId"`
	ReceiverID    string    `json:"receiverId"`
	GiftID        string    `json:"giftId"`
	SenderName    string    `json:"senderName"`
	ReceiverName  string    `json:"receiverName"`
	GiftName      string    `json:"giftName"`
	GiftEmoji     string    `json:"giftEmoji"`
	BroadcastType string    `json:"broadcastType"`
	Message       string    `json:"message"`
	CreatedAt     time.Time `json:"createdAt"`
}

type GiftStreak struct {
	UserID            string    `json:"userId"`
	CurrentStreak     int       `json:"currentStreak"`
	LongestStreak     int       `json:"longestStreak"`
	LastGiftDate      *string   `json:"lastGiftDate"`
	BonusMultiplier   float64   `json:"bonusMultiplier"`
}

type SendGiftInput struct {
	IdempotencyKey string
	SenderID       string
	ReceiverID     string
	GiftID         string
	Message        string // max 50 chars
}

type SendGiftResult struct {
	Transaction     *GiftTransaction
	SenderDiamonds  int64
	ReceiverCharm   int64
	SenderPopularity int64
	ComboTriggered  bool
	ComboCount      int
	StreakBonus     float64
	Events          []string // event names emitted
}

// ─── Diamond Balance ─────────────────────────────────────────

func GetDiamondBalance(userID string) (*DiamondBalance, error) {
	if DB == nil {
		// Memory fallback: every user starts with 100 diamonds (matches migration default)
		if Mem != nil {
			return Mem.GetDiamondBalance(userID), nil
		}
		return &DiamondBalance{UserID: userID, Amount: 100}, nil
	}
	b := &DiamondBalance{}
	err := DB.QueryRow(`
		SELECT user_id, COALESCE(amount, 100), COALESCE(total_spent, 0) FROM diamond_balance WHERE user_id = $1
	`, userID).Scan(&b.UserID, &b.Amount, &b.TotalSpent)
	if errors.Is(err, sql.ErrNoRows) {
		// Auto-create on first read with 100 default diamonds
		DB.Exec(`INSERT INTO diamond_balance (user_id, amount) VALUES ($1, 100) ON CONFLICT DO NOTHING`, userID)
		return &DiamondBalance{UserID: userID, Amount: 100}, nil
	}
	if err != nil {
		// Fallback: try without total_spent (column might not exist yet)
		err2 := DB.QueryRow(`SELECT user_id, COALESCE(amount, 100) FROM diamond_balance WHERE user_id = $1`, userID).Scan(&b.UserID, &b.Amount)
		if err2 == nil {
			return b, nil
		}
		// If still fails, create record
		DB.Exec(`INSERT INTO diamond_balance (user_id, amount) VALUES ($1, 100) ON CONFLICT DO NOTHING`, userID)
		return &DiamondBalance{UserID: userID, Amount: 100}, nil
	}
	return b, nil
}

func TopUpDiamonds(userID string, amount int64, refID, reason string) (int64, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.TopUpDiamonds(userID, amount), nil
		}
		return 0, nil
	}
	tx, err := DB.Begin()
	if err != nil {
		return 0, err
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Idempotency: check if refID already processed
	if refID != "" {
		var exists bool
		tx.QueryRow(`SELECT EXISTS(SELECT 1 FROM diamond_transactions WHERE ref_id=$1)`, refID).Scan(&exists)
		if exists {
			tx.Rollback()
			return 0, errors.New("transaction already processed")
		}
	}

	var newBalance int64
	err = tx.QueryRow(`
		INSERT INTO diamond_balance (user_id, amount)
		VALUES ($1, $2)
		ON CONFLICT (user_id) DO UPDATE
			SET amount = diamond_balance.amount + $2, updated_at = now()
		RETURNING amount
	`, userID, amount).Scan(&newBalance)
	if err != nil {
		return 0, err
	}

	_, err = tx.Exec(`
		INSERT INTO diamond_transactions (user_id, amount, balance_after, reason, ref_id)
		VALUES ($1, $2, $3, $4, $5)
	`, userID, amount, newBalance, reason, nullStr(refID))
	if err != nil {
		return 0, err
	}
	return newBalance, tx.Commit()
}

// ─── Gift Catalog ────────────────────────────────────────────

func GetGiftCatalog(giftType string) ([]GiftCatalogItem, error) {
	if DB == nil {
		return nil, nil
	}
	query := `
		SELECT id, name, emoji, category, type, diamond_price,
		       charm_delta, popularity_delta, animation_key,
		       broadcast_type, rarity, is_limited, is_active,
		       COALESCE(description,''), sort_order
		FROM gift_catalog
		WHERE is_active = true`
	args := []interface{}{}
	if giftType == "gift" || giftType == "curse" {
		query += ` AND type = $1`
		args = append(args, giftType)
	}
	query += ` ORDER BY sort_order ASC`

	rows, err := DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []GiftCatalogItem
	for rows.Next() {
		var it GiftCatalogItem
		if err := rows.Scan(&it.ID, &it.Name, &it.Emoji, &it.Category,
			&it.Type, &it.DiamondPrice, &it.CharmDelta, &it.PopularityDelta,
			&it.AnimationKey, &it.BroadcastType, &it.Rarity, &it.IsLimited,
			&it.IsActive, &it.Description, &it.SortOrder); err == nil {
			items = append(items, it)
		}
	}
	return items, nil
}

func GetGiftByID(giftID string) (*GiftCatalogItem, error) {
	if DB == nil {
		return nil, errors.New("db unavailable")
	}
	it := &GiftCatalogItem{}
	err := DB.QueryRow(`
		SELECT id, name, emoji, category, type, diamond_price,
		       charm_delta, popularity_delta, animation_key,
		       broadcast_type, rarity, is_limited, is_active,
		       COALESCE(description,''), sort_order
		FROM gift_catalog WHERE id = $1 AND is_active = true
	`, giftID).Scan(&it.ID, &it.Name, &it.Emoji, &it.Category,
		&it.Type, &it.DiamondPrice, &it.CharmDelta, &it.PopularityDelta,
		&it.AnimationKey, &it.BroadcastType, &it.Rarity, &it.IsLimited,
		&it.IsActive, &it.Description, &it.SortOrder)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, errors.New("gift not found")
	}
	return it, err
}

// ─── SendGift (atomic transaction) ───────────────────────────
// All checks + writes happen in one DB transaction.
// Returns detailed result including events to emit.

func SendGift(input SendGiftInput) (*SendGiftResult, error) {
	if DB == nil {
		return nil, errors.New("db unavailable")
	}

	// Anti-abuse: self-gift
	if input.SenderID == input.ReceiverID {
		return nil, errors.New("cannot send gift to yourself")
	}
	// Truncate message
	if len(input.Message) > 50 {
		input.Message = input.Message[:50]
	}

	// Fetch gift catalog item
	gift, err := GetGiftByID(input.GiftID)
	if err != nil {
		return nil, err
	}

	// Anti-abuse: check hourly rate limit (max 50 sends/hour/user)
	if err := checkGiftRateLimit(input.SenderID); err != nil {
		return nil, err
	}

	tx, err := DB.Begin()
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Idempotency: prevent double-send
	var exists bool
	tx.QueryRow(`SELECT EXISTS(SELECT 1 FROM gift_transactions WHERE idempotency_key=$1)`,
		input.IdempotencyKey).Scan(&exists)
	if exists {
		tx.Rollback()
		return nil, errors.New("duplicate transaction")
	}

	// Deduct diamonds from sender (with balance check)
	var newDiamonds int64
	err = tx.QueryRow(`
		UPDATE diamond_balance SET
			amount = amount - $2,
			total_spent = total_spent + $2,
			updated_at = now()
		WHERE user_id = $1 AND amount >= $2
		RETURNING amount
	`, input.SenderID, gift.DiamondPrice).Scan(&newDiamonds)
	if errors.Is(err, sql.ErrNoRows) {
		tx.Rollback()
		return nil, errors.New("diamond tidak cukup")
	}
	if err != nil {
		return nil, fmt.Errorf("deduct diamonds: %w", err)
	}

	// Record diamond transaction
	_, err = tx.Exec(`
		INSERT INTO diamond_transactions (user_id, amount, balance_after, reason, ref_id)
		VALUES ($1, $2, $3, $4, $5)
	`, input.SenderID, -gift.DiamondPrice, newDiamonds,
		"gift_"+gift.ID, input.IdempotencyKey)
	if err != nil {
		return nil, fmt.Errorf("diamond tx: %w", err)
	}

	// Insert gift transaction
	var txID string
	err = tx.QueryRow(`
		INSERT INTO gift_transactions
			(idempotency_key, sender_id, receiver_id, gift_id, gift_type,
			 diamond_spent, charm_delta, popularity_delta, message)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		RETURNING id
	`, input.IdempotencyKey, input.SenderID, input.ReceiverID,
		gift.ID, gift.Type, gift.DiamondPrice,
		gift.CharmDelta, gift.PopularityDelta, nullStr(input.Message)).Scan(&txID)
	if err != nil {
		return nil, fmt.Errorf("gift tx: %w", err)
	}

	// Update receiver charm (ensure social_stats row exists)
	tx.Exec(`INSERT INTO social_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, input.ReceiverID)
	tx.Exec(`INSERT INTO social_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, input.SenderID)

	var newCharm int64
	err = tx.QueryRow(`
		UPDATE social_stats SET
			charm = GREATEST(0, charm + $2),
			gifts_received = gifts_received + CASE WHEN $3 = 'gift' THEN 1 ELSE 0 END,
			curses_received = curses_received + CASE WHEN $3 = 'curse' THEN 1 ELSE 0 END,
			total_gift_value_received = total_gift_value_received + $4,
			legendary_gifts_received = legendary_gifts_received + CASE WHEN $5 = 'legendary' THEN 1 ELSE 0 END,
			updated_at = now()
		WHERE user_id = $1
		RETURNING charm
	`, input.ReceiverID, gift.CharmDelta, gift.Type, gift.DiamondPrice, gift.Rarity).Scan(&newCharm)
	if err != nil {
		return nil, fmt.Errorf("update receiver charm: %w", err)
	}

	// Update sender popularity + stats
	var newPop int64
	err = tx.QueryRow(`
		UPDATE social_stats SET
			popularity = popularity + $2,
			gifts_sent = gifts_sent + CASE WHEN $3 = 'gift' THEN 1 ELSE 0 END,
			curses_sent = curses_sent + CASE WHEN $3 = 'curse' THEN 1 ELSE 0 END,
			diamonds_spent_gifts = diamonds_spent_gifts + $4,
			legendary_gifts_sent = legendary_gifts_sent + CASE WHEN $5 = 'legendary' THEN 1 ELSE 0 END,
			total_gift_value_sent = total_gift_value_sent + $4,
			updated_at = now()
		WHERE user_id = $1
		RETURNING popularity
	`, input.SenderID, gift.PopularityDelta, gift.Type, gift.DiamondPrice, gift.Rarity).Scan(&newPop)
	if err != nil {
		return nil, fmt.Errorf("update sender popularity: %w", err)
	}

	// Charm ledger entry
	tx.Exec(`
		INSERT INTO charm_ledger (user_id, delta, balance, reason, ref_id)
		VALUES ($1, $2, $3, $4, $5)
	`, input.ReceiverID, gift.CharmDelta, newCharm, "gift_"+gift.ID, txID)

	// Popularity ledger entry
	tx.Exec(`
		INSERT INTO popularity_ledger (user_id, delta, balance, reason, ref_id)
		VALUES ($1, $2, $3, $4, $5)
	`, input.SenderID, gift.PopularityDelta, newPop, "gift_sent_"+gift.ID, txID)

	// Sync profiles.charm + profiles.popularity
	tx.Exec(`UPDATE profiles SET charm = $2 WHERE user_id = $1`, input.ReceiverID, newCharm)
	tx.Exec(`UPDATE profiles SET popularity = $2 WHERE user_id = $1`, input.SenderID, newPop)

	// Sync player_stats gift counters
	tx.Exec(`
		UPDATE player_stats SET
			gifts_sent = gifts_sent + CASE WHEN $2 = 'gift' THEN 1 ELSE 0 END,
			curses_sent = curses_sent + CASE WHEN $2 = 'curse' THEN 1 ELSE 0 END,
			legendary_gifts_sent = legendary_gifts_sent + CASE WHEN $3 = 'legendary' THEN 1 ELSE 0 END,
			diamonds_spent = diamonds_spent + $4
		WHERE user_id = $1
	`, input.SenderID, gift.Type, gift.Rarity, gift.DiamondPrice)
	tx.Exec(`
		UPDATE player_stats SET
			gifts_received = gifts_received + CASE WHEN $2 = 'gift' THEN 1 ELSE 0 END
		WHERE user_id = $1
	`, input.ReceiverID, gift.Type)

	// Gift album (sender sent, receiver received)
	tx.Exec(`
		INSERT INTO gift_album (user_id, gift_id, role, count)
		VALUES ($1, $2, 'sender', 1)
		ON CONFLICT (user_id, gift_id, role) DO UPDATE SET count = gift_album.count + 1
	`, input.SenderID, gift.ID)
	tx.Exec(`
		INSERT INTO gift_album (user_id, gift_id, role, count)
		VALUES ($1, $2, 'receiver', 1)
		ON CONFLICT (user_id, gift_id, role) DO UPDATE SET count = gift_album.count + 1
	`, input.ReceiverID, gift.ID)

	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}

	// Post-commit: gift streak (non-blocking)
	streak := updateGiftStreak(input.SenderID)

	// Post-commit: combo check
	comboCount, comboTriggered := checkAndUpdateCombo(input.GiftID, input.ReceiverID, input.SenderID)

	result := &SendGiftResult{
		Transaction: &GiftTransaction{
			ID: txID, SenderID: input.SenderID, ReceiverID: input.ReceiverID,
			GiftID: gift.ID, GiftType: gift.Type,
			DiamondSpent: gift.DiamondPrice, CharmDelta: gift.CharmDelta,
			PopularityDelta: gift.PopularityDelta, Message: input.Message,
			CreatedAt: time.Now(), GiftName: gift.Name, GiftEmoji: gift.Emoji,
		},
		SenderDiamonds:   newDiamonds,
		ReceiverCharm:    newCharm,
		SenderPopularity: newPop,
		ComboTriggered:   comboTriggered,
		ComboCount:       comboCount,
		StreakBonus:       streak.BonusMultiplier,
		Events:           buildEventList(gift, comboTriggered),
	}

	// Record analytics (async, non-blocking)
	go recordGiftAnalytics(gift.ID, gift.Type, int64(gift.DiamondPrice))

	// Update social leaderboard cache (async)
	go updateSocialLeaderboard(input.SenderID, input.ReceiverID, gift)

	return result, nil
}

// ─── Anti-Abuse: Rate Limit ───────────────────────────────────

func checkGiftRateLimit(userID string) error {
	if DB == nil {
		return nil
	}
	// Hourly window key: YYYYMMDDHH
	windowKey := time.Now().UTC().Format("2006010215") + userID
	var count int
	DB.QueryRow(`
		SELECT count FROM gift_rate_limit WHERE user_id=$1 AND window_key=$2
	`, userID, windowKey).Scan(&count)
	if count >= 50 {
		// Log potential abuse
		DB.Exec(`
			INSERT INTO gift_abuse_log (user_id, reason, detail)
			VALUES ($1, 'rate_limit_exceeded', $2)
		`, userID, fmt.Sprintf(`{"windowKey":"%s","count":%d}`, windowKey, count))
		return errors.New("terlalu banyak pengiriman, coba lagi nanti")
	}
	DB.Exec(`
		INSERT INTO gift_rate_limit (user_id, window_key, count)
		VALUES ($1, $2, 1)
		ON CONFLICT (user_id, window_key) DO UPDATE SET count = gift_rate_limit.count + 1
	`, userID, windowKey)
	return nil
}

// ─── Gift Streak ──────────────────────────────────────────────

func updateGiftStreak(userID string) GiftStreak {
	if DB == nil {
		return GiftStreak{BonusMultiplier: 1.0}
	}
	today := time.Now().UTC().Format("2006-01-02")
	var s GiftStreak
	err := DB.QueryRow(`
		SELECT user_id, current_streak, longest_streak,
		       TO_CHAR(last_gift_date,'YYYY-MM-DD'), streak_bonus_multiplier
		FROM gift_streaks WHERE user_id = $1
	`, userID).Scan(&s.UserID, &s.CurrentStreak, &s.LongestStreak,
		&s.LastGiftDate, &s.BonusMultiplier)

	if errors.Is(err, sql.ErrNoRows) || s.UserID == "" {
		DB.Exec(`
			INSERT INTO gift_streaks (user_id, current_streak, longest_streak, last_gift_date, streak_bonus_multiplier)
			VALUES ($1, 1, 1, $2, 1.1)
			ON CONFLICT (user_id) DO NOTHING
		`, userID, today)
		return GiftStreak{UserID: userID, CurrentStreak: 1, LongestStreak: 1, BonusMultiplier: 1.1}
	}

	yesterday := time.Now().UTC().AddDate(0, 0, -1).Format("2006-01-02")
	newStreak := 1
	if s.LastGiftDate != nil && *s.LastGiftDate == yesterday {
		newStreak = s.CurrentStreak + 1
	} else if s.LastGiftDate != nil && *s.LastGiftDate == today {
		return s // already counted today
	}
	// Bonus: +5% per consecutive day, max 2x
	multiplier := 1.0 + float64(newStreak)*0.05
	if multiplier > 2.0 {
		multiplier = 2.0
	}
	newLongest := s.LongestStreak
	if newStreak > newLongest {
		newLongest = newStreak
	}
	DB.Exec(`
		UPDATE gift_streaks SET
			current_streak = $2, longest_streak = $3,
			last_gift_date = $4, streak_bonus_multiplier = $5, updated_at = now()
		WHERE user_id = $1
	`, userID, newStreak, newLongest, today, multiplier)

	return GiftStreak{UserID: userID, CurrentStreak: newStreak, LongestStreak: newLongest, BonusMultiplier: multiplier}
}

// ─── Gift Combo ───────────────────────────────────────────────

func checkAndUpdateCombo(giftID, receiverID, senderID string) (int, bool) {
	if DB == nil {
		return 1, false
	}
	now := time.Now().UTC()
	windowEnd := now.Add(5 * time.Minute)

	// Find active combo window for this gift+receiver
	var comboID string
	var senderIDs []string
	var comboCount int
	err := DB.QueryRow(`
		SELECT id, sender_ids, combo_count FROM gift_combo_events
		WHERE gift_id=$1 AND receiver_id=$2 AND window_end > $3 AND triggered=false
		ORDER BY window_start DESC LIMIT 1
	`, giftID, receiverID, now).Scan(&comboID, pq_array(&senderIDs), &comboCount)

	if errors.Is(err, sql.ErrNoRows) {
		// New combo window
		DB.Exec(`
			INSERT INTO gift_combo_events (gift_id, receiver_id, sender_ids, combo_count, window_start, window_end)
			VALUES ($1, $2, $3, 1, $4, $5)
		`, giftID, receiverID, pq_array([]string{senderID}), now, windowEnd)
		return 1, false
	}

	// Already in window — add sender if not already there
	for _, s := range senderIDs {
		if s == senderID {
			return comboCount, false // same sender again, no new combo increment
		}
	}
	senderIDs = append(senderIDs, senderID)
	newCount := comboCount + 1
	triggered := newCount >= 3 // combo triggers at 3+ unique senders

	DB.Exec(`
		UPDATE gift_combo_events SET
			sender_ids = $2, combo_count = $3, triggered = $4
		WHERE id = $1
	`, comboID, pq_array(senderIDs), newCount, triggered)

	return newCount, triggered
}

// ─── Social Stats ─────────────────────────────────────────────

func GetSocialStats(userID string) (*SocialStats, error) {
	if DB == nil {
		return &SocialStats{UserID: userID}, nil
	}
	DB.Exec(`INSERT INTO social_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, userID)
	s := &SocialStats{}
	err := DB.QueryRow(`
		SELECT user_id, charm, popularity, gifts_sent, gifts_received,
		       curses_sent, curses_received, diamonds_spent_gifts,
		       legendary_gifts_sent, legendary_gifts_received,
		       total_gift_value_sent, total_gift_value_received
		FROM social_stats WHERE user_id = $1
	`, userID).Scan(&s.UserID, &s.Charm, &s.Popularity,
		&s.GiftsSent, &s.GiftsReceived, &s.CursesSent, &s.CursesReceived,
		&s.DiamondsSpentGifts, &s.LegendaryGiftsSent, &s.LegendaryGiftsReceived,
		&s.TotalGiftValueSent, &s.TotalGiftValueReceived)
	return s, err
}

// ─── Activity Feed ────────────────────────────────────────────

func CreateActivityFeedEntry(txID string, gift *GiftCatalogItem,
	senderID, receiverID, senderName, receiverName, message, eventType string) {
	if DB == nil {
		return
	}
	DB.Exec(`
		INSERT INTO social_activity_feed
			(event_type, sender_id, receiver_id, gift_id,
			 sender_name, receiver_name, gift_name, gift_emoji,
			 broadcast_type, message)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
	`, eventType, senderID, receiverID, gift.ID,
		senderName, receiverName, gift.Name, gift.Emoji,
		gift.BroadcastType, nullStr(message))
}

func GetActivityFeed(limit int, scope string) ([]ActivityFeedItem, error) {
	if DB == nil {
		return nil, nil
	}
	query := `
		SELECT id, event_type,
		       COALESCE(sender_id::text,''), COALESCE(receiver_id::text,''),
		       COALESCE(gift_id,''), COALESCE(sender_name,''), COALESCE(receiver_name,''),
		       COALESCE(gift_name,''), COALESCE(gift_emoji,''),
		       broadcast_type, COALESCE(message,''), created_at
		FROM social_activity_feed`
	if scope == "global" {
		query += ` WHERE broadcast_type IN ('room','global')`
	}
	query += ` ORDER BY created_at DESC LIMIT $1`

	rows, err := DB.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []ActivityFeedItem
	for rows.Next() {
		var it ActivityFeedItem
		if err := rows.Scan(&it.ID, &it.EventType, &it.SenderID, &it.ReceiverID,
			&it.GiftID, &it.SenderName, &it.ReceiverName, &it.GiftName, &it.GiftEmoji,
			&it.BroadcastType, &it.Message, &it.CreatedAt); err == nil {
			items = append(items, it)
		}
	}
	return items, nil
}

func GetUserActivityFeed(userID string, limit int) ([]ActivityFeedItem, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT id, event_type,
		       COALESCE(sender_id::text,''), COALESCE(receiver_id::text,''),
		       COALESCE(gift_id,''), COALESCE(sender_name,''), COALESCE(receiver_name,''),
		       COALESCE(gift_name,''), COALESCE(gift_emoji,''),
		       broadcast_type, COALESCE(message,''), created_at
		FROM social_activity_feed
		WHERE receiver_id = $1 OR sender_id = $1
		ORDER BY created_at DESC LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []ActivityFeedItem
	for rows.Next() {
		var it ActivityFeedItem
		if err := rows.Scan(&it.ID, &it.EventType, &it.SenderID, &it.ReceiverID,
			&it.GiftID, &it.SenderName, &it.ReceiverName, &it.GiftName, &it.GiftEmoji,
			&it.BroadcastType, &it.Message, &it.CreatedAt); err == nil {
			items = append(items, it)
		}
	}
	return items, nil
}

// ─── Gift History ─────────────────────────────────────────────

func GetGiftHistory(userID string, role string, limit int) ([]GiftTransaction, error) {
	if DB == nil {
		return nil, nil
	}
	var filter string
	var args []interface{}
	args = append(args, userID)
	if role == "sent" {
		filter = "WHERE gt.sender_id = $1"
	} else if role == "received" {
		filter = "WHERE gt.receiver_id = $1"
	} else {
		filter = "WHERE gt.sender_id = $1 OR gt.receiver_id = $1"
	}
	args = append(args, limit)

	rows, err := DB.Query(fmt.Sprintf(`
		SELECT gt.id, gt.sender_id, gt.receiver_id, gt.gift_id, gt.gift_type,
		       gt.diamond_spent, gt.charm_delta, gt.popularity_delta,
		       COALESCE(gt.message,''), gt.created_at,
		       sp.display_name, rp.display_name,
		       gc.name, gc.emoji
		FROM gift_transactions gt
		JOIN profiles sp ON sp.user_id = gt.sender_id
		JOIN profiles rp ON rp.user_id = gt.receiver_id
		JOIN gift_catalog gc ON gc.id = gt.gift_id
		%s
		ORDER BY gt.created_at DESC LIMIT $2
	`, filter), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var txs []GiftTransaction
	for rows.Next() {
		var t GiftTransaction
		if err := rows.Scan(&t.ID, &t.SenderID, &t.ReceiverID, &t.GiftID, &t.GiftType,
			&t.DiamondSpent, &t.CharmDelta, &t.PopularityDelta, &t.Message, &t.CreatedAt,
			&t.SenderName, &t.ReceiverName, &t.GiftName, &t.GiftEmoji); err == nil {
			txs = append(txs, t)
		}
	}
	return txs, nil
}

// ─── Gift Album ───────────────────────────────────────────────

type GiftAlbumEntry struct {
	GiftID    string `json:"giftId"`
	GiftName  string `json:"giftName"`
	GiftEmoji string `json:"giftEmoji"`
	Rarity    string `json:"rarity"`
	Role      string `json:"role"`
	Count     int    `json:"count"`
	FirstAt   time.Time `json:"firstAt"`
}

func GetGiftAlbum(userID string) ([]GiftAlbumEntry, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT ga.gift_id, gc.name, gc.emoji, gc.rarity, ga.role, ga.count, ga.first_at
		FROM gift_album ga
		JOIN gift_catalog gc ON gc.id = ga.gift_id
		WHERE ga.user_id = $1
		ORDER BY ga.first_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var entries []GiftAlbumEntry
	for rows.Next() {
		var e GiftAlbumEntry
		if err := rows.Scan(&e.GiftID, &e.GiftName, &e.GiftEmoji,
			&e.Rarity, &e.Role, &e.Count, &e.FirstAt); err == nil {
			entries = append(entries, e)
		}
	}
	return entries, nil
}

// ─── Social Leaderboard ───────────────────────────────────────

type SocialLeaderboardEntry struct {
	Rank        int    `json:"rank"`
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	AvatarID    int    `json:"avatarId"`
	Score       int64  `json:"score"`
	BoardType   string `json:"boardType"`
	Period      string `json:"period"`
}

func GetSocialLeaderboard(boardType, period string, limit int) ([]SocialLeaderboardEntry, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT sl.rank, sl.user_id, sl.display_name, COALESCE(sl.avatar_id,1), sl.score
		FROM social_leaderboard sl
		WHERE sl.board_type = $1 AND sl.period = $2 AND sl.rank IS NOT NULL
		ORDER BY sl.rank ASC LIMIT $3
	`, boardType, period, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var entries []SocialLeaderboardEntry
	for rows.Next() {
		var e SocialLeaderboardEntry
		e.BoardType = boardType
		e.Period = period
		if err := rows.Scan(&e.Rank, &e.UserID, &e.DisplayName, &e.AvatarID, &e.Score); err == nil {
			entries = append(entries, e)
		}
	}
	return entries, nil
}

func updateSocialLeaderboard(senderID, receiverID string, gift *GiftCatalogItem) {
	if DB == nil {
		return
	}
	// Upsert sender popularity score
	DB.Exec(`
		INSERT INTO social_leaderboard (user_id, board_type, period, score, display_name, avatar_id)
		SELECT $1, 'popularity', p.val, ss.popularity,
		       pr.display_name, pr.avatar_id
		FROM social_stats ss
		JOIN profiles pr ON pr.user_id = ss.user_id
		CROSS JOIN (VALUES ('weekly'),('monthly'),('alltime')) AS p(val)
		WHERE ss.user_id = $1
		ON CONFLICT (user_id, board_type, period) DO UPDATE
			SET score = EXCLUDED.score, display_name = EXCLUDED.display_name, updated_at = now()
	`, senderID)
	// Upsert receiver charm score
	DB.Exec(`
		INSERT INTO social_leaderboard (user_id, board_type, period, score, display_name, avatar_id)
		SELECT $1, 'charm', p.val, ss.charm,
		       pr.display_name, pr.avatar_id
		FROM social_stats ss
		JOIN profiles pr ON pr.user_id = ss.user_id
		CROSS JOIN (VALUES ('weekly'),('monthly'),('alltime')) AS p(val)
		WHERE ss.user_id = $1
		ON CONFLICT (user_id, board_type, period) DO UPDATE
			SET score = EXCLUDED.score, updated_at = now()
	`, receiverID)
	// Re-rank (just top 100 for efficiency)
	for _, board := range []string{"charm", "popularity"} {
		for _, period := range []string{"weekly", "monthly", "alltime"} {
			DB.Exec(`
				UPDATE social_leaderboard sl SET rank = r.new_rank
				FROM (
					SELECT user_id, ROW_NUMBER() OVER (ORDER BY score DESC) AS new_rank
					FROM social_leaderboard
					WHERE board_type=$1 AND period=$2
				) r
				WHERE sl.user_id = r.user_id AND sl.board_type=$1 AND sl.period=$2
			`, board, period)
		}
	}
}

// ─── Analytics ───────────────────────────────────────────────

func recordGiftAnalytics(giftID, giftType string, diamondRevenue int64) {
	if DB == nil {
		return
	}
	DB.Exec(`
		INSERT INTO gift_analytics (event_date, gift_id, gift_type, transaction_count, diamond_revenue)
		VALUES (CURRENT_DATE, $1, $2, 1, $3)
		ON CONFLICT (event_date, gift_id) DO UPDATE SET
			transaction_count = gift_analytics.transaction_count + 1,
			diamond_revenue   = gift_analytics.diamond_revenue + EXCLUDED.diamond_revenue
	`, giftID, giftType, diamondRevenue)
}

func GetGiftAnalytics(days int) ([]map[string]interface{}, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT ga.event_date, ga.gift_id, gc.name, gc.emoji, ga.gift_type,
		       ga.transaction_count, ga.diamond_revenue
		FROM gift_analytics ga
		JOIN gift_catalog gc ON gc.id = ga.gift_id
		WHERE ga.event_date >= CURRENT_DATE - INTERVAL '1 day' * $1
		ORDER BY ga.diamond_revenue DESC
		LIMIT 50
	`, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var results []map[string]interface{}
	for rows.Next() {
		var date, giftID, name, emoji, giftType string
		var count int
		var revenue int64
		if err := rows.Scan(&date, &giftID, &name, &emoji, &giftType, &count, &revenue); err == nil {
			results = append(results, map[string]interface{}{
				"date": date, "giftId": giftID, "name": name, "emoji": emoji,
				"type": giftType, "transactions": count, "revenue": revenue,
			})
		}
	}
	return results, nil
}

// ─── Helpers ─────────────────────────────────────────────────

func nullStr(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

// pq_array wraps a string slice for PostgreSQL text[] parameter binding
func pq_array(v interface{}) interface{} {
	switch val := v.(type) {
	case []string:
		return pq.Array(val)
	case *[]string:
		return pq.Array(*val)
	default:
		return v
	}
}

func buildEventList(gift *GiftCatalogItem, comboTriggered bool) []string {
	events := []string{"GiftSent", "CharmUpdated", "PopularityUpdated"}
	if gift.Type == "curse" {
		events[0] = "CurseSent"
	}
	if gift.Rarity == "legendary" {
		events = append(events, "LegendaryGiftSent")
	}
	if comboTriggered {
		events = append(events, "ComboTriggered")
	}
	if gift.BroadcastType == "global" {
		events = append(events, "GlobalBroadcast")
	}
	return events
}

// GetDisplayName returns the display_name for a user (used by handlers)
func GetDisplayName(userID string) (string, error) {
	if DB == nil {
		return "Player", nil
	}
	var name string
	err := DB.QueryRow(`SELECT display_name FROM profiles WHERE user_id=$1`, userID).Scan(&name)
	return name, err
}
