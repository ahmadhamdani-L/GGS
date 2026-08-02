package api

import (
	"encoding/json"
	"net/http"

	"github.com/ggs/werewolf-server/internal/db"
)

// ─── Lucky Spin ────────────────────────────────────────────

// HandleLuckySpin handles GET /api/lucky-spin (status) and POST /api/lucky-spin (do spin)
func (s *Server) HandleLuckySpin(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		status, err := db.GetSpinStatus(userID)
		if err != nil {
			errorResponse(w, http.StatusInternalServerError, "Gagal memuat spin")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(status)

	case "POST":
		result, err := db.DoSpin(userID)
		if err != nil {
			errorResponse(w, http.StatusBadRequest, err.Error())
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// HandleSpinHistory handles GET /api/lucky-spin/history
func (s *Server) HandleSpinHistory(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	history, err := db.GetSpinHistory(userID, 20)
	if err != nil {
		history = []db.SpinHistoryEntry{}
	}
	if history == nil {
		history = []db.SpinHistoryEntry{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"history": history,
		"count":   len(history),
	})
}
