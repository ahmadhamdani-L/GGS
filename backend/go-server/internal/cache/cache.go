// Package cache provides a unified caching/shared-state interface
// that can be backed by in-memory (single instance) or Redis (multi-instance).
//
// SCALING ARCHITECTURE:
//
//   Single Instance (current):
//     [Client] → [Go Server (memory cache)] → [PostgreSQL]
//
//   Multi Instance (future with Redis):
//     [Client] → [Load Balancer] → [Go Server N] → [Redis (shared state)] → [PostgreSQL]
//
// Components that need shared state for horizontal scaling:
//   1. Rate Limiting     — currently in-memory tokenBucket per instance
//   2. Refresh Tokens    — DONE: moved to PostgreSQL (migration 015)
//   3. Game Rooms/State  — requires sticky sessions OR Redis pub/sub
//   4. WebSocket Routing — requires Redis pub/sub for cross-instance broadcasts
//   5. Profile Cache     — currently sync.Map per instance (acceptable with TTL)
//
// MIGRATION PATH TO MULTI-INSTANCE:
//   Phase 1 (current): Single instance, all in-memory. PostgreSQL for persistence.
//   Phase 2: Add Redis for rate limiting + session cache. Deploy 2 instances behind LB.
//   Phase 3: Redis pub/sub for WebSocket cross-instance game state broadcasts.
//   Phase 4: Separate game-server instances with dedicated room assignment.
//
package cache

import (
	"log"
	"os"
	"sync"
	"time"
)

// Store is the unified cache interface.
// Implementations: MemoryStore (default), RedisStore (future).
type Store interface {
	// Get retrieves a value by key. Returns ("", false) if not found/expired.
	Get(key string) (string, bool)
	// Set stores a value with TTL. ttl=0 means no expiry.
	Set(key string, value string, ttl time.Duration) error
	// Incr atomically increments a counter and returns new value.
	Incr(key string, ttl time.Duration) (int64, error)
	// Del removes a key.
	Del(key string) error
	// Type returns "memory" or "redis".
	Type() string
}

// Global cache instance
var Global Store

// Init initializes the global cache store.
// Uses Redis if REDIS_URL env is set, otherwise falls back to in-memory.
func Init() {
	redisURL := os.Getenv("REDIS_URL")
	if redisURL != "" {
		store, err := NewRedisStore(redisURL)
		if err != nil {
			log.Printf("⚠ Redis connection failed: %v — falling back to memory store", err)
			Global = NewMemoryStore()
		} else {
			Global = store
		}
	} else {
		Global = NewMemoryStore()
		log.Println("ℹ Cache: in-memory (single instance mode). Set REDIS_URL for multi-instance scaling.")
	}
}

// ─── In-Memory Store ─────────────────────────────────────────

type MemoryStore struct {
	mu    sync.RWMutex
	items map[string]*cacheItem
}

type cacheItem struct {
	value     string
	expiresAt time.Time
	hasExpiry bool
}

func NewMemoryStore() *MemoryStore {
	ms := &MemoryStore{items: make(map[string]*cacheItem)}
	// Background cleanup every 2 minutes
	go func() {
		ticker := time.NewTicker(2 * time.Minute)
		for range ticker.C {
			ms.cleanup()
		}
	}()
	return ms
}

func (m *MemoryStore) Get(key string) (string, bool) {
	m.mu.RLock()
	item, ok := m.items[key]
	m.mu.RUnlock()
	if !ok {
		return "", false
	}
	if item.hasExpiry && time.Now().After(item.expiresAt) {
		m.Del(key)
		return "", false
	}
	return item.value, true
}

func (m *MemoryStore) Set(key string, value string, ttl time.Duration) error {
	m.mu.Lock()
	item := &cacheItem{value: value}
	if ttl > 0 {
		item.expiresAt = time.Now().Add(ttl)
		item.hasExpiry = true
	}
	m.items[key] = item
	m.mu.Unlock()
	return nil
}

func (m *MemoryStore) Incr(key string, ttl time.Duration) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	item, ok := m.items[key]
	if !ok || (item.hasExpiry && time.Now().After(item.expiresAt)) {
		// Create new counter
		m.items[key] = &cacheItem{
			value:     "1",
			expiresAt: time.Now().Add(ttl),
			hasExpiry: ttl > 0,
		}
		return 1, nil
	}

	// Parse and increment
	var count int64
	for _, c := range item.value {
		count = count*10 + int64(c-'0')
	}
	count++
	item.value = intToStr(count)
	return count, nil
}

func (m *MemoryStore) Del(key string) error {
	m.mu.Lock()
	delete(m.items, key)
	m.mu.Unlock()
	return nil
}

func (m *MemoryStore) Type() string { return "memory" }

func (m *MemoryStore) cleanup() {
	m.mu.Lock()
	now := time.Now()
	for k, item := range m.items {
		if item.hasExpiry && now.After(item.expiresAt) {
			delete(m.items, k)
		}
	}
	m.mu.Unlock()
}

func intToStr(n int64) string {
	if n == 0 {
		return "0"
	}
	b := make([]byte, 0, 20)
	for n > 0 {
		b = append(b, byte('0'+n%10))
		n /= 10
	}
	// reverse
	for i, j := 0, len(b)-1; i < j; i, j = i+1, j-1 {
		b[i], b[j] = b[j], b[i]
	}
	return string(b)
}
