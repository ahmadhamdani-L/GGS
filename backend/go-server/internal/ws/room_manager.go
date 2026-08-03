package ws

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

// ═══════════════════════════════════════════════════════════════
// ROOM MANAGER — Production-Ready Room Management System
// ═══════════════════════════════════════════════════════════════
//
// Design principles:
// - All logic lives on backend; frontend is pure presenter
// - No race conditions: single mutex per room, atomic seat selection
// - Memory-safe: automatic cleanup of empty private rooms
// - Public rooms are permanent (never deleted)
// - State machine enforces valid transitions only
// - Host migration with grace period
// - Player reconnect with seat preservation
// ═══════════════════════════════════════════════════════════════

// ─── Constants ───────────────────────────────────────────────

const (
	MaxSeats             = 16
	MinPlayersToStart    = 8  // Minimum seated players (humans + bots) to start
	HostGracePeriod      = 30 * time.Second
	ReconnectGracePeriod = 30 * time.Second
	PublicRoomCount      = 5
)

// ─── Room State Machine ──────────────────────────────────────

type RoomState string

const (
	StateWaiting    RoomState = "WAITING"
	StateCountdown  RoomState = "COUNTDOWN"
	StateStarting   RoomState = "STARTING"
	StatePlaying    RoomState = "PLAYING"
	StateResult     RoomState = "RESULT"
	StateRestarting RoomState = "RESTARTING"
)

// Valid state transitions
var validTransitions = map[RoomState][]RoomState{
	StateWaiting:    {StateCountdown},
	StateCountdown:  {StateStarting, StateWaiting}, // can cancel countdown
	StateStarting:   {StatePlaying},
	StatePlaying:    {StateResult},
	StateResult:     {StateRestarting, StateWaiting}, // play again or back to waiting
	StateRestarting: {StatePlaying},
}

func (s RoomState) CanTransitionTo(target RoomState) bool {
	for _, valid := range validTransitions[s] {
		if valid == target {
			return true
		}
	}
	return false
}

// ─── Room Type ───────────────────────────────────────────────

type RoomType string

const (
	RoomTypePublic  RoomType = "public"
	RoomTypePrivate RoomType = "private"
)

// ─── Seat ────────────────────────────────────────────────────

type Seat struct {
	Index    int                    `json:"index"`    // 0-15
	PlayerID string                 `json:"playerId"` // "" if empty
	IsBot    bool                   `json:"isBot"`
	BotName  string                 `json:"botName,omitempty"`
	// Player info (populated when occupied by human)
	DisplayName string                 `json:"displayName,omitempty"`
	AvatarID    int                    `json:"avatarId,omitempty"`
	ChibiConfig map[string]interface{} `json:"chibiConfig,omitempty"`
}

func (s *Seat) IsEmpty() bool  { return s.PlayerID == "" }
func (s *Seat) IsHuman() bool  { return s.PlayerID != "" && !s.IsBot }

// ─── Player Connection State ─────────────────────────────────

type PlayerConnectionState string

const (
	PlayerConnected    PlayerConnectionState = "connected"
	PlayerDisconnected PlayerConnectionState = "disconnected"
	PlayerLeft         PlayerConnectionState = "left"
)

// ─── Room Player (v2) ────────────────────────────────────────

type RoomPlayerV2 struct {
	UserID          string                 `json:"userId"`
	DisplayName     string                 `json:"displayName"`
	AvatarID        int                    `json:"avatarId"`
	ChibiConfig     map[string]interface{} `json:"chibiConfig,omitempty"`
	SeatIndex       int                    `json:"seatIndex"` // -1 = no seat
	IsReady         bool                   `json:"isReady"`
	IsHost          bool                   `json:"isHost"`
	IsBot           bool                   `json:"isBot"`
	ConnState       PlayerConnectionState  `json:"connState"`
	DisconnectedAt  *time.Time             `json:"-"`
	PlayAgain       bool                   `json:"playAgain,omitempty"`
}

// ─── ManagedRoom (v2) ────────────────────────────────────────

type ManagedRoom struct {
	ID        string    `json:"id"`
	Code      string    `json:"code"`
	Name      string    `json:"name"`
	Type      RoomType  `json:"type"`
	State     RoomState `json:"state"`
	HostID    string    `json:"hostId"`
	MaxSeats  int       `json:"maxSeats"`
	CreatedAt time.Time `json:"createdAt"`

	// Seats (fixed array, atomic assignment)
	Seats [MaxSeats]Seat `json:"seats"`

	// Players index (userID → player info)
	Players map[string]*RoomPlayerV2 `json:"-"`

	// Connected WebSocket clients
	Clients map[string]*Client `json:"-"`

	// Game state (nil when not playing)
	Game *game.GameState `json:"-"`

	// Timer settings
	Settings RoomSettings `json:"settings"`

	// Host migration timer
	hostGraceTimer *time.Timer
	hostGraceOldID string

	// Room-level mutex (one per room, no global lock needed for room ops)
	mu sync.Mutex
}

type RoomSettings struct {
	MaxPlayers     int `json:"maxPlayers"`
	DiscussionTime int `json:"discussionTime"`
	VotingTime     int `json:"votingTime"`
	NightTime      int `json:"nightTime"`
	TestamentTime  int `json:"testamentTime"`
}

func DefaultSettings() RoomSettings {
	return RoomSettings{
		MaxPlayers:     MaxSeats,
		DiscussionTime: 60,
		VotingTime:     30,
		NightTime:      30,
		TestamentTime:  30,
	}
}

// ─── Room Manager ────────────────────────────────────────────

type RoomManager struct {
	rooms map[string]*ManagedRoom // roomID → room
	codes map[string]string       // code → roomID (for O(1) lookup by code)
	hub   *Hub
	mu    sync.RWMutex
}

func NewRoomManager(hub *Hub) *RoomManager {
	rm := &RoomManager{
		rooms: make(map[string]*ManagedRoom),
		codes: make(map[string]string),
		hub:   hub,
	}
	// Create permanent public rooms
	rm.initPublicRooms()
	// Start cleanup goroutine
	go rm.cleanupLoop()
	return rm
}

func (rm *RoomManager) initPublicRooms() {
	for i := 1; i <= PublicRoomCount; i++ {
		code := fmt.Sprintf("PUB%d", i)
		id := fmt.Sprintf("public-room-%d", i)
		room := &ManagedRoom{
			ID:        id,
			Code:      code,
			Name:      fmt.Sprintf("Room %d", i),
			Type:      RoomTypePublic,
			State:     StateWaiting,
			HostID:    "",
			MaxSeats:  MaxSeats,
			CreatedAt: time.Now(),
			Players:   make(map[string]*RoomPlayerV2),
			Clients:   make(map[string]*Client),
			Settings:  DefaultSettings(),
		}
		// Initialize empty seats
		for j := 0; j < MaxSeats; j++ {
			room.Seats[j] = Seat{Index: j}
		}
		rm.rooms[id] = room
		rm.codes[code] = id
	}
	logger.Info(logger.CatRoom, "Public rooms initialized", map[string]interface{}{
		"count": PublicRoomCount,
	})
}

// ─── Room CRUD ───────────────────────────────────────────────

// CreatePrivateRoom creates a new private room and returns it
func (rm *RoomManager) CreatePrivateRoom(hostID, displayName string, avatarID int, chibi map[string]interface{}) *ManagedRoom {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	code := rm.generateUniqueCode()
	id := generateRoomID()

	room := &ManagedRoom{
		ID:        id,
		Code:      code,
		Name:      displayName + "'s Room",
		Type:      RoomTypePrivate,
		State:     StateWaiting,
		HostID:    hostID,
		MaxSeats:  MaxSeats,
		CreatedAt: time.Now(),
		Players:   make(map[string]*RoomPlayerV2),
		Clients:   make(map[string]*Client),
		Settings:  DefaultSettings(),
	}
	for j := 0; j < MaxSeats; j++ {
		room.Seats[j] = Seat{Index: j}
	}
	rm.rooms[id] = room
	rm.codes[code] = id

	logger.RoomCreated(id, code, hostID)
	return room
}

// GetRoom returns a room by ID
func (rm *RoomManager) GetRoom(roomID string) *ManagedRoom {
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	return rm.rooms[roomID]
}

// GetRoomByCode returns a room by code
func (rm *RoomManager) GetRoomByCode(code string) *ManagedRoom {
	rm.mu.RLock()
	roomID, ok := rm.codes[strings.ToUpper(code)]
	rm.mu.RUnlock()
	if !ok {
		return nil
	}
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	return rm.rooms[roomID]
}

// DestroyRoom removes a private room (public rooms are never destroyed)
func (rm *RoomManager) DestroyRoom(roomID string) {
	rm.mu.Lock()
	room, ok := rm.rooms[roomID]
	if !ok {
		rm.mu.Unlock()
		return
	}
	if room.Type == RoomTypePublic {
		rm.mu.Unlock()
		return // Never destroy public rooms
	}
	delete(rm.codes, room.Code)
	delete(rm.rooms, roomID)
	rm.mu.Unlock()

	logger.RoomDestroyed(roomID, "all players left private room")
}

// ─── Join / Leave ────────────────────────────────────────────

// JoinRoom adds a player to a room. Returns error message or "".
func (rm *RoomManager) JoinRoom(room *ManagedRoom, client *Client, userID, displayName string, avatarID int, chibi map[string]interface{}) string {
	room.mu.Lock()
	defer room.mu.Unlock()

	// Can only join in WAITING or RESULT state
	if room.State != StateWaiting && room.State != StateResult {
		return "Tidak bisa bergabung saat game berjalan"
	}

	// Check if already in room (reconnect case)
	if existing, ok := room.Players[userID]; ok {
		existing.ConnState = PlayerConnected
		existing.DisconnectedAt = nil
		room.Clients[userID] = client
		client.RoomID = room.ID
		return "" // Reconnected
	}

	// Check seat capacity
	humanCount := 0
	for _, p := range room.Players {
		if !p.IsBot {
			humanCount++
		}
	}
	if humanCount >= room.Settings.MaxPlayers {
		return "Room penuh"
	}

	// Create player (no seat assigned yet — they must select)
	player := &RoomPlayerV2{
		UserID:      userID,
		DisplayName: displayName,
		AvatarID:    avatarID,
		ChibiConfig: chibi,
		SeatIndex:   -1,
		IsReady:     false,
		IsHost:      false,
		IsBot:       false,
		ConnState:   PlayerConnected,
	}

	// Auto-assign as host if room has no host
	if room.HostID == "" {
		room.HostID = userID
		player.IsHost = true
	}

	room.Players[userID] = player
	room.Clients[userID] = client
	client.RoomID = room.ID

	return ""
}

// LeaveRoom removes a player from a room. Handles host migration & cleanup.
func (rm *RoomManager) LeaveRoom(room *ManagedRoom, userID string) {
	room.mu.Lock()

	player, exists := room.Players[userID]
	if !exists {
		room.mu.Unlock()
		return
	}

	// Release seat
	if player.SeatIndex >= 0 && player.SeatIndex < MaxSeats {
		room.Seats[player.SeatIndex] = Seat{Index: player.SeatIndex}
	}

	// Remove from room
	delete(room.Players, userID)
	delete(room.Clients, userID)

	wasHost := room.HostID == userID
	humanCount := 0
	for _, p := range room.Players {
		if !p.IsBot {
			humanCount++
		}
	}

	// If no humans left
	if humanCount == 0 {
		// Clear all bots too
		for uid, p := range room.Players {
			if p.IsBot {
				if p.SeatIndex >= 0 {
					room.Seats[p.SeatIndex] = Seat{Index: p.SeatIndex}
				}
				delete(room.Players, uid)
			}
		}
		room.State = StateWaiting
		room.HostID = ""
		room.Game = nil
		room.mu.Unlock()

		// Destroy private rooms when empty
		if room.Type == RoomTypePrivate {
			rm.DestroyRoom(room.ID)
		}
		return
	}

	// Host migration if host left
	if wasHost {
		rm.migrateHost(room)
	}
	room.mu.Unlock()
}

// ─── Seat System (Atomic) ────────────────────────────────────

// SelectSeat atomically assigns a player to a seat. Returns error string or "".
func (rm *RoomManager) SelectSeat(room *ManagedRoom, userID string, seatIdx int) string {
	if seatIdx < 0 || seatIdx >= MaxSeats {
		return "Seat index tidak valid"
	}

	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists {
		return "Kamu tidak ada di room ini"
	}

	if room.State != StateWaiting && room.State != StateResult {
		return "Tidak bisa ganti seat saat game berlangsung"
	}

	// Check if seat is taken
	seat := &room.Seats[seatIdx]
	if !seat.IsEmpty() && seat.PlayerID != userID {
		return "Seat sudah diisi pemain lain"
	}

	// Release old seat if player had one
	if player.SeatIndex >= 0 && player.SeatIndex < MaxSeats {
		oldSeat := &room.Seats[player.SeatIndex]
		*oldSeat = Seat{Index: player.SeatIndex}
	}

	// Assign new seat
	seat.PlayerID = userID
	seat.IsBot = player.IsBot
	seat.DisplayName = player.DisplayName
	seat.AvatarID = player.AvatarID
	seat.ChibiConfig = player.ChibiConfig
	player.SeatIndex = seatIdx

	return ""
}

// ReleaseSeat releases a player's seat
func (rm *RoomManager) ReleaseSeat(room *ManagedRoom, userID string) {
	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists || player.SeatIndex < 0 {
		return
	}
	room.Seats[player.SeatIndex] = Seat{Index: player.SeatIndex}
	player.SeatIndex = -1
}

// ─── Ready System ────────────────────────────────────────────

// SetReady marks a player as ready/not ready
func (rm *RoomManager) SetReady(room *ManagedRoom, userID string, ready bool) string {
	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists {
		return "Player not found"
	}
	if player.SeatIndex < 0 {
		return "Pilih seat dulu sebelum ready"
	}
	player.IsReady = ready
	return ""
}

// CanStart checks if the game can be started
func (rm *RoomManager) CanStart(room *ManagedRoom) (bool, string) {
	room.mu.Lock()
	defer room.mu.Unlock()

	if room.State != StateWaiting {
		return false, "Room tidak dalam status waiting"
	}

	seatedHumans := 0
	allReady := true
	for _, p := range room.Players {
		if p.IsBot {
			continue
		}
		if p.SeatIndex >= 0 {
			seatedHumans++
			if !p.IsReady {
				allReady = false
			}
		}
	}

	if seatedHumans < MinPlayersToStart {
		return false, fmt.Sprintf("Minimal %d pemain diperlukan", MinPlayersToStart)
	}
	if !allReady {
		return false, "Semua pemain harus ready"
	}
	return true, ""
}

// ─── Host Migration ──────────────────────────────────────────

// migrateHost selects a new host from human players (called while holding room.mu)
func (rm *RoomManager) migrateHost(room *ManagedRoom) {
	var candidates []string
	for uid, p := range room.Players {
		if !p.IsBot && p.ConnState == PlayerConnected {
			candidates = append(candidates, uid)
		}
	}
	if len(candidates) == 0 {
		// Try disconnected players
		for uid, p := range room.Players {
			if !p.IsBot {
				candidates = append(candidates, uid)
			}
		}
	}
	if len(candidates) == 0 {
		room.HostID = ""
		return
	}

	// Pick random candidate
	idx := 0
	if len(candidates) > 1 {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(candidates))))
		idx = int(n.Int64())
	}
	newHost := candidates[idx]
	room.HostID = newHost

	// Update IsHost flags
	for _, p := range room.Players {
		p.IsHost = (p.UserID == newHost)
	}

	logger.Info(logger.CatRoom, "Host migrated", map[string]interface{}{
		"roomId":  room.ID,
		"newHost": newHost,
	})
}

// ─── Player Disconnect / Reconnect ──────────────────────────

// PlayerDisconnect marks a player as disconnected (seat preserved)
func (rm *RoomManager) PlayerDisconnect(room *ManagedRoom, userID string) {
	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists {
		return
	}

	now := time.Now()
	player.ConnState = PlayerDisconnected
	player.DisconnectedAt = &now
	delete(room.Clients, userID)

	// If host disconnected, start grace period
	if room.HostID == userID {
		room.hostGraceOldID = userID
		room.hostGraceTimer = time.AfterFunc(HostGracePeriod, func() {
			rm.expireHostGrace(room)
		})
	}
}

// PlayerReconnect handles a player reconnecting
func (rm *RoomManager) PlayerReconnect(room *ManagedRoom, client *Client, userID string) bool {
	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists || player.ConnState == PlayerLeft {
		return false
	}

	player.ConnState = PlayerConnected
	player.DisconnectedAt = nil
	room.Clients[userID] = client
	client.RoomID = room.ID

	// If this was the old host and grace period is still active, restore host
	if room.hostGraceOldID == userID && room.hostGraceTimer != nil {
		room.hostGraceTimer.Stop()
		room.hostGraceTimer = nil
		room.hostGraceOldID = ""
		room.HostID = userID
		for _, p := range room.Players {
			p.IsHost = (p.UserID == userID)
		}
	}

	return true
}

// expireHostGrace is called when host grace period expires
func (rm *RoomManager) expireHostGrace(room *ManagedRoom) {
	room.mu.Lock()
	room.hostGraceTimer = nil
	room.hostGraceOldID = ""
	// Migrate to another player
	rm.migrateHost(room)
	room.mu.Unlock()

	// Broadcast host change
	rm.BroadcastRoomState(room)
}

// ─── Bot Management ──────────────────────────────────────────

// AddBot adds a bot to a specific seat
func (rm *RoomManager) AddBot(room *ManagedRoom, hostID string, seatIdx int) string {
	room.mu.Lock()
	defer room.mu.Unlock()

	if room.HostID != hostID {
		return "Hanya host yang bisa menambah bot"
	}
	if seatIdx < 0 || seatIdx >= MaxSeats {
		return "Seat index tidak valid"
	}
	if !room.Seats[seatIdx].IsEmpty() {
		return "Seat sudah terisi"
	}

	botID := fmt.Sprintf("bot-%s-%d", room.ID[:8], seatIdx)
	botName := generateBotName(seatIdx)

	room.Seats[seatIdx] = Seat{
		Index:       seatIdx,
		PlayerID:    botID,
		IsBot:       true,
		BotName:     botName,
		DisplayName: botName,
	}
	room.Players[botID] = &RoomPlayerV2{
		UserID:      botID,
		DisplayName: botName,
		SeatIndex:   seatIdx,
		IsReady:     true, // Bots are always ready
		IsHost:      false,
		IsBot:       true,
		ConnState:   PlayerConnected,
	}
	return ""
}

// RemoveBot removes a bot from a seat
func (rm *RoomManager) RemoveBot(room *ManagedRoom, hostID string, seatIdx int) string {
	room.mu.Lock()
	defer room.mu.Unlock()

	if room.HostID != hostID {
		return "Hanya host yang bisa menghapus bot"
	}
	if seatIdx < 0 || seatIdx >= MaxSeats {
		return "Seat index tidak valid"
	}
	seat := &room.Seats[seatIdx]
	if seat.IsEmpty() || !seat.IsBot {
		return "Seat ini bukan bot"
	}

	delete(room.Players, seat.PlayerID)
	*seat = Seat{Index: seatIdx}
	return ""
}

// ─── State Transitions ───────────────────────────────────────

// TransitionState safely transitions the room state
func (rm *RoomManager) TransitionState(room *ManagedRoom, target RoomState) bool {
	room.mu.Lock()
	defer room.mu.Unlock()

	if !room.State.CanTransitionTo(target) {
		logger.Warn(logger.CatRoom, "Invalid state transition", map[string]interface{}{
			"roomId": room.ID, "from": room.State, "to": target,
		})
		return false
	}
	room.State = target
	return true
}

// ─── Play Again ──────────────────────────────────────────────

// SetPlayAgain marks a player as wanting to play again
func (rm *RoomManager) SetPlayAgain(room *ManagedRoom, userID string) {
	room.mu.Lock()
	defer room.mu.Unlock()

	player, exists := room.Players[userID]
	if !exists {
		return
	}
	player.PlayAgain = true

	// Check if all connected humans want to play again
	allReady := true
	for _, p := range room.Players {
		if !p.IsBot && p.ConnState == PlayerConnected && !p.PlayAgain {
			allReady = false
			break
		}
	}

	if allReady {
		// Reset for new game
		for _, p := range room.Players {
			p.IsReady = true
			p.PlayAgain = false
		}
		room.Game = nil
		room.State = StateRestarting
	}
}

// ResetForNewGame clears game state but preserves players/seats
func (rm *RoomManager) ResetForNewGame(room *ManagedRoom) {
	room.mu.Lock()
	defer room.mu.Unlock()

	room.Game = nil
	room.State = StateWaiting
	for _, p := range room.Players {
		p.IsReady = false
		p.PlayAgain = false
	}
}

// ─── Broadcasting ────────────────────────────────────────────

// BroadcastRoomState sends the full room state to all connected clients
func (rm *RoomManager) BroadcastRoomState(room *ManagedRoom) {
	room.mu.Lock()
	state := rm.buildRoomSnapshot(room)
	clients := make([]*Client, 0, len(room.Clients))
	for _, c := range room.Clients {
		clients = append(clients, c)
	}
	room.mu.Unlock()

	payload, _ := json.Marshal(state)
	msg := &Message{Type: "room_state", Payload: payload}
	for _, c := range clients {
		safeSend(c, msg)
	}
}

// BroadcastEvent sends a specific event to all clients in room
func (rm *RoomManager) BroadcastEvent(room *ManagedRoom, eventType string, data map[string]interface{}) {
	room.mu.Lock()
	clients := make([]*Client, 0, len(room.Clients))
	for _, c := range room.Clients {
		clients = append(clients, c)
	}
	room.mu.Unlock()

	payload, _ := json.Marshal(data)
	msg := &Message{Type: eventType, Payload: payload}
	for _, c := range clients {
		safeSend(c, msg)
	}
}

// buildRoomSnapshot creates a serializable snapshot (called while holding mu)
func (rm *RoomManager) buildRoomSnapshot(room *ManagedRoom) map[string]interface{} {
	players := make([]map[string]interface{}, 0, len(room.Players))
	for _, p := range room.Players {
		players = append(players, map[string]interface{}{
			"userId":      p.UserID,
			"displayName": p.DisplayName,
			"avatarId":    p.AvatarID,
			"chibiConfig": p.ChibiConfig,
			"seatIndex":   p.SeatIndex,
			"isReady":     p.IsReady,
			"isHost":      p.IsHost,
			"isBot":       p.IsBot,
			"connState":   p.ConnState,
			"playAgain":   p.PlayAgain,
		})
	}

	seats := make([]map[string]interface{}, MaxSeats)
	for i := 0; i < MaxSeats; i++ {
		s := room.Seats[i]
		seats[i] = map[string]interface{}{
			"index":       s.Index,
			"playerId":    s.PlayerID,
			"isBot":       s.IsBot,
			"displayName": s.DisplayName,
			"avatarId":    s.AvatarID,
			"chibiConfig": s.ChibiConfig,
		}
	}

	return map[string]interface{}{
		"roomId":   room.ID,
		"code":     room.Code,
		"name":     room.Name,
		"type":     room.Type,
		"state":    room.State,
		"hostId":   room.HostID,
		"maxSeats": room.MaxSeats,
		"settings": room.Settings,
		"players":  players,
		"seats":    seats,
	}
}

// ─── Lobby List ──────────────────────────────────────────────

// GetLobbyList returns all joinable rooms for the lobby display
func (rm *RoomManager) GetLobbyList() []map[string]interface{} {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	result := make([]map[string]interface{}, 0, len(rm.rooms))
	for _, room := range rm.rooms {
		room.mu.Lock()
		humanCount := 0
		botCount := 0
		for _, p := range room.Players {
			if p.IsBot {
				botCount++
			} else {
				humanCount++
			}
		}
		hostName := ""
		if hp, ok := room.Players[room.HostID]; ok {
			hostName = hp.DisplayName
		}
		info := map[string]interface{}{
			"roomId":      room.ID,
			"code":        room.Code,
			"name":        room.Name,
			"type":        room.Type,
			"state":       room.State,
			"playerCount": humanCount,
			"botCount":    botCount,
			"maxSeats":    room.Settings.MaxPlayers,
			"hostName":    hostName,
		}
		room.mu.Unlock()
		result = append(result, info)
	}
	return result
}

// ─── Cleanup ─────────────────────────────────────────────────

// cleanupLoop periodically checks for disconnected players that timed out
func (rm *RoomManager) cleanupLoop() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		rm.mu.RLock()
		roomIDs := make([]string, 0, len(rm.rooms))
		for id := range rm.rooms {
			roomIDs = append(roomIDs, id)
		}
		rm.mu.RUnlock()

		for _, id := range roomIDs {
			rm.mu.RLock()
			room, ok := rm.rooms[id]
			rm.mu.RUnlock()
			if !ok {
				continue
			}
			rm.cleanupDisconnectedPlayers(room)
		}
	}
}

func (rm *RoomManager) cleanupDisconnectedPlayers(room *ManagedRoom) {
	room.mu.Lock()
	var toRemove []string
	now := time.Now()

	for uid, p := range room.Players {
		if p.ConnState == PlayerDisconnected && p.DisconnectedAt != nil {
			if now.Sub(*p.DisconnectedAt) > ReconnectGracePeriod {
				toRemove = append(toRemove, uid)
			}
		}
	}
	room.mu.Unlock()

	// Remove expired players outside lock
	for _, uid := range toRemove {
		rm.LeaveRoom(room, uid)
		rm.BroadcastEvent(room, "player_leave", map[string]interface{}{
			"userId": uid,
			"reason": "reconnect_timeout",
		})
		rm.BroadcastRoomState(room)
	}
}

// ─── Helpers ─────────────────────────────────────────────────

func (rm *RoomManager) generateUniqueCode() string {
	for {
		code := generateRoomCodeV2()
		if _, exists := rm.codes[code]; !exists {
			return code
		}
	}
}

func generateRoomID() string {
	b := make([]byte, 12)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func generateRoomCodeV2() string {
	const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	code := make([]byte, 6)
	for i := range code {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		code[i] = chars[n.Int64()]
	}
	return string(code)
}

var botNames = []string{
	"Atlas", "Blaze", "Sage", "Storm", "Echo",
	"Ivy", "Nova", "Shadow", "Ember", "Frost",
	"Raven", "Onyx", "Hawk", "Luna", "Viper",
	"Phoenix",
}

func generateBotName(seatIdx int) string {
	return botNames[seatIdx%len(botNames)]
}
