package security

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"sync"
	"time"
)

// CSRFTokenStore stores valid CSRF tokens with expiration
type CSRFTokenStore struct {
	mu     sync.RWMutex
	tokens map[string]time.Time
	ttl    time.Duration
}

// NewCSRFTokenStore creates a new CSRF token store
func NewCSRFTokenStore(ttl time.Duration) *CSRFTokenStore {
	store := &CSRFTokenStore{
		tokens: make(map[string]time.Time),
		ttl:    ttl,
	}
	
	// Start cleanup goroutine
	go store.cleanup()
	
	return store
}

// GenerateToken creates a new CSRF token
func (s *CSRFTokenStore) GenerateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	
	token := base64.URLEncoding.EncodeToString(b)
	
	s.mu.Lock()
	s.tokens[token] = time.Now().Add(s.ttl)
	s.mu.Unlock()
	
	return token, nil
}

// ValidateToken checks if a CSRF token is valid
func (s *CSRFTokenStore) ValidateToken(token string) bool {
	s.mu.RLock()
	expiry, exists := s.tokens[token]
	s.mu.RUnlock()
	
	if !exists {
		return false
	}
	
	if time.Now().After(expiry) {
		s.mu.Lock()
		delete(s.tokens, token)
		s.mu.Unlock()
		return false
	}
	
	return true
}

// InvalidateToken removes a CSRF token (single use)
func (s *CSRFTokenStore) InvalidateToken(token string) {
	s.mu.Lock()
	delete(s.tokens, token)
	s.mu.Unlock()
}

// cleanup removes expired tokens periodically
func (s *CSRFTokenStore) cleanup() {
	ticker := time.NewTicker(time.Minute * 5)
	for range ticker.C {
		s.mu.Lock()
		now := time.Now()
		for token, expiry := range s.tokens {
			if now.After(expiry) {
				delete(s.tokens, token)
			}
		}
		s.mu.Unlock()
	}
}

// HashPassword creates a secure hash for comparison (not for storage - use bcrypt for that)
func HashForComparison(data string) string {
	hash := sha256.Sum256([]byte(data))
	return fmt.Sprintf("%x", hash)
}

// GenerateSecureRandom generates a cryptographically secure random string
func GenerateSecureRandom(length int) (string, error) {
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b)[:length], nil
}
