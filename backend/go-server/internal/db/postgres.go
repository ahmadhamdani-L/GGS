package db

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
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
		dbUser := os.Getenv("DB_USER")
		if dbUser == "" {
			dbUser = "postgres"
		}
		dbPass := os.Getenv("DB_PASSWORD")
		if dbPass == "" {
			dbPass = "postgres"
		}
		dbPort := os.Getenv("DB_PORT")
		if dbPort == "" {
			dbPort = "5432" // Using standard postgres port instead of 5432
		}
		// Default for local dev
		dsn = fmt.Sprintf("postgres://%s:%s@localhost:%s/ggs_werewolf?sslmode=disable", dbUser, dbPass, dbPort)
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
		// If database doesn't exist, try to create it automatically
		if isDBNotExistError(err) {
			log.Println("⚠ Database ggs_werewolf not found, creating automatically...")
			if createErr := ensureDatabase(dsn); createErr != nil {
				return fmt.Errorf("failed to auto-create database: %w", createErr)
			}
			// Retry ping after creating DB
			ctx2, cancel2 := context.WithTimeout(context.Background(), defaultPingTimeout)
			defer cancel2()
			if err2 := DB.PingContext(ctx2); err2 != nil {
				return fmt.Errorf("failed to ping db after create: %w", err2)
			}
			log.Println("✓ Database ggs_werewolf created, running migrations...")
			runMigrations()
		} else {
			return fmt.Errorf("failed to ping db: %w", err)
		}
	}

	// P2-37: Set default statement timeout to prevent runaway queries
	DB.Exec("SET statement_timeout = '5000'") // 5 seconds max per query

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

// ─── Auto-create database if not exists ──────────────────────

// isDBNotExistError checks if the error is because database doesn't exist
func isDBNotExistError(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "does not exist") ||
		strings.Contains(msg, "database") && strings.Contains(msg, "not exist")
}

// ensureDatabase connects to the default "postgres" database and creates ggs_werewolf
func ensureDatabase(originalDSN string) error {
	// Replace database name in DSN with "postgres" (default DB that always exists)
	adminDSN := strings.Replace(originalDSN, "/ggs_werewolf", "/postgres", 1)

	adminDB, err := sql.Open("postgres", adminDSN)
	if err != nil {
		return fmt.Errorf("cannot connect to postgres db: %w", err)
	}
	defer adminDB.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := adminDB.PingContext(ctx); err != nil {
		return fmt.Errorf("cannot ping postgres db: %w", err)
	}

	// Check if database exists
	var exists bool
	adminDB.QueryRow("SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = 'ggs_werewolf')").Scan(&exists)
	if exists {
		return nil // Already exists
	}

	// Create database
	_, err = adminDB.Exec("CREATE DATABASE ggs_werewolf")
	if err != nil {
		return fmt.Errorf("CREATE DATABASE failed: %w", err)
	}
	log.Println("✓ Created database ggs_werewolf")
	return nil
}

// runMigrations executes the SQL migration files
func runMigrations() {
	if DB == nil {
		return
	}

	// Try to read migration file from common locations
	migrationPaths := []string{
		"./migrations/001_init.sql",
		"/app/migrations/001_init.sql",
		"../migrations/001_init.sql",
	}

	for _, path := range migrationPaths {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		_, execErr := DB.Exec(string(data))
		if execErr != nil {
			log.Printf("⚠ Migration warning (non-fatal): %v", execErr)
		} else {
			log.Printf("✓ Migration applied from %s", path)
		}
		return
	}
	log.Println("⚠ No migration files found — database tables may be missing")
}
