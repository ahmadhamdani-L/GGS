package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	
	"github.com/ggs/werewolf-server/internal/db"
)

func init() {
	// Initialize in-memory store for tests
	db.InitMemoryStore()
}

func TestHealthHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/api/health", nil)
	if err != nil {
		t.Fatal(err)
	}
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(HealthHandler)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("HealthHandler returned wrong status: got %d, want %d", status, http.StatusOK)
	}
	
	var response map[string]interface{}
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	
	if response["status"] != "ok" {
		t.Errorf("HealthHandler status = %v, want ok", response["status"])
	}
	
	if response["service"] != "ggs-werewolf-server" {
		t.Errorf("HealthHandler service = %v, want ggs-werewolf-server", response["service"])
	}
}

func TestValidateEmail(t *testing.T) {
	tests := []struct {
		email    string
		expected bool
	}{
		{"test@example.com", true},
		{"user.name@domain.co", true},
		{"user+tag@example.org", true},
		{"", false},
		{"invalid", false},
		{"@nodomain.com", false},
		{"noat.com", false},
		{"spaces in@email.com", false},
	}
	
	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			result := validateEmail(tt.email)
			if result != tt.expected {
				t.Errorf("validateEmail(%q) = %v, want %v", tt.email, result, tt.expected)
			}
		})
	}
}

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		password string
		valid    bool
	}{
		{"Password1", true},
		{"StrongP@ss123", true},
		{"ABCdef123", true},
		{"short", false},          // too short
		{"nouppercase1", false},   // no uppercase
		{"NOLOWERCASE1", false},   // no lowercase
		{"NoDigitsHere", false},   // no digit
		{"", false},               // empty
	}
	
	for _, tt := range tests {
		t.Run(tt.password, func(t *testing.T) {
			valid, _ := validatePassword(tt.password)
			if valid != tt.valid {
				t.Errorf("validatePassword(%q) = %v, want %v", tt.password, valid, tt.valid)
			}
		})
	}
}

func TestValidateDisplayName(t *testing.T) {
	tests := []struct {
		name  string
		valid bool
	}{
		{"Player1", true},
		{"Cool Name", true},
		{"user_123", true},
		{"player-one", true},
		{"AB", true},           // minimum 2 chars
		{"A", false},           // too short
		{"", false},            // empty
		{"This name is way too long to be valid", false},
		{"<script>", false},    // invalid chars
		{"player@123", false},  // @ not allowed
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			valid, _ := validateDisplayName(tt.name)
			if valid != tt.valid {
				t.Errorf("validateDisplayName(%q) = %v, want %v", tt.name, valid, tt.valid)
			}
		})
	}
}

func TestValidateUUID(t *testing.T) {
	tests := []struct {
		id       string
		expected bool
	}{
		{"550e8400-e29b-41d4-a716-446655440000", true},
		{"123e4567-e89b-12d3-a456-426614174000", true},
		{"invalid-uuid", false},
		{"550e8400e29b41d4a716446655440000", false}, // no dashes
		{"", false},
	}
	
	for _, tt := range tests {
		t.Run(tt.id, func(t *testing.T) {
			result := validateUUID(tt.id)
			if result != tt.expected {
				t.Errorf("validateUUID(%q) = %v, want %v", tt.id, result, tt.expected)
			}
		})
	}
}

func TestValidateLimit(t *testing.T) {
	tests := []struct {
		limit      int
		defaultVal int
		maxVal     int
		expected   int
	}{
		{10, 20, 100, 10},   // valid limit
		{0, 20, 100, 20},    // zero returns default
		{-5, 20, 100, 20},   // negative returns default
		{150, 20, 100, 100}, // over max returns max
		{100, 20, 100, 100}, // exactly max
	}
	
	for _, tt := range tests {
		result := validateLimit(tt.limit, tt.defaultVal, tt.maxVal)
		if result != tt.expected {
			t.Errorf("validateLimit(%d, %d, %d) = %d, want %d",
				tt.limit, tt.defaultVal, tt.maxVal, result, tt.expected)
		}
	}
}

func TestHandleRegister(t *testing.T) {
	server := NewServer()
	
	body := map[string]string{
		"email":       "test@example.com",
		"password":    "Password123",
		"displayName": "TestUser",
	}
	bodyBytes, _ := json.Marshal(body)
	
	req, err := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(bodyBytes))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(server.HandleRegister)
	
	handler.ServeHTTP(rr, req)
	
	if status := rr.Code; status != http.StatusCreated {
		t.Errorf("HandleRegister returned wrong status: got %d, want %d. Body: %s",
			status, http.StatusCreated, rr.Body.String())
	}
	
	var response map[string]interface{}
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	
	if response["token"] == nil || response["token"] == "" {
		t.Error("HandleRegister should return a token")
	}
	
	if response["accessToken"] == nil || response["accessToken"] == "" {
		t.Error("HandleRegister should return an accessToken")
	}
	
	if response["refreshToken"] == nil || response["refreshToken"] == "" {
		t.Error("HandleRegister should return a refreshToken")
	}
}

func TestHandleRegister_InvalidEmail(t *testing.T) {
	server := NewServer()
	
	body := map[string]string{
		"email":       "invalid-email",
		"password":    "Password123",
		"displayName": "TestUser",
	}
	bodyBytes, _ := json.Marshal(body)
	
	req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	server.HandleRegister(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("HandleRegister with invalid email should return 400, got %d", status)
	}
}

func TestHandleRegister_WeakPassword(t *testing.T) {
	server := NewServer()
	
	body := map[string]string{
		"email":       "weak@example.com",
		"password":    "weak",
		"displayName": "TestUser",
	}
	bodyBytes, _ := json.Marshal(body)
	
	req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	server.HandleRegister(rr, req)
	
	if status := rr.Code; status != http.StatusBadRequest {
		t.Errorf("HandleRegister with weak password should return 400, got %d", status)
	}
}

func TestHandleRegister_MethodNotAllowed(t *testing.T) {
	server := NewServer()
	
	req, _ := http.NewRequest("GET", "/api/auth/register", nil)
	
	rr := httptest.NewRecorder()
	server.HandleRegister(rr, req)
	
	if status := rr.Code; status != http.StatusMethodNotAllowed {
		t.Errorf("HandleRegister GET should return 405, got %d", status)
	}
}

func TestHandleLogin_InvalidCredentials(t *testing.T) {
	server := NewServer()
	
	body := map[string]string{
		"email":    "nonexistent@example.com",
		"password": "WrongPassword1",
	}
	bodyBytes, _ := json.Marshal(body)
	
	req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	server.HandleLogin(rr, req)
	
	if status := rr.Code; status != http.StatusUnauthorized {
		t.Errorf("HandleLogin with wrong credentials should return 401, got %d", status)
	}
}

func TestHandleGuest(t *testing.T) {
	server := NewServer()
	
	body := map[string]string{
		"displayName": "GuestPlayer",
	}
	bodyBytes, _ := json.Marshal(body)
	
	req, _ := http.NewRequest("POST", "/api/auth/guest", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	
	rr := httptest.NewRecorder()
	server.HandleGuest(rr, req)
	
	if status := rr.Code; status != http.StatusCreated {
		t.Errorf("HandleGuest returned wrong status: got %d, want %d. Body: %s",
			status, http.StatusCreated, rr.Body.String())
	}
	
	var response map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &response)
	
	if response["token"] == nil {
		t.Error("HandleGuest should return a token")
	}
}

func TestHandleLeaderboard(t *testing.T) {
	server := NewServer()
	
	req, _ := http.NewRequest("GET", "/api/leaderboard?sort=rating&limit=10", nil)
	
	rr := httptest.NewRecorder()
	server.HandleLeaderboard(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("HandleLeaderboard returned wrong status: got %d, want %d", status, http.StatusOK)
	}
	
	var response map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &response)
	
	if response["leaderboard"] == nil {
		t.Error("HandleLeaderboard should return leaderboard array")
	}
}

func TestHandleLeaderboard_InvalidSort(t *testing.T) {
	server := NewServer()
	
	// Invalid sort parameter should default to "rating"
	req, _ := http.NewRequest("GET", "/api/leaderboard?sort=invalid", nil)
	
	rr := httptest.NewRecorder()
	server.HandleLeaderboard(rr, req)
	
	// Should still succeed with default sort
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("HandleLeaderboard with invalid sort should still succeed, got %d", status)
	}
}

func TestSanitizeString(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"normal text", "normal text"},
		{"  trimmed  ", "trimmed"},
		{"<script>alert('xss')</script>", "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"},
		{"Hello & World", "Hello &amp; World"},
		{"\"quoted\"", "&#34;quoted&#34;"},
	}
	
	for _, tt := range tests {
		result := sanitizeString(tt.input)
		if result != tt.expected {
			t.Errorf("sanitizeString(%q) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}
