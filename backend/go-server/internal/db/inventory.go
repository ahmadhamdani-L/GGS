package db

// ShopItem represents an item available in the shop
type ShopItem struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Emoji       string `json:"emoji"`
	Category    string `json:"category"`
	Price       int    `json:"price"`
	IsActive    bool   `json:"isActive"`
}

// GetShopItems returns all active shop items
func GetShopItems() ([]ShopItem, error) {
	if DB == nil {
		// Return seed data for in-memory mode
		return []ShopItem{
			{ID: "border_gold", Name: "Gold Border", Description: "Border emas untuk avatar", Emoji: "✨", Category: "borders", Price: 200, IsActive: true},
			{ID: "border_fire", Name: "Fire Border", Description: "Border api untuk avatar", Emoji: "🔥", Category: "borders", Price: 300, IsActive: true},
			{ID: "border_ice", Name: "Ice Border", Description: "Border es untuk avatar", Emoji: "❄️", Category: "borders", Price: 300, IsActive: true},
			{ID: "emote_laugh", Name: "Emote: Laugh", Description: "Emote tertawa in-game", Emoji: "😂", Category: "emotes", Price: 100, IsActive: true},
			{ID: "emote_think", Name: "Emote: Think", Description: "Emote berpikir in-game", Emoji: "🤔", Category: "emotes", Price: 100, IsActive: true},
			{ID: "emote_sus", Name: "Emote: Sus", Description: "Emote curiga in-game", Emoji: "🧐", Category: "emotes", Price: 150, IsActive: true},
			{ID: "theme_blood", Name: "Blood Moon", Description: "Tema gelap blood moon", Emoji: "🌑", Category: "themes", Price: 500, IsActive: true},
			{ID: "theme_forest", Name: "Enchanted Forest", Description: "Tema hutan mistis", Emoji: "🌲", Category: "themes", Price: 500, IsActive: true},
		}, nil
	}
	rows, err := DB.Query(`
		SELECT id, name, COALESCE(description, ''), COALESCE(emoji, ''), category, price, is_active
		FROM shop_items
		WHERE is_active = true
		ORDER BY category, price
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []ShopItem
	for rows.Next() {
		var i ShopItem
		if err := rows.Scan(&i.ID, &i.Name, &i.Description, &i.Emoji, &i.Category, &i.Price, &i.IsActive); err != nil {
			continue
		}
		items = append(items, i)
	}
	return items, nil
}

// CheckOwnership returns true if user owns the item
func CheckOwnership(userID, itemID string) bool {
	if DB == nil {
		return false
	}
	var count int
	DB.QueryRow(`SELECT COUNT(*) FROM user_purchases WHERE user_id = $1 AND item_id = $2`, userID, itemID).Scan(&count)
	return count > 0
}

// EquippedItems represents a player's active cosmetics
type EquippedItems struct {
	UserID   string  `json:"userId"`
	FrameID  *string `json:"frameId"`
	TitleID  *string `json:"titleId"`
	EmoteSet *string `json:"emoteSetId"`
	BubbleID *string `json:"bubbleId"`
	ThemeID  *string `json:"themeId"`
}

// OwnedItem represents an item the player has purchased
type OwnedItem struct {
	ItemID      string `json:"itemId"`
	Name        string `json:"name"`
	Emoji       string `json:"emoji"`
	Category    string `json:"category"`
	PurchasedAt string `json:"purchasedAt"`
}

// GetInventory returns all items owned by a user
func GetInventory(userID string) ([]OwnedItem, error) {
	if DB == nil {
		return []OwnedItem{}, nil
	}
	rows, err := DB.Query(`
		SELECT s.id, s.name, s.emoji, s.category, up.purchased_at
		FROM user_purchases up
		JOIN shop_items s ON s.id = up.item_id
		WHERE up.user_id = $1
		ORDER BY up.purchased_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []OwnedItem
	for rows.Next() {
		var i OwnedItem
		rows.Scan(&i.ItemID, &i.Name, &i.Emoji, &i.Category, &i.PurchasedAt)
		items = append(items, i)
	}
	return items, nil
}

// GetEquipped returns active equipped items
func GetEquipped(userID string) (*EquippedItems, error) {
	if DB == nil {
		return &EquippedItems{UserID: userID}, nil
	}
	e := &EquippedItems{UserID: userID}
	DB.QueryRow(`SELECT frame_id, title_id, emote_set_id, bubble_id, theme_id
		FROM equipped_items WHERE user_id = $1`, userID).
		Scan(&e.FrameID, &e.TitleID, &e.EmoteSet, &e.BubbleID, &e.ThemeID)
	return e, nil
}

// EquipItem sets an item as active in the appropriate slot
func EquipItem(userID, itemID, category string) error {
	if DB == nil {
		return nil
	}
	col := categoryToColumn(category)
	if col == "" {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO equipped_items (user_id, `+col+`) VALUES ($1, $2)
		ON CONFLICT (user_id) DO UPDATE SET `+col+` = $2, updated_at = now()
	`, userID, itemID)
	return err
}

// UnequipItem clears a slot
func UnequipItem(userID, category string) error {
	if DB == nil {
		return nil
	}
	col := categoryToColumn(category)
	if col == "" {
		return nil
	}
	_, err := DB.Exec(`UPDATE equipped_items SET `+col+` = NULL, updated_at = now() WHERE user_id = $1`, userID)
	return err
}

// PurchaseItem buys an item (deducts coins, adds to inventory)
func PurchaseItem(userID, itemID string) error {
	if DB == nil {
		return nil
	}
	// Get item price
	var price int
	err := DB.QueryRow(`SELECT price FROM shop_items WHERE id = $1 AND is_active = true`, itemID).Scan(&price)
	if err != nil {
		return err
	}
	// Check coins
	var coins int
	DB.QueryRow(`SELECT coins FROM profiles WHERE user_id = $1`, userID).Scan(&coins)
	if coins < price {
		return errInsufficientCoins
	}
	// Deduct and insert
	DB.Exec(`UPDATE profiles SET coins = coins - $2 WHERE user_id = $1`, userID, price)
	DB.Exec(`INSERT INTO user_purchases (user_id, item_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, itemID)
	return nil
}

func categoryToColumn(cat string) string {
	switch cat {
	case "borders":
		return "frame_id"
	case "emotes":
		return "emote_set_id"
	case "themes":
		return "theme_id"
	default:
		return ""
	}
}

var errInsufficientCoins = &AppError{Message: "insufficient coins"}

type AppError struct{ Message string }

func (e *AppError) Error() string { return e.Message }
