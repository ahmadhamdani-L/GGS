package api

import (
	"encoding/json"
	"net/http"

	"github.com/ggs/werewolf-server/internal/db"
)

// ─── Events ────────────────────────────────────────────────

// HandleEvents handles GET /api/events
func (s *Server) HandleEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get userID from context (may be empty for unauthenticated)
	userID, _ := r.Context().Value(userIDKey).(string)

	events, err := db.GetEventsWithProgress(userID)
	if err != nil {
		events = []db.EventWithProgress{}
	}
	if events == nil {
		events = []db.EventWithProgress{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"events": events,
		"count":  len(events),
	})
}

// HandleEventClaim handles POST /api/events/claim
func (s *Server) HandleEventClaim(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	var body struct {
		EventID string `json:"eventId"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodySize)).Decode(&body); err != nil {
		errorResponse(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if body.EventID == "" {
		errorResponse(w, http.StatusBadRequest, "eventId required")
		return
	}

	err := db.ClaimEventReward(userID, body.EventID)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Gagal klaim reward")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Event reward claimed!",
	})
}
