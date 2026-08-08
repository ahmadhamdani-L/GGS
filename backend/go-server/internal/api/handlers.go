package api

import (
	"context"
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"github.com/ggs/werewolf-server/internal/auth"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/security"
	"github.com/ggs/werewolf-server/internal/push"
	"github.com/ggs/werewolf-server/internal/ws"
)

// Input validation patterns
var (
	emailRegex    = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	uuidRegex     = regexp.MustCompile(`^[a-fA-F0-9\-]{36}$`)
	itemIDRegex   = regexp.MustCompile(`^[a-zA-Z0-9_\-]{1,50}$`)
	categoryRegex = regexp.MustCompile(`^(avatar|frame|title|effect|emote)$`)
	actionRegex   = regexp.MustCompile(`^(add|accept|block|remove)$`)
	reasonRegex   = regexp.MustCompile(`^(spam|offensive|cheating|harassment|other)$`)
)

// Request body size limits
const (
	maxBodySize      = 1024 * 10   // 10KB for most requests
	maxReportDetails = 500         // Max characters for report details
	maxMatchLimit    = 100         // Max match history items
	maxLeaderLimit   = 100         // Max leaderboard entries
)

// ErrorResponse represents a structured API error
type ErrorResponse struct {
	Error   string `json:"error"`
	Code    string `json:"code,omitempty"`
	Details string `json:"details,omitempty"`
}

// validateEmail checks if email format is valid
func validateEmail(email string) bool {
	if len(email) < 5 || len(email) > 254 {
		return false
	}
	return emailRegex.MatchString(email)
}

// validatePassword checks password strength requirements:
// - Minimum 8 characters
// - At least one uppercase letter
// - At least one lowercase letter
// - At least one digit
func validatePassword(password string) (bool, string) {
	if len(password) < 8 {
		return false, "password must be at least 8 characters"
	}
	if len(password) > 128 {
		return false, "password must be less than 128 characters"
	}

	var hasUpper, hasLower, hasDigit bool
	for _, c := range password {
		switch {
		case unicode.IsUpper(c):
			hasUpper = true
		case unicode.IsLower(c):
			hasLower = true
		case unicode.IsDigit(c):
			hasDigit = true
		}
	}

	if !hasUpper {
		return false, "password must contain at least one uppercase letter"
	}
	if !hasLower {
		return false, "password must contain at least one lowercase letter"
	}
	if !hasDigit {
		return false, "password must contain at least one digit"
	}

	return true, ""
}

// validateDisplayName checks display name requirements
func validateDisplayName(name string) (bool, string) {
	name = strings.TrimSpace(name)
	if len(name) < 2 {
		return false, "display name must be at least 2 characters"
	}
	if len(name) > 20 {
		return false, "display name must be less than 20 characters"
	}
	// Only allow alphanumeric, spaces, and common punctuation
	validNameRegex := regexp.MustCompile(`^[a-zA-Z0-9\s._\-]+$`)
	if !validNameRegex.MatchString(name) {
		return false, "display name contains invalid characters"
	}
	return true, ""
}

// validateUUID checks if a string is a valid UUID format
func validateUUID(id string) bool {
	return uuidRegex.MatchString(strings.TrimSpace(id))
}

// validateAvatarID checks if avatar ID is within valid range
func validateAvatarID(id int) bool {
	return id >= 1 && id <= 12 // 12 avatars available
}

// validateLimit validates and sanitizes pagination limit
func validateLimit(limit, defaultVal, maxVal int) int {
	if limit <= 0 {
		return defaultVal
	}
	if limit > maxVal {
		return maxVal
	}
	return limit
}

// sanitizeString escapes HTML to prevent XSS
func sanitizeString(input string) string {
	return html.EscapeString(strings.TrimSpace(input))
}

type Server struct {
	Hub *ws.Hub
}

func NewServer(h ...*ws.Hub) *Server {
	var hub *ws.Hub
	if len(h) > 0 {
		hub = h[0]
	}
	return &Server{Hub: hub}
}

func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func errorResponse(w http.ResponseWriter, status int, msg string) {
	jsonResponse(w, status, ErrorResponse{Error: msg})
}

func errorResponseWithCode(w http.ResponseWriter, status int, msg, code string) {
	jsonResponse(w, status, ErrorResponse{Error: msg, Code: code})
}

// ─── Auth ────────────────────────────────────────────────

func (s *Server) HandleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	// H-06 FIX: limit request body on all auth endpoints
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	var req struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"displayName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}

	// Trim whitespace
	req.Email = strings.TrimSpace(req.Email)
	req.DisplayName = strings.TrimSpace(req.DisplayName)

	// Required fields check
	if req.Email == "" || req.Password == "" || req.DisplayName == "" {
		errorResponse(w, 400, "email, password, and displayName required")
		return
	}

	// Validate email format
	if !validateEmail(req.Email) {
		errorResponse(w, 400, "invalid email format")
		return
	}

	// Validate password strength
	if valid, msg := validatePassword(req.Password); !valid {
		errorResponse(w, 400, msg)
		return
	}

	// Validate display name
	if valid, msg := validateDisplayName(req.DisplayName); !valid {
		errorResponse(w, 400, msg)
		return
	}

	var user *db.User
	var profile *db.Profile
	var err error

	if db.DB != nil {
		user, profile, err = db.CreateUser(req.Email, req.Password, req.DisplayName)
	} else {
		user, profile, err = db.Mem.CreateUser(req.Email, req.Password, req.DisplayName)
	}
	if err != nil {
		errorResponse(w, 409, err.Error())
		return
	}

	// Generate token pair (access + refresh)
	tokenPair, err := auth.GenerateTokenPair(user.ID)
	if err != nil {
		errorResponse(w, 500, "failed to generate tokens")
		return
	}

	jsonResponse(w, 201, map[string]interface{}{
		"token":        tokenPair.AccessToken,  // backward compatible
		"accessToken":  tokenPair.AccessToken,
		"refreshToken": tokenPair.RefreshToken,
		"expiresIn":    tokenPair.ExpiresIn,
		"user":         user,
		"profile":      profile,
	})
}

func (s *Server) HandleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	// H-06 FIX: limit request body
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}

	// Trim whitespace
	req.Email = strings.TrimSpace(req.Email)

	// Basic validation
	if req.Email == "" || req.Password == "" {
		errorResponse(w, 400, "email and password required")
		return
	}

	// Validate email format
	if !validateEmail(req.Email) {
		errorResponse(w, 400, "invalid email format")
		return
	}

	var user *db.User
	var profile *db.Profile
	var err error

	if db.DB != nil {
		user, err = db.LoginUser(req.Email, req.Password)
		if err == nil {
			profile, _ = db.GetProfile(user.ID)
		}
	} else {
		user, err = db.Mem.LoginUser(req.Email, req.Password)
		if err == nil {
			profile, _ = db.Mem.GetProfile(user.ID)
		}
	}
	if err != nil {
		errorResponse(w, 401, err.Error())
		return
	}

	// Generate token pair (access + refresh)
	tokenPair, err := auth.GenerateTokenPair(user.ID)
	if err != nil {
		errorResponse(w, 500, "failed to generate tokens")
		return
	}

	jsonResponse(w, 200, map[string]interface{}{
		"token":        tokenPair.AccessToken,  // backward compatible
		"accessToken":  tokenPair.AccessToken,
		"refreshToken": tokenPair.RefreshToken,
		"expiresIn":    tokenPair.ExpiresIn,
		"user":         user,
		"profile":      profile,
	})
}

func (s *Server) HandleGuest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	// H-06 FIX: limit request body
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	var req struct {
		DisplayName string `json:"displayName"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	var user *db.User
	var profile *db.Profile
	var err error

	if db.DB != nil {
		user, profile, err = db.CreateGuest(req.DisplayName)
	} else {
		user, profile, err = db.Mem.CreateGuest(req.DisplayName)
	}
	if err != nil {
		errorResponse(w, 500, err.Error())
		return
	}

	// Generate token pair (access + refresh)
	tokenPair, err := auth.GenerateTokenPair(user.ID)
	if err != nil {
		errorResponse(w, 500, "failed to generate tokens")
		return
	}

	jsonResponse(w, 201, map[string]interface{}{
		"token":        tokenPair.AccessToken,  // backward compatible
		"accessToken":  tokenPair.AccessToken,
		"refreshToken": tokenPair.RefreshToken,
		"expiresIn":    tokenPair.ExpiresIn,
		"user":         user,
		"profile":      profile,
	})
}

// HandleRefresh exchanges a valid refresh token for a new token pair
func (s *Server) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}

	if req.RefreshToken == "" {
		errorResponseWithCode(w, 400, "refreshToken required", "MISSING_REFRESH_TOKEN")
		return
	}

	// Refresh tokens (this also rotates the refresh token)
	tokenPair, err := auth.RefreshAccessToken(req.RefreshToken)
	if err != nil {
		errorResponseWithCode(w, 401, "invalid or expired refresh token", "INVALID_REFRESH_TOKEN")
		return
	}

	jsonResponse(w, 200, map[string]interface{}{
		"token":        tokenPair.AccessToken,  // backward compatible
		"accessToken":  tokenPair.AccessToken,
		"refreshToken": tokenPair.RefreshToken,
		"expiresIn":    tokenPair.ExpiresIn,
	})
}

// HandleLogout revokes all refresh tokens for the user (logout from all devices)
func (s *Server) HandleLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	// Revoke all refresh tokens for this user
	auth.RevokeAllUserTokens(userID)

	jsonResponse(w, 200, map[string]string{
		"message": "logged out successfully",
	})
}

// HandleForgotPassword implements a two-step reset flow.
// H-04 FIX: Step 1 — POST email → generates a short-lived reset token stored in DB.
//           Step 2 — POST email + token + newPassword → validates token then resets.
// In production this token would be sent by email; here it is returned directly
// so the client can drive the "enter token" UI (e.g., shown in-app for dev,
// sent via email service integration for prod).
func (s *Server) HandleForgotPassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

	var req struct {
		Email       string `json:"email"`
		Token       string `json:"token"`       // empty on step 1, filled on step 2
		NewPassword string `json:"newPassword"` // empty on step 1
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	if req.Email == "" {
		errorResponse(w, 400, "email required")
		return
	}
	if !validateEmail(req.Email) {
		errorResponse(w, 400, "invalid email format")
		return
	}

	if req.Token == "" {
		// Step 1: generate reset token
		token, err := db.CreatePasswordResetToken(req.Email)
		if err != nil {
			// Always return 200 to prevent email enumeration
			jsonResponse(w, 200, map[string]string{"message": "Jika email terdaftar, kode reset telah dikirim."})
			return
		}
		// In production: send token via email service. For dev/testing return it.
		devMode := os.Getenv("APP_ENV") != "production"
		resp := map[string]string{"message": "Kode reset berhasil dikirim."}
		if devMode {
			resp["token"] = token // dev only
		}
		jsonResponse(w, 200, resp)
		return
	}

	// Step 2: validate token + reset password
	if req.NewPassword == "" {
		errorResponse(w, 400, "newPassword required")
		return
	}
	if valid, msg := validatePassword(req.NewPassword); !valid {
		errorResponse(w, 400, msg)
		return
	}

	if err := db.ResetPasswordWithToken(req.Email, req.Token, req.NewPassword); err != nil {
		errorResponseWithCode(w, 400, err.Error(), "INVALID_RESET_TOKEN")
		return
	}

	jsonResponse(w, 200, map[string]string{
		"message": "Password berhasil diubah. Silakan login kembali.",
	})
}

// HandleConvertGuest converts a guest account to a registered email account
func (s *Server) HandleConvertGuest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, 400, "invalid body")
		return
	}

	req.Email = strings.TrimSpace(req.Email)
	if req.Email == "" || req.Password == "" {
		errorResponse(w, 400, "email and password required")
		return
	}

	if !validateEmail(req.Email) {
		errorResponse(w, 400, "invalid email format")
		return
	}

	if valid, msg := validatePassword(req.Password); !valid {
		errorResponse(w, 400, msg)
		return
	}

	var user *db.User
	var profile *db.Profile
	var err error

	if db.DB != nil {
		user, profile, err = db.ConvertGuest(userID, req.Email, req.Password)
	} else {
		user, profile, err = db.Mem.ConvertGuest(userID, req.Email, req.Password)
	}

	if err != nil {
		errorResponse(w, 400, err.Error())
		return
	}

	jsonResponse(w, 200, map[string]interface{}{
		"message": "Akun berhasil dihubungkan ke email!",
		"user":    user,
		"profile": profile,
	})
}

// HandleGetPublicRooms handles GET /api/rooms/public
func (s *Server) HandleGetPublicRooms(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "Method not allowed")
		return
	}

	var rooms []map[string]interface{}
	if s.Hub != nil {
		rooms = s.Hub.GetPublicRoomsList()
	} else {
		rooms = make([]map[string]interface{}, 0)
	}
	jsonResponse(w, 200, map[string]interface{}{
		"rooms": rooms,
	})
}

// ─── Profile ─────────────────────────────────────────────

func (s *Server) HandleProfile(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		var profile *db.Profile
		var err error
		if db.DB != nil {
			profile, err = db.GetProfile(userID)
		} else {
			profile, err = db.Mem.GetProfile(userID)
		}
		if err != nil {
			errorResponseWithCode(w, 404, "profile not found", "PROFILE_NOT_FOUND")
			return
		}
		// Enrich profile response with isGuest flag from users table
		isGuest := false
		if db.DB != nil {
			db.DB.QueryRow(`SELECT is_guest FROM users WHERE id = $1`, userID).Scan(&isGuest)
		} else if db.Mem != nil {
			if u, _ := db.Mem.GetUserByID(userID); u != nil {
				isGuest = u.IsGuest
			}
		}
		type profileResp struct {
			*db.Profile
			IsGuest bool `json:"isGuest"`
		}
		jsonResponse(w, 200, profileResp{Profile: profile, IsGuest: isGuest})

	case "PUT":
		// Limit request body size
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			DisplayName string                 `json:"displayName"`
			AvatarID    int                    `json:"avatarId"`
			ChibiConfig map[string]interface{} `json:"chibiConfig"`
			AvatarURL   string                 `json:"avatarUrl"` // Task #7: custom uploaded photo
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		// Validate display name if provided
		if req.DisplayName != "" {
			req.DisplayName = security.SanitizeDisplayName(req.DisplayName)
			if valid, msg := validateDisplayName(req.DisplayName); !valid {
				errorResponseWithCode(w, 400, msg, "INVALID_DISPLAY_NAME")
				return
			}
		}

		// Validate avatar ID if provided
		if req.AvatarID != 0 && !validateAvatarID(req.AvatarID) {
			errorResponseWithCode(w, 400, "avatar ID must be between 1 and 12", "INVALID_AVATAR_ID")
			return
		}

		// Validate chibi config if provided
		if req.ChibiConfig != nil {
			if !validateChibiConfig(req.ChibiConfig) {
				errorResponseWithCode(w, 400, "invalid chibi config format", "INVALID_CHIBI_CONFIG")
				return
			}
		}

		var profile *db.Profile
		var err error
		if db.DB != nil {
			profile, err = db.UpdateProfile(userID, req.DisplayName, req.AvatarID)
			if err == nil && req.ChibiConfig != nil {
				err = db.UpdateChibiConfig(userID, req.ChibiConfig)
				if err == nil {
					profile, _ = db.GetProfile(userID)
				}
			}
			// Task #7: save avatar_url if provided from profile setup
			if err == nil && req.AvatarURL != "" {
				db.DB.Exec(`UPDATE profiles SET avatar_url=$2, updated_at=now() WHERE user_id=$1`,
					userID, req.AvatarURL)
				if profile != nil {
					profile.AvatarURL = req.AvatarURL
				}
			}
		} else {
			profile, err = db.Mem.UpdateProfile(userID, req.DisplayName, req.AvatarID)
			if err == nil && req.ChibiConfig != nil {
				db.Mem.UpdateChibiConfig(userID, req.ChibiConfig)
				profile, _ = db.Mem.GetProfile(userID)
			}
		}
		if err != nil {
			errorResponseWithCode(w, 500, "failed to update profile", "UPDATE_FAILED")
			return
		}
		// M-01 FIX: Invalidate WS hub profile cache so next join uses fresh data
		if s.Hub != nil {
			s.Hub.InvalidateProfileCache(userID)
		}
		jsonResponse(w, 200, profile)

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// validateChibiConfig validates the chibi config structure
func validateChibiConfig(config map[string]interface{}) bool {
	// Check required color fields (should be integers)
	colorFields := []string{"skinColor", "hairColor", "eyeColor", "shirtColor", "pantsColor"}
	for _, field := range colorFields {
		if val, ok := config[field]; ok {
			switch v := val.(type) {
			case float64:
				if v < 0 || v > 4294967295 { // Max uint32
					return false
				}
			case int:
				if v < 0 {
					return false
				}
			default:
				return false
			}
		}
	}

	// Check style fields (should be integers 0-20 range)
	styleFields := []string{"hairStyle", "eyeStyle", "expression", "shirtStyle", "accessory"}
	for _, field := range styleFields {
		if val, ok := config[field]; ok {
			switch v := val.(type) {
			case float64:
				if v < 0 || v > 20 {
					return false
				}
			case int:
				if v < 0 || v > 20 {
					return false
				}
			default:
				return false
			}
		}
	}

	// showBlush should be boolean
	if val, ok := config["showBlush"]; ok {
		if _, isBool := val.(bool); !isBool {
			return false
		}
	}

	return true
}

// ─── Stats ───────────────────────────────────────────────

func (s *Server) HandleStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)
	var stats *db.PlayerStats
	var err error
	if db.DB != nil {
		stats, err = db.GetPlayerStats(userID)
	} else {
		stats, err = db.Mem.GetPlayerStats(userID)
	}
	if err != nil {
		errorResponseWithCode(w, 404, "stats not found", "STATS_NOT_FOUND")
		return
	}
	jsonResponse(w, 200, stats)
}

func (s *Server) HandleMatchHistory(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)
	
	// Validate and sanitize limit parameter
	limitStr := r.URL.Query().Get("limit")
	limit, _ := strconv.Atoi(limitStr)
	limit = validateLimit(limit, 20, maxMatchLimit)
	
	var history []db.MatchHistoryEntry
	var err error
	if db.DB != nil {
		history, err = db.GetMatchHistory(userID, limit)
	} else {
		history, err = db.Mem.GetMatchHistory(userID, limit)
	}
	if err != nil {
		errorResponseWithCode(w, 500, "failed to fetch match history", "FETCH_FAILED")
		return
	}
	if history == nil {
		history = []db.MatchHistoryEntry{}
	}
	jsonResponse(w, 200, map[string]interface{}{"matches": history})
}

func (s *Server) HandleGetMatchReplay(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	
	// Extract match ID from URL path: /api/matches/{id}/replay
	matchID := r.PathValue("id")
	if matchID == "" {
		errorResponse(w, 400, "invalid path")
		return
	}

	var actions []db.GameAction
	var err error
	if db.DB != nil {
		actions, err = db.GetGameReplay(matchID)
	}
	
	if err != nil {
		errorResponseWithCode(w, 500, "failed to fetch match replay", "FETCH_FAILED")
		return
	}
	
	if actions == nil {
		actions = []db.GameAction{}
	}
	
	jsonResponse(w, 200, map[string]interface{}{"actions": actions})
}

func (s *Server) HandleLeaderboard(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	
	// Validate sort parameter - only allow specific values
	sortBy := r.URL.Query().Get("sort")
	validSorts := map[string]bool{"rating": true, "wins": true, "games": true, "winrate": true}
	if sortBy != "" && !validSorts[sortBy] {
		sortBy = "rating" // Default to rating if invalid
	}
	
	// Validate and sanitize limit parameter
	limitStr := r.URL.Query().Get("limit")
	limit, _ := strconv.Atoi(limitStr)
	limit = validateLimit(limit, 50, maxLeaderLimit)
	
	var entries []db.LeaderboardEntry
	var err error
	if db.DB != nil {
		entries, err = db.GetLeaderboard(sortBy, limit)
	} else {
		entries, err = db.Mem.GetLeaderboard(sortBy, limit)
	}
	if err != nil {
		errorResponseWithCode(w, 500, "failed to fetch leaderboard", "FETCH_FAILED")
		return
	}
	if entries == nil {
		entries = []db.LeaderboardEntry{}
	}
	jsonResponse(w, 200, map[string]interface{}{"leaderboard": entries})
}

// ─── Middleware ──────────────────────────────────────────

// NOTE: ctxKey kept for backward compat with handlers in this file.
// New handlers should use ContextKeyUserID from middleware.go.
type ctxKey string

const userIDKey ctxKey = "userId"

func (s *Server) AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if header == "" {
			errorResponse(w, 401, "missing authorization")
			return
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			errorResponse(w, 401, "invalid authorization format")
			return
		}
		userID, err := auth.ValidateToken(parts[1])
		if err != nil {
			errorResponse(w, 401, "invalid token")
			return
		}
		// Set BOTH keys so handlers using either type can read the user ID
		ctx := context.WithValue(r.Context(), userIDKey, userID)
		ctx = context.WithValue(ctx, ContextKeyUserID, userID)
		next(w, r.WithContext(ctx))
	}
}

// ─── Health ──────────────────────────────────────────────

func HealthHandler(w http.ResponseWriter, r *http.Request) {
	dbOk := false
	var poolStats map[string]interface{}
	
	if db.DB != nil {
		if err := db.HealthCheck(); err == nil {
			dbOk = true
			poolStats = db.GetPoolStats()
		}
	}
	
	status := "ok"
	statusCode := 200
	if !dbOk && db.DB != nil {
		status = "degraded"
		statusCode = 503
	}
	
	response := map[string]interface{}{
		"status":   status,
		"service":  "ggs-werewolf-server",
		"version":  "2.0.0",
		"database": dbOk,
	}
	
	// Include pool stats in verbose mode
	if r.URL.Query().Get("verbose") == "true" && poolStats != nil {
		response["pool"] = poolStats
	}
	
	jsonResponse(w, statusCode, response)
}

// ─── Achievements ────────────────────────────────────────

func (s *Server) HandleAchievements(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)

	unlocked, err := db.GetPlayerAchievements(userID)
	if err != nil {
		unlocked = []db.PlayerAchievement{}
	}

	// Return all definitions + player's unlocked status
	unlockedMap := make(map[string]string)
	for _, a := range unlocked {
		unlockedMap[a.AchievementID] = a.UnlockedAt
	}

	type AchievementResponse struct {
		ID          string  `json:"id"`
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Emoji       string  `json:"emoji"`
		Category    string  `json:"category"`
		Unlocked    bool    `json:"unlocked"`
		UnlockedAt  *string `json:"unlockedAt"`
	}

	var result []AchievementResponse
	for _, def := range db.Achievements {
		ar := AchievementResponse{
			ID: def.ID, Name: def.Name, Description: def.Description,
			Emoji: def.Emoji, Category: def.Category,
		}
		if ts, ok := unlockedMap[def.ID]; ok {
			ar.Unlocked = true
			ar.UnlockedAt = &ts
		}
		result = append(result, ar)
	}

	jsonResponse(w, 200, map[string]interface{}{"achievements": result})
}

// ─── Social (Friends, Report, Block) ─────────────────────

func (s *Server) HandleFriends(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		friends, err := db.GetFriends(userID)
		if err != nil {
			friends = []db.FriendProfile{}
		}
		pending, _ := db.GetPendingRequests(userID)
		if pending == nil {
			pending = []db.FriendProfile{}
		}
		jsonResponse(w, 200, map[string]interface{}{"friends": friends, "pending": pending})

	case "POST":
		// Limit request body size
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			FriendID string `json:"friendId"`
			Action   string `json:"action"` // "add", "accept", "block", "remove"
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		// Validate friend ID (must be a valid UUID)
		req.FriendID = strings.TrimSpace(req.FriendID)
		if req.FriendID == "" {
			errorResponseWithCode(w, 400, "friendId is required", "MISSING_FRIEND_ID")
			return
		}
		if !validateUUID(req.FriendID) {
			errorResponseWithCode(w, 400, "invalid friendId format", "INVALID_FRIEND_ID")
			return
		}

		// Prevent self-friending
		if req.FriendID == userID {
			errorResponseWithCode(w, 400, "cannot friend yourself", "SELF_FRIEND")
			return
		}

		// Validate action
		req.Action = strings.ToLower(strings.TrimSpace(req.Action))
		if !actionRegex.MatchString(req.Action) {
			errorResponseWithCode(w, 400, "action must be: add, accept, block, or remove", "INVALID_ACTION")
			return
		}

		var err error
		switch req.Action {
		case "add":
			err = db.SendFriendRequest(userID, req.FriendID)
			if err == nil {
				// Send push notification to the friend
				senderProfile, _ := db.GetProfile(userID)
				senderName := "Seseorang"
				if senderProfile != nil {
					senderName = senderProfile.DisplayName
				}
				go push.SendFriendRequestPushNotification(req.FriendID, senderName)
			}
		case "accept":
			err = db.AcceptFriendRequest(userID, req.FriendID)
			if err == nil {
				// Notify the original requester that their request was accepted
				accepterProfile, _ := db.GetProfile(userID)
				accepterName := "Seseorang"
				if accepterProfile != nil {
					accepterName = accepterProfile.DisplayName
				}
				go push.SendPushNotification(req.FriendID, "Pertemanan Diterima! 🎉",
					fmt.Sprintf("%s menerima permintaan pertemananmu!", accepterName),
					map[string]interface{}{"type": "friend_accepted", "friendName": accepterName})
			}
		case "block":
			err = db.BlockUser(userID, req.FriendID)
		case "remove":
			err = db.RemoveFriend(userID, req.FriendID)
		}
		if err != nil {
			errorResponseWithCode(w, 500, err.Error(), "ACTION_FAILED")
			return
		}
		jsonResponse(w, 200, map[string]string{"status": "ok"})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// HandleSearchUsers searches users in DB by display name or user ID
func (s *Server) HandleSearchUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "Method not allowed")
		return
	}

	query := r.URL.Query().Get("q")
	if strings.TrimSpace(query) == "" {
		jsonResponse(w, 200, map[string]interface{}{"users": []db.Profile{}})
		return
	}

	var users []db.Profile
	if db.DB != nil {
		users, _ = db.SearchUsers(query)
	} else if db.Mem != nil {
		users = db.Mem.SearchUsers(query)
	} else {
		users = []db.Profile{}
	}

	jsonResponse(w, 200, map[string]interface{}{"users": users})
}

// HandleSendGift is now fully implemented in handlers_social.go.
// This stub is kept to prevent import errors during transition.
// The route in main.go points to the new full implementation.
// OLD stub removed — see handlers_social.go HandleSendGift.

func (s *Server) HandleReport(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	
	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	
	userID := r.Context().Value(userIDKey).(string)
	var req struct {
		ReportedID string `json:"reportedId"`
		Reason     string `json:"reason"`
		Details    string `json:"details"`
		MatchID    string `json:"matchId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
		return
	}

	// Validate reported user ID
	req.ReportedID = strings.TrimSpace(req.ReportedID)
	if req.ReportedID == "" {
		errorResponseWithCode(w, 400, "reportedId is required", "MISSING_REPORTED_ID")
		return
	}
	if !validateUUID(req.ReportedID) {
		errorResponseWithCode(w, 400, "invalid reportedId format", "INVALID_REPORTED_ID")
		return
	}

	// Prevent self-reporting
	if req.ReportedID == userID {
		errorResponseWithCode(w, 400, "cannot report yourself", "SELF_REPORT")
		return
	}

	// Validate reason (must be one of predefined reasons)
	req.Reason = strings.ToLower(strings.TrimSpace(req.Reason))
	if req.Reason == "" {
		errorResponseWithCode(w, 400, "reason is required", "MISSING_REASON")
		return
	}
	if !reasonRegex.MatchString(req.Reason) {
		errorResponseWithCode(w, 400, "reason must be: spam, offensive, cheating, harassment, or other", "INVALID_REASON")
		return
	}

	// Sanitize and limit details
	req.Details = security.SanitizeString(req.Details)
	if len(req.Details) > maxReportDetails {
		req.Details = req.Details[:maxReportDetails]
	}

	// Validate match ID if provided
	if req.MatchID != "" {
		req.MatchID = strings.TrimSpace(req.MatchID)
		if !validateUUID(req.MatchID) {
			errorResponseWithCode(w, 400, "invalid matchId format", "INVALID_MATCH_ID")
			return
		}
	}

	err := db.ReportPlayer(userID, req.ReportedID, req.Reason, req.Details, req.MatchID)
	if err != nil {
		errorResponseWithCode(w, 500, "failed to submit report", "REPORT_FAILED")
		return
	}
	jsonResponse(w, 200, map[string]string{"status": "reported"})
}

func (s *Server) HandleRecentPlayers(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)
	players, err := db.GetRecentPlayers(userID, 20)
	if err != nil {
		players = []db.RecentPlayer{}
	}
	jsonResponse(w, 200, map[string]interface{}{"players": players})
}

func (s *Server) HandleBlocked(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		// Get list of blocked users
		blocked, err := db.GetBlockedUsers(userID)
		if err != nil {
			blocked = []db.BlockedUser{}
		}
		jsonResponse(w, 200, map[string]interface{}{"blocked": blocked})

	case "DELETE":
		// Unblock a user
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)

		var req struct {
			UserID string `json:"userId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		req.UserID = strings.TrimSpace(req.UserID)
		if req.UserID == "" {
			errorResponseWithCode(w, 400, "userId is required", "MISSING_USER_ID")
			return
		}
		if !validateUUID(req.UserID) {
			errorResponseWithCode(w, 400, "invalid userId format", "INVALID_USER_ID")
			return
		}

		if err := db.UnblockUser(userID, req.UserID); err != nil {
			errorResponseWithCode(w, 500, "failed to unblock user", "UNBLOCK_FAILED")
			return
		}
		jsonResponse(w, 200, map[string]string{"status": "unblocked"})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// ─── Ranking ─────────────────────────────────────────────

func (s *Server) HandleRankInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)

	var rating int
	var rankTier string
	if db.DB != nil {
		db.DB.QueryRow(`SELECT rating, rank_tier FROM player_stats WHERE user_id = $1`, userID).Scan(&rating, &rankTier)
	}

	tier := db.GetRankTierForRating(rating)
	season, _ := db.GetCurrentSeason()

	jsonResponse(w, 200, map[string]interface{}{
		"rating":  rating,
		"tier":    tier,
		"season":  season,
		"tiers":   db.RankTiers,
		"rewards": db.SeasonRewards,
	})
}

// ─── Inventory ───────────────────────────────────────────

func (s *Server) HandleInventory(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		items, _ := db.GetInventory(userID)
		equipped, _ := db.GetEquipped(userID)
		if items == nil {
			items = []db.OwnedItem{}
		}
		jsonResponse(w, 200, map[string]interface{}{"items": items, "equipped": equipped})

	case "POST":
		// Limit request body size
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			Action   string `json:"action"` // "buy", "equip", "unequip"
			ItemID   string `json:"itemId"`
			Category string `json:"category"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		// Validate action
		req.Action = strings.ToLower(strings.TrimSpace(req.Action))
		validActions := map[string]bool{"buy": true, "equip": true, "unequip": true}
		if !validActions[req.Action] {
			errorResponseWithCode(w, 400, "action must be: buy, equip, or unequip", "INVALID_ACTION")
			return
		}

		// Validate item ID for buy/equip actions
		if req.Action == "buy" || req.Action == "equip" {
			req.ItemID = strings.TrimSpace(req.ItemID)
			if req.ItemID == "" {
				errorResponseWithCode(w, 400, "itemId is required", "MISSING_ITEM_ID")
				return
			}
			if !itemIDRegex.MatchString(req.ItemID) {
				errorResponseWithCode(w, 400, "invalid itemId format", "INVALID_ITEM_ID")
				return
			}
		}

		// Validate category for equip/unequip actions
		if req.Action == "equip" || req.Action == "unequip" {
			req.Category = strings.ToLower(strings.TrimSpace(req.Category))
			if req.Category == "" {
				errorResponseWithCode(w, 400, "category is required", "MISSING_CATEGORY")
				return
			}
			if !categoryRegex.MatchString(req.Category) {
				errorResponseWithCode(w, 400, "category must be: avatar, frame, title, effect, or emote", "INVALID_CATEGORY")
				return
			}
		}

		switch req.Action {
		case "buy":
			if err := db.PurchaseItem(userID, req.ItemID); err != nil {
				errorResponseWithCode(w, 400, err.Error(), "PURCHASE_FAILED")
				return
			}
		case "equip":
			if err := db.EquipItem(userID, req.ItemID, req.Category); err != nil {
				errorResponseWithCode(w, 400, err.Error(), "EQUIP_FAILED")
				return
			}
		case "unequip":
			if err := db.UnequipItem(userID, req.Category); err != nil {
				errorResponseWithCode(w, 400, err.Error(), "UNEQUIP_FAILED")
				return
			}
		}
		jsonResponse(w, 200, map[string]string{"status": "ok"})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// ─── Shop ────────────────────────────────────────────────

func (s *Server) HandleShop(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		// Return all shop items with ownership status
		items, err := db.GetShopItems()
		if err != nil {
			items = []db.ShopItem{}
		}
		
		// Mark owned items
		type ShopItemWithOwned struct {
			db.ShopItem
			Owned bool `json:"owned"`
		}
		result := make([]ShopItemWithOwned, len(items))
		for i, item := range items {
			result[i] = ShopItemWithOwned{
				ShopItem: item,
				Owned:    db.CheckOwnership(userID, item.ID),
			}
		}
		
		// Get user's current coins
		var coins int64
		if db.DB != nil {
			db.DB.QueryRow(`SELECT coins FROM profiles WHERE user_id = $1`, userID).Scan(&coins)
		}
		
		jsonResponse(w, 200, map[string]interface{}{
			"items": result,
			"coins": coins,
		})

	case "POST":
		// Purchase an item
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			ItemID string `json:"itemId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		// Validate item ID
		req.ItemID = strings.TrimSpace(req.ItemID)
		if req.ItemID == "" {
			errorResponseWithCode(w, 400, "itemId is required", "MISSING_ITEM_ID")
			return
		}
		if !itemIDRegex.MatchString(req.ItemID) {
			errorResponseWithCode(w, 400, "invalid itemId format", "INVALID_ITEM_ID")
			return
		}

		// Check if already owned
		if db.CheckOwnership(userID, req.ItemID) {
			errorResponseWithCode(w, 400, "item already owned", "ALREADY_OWNED")
			return
		}

		// Attempt purchase
		if err := db.PurchaseItem(userID, req.ItemID); err != nil {
			if err.Error() == "insufficient coins" {
				errorResponseWithCode(w, 400, "insufficient coins", "INSUFFICIENT_COINS")
			} else {
				errorResponseWithCode(w, 400, err.Error(), "PURCHASE_FAILED")
			}
			return
		}

		// Get updated coins balance
		var coins int64
		if db.DB != nil {
			db.DB.QueryRow(`SELECT coins FROM profiles WHERE user_id = $1`, userID).Scan(&coins)
		}

		jsonResponse(w, 200, map[string]interface{}{
			"status": "purchased",
			"itemId": req.ItemID,
			"coins":  coins,
		})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// ─── Feature Flags ───────────────────────────────────────

func (s *Server) HandleFeatureFlags(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	if db.DB == nil {
		jsonResponse(w, 200, map[string]interface{}{"flags": map[string]bool{}})
		return
	}
	rows, err := db.DB.Query(`SELECT key, enabled FROM feature_flags`)
	if err != nil {
		jsonResponse(w, 200, map[string]interface{}{"flags": map[string]bool{}})
		return
	}
	defer rows.Close()
	flags := make(map[string]bool)
	for rows.Next() {
		var k string
		var v bool
		rows.Scan(&k, &v)
		flags[k] = v
	}
	jsonResponse(w, 200, map[string]interface{}{"flags": flags})
}

// ─── Daily Reward ────────────────────────────────────────

func (s *Server) HandleDailyReward(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		status, err := db.GetDailyRewardStatus(userID)
		if err != nil {
			errorResponse(w, 500, "failed to get reward status")
			return
		}
		jsonResponse(w, 200, status)

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

func (s *Server) HandleDailyRewardClaim(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(userIDKey).(string)

	result, err := db.ClaimDailyReward(userID)
	if err != nil {
		if err.Error() == "already claimed today" {
			errorResponseWithCode(w, 400, "Sudah diklaim hari ini", "ALREADY_CLAIMED")
			return
		}
		errorResponse(w, 500, "failed to claim reward")
		return
	}
	jsonResponse(w, 200, result)
}

// ─── Daily Missions ──────────────────────────────────────

func (s *Server) HandleMissions(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		// Get daily missions for user
		missions, err := db.GetDailyMissions(userID)
		if err != nil {
			missions = []db.DailyMission{}
		}
		jsonResponse(w, 200, map[string]interface{}{"missions": missions})

	case "POST":
		// Claim mission reward
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			MissionID string `json:"missionId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		req.MissionID = strings.TrimSpace(req.MissionID)
		if req.MissionID == "" {
			errorResponseWithCode(w, 400, "missionId is required", "MISSING_MISSION_ID")
			return
		}

		mission, err := db.ClaimMissionReward(userID, req.MissionID)
		if err != nil {
			errorResponseWithCode(w, 400, err.Error(), "CLAIM_FAILED")
			return
		}

		jsonResponse(w, 200, map[string]interface{}{
			"status":   "claimed",
			"mission":  mission,
			"xpEarned": mission.XPReward,
			"coins":    mission.CoinReward,
		})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// ─── Notifications ───────────────────────────────────────

func (s *Server) HandleNotifications(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(string)

	switch r.Method {
	case "GET":
		// Get notifications
		limitStr := r.URL.Query().Get("limit")
		limit, _ := strconv.Atoi(limitStr)
		if limit <= 0 {
			limit = 50
		}
		unreadOnly := r.URL.Query().Get("unread") == "true"

		notifications, err := db.GetNotifications(userID, limit, unreadOnly)
		if err != nil {
			notifications = []db.Notification{}
		}
		
		unreadCount, _ := db.GetUnreadCount(userID)

		jsonResponse(w, 200, map[string]interface{}{
			"notifications": notifications,
			"unreadCount":   unreadCount,
		})

	case "POST":
		// Mark notifications as read
		r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		
		var req struct {
			Action         string `json:"action"` // "read", "read_all", "delete"
			NotificationID string `json:"notificationId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
			return
		}

		req.Action = strings.ToLower(strings.TrimSpace(req.Action))
		
		switch req.Action {
		case "read":
			if req.NotificationID == "" {
				errorResponseWithCode(w, 400, "notificationId required", "MISSING_ID")
				return
			}
			if err := db.MarkNotificationRead(userID, req.NotificationID); err != nil {
				errorResponseWithCode(w, 500, "failed to mark as read", "MARK_FAILED")
				return
			}
		case "read_all":
			if err := db.MarkAllNotificationsRead(userID); err != nil {
				errorResponseWithCode(w, 500, "failed to mark all as read", "MARK_FAILED")
				return
			}
		case "delete":
			if req.NotificationID == "" {
				errorResponseWithCode(w, 400, "notificationId required", "MISSING_ID")
				return
			}
			if err := db.DeleteNotification(userID, req.NotificationID); err != nil {
				errorResponseWithCode(w, 500, "failed to delete", "DELETE_FAILED")
				return
			}
		default:
			errorResponseWithCode(w, 400, "action must be: read, read_all, or delete", "INVALID_ACTION")
			return
		}

		jsonResponse(w, 200, map[string]string{"status": "ok"})

	default:
		errorResponse(w, 405, "method not allowed")
	}
}

// ─── Quests (wraps missions for QuestPage FE) ────────────

// HandleQuests serves GET /api/quests — returns daily + weekly quests.
// P0-1 FIX: QuestPage calls /api/quests which previously had no handler.
// This wraps existing daily missions and returns them in the format
// the Flutter QuestPage expects: { daily: [...], weekly: [...] }
func (s *Server) HandleQuests(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	missions, err := db.GetDailyMissions(userID)
	if err != nil {
		missions = []db.DailyMission{}
	}

	// Transform missions into the quest format the FE expects
	daily := make([]map[string]interface{}, 0, len(missions))
	for _, m := range missions {
		daily = append(daily, map[string]interface{}{
			"id":             m.ID,
			"title":          m.Title,
			"description":    m.Description,
			"progress":       m.Progress,
			"target":         m.Target,
			"claimed":        m.IsClaimed,
			"completed":      m.IsCompleted,
			"rewardCoins":    m.CoinReward,
			"rewardXp":       m.XPReward,
			"rewardDiamonds": 0,
		})
	}

	// Weekly quests — placeholder for future implementation
	weekly := []map[string]interface{}{}

	jsonResponse(w, 200, map[string]interface{}{
		"daily":  daily,
		"weekly": weekly,
	})
}

// HandleClaimQuest serves POST /api/quests/claim — claims a quest reward.
// P0-1 FIX: Wraps existing ClaimMissionReward for the quest endpoint.
func (s *Server) HandleClaimQuest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	userID := r.Context().Value(userIDKey).(string)

	r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
	var req struct {
		QuestID string `json:"questId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponseWithCode(w, 400, "invalid request body", "INVALID_BODY")
		return
	}

	req.QuestID = strings.TrimSpace(req.QuestID)
	if req.QuestID == "" {
		errorResponseWithCode(w, 400, "questId is required", "MISSING_QUEST_ID")
		return
	}

	mission, err := db.ClaimMissionReward(userID, req.QuestID)
	if err != nil {
		errorResponseWithCode(w, 400, err.Error(), "CLAIM_FAILED")
		return
	}

	jsonResponse(w, 200, map[string]interface{}{
		"status":   "claimed",
		"xpEarned": mission.XPReward,
		"coins":    mission.CoinReward,
	})
}
