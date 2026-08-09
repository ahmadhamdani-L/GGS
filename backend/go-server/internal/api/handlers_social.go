package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
	"github.com/ggs/werewolf-server/internal/push"
)

func getEnvSafe(key string) string { return os.Getenv(key) }

// ─── Gift Catalog ─────────────────────────────────────────────

// GET /api/gifts/catalog?type=gift|curse
func (s *Server) HandleGiftCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	giftType := r.URL.Query().Get("type") // "gift" | "curse" | "" (all)
	items, err := db.GetGiftCatalog(giftType)
	if err != nil {
		errorResponse(w, 500, "failed to load catalog")
		return
	}
	jsonResponse(w, 200, map[string]interface{}{
		"gifts": items,
		"count": len(items),
	})
}

// ─── Diamond Balance ─────────────────────────────────────────

// GET /api/diamonds
func (s *Server) HandleGetDiamonds(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(ContextKeyUserID).(string)
	balance, err := db.GetDiamondBalance(userID)
	if err != nil {
		errorResponse(w, 500, "failed to get balance")
		return
	}
	jsonResponse(w, 200, balance)
}

// POST /api/diamonds/topup  (admin/payment gateway callback)
// Body: { "userId": "...", "amount": 100, "refId": "order_xxx", "reason": "topup_100" }
func (s *Server) HandleTopUpDiamonds(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	// Must be called with admin key or payment webhook secret
	adminKey := r.Header.Get("X-Admin-Key")
	if adminKey == "" || adminKey != getEnvSafe("ADMIN_KEY") {
		errorResponse(w, 403, "forbidden")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16)
	var req struct {
		UserID string `json:"userId"`
		Amount int64  `json:"amount"`
		RefID  string `json:"refId"`
		Reason string `json:"reason"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.UserID == "" || req.Amount <= 0 {
		errorResponse(w, 400, "invalid body")
		return
	}
	newBalance, err := db.TopUpDiamonds(req.UserID, req.Amount, req.RefID, req.Reason)
	if err != nil {
		if strings.Contains(err.Error(), "already processed") {
			jsonResponse(w, 200, map[string]interface{}{"message": "already processed", "idempotent": true})
			return
		}
		errorResponse(w, 500, "top-up failed: "+err.Error())
		return
	}
	logger.Info(logger.CatAPI, "Diamond top-up", map[string]interface{}{
		"userId": req.UserID, "amount": req.Amount, "newBalance": newBalance,
	})
	jsonResponse(w, 200, map[string]interface{}{"newBalance": newBalance})
}

// ─── Send Gift / Curse ────────────────────────────────────────

// POST /api/gifts/send
// Body: { "receiverId":"...", "giftId":"rose", "message":"..." }
func (s *Server) HandleSendGift(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16)
	userID := r.Context().Value(ContextKeyUserID).(string)

	var req struct {
		ReceiverID     string `json:"receiverId"`
		GiftID         string `json:"giftId"`
		Message        string `json:"message"`
		IdempotencyKey string `json:"idempotencyKey"` // client-generated UUID
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}
	if req.ReceiverID == "" || req.GiftID == "" {
		errorResponse(w, 400, "receiverId and giftId required")
		return
	}
	if req.IdempotencyKey == "" {
		errorResponse(w, 400, "idempotencyKey required")
		return
	}
	// Sanitize
	req.ReceiverID = strings.TrimSpace(req.ReceiverID)
	req.GiftID     = strings.ToLower(strings.TrimSpace(req.GiftID))
	if len(req.Message) > 50 {
		req.Message = req.Message[:50]
	}

	result, err := db.SendGift(db.SendGiftInput{
		IdempotencyKey: req.IdempotencyKey,
		SenderID:       userID,
		ReceiverID:     req.ReceiverID,
		GiftID:         req.GiftID,
		Message:        req.Message,
	})
	if err != nil {
		code := 500
		msg := err.Error()
		if strings.Contains(msg, "tidak cukup") || strings.Contains(msg, "yourself") ||
			strings.Contains(msg, "terlalu banyak") || strings.Contains(msg, "duplicate") ||
			strings.Contains(msg, "not found") {
			code = 400
		}
		errorResponseWithCode(w, code, msg, "GIFT_ERROR")
		return
	}

	// Get sender + receiver names for activity feed
	senderName, _ := db.GetDisplayName(userID)
	receiverName, _ := db.GetDisplayName(req.ReceiverID)

	// Create activity feed entry (async)
	gift, _ := db.GetGiftByID(req.GiftID)
	if gift != nil {
		eventType := "gift_sent"
		if gift.Type == "curse" {
			eventType = "curse_sent"
		}
		if gift.Rarity == "legendary" {
			eventType = "legendary_gift"
		}
		go db.CreateActivityFeedEntry(result.Transaction.ID, gift,
			userID, req.ReceiverID, senderName, receiverName, req.Message, eventType)

		// Emit social events (async)
		go s.emitSocialEvents(result, gift, senderName, receiverName)

		// Check achievements (async)
		go s.checkGiftAchievements(userID, req.ReceiverID, gift, result)

		// Send WS notification to receiver (if online)
		go s.sendGiftNotification(req.ReceiverID, gift, senderName, req.Message, result)
	}

	jsonResponse(w, 200, map[string]interface{}{
		"success":          true,
		"transaction":      result.Transaction,
		"senderDiamonds":   result.SenderDiamonds,
		"receiverCharm":    result.ReceiverCharm,
		"senderPopularity": result.SenderPopularity,
		"comboTriggered":   result.ComboTriggered,
		"comboCount":       result.ComboCount,
		"streakBonus":      result.StreakBonus,
		"events":           result.Events,
	})
}

// ─── Gift History ─────────────────────────────────────────────

// GET /api/gifts/history?role=sent|received|all&limit=20
func (s *Server) HandleGiftHistory(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(ContextKeyUserID).(string)
	role  := r.URL.Query().Get("role")
	limit := 20
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 && l <= 100 {
		limit = l
	}
	history, err := db.GetGiftHistory(userID, role, limit)
	if err != nil {
		errorResponse(w, 500, "failed to get history")
		return
	}
	jsonResponse(w, 200, map[string]interface{}{
		"history": history,
		"count":   len(history),
	})
}

// ─── Social Stats ─────────────────────────────────────────────

// GET /api/social/stats?userId=... (own if omitted)
func (s *Server) HandleSocialStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(ContextKeyUserID).(string)
	if uid := r.URL.Query().Get("userId"); uid != "" {
		userID = uid
	}
	stats, err := db.GetSocialStats(userID)
	if err != nil {
		errorResponse(w, 500, "failed to get stats")
		return
	}
	playerStats, _ := db.GetPlayerStats(userID)
	rankTier := "Bronze"
	if playerStats != nil && playerStats.RankTier != "" {
		rankTier = playerStats.RankTier
	}

	streak := getStreak(userID)
	album, _ := db.GetGiftAlbum(userID)
	jsonResponse(w, 200, map[string]interface{}{
		"stats":    stats,
		"streak":   streak,
		"album":    album,
		"rankTier": rankTier,
	})
}

// ─── Activity Feed ────────────────────────────────────────────

// GET /api/social/feed?scope=global|mine&limit=30
func (s *Server) HandleActivityFeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(ContextKeyUserID).(string)
	scope  := r.URL.Query().Get("scope") // "global" | "mine"
	limit  := 30
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 && l <= 100 {
		limit = l
	}

	var feed []db.ActivityFeedItem
	var err error
	if scope == "mine" {
		feed, err = db.GetUserActivityFeed(userID, limit)
	} else {
		feed, err = db.GetActivityFeed(limit, "global")
	}
	if err != nil {
		errorResponse(w, 500, "failed to get feed")
		return
	}
	jsonResponse(w, 200, map[string]interface{}{
		"feed":  feed,
		"count": len(feed),
	})
}

// ─── Social Leaderboard ───────────────────────────────────────

// GET /api/social/leaderboard?type=charm&period=weekly&limit=50
// types: charm|popularity|gift_sent|gift_received|legendary_sent|curse_sent
// periods: weekly|monthly|alltime
func (s *Server) HandleSocialLeaderboard(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	boardType := r.URL.Query().Get("type")
	period    := r.URL.Query().Get("period")
	if boardType == "" { boardType = "charm" }
	if period    == "" { period    = "alltime" }

	validTypes := map[string]bool{
		"charm": true, "popularity": true, "gift_sent": true,
		"gift_received": true, "legendary_sent": true, "curse_sent": true,
	}
	validPeriods := map[string]bool{"weekly": true, "monthly": true, "alltime": true}
	if !validTypes[boardType] || !validPeriods[period] {
		errorResponse(w, 400, "invalid type or period")
		return
	}

	limit := 50
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 && l <= 100 {
		limit = l
	}

	entries, err := db.GetSocialLeaderboard(boardType, period, limit)
	if err != nil {
		errorResponse(w, 500, "failed to get leaderboard")
		return
	}
	jsonResponse(w, 200, map[string]interface{}{
		"boardType": boardType,
		"period":    period,
		"entries":   entries,
		"count":     len(entries),
	})
}

// GET /api/gifts/analytics?days=7  (admin)
func (s *Server) HandleGiftAnalytics(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	if r.Header.Get("X-Admin-Key") != getEnvSafe("ADMIN_KEY") {
		errorResponse(w, 403, "forbidden")
		return
	}
	days := 7
	if d, err := strconv.Atoi(r.URL.Query().Get("days")); err == nil && d > 0 && d <= 365 {
		days = d
	}
	data, err := db.GetGiftAnalytics(days)
	if err != nil {
		errorResponse(w, 500, "failed to get analytics")
		return
	}
	jsonResponse(w, 200, map[string]interface{}{"analytics": data, "days": days})
}

// ─── Task #5: Event System ────────────────────────────────────

// emitSocialEvents dispatches all social events from a gift send.
// Events: GiftSent, CurseSent, CharmUpdated, PopularityUpdated,
//         LegendaryGiftSent, ComboTriggered, GlobalBroadcast, AchievementUnlocked
func (s *Server) emitSocialEvents(result *db.SendGiftResult, gift *db.GiftCatalogItem, senderName, receiverName string) {
	for _, event := range result.Events {
		logger.Info(logger.CatSystem, "SocialEvent:"+event, map[string]interface{}{
			"giftId":       gift.ID,
			"senderId":     result.Transaction.SenderID,
			"receiverId":   result.Transaction.ReceiverID,
			"senderName":   senderName,
			"receiverName": receiverName,
			"diamondSpent": result.Transaction.DiamondSpent,
			"charmDelta":   result.Transaction.CharmDelta,
			"popularity":   result.SenderPopularity,
			"charm":        result.ReceiverCharm,
		})
	}
}

// sendGiftNotification pushes WS notification to receiver if online
func (s *Server) sendGiftNotification(receiverID string, gift *db.GiftCatalogItem,
	senderName, message string, result *db.SendGiftResult) {
	if s.Hub == nil {
		return
	}

	notifMsg := fmt.Sprintf("%s mengirim %s %s kepadamu!", senderName, gift.Emoji, gift.Name)
	if gift.Type == "curse" {
		notifMsg = fmt.Sprintf("%s melempar %s %s kepadamu!", senderName, gift.Emoji, gift.Name)
	}
	if message != "" {
		notifMsg += fmt.Sprintf(` "%s"`, message)
	}

	payload := map[string]interface{}{
		"type":           "gift_received",
		"giftId":         gift.ID,
		"giftName":       gift.Name,
		"giftEmoji":      gift.Emoji,
		"giftType":       gift.Type,
		"animationKey":   gift.AnimationKey,
		"broadcastType":  gift.BroadcastType,
		"senderName":     senderName,
		"message":        message,
		"charmDelta":     result.ReceiverCharm,
		"notification":   notifMsg,
		"comboTriggered": result.ComboTriggered,
		"comboCount":     result.ComboCount,
	}
	s.Hub.SendToUser(receiverID, "gift_notification", payload)

	// Global broadcast for legendary/global gifts
	if gift.BroadcastType == "global" {
		s.Hub.BroadcastAll("gift_global_broadcast", map[string]interface{}{
			"giftId":       gift.ID,
			"giftName":     gift.Name,
			"giftEmoji":    gift.Emoji,
			"senderName":   senderName,
			"receiverName": getDisplayNameSafe(receiverID),
			"animationKey": gift.AnimationKey,
		})
	}

	// Room-wide animation broadcast: if sender is in a room, broadcast animation
	// to ALL players in that room so everyone sees the gift/curse fly from sender to receiver.
	// Always broadcast to room regardless of broadcastType (even "none" gifts get room animation).
	s.Hub.BroadcastToUserRoom(result.Transaction.SenderID, "gift_animation_broadcast", map[string]interface{}{
		"senderId":      result.Transaction.SenderID,
		"receiverId":    receiverID,
		"senderName":    senderName,
		"receiverName":  getDisplayNameSafe(receiverID),
		"giftId":        gift.ID,
		"giftName":      gift.Name,
		"giftEmoji":     gift.Emoji,
		"giftType":      gift.Type,
		"animationKey":  gift.AnimationKey,
		"rarity":        gift.Rarity,
		"broadcastType": gift.BroadcastType,
	})

	// Persist notification in DB
	db.CreateNotification(receiverID, "gift_received", gift.Emoji+" "+gift.Name, notifMsg,
		map[string]interface{}{
			"giftId": gift.ID, "senderId": result.Transaction.SenderID,
			"senderName": senderName, "message": message,
		})

	// Send push notification
	isCurse := gift.Type == "curse"
	go push.SendGiftPushNotification(receiverID, senderName, gift.Name, gift.Emoji, isCurse)
}

// ─── Task #4: Achievement Checker ────────────────────────────

type achievementCheck struct {
	id        string
	condition func() bool
}

func (s *Server) checkGiftAchievements(senderID, receiverID string,
	gift *db.GiftCatalogItem, result *db.SendGiftResult) {

	stats, err := db.GetSocialStats(senderID)
	if err != nil {
		return
	}
	receiverStats, _ := db.GetSocialStats(receiverID)

	checks := []achievementCheck{
		{"gift_first_send",        func() bool { return stats.GiftsSent == 1 }},
		{"gift_100_sent",          func() bool { return stats.GiftsSent >= 100 }},
		{"gift_legendary_sent",    func() bool { return gift.Rarity == "legendary" }},
		{"gift_diamonds_10000",    func() bool { return stats.DiamondsSpentGifts >= 10000 }},
		{"gift_most_generous",     func() bool { return stats.DiamondsSpentGifts >= 100000 }},
		{"gift_king_of_gifts",     func() bool { return stats.GiftsSent >= 1000 }},
		{"curse_first_send",       func() bool { return stats.CursesSent == 1 && gift.Type == "curse" }},
		{"curse_prankster",        func() bool { return stats.CursesSent >= 50 }},
		{"curse_master_troll",     func() bool { return stats.CursesSent >= 200 }},
		{"social_popularity_100",  func() bool { return result.SenderPopularity >= 100 }},
		{"social_popularity_1000", func() bool { return result.SenderPopularity >= 1000 }},
		{"social_popularity_10000",func() bool { return result.SenderPopularity >= 10000 }},
	}
	if receiverStats != nil {
		checks = append(checks, []achievementCheck{
			{"gift_received_10",   func() bool { return receiverStats.GiftsReceived >= 10 }},
			{"gift_received_100",  func() bool { return receiverStats.GiftsReceived >= 100 }},
			{"gift_loved_by_all",  func() bool { return receiverStats.GiftsReceived >= 1000 }},
			{"charm_1000",         func() bool { return result.ReceiverCharm >= 1000 }},
			{"charm_5000",         func() bool { return result.ReceiverCharm >= 5000 }},
			{"charm_10000",        func() bool { return result.ReceiverCharm >= 10000 }},
		}...)
	}

	for _, ch := range checks {
		if ch.condition() {
			db.UnlockAchievement(senderID, ch.id)
			go push.SendAchievementPushNotification(senderID, ch.id)
		}
	}
}

// ─── Helpers ─────────────────────────────────────────────────

func getStreak(userID string) *db.GiftStreak {
	if db.DB == nil {
		return &db.GiftStreak{BonusMultiplier: 1.0}
	}
	s := &db.GiftStreak{}
	var lastDate *string
	err := db.DB.QueryRow(`
		SELECT user_id, current_streak, longest_streak,
		       TO_CHAR(last_gift_date,'YYYY-MM-DD'), streak_bonus_multiplier
		FROM gift_streaks WHERE user_id = $1
	`, userID).Scan(&s.UserID, &s.CurrentStreak, &s.LongestStreak, &lastDate, &s.BonusMultiplier)
	if err != nil {
		return &db.GiftStreak{UserID: userID, BonusMultiplier: 1.0}
	}
	s.LastGiftDate = lastDate
	return s
}

func getDisplayNameSafe(userID string) string {
	name, _ := db.GetDisplayName(userID)
	return name
}

var _ = time.Now
