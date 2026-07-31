package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ggs/werewolf-server/internal/db"
)

// Integration tests for complete auth flow

func TestAuthFlow_RegisterLoginRefresh(t *testing.T) {
	// Initialize in-memory store
	db.InitMemoryStore()
	server := NewServer()

	// Step 1: Register new user
	t.Run("1_Register", func(t *testing.T) {
		body := map[string]string{
			"email":       "integration@test.com",
			"password":    "TestPass123",
			"displayName": "IntegrationUser",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleRegister(rr, req)

		if rr.Code != http.StatusCreated {
			t.Fatalf("Register failed: %d - %s", rr.Code, rr.Body.String())
		}

		var resp map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &resp)

		if resp["accessToken"] == nil {
			t.Error("Missing accessToken in register response")
		}
		if resp["refreshToken"] == nil {
			t.Error("Missing refreshToken in register response")
		}
		if resp["expiresIn"] == nil {
			t.Error("Missing expiresIn in register response")
		}
	})

	// Step 2: Login with same credentials
	var accessToken, refreshToken string
	t.Run("2_Login", func(t *testing.T) {
		body := map[string]string{
			"email":    "integration@test.com",
			"password": "TestPass123",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleLogin(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("Login failed: %d - %s", rr.Code, rr.Body.String())
		}

		var resp map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &resp)

		accessToken = resp["accessToken"].(string)
		refreshToken = resp["refreshToken"].(string)

		if accessToken == "" {
			t.Error("Empty accessToken")
		}
		if refreshToken == "" {
			t.Error("Empty refreshToken")
		}
	})

	// Step 3: Access protected endpoint with token
	t.Run("3_AccessProtectedEndpoint", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("Profile access failed: %d - %s", rr.Code, rr.Body.String())
		}
	})

	// Step 4: Refresh token
	var newAccessToken, newRefreshToken string
	t.Run("4_RefreshToken", func(t *testing.T) {
		body := map[string]string{
			"refreshToken": refreshToken,
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/refresh", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleRefresh(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("Refresh failed: %d - %s", rr.Code, rr.Body.String())
		}

		var resp map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &resp)

		newAccessToken = resp["accessToken"].(string)
		newRefreshToken = resp["refreshToken"].(string)

		if newAccessToken == "" {
			t.Error("Empty new accessToken")
		}
		if newRefreshToken == "" {
			t.Error("Empty new refreshToken")
		}
		// Token rotation: new refresh token should be different
		if newRefreshToken == refreshToken {
			t.Error("Refresh token should rotate (be different)")
		}
	})

	// Step 5: Old refresh token should be invalid (rotation)
	t.Run("5_OldRefreshTokenInvalid", func(t *testing.T) {
		body := map[string]string{
			"refreshToken": refreshToken, // old token
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/refresh", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleRefresh(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Errorf("Old refresh token should be rejected: got %d", rr.Code)
		}
	})

	// Step 6: New access token should work
	t.Run("6_NewAccessTokenWorks", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer "+newAccessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("New access token should work: %d", rr.Code)
		}
	})
}

func TestAuthFlow_InvalidCredentials(t *testing.T) {
	db.InitMemoryStore()
	server := NewServer()

	// Register first
	regBody := map[string]string{
		"email":       "invalid@test.com",
		"password":    "ValidPass123",
		"displayName": "TestUser",
	}
	regBytes, _ := json.Marshal(regBody)
	regReq, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(regBytes))
	regReq.Header.Set("Content-Type", "application/json")
	regRR := httptest.NewRecorder()
	server.HandleRegister(regRR, regReq)

	t.Run("WrongPassword", func(t *testing.T) {
		body := map[string]string{
			"email":    "invalid@test.com",
			"password": "WrongPass123",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleLogin(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Errorf("Expected 401 for wrong password, got %d", rr.Code)
		}
	})

	t.Run("NonexistentEmail", func(t *testing.T) {
		body := map[string]string{
			"email":    "nonexistent@test.com",
			"password": "AnyPass123",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleLogin(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Errorf("Expected 401 for nonexistent email, got %d", rr.Code)
		}
	})

	t.Run("InvalidToken", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer invalid-token-here")

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Errorf("Expected 401 for invalid token, got %d", rr.Code)
		}
	})

	t.Run("MissingToken", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Errorf("Expected 401 for missing token, got %d", rr.Code)
		}
	})
}

func TestProfileFlow_UpdateAndRetrieve(t *testing.T) {
	db.InitMemoryStore()
	server := NewServer()

	// Register user
	regBody := map[string]string{
		"email":       "profile@test.com",
		"password":    "TestPass123",
		"displayName": "OriginalName",
	}
	regBytes, _ := json.Marshal(regBody)
	regReq, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(regBytes))
	regReq.Header.Set("Content-Type", "application/json")
	regRR := httptest.NewRecorder()
	server.HandleRegister(regRR, regReq)

	var regResp map[string]interface{}
	json.Unmarshal(regRR.Body.Bytes(), &regResp)
	accessToken := regResp["accessToken"].(string)

	t.Run("GetProfile", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("Get profile failed: %d", rr.Code)
		}

		var profile map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &profile)

		if profile["displayName"] != "OriginalName" {
			t.Errorf("Expected displayName 'OriginalName', got '%v'", profile["displayName"])
		}
	})

	t.Run("UpdateProfile", func(t *testing.T) {
		body := map[string]interface{}{
			"displayName": "UpdatedName",
			"avatarId":    3,
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("PUT", "/api/profile", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("Update profile failed: %d - %s", rr.Code, rr.Body.String())
		}

		var profile map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &profile)

		if profile["displayName"] != "UpdatedName" {
			t.Errorf("Expected displayName 'UpdatedName', got '%v'", profile["displayName"])
		}
	})

	t.Run("VerifyUpdate", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		var profile map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &profile)

		if profile["displayName"] != "UpdatedName" {
			t.Errorf("Profile update not persisted: got '%v'", profile["displayName"])
		}
	})
}

func TestGuestFlow(t *testing.T) {
	db.InitMemoryStore()
	server := NewServer()

	var accessToken string

	t.Run("CreateGuest", func(t *testing.T) {
		body := map[string]string{
			"displayName": "GuestPlayer",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/auth/guest", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")

		rr := httptest.NewRecorder()
		server.HandleGuest(rr, req)

		if rr.Code != http.StatusCreated {
			t.Fatalf("Guest creation failed: %d", rr.Code)
		}

		var resp map[string]interface{}
		json.Unmarshal(rr.Body.Bytes(), &resp)

		accessToken = resp["accessToken"].(string)
		if accessToken == "" {
			t.Error("Missing accessToken for guest")
		}
	})

	t.Run("GuestCanAccessProfile", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/api/profile", nil)
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleProfile)(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("Guest should access profile: %d", rr.Code)
		}
	})
}

func TestSocialFlow_FriendsValidation(t *testing.T) {
	db.InitMemoryStore()
	server := NewServer()

	// Create user
	regBody := map[string]string{
		"email":       "social@test.com",
		"password":    "TestPass123",
		"displayName": "SocialUser",
	}
	regBytes, _ := json.Marshal(regBody)
	regReq, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(regBytes))
	regReq.Header.Set("Content-Type", "application/json")
	regRR := httptest.NewRecorder()
	server.HandleRegister(regRR, regReq)

	var regResp map[string]interface{}
	json.Unmarshal(regRR.Body.Bytes(), &regResp)
	accessToken := regResp["accessToken"].(string)

	t.Run("InvalidFriendId", func(t *testing.T) {
		body := map[string]string{
			"friendId": "not-a-uuid",
			"action":   "add",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/friends", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleFriends)(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("Expected 400 for invalid friendId, got %d", rr.Code)
		}
	})

	t.Run("InvalidAction", func(t *testing.T) {
		body := map[string]string{
			"friendId": "550e8400-e29b-41d4-a716-446655440000",
			"action":   "invalid",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/friends", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleFriends)(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("Expected 400 for invalid action, got %d", rr.Code)
		}
	})
}

func TestReportFlow_Validation(t *testing.T) {
	db.InitMemoryStore()
	server := NewServer()

	// Create user
	regBody := map[string]string{
		"email":       "report@test.com",
		"password":    "TestPass123",
		"displayName": "ReportUser",
	}
	regBytes, _ := json.Marshal(regBody)
	regReq, _ := http.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(regBytes))
	regReq.Header.Set("Content-Type", "application/json")
	regRR := httptest.NewRecorder()
	server.HandleRegister(regRR, regReq)

	var regResp map[string]interface{}
	json.Unmarshal(regRR.Body.Bytes(), &regResp)
	accessToken := regResp["accessToken"].(string)
	userProfile := regResp["profile"].(map[string]interface{})
	userId := userProfile["userId"].(string)

	t.Run("InvalidReason", func(t *testing.T) {
		body := map[string]string{
			"reportedId": "550e8400-e29b-41d4-a716-446655440000",
			"reason":     "invalid-reason",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/report", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleReport)(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("Expected 400 for invalid reason, got %d", rr.Code)
		}
	})

	t.Run("SelfReport", func(t *testing.T) {
		body := map[string]string{
			"reportedId": userId,
			"reason":     "spam",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/report", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleReport)(rr, req)

		if rr.Code != http.StatusBadRequest {
			t.Errorf("Expected 400 for self-report, got %d", rr.Code)
		}
	})

	t.Run("ValidReport", func(t *testing.T) {
		body := map[string]string{
			"reportedId": "550e8400-e29b-41d4-a716-446655440000",
			"reason":     "cheating",
			"details":    "Player was using hacks",
		}
		bodyBytes, _ := json.Marshal(body)

		req, _ := http.NewRequest("POST", "/api/report", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+accessToken)

		rr := httptest.NewRecorder()
		server.AuthMiddleware(server.HandleReport)(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("Valid report should succeed: %d - %s", rr.Code, rr.Body.String())
		}
	})
}
