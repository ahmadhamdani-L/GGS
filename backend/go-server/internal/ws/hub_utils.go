package ws

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

// safeSend sends a message to a client without panicking on closed channel.
// P1-17 FIX: If buffer is full (slow client), log and skip — prevents memory growth.
// The client will receive the next state update instead (self-healing via periodic broadcasts).
func safeSend(c *Client, msg *Message) {
	defer func() { recover() }()
	select {
	case c.Send <- msg:
	default:
		// Buffer full — slow client. Drop this message silently.
		// Client will get next broadcast. If consistently slow, writePump will
		// close the connection when WriteDeadline expires.
	}
}

// P3-46: Minimum interval between game actions (anti-spam/cheat)
const minActionInterval = 500 * time.Millisecond

// checkActionThrottle returns true if action is allowed (not too fast).
// Updates client.lastAction timestamp. Uses atomic int64 to avoid data races.
func checkActionThrottle(client *Client) bool {
	now := time.Now().UnixMilli()
	last := client.lastActionMs.Load()
	if now-last < int64(minActionInterval/time.Millisecond) {
		return false
	}
	client.lastActionMs.Store(now)
	return true
}

func sendError(client *Client, msg string) {
	resp := map[string]string{"message": msg}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "error", Payload: respBytes}
}

func (h *Hub) broadcastToRoom(roomID string, msg *Message, exclude *Client) {
	// Try V1 room first
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if ok {
		room.mu.RLock()
		defer room.mu.RUnlock()
		for _, c := range room.Clients {
			if c != exclude {
				safeSend(c, msg)
			}
		}
		return
	}

	// Fallback: try V2 managed room
	if managedRoom := h.roomMgr.GetRoom(roomID); managedRoom != nil {
		managedRoom.mu.Lock()
		clients := make([]*Client, 0, len(managedRoom.Clients))
		for _, c := range managedRoom.Clients {
			if c != exclude {
				clients = append(clients, c)
			}
		}
		managedRoom.mu.Unlock()
		for _, c := range clients {
			safeSend(c, msg)
		}
	}
}

// getPlayerProfile fetches displayName, avatarID, avatarURL and chibiConfig with caching
func (h *Hub) getPlayerProfile(userID string) (string, int, string, map[string]interface{}) {
	if cached, ok := h.profileCache.Load(userID); ok {
		cp := cached.(*CachedProfile)
		if time.Since(cp.CachedAt) < profileCacheTTL {
			return cp.DisplayName, cp.AvatarID, cp.AvatarURL, cp.ChibiConfig
		}
	}

	displayName := "Player"
	avatarID := 1
	avatarURL := ""
	var chibiConfig map[string]interface{}

	if db.DB != nil {
		profile, err := db.GetProfile(userID)
		if err == nil && profile != nil {
			displayName = profile.DisplayName
			avatarID = profile.AvatarID
			avatarURL = profile.AvatarURL
			chibiConfig = profile.ChibiConfig
		}
	} else if db.Mem != nil {
		profile, err := db.Mem.GetProfile(userID)
		if err == nil && profile != nil {
			displayName = profile.DisplayName
			avatarID = profile.AvatarID
			chibiConfig = profile.ChibiConfig
		}
	}

	h.profileCache.Store(userID, &CachedProfile{
		DisplayName: displayName,
		AvatarID:    avatarID,
		AvatarURL:   avatarURL,
		ChibiConfig: chibiConfig,
		CachedAt:    time.Now(),
	})

	return displayName, avatarID, avatarURL, chibiConfig
}

// InvalidateProfileCache removes a user's profile from cache (call after profile update)
func (h *Hub) InvalidateProfileCache(userID string) {
	h.profileCache.Delete(userID)
}

// getPlayerList returns slice of all players in room (for broadcasting)
func (h *Hub) getPlayerList(room *Room) []map[string]interface{} {
	players := make([]map[string]interface{}, 0, len(room.Players))
	for _, p := range room.Players {
		playerData := map[string]interface{}{
			"userId":      p.UserID,
			"displayName": p.DisplayName,
			"avatarId":    p.AvatarID,
			"isReady":     p.IsReady,
			"slot":        p.Slot,
		}
		if p.ChibiConfig != nil {
			playerData["chibiConfig"] = p.ChibiConfig
		}
		players = append(players, playerData)
	}
	return players
}

// ─── Social Gift Helpers ──────────────────────────────────────

// BroadcastToUserRoom sends a typed message to ALL clients in the same room as the given user.
// Used for room-wide gift/curse animation broadcasts visible to all players.
func (h *Hub) BroadcastToUserRoom(userID string, msgType string, payload interface{}) {
	h.mu.RLock()
	client, ok := h.userIndex[userID]
	h.mu.RUnlock()
	if !ok || client.RoomID == "" {
		return
	}
	payloadBytes, _ := json.Marshal(payload)
	h.broadcastToRoom(client.RoomID, &Message{Type: msgType, Payload: payloadBytes}, nil)
}

// SendToUser sends a typed message to a specific user by ID (O(1) via userIndex).
func (h *Hub) SendToUser(userID string, msgType string, payload interface{}) {
	h.mu.RLock()
	client, ok := h.userIndex[userID]
	h.mu.RUnlock()
	if !ok {
		return
	}
	payloadBytes, _ := json.Marshal(payload)
	safeSend(client, &Message{Type: msgType, Payload: payloadBytes})
}

// BroadcastAll sends a typed message to ALL connected clients.
// Used for global broadcast gifts (legendary, whale, royal throne, etc.)
func (h *Hub) BroadcastAll(msgType string, payload interface{}) {
	payloadBytes, _ := json.Marshal(payload)
	msg := &Message{Type: msgType, Payload: payloadBytes}

	h.mu.RLock()
	clients := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	for _, c := range clients {
		safeSend(c, msg)
	}
}

// profileCacheCleanupLoop periodically removes expired cache entries
func (h *Hub) profileCacheCleanupLoop() {
	ticker := time.NewTicker(profileCacheCleanup)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now()
		expired := 0
		h.profileCache.Range(func(key, value interface{}) bool {
			cp := value.(*CachedProfile)
			if now.Sub(cp.CachedAt) > profileCacheTTL {
				h.profileCache.Delete(key)
				expired++
			}
			return true
		})
		if expired > 0 {
			logger.Debug(logger.CatSystem, "Cleaned expired profile cache entries", map[string]interface{}{"count": expired})
		}
	}
}

// trackRequest checks if a requestId has already been processed for this user.
// Returns true if the request is new (should be processed), false if it's a duplicate.
func (h *Hub) trackRequest(userID, requestID string) bool {
	now := time.Now()

	// Load or create the per-user map
	val, _ := h.requestsCache.LoadOrStore(userID, &sync.Map{})
	userMap := val.(*sync.Map)

	// Check if this requestID was already seen
	if _, loaded := userMap.LoadOrStore(requestID, now); loaded {
		// Already present — duplicate
		return false
	}
	// First time seeing this requestID
	return true
}

// cleanupRequestCache removes expired requestId entries to prevent memory leaks
func (h *Hub) cleanupRequestCache() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		cutoff := time.Now().Add(-requestIDTTL)
		h.requestsCache.Range(func(userKey, userVal any) bool {
			userMap := userVal.(*sync.Map)
			userMap.Range(func(reqKey, reqVal any) bool {
				if t, ok := reqVal.(time.Time); ok && t.Before(cutoff) {
					userMap.Delete(reqKey)
				}
				return true
			})
			return true
		})
	}
}

// ─── Game Snapshot Persistence (#8) ──────────────────────────

// SaveAllSnapshots serialises every active game to DB before shutdown.
func (h *Hub) SaveAllSnapshots() {
	h.mu.RLock()
	rooms := make(map[string]*Room, len(h.rooms))
	for id, r := range h.rooms {
		rooms[id] = r
	}
	h.mu.RUnlock()

	saved := 0
	for roomID, room := range rooms {
		room.mu.RLock()
		g := room.Game
		room.mu.RUnlock()
		if g == nil || g.Phase == game.PhaseGameEnd {
			continue
		}
		stateBytes, err := json.Marshal(g)
		if err != nil {
			continue
		}
		if err := db.SaveGameSnapshot(roomID, string(stateBytes)); err == nil {
			saved++
		}
	}
	logger.Info(logger.CatSystem, "Game snapshots saved", map[string]interface{}{"count": saved})
}

// RestoreSnapshots loads game states saved before the last shutdown and
// re-creates in-memory rooms so in-progress games can continue.
func (h *Hub) RestoreSnapshots() {
	snapshots, err := db.LoadGameSnapshots(2 * time.Hour)
	if err != nil || len(snapshots) == 0 {
		return
	}
	restored := 0
	for roomID, rawState := range snapshots {
		var g game.GameState
		if err := json.Unmarshal(rawState, &g); err != nil {
			continue
		}
		if g.Phase == game.PhaseGameEnd {
			db.DeleteGameSnapshot(roomID)
			continue
		}

		room := &Room{
			ID:      roomID,
			Code:    roomID[:6], // use first 6 chars as code
			Status:  RoomPlaying,
			Clients: make(map[string]*Client),
			Players: make(map[string]*RoomPlayer),
			Game:    &g,
		}
		for _, p := range g.Players {
			if p.IsBot {
				continue
			}
			room.Players[p.ID] = &RoomPlayer{
				UserID:      p.ID,
				DisplayName: p.Name,
				AvatarID:    p.AvatarID,
				Slot:        0,
			}
		}

		h.mu.Lock()
		h.rooms[roomID] = room
		h.mu.Unlock()

		// Schedule phase timer so game continues when players reconnect
		if g.TimerDeadline != nil {
			h.scheduleRoomPhaseTimer(roomID, *g.TimerDeadline)
		}
		db.DeleteGameSnapshot(roomID)
		restored++
	}
	if restored > 0 {
		logger.Info(logger.CatSystem, "Game snapshots restored", map[string]interface{}{"count": restored})
	}
}

// GetStats returns hub stats for admin dashboard (safe from outside ws package).
func (h *Hub) GetStats() map[string]int {
	h.mu.RLock()
	clients := len(h.clients)
	rooms := len(h.rooms)
	games := 0
	for _, room := range h.rooms {
		room.mu.RLock()
		if room.Game != nil {
			games++
		}
		room.mu.RUnlock()
	}
	h.mu.RUnlock()
	return map[string]int{"clients": clients, "rooms": rooms, "games": games}
}

// LoadMaxRooms reads the max_rooms setting from DB and stores it in the hub.
// Call this after DB.Connect() succeeds.
func (h *Hub) LoadMaxRooms() {
	if db.DB == nil {
		return
	}
	var max int
	if err := db.DB.QueryRow(`SELECT value FROM server_settings WHERE key = 'max_rooms'`).Scan(&max); err == nil && max > 0 {
		h.mu.Lock()
		h.maxRooms = max
		h.mu.Unlock()
		logger.Info(logger.CatSystem, "Max rooms loaded", map[string]interface{}{"maxRooms": max})
	}
}

// startRoomTimer is now a no-op since we use global timer
// Kept for backward compatibility
func (h *Hub) startRoomTimer(roomID string) {
	// Global timer handles all rooms - nothing to do here
	logger.Debug(logger.CatTimer, "Room timer managed by global loop", map[string]interface{}{"roomId": roomID})
}

// stopRoomTimer is now a no-op since we use global timer
func (h *Hub) stopRoomTimer(roomID string) {
	// Global timer handles all rooms - nothing to do here
}
