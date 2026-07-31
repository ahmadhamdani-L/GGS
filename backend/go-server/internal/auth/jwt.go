package auth

import (
	"crypto/rand"
	"encoding/base64"
	"errors"
	"log"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var jwtSecret []byte
var refreshSecret []byte

// Token durations
const (
	AccessTokenDuration  = 15 * time.Minute  // Short-lived access token
	RefreshTokenDuration = 7 * 24 * time.Hour // 7 days refresh token
)

// RefreshTokenStore stores valid refresh tokens with metadata
type RefreshTokenStore struct {
	mu     sync.RWMutex
	tokens map[string]*RefreshTokenData
}

type RefreshTokenData struct {
	UserID    string
	ExpiresAt time.Time
	IssuedAt  time.Time
	Revoked   bool
}

var refreshStore = &RefreshTokenStore{
	tokens: make(map[string]*RefreshTokenData),
}

func init() {
	// Load JWT secret from environment variable
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		// In development, generate a random secret and warn
		log.Println("⚠ WARNING: JWT_SECRET not set, generating random secret (sessions will not persist across restarts)")
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			log.Fatal("Failed to generate random JWT secret")
		}
		secret = base64.StdEncoding.EncodeToString(b)
	}
	if len(secret) < 32 {
		log.Fatal("JWT_SECRET must be at least 32 characters")
	}
	jwtSecret = []byte(secret)

	// Separate secret for refresh tokens
	refreshSecretEnv := os.Getenv("JWT_REFRESH_SECRET")
	if refreshSecretEnv == "" {
		refreshSecretEnv = secret + "_refresh"
	}
	refreshSecret = []byte(refreshSecretEnv)

	// Start cleanup goroutine for expired refresh tokens
	go refreshStore.cleanup()
}

type Claims struct {
	UserID    string `json:"userId"`
	TokenType string `json:"type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

// TokenPair contains both access and refresh tokens
type TokenPair struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int64  `json:"expiresIn"` // seconds until access token expires
}

// GenerateTokenPair creates both access and refresh tokens
func GenerateTokenPair(userID string) (*TokenPair, error) {
	accessToken, err := generateAccessToken(userID)
	if err != nil {
		return nil, err
	}

	refreshToken, err := generateRefreshToken(userID)
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(AccessTokenDuration.Seconds()),
	}, nil
}

// generateAccessToken creates a short-lived JWT access token
func generateAccessToken(userID string) (string, error) {
	claims := &Claims{
		UserID:    userID,
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(AccessTokenDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "ggs-werewolf",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// generateRefreshToken creates a long-lived refresh token
func generateRefreshToken(userID string) (string, error) {
	// Generate a random token ID
	tokenID := make([]byte, 32)
	if _, err := rand.Read(tokenID); err != nil {
		return "", err
	}
	tokenIDStr := base64.URLEncoding.EncodeToString(tokenID)

	claims := &Claims{
		UserID:    userID,
		TokenType: "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        tokenIDStr,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(RefreshTokenDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "ggs-werewolf",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedToken, err := token.SignedString(refreshSecret)
	if err != nil {
		return "", err
	}

	// Store refresh token metadata
	refreshStore.mu.Lock()
	refreshStore.tokens[tokenIDStr] = &RefreshTokenData{
		UserID:    userID,
		ExpiresAt: time.Now().Add(RefreshTokenDuration),
		IssuedAt:  time.Now(),
		Revoked:   false,
	}
	refreshStore.mu.Unlock()

	return signedToken, nil
}

// GenerateToken creates a JWT token for a user (backward compatible - returns access token)
func GenerateToken(userID string) (string, error) {
	return generateAccessToken(userID)
}

// ValidateToken validates a JWT token and returns user ID
func ValidateToken(tokenString string) (string, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return jwtSecret, nil
	})

	if err != nil {
		return "", err
	}

	if !token.Valid {
		return "", errors.New("invalid token")
	}

	// For access tokens, just return user ID
	if claims.TokenType == "" || claims.TokenType == "access" {
		return claims.UserID, nil
	}

	return "", errors.New("invalid token type")
}

// ValidateRefreshToken validates a refresh token and returns user ID
func ValidateRefreshToken(tokenString string) (string, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return refreshSecret, nil
	})

	if err != nil {
		return "", err
	}

	if !token.Valid {
		return "", errors.New("invalid token")
	}

	if claims.TokenType != "refresh" {
		return "", errors.New("not a refresh token")
	}

	// Check if token is revoked
	refreshStore.mu.RLock()
	data, exists := refreshStore.tokens[claims.ID]
	refreshStore.mu.RUnlock()

	if !exists {
		return "", errors.New("refresh token not found")
	}

	if data.Revoked {
		return "", errors.New("refresh token has been revoked")
	}

	if time.Now().After(data.ExpiresAt) {
		return "", errors.New("refresh token expired")
	}

	return claims.UserID, nil
}

// RefreshAccessToken creates a new access token from a valid refresh token
func RefreshAccessToken(refreshTokenString string) (*TokenPair, error) {
	userID, err := ValidateRefreshToken(refreshTokenString)
	if err != nil {
		return nil, err
	}

	// Generate new token pair (rotate refresh token for security)
	newPair, err := GenerateTokenPair(userID)
	if err != nil {
		return nil, err
	}

	// Revoke old refresh token
	claims := &Claims{}
	jwt.ParseWithClaims(refreshTokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return refreshSecret, nil
	})
	if claims.ID != "" {
		RevokeRefreshToken(claims.ID)
	}

	return newPair, nil
}

// RevokeRefreshToken invalidates a refresh token
func RevokeRefreshToken(tokenID string) {
	refreshStore.mu.Lock()
	if data, exists := refreshStore.tokens[tokenID]; exists {
		data.Revoked = true
	}
	refreshStore.mu.Unlock()
}

// RevokeAllUserTokens invalidates all refresh tokens for a user (logout from all devices)
func RevokeAllUserTokens(userID string) {
	refreshStore.mu.Lock()
	for _, data := range refreshStore.tokens {
		if data.UserID == userID {
			data.Revoked = true
		}
	}
	refreshStore.mu.Unlock()
}

// cleanup removes expired refresh tokens periodically
func (s *RefreshTokenStore) cleanup() {
	ticker := time.NewTicker(time.Hour)
	for range ticker.C {
		s.mu.Lock()
		now := time.Now()
		for id, data := range s.tokens {
			if now.After(data.ExpiresAt) || data.Revoked {
				delete(s.tokens, id)
			}
		}
		s.mu.Unlock()
	}
}

// GetActiveSessionCount returns the number of active sessions for a user
func GetActiveSessionCount(userID string) int {
	refreshStore.mu.RLock()
	defer refreshStore.mu.RUnlock()
	
	count := 0
	now := time.Now()
	for _, data := range refreshStore.tokens {
		if data.UserID == userID && !data.Revoked && now.Before(data.ExpiresAt) {
			count++
		}
	}
	return count
}
