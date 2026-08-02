package api

import (
	"encoding/json"
	"net/http"

	"github.com/ggs/werewolf-server/internal/db"
)

// ─── Gift Inbox ────────────────────────────────────────────

// HandleGiftInbox handles GET /api/gifts/inbox
func (s *Server) HandleGiftInbox(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	gifts, err := db.GetGiftInbox(userID)
	if err != nil {
		gifts = []db.GiftInboxItem{}
	}
	if gifts == nil {
		gifts = []db.GiftInboxItem{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"gifts": gifts,
		"count": len(gifts),
	})
}

// HandleGiftClaim handles POST /api/gifts/claim
func (s *Server) HandleGiftClaim(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	var body struct {
		GiftID string `json:"giftId"`
		All    bool   `json:"all"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodySize)).Decode(&body); err != nil {
		errorResponse(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if body.All {
		count, err := db.ClaimAllGifts(userID)
		if err != nil {
			errorResponse(w, http.StatusInternalServerError, "Gagal klaim gift")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"claimed": count,
			"message": "Semua gift berhasil diklaim!",
		})
		return
	}

	if body.GiftID == "" {
		errorResponse(w, http.StatusBadRequest, "giftId or all=true required")
		return
	}

	gift, err := db.ClaimGift(userID, body.GiftID)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, "Gift tidak ditemukan atau sudah diklaim")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"gift":    gift,
		"message": "Gift berhasil diklaim!",
	})
}
