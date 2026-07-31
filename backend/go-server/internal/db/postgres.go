package db

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	_ "github.com/lib/pq"
)

var DB *sql.DB

// Pool configuration defaults (can be overridden via environment)
const (
	defaultMaxOpenConns    = 25
	defaultMaxIdleConns    = 10
	defaultConnMaxLifetime = 5 * time.Minute
	defaultConnMaxIdleTime = 2 * time.Minute
	defaultPingTimeout     = 5 * time.Second
)

// Connect initializes the PostgreSQL connection pool with optimized settings
func Connect() error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		// Default for local dev
		dsn = "postgres://postgres:postgres@localhost:5433/ggs_werewolf?sslmode=disable"
	}

	var err error
	DB, err = sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("failed to open db: %w", err)
	}

	// Pool settings - configurable via environment variables
	maxOpen := getEnvInt("DB_MAX_OPEN_CONNS", defaultMaxOpenConns)
	maxIdle := getEnvInt("DB_MAX_IDLE_CONNS", defaultMaxIdleConns)
	connLifetime := getEnvDuration("DB_CONN_MAX_LIFETIME", defaultConnMaxLifetime)
	connIdleTime := getEnvDuration("DB_CONN_MAX_IDLE_TIME", defaultConnMaxIdleTime)

	DB.SetMaxOpenConns(maxOpen)
	DB.SetMaxIdleConns(maxIdle)
	DB.SetConnMaxLifetime(connLifetime)
	DB.SetConnMaxIdleTime(connIdleTime)

	// Verify connection with timeout
	ctx, cancel := context.WithTimeout(context.Background(), defaultPingTimeout)
	defer cancel()

	if err := DB.PingContext(ctx); err != nil {
		return fmt.Errorf("failed to ping db: %w", err)
	}

	log.Printf("✓ Connected to PostgreSQL (pool: %d max, %d idle, %v lifetime)", maxOpen, maxIdle, connLifetime)
	return nil
}

// Close closes the database connection
func Close() {
	if DB != nil {
		DB.Close()
		log.Println("✓ Database connection closed")
	}
}

// HealthCheck performs a health check on the database
func HealthCheck() error {
	if DB == nil {
		return fmt.Errorf("database not connected")
	}
	
	ctx, cancel := context.WithTimeout(context.Background(), defaultPingTimeout)
	defer cancel()
	
	return DB.PingContext(ctx)
}

// GetPoolStats returns current connection pool statistics
func GetPoolStats() map[string]interface{} {
	if DB == nil {
		return nil
	}
	
	stats := DB.Stats()
	return map[string]interface{}{
		"maxOpenConnections": stats.MaxOpenConnections,
		"openConnections":    stats.OpenConnections,
		"inUse":              stats.InUse,
		"idle":               stats.Idle,
		"waitCount":          stats.WaitCount,
		"waitDuration":       stats.WaitDuration.String(),
		"maxIdleClosed":      stats.MaxIdleClosed,
		"maxIdleTimeClosed":  stats.MaxIdleTimeClosed,
		"maxLifetimeClosed":  stats.MaxLifetimeClosed,
	}
}

// Helper functions for environment configuration
func getEnvInt(key string, defaultVal int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return defaultVal
}

func getEnvDuration(key string, defaultVal time.Duration) time.Duration {
	if val := os.Getenv(key); val != "" {
		if d, err := time.ParseDuration(val); err == nil {
			return d
		}
	}
	return defaultVal
}
