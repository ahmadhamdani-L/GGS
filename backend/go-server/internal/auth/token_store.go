package auth

import (
	"database/sql"
	"log"
	"sync"
	"time"
)

// DB is set by the main package after db.Connect() succeeds.
// If nil, falls back to in-memory store (dev mode only).
var DB *sql.DB

// SetDB configures the database connection for persistent token storage.
// Call this from main.go after db.Connect() succeeds.
func SetDB(database *sql.DB) {
	DB = database
	if DB != nil {
		log.Println("✅ Refresh token store: PostgreSQL (persistent)")
	} else {
		log.Println("⚠ Refresh token store: in-memory (dev mode — tokens lost on restart)")
	}
}

// ─── DB-backed operations ────────────────────────────────────

// storeRefreshToken persists a refresh token to PostgreSQL (or in-memory fallback).
func storeRefreshToken(tokenID, userID string, expiresAt, issuedAt time.Time) {
	if DB != nil {
		_, err := DB.Exec(`
			INSERT INTO refresh_tokens (id, user_id, expires_at, issued_at, revoked)
			VALUES ($1, $2, $3, $4, false)
			ON CONFLICT (id) DO NOTHING
		`, tokenID, userID, expiresAt, issuedAt)
		if err != nil {
			log.Printf("[AUTH] Failed to store refresh token in DB: %v (falling back to memory)", err)
			// Fallback to memory
			storeRefreshTokenMemory(tokenID, userID, expiresAt, issuedAt)
		}
		return
	}
	storeRefreshTokenMemory(tokenID, userID, expiresAt, issuedAt)
}

// lookupRefreshToken checks if a refresh token is valid (not revoked, not expired).
func lookupRefreshToken(tokenID string) (userID string, valid bool) {
	if DB != nil {
		var uid string
		var revoked bool
		var expiresAt time.Time
		err := DB.QueryRow(`
			SELECT user_id, revoked, expires_at FROM refresh_tokens WHERE id = $1
		`, tokenID).Scan(&uid, &revoked, &expiresAt)
		if err != nil {
			return "", false
		}
		if revoked || time.Now().After(expiresAt) {
			return "", false
		}
		return uid, true
	}
	return lookupRefreshTokenMemory(tokenID)
}

// revokeRefreshTokenByID marks a single refresh token as revoked.
func revokeRefreshTokenByID(tokenID string) {
	if DB != nil {
		DB.Exec(`UPDATE refresh_tokens SET revoked = true WHERE id = $1`, tokenID)
		return
	}
	revokeRefreshTokenMemory(tokenID)
}

// revokeAllUserRefreshTokens revokes all refresh tokens for a user (logout all devices).
func revokeAllUserRefreshTokens(userID string) {
	if DB != nil {
		DB.Exec(`UPDATE refresh_tokens SET revoked = true WHERE user_id = $1`, userID)
		return
	}
	revokeAllUserTokensMemory(userID)
}

// countActiveUserSessions counts non-revoked, non-expired tokens for a user.
func countActiveUserSessions(userID string) int {
	if DB != nil {
		var count int
		DB.QueryRow(`
			SELECT COUNT(*) FROM refresh_tokens 
			WHERE user_id = $1 AND revoked = false AND expires_at > now()
		`, userID).Scan(&count)
		return count
	}
	return countActiveSessionsMemory(userID)
}

// cleanupExpiredTokens removes old tokens from the database.
func cleanupExpiredTokens() {
	if DB != nil {
		result, err := DB.Exec(`DELETE FROM refresh_tokens WHERE expires_at < now() - interval '14 days' OR (revoked = true AND issued_at < now() - interval '1 day')`)
		if err == nil {
			if rows, _ := result.RowsAffected(); rows > 0 {
				log.Printf("[AUTH] Cleaned up %d expired/revoked refresh tokens", rows)
			}
		}
		return
	}
	cleanupExpiredTokensMemory()
}

// ─── In-memory fallback (dev mode) ──────────────────────────

var memStore = struct {
	mu     sync.RWMutex
	tokens map[string]*memToken
}{tokens: make(map[string]*memToken)}

type memToken struct {
	UserID    string
	ExpiresAt time.Time
	Revoked   bool
}

func storeRefreshTokenMemory(tokenID, userID string, expiresAt, issuedAt time.Time) {
	memStore.mu.Lock()
	memStore.tokens[tokenID] = &memToken{UserID: userID, ExpiresAt: expiresAt}
	memStore.mu.Unlock()
}

func lookupRefreshTokenMemory(tokenID string) (string, bool) {
	memStore.mu.RLock()
	t, ok := memStore.tokens[tokenID]
	memStore.mu.RUnlock()
	if !ok || t.Revoked || time.Now().After(t.ExpiresAt) {
		return "", false
	}
	return t.UserID, true
}

func revokeRefreshTokenMemory(tokenID string) {
	memStore.mu.Lock()
	if t, ok := memStore.tokens[tokenID]; ok {
		t.Revoked = true
	}
	memStore.mu.Unlock()
}

func revokeAllUserTokensMemory(userID string) {
	memStore.mu.Lock()
	for _, t := range memStore.tokens {
		if t.UserID == userID {
			t.Revoked = true
		}
	}
	memStore.mu.Unlock()
}

func countActiveSessionsMemory(userID string) int {
	memStore.mu.RLock()
	defer memStore.mu.RUnlock()
	count := 0
	now := time.Now()
	for _, t := range memStore.tokens {
		if t.UserID == userID && !t.Revoked && now.Before(t.ExpiresAt) {
			count++
		}
	}
	return count
}

func cleanupExpiredTokensMemory() {
	memStore.mu.Lock()
	now := time.Now()
	for id, t := range memStore.tokens {
		if now.After(t.ExpiresAt) || t.Revoked {
			delete(memStore.tokens, id)
		}
	}
	memStore.mu.Unlock()
}

// StartTokenCleanup runs periodic cleanup of expired tokens.
func StartTokenCleanup() {
	go func() {
		ticker := time.NewTicker(1 * time.Hour)
		for range ticker.C {
			cleanupExpiredTokens()
		}
	}()
}
