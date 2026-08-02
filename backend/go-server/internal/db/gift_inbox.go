package db

import "time"

// GiftInboxItem represents a received gift awaiting claim
type GiftInboxItem struct {
	ID          string     `json:"id"`
	RecipientID string     `json:"recipientId"`
	SenderID    string     `json:"senderId,omitempty"`
	SenderName  string     `json:"senderName"`
	GiftType    string     `json:"giftType"` // coins, diamonds, xp, item
	Amount      int        `json:"amount"`
	ItemID      string     `json:"itemId,omitempty"`
	Message     string     `json:"message,omitempty"`
	Claimed     bool       `json:"claimed"`
	ClaimedAt   *time.Time `json:"claimedAt,omitempty"`
	ExpiresAt   time.Time  `json:"expiresAt"`
	CreatedAt   time.Time  `json:"createdAt"`
}

// GetGiftInbox returns unclaimed gifts for a user
func GetGiftInbox(userID string) ([]GiftInboxItem, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT id, recipient_id, COALESCE(sender_id::text, ''), COALESCE(sender_name, 'System'),
		       gift_type, amount, COALESCE(item_id, ''), COALESCE(message, ''),
		       claimed, claimed_at, expires_at, created_at
		FROM gift_inbox
		WHERE recipient_id = $1 AND claimed = false AND expires_at > now()
		ORDER BY created_at DESC
		LIMIT 50
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var gifts []GiftInboxItem
	for rows.Next() {
		var g GiftInboxItem
		err := rows.Scan(&g.ID, &g.RecipientID, &g.SenderID, &g.SenderName,
			&g.GiftType, &g.Amount, &g.ItemID, &g.Message,
			&g.Claimed, &g.ClaimedAt, &g.ExpiresAt, &g.CreatedAt)
		if err != nil {
			continue
		}
		gifts = append(gifts, g)
	}
	return gifts, nil
}

// ClaimGift marks a gift as claimed and grants the reward
func ClaimGift(userID, giftID string) (*GiftInboxItem, error) {
	if DB == nil {
		return nil, nil
	}

	var g GiftInboxItem
	err := DB.QueryRow(`
		UPDATE gift_inbox SET claimed = true, claimed_at = now()
		WHERE id = $1 AND recipient_id = $2 AND claimed = false AND expires_at > now()
		RETURNING id, gift_type, amount, COALESCE(item_id, ''), COALESCE(sender_name, 'System')
	`, giftID, userID).Scan(&g.ID, &g.GiftType, &g.Amount, &g.ItemID, &g.SenderName)
	if err != nil {
		return nil, err
	}

	// Grant reward
	switch g.GiftType {
	case "coins":
		DB.Exec(`UPDATE profiles SET coins = coins + $2 WHERE user_id = $1`, userID, g.Amount)
	case "diamonds":
		DB.Exec(`UPDATE diamond_balance SET amount = amount + $2, updated_at = now() WHERE user_id = $1`, userID, g.Amount)
	case "xp":
		DB.Exec(`UPDATE profiles SET xp = xp + $2 WHERE user_id = $1`, userID, g.Amount)
	}

	g.Claimed = true
	return &g, nil
}

// ClaimAllGifts claims all pending gifts
func ClaimAllGifts(userID string) (int, error) {
	if DB == nil {
		return 0, nil
	}

	// Get all unclaimed
	gifts, err := GetGiftInbox(userID)
	if err != nil {
		return 0, err
	}
	claimed := 0
	for _, g := range gifts {
		_, err := ClaimGift(userID, g.ID)
		if err == nil {
			claimed++
		}
	}
	return claimed, nil
}

// SendToInbox adds a gift to someone's inbox (used by system/events/friends)
func SendToInbox(recipientID, senderID, senderName, giftType string, amount int, message string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO gift_inbox (recipient_id, sender_id, sender_name, gift_type, amount, message)
		VALUES ($1, NULLIF($2, ''), $3, $4, $5, $6)
	`, recipientID, senderID, senderName, giftType, amount, message)
	return err
}
