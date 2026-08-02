package ws

import (
	"encoding/json"
	"strings"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/filter"
	"github.com/ggs/werewolf-server/internal/logger"
)

// handleGlobalChat broadcasts a message to all connected clients
func (h *Hub) handleGlobalChat(client *Client, payload json.RawMessage) {
	var req struct {
		Message string `json:"message"`
	}
	if err := json.Unmarshal(payload, &req); err != nil {
		return
	}

	// Validate message
	msg := strings.TrimSpace(req.Message)
	if msg == "" || len(msg) > 200 {
		client.Send <- &Message{
			Type:    "error",
			Payload: mustMarshal(map[string]string{"error": "Pesan harus 1-200 karakter"}),
		}
		return
	}

	// Rate limit: max 1 message per 3 seconds per user
	if client.lastGlobalChat.Add(3 * time.Second).After(time.Now()) {
		client.Send <- &Message{
			Type:    "error",
			Payload: mustMarshal(map[string]string{"error": "Terlalu cepat, tunggu sebentar"}),
		}
		return
	}
	client.lastGlobalChat = time.Now()

	// Filter profanity
	msg = filter.CensorProfanity(msg)

	// Get display name
	displayName := client.DisplayName
	if displayName == "" {
		displayName = "Player"
	}

	// Save to DB
	savedMsg, err := db.SaveGlobalChatMessage(client.UserID, displayName, msg)
	if err != nil {
		logger.Warn(logger.CatWebSocket, "Failed to save global chat", map[string]interface{}{
			"error": err.Error(),
		})
	}

	// Build broadcast payload
	chatMsg := map[string]interface{}{
		"id":          "",
		"userId":      client.UserID,
		"displayName": displayName,
		"message":     msg,
		"createdAt":   time.Now().Format(time.RFC3339),
	}
	if savedMsg != nil {
		chatMsg["id"] = savedMsg.ID
	}

	broadcast := &Message{
		Type:    "global_chat_message",
		Payload: mustMarshal(chatMsg),
	}

	// Send to all connected clients
	h.mu.RLock()
	for c := range h.clients {
		select {
		case c.Send <- broadcast:
		default:
			// Skip if client send buffer is full
		}
	}
	h.mu.RUnlock()
}

// handleGetGlobalChat sends recent chat history to the requesting client
func (h *Hub) handleGetGlobalChat(client *Client) {
	messages, err := db.GetRecentGlobalChat(30)
	if err != nil || messages == nil {
		messages = []db.GlobalChatMessage{}
	}

	client.Send <- &Message{
		Type:    "global_chat_history",
		Payload: mustMarshal(map[string]interface{}{"messages": messages}),
	}
}

func mustMarshal(v interface{}) json.RawMessage {
	data, _ := json.Marshal(v)
	return data
}
