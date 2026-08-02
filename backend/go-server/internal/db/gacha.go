package db

import (
	"errors"
	"math/rand"
	"time"
)

// GachaPool defines a mystery box with weighted rarity drops.
type GachaPool struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	DiamondCost int    `json:"diamondCost"`
	// Drop rates (must sum to 100)
	CommonRate    int `json:"commonRate"`    // e.g. 60%
	RareRate      int `json:"rareRate"`      // e.g. 25%
	EpicRate      int `json:"epicRate"`      // e.g. 12%
	LegendaryRate int `json:"legendaryRate"` // e.g. 3%
}

// Predefined gacha pools
var GachaPools = []GachaPool{
	{ID: "basic_box",    Name: "Mystery Box",         DiamondCost: 100, CommonRate: 60, RareRate: 25, EpicRate: 12, LegendaryRate: 3},
	{ID: "premium_box",  Name: "Premium Mystery Box", DiamondCost: 500, CommonRate: 35, RareRate: 35, EpicRate: 22, LegendaryRate: 8},
	{ID: "legendary_box",Name: "Legendary Box",       DiamondCost: 2000,CommonRate: 10, RareRate: 25, EpicRate: 40, LegendaryRate: 25},
}

// RollGacha spends diamonds and returns a random gift from the pool.
func RollGacha(userID, poolID string) (*GiftCatalogItem, error) {
	if DB == nil {
		return nil, errors.New("db unavailable")
	}

	// Find pool
	var pool *GachaPool
	for i := range GachaPools {
		if GachaPools[i].ID == poolID {
			pool = &GachaPools[i]
			break
		}
	}
	if pool == nil {
		return nil, errors.New("pool tidak ditemukan")
	}

	// Deduct diamonds
	var balance int64
	err := DB.QueryRow(`
		UPDATE diamond_balance SET amount = amount - $2, total_spent = total_spent + $2, updated_at = now()
		WHERE user_id = $1 AND amount >= $2
		RETURNING amount
	`, userID, pool.DiamondCost).Scan(&balance)
	if err != nil {
		return nil, errors.New("diamond tidak cukup")
	}

	// Roll rarity
	roll := rand.Intn(100)
	var rarity string
	switch {
	case roll < pool.LegendaryRate:
		rarity = "legendary"
	case roll < pool.LegendaryRate+pool.EpicRate:
		rarity = "epic"
	case roll < pool.LegendaryRate+pool.EpicRate+pool.RareRate:
		rarity = "rare"
	default:
		rarity = "common"
	}

	// Pick random gift of that rarity
	gift, err := getRandomGiftByRarity(rarity)
	if err != nil || gift == nil {
		// Fallback to any common gift
		gift, _ = getRandomGiftByRarity("common")
	}
	if gift == nil {
		return nil, errors.New("tidak ada hadiah tersedia")
	}

	// Record the gacha roll
	DB.Exec(`
		INSERT INTO diamond_transactions (user_id, amount, balance_after, reason, ref_id)
		VALUES ($1, $2, $3, $4, $5)
	`, userID, -pool.DiamondCost, balance, "gacha_"+poolID, time.Now().UnixNano())

	// Add to user's gift album
	DB.Exec(`
		INSERT INTO gift_album (user_id, gift_id, role, count)
		VALUES ($1, $2, 'gacha', 1)
		ON CONFLICT (user_id, gift_id, role) DO UPDATE SET count = gift_album.count + 1
	`, userID, gift.ID)

	return gift, nil
}

func getRandomGiftByRarity(rarity string) (*GiftCatalogItem, error) {
	it := &GiftCatalogItem{}
	err := DB.QueryRow(`
		SELECT id, name, emoji, category, type, diamond_price, charm_delta, popularity_delta,
		       animation_key, broadcast_type, rarity, is_limited, is_active, COALESCE(description,''), sort_order
		FROM gift_catalog
		WHERE rarity = $1 AND is_active = true AND type = 'gift'
		ORDER BY RANDOM() LIMIT 1
	`, rarity).Scan(&it.ID, &it.Name, &it.Emoji, &it.Category, &it.Type,
		&it.DiamondPrice, &it.CharmDelta, &it.PopularityDelta, &it.AnimationKey,
		&it.BroadcastType, &it.Rarity, &it.IsLimited, &it.IsActive, &it.Description, &it.SortOrder)
	if err != nil {
		return nil, err
	}
	return it, nil
}
