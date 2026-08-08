package ws

import (
	"encoding/json"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/filter"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

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

	// Check chat permissions per phase (Criterion 5 Audit):
	// - Lobby (room.Game == nil): all players in room can chat
	// - Discussion & Voting: alive players only can chat (others get Ghost Chat)
	room.mu.RLock()
	canChat := false
	isGhost := false
	
	if room.Game == nil {
		canChat = true // Everyone can chat in lobby
	} else if room.Game.Phase == game.PhaseDiscussion || room.Game.Phase == game.PhaseVoting {
		for _, p := range room.Game.Players {
			if p.ID == req.SenderID {
				if p.IsAlive {
					canChat = true
				} else {
					isGhost = true
				}
				break
			}
		}
	}
	room.mu.RUnlock()

	if !canChat && !isGhost {
		return
	}

	// Broadcast chat message
	resp := map[string]interface{}{
		"senderId": req.SenderID,
		"content":  content,
	}
	respBytes, _ := json.Marshal(resp)

	if isGhost {
		ghostMsg := &Message{Type: "ghost_chat_message", Payload: respBytes}
		room.mu.RLock()
		defer room.mu.RUnlock()
		for _, p := range room.Game.Players {
			// Only dead players see ghost chat
			if !p.IsAlive && !p.IsBot {
				if c, ok := room.Clients[p.ID]; ok {
					safeSend(c, ghostMsg)
				}
			}
		}
		return
	}

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

// handleGiftAnimation broadcasts a gift/curse flying animation to all players in the sender's room.
// Triggered client-side after a successful gift send (REST API), so that the animation
// is shown to ALL room members (flying from sender avatar to receiver avatar).
func (h *Hub) handleGiftAnimation(client *Client, payload json.RawMessage) {
	if client.RoomID == "" {
		return
	}

	// Anti-spam: throttle gift animations
	if !checkActionThrottle(client) {
		return
	}

	var req struct {
		ReceiverID    string `json:"receiverId"`
		GiftID        string `json:"giftId"`
		GiftName      string `json:"giftName"`
		GiftEmoji     string `json:"giftEmoji"`
		GiftType      string `json:"giftType"`      // "gift" | "curse"
		AnimationKey  string `json:"animationKey"`
		Rarity        string `json:"rarity"`        // common|rare|epic|legendary
		BroadcastType string `json:"broadcastType"` // room|global
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	if req.ReceiverID == "" || req.GiftID == "" {
		return
	}

	// Get sender display name from profile cache
	senderName, _, _, _ := h.getPlayerProfile(client.UserID)
	receiverName, _, _, _ := h.getPlayerProfile(req.ReceiverID)

	broadcastPayload := map[string]interface{}{
		"senderId":      client.UserID,
		"receiverId":    req.ReceiverID,
		"senderName":    senderName,
		"receiverName":  receiverName,
		"giftId":        req.GiftID,
		"giftName":      req.GiftName,
		"giftEmoji":     req.GiftEmoji,
		"giftType":      req.GiftType,
		"animationKey":  req.AnimationKey,
		"rarity":        req.Rarity,
		"broadcastType": req.BroadcastType,
	}
	respBytes, _ := json.Marshal(broadcastPayload)

	// Broadcast to room (all players see the animation)
	h.broadcastToRoom(client.RoomID, &Message{Type: "gift_animation_broadcast", Payload: respBytes}, nil)

	// If global broadcast (legendary), also send to ALL connected clients
	if req.BroadcastType == "global" {
		h.BroadcastAll("gift_animation_broadcast", broadcastPayload)
	}

	logger.Debug(logger.CatWebSocket, "Gift animation broadcast", map[string]interface{}{
		"senderId":   client.UserID,
		"receiverId": req.ReceiverID,
		"giftId":     req.GiftID,
		"rarity":     req.Rarity,
		"roomId":     client.RoomID,
	})
}

func (h *Hub) handleTyping(client *Client) {
	resp := map[string]interface{}{"playerId": client.UserID}
	respBytes, _ := json.Marshal(resp)
	h.broadcastToRoom(client.RoomID, &Message{Type: "typing_indicator", Payload: respBytes}, client)
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

func (h *Hub) handleInvite(client *Client, payload json.RawMessage) {
	var req struct {
		TargetUserID string `json:"targetUserId"`
		RoomCode     string `json:"roomCode"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}
	// C-07 FIX: O(1) lookup via userIndex instead of O(N) scan over h.clients
	h.mu.RLock()
	target, ok := h.userIndex[req.TargetUserID]
	h.mu.RUnlock()
	if ok {
		resp := map[string]interface{}{"fromUserId": client.UserID, "roomCode": req.RoomCode}
		respBytes, _ := json.Marshal(resp)
		safeSend(target, &Message{Type: "game_invite", Payload: respBytes})
	}
}
