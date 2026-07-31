package auth

import (
	"testing"
	"time"
)

func TestGenerateToken(t *testing.T) {
	userID := "test-user-123"
	
	token, err := GenerateToken(userID)
	if err != nil {
		t.Fatalf("GenerateToken failed: %v", err)
	}
	
	if token == "" {
		t.Error("GenerateToken returned empty token")
	}
}

func TestValidateToken(t *testing.T) {
	userID := "test-user-456"
	
	token, err := GenerateToken(userID)
	if err != nil {
		t.Fatalf("GenerateToken failed: %v", err)
	}
	
	validatedID, err := ValidateToken(token)
	if err != nil {
		t.Fatalf("ValidateToken failed: %v", err)
	}
	
	if validatedID != userID {
		t.Errorf("ValidateToken returned wrong userID: got %s, want %s", validatedID, userID)
	}
}

func TestValidateToken_InvalidToken(t *testing.T) {
	_, err := ValidateToken("invalid-token")
	if err == nil {
		t.Error("ValidateToken should fail with invalid token")
	}
}

func TestValidateToken_EmptyToken(t *testing.T) {
	_, err := ValidateToken("")
	if err == nil {
		t.Error("ValidateToken should fail with empty token")
	}
}

func TestGenerateTokenPair(t *testing.T) {
	userID := "test-user-789"
	
	pair, err := GenerateTokenPair(userID)
	if err != nil {
		t.Fatalf("GenerateTokenPair failed: %v", err)
	}
	
	if pair.AccessToken == "" {
		t.Error("AccessToken should not be empty")
	}
	
	if pair.RefreshToken == "" {
		t.Error("RefreshToken should not be empty")
	}
	
	if pair.ExpiresIn <= 0 {
		t.Error("ExpiresIn should be positive")
	}
	
	// Verify access token is valid
	validatedID, err := ValidateToken(pair.AccessToken)
	if err != nil {
		t.Fatalf("Access token validation failed: %v", err)
	}
	
	if validatedID != userID {
		t.Errorf("Access token has wrong userID: got %s, want %s", validatedID, userID)
	}
}

func TestRefreshAccessToken(t *testing.T) {
	userID := "test-user-refresh"
	
	// Generate initial token pair
	pair, err := GenerateTokenPair(userID)
	if err != nil {
		t.Fatalf("GenerateTokenPair failed: %v", err)
	}
	
	// Wait a bit to ensure different token
	time.Sleep(10 * time.Millisecond)
	
	// Refresh the token
	newPair, err := RefreshAccessToken(pair.RefreshToken)
	if err != nil {
		t.Fatalf("RefreshAccessToken failed: %v", err)
	}
	
	if newPair.AccessToken == "" {
		t.Error("New access token should not be empty")
	}
	
	if newPair.RefreshToken == "" {
		t.Error("New refresh token should not be empty")
	}
	
	// Old refresh token should be revoked (rotation)
	_, err = RefreshAccessToken(pair.RefreshToken)
	if err == nil {
		t.Error("Old refresh token should be revoked after rotation")
	}
	
	// New refresh token should work
	_, err = RefreshAccessToken(newPair.RefreshToken)
	if err != nil {
		t.Errorf("New refresh token should be valid: %v", err)
	}
}

func TestRefreshAccessToken_InvalidToken(t *testing.T) {
	_, err := RefreshAccessToken("invalid-refresh-token")
	if err == nil {
		t.Error("RefreshAccessToken should fail with invalid token")
	}
}

func TestRevokeAllUserTokens(t *testing.T) {
	userID := "test-user-revoke"
	
	// Generate multiple token pairs
	pair1, _ := GenerateTokenPair(userID)
	pair2, _ := GenerateTokenPair(userID)
	
	// Revoke all tokens for user
	RevokeAllUserTokens(userID)
	
	// Both refresh tokens should be invalid
	_, err := RefreshAccessToken(pair1.RefreshToken)
	if err == nil {
		t.Error("pair1 refresh token should be revoked")
	}
	
	_, err = RefreshAccessToken(pair2.RefreshToken)
	if err == nil {
		t.Error("pair2 refresh token should be revoked")
	}
}

func TestValidateRefreshToken(t *testing.T) {
	userID := "test-user-validate-refresh"
	
	pair, err := GenerateTokenPair(userID)
	if err != nil {
		t.Fatalf("GenerateTokenPair failed: %v", err)
	}
	
	validatedID, err := ValidateRefreshToken(pair.RefreshToken)
	if err != nil {
		t.Fatalf("ValidateRefreshToken failed: %v", err)
	}
	
	if validatedID != userID {
		t.Errorf("ValidateRefreshToken returned wrong userID: got %s, want %s", validatedID, userID)
	}
}
