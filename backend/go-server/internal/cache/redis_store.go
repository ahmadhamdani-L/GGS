package cache

import (
	"context"
	"fmt"
	"log"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisStore implements Store interface backed by Redis.
// Used for multi-instance deployments where state must be shared.
type RedisStore struct {
	client *redis.Client
	ctx    context.Context
}

// NewRedisStore creates a new Redis-backed cache store.
// url format: redis://:password@host:port/db
func NewRedisStore(url string) (*RedisStore, error) {
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, fmt.Errorf("invalid REDIS_URL: %w", err)
	}

	client := redis.NewClient(opts)
	ctx := context.Background()

	// Test connection
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("redis ping failed: %w", err)
	}

	log.Printf("✅ Redis connected: %s", opts.Addr)

	return &RedisStore{client: client, ctx: ctx}, nil
}

func (r *RedisStore) Get(key string) (string, bool) {
	val, err := r.client.Get(r.ctx, key).Result()
	if err == redis.Nil {
		return "", false
	}
	if err != nil {
		return "", false
	}
	return val, true
}

func (r *RedisStore) Set(key string, value string, ttl time.Duration) error {
	return r.client.Set(r.ctx, key, value, ttl).Err()
}

func (r *RedisStore) Incr(key string, ttl time.Duration) (int64, error) {
	pipe := r.client.TxPipeline()
	incr := pipe.Incr(r.ctx, key)
	if ttl > 0 {
		pipe.Expire(r.ctx, key, ttl)
	}
	_, err := pipe.Exec(r.ctx)
	if err != nil {
		return 0, err
	}
	return incr.Val(), nil
}

func (r *RedisStore) Del(key string) error {
	return r.client.Del(r.ctx, key).Err()
}

func (r *RedisStore) Type() string { return "redis" }

// Close cleanly shuts down the Redis connection.
func (r *RedisStore) Close() error {
	return r.client.Close()
}

// ─── Rate Limiting via Redis ─────────────────────────────────

// RateLimitCheck checks if a key has exceeded the limit within the window.
// Returns (allowed bool, remaining int).
// Uses Redis sliding window counter pattern.
func (r *RedisStore) RateLimitCheck(key string, limit int, window time.Duration) (bool, int) {
	now := time.Now().UnixMilli()
	windowStart := now - window.Milliseconds()

	pipe := r.client.TxPipeline()
	// Remove expired entries
	pipe.ZRemRangeByScore(r.ctx, key, "0", strconv.FormatInt(windowStart, 10))
	// Count current entries
	count := pipe.ZCard(r.ctx, key)
	// Add current request
	pipe.ZAdd(r.ctx, key, redis.Z{Score: float64(now), Member: now})
	// Set expiry on the whole key
	pipe.Expire(r.ctx, key, window)

	_, err := pipe.Exec(r.ctx)
	if err != nil {
		// On error, allow the request (fail-open)
		return true, limit
	}

	currentCount := int(count.Val())
	if currentCount >= limit {
		return false, 0
	}
	return true, limit - currentCount
}
