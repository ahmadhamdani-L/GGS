package ws

import (
	"encoding/json"
	"runtime"
	"sync"
	"time"

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

	// Idempotency: how long to remember a processed requestId
	requestIDTTL = 60 * time.Second
)

// Hub maintains the set of active clients and rooms
type Hub struct {
	// Registered clients
	clients map[*Client]bool

	// C-07 FIX: Secondary index userID → *Client for O(1) lookup (replaces O(N) scan in handleInvite).
	userIndex map[string]*Client

	// Room ID → Room
	rooms map[string]*Room

	// V2 Room Manager (production-ready)
	roomMgr *RoomManager

	// Register requests
	register chan *Client

	// Unregister requests
	unregister chan *Client

	// Inbound messages from clients (buffered for workers)
	broadcast chan *ClientMessage

	// Profile cache to reduce DB queries
	profileCache sync.Map // userID → *CachedProfile

	// Idempotency: tracks seen requestIds per user with expiry
	requestsCache sync.Map // userID → map[requestID]time.Time

	// H-05 FIX: Max rooms limit (read from server_settings at startup, default 100)
	maxRooms int

	// Worker pool control
	workerCount int

	mu sync.RWMutex
}

// CachedProfile holds cached player profile data
type CachedProfile struct {
	DisplayName string
	AvatarID    int
	AvatarURL   string
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
	Clients    map[string]*Client       // userID → client (players)
	Spectators map[string]*Client       // LOW #8: userID → client (spectators, view-only)
	Players    map[string]*RoomPlayer   // userID → player info
	Game          *game.GameState
	TimerSettings map[string]int
	mu            sync.RWMutex
}

// RoomPlayer holds player info in lobby
type RoomPlayer struct {
	UserID      string                 `json:"userId"`
	DisplayName string                 `json:"displayName"`
	AvatarID    int                    `json:"avatarId"`
	AvatarURL   string                 `json:"avatarUrl,omitempty"` // custom uploaded photo
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
		userIndex:   make(map[string]*Client),
		rooms:       make(map[string]*Room),
		register:    make(chan *Client, registerBufferSize),
		unregister:  make(chan *Client, unregisterBufferSize),
		broadcast:   make(chan *ClientMessage, broadcastBufferSize),
		workerCount: workers,
		maxRooms:    100, // default; overridden by loadMaxRooms()
	}

	// Initialize V2 Room Manager
	h.roomMgr = NewRoomManager(h)

	return h
}

// Run starts the hub's main loop and worker pool
func (h *Hub) Run() {
	// Start idempotency cleanup goroutine
	go h.cleanupRequestCache()

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

// handleRegister adds a client to the hub and enforces single-session per user
func (h *Hub) handleRegister(client *Client) {
	h.mu.Lock()

	// C-07 FIX + Double Login Protection: use userIndex for O(1) old-session lookup
	if client.UserID != "" {
		if old, exists := h.userIndex[client.UserID]; exists && old != client {
			logger.Warn(logger.CatWebSocket, "Evicting duplicate session for user", map[string]interface{}{
				"userId": client.UserID,
				"oldIP":  old.Conn.RemoteAddr().String(),
				"newIP":  client.Conn.RemoteAddr().String(),
			})
			msgBytes, _ := json.Marshal(map[string]string{
				"message": "Akun Anda telah login di perangkat/sesi lain.",
				"reason":  "session_replaced",
			})
			safeSend(old, &Message{Type: "session_replaced", Payload: msgBytes})
			delete(h.clients, old)
			close(old.Send)
		}
		h.userIndex[client.UserID] = client
	}

	h.clients[client] = true
	clientCount := len(h.clients)
	h.mu.Unlock()
	logger.WSConnect(client.UserID, client.Conn.RemoteAddr().String())
	logger.Debug(logger.CatWebSocket, "Total clients connected", map[string]interface{}{
		"count": clientCount,
	})
}

// handleUnregister removes a client from the hub.
// #2 FIX: Close client.Send ONLY here. handleKick sends the kicked client to the
// unregister channel and does NOT close Send itself — preventing a double-close panic.
func (h *Hub) handleUnregister(client *Client) {
	h.mu.Lock()
	alreadyClosed := false
	if _, ok := h.clients[client]; ok {
		delete(h.clients, client)
		if h.userIndex[client.UserID] == client {
			delete(h.userIndex, client.UserID)
		}
		close(client.Send)
	} else {
		// Client was already removed (e.g. by session eviction in handleRegister).
		// Don't close Send again.
		alreadyClosed = true
	}
	clientCount := len(h.clients)
	h.mu.Unlock()

	if !alreadyClosed && client.RoomID != "" {
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
		// P3-45: Host migration — transfer host to another player instead of destroying room
		room.mu.Lock()
		var newHostID string
		for uid := range room.Clients {
			if uid != client.UserID {
				newHostID = uid
				break
			}
		}
		if newHostID != "" {
			// Migrate host to another player
			room.HostID = newHostID
			room.mu.Unlock()
			logger.Info(logger.CatRoom, "Host migrated", map[string]interface{}{
				"roomId": roomID, "oldHost": client.UserID, "newHost": newHostID,
			})
			// Notify all players about new host
			resp, _ := json.Marshal(map[string]interface{}{
				"newHostId": newHostID,
				"reason":    "Tuan rumah berganti karena host sebelumnya keluar",
			})
			h.broadcastToRoom(roomID, &Message{Type: "host_changed", Payload: resp}, nil)
			h.broadcastRoomUpdate(roomID)
		} else {
			// No other players — destroy room
			room.Clients = make(map[string]*Client)
			room.Players = make(map[string]*RoomPlayer)
			room.mu.Unlock()

			h.mu.Lock()
			delete(h.rooms, roomID)
			h.mu.Unlock()
			logger.RoomDestroyed(roomID, "host disconnected, no other players")
		}
	} else if isHost && hasGame {
		// During game: migrate host silently (game continues regardless)
		room.mu.Lock()
		for uid := range room.Clients {
			if uid != client.UserID {
				room.HostID = uid
				break
			}
		}
		room.mu.Unlock()
		h.broadcastRoomUpdate(roomID)
	} else if clientCount > 0 {
		// Broadcast updated player list to remaining players
		h.broadcastRoomUpdate(roomID)
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
	// ─── V2 Room Manager Events ──────────────────────────────
	case "v2_create_room":
		h.handleCreateRoomV2(client, msg.Payload)
	case "v2_join_room":
		h.handleJoinRoomV2(client, msg.Payload)
	case "v2_leave_room":
		h.handleLeaveRoomV2(client, msg.Payload)
	case "v2_select_seat":
		h.handleSelectSeatV2(client, msg.Payload)
	case "v2_release_seat":
		h.handleReleaseSeatV2(client, msg.Payload)
	case "v2_ready":
		h.handleReadyV2(client, msg.Payload)
	case "v2_add_bot":
		h.handleAddBotV2(client, msg.Payload)
	case "v2_remove_bot":
		h.handleRemoveBotV2(client, msg.Payload)
	case "v2_kick":
		h.handleKickV2(client, msg.Payload)
	case "v2_settings":
		h.handleUpdateSettingsV2(client, msg.Payload)
	case "v2_play_again":
		h.handlePlayAgainV2(client, msg.Payload)
	case "v2_get_lobby":
		h.handleGetLobbyV2(client)
	case "v2_reconnect_room":
		h.handleReconnectRoomV2(client, msg.Payload)
	case "v2_start_game":
		h.handleStartGameV2(client, msg.Payload)
	case "v2_room_chat":
		h.handleRoomChatV2(client, msg.Payload)
	case "spectate_game":
		h.handleSpectateGame(client, msg.Payload)
	case "global_chat":
		h.handleGlobalChat(client, msg.Payload)
	case "get_global_chat":
		h.handleGetGlobalChat(client)
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
