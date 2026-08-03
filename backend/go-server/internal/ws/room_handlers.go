package ws

import (
	"encoding/json"

	"github.com/ggs/werewolf-server/internal/bot"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

// ═══════════════════════════════════════════════════════════════
// ROOM HANDLERS V2 — WebSocket event handlers for RoomManager
// ═══════════════════════════════════════════════════════════════
//
// All events follow consistent payload structure:
// - Request: { "type": "event_name", "payload": { ... } }
// - Response: { "type": "event_name", "payload": { roomId, ...data } }
// - Error: { "type": "error", "payload": { "message": "...", "code": "..." } }
// - State broadcast: { "type": "room_state", "payload": { full room snapshot } }
//
// Every mutation broadcasts room_state to all clients in the room.
// ═══════════════════════════════════════════════════════════════

// handleCreateRoomV2 creates a new private room
func (h *Hub) handleCreateRoomV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid create_room payload")
		return
	}

	displayName, avatarID, _, chibi := h.getPlayerProfile(req.UserID)

	room := h.roomMgr.CreatePrivateRoom(req.UserID, displayName, avatarID, chibi)

	// Join the creator to the room
	errMsg := h.roomMgr.JoinRoom(room, client, req.UserID, displayName, avatarID, chibi)
	if errMsg != "" {
		sendErrorV2(client, "JOIN_FAILED", errMsg)
		return
	}

	// Auto-assign seat 0 to creator
	h.roomMgr.SelectSeat(room, req.UserID, 0)

	logger.RoomCreated(room.ID, room.Code, req.UserID)

	// Send room_created to creator
	sendEvent(client, "room_created", map[string]interface{}{
		"roomId": room.ID,
		"code":   room.Code,
	})

	// Broadcast full room state
	h.roomMgr.BroadcastRoomState(room)
	// Update lobby list for all connected clients
	h.broadcastLobbyListV2()
}

// handleJoinRoomV2 joins a player to an existing room by code
func (h *Hub) handleJoinRoomV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID   string `json:"userId"`
		RoomCode string `json:"roomCode"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid join_room payload")
		return
	}

	room := h.roomMgr.GetRoomByCode(req.RoomCode)
	if room == nil {
		sendErrorV2(client, "ROOM_NOT_FOUND", "Room tidak ditemukan")
		return
	}

	displayName, avatarID, _, chibi := h.getPlayerProfile(req.UserID)

	errMsg := h.roomMgr.JoinRoom(room, client, req.UserID, displayName, avatarID, chibi)
	if errMsg != "" {
		sendErrorV2(client, "JOIN_FAILED", errMsg)
		return
	}

	// Send room_joined to joiner
	sendEvent(client, "room_joined", map[string]interface{}{
		"roomId": room.ID,
		"code":   room.Code,
	})

	// Broadcast player_join event + full state to all
	h.roomMgr.BroadcastEvent(room, "player_join", map[string]interface{}{
		"userId":      req.UserID,
		"displayName": displayName,
	})
	h.roomMgr.BroadcastRoomState(room)
	h.broadcastLobbyListV2()
}

// handleLeaveRoomV2 removes a player from a room
func (h *Hub) handleLeaveRoomV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	h.roomMgr.LeaveRoom(room, req.UserID)
	client.RoomID = ""

	// Notify the leaving player
	sendEvent(client, "room_left", map[string]interface{}{
		"roomId": req.RoomID,
	})

	// Broadcast to remaining players
	h.roomMgr.BroadcastEvent(room, "player_leave", map[string]interface{}{
		"userId": req.UserID,
		"reason": "left",
	})
	h.roomMgr.BroadcastRoomState(room)
	h.broadcastLobbyListV2()
}

// handleSelectSeatV2 — player selects a seat (atomic)
func (h *Hub) handleSelectSeatV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID    string `json:"userId"`
		RoomID    string `json:"roomId"`
		SeatIndex int    `json:"seatIndex"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid select_seat payload")
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		sendErrorV2(client, "ROOM_NOT_FOUND", "Room tidak ditemukan")
		return
	}

	errMsg := h.roomMgr.SelectSeat(room, req.UserID, req.SeatIndex)
	if errMsg != "" {
		sendErrorV2(client, "SEAT_TAKEN", errMsg)
		return
	}

	// Broadcast seat_selected event + full state
	h.roomMgr.BroadcastEvent(room, "seat_selected", map[string]interface{}{
		"userId":    req.UserID,
		"seatIndex": req.SeatIndex,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleReleaseSeatV2 — player releases their seat
func (h *Hub) handleReleaseSeatV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	h.roomMgr.ReleaseSeat(room, req.UserID)
	h.roomMgr.BroadcastEvent(room, "seat_released", map[string]interface{}{
		"userId": req.UserID,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleReadyV2 — player toggles ready state
func (h *Hub) handleReadyV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
		Ready  bool   `json:"ready"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	errMsg := h.roomMgr.SetReady(room, req.UserID, req.Ready)
	if errMsg != "" {
		sendErrorV2(client, "READY_FAILED", errMsg)
		return
	}

	h.roomMgr.BroadcastEvent(room, "ready_changed", map[string]interface{}{
		"userId": req.UserID,
		"ready":  req.Ready,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleAddBotV2 — host adds a bot to a seat
func (h *Hub) handleAddBotV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID    string `json:"roomId"`
		SeatIndex int    `json:"seatIndex"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid add_bot payload")
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		sendErrorV2(client, "ROOM_NOT_FOUND", "Room tidak ditemukan")
		return
	}

	errMsg := h.roomMgr.AddBot(room, client.UserID, req.SeatIndex)
	if errMsg != "" {
		sendErrorV2(client, "BOT_FAILED", errMsg)
		return
	}

	h.roomMgr.BroadcastEvent(room, "bot_added", map[string]interface{}{
		"seatIndex": req.SeatIndex,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleRemoveBotV2 — host removes a bot from a seat
func (h *Hub) handleRemoveBotV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID    string `json:"roomId"`
		SeatIndex int    `json:"seatIndex"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	errMsg := h.roomMgr.RemoveBot(room, client.UserID, req.SeatIndex)
	if errMsg != "" {
		sendErrorV2(client, "BOT_FAILED", errMsg)
		return
	}

	h.roomMgr.BroadcastEvent(room, "bot_removed", map[string]interface{}{
		"seatIndex": req.SeatIndex,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleKickV2 — host kicks a player
func (h *Hub) handleKickV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID       string `json:"roomId"`
		TargetUserID string `json:"targetUserId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	room.mu.Lock()
	if room.HostID != client.UserID {
		room.mu.Unlock()
		sendErrorV2(client, "NOT_HOST", "Hanya host yang bisa kick")
		return
	}
	targetClient, hasClient := room.Clients[req.TargetUserID]
	room.mu.Unlock()

	// Notify kicked player
	if hasClient {
		sendEvent(targetClient, "kicked", map[string]interface{}{
			"reason": "Kicked by host",
		})
		targetClient.RoomID = ""
	}

	h.roomMgr.LeaveRoom(room, req.TargetUserID)

	h.roomMgr.BroadcastEvent(room, "player_leave", map[string]interface{}{
		"userId": req.TargetUserID,
		"reason": "kicked",
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleUpdateSettingsV2 — host updates room settings
func (h *Hub) handleUpdateSettingsV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID   string       `json:"roomId"`
		Settings RoomSettings `json:"settings"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid settings payload")
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	room.mu.Lock()
	if room.HostID != client.UserID {
		room.mu.Unlock()
		sendErrorV2(client, "NOT_HOST", "Hanya host yang bisa mengubah settings")
		return
	}
	// Validate and apply
	if req.Settings.MaxPlayers >= 4 && req.Settings.MaxPlayers <= MaxSeats {
		room.Settings.MaxPlayers = req.Settings.MaxPlayers
	}
	if req.Settings.DiscussionTime > 0 {
		room.Settings.DiscussionTime = req.Settings.DiscussionTime
	}
	if req.Settings.VotingTime > 0 {
		room.Settings.VotingTime = req.Settings.VotingTime
	}
	if req.Settings.NightTime > 0 {
		room.Settings.NightTime = req.Settings.NightTime
	}
	if req.Settings.TestamentTime > 0 {
		room.Settings.TestamentTime = req.Settings.TestamentTime
	}
	room.mu.Unlock()

	h.roomMgr.BroadcastEvent(room, "settings_updated", map[string]interface{}{
		"settings": room.Settings,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handlePlayAgainV2 — player wants to play again after game ends
func (h *Hub) handlePlayAgainV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	h.roomMgr.SetPlayAgain(room, req.UserID)

	h.roomMgr.BroadcastEvent(room, "play_again", map[string]interface{}{
		"userId": req.UserID,
	})
	h.roomMgr.BroadcastRoomState(room)
}

// handleGetLobbyV2 — client requests the lobby room list
func (h *Hub) handleGetLobbyV2(client *Client) {
	rooms := h.roomMgr.GetLobbyList()
	payload, _ := json.Marshal(map[string]interface{}{
		"rooms": rooms,
		"count": len(rooms),
	})
	client.Send <- &Message{Type: "lobby_list", Payload: payload}
}

// handleReconnectRoomV2 — player reconnects to a room they were in
func (h *Hub) handleReconnectRoomV2(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		sendErrorV2(client, "ROOM_NOT_FOUND", "Room tidak ditemukan")
		return
	}

	ok := h.roomMgr.PlayerReconnect(room, client, req.UserID)
	if !ok {
		sendErrorV2(client, "RECONNECT_FAILED", "Tidak bisa reconnect ke room ini")
		return
	}

	// Send player_reconnect event
	h.roomMgr.BroadcastEvent(room, "player_reconnect", map[string]interface{}{
		"userId": req.UserID,
	})
	// Send full state to reconnected player
	h.roomMgr.BroadcastRoomState(room)
}

// handleStartGameV2 — host starts the game from V2 room system
func (h *Hub) handleStartGameV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendErrorV2(client, "INVALID_PAYLOAD", "Invalid start_game payload")
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		sendErrorV2(client, "ROOM_NOT_FOUND", "Room tidak ditemukan")
		return
	}

	room.mu.Lock()
	if room.HostID != client.UserID {
		room.mu.Unlock()
		sendErrorV2(client, "NOT_HOST", "Hanya host yang bisa memulai game")
		return
	}
	if room.State != StateWaiting {
		room.mu.Unlock()
		sendErrorV2(client, "INVALID_STATE", "Room tidak dalam status waiting")
		return
	}

	// Count seated players (humans + bots)
	seatedCount := 0
	for _, p := range room.Players {
		if p.SeatIndex >= 0 {
			seatedCount++
		}
	}
	if seatedCount < 8 {
		room.mu.Unlock()
		sendErrorV2(client, "NOT_ENOUGH_PLAYERS", "Butuh minimal 8 pemain (termasuk bot) untuk mulai")
		return
	}

	// Check all seated humans (except the one starting the game) are ready.
	// Host/starter is implicitly ready by pressing "Start Game".
	// Bots are always marked as ready when created.
	for _, p := range room.Players {
		if !p.IsBot && p.SeatIndex >= 0 && p.UserID != client.UserID && !p.IsReady {
			room.mu.Unlock()
			sendErrorV2(client, "NOT_ALL_READY", "Semua pemain harus ready sebelum mulai")
			return
		}
	}

	// Transition to countdown
	room.State = StateCountdown
	room.mu.Unlock()

	// Broadcast countdown
	h.roomMgr.BroadcastEvent(room, "game_countdown", map[string]interface{}{
		"seconds": 3,
	})

	// Collect player info from seated players
	room.mu.Lock()
	playerInfos := make([]game.PlayerInfo, 0, seatedCount)
	for _, p := range room.Players {
		if p.SeatIndex < 0 {
			continue // skip unseated players
		}
		playerInfos = append(playerInfos, game.PlayerInfo{
			ID:          p.UserID,
			DisplayName: p.DisplayName,
			AvatarID:    p.AvatarID,
			ChibiConfig: p.ChibiConfig,
		})
	}

	// Apply room settings to game config
	settings := room.Settings
	room.mu.Unlock()

	// Create the game state
	gameState := game.CreateGame(playerInfos)

	// Apply timer settings from room
	if settings.DiscussionTime > 0 {
		gameState.Config.TimerDuration.Discussion = settings.DiscussionTime
	}
	if settings.VotingTime > 0 {
		gameState.Config.TimerDuration.Voting = settings.VotingTime
	}
	if settings.NightTime > 0 {
		gameState.Config.TimerDuration.NightAction = settings.NightTime
	}

	// Mark bots
	bot.MarkBots(gameState)
	gameState = game.StartGame(gameState)

	// Process initial bot actions (role confirmations)
	gameState = bot.ProcessBotActions(gameState, bot.Medium)

	// Store game state in room
	room.mu.Lock()
	room.Game = gameState
	room.State = StatePlaying
	room.mu.Unlock()

	logger.Info(logger.CatRoom, "Game started via V2 room", map[string]interface{}{
		"roomId":  room.ID,
		"players": seatedCount,
	})

	// Also register room in hub.rooms for game state broadcasts
	h.mu.Lock()
	h.rooms[room.ID] = &Room{
		ID:       room.ID,
		Code:     room.Code,
		HostID:   room.HostID,
		Status:   RoomPlaying,
		Game:     gameState,
		Players:  make(map[string]*RoomPlayer),
		Clients:  make(map[string]*Client),
	}
	// Copy clients from managed room to v1 room for broadcastGameState compatibility
	room.mu.Lock()
	for uid, c := range room.Clients {
		h.rooms[room.ID].Clients[uid] = c
		h.rooms[room.ID].Players[uid] = &RoomPlayer{
			UserID:      uid,
			DisplayName: room.Players[uid].DisplayName,
			AvatarID:    room.Players[uid].AvatarID,
			ChibiConfig: room.Players[uid].ChibiConfig,
		}
	}
	room.mu.Unlock()
	h.mu.Unlock()

	// Start the timer goroutine
	h.startRoomTimer(room.ID)

	// Broadcast game_started event so Flutter navigates
	h.roomMgr.BroadcastEvent(room, "game_started", map[string]interface{}{
		"roomId": room.ID,
		"gameId": room.ID,
	})

	// Broadcast filtered game state per player
	h.broadcastGameState(room.ID)
}

// handleRoomChatV2 — send a chat message in the room lobby
func (h *Hub) handleRoomChatV2(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID  string `json:"roomId"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	if len(req.Message) == 0 || len(req.Message) > 200 {
		return
	}

	room := h.roomMgr.GetRoom(req.RoomID)
	if room == nil {
		return
	}

	// Verify player is in this room
	room.mu.Lock()
	player, exists := room.Players[client.UserID]
	if !exists {
		room.mu.Unlock()
		return
	}
	displayName := player.DisplayName
	room.mu.Unlock()

	// Broadcast chat to all in room
	h.roomMgr.BroadcastEvent(room, "room_chat", map[string]interface{}{
		"userId":      client.UserID,
		"displayName": displayName,
		"message":     req.Message,
		"timestamp":   json.Number("0"), // client uses local time
	})
}

// ─── Helper: broadcast lobby to all connected clients ────────

func (h *Hub) broadcastLobbyListV2() {
	rooms := h.roomMgr.GetLobbyList()
	payload, _ := json.Marshal(map[string]interface{}{
		"rooms": rooms,
		"count": len(rooms),
	})
	h.BroadcastAll("lobby_update", json.RawMessage(payload))
}

// ─── Helper: send structured error ──────────────────────────

func sendErrorV2(client *Client, code, message string) {
	payload, _ := json.Marshal(map[string]interface{}{
		"code":    code,
		"message": message,
	})
	safeSend(client, &Message{Type: "error", Payload: payload})
}

// ─── Helper: send event to single client ─────────────────────

func sendEvent(client *Client, eventType string, data map[string]interface{}) {
	payload, _ := json.Marshal(data)
	safeSend(client, &Message{Type: eventType, Payload: payload})
}
