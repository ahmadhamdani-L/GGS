package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"

	"github.com/ggs/werewolf-server/internal/auth"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
)

// getAllowedOrigins returns the list of allowed WebSocket origins
func getAllowedOrigins() map[string]bool {
	origins := make(map[string]bool)
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		// Default: allow localhost for development
		allowedOrigins = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080"
	}
	for _, o := range strings.Split(allowedOrigins, ",") {
		origins[strings.TrimSpace(o)] = true
	}
	return origins
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			return true // Allow requests without origin (mobile apps, curl, etc.)
		}
		allowedOrigins := getAllowedOrigins()
		return allowedOrigins[origin]
	},
}

// Message represents a WebSocket message
type Message struct {
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	RequestID string          `json:"requestId,omitempty"` // For client-side idempotency
}

// Client represents a connected WebSocket client
type Client struct {
	Hub         *Hub
	Conn        *websocket.Conn
	Send        chan *Message
	UserID      string
	RoomID      string
	DisplayName string
	lastGlobalChat time.Time
	// P3-46: Anti-cheat — track last action time to prevent spam (atomic for thread safety)
	lastActionMs atomic.Int64
}

// HandleWebSocket upgrades HTTP to WebSocket
func HandleWebSocket(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	// C-01 FIX: Token is mandatory — reject anonymous connections entirely.
	// A missing or invalid token closes the connection immediately.
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		log.Printf("WebSocket auth rejected: missing token from %s", conn.RemoteAddr())
		conn.WriteMessage(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "authentication required"))
		conn.Close()
		return
	}
	userID, err := auth.ValidateToken(tokenStr)
	if err != nil {
		log.Printf("WebSocket auth failed: %v", err)
		conn.WriteMessage(websocket.CloseMessage,
			websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "invalid token"))
		conn.Close()
		return
	}

	client := &Client{
		Hub:    hub,
		Conn:   conn,
		Send:   make(chan *Message, 256),
		UserID: userID,
	}

	// Fetch display name for chat
	if db.DB != nil {
		db.DB.QueryRow(`SELECT display_name FROM profiles WHERE user_id = $1`, userID).Scan(&client.DisplayName)
	}
	if client.DisplayName == "" {
		client.DisplayName = "Player"
	}

	hub.register <- client

	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.Hub.unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, data, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var msg Message
		if err := json.Unmarshal(data, &msg); err != nil {
			log.Printf("Message parse error: %v", err)
			continue
		}

		// Idempotency: ignore duplicate requestId from the same client
		if msg.RequestID != "" {
			if !c.Hub.trackRequest(c.UserID, msg.RequestID) {
				log.Printf("[WS] Duplicate requestId=%s from user=%s, dropping", msg.RequestID, c.UserID)
				continue
			}
		}

		c.Hub.broadcast <- &ClientMessage{Client: c, Message: &msg}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case msg, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			data, err := json.Marshal(msg)
			if err != nil {
				return
			}
			if err := c.Conn.WriteMessage(websocket.TextMessage, data); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
