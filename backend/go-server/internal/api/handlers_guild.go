package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/ggs/werewolf-server/internal/db"
)

// HandleCreateGuild handles POST /api/guilds
func (s *Server) HandleCreateGuild(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(userIDKey).(string)
	if !ok || userID == "" {
		errorResponse(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req struct {
		Name        string `json:"name"`
		Tag         string `json:"tag"`
		Description string `json:"description"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, http.StatusBadRequest, "Invalid request format")
		return
	}

	if len(req.Name) < 3 || len(req.Name) > 20 {
		errorResponse(w, http.StatusBadRequest, "Nama guild harus 3-20 karakter")
		return
	}
	if len(req.Tag) < 2 || len(req.Tag) > 6 {
		errorResponse(w, http.StatusBadRequest, "Tag guild harus 2-6 karakter")
		return
	}

	guild, err := db.CreateGuild(userID, req.Name, req.Tag, req.Description)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, guild)
}

// HandleGetGuild handles GET /api/guilds/{id}
func (s *Server) HandleGetGuild(w http.ResponseWriter, r *http.Request) {
	guildID := r.PathValue("id")
	if guildID == "" {
		errorResponse(w, http.StatusBadRequest, "Missing guild ID")
		return
	}

	guild, err := db.GetGuild(guildID)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to get guild")
		return
	}
	if guild == nil || guild.ID == "" {
		errorResponse(w, http.StatusNotFound, "Guild not found")
		return
	}

	jsonResponse(w, http.StatusOK, guild)
}

// HandleJoinGuild handles POST /api/guilds/{id}/join
func (s *Server) HandleJoinGuild(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(userIDKey).(string)
	if !ok || userID == "" {
		errorResponse(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	guildID := r.PathValue("id")
	if guildID == "" {
		errorResponse(w, http.StatusBadRequest, "Missing guild ID")
		return
	}

	err := db.JoinGuild(userID, guildID)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate profile cache
	s.Hub.InvalidateProfileCache(userID)

	jsonResponse(w, http.StatusOK, map[string]bool{"success": true})
}

// HandleLeaveGuild handles POST /api/guilds/leave
func (s *Server) HandleLeaveGuild(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(userIDKey).(string)
	if !ok || userID == "" {
		errorResponse(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	err := db.LeaveGuild(userID)
	if err != nil {
		errorResponse(w, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate profile cache
	s.Hub.InvalidateProfileCache(userID)

	jsonResponse(w, http.StatusOK, map[string]bool{"success": true})
}

// HandleSearchGuilds handles GET /api/guilds/search
func (s *Server) HandleSearchGuilds(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	limitStr := r.URL.Query().Get("limit")
	limit := 50
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	guilds, err := db.SearchGuilds(query, limit)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to search guilds")
		return
	}
	if guilds == nil {
		guilds = []db.Guild{}
	}

	jsonResponse(w, http.StatusOK, guilds)
}

// HandleGetGuildMembers handles GET /api/guilds/{id}/members
func (s *Server) HandleGetGuildMembers(w http.ResponseWriter, r *http.Request) {
	guildID := r.PathValue("id")
	if guildID == "" {
		errorResponse(w, http.StatusBadRequest, "Missing guild ID")
		return
	}

	members, err := db.GetGuildMembers(guildID)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to get members")
		return
	}
	if members == nil {
		members = []db.GuildMember{}
	}

	jsonResponse(w, http.StatusOK, members)
}

// HandleGetGuildChat handles GET /api/guilds/{id}/chat
func (s *Server) HandleGetGuildChat(w http.ResponseWriter, r *http.Request) {
	guildID := r.PathValue("id")
	if guildID == "" {
		errorResponse(w, http.StatusBadRequest, "Missing guild ID")
		return
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 50
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
		limit = l
	}

	msgs, err := db.GetGuildChat(guildID, limit)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to get chat")
		return
	}
	if msgs == nil {
		msgs = []map[string]interface{}{}
	}

	jsonResponse(w, http.StatusOK, msgs)
}

// HandleSendGuildChat handles POST /api/guilds/{id}/chat
func (s *Server) HandleSendGuildChat(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(userIDKey).(string)
	if !ok || userID == "" {
		errorResponse(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	guildID := r.PathValue("id")
	if guildID == "" {
		errorResponse(w, http.StatusBadRequest, "Missing guild ID")
		return
	}

	var req struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		errorResponse(w, http.StatusBadRequest, "Invalid request format")
		return
	}
	if req.Content == "" {
		errorResponse(w, http.StatusBadRequest, "Content empty")
		return
	}

	// Fetch sender name
	profile, err := db.GetProfile(userID)
	senderName := "Unknown"
	if err == nil && profile != nil {
		senderName = profile.DisplayName
	}

	err = db.SendGuildChat(guildID, userID, senderName, req.Content)
	if err != nil {
		errorResponse(w, http.StatusInternalServerError, "Failed to send chat")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]bool{"success": true})
}
