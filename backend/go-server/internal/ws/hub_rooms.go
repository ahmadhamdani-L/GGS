package ws

import (
	"encoding/json"
	"time"

	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

func (h *Hub) handleCreateRoom(client *Client, payload json.RawMessage) {
	var req struct {
		UserID     string `json:"userId"`
		MaxPlayers int    `json:"maxPlayers"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		logger.WSError(client.UserID, "create_room", "Invalid payload")
		sendError(client, "Invalid create_room payload")
		return
	}

	// H-05 FIX: Enforce max_rooms limit
	h.mu.RLock()
	currentRooms := len(h.rooms)
	maxRooms := h.maxRooms
	h.mu.RUnlock()
	if currentRooms >= maxRooms {
		sendError(client, "Server sedang penuh, coba lagi nanti")
		return
	}

	// Get player profile with chibi config
	displayName, avatarID, avatarURL, chibiConfig := h.getPlayerProfile(req.UserID)

	room := &Room{
		ID:      generateID(),
		Code:    generateRoomCode(),
		HostID:  req.UserID,
		Status:  RoomWaiting,
		Clients: make(map[string]*Client),
		Players: make(map[string]*RoomPlayer),
	}
	room.Clients[req.UserID] = client
	room.Players[req.UserID] = &RoomPlayer{
		UserID:      req.UserID,
		DisplayName: displayName,
		AvatarID:    avatarID,
		AvatarURL:   avatarURL,
		ChibiConfig: chibiConfig,
		IsReady:     false,
		Slot:        0,
	}
	client.RoomID = room.ID

	h.mu.Lock()
	h.rooms[room.ID] = room
	h.mu.Unlock()

	// Send room_created with full player list
	resp := map[string]interface{}{
		"roomId":   room.ID,
		"roomCode": room.Code,
		"userId":   req.UserID,
		"hostId":   req.UserID,
		"players":  h.getPlayerList(room),
	}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "room_created", Payload: respBytes}
}

func (h *Hub) handleJoinRoom(client *Client, payload json.RawMessage) {
	var req struct {
		UserID   string `json:"userId"`
		RoomCode string `json:"roomCode"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid join_room payload")
		return
	}

	// Find room by code
	h.mu.RLock()
	var targetRoom *Room
	for _, room := range h.rooms {
		if room.Code == req.RoomCode {
			targetRoom = room
			break
		}
	}
	h.mu.RUnlock()

	// M-07 FIX: Block joining a room that already has an active game in progress
	if targetRoom != nil {
		targetRoom.mu.RLock()
		status := targetRoom.Status
		targetRoom.mu.RUnlock()
		if status == RoomPlaying || status == RoomFinished {
			sendError(client, "Game sudah berjalan, tidak bisa bergabung")
			return
		}
	}

	// If room not found AND it's a public room code (PUB1, PUB2, etc.), auto-create it
	if targetRoom == nil {
		if len(req.RoomCode) >= 4 && req.RoomCode[:3] == "PUB" {
			// Auto-create public room
			targetRoom = h.createPublicRoom(req.RoomCode, req.UserID)
			if targetRoom == nil {
				sendError(client, "Failed to create public room")
				return
			}
		} else {
			sendError(client, "Room not found")
			return
		}
	}

	// Get player profile with chibi config
	displayName, avatarID, avatarURL, chibiConfig := h.getPlayerProfile(req.UserID)

	targetRoom.mu.Lock()
	targetRoom.Clients[req.UserID] = client
	targetRoom.Players[req.UserID] = &RoomPlayer{
		UserID:      req.UserID,
		DisplayName: displayName,
		AvatarID:    avatarID,
		AvatarURL:   avatarURL,
		ChibiConfig: chibiConfig,
		IsReady:     false,
		Slot:        len(targetRoom.Players),
	}
	client.RoomID = targetRoom.ID
	players := h.getPlayerList(targetRoom)
	targetRoom.mu.Unlock()

	// C-4 FIX: maxPlayers was hardcoded to 16. Read from room's TimerSettings
	// (set by host via update_room_config) with fallback to 18 (max allowed).
	targetRoom.mu.RLock()
	maxPlayersInRoom := 18
	if ts, ok := targetRoom.TimerSettings["maxPlayers"]; ok && ts >= 8 && ts <= 18 {
		maxPlayersInRoom = ts
	}
	targetRoom.mu.RUnlock()

	// Send room_joined to joiner with full player list
	resp := map[string]interface{}{
		"roomId":     targetRoom.ID,
		"roomCode":   targetRoom.Code,
		"userId":     req.UserID,
		"hostId":     targetRoom.HostID,
		"maxPlayers": maxPlayersInRoom,
		"players":    players,
	}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "room_joined", Payload: respBytes}

	// Broadcast room_updated with full player list to ALL in room (including joiner)
	updateResp := map[string]interface{}{
		"roomId":  targetRoom.ID,
		"players": players,
	}
	updateBytes, _ := json.Marshal(updateResp)
	h.broadcastToRoom(targetRoom.ID, &Message{Type: "room_updated", Payload: updateBytes}, nil)
}

// createPublicRoom creates a new public room with the given code
func (h *Hub) createPublicRoom(code string, hostUserID string) *Room {
	roomID := generateID()

	room := &Room{
		ID:      roomID,
		Code:    code,
		HostID:  hostUserID,
		Status:  RoomWaiting,
		Clients: make(map[string]*Client),
		Players: make(map[string]*RoomPlayer),
	}

	h.mu.Lock()
	h.rooms[roomID] = room
	h.mu.Unlock()

	logger.RoomCreated(roomID, code, hostUserID)
	go h.broadcastRoomListUpdate()
	return room
}

func (h *Hub) handleLeaveRoom(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	// #1 FIX: handleLeaveRoom previously acquired room.mu.Lock TWICE — once for the
	// host-leave path and again for MarkPlayerDisconnected. This caused a double-lock
	// if the first critical section fell through to the second lock without returning.
	// Fix: use a single lock scope, collect everything we need, then unlock ONCE.
	room.mu.Lock()
	delete(room.Clients, req.UserID)
	delete(room.Players, req.UserID)
	client.RoomID = ""

	isHost := room.HostID == req.UserID
	hasGame := room.Game != nil

	if isHost {
		if hasGame {
			// Game is running — migrate host instead of destroying room
			var newHostID string
			for uid := range room.Clients {
				if uid != req.UserID {
					newHostID = uid
					break
				}
			}
			if newHostID != "" {
				room.HostID = newHostID
				room.Game = game.MarkPlayerDisconnected(room.Game, req.UserID)
				room.mu.Unlock()
				logger.Info(logger.CatRoom, "Host left during game — migrated", map[string]interface{}{
					"roomId": req.RoomID, "newHost": newHostID,
				})
				resp, _ := json.Marshal(map[string]interface{}{"newHostId": newHostID, "reason": "Host keluar, host baru ditunjuk"})
				h.broadcastToRoom(req.RoomID, &Message{Type: "host_changed", Payload: resp}, nil)
				h.broadcastRoomUpdate(req.RoomID)
				return
			}
			// No other players — destroy
		}

		// No game or no other players — kick all and destroy
		kickMsg, _ := json.Marshal(map[string]string{"reason": "Host left the room"})
		for _, c := range room.Clients {
			safeSend(c, &Message{Type: "kicked", Payload: kickMsg})
			c.RoomID = ""
		}
		room.Clients = make(map[string]*Client)
		room.Players = make(map[string]*RoomPlayer)
		room.mu.Unlock()

		h.mu.Lock()
		delete(h.rooms, req.RoomID)
		h.mu.Unlock()
		logger.RoomDestroyed(req.RoomID, "host left")
		return
	}

	// Non-host: mark disconnected in active game (still under the same lock scope)
	if hasGame {
		room.Game = game.MarkPlayerDisconnected(room.Game, req.UserID)
	}
	room.mu.Unlock()

	// Broadcast full player list to remaining players
	h.broadcastRoomUpdate(req.RoomID)
}

func (h *Hub) handlePlayerReady(client *Client, payload json.RawMessage) {
	var req struct {
		UserID string `json:"userId"`
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	// Update player ready state in room
	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if ok {
		room.mu.Lock()
		if p, exists := room.Players[req.UserID]; exists {
			p.IsReady = true
		}
		room.mu.Unlock()
	}

	// Broadcast full player list with updated ready state
	h.broadcastRoomUpdate(req.RoomID)
}

func (h *Hub) handleKick(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID       string `json:"roomId"`
		TargetUserID string `json:"targetUserId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok {
		return
	}
	// Only host can kick
	if room.HostID != client.UserID {
		sendError(client, "Only host can kick")
		return
	}

	var kickedClient *Client
	room.mu.Lock()
	if target, exists := room.Clients[req.TargetUserID]; exists {
		kickedClient = target
		resp, _ := json.Marshal(map[string]string{"reason": "Kicked by host"})
		safeSend(target, &Message{Type: "kicked", Payload: resp})
		delete(room.Clients, req.TargetUserID)
		delete(room.Players, req.TargetUserID)
		target.RoomID = ""
	}
	room.mu.Unlock()

	// M-12 FIX: fully remove kicked client from hub's client set and userIndex
	if kickedClient != nil {
		h.unregister <- kickedClient
	}

	// Broadcast full player list to remaining players
	h.broadcastRoomUpdate(req.RoomID)
}

func (h *Hub) handleRoomSettings(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID   string                 `json:"roomId"`
		Settings map[string]interface{} `json:"settings"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok || room.HostID != client.UserID {
		return
	}
	resp, _ := json.Marshal(map[string]interface{}{"settings": req.Settings})
	h.broadcastToRoom(req.RoomID, &Message{Type: "room_settings_updated", Payload: resp}, nil)
}

func (h *Hub) handleUpdateRoomConfig(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID        string                 `json:"roomId"`
		MaxPlayers    int                    `json:"maxPlayers"`
		TimerDuration map[string]interface{} `json:"timerDuration"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid room config payload")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok {
		sendError(client, "Room not found")
		return
	}

	// Only host can update config
	if room.HostID != client.UserID {
		sendError(client, "Only host can update room config")
		return
	}

	// Validate max players (8-18)
	if req.MaxPlayers < 8 || req.MaxPlayers > 18 {
		req.MaxPlayers = 12 // default
	}

	room.mu.Lock()
	if room.TimerSettings == nil {
		room.TimerSettings = make(map[string]int)
	}
	// Store maxPlayers in TimerSettings so handleStartGame can read it
	room.TimerSettings["maxPlayers"] = req.MaxPlayers
	for k, v := range req.TimerDuration {
		if num, ok := v.(float64); ok {
			room.TimerSettings[k] = int(num)
		} else if num, ok := v.(int); ok {
			room.TimerSettings[k] = num
		}
	}
	room.mu.Unlock()

	logger.Info(logger.CatRoom, "Room config updated", map[string]interface{}{
		"roomId":     req.RoomID,
		"maxPlayers": req.MaxPlayers,
		"timer":      req.TimerDuration,
	})

	// Broadcast config update to all players in room
	resp := map[string]interface{}{
		"maxPlayers":    req.MaxPlayers,
		"timerDuration": req.TimerDuration,
	}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(req.RoomID, &Message{Type: "room_config_updated", Payload: respBytes}, nil)
}

// handleGetPublicRooms returns a list of public rooms (PUB1-PUB10) with real player counts
func (h *Hub) handleGetPublicRooms(client *Client) {
	// C-05b FIX: Return ALL active rooms that are joinable (waiting/countdown).
	// Previous implementation only looked for hardcoded PUB1-PUB10 IDs which
	// never matched dynamically-created rooms, resulting in an always-empty list.
	const maxPublicRooms = 20

	type PublicRoomInfo struct {
		RoomID      string `json:"roomId"`
		Code        string `json:"code"`
		PlayerCount int    `json:"playerCount"`
		MaxPlayers  int    `json:"maxPlayers"`
		Status      string `json:"status"`
		HostName    string `json:"hostName,omitempty"`
	}

	rooms := make([]PublicRoomInfo, 0, maxPublicRooms)

	h.mu.RLock()
	for _, room := range h.rooms {
		// Only show rooms that can still be joined
		if room.Status != RoomWaiting && room.Status != RoomCountdown {
			continue
		}
		room.mu.RLock()
		playerCount := len(room.Players)
		// Determine maxPlayers from game config if game exists, else default to 18
		maxPlayers := 18
		if room.Game != nil {
			maxPlayers = room.Game.Config.MaxPlayers
		}
		// Skip full rooms
		if playerCount >= maxPlayers {
			room.mu.RUnlock()
			continue
		}
		info := PublicRoomInfo{
			RoomID:      room.ID,
			Code:        room.Code,
			PlayerCount: playerCount,
			MaxPlayers:  maxPlayers,
			Status:      string(room.Status),
		}
		if hostPlayer, hasHost := room.Players[room.HostID]; hasHost {
			info.HostName = hostPlayer.DisplayName
		}
		room.mu.RUnlock()
		rooms = append(rooms, info)
		if len(rooms) >= maxPublicRooms {
			break
		}
	}
	h.mu.RUnlock()

	resp := map[string]interface{}{
		"rooms": rooms,
	}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "public_rooms_list", Payload: respBytes}
}

// GetPublicRoomsList exported method for REST API /api/rooms/public
func (h *Hub) GetPublicRoomsList() []map[string]interface{} {
	h.mu.RLock()
	defer h.mu.RUnlock()

	result := make([]map[string]interface{}, 0)
	for _, room := range h.rooms {
		if room.Status != RoomWaiting && room.Status != RoomCountdown {
			continue
		}
		room.mu.RLock()
		playerCount := len(room.Players)
		maxPlayers := 18
		if room.Game != nil {
			maxPlayers = room.Game.Config.MaxPlayers
		}
		if playerCount >= maxPlayers {
			room.mu.RUnlock()
			continue
		}
		hostName := "Host"
		if hostPlayer, hasHost := room.Players[room.HostID]; hasHost {
			hostName = hostPlayer.DisplayName
		}
		roomInfo := map[string]interface{}{
			"roomId":      room.ID,
			"code":        room.Code,
			"playerCount": playerCount,
			"maxPlayers":  maxPlayers,
			"status":      string(room.Status),
			"hostName":    hostName,
		}
		room.mu.RUnlock()
		result = append(result, roomInfo)
	}
	return result
}

// broadcastRoomUpdate sends full player list to all clients in room
func (h *Hub) broadcastRoomUpdate(roomID string) {
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.RLock()
	players := h.getPlayerList(room)
	room.mu.RUnlock()

	resp := map[string]interface{}{
		"roomId":  roomID,
		"players": players,
	}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(roomID, &Message{Type: "room_updated", Payload: respBytes}, nil)
}

// ─── Room Auto-Refresh (MED #7) ──────────────────────────────

// broadcastRoomListUpdate sends the current public room list to ALL connected
// clients. Called whenever a room is created or destroyed so home pages
// auto-update without polling.
func (h *Hub) broadcastRoomListUpdate() {
	// Reuse the same logic as handleGetPublicRooms but send to everyone
	h.mu.RLock()
	type roomInfo struct {
		ID          string `json:"id"`
		Code        string `json:"code"`
		Status      string `json:"status"`
		PlayerCount int    `json:"playerCount"`
		MaxPlayers  int    `json:"maxPlayers"`
		HostName    string `json:"hostName"`
	}
	var rooms []roomInfo
	for _, room := range h.rooms {
		room.mu.RLock()
		ri := roomInfo{
			ID:          room.ID,
			Code:        room.Code,
			Status:      string(room.Status),
			PlayerCount: len(room.Players),
			MaxPlayers:  18,
		}
		if ts, ok := room.TimerSettings["maxPlayers"]; ok {
			ri.MaxPlayers = ts
		}
		if hostPlayer, ok := room.Players[room.HostID]; ok {
			ri.HostName = hostPlayer.DisplayName
		}
		room.mu.RUnlock()
		// Only show waiting rooms (not playing/finished)
		if room.Status == RoomWaiting {
			rooms = append(rooms, ri)
		}
	}
	h.mu.RUnlock()

	payload, _ := json.Marshal(map[string]interface{}{
		"rooms": rooms,
		"count": len(rooms),
	})
	h.BroadcastAll("public_rooms_update", json.RawMessage(payload))
}

// cleanupRoom removes a room after the game ends (replaces scheduleRoomCleanup).
// H-10 FIX: Called via time.AfterFunc — no goroutine blocked on Sleep.
func (h *Hub) cleanupRoom(roomID string) {
	h.stopRoomTimer(roomID)

	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.Lock()
	cleanupMsg, _ := json.Marshal(map[string]string{"reason": "game_ended"})
	for _, c := range room.Clients {
		safeSend(c, &Message{Type: "room_closed", Payload: cleanupMsg})
		c.RoomID = ""
	}
	room.Clients = make(map[string]*Client)
	room.mu.Unlock()

	h.mu.Lock()
	delete(h.rooms, roomID)
	h.mu.Unlock()
	logger.RoomDestroyed(roomID, "game ended")
	go h.broadcastRoomListUpdate()
}

// scheduleRoomCleanup kept for backward compat — delegates to cleanupRoom via AfterFunc.
func (h *Hub) scheduleRoomCleanup(roomID string, delaySec int) {
	time.AfterFunc(time.Duration(delaySec)*time.Second, func() { h.cleanupRoom(roomID) })
}
