package ws

import (
	"encoding/json"
	"log"
	"math/rand"
	"time"

	"github.com/ggs/werewolf-server/internal/bot"
	"github.com/ggs/werewolf-server/internal/game"
	"github.com/ggs/werewolf-server/internal/logger"
)

// Bot chat messages for discussion phase only
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

// P-01 FIX: Replace global 1-second ticker (O(rooms) scan per tick) with
// per-room time.AfterFunc scheduling. The StartTimerLoop is now just a
// lightweight fallback that only checks rooms with an active deadline.
// Main path: each phase change calls scheduleRoomPhaseTimer which fires once.
func (h *Hub) StartTimerLoop() {
	go func() {
		// Fallback: 1s tick, but only checks rooms where timer is active.
		// This handles cases where AfterFunc was not set (e.g., legacy code paths).
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()

		for range ticker.C {
			h.checkExpiredTimers()
		}
	}()
}

// scheduleRoomPhaseTimer sets up a time.AfterFunc for the current phase deadline.
// Called after every phase change that sets a TimerDeadline.
func (h *Hub) scheduleRoomPhaseTimer(roomID string, deadlineMs int64) {
	delay := time.Until(time.UnixMilli(deadlineMs))
	if delay <= 0 {
		delay = time.Millisecond
	}
	time.AfterFunc(delay, func() {
		h.advanceRoomTimer(roomID, deadlineMs)
	})
}

// advanceRoomTimer fires when a room's phase timer expires.
// It checks that the deadline hasn't changed (to handle re-scheduled timers).
func (h *Hub) advanceRoomTimer(roomID string, expectedDeadline int64) {
	h.mu.RLock()
	room, ok := h.rooms[roomID]
	h.mu.RUnlock()
	if !ok {
		return
	}

	room.mu.Lock()
	if room.Game == nil || room.Game.TimerDeadline == nil {
		room.mu.Unlock()
		return
	}
	// Stale check: if deadline was updated since this timer was scheduled, ignore
	if *room.Game.TimerDeadline != expectedDeadline {
		room.mu.Unlock()
		return
	}
	log.Printf("[Timer] Phase expired for room %s, phase %s", roomID, room.Game.Phase)
	room.Game = game.AutoAdvanceOnTimeout(room.Game)
	room.Game = bot.ProcessBotActions(room.Game, bot.Medium)

	// If game reached GAME_END, clear timer and broadcast ONCE only
	isGameEnd := room.Game.Phase == game.PhaseGameEnd || room.Game.Phase == game.PhaseResults

	// Schedule next phase timer if a new deadline was set (and game not ended)
	var newDeadline *int64
	if !isGameEnd {
		newDeadline = room.Game.TimerDeadline
	} else {
		room.Game.TimerDeadline = nil
	}
	room.mu.Unlock()

	h.broadcastGameState(roomID)

	// Chain: schedule the next phase timer immediately (skip if game ended)
	if newDeadline != nil {
		h.scheduleRoomPhaseTimer(roomID, *newDeadline)
	}
}

// checkExpiredTimers is the fallback for rooms not covered by AfterFunc.
func (h *Hub) checkExpiredTimers() {
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

		// Stop processing if game has ended — no more timer-driven broadcasts
		if room.Game.Phase == game.PhaseGameEnd || room.Game.Phase == game.PhaseResults {
			room.Game.TimerDeadline = nil // Clear deadline to prevent re-entry
			room.mu.Unlock()
			continue
		}

		// H-4 FIX: Check if too many players disconnected — abort the game early
		// rather than letting it limp along with nobody playing.
		if game.ShouldAbortGame(room.Game) {
			logger.Warn(logger.CatRoom, "Aborting game — too many disconnected players", map[string]interface{}{
				"roomId": roomID,
			})
			abortMsg, _ := json.Marshal(map[string]string{"reason": "Terlalu banyak pemain disconnect, game dibatalkan"})
			// Collect clients before unlock
			type clientRef struct{ c *Client }
			var refs []clientRef
			for _, c := range room.Clients {
				refs = append(refs, clientRef{c: c})
			}
			room.mu.Unlock()
			for _, ref := range refs {
				safeSend(ref.c, &Message{Type: "game_aborted", Payload: abortMsg})
			}
			// Schedule cleanup
			time.AfterFunc(5*time.Second, func() { h.cleanupRoom(roomID) })
			continue
		}

		// M-03 FIX: Bot chat only during DISCUSSION phase (not night/voting/resolve)
		if room.Game.Phase == game.PhaseDiscussion {
			h.triggerBotChat(room, roomID)
		}

		if now < *room.Game.TimerDeadline {
			room.mu.Unlock()
			continue
		}

		log.Printf("[Timer] Fallback expired for room %s, phase %s", roomID, room.Game.Phase)
		room.Game = game.AutoAdvanceOnTimeout(room.Game)

		// Only process bots if game hasn't ended
		if room.Game.Phase != game.PhaseGameEnd && room.Game.Phase != game.PhaseResults {
			room.Game = bot.ProcessBotActions(room.Game, bot.Medium)
		}

		newDeadline := room.Game.TimerDeadline
		// Clear deadline if game ended to prevent re-entry
		if room.Game.Phase == game.PhaseGameEnd || room.Game.Phase == game.PhaseResults {
			room.Game.TimerDeadline = nil
			newDeadline = nil
		}
		room.mu.Unlock()

		h.broadcastGameState(roomID)

		if newDeadline != nil {
			h.scheduleRoomPhaseTimer(roomID, *newDeadline)
		}
	}
}

// triggerBotChat builds a bot chat message and enqueues it for broadcast
// OUTSIDE the room lock to avoid sending to channels while holding mutex.
// H-02 FIX: never send to channels while room.mu is held.
func (h *Hub) triggerBotChat(room *Room, roomID string) {
	if room.Game == nil {
		return
	}
	// Pick random alive bot while under lock
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

	// Unlock is handled by caller; schedule broadcast asynchronously
	go func() {
		resp := map[string]interface{}{
			"senderId": speaker.ID,
			"content":  msg,
		}
		respBytes, _ := json.Marshal(resp)
		h.broadcastToRoom(roomID, &Message{Type: "chat_message", Payload: respBytes}, nil)
	}()
}
