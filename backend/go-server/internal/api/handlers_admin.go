package api

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
)

// Admin endpoints are protected by X-Admin-Key header + optional IP allowlist.
// All require ADMIN_KEY env var to be set.

func adminAuth(r *http.Request) bool {
	key := os.Getenv("ADMIN_KEY")
	if key == "" || r.Header.Get("X-Admin-Key") != key {
		return false
	}
	// P2-29: Optional IP allowlist for admin endpoints
	allowedIPs := os.Getenv("ADMIN_ALLOWED_IPS")
	if allowedIPs == "" {
		return true // No IP restriction configured
	}
	clientIP := strings.Split(r.RemoteAddr, ":")[0]
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		clientIP = strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	for _, ip := range strings.Split(allowedIPs, ",") {
		if strings.TrimSpace(ip) == clientIP {
			return true
		}
	}
	logger.Warn(logger.CatAuth, "Admin access denied by IP", map[string]interface{}{
		"clientIP": clientIP, "allowed": allowedIPs,
	})
	return false
}

// POST /api/admin/ban — ban or unban a user
func (s *Server) HandleAdminBan(w http.ResponseWriter, r *http.Request) {
	if !adminAuth(r) { errorResponse(w, 403, "forbidden"); return }
	if r.Method != "POST" { errorResponse(w, 405, "method not allowed"); return }
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req struct {
		UserID string `json:"userId"`
		Ban    bool   `json:"ban"` // true=ban, false=unban
		Reason string `json:"reason"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.UserID == "" {
		errorResponse(w, 400, "userId required")
		return
	}

	if db.DB != nil {
		if req.Ban {
			db.DB.Exec(`UPDATE users SET is_banned=true, ban_reason=$2 WHERE id=$1`, req.UserID, req.Reason)
			// Force disconnect via WS
			if s.Hub != nil {
				s.Hub.SendToUser(req.UserID, "account_banned", map[string]interface{}{
					"reason": req.Reason,
				})
			}
			logger.Info(logger.CatAPI, "User banned", map[string]interface{}{
				"userId": req.UserID, "reason": req.Reason})
		} else {
			db.DB.Exec(`UPDATE users SET is_banned=false, ban_reason=NULL WHERE id=$1`, req.UserID)
			logger.Info(logger.CatAPI, "User unbanned", map[string]interface{}{"userId": req.UserID})
		}
	}
	jsonResponse(w, 200, map[string]string{"status": "ok"})
}

// PUT /api/admin/gift-catalog — update a gift catalog item
func (s *Server) HandleAdminUpdateGift(w http.ResponseWriter, r *http.Request) {
	if !adminAuth(r) { errorResponse(w, 403, "forbidden"); return }
	if r.Method != "PUT" { errorResponse(w, 405, "method not allowed"); return }
	r.Body = http.MaxBytesReader(w, r.Body, 8192)

	var req struct {
		ID           string `json:"id"`
		DiamondPrice *int   `json:"diamondPrice"`
		IsActive     *bool  `json:"isActive"`
		IsLimited    *bool  `json:"isLimited"`
		Description  *string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ID == "" {
		errorResponse(w, 400, "id required")
		return
	}

	if db.DB != nil {
		if req.DiamondPrice != nil {
			db.DB.Exec(`UPDATE gift_catalog SET diamond_price=$2 WHERE id=$1`, req.ID, *req.DiamondPrice)
		}
		if req.IsActive != nil {
			db.DB.Exec(`UPDATE gift_catalog SET is_active=$2 WHERE id=$1`, req.ID, *req.IsActive)
		}
		if req.IsLimited != nil {
			db.DB.Exec(`UPDATE gift_catalog SET is_limited=$2 WHERE id=$1`, req.ID, *req.IsLimited)
		}
		if req.Description != nil {
			db.DB.Exec(`UPDATE gift_catalog SET description=$2 WHERE id=$1`, req.ID, *req.Description)
		}
	}
	jsonResponse(w, 200, map[string]string{"status": "updated"})
}

// GET /api/admin/stats — server stats overview
func (s *Server) HandleAdminStats(w http.ResponseWriter, r *http.Request) {
	if !adminAuth(r) { errorResponse(w, 403, "forbidden"); return }
	if r.Method != "GET" { errorResponse(w, 405, "method not allowed"); return }

	stats := map[string]interface{}{
		"connectedClients": 0,
		"activeRooms":      0,
		"activeGames":      0,
	}
	if s.Hub != nil {
		hubStats := s.Hub.GetStats()
		stats["connectedClients"] = hubStats["clients"]
		stats["activeRooms"]      = hubStats["rooms"]
		stats["activeGames"]      = hubStats["games"]
	}

	if db.DB != nil {
		var totalUsers, totalGames int
		db.DB.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&totalUsers)
		db.DB.QueryRow(`SELECT COUNT(*) FROM match_history`).Scan(&totalGames)
		stats["totalUsers"] = totalUsers
		stats["totalGames"] = totalGames

		var totalDiamondsSpent int64
		db.DB.QueryRow(`SELECT COALESCE(SUM(total_spent),0) FROM diamond_balance`).Scan(&totalDiamondsSpent)
		stats["totalDiamondsSpent"] = totalDiamondsSpent
	}
	jsonResponse(w, 200, stats)
}

// PUT /api/admin/feature-flags — update a feature flag
func (s *Server) HandleAdminFeatureFlags(w http.ResponseWriter, r *http.Request) {
	if !adminAuth(r) { errorResponse(w, 403, "forbidden"); return }
	if r.Method != "PUT" { errorResponse(w, 405, "method not allowed"); return }
	r.Body = http.MaxBytesReader(w, r.Body, 4096)

	var req struct {
		Key         string `json:"key"`
		Enabled     *bool  `json:"enabled"`
		Description *string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Key == "" {
		errorResponse(w, 400, "key required")
		return
	}
	// Whitelist valid keys to prevent injection
	validKeys := map[string]bool{
		"maintenance_mode": true, "push_notifications": true,
		"gift_system": true, "payment_enabled": true,
		"registration_open": true,
	}
	if !validKeys[strings.ToLower(req.Key)] {
		errorResponse(w, 400, "invalid flag key")
		return
	}

	if db.DB != nil {
		if req.Enabled != nil {
			db.DB.Exec(`UPDATE feature_flags SET enabled=$2 WHERE key=$1`, req.Key, *req.Enabled)
		}
		if req.Description != nil {
			db.DB.Exec(`UPDATE feature_flags SET description=$2 WHERE key=$1`, req.Key, *req.Description)
		}
	}
	jsonResponse(w, 200, map[string]string{"status": "updated"})
}
