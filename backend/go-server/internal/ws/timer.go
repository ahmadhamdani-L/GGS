package ws

import (
	"encoding/json"
	"log"
	"math/rand"
	"time"

	"github.com/ggs/werewolf-server/internal/bot"
	"github.com/ggs/werewolf-server/internal/game"
)

// Bot chat messages for discussion phase
var botChatMessages = []string{
	"Aku curiga sama yang diam...",
	"Siapa yang mau vote?",
	"Ada yang lihat sesuatu mencurigakan?",
	"Aku bukan werewolf, sumpah!",
	"Yang tadi malam mencurigakan...",
	"Hmm, aku punya firasat buruk.",
	"Kita harus kerja sama!",
	"Siapa yang mau mati berikutnya?",
	"Jangan vote aku!",
	"Aku percaya dia bukan werewolf.",
	"Yang diam pasti serigala.",
	"Vote siapa nih?",
	"Aku lihat gerak-gerik mencurigakan.",
	"Kalian percaya aku kan?",
	"Ini susah banget...",
}

func (h *Hub) StartTimerLoop() {
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			h.checkTimers()
		}
	}()
}

func (h *Hub) checkTimers() {
	h.mu.RLock()
	roomIDs := make([]string, 0, len(h.rooms))
	for id := range h.rooms {
		roomIDs = append(roomIDs, id)
	}
	h.mu.RUnlock()

	now := time.Now().UnixMilli()

	for _, roomID := range roomIDs {
		h.mu.RLock()
		room, ok := h.rooms[roomID]
		h.mu.RUnlock()
		if !ok {
			continue
		}

		room.mu.Lock()
		if room.Game == nil || room.Game.TimerDeadline == nil {
			room.mu.Unlock()
			continue
		}

		// Bot chat during DISCUSSION — random bot speaks every ~4 seconds
		if room.Game.Phase == game.PhaseDiscussion && rand.Intn(4) == 0 {
			h.sendBotChatUnlocked(room, roomID)
		}

		if now < *room.Game.TimerDeadline {
			room.mu.Unlock()
			continue
		}

		// Timer expired — auto-advance
		log.Printf("Timer expired for room %s, phase %s", roomID, room.Game.Phase)
		room.Game = game.AutoAdvanceOnTimeout(room.Game)
		room.Game = bot.ProcessBotActions(room.Game, bot.Medium)
		room.mu.Unlock()

		h.broadcastGameState(roomID)
	}
}

// sendBotChatUnlocked sends a random chat message from a random alive bot.
// Must be called with room.mu held.
func (h *Hub) sendBotChatUnlocked(room *Room, roomID string) {
	if room.Game == nil {
		return
	}
	// Pick random alive bot
	var bots []game.PlayerState
	for _, p := range room.Game.Players {
		if p.IsBot && p.IsAlive {
			bots = append(bots, p)
		}
	}
	if len(bots) == 0 {
		return
	}
	speaker := bots[rand.Intn(len(bots))]
	msg := botChatMessages[rand.Intn(len(botChatMessages))]

	resp := map[string]interface{}{
		"senderId": speaker.ID,
		"content":  msg,
	}
	respBytes, _ := json.Marshal(resp)

	// Send to all clients in room (release lock briefly for send)
	for _, c := range room.Clients {
		safeSend(c, &Message{Type: "chat_message", Payload: respBytes})
	}
}
