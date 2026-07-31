package ws

import (
	"encoding/json"
	"runtime"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/bot"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/filter"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

// Performance tuning constants
const (
	// Worker pool size - scales with CPU cores
	minWorkers = 4
	maxWorkers = 32
	
	// Channel buffer sizes
	registerBufferSize   = 256
	unregisterBufferSize = 256
	broadcastBufferSize  = 2048
	
	// Profile cache settings
	profileCacheTTL     = 5 * time.Minute
	profileCacheCleanup = 10 * time.Minute
)

// Hub maintains the set of active clients and rooms
type Hub struct {
	// Registered clients
	clients map[*Client]bool

	// Room ID → Room
	rooms map[string]*Room

	// Register requests
	register chan *Client

	// Unregister requests
	unregister chan *Client

	// Inbound messages from clients (buffered for workers)
	broadcast chan *ClientMessage

	// Profile cache to reduce DB queries
	profileCache sync.Map // userID → *CachedProfile

	// Worker pool control
	workerCount int
	
	mu sync.RWMutex
}

// CachedProfile holds cached player profile data
type CachedProfile struct {
	DisplayName string
	AvatarID    int
	ChibiConfig map[string]interface{}
	CachedAt    time.Time
}

// RoomStatus represents the room lifecycle
type RoomStatus string

const (
	RoomWaiting   RoomStatus = "waiting"
	RoomCountdown RoomStatus = "countdown"
	RoomPlaying   RoomStatus = "playing"
	RoomFinished  RoomStatus = "finished"
	RoomClosing   RoomStatus = "closing"
)

// Room represents a game room with connected players
type Room struct {
	ID         string
	Code       string
	HostID     string
	Status     RoomStatus
	Clients    map[string]*Client       // userID → client
	Players    map[string]*RoomPlayer   // userID → player info
	Game       *game.GameState
	mu         sync.RWMutex
}

// RoomPlayer holds player info in lobby
type RoomPlayer struct {
	UserID      string                 `json:"userId"`
	DisplayName string                 `json:"displayName"`
	AvatarID    int                    `json:"avatarId"`
	ChibiConfig map[string]interface{} `json:"chibiConfig,omitempty"`
	IsReady     bool                   `json:"isReady"`
	Slot        int                    `json:"slot"`
}

// ClientMessage wraps a message with the sender
type ClientMessage struct {
	Client  *Client
	Message *Message
}

func NewHub() *Hub {
	// Calculate optimal worker count based on CPU cores
	numCPU := runtime.NumCPU()
	workers := numCPU * 2
	if workers < minWorkers {
		workers = minWorkers
	}
	if workers > maxWorkers {
		workers = maxWorkers
	}

	h := &Hub{
		clients:     make(map[*Client]bool),
		rooms:       make(map[string]*Room),
		register:    make(chan *Client, registerBufferSize),
		unregister:  make(chan *Client, unregisterBufferSize),
		broadcast:   make(chan *ClientMessage, broadcastBufferSize),
		workerCount: workers,
	}

	return h
}

// Run starts the hub's main loop and worker pool
func (h *Hub) Run() {
	// Start worker pool for message handling
	for i := 0; i < h.workerCount; i++ {
		go h.messageWorker(i)
	}
	logger.Info(logger.CatSystem, "Started message workers", map[string]interface{}{
		"workers": h.workerCount,
	})

	// Start profile cache cleanup goroutine
	go h.profileCacheCleanupLoop()

	// Main loop handles only register/unregister (lightweight operations)
	for {
		select {
		case client := <-h.register:
			h.handleRegister(client)

		case client := <-h.unregister:
			h.handleUnregister(client)
		}
	}
}

// messageWorker processes messages from the broadcast channel
func (h *Hub) messageWorker(id int) {
	for cm := range h.broadcast {
		h.handleMessage(cm)
	}
	logger.Debug(logger.CatSystem, "Worker stopped", map[string]interface{}{"workerId": id})
}

// handleRegister adds a client to the hub
func (h *Hub) handleRegister(client *Client) {
	h.mu.Lock()
	h.clients[client] = true
	clientCount := len(h.clients)
	h.mu.Unlock()
	logger.WSConnect(client.UserID, client.Conn.RemoteAddr().String())
	logger.Debug(logger.CatWebSocket, "Total clients connected", map[string]interface{}{
		"count": clientCount,
	})
}

// handleUnregister removes a client from the hub
func (h *Hub) handleUnregister(client *Client) {
	h.mu.Lock()
	if _, ok := h.clients[client]; ok {
		delete(h.clients, client)
		close(client.Send)
	}
	clientCount := len(h.clients)
	h.mu.Unlock()

	// Remove from room if in one
	if client.RoomID != "" {
		h.handleClientDisconnect(client)
	}
	logger.WSDisconnect(client.UserID, "connection closed")
	logger.Debug(logger.CatWebSocket, "Total clients connected", map[string]interface{}{
		"count": clientCount,
	})
}

// handleClientDisconnect handles cleanup when a client disconnects from a room
func (h *Hub) handleClientDisconnect(client *Client) {
	roomID := client.RoomID
	h.mu.RLock()
	room, roomOk := h.rooms[roomID]
	h.mu.RUnlock()
	
	if !roomOk {
		return
	}

	room.mu.Lock()
	delete(room.Clients, client.UserID)
	delete(room.Players, client.UserID)

	// If game is active, mark player disconnected (not removed)
	if room.Game != nil {
		room.Game = game.MarkPlayerDisconnected(room.Game, client.UserID)
	}

	// If host disconnects and no game running, destroy room
	isHost := room.HostID == client.UserID
	hasGame := room.Game != nil
	clientCount := len(room.Clients)
	room.mu.Unlock()

	if isHost && !hasGame {
		// Notify all remaining players and destroy room
		kickMsg, _ := json.Marshal(map[string]string{"reason": "Host disconnected"})
		h.broadcastToRoom(roomID, &Message{Type: "kicked", Payload: kickMsg}, nil)

		room.mu.Lock()
		for _, c := range room.Clients {
			c.RoomID = ""
		}
		room.Clients = make(map[string]*Client)
		room.Players = make(map[string]*RoomPlayer)
		room.mu.Unlock()

		h.mu.Lock()
		delete(h.rooms, roomID)
		h.mu.Unlock()
		logger.RoomDestroyed(roomID, "host disconnected")
	} else if clientCount > 0 {
		// Broadcast updated player list to remaining players
		h.broadcastRoomUpdate(roomID)
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

func (h *Hub) handleMessage(cm *ClientMessage) {
	msg := cm.Message
	client := cm.Client
	startTime := time.Now()

	// Log incoming message
	logger.WSMessage(client.UserID, msg.Type, client.RoomID, nil)

	switch msg.Type {
	case "create_room":
		h.handleCreateRoom(client, msg.Payload)
	case "join_room":
		h.handleJoinRoom(client, msg.Payload)
	case "leave_room":
		h.handleLeaveRoom(client, msg.Payload)
	case "start_game":
		h.handleStartGame(client, msg.Payload)
	case "submit_night_action":
		h.handleNightAction(client, msg.Payload)
	case "submit_witch_action":
		h.handleWitchAction(client, msg.Payload)
	case "cast_vote":
		h.handleVote(client, msg.Payload)
	case "confirm_role_reveal":
		h.handleConfirmRole(client, msg.Payload)
	case "submit_testament":
		h.handleTestament(client, msg.Payload)
	case "send_chat":
		h.handleChat(client, msg.Payload)
	case "team_chat":
		h.handleTeamChat(client, msg.Payload)
	case "report_player":
		h.handleReportPlayer(client, msg.Payload)
	case "block_player":
		h.handleBlockPlayer(client, msg.Payload)
	case "reconnect_game":
		h.handleReconnectGame(client)
	case "player_ready":
		h.handlePlayerReady(client, msg.Payload)
	case "send_emote":
		h.handleEmote(client, msg.Payload)
	case "typing":
		h.handleTyping(client)
	case "invite_to_room":
		h.handleInvite(client, msg.Payload)
	case "kick_player":
		h.handleKick(client, msg.Payload)
	case "update_room_settings":
		h.handleRoomSettings(client, msg.Payload)
	case "update_room_config":
		h.handleUpdateRoomConfig(client, msg.Payload)
	case "ping":
		client.Send <- &Message{Type: "pong", Payload: json.RawMessage(`{}`)}
	case "get_public_rooms":
		h.handleGetPublicRooms(client)
	default:
		logger.Warn(logger.CatWebSocket, "Unknown message type", map[string]interface{}{
			"userId": client.UserID,
			"type":   msg.Type,
		})
	}

	// Log processing time for non-trivial messages
	duration := time.Since(startTime)
	if duration > 10*time.Millisecond && msg.Type != "ping" {
		logger.Debug(logger.CatWebSocket, "Message processed", map[string]interface{}{
			"type":     msg.Type,
			"userId":   client.UserID,
			"duration": duration.String(),
		})
	}
}

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

	// Get player profile with chibi config
	displayName, avatarID, chibiConfig := h.getPlayerProfile(req.UserID)

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
	displayName, avatarID, chibiConfig := h.getPlayerProfile(req.UserID)

	targetRoom.mu.Lock()
	targetRoom.Clients[req.UserID] = client
	targetRoom.Players[req.UserID] = &RoomPlayer{
		UserID:      req.UserID,
		DisplayName: displayName,
		AvatarID:    avatarID,
		ChibiConfig: chibiConfig,
		IsReady:     false,
		Slot:        len(targetRoom.Players),
	}
	client.RoomID = targetRoom.ID
	players := h.getPlayerList(targetRoom)
	targetRoom.mu.Unlock()

	// Send room_joined to joiner with full player list
	resp := map[string]interface{}{
		"roomId":     targetRoom.ID,
		"roomCode":   targetRoom.Code,
		"userId":     req.UserID,
		"hostId":     targetRoom.HostID,
		"maxPlayers": 16,
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

	room.mu.Lock()
	delete(room.Clients, req.UserID)
	delete(room.Players, req.UserID)
	client.RoomID = ""

	// If host leaves — destroy the entire room
	if room.HostID == req.UserID {
		// Notify all remaining players
		kickMsg, _ := json.Marshal(map[string]string{"reason": "Host left the room"})
		for _, c := range room.Clients {
			safeSend(c, &Message{Type: "kicked", Payload: kickMsg})
			c.RoomID = ""
		}
		room.Clients = make(map[string]*Client)
		room.Players = make(map[string]*RoomPlayer)
		room.mu.Unlock()

		// Remove room from hub
		h.mu.Lock()
		delete(h.rooms, req.RoomID)
		h.mu.Unlock()
		logger.RoomDestroyed(req.RoomID, "host left")
		return
	}
	room.mu.Unlock()

	// Mark player as disconnected in active game
	room.mu.Lock()
	if room.Game != nil {
		room.Game = game.MarkPlayerDisconnected(room.Game, req.UserID)
	}
	room.mu.Unlock()

	// Broadcast full player list to remaining players
	h.broadcastRoomUpdate(req.RoomID)
}

func (h *Hub) handleStartGame(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID string `json:"roomId"`
		HostID string `json:"hostId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid start_game payload")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok {
		sendError(client, "Room not found")
		return
	}

	if room.HostID != req.HostID {
		sendError(client, "Only host can start the game")
		return
	}

	// Set room to countdown status
	room.mu.Lock()
	room.Status = RoomCountdown
	room.mu.Unlock()

	// Broadcast countdown (client shows 3-2-1)
	countResp, _ := json.Marshal(map[string]interface{}{"seconds": 3})
	h.broadcastToRoom(req.RoomID, &Message{Type: "game_countdown", Payload: countResp}, nil)

	// Collect player info with chibi configs from room players
	room.mu.RLock()
	playerInfos := make([]game.PlayerInfo, 0, len(room.Players))
	for _, rp := range room.Players {
		playerInfos = append(playerInfos, game.PlayerInfo{
			ID:          rp.UserID,
			DisplayName: rp.DisplayName,
			AvatarID:    rp.AvatarID,
			ChibiConfig: rp.ChibiConfig,
		})
	}
	room.mu.RUnlock()

	// Fill with bots to reach 18 players for a full game
	playerInfos = bot.FillWithBotsInfo(playerInfos, 18)

	// Create game with full player info (including chibi configs)
	gameState := game.CreateGame(playerInfos)
	bot.MarkBots(gameState)
	gameState = game.StartGame(gameState)

	// Process bot role confirmations immediately
	gameState = bot.ProcessBotActions(gameState, bot.Medium)

	room.mu.Lock()
	room.Game = gameState
	room.Status = RoomPlaying
	room.mu.Unlock()

	// Start the timer goroutine for this room
	h.startRoomTimer(req.RoomID)

	// Send filtered game state per player (each player sees only their own role)
	h.broadcastGameState(req.RoomID)
}

func (h *Hub) handleNightAction(client *Client, payload json.RawMessage) {
	var req struct {
		PlayerID     string  `json:"playerId"`
		TargetID     string  `json:"targetId"`
		WitchHeal    bool    `json:"witchHeal"`
		PoisonTarget *string `json:"poisonTarget"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid night action")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()
	newState, err := game.SubmitNightActionSequential(room.Game, req.PlayerID, req.TargetID, req.WitchHeal, req.PoisonTarget)
	if err != nil {
		room.mu.Unlock()
		sendError(client, err.Error())
		return
	}
	room.Game = newState
	room.mu.Unlock()

	h.broadcastGameState(client.RoomID)
}

func (h *Hub) handleWitchAction(client *Client, payload json.RawMessage) {
	var req struct {
		PlayerID     string  `json:"playerId"`
		UseHeal      bool    `json:"useHeal"`
		PoisonTarget *string `json:"poisonTarget"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid witch action")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()
	newState, err := game.SubmitNightActionSequential(room.Game, req.PlayerID, "", req.UseHeal, req.PoisonTarget)
	if err != nil {
		room.mu.Unlock()
		sendError(client, err.Error())
		return
	}
	room.Game = newState
	room.mu.Unlock()

	h.broadcastGameState(client.RoomID)
}

func (h *Hub) handleVote(client *Client, payload json.RawMessage) {
	var req struct {
		VoterID  string `json:"voterId"`
		TargetID string `json:"targetId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		sendError(client, "Invalid vote")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()
	newState, err := game.CastVote(room.Game, req.VoterID, req.TargetID)
	if err != nil {
		room.mu.Unlock()
		sendError(client, err.Error())
		return
	}
	room.Game = newState
	room.mu.Unlock()

	h.broadcastGameState(client.RoomID)
}

func (h *Hub) handleConfirmRole(client *Client, payload json.RawMessage) {
	var req struct {
		PlayerID string `json:"playerId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()
	newState := game.ConfirmRoleReveal(room.Game, req.PlayerID)
	room.Game = newState
	room.mu.Unlock()

	h.broadcastGameState(client.RoomID)
}

func (h *Hub) handleTestament(client *Client, payload json.RawMessage) {
	var req struct {
		PlayerID string `json:"playerId"`
		Message  string `json:"message"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()
	newState := game.SubmitTestament(room.Game, req.PlayerID, req.Message)
	room.Game = newState
	room.mu.Unlock()

	h.broadcastGameState(client.RoomID)
}

func (h *Hub) handleChat(client *Client, payload json.RawMessage) {
	var req struct {
		SenderID string `json:"senderId"`
		Content  string `json:"content"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	if client.RoomID == "" {
		return
	}

	// Max 200 characters
	content := req.Content
	if len(content) > 200 {
		content = content[:200]
	}
	
	// Apply profanity filter
	content = filter.CensorProfanity(content)

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	// Only allow chat during DISCUSSION phase (alive players only)
	room.mu.RLock()
	canChat := false
	if room.Game != nil && (room.Game.Phase == game.PhaseDiscussion || room.Game.Phase == game.PhaseVoting) {
		for _, p := range room.Game.Players {
			if p.ID == req.SenderID && p.IsAlive {
				canChat = true
				break
			}
		}
	}
	room.mu.RUnlock()

	if !canChat {
		return
	}

	// Broadcast chat message to all players in room
	resp := map[string]interface{}{
		"senderId": req.SenderID,
		"content":  content,
	}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(client.RoomID, &Message{Type: "chat_message", Payload: respBytes}, nil)
}

func (h *Hub) handleTeamChat(client *Client, payload json.RawMessage) {
	var req struct {
		SenderID string `json:"senderId"`
		Content  string `json:"content"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	if client.RoomID == "" {
		return
	}

	content := req.Content
	if len(content) > 200 {
		content = content[:200]
	}
	
	// Apply profanity filter
	content = filter.CensorProfanity(content)

	h.mu.RLock()
	room, ok := h.rooms[client.RoomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.RLock()
	defer room.mu.RUnlock()

	if room.Game == nil {
		return
	}

	// Only allow team chat during night phases
	if !room.Game.Phase.IsNight() {
		return
	}

	// Find sender's role
	var senderRole game.Role
	var senderAlive bool
	for _, p := range room.Game.Players {
		if p.ID == req.SenderID {
			senderRole = p.Role
			senderAlive = p.IsAlive
			break
		}
	}

	if !senderAlive {
		return
	}

	// Only werewolves and seers can use team chat
	if senderRole != game.RoleWerewolf && senderRole != game.RoleSeer {
		return
	}

	// Find teammates to send to
	resp := map[string]interface{}{
		"senderId": req.SenderID,
		"content":  content,
		"team":     string(senderRole),
	}
	respBytes, _ := json.Marshal(resp)
	teamMsg := &Message{Type: "team_chat_message", Payload: respBytes}

	for _, p := range room.Game.Players {
		if !p.IsAlive || p.IsBot {
			continue
		}
		// Send to same role teammates
		if p.Role == senderRole {
			if c, ok := room.Clients[p.ID]; ok {
				safeSend(c, teamMsg)
			}
		}
	}
}

func (h *Hub) handleReportPlayer(client *Client, payload json.RawMessage) {
	var req struct {
		ReportedID string `json:"reportedId"`
		Reason     string `json:"reason"`
		Details    string `json:"details"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	// Validate reason
	validReasons := map[string]bool{
		"toxic": true, "cheating": true, "afk": true,
		"inappropriate_name": true, "spam": true, "other": true,
	}
	if !validReasons[req.Reason] {
		client.Send <- &Message{
			Type:    "report_error",
			Payload: json.RawMessage(`{"error":"invalid reason"}`),
		}
		return
	}

	// Prevent self-reporting
	if req.ReportedID == client.UserID {
		client.Send <- &Message{
			Type:    "report_error",
			Payload: json.RawMessage(`{"error":"cannot report yourself"}`),
		}
		return
	}

	// Get current game ID if in a game
	var gameID string
	if client.RoomID != "" {
		h.mu.RLock()
		if room, ok := h.rooms[client.RoomID]; ok {
			room.mu.RLock()
			if room.Game != nil {
				gameID = room.Game.ID
			}
			room.mu.RUnlock()
		}
		h.mu.RUnlock()
	}

	// Truncate details
	details := req.Details
	if len(details) > 500 {
		details = details[:500]
	}

	// Save report to database
	err := db.ReportPlayer(client.UserID, req.ReportedID, req.Reason, details, gameID)
	if err != nil {
		logger.Error(logger.CatWebSocket, "Failed to save report", map[string]interface{}{
			"reporterId": client.UserID,
			"reportedId": req.ReportedID,
			"error":      err.Error(),
		})
		client.Send <- &Message{
			Type:    "report_error",
			Payload: json.RawMessage(`{"error":"failed to submit report"}`),
		}
		return
	}

	logger.Info(logger.CatWebSocket, "Player reported", map[string]interface{}{
		"reporterId": client.UserID,
		"reportedId": req.ReportedID,
		"reason":     req.Reason,
		"gameId":     gameID,
	})

	client.Send <- &Message{
		Type:    "report_success",
		Payload: json.RawMessage(`{"status":"reported"}`),
	}
}

func (h *Hub) handleBlockPlayer(client *Client, payload json.RawMessage) {
	var req struct {
		BlockedID string `json:"blockedId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	// Prevent self-blocking
	if req.BlockedID == client.UserID {
		client.Send <- &Message{
			Type:    "block_error",
			Payload: json.RawMessage(`{"error":"cannot block yourself"}`),
		}
		return
	}

	// Block the user via DB
	err := db.BlockUser(client.UserID, req.BlockedID)
	if err != nil {
		logger.Error(logger.CatWebSocket, "Failed to block user", map[string]interface{}{
			"blockerId": client.UserID,
			"blockedId": req.BlockedID,
			"error":     err.Error(),
		})
		client.Send <- &Message{
			Type:    "block_error",
			Payload: json.RawMessage(`{"error":"failed to block user"}`),
		}
		return
	}

	logger.Info(logger.CatWebSocket, "User blocked", map[string]interface{}{
		"blockerId": client.UserID,
		"blockedId": req.BlockedID,
	})

	client.Send <- &Message{
		Type:    "block_success",
		Payload: json.RawMessage(`{"status":"blocked"}`),
	}
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

func (h *Hub) handleEmote(client *Client, payload json.RawMessage) {
	var req struct {
		PlayerID string `json:"playerId"`
		EmoteID  string `json:"emoteId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	resp := map[string]interface{}{"playerId": req.PlayerID, "emoteId": req.EmoteID}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(client.RoomID, &Message{Type: "emote_received", Payload: respBytes}, nil)
}

func (h *Hub) handleTyping(client *Client) {
	resp := map[string]interface{}{"playerId": client.UserID}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(client.RoomID, &Message{Type: "typing_indicator", Payload: respBytes}, client)
}

func (h *Hub) handleInvite(client *Client, payload json.RawMessage) {
	var req struct {
		TargetUserID string `json:"targetUserId"`
		RoomCode     string `json:"roomCode"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	// Find target client by userID
	h.mu.RLock()
	for c := range h.clients {
		if c.UserID == req.TargetUserID {
			resp := map[string]interface{}{"fromUserId": client.UserID, "roomCode": req.RoomCode}
			respBytes, _ := json.Marshal(resp)
			c.Send <- &Message{Type: "game_invite", Payload: respBytes}
			break
		}
	}
	h.mu.RUnlock()
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
	room.mu.Lock()
	if target, exists := room.Clients[req.TargetUserID]; exists {
		resp, _ := json.Marshal(map[string]string{"reason": "Kicked by host"})
		target.Send <- &Message{Type: "kicked", Payload: resp}
		delete(room.Clients, req.TargetUserID)
		delete(room.Players, req.TargetUserID)
		target.RoomID = ""
	}
	room.mu.Unlock()

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

func (h *Hub) handleReconnectGame(client *Client) {
	// Find if this user has an active game in any room
	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, room := range h.rooms {
		room.mu.RLock()
		if room.Game == nil || room.Game.Phase == game.PhaseGameEnd {
			room.mu.RUnlock()
			continue
		}

		// Check if player is in this game
		found := false
		for _, p := range room.Game.Players {
			if p.ID == client.UserID {
				found = true
				break
			}
		}

		if found {
			// Rejoin the room
			room.mu.RUnlock()
			room.mu.Lock()
			room.Clients[client.UserID] = client
			client.RoomID = room.ID

			// Mark player as reconnected
			for i := range room.Game.Players {
				if room.Game.Players[i].ID == client.UserID {
					room.Game.Players[i].IsConnected = true
					break
				}
			}
			room.mu.Unlock()

			// Send current game state to reconnected player
			filteredState := game.FilterStateForPlayer(room.Game, client.UserID)
			stateBytes, _ := json.Marshal(filteredState)
			resp := map[string]interface{}{
				"roomId":    room.ID,
				"roomCode":  room.Code,
				"gameState": json.RawMessage(stateBytes),
			}
			respBytes, _ := json.Marshal(resp)
			client.Send <- &Message{Type: "game_resumed", Payload: respBytes}
			logger.Info(logger.CatRoom, "Player reconnected", map[string]interface{}{"userId": client.UserID, "roomId": room.ID})
			return
		}
		room.mu.RUnlock()
	}

	// No active game found
	resp, _ := json.Marshal(map[string]interface{}{"active": false})
	client.Send <- &Message{Type: "no_active_game", Payload: resp}
}

func (h *Hub) broadcastGameState(roomID string) {
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	// Single lock scope: process bots + broadcast
	room.mu.Lock()
	room.Game = bot.ProcessBotActions(room.Game, bot.Medium)

	// Record match results when game ends (collect data, write after unlock)
	var recordPlayers []game.PlayerState
	var recordGameID string
	var recordWinner *game.Team
	var recordRound int
	var recordPlayerCount int
	var playerRewards map[string]*game.PlayerRewards
	
	if room.Game.Phase == game.PhaseGameEnd && room.Game.Winner != nil {
		recordPlayers = make([]game.PlayerState, len(room.Game.Players))
		copy(recordPlayers, room.Game.Players)
		recordGameID = room.Game.ID
		recordWinner = room.Game.Winner
		recordRound = room.Game.Round
		recordPlayerCount = len(room.Game.Players)
		
		// Pre-calculate rewards for each player (to include in their state)
		playerRewards = make(map[string]*game.PlayerRewards)
		for _, p := range room.Game.Players {
			if p.IsBot {
				continue
			}
			playerTeam := game.GetRoleTeam(p.Role)
			won := playerTeam == *recordWinner
			survived := p.IsAlive
			xp := db.CalculateXPReward(won, survived, recordRound, string(p.Role))
			coins := db.CalculateCoinReward(won, survived)
			// Use default rating (1000) for simplified MMR calculation
			mmr := db.CalculateMMRChange(1000, 1000, won, string(p.Role))
			playerRewards[p.ID] = &game.PlayerRewards{
				XPEarned:    xp,
				CoinsEarned: coins,
				Won:         won,
				Survived:    survived,
				MMRChange:   mmr,
			}
		}
	}

	// Build filtered states while under lock
	// Optimization: collect client info first, then release lock before sending
	type playerMsg struct {
		client *Client
		userID string
	}
	var clients []playerMsg
	for uid, c := range room.Clients {
		clients = append(clients, playerMsg{client: c, userID: uid})
	}
	
	// Pre-compute filtered states for each player
	states := make(map[string][]byte, len(clients))
	for _, pm := range clients {
		filteredState := game.FilterStateForPlayer(room.Game, pm.userID)
		// Attach rewards to player's state if game ended
		if playerRewards != nil {
			if rewards, ok := playerRewards[pm.userID]; ok {
				filteredState.Rewards = rewards
			}
		}
		stateBytes, _ := json.Marshal(filteredState)
		states[pm.userID] = stateBytes
	}
	room.mu.Unlock()

	// Send outside of lock (non-blocking with safeSend)
	for _, pm := range clients {
		if data, ok := states[pm.userID]; ok {
			safeSend(pm.client, &Message{Type: "game_state_update", Payload: data})
		}
	}

	// Record results async (outside lock)
	if recordWinner != nil {
		go h.recordGameResultsAsync(recordPlayers, recordGameID, *recordWinner, recordRound, recordPlayerCount)
		// Schedule room cleanup after game ends (give clients time to see results)
		go h.scheduleRoomCleanup(roomID, 60)
	}
}

// safeSend sends a message to a client without panicking on closed channel.
func safeSend(c *Client, msg *Message) {
	defer func() { recover() }()
	select {
	case c.Send <- msg:
	default:
	}
}

func (h *Hub) recordGameResultsAsync(players []game.PlayerState, gameID string, winnerTeam game.Team, round, playerCount int) {
	for _, p := range players {
		if p.IsBot {
			continue
		}
		playerTeam := game.GetRoleTeam(p.Role)
		won := playerTeam == winnerTeam
		survived := p.IsAlive
		db.RecordMatchWithXP(p.ID, gameID, string(p.Role), string(playerTeam), won, survived, round, 0, playerCount)
	}
}

// scheduleRoomCleanup removes a room from the hub after a delay (seconds).
// This gives clients time to view results before the room is destroyed.
func (h *Hub) scheduleRoomCleanup(roomID string, delaySec int) {
	time.Sleep(time.Duration(delaySec) * time.Second)

	// Stop timer first
	h.stopRoomTimer(roomID)

	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.Lock()
	// Notify all clients that the room is being cleaned up
	cleanupMsg, _ := json.Marshal(map[string]string{"reason": "game_ended"})
	for _, c := range room.Clients {
		safeSend(c, &Message{Type: "room_closed", Payload: cleanupMsg})
		c.RoomID = ""
	}
	room.Clients = make(map[string]*Client)
	room.mu.Unlock()

	// Remove room from hub
	h.mu.Lock()
	delete(h.rooms, roomID)
	h.mu.Unlock()
	logger.RoomDestroyed(roomID, "game ended")
}

func (h *Hub) broadcastToRoom(roomID string, msg *Message, exclude *Client) {
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.RLock()
	defer room.mu.RUnlock()

	for _, c := range room.Clients {
		if c != exclude {
			safeSend(c, msg)
		}
	}
}

func sendError(client *Client, msg string) {
	resp := map[string]string{"message": msg}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "error", Payload: respBytes}
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

// getPlayerProfile fetches displayName, avatarID, and chibiConfig with caching
func (h *Hub) getPlayerProfile(userID string) (string, int, map[string]interface{}) {
	// Check cache first
	if cached, ok := h.profileCache.Load(userID); ok {
		cp := cached.(*CachedProfile)
		if time.Since(cp.CachedAt) < profileCacheTTL {
			return cp.DisplayName, cp.AvatarID, cp.ChibiConfig
		}
		// Cache expired, will refresh below
	}

	// Default values
	displayName := "Player"
	avatarID := 1
	var chibiConfig map[string]interface{}

	// Try to get from database
	if db.DB != nil {
		profile, err := db.GetProfile(userID)
		if err == nil && profile != nil {
			displayName = profile.DisplayName
			avatarID = profile.AvatarID
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

	// Store in cache
	h.profileCache.Store(userID, &CachedProfile{
		DisplayName: displayName,
		AvatarID:    avatarID,
		ChibiConfig: chibiConfig,
		CachedAt:    time.Now(),
	})

	return displayName, avatarID, chibiConfig
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

// handleGetPublicRooms returns a list of public rooms (PUB1-PUB10) with real player counts
func (h *Hub) handleGetPublicRooms(client *Client) {
	// Public room IDs are PUB1 through PUB10
	publicRoomIDs := []string{"PUB1", "PUB2", "PUB3", "PUB4", "PUB5", "PUB6", "PUB7", "PUB8", "PUB9", "PUB10"}
	
	type PublicRoomInfo struct {
		RoomID      string `json:"roomId"`
		Code        string `json:"code"`
		PlayerCount int    `json:"playerCount"`
		MaxPlayers  int    `json:"maxPlayers"`
		Status      string `json:"status"`
		HostName    string `json:"hostName,omitempty"`
	}
	
	rooms := make([]PublicRoomInfo, 0, len(publicRoomIDs))
	
	h.mu.RLock()
	for _, pubID := range publicRoomIDs {
		info := PublicRoomInfo{
			RoomID:      pubID,
			Code:        pubID,
			PlayerCount: 0,
			MaxPlayers:  16,
			Status:      "empty",
		}
		
		// Check if this public room exists and has players
		if room, exists := h.rooms[pubID]; exists {
			room.mu.RLock()
			info.PlayerCount = len(room.Players)
			info.Status = string(room.Status)
			// Get host name if available
			if hostPlayer, hasHost := room.Players[room.HostID]; hasHost {
				info.HostName = hostPlayer.DisplayName
			}
			room.mu.RUnlock()
		}
		
		rooms = append(rooms, info)
	}
	h.mu.RUnlock()
	
	resp := map[string]interface{}{
		"rooms": rooms,
	}
	respBytes, _ := json.Marshal(resp)
	client.Send <- &Message{Type: "public_rooms_list", Payload: respBytes}
}
