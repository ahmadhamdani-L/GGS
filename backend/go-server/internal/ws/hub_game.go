package ws

import (
	"encoding/json"
	"time"

	"github.com/ggs/werewolf-server/internal/bot"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

func (h *Hub) handleStartGame(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID    string `json:"roomId"`
		HostID    string `json:"hostId"`
		NoBotFill bool   `json:"noBotFill"` // C-1 FIX: true = start with only real players, no bot fill
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

	// Validate minimum player count (always need at least 8 for valid role distribution)
	room.mu.RLock()
	currentPlayers := len(room.Players)
	room.mu.RUnlock()
	if currentPlayers < 8 && req.NoBotFill {
		sendError(client, "Butuh minimal 8 pemain untuk mulai tanpa bot")
		return
	}

	// Set room to countdown status
	room.mu.Lock()
	room.Status = RoomCountdown
	room.mu.Unlock()

	// Broadcast countdown (client shows 3-2-1)
	countResp, _ := json.Marshal(map[string]interface{}{"seconds": 3})
	h.broadcastToRoom(req.RoomID, &Message{Type: "game_countdown", Payload: countResp}, nil)

	// M-08 / C-1 FIX: Determine fill target.
	// - If NoBotFill=true: use exactly the players who joined (no bot fill).
	// - Otherwise: use TimerSettings.maxPlayers or default to 18.
	room.mu.RLock()
	maxPlayersTarget := 18
	if req.NoBotFill {
		maxPlayersTarget = len(room.Players) // fill to exact current count = no bots added
	} else if ts, ok := room.TimerSettings["maxPlayers"]; ok && ts >= 8 && ts <= 18 {
		maxPlayersTarget = ts
	}
	room.mu.RUnlock()

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

	// Fill with bots up to maxPlayersTarget
	playerInfos = bot.FillWithBotsInfo(playerInfos, maxPlayersTarget)

	// Create game with full player info (including chibi configs)
	gameState := game.CreateGame(playerInfos)
	room.mu.RLock()
	if room.TimerSettings != nil {
		if d, ok := room.TimerSettings["discussion"]; ok && d > 0 {
			gameState.Config.TimerDuration.Discussion = d
		}
		if v, ok := room.TimerSettings["voting"]; ok && v > 0 {
			gameState.Config.TimerDuration.Voting = v
		}
		if n, ok := room.TimerSettings["night"]; ok && n > 0 {
			gameState.Config.TimerDuration.NightAction = n
		}
	}
	room.mu.RUnlock()

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
	if !checkActionThrottle(client) {
		return // P3-46: too fast, ignore
	}
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
	if !checkActionThrottle(client) {
		return // P3-46: too fast, ignore
	}
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

func (h *Hub) broadcastGameState(roomID string) {
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok || room.Game == nil {
		return
	}

	room.mu.Lock()

	if room.Game == nil {
		room.mu.Unlock()
		return
	}

	// P0-2 FIX: Process bot actions INSIDE the lock to eliminate the race condition.
	// Bot processing is CPU-only (random decisions, no I/O), so holding the lock is safe.
	// Previously, unlocking for bot processing allowed the timer goroutine to advance
	// the game concurrently, causing state corruption via shared slice backing arrays.
	room.Game = bot.ProcessBotActions(room.Game, bot.Medium)

	// Record match results when game ends (collect data, write after unlock)
	// CRITICAL: Only record ONCE using ResultsRecorded flag to prevent looping stats
	var recordPlayers []game.PlayerState
	var recordGameID string
	var recordWinner *game.Team
	var recordRound int
	var recordPlayerCount int
	var playerRewards map[string]*game.PlayerRewards

	if room.Game != nil && room.Game.Phase == game.PhaseGameEnd && room.Game.Winner != nil && !room.Game.ResultsRecorded {
		// Mark as recorded IMMEDIATELY to prevent duplicate recording
		room.Game.ResultsRecorded = true

		recordPlayers = make([]game.PlayerState, len(room.Game.Players))
		copy(recordPlayers, room.Game.Players)
		recordGameID = room.Game.ID
		recordWinner = room.Game.Winner
		recordRound = room.Game.Round
		recordPlayerCount = len(room.Game.Players)

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

	// Build filtered states while under lock; collect client refs
	type playerMsg struct {
		client *Client
		userID string
	}
	var clients []playerMsg
	if room.Game != nil {
		for uid, c := range room.Clients {
			clients = append(clients, playerMsg{client: c, userID: uid})
		}
	}

	states := make(map[string][]byte, len(clients))
	for _, pm := range clients {
		if room.Game == nil {
			break
		}
		filteredState := game.FilterStateForPlayer(room.Game, pm.userID)
		if playerRewards != nil {
			if rewards, ok := playerRewards[pm.userID]; ok {
				filteredState.Rewards = rewards
			}
		}
		stateBytes, _ := json.Marshal(filteredState)
		states[pm.userID] = stateBytes
	}
	room.mu.Unlock()

	// Send outside of lock (channel sends should not hold mutex)
	for _, pm := range clients {
		if data, ok := states[pm.userID]; ok {
			safeSend(pm.client, &Message{Type: "game_state_update", Payload: data})
		}
	}

	if recordWinner != nil {
		go h.recordGameResultsAsync(recordPlayers, recordGameID, *recordWinner, recordRound, recordPlayerCount)
		time.AfterFunc(60*time.Second, func() { h.cleanupRoom(roomID) })
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

func (h *Hub) handleReconnectGame(client *Client) {
	// #3 FIX: handleReconnectGame previously held h.mu.RLock while acquiring room.mu.Lock
	// inside the loop — a lock-inversion deadlock if another goroutine held room.mu and
	// tried to acquire h.mu. Fix: collect room candidates under h.mu.RLock, release it,
	// then lock each room individually.

	// Step 1: collect candidate rooms under h.mu.RLock (no room lock)
	h.mu.RLock()
	type candidate struct {
		room   *Room
		roomID string
	}
	candidates := make([]candidate, 0, len(h.rooms))
	for id, room := range h.rooms {
		candidates = append(candidates, candidate{room: room, roomID: id})
	}
	h.mu.RUnlock()

	// Step 2: check each room without holding h.mu
	for _, c := range candidates {
		room := c.room

		room.mu.RLock()
		if room.Game == nil || room.Game.Phase == game.PhaseGameEnd {
			room.mu.RUnlock()
			continue
		}
		found := false
		for _, p := range room.Game.Players {
			if p.ID == client.UserID {
				found = true
				break
			}
		}
		room.mu.RUnlock()

		if !found {
			continue
		}

		// Rejoin the room — now take write lock
		room.mu.Lock()
		room.Clients[client.UserID] = client
		client.RoomID = room.ID
		for i := range room.Game.Players {
			if room.Game.Players[i].ID == client.UserID {
				room.Game.Players[i].IsConnected = true
				break
			}
		}
		filteredState := game.FilterStateForPlayer(room.Game, client.UserID)
		roomID := room.ID
		roomCode := room.Code
		room.mu.Unlock()

		stateBytes, _ := json.Marshal(filteredState)
		resp := map[string]interface{}{
			"roomId":    roomID,
			"roomCode":  roomCode,
			"gameState": json.RawMessage(stateBytes),
		}
		respBytes, _ := json.Marshal(resp)
		safeSend(client, &Message{Type: "game_resumed", Payload: respBytes})
		logger.Info(logger.CatRoom, "Player reconnected", map[string]interface{}{
			"userId": client.UserID, "roomId": roomID,
		})
		return
	}

	// No active game found
	resp, _ := json.Marshal(map[string]interface{}{"active": false})
	safeSend(client, &Message{Type: "no_active_game", Payload: resp})
}

// ─── Spectator Mode (LOW #8) ──────────────────────────────────

// handleSpectateGame allows a client to watch an active game without participating.
// WS message: { "type": "spectate_game", "payload": { "roomId": "..." } }
func (h *Hub) handleSpectateGame(client *Client, payload json.RawMessage) {
	var req struct {
		RoomID string `json:"roomId"`
	}
	if err := json.Unmarshal(payload, &req); err != nil || req.RoomID == "" {
		sendError(client, "roomId required")
		return
	}

	h.mu.RLock()
	room, ok := h.rooms[req.RoomID]
	h.mu.RUnlock()
	if !ok {
		sendError(client, "room not found")
		return
	}

	room.mu.RLock()
	if room.Game == nil {
		room.mu.RUnlock()
		sendError(client, "no active game in this room")
		return
	}

	// Create a spectator-filtered state: show all names/alive status but NO roles
	spectatorState := game.FilterStateForSpectator(room.Game)
	room.mu.RUnlock()

	// Add client to room's spectator list (they receive broadcasts but can't act)
	room.mu.Lock()
	if room.Spectators == nil {
		room.Spectators = make(map[string]*Client)
	}
	room.Spectators[client.UserID] = client
	client.RoomID = room.ID
	room.mu.Unlock()

	// Send current state
	stateBytes, _ := json.Marshal(spectatorState)
	safeSend(client, &Message{Type: "spectator_state", Payload: stateBytes})

	resp, _ := json.Marshal(map[string]interface{}{
		"roomId":   room.ID,
		"roomCode": room.Code,
		"message":  "Kamu sekarang menonton game ini",
	})
	safeSend(client, &Message{Type: "spectate_joined", Payload: resp})
}
