package db

import (
	"fmt"
	"time"
)

// StartCleanupJobs starts background cleanup goroutines.
// Call once after DB.Connect() in main.go.
func StartCleanupJobs() {
	if DB == nil {
		return
	}
	go cleanupLoop()
	fmt.Println("🧹 Cleanup jobs started")
}

func cleanupLoop() {
	// Run immediately on start, then every hour
	runCleanup()
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()
	for range ticker.C {
		runCleanup()
	}
}

func runCleanup() {
	cleanExpiredPasswordResetTokens()
	cleanOldActivityFeed(30)    // 30 days
	cleanOldGameSnapshots(2)    // 2 hours
	cleanOldRateLimitWindows()
	cleanOldDiamondTransactions(90)  // 90 days
	cleanOldAbuseLog(60)        // 60 days
	cleanExpiredComboWindows()
}

func cleanExpiredPasswordResetTokens() {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM password_reset_tokens WHERE expires_at < NOW() OR used = true`)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d expired password reset tokens\n", n)
	}
}

func cleanOldActivityFeed(days int) {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM social_activity_feed WHERE created_at < NOW() - INTERVAL '1 day' * $1`, days)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d old activity feed entries (>%dd)\n", n, days)
	}
}

func cleanOldGameSnapshots(hours int) {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM game_snapshots WHERE saved_at < NOW() - INTERVAL '1 hour' * $1`, hours)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d expired game snapshots (>%dh)\n", n, hours)
	}
}

func cleanOldRateLimitWindows() {
	if DB == nil { return }
	cutoff := time.Now().UTC().Add(-2 * time.Hour).Format("2006010215")
	res, err := DB.Exec(`DELETE FROM gift_rate_limit WHERE window_key < $1`, cutoff)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d old rate limit entries\n", n)
	}
}

func cleanOldDiamondTransactions(days int) {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM diamond_transactions WHERE created_at < NOW() - INTERVAL '1 day' * $1`, days)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d old diamond transactions (>%dd)\n", n, days)
	}
}

func cleanOldAbuseLog(days int) {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM gift_abuse_log WHERE created_at < NOW() - INTERVAL '1 day' * $1`, days)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d old abuse log entries (>%dd)\n", n, days)
	}
}

func cleanExpiredComboWindows() {
	if DB == nil { return }
	res, err := DB.Exec(`DELETE FROM gift_combo_events WHERE window_end < NOW() - INTERVAL '1 hour'`)
	if err != nil || res == nil { return }
	if n, _ := res.RowsAffected(); n > 0 {
		fmt.Printf("[Cleanup] Deleted %d expired combo windows\n", n)
	}
}
