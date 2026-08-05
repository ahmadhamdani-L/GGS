package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/ggs/werewolf-server/internal/api"
	"github.com/ggs/werewolf-server/internal/auth"
	"github.com/ggs/werewolf-server/internal/cache"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
	"github.com/ggs/werewolf-server/internal/ws"
)

// ─── Token-Bucket Rate Limiter ────────────────────────────
// H-07 FIX: Replace fixed-window counter with token bucket to prevent burst abuse.

type tokenBucket struct {
	mu       sync.Mutex
	buckets  map[string]*bucket
	rate     float64       // tokens per second
	capacity float64       // max tokens
	window   time.Duration // cleanup interval
}

type bucket struct {
	tokens   float64
	lastSeen time.Time
}

func newTokenBucket(ratePerMin int, capacity int) *tokenBucket {
	tb := &tokenBucket{
		buckets:  make(map[string]*bucket),
		rate:     float64(ratePerMin) / 60.0,
		capacity: float64(capacity),
		window:   5 * time.Minute,
	}
	// Cleanup goroutine — remove stale buckets
	go func() {
		for {
			time.Sleep(2 * time.Minute)
			tb.mu.Lock()
			cutoff := time.Now().Add(-tb.window)
			for ip, b := range tb.buckets {
				if b.lastSeen.Before(cutoff) {
					delete(tb.buckets, ip)
				}
			}
			tb.mu.Unlock()
		}
	}()
	return tb
}

func (tb *tokenBucket) allow(ip string) bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	now := time.Now()
	b, exists := tb.buckets[ip]
	if !exists {
		tb.buckets[ip] = &bucket{tokens: tb.capacity - 1, lastSeen: now}
		return true
	}

	// Refill tokens based on elapsed time
	elapsed := now.Sub(b.lastSeen).Seconds()
	b.tokens = min(tb.capacity, b.tokens+elapsed*tb.rate)
	b.lastSeen = now

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

func getClientIP(r *http.Request) string {
	xff := r.Header.Get("X-Forwarded-For")
	if xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	xri := r.Header.Get("X-Real-IP")
	if xri != "" {
		return xri
	}
	return strings.Split(r.RemoteAddr, ":")[0]
}

func main() {
	logger.Init()
	logger.Info(logger.CatSystem, "Starting GGS Werewolf Server", nil)

	// P0-3: Initialize shared cache (memory or Redis based on REDIS_URL env)
	cache.Init()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Write all logs to file for analysis (append mode to preserve across restarts)
	logFile, err := os.OpenFile("./server_debug.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err == nil {
		log.SetOutput(io.MultiWriter(os.Stdout, logFile))
		defer logFile.Close()
		log.Println("📄 Server log file: ./server_debug.log (append mode)")
	}

	// C-02 FIX: ALLOWED_ORIGINS no longer contains "*" in the default.
	// Mobile apps don't send Origin headers so they are always allowed.
	// The wildcard is only set if explicitly requested via env (dev override).
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		allowedOrigins = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080"
		log.Println("⚠ ALLOWED_ORIGINS not set, using localhost defaults only. Set ALLOWED_ORIGINS=* for open dev mode.")
	}
	originList := strings.Split(allowedOrigins, ",")
	for i := range originList {
		originList[i] = strings.TrimSpace(originList[i])
	}

	// H-07 FIX: Token-bucket rate limiters (burst-resistant)
	// auth: 10 tokens, refills at 10/min → can burst 10, then 1 per 6s
	authLimiter := newTokenBucket(10, 10)
	// forgot-password: M-04 FIX — stricter, 3 tokens, refills at 3/min
	forgotPwLimiter := newTokenBucket(3, 3)
	// api: 100 tokens, refills at 100/min
	apiLimiter := newTokenBucket(100, 100)
	// ws: 5 tokens, refills at 5/min
	wsLimiter := newTokenBucket(5, 5)

	if err := db.Connect(); err != nil {
		logger.Warn(logger.CatDB, "PostgreSQL unavailable, using in-memory fallback", map[string]interface{}{
			"error": err.Error(),
		})
		db.InitMemoryStore()
	} else {
		logger.Info(logger.CatDB, "Connected to PostgreSQL", nil)
		defer db.Close()
		// P0-1 FIX: Wire persistent refresh token store to PostgreSQL
		auth.SetDB(db.DB)
	}

	// Start token cleanup job (works for both DB and memory mode)
	auth.StartTokenCleanup()

	hub := ws.NewHub()
	go hub.Run()
	hub.StartTimerLoop()
	hub.LoadMaxRooms()
	hub.RestoreSnapshots()

	// Initialize crash reporting (Sentry)
	api.InitSentry()

	// Start background cleanup jobs (expired tokens, old data, etc.)
	db.StartCleanupJobs()

	server := api.NewServer(hub)

	mux := http.NewServeMux()

	// Health
	mux.HandleFunc("/api/health", api.HealthHandler)

	// C-03 FIX: Debug endpoint is now gated by DEBUG_KEY env var (not hardcoded).
	// Disabled entirely in production (when DEBUG_KEY is not set).
	debugKey := os.Getenv("DEBUG_KEY")
	if debugKey != "" {
		mux.HandleFunc("/api/debug/logs", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("X-Debug-Key") != debugKey {
				http.Error(w, "Forbidden", http.StatusForbidden)
				return
			}
			api.DebugLogsHandler(w, r)
		})
		log.Println("⚠ Debug endpoint enabled (DEBUG_KEY is set)")
	}

	// Auth (rate limited with token bucket)
	mux.HandleFunc("/api/auth/register", rateLimitMiddleware(authLimiter, server.HandleRegister))
	mux.HandleFunc("/api/auth/login", rateLimitMiddleware(authLimiter, server.HandleLogin))
	mux.HandleFunc("/api/auth/guest", rateLimitMiddleware(authLimiter, server.HandleGuest))
	mux.HandleFunc("/api/auth/refresh", rateLimitMiddleware(authLimiter, server.HandleRefresh))
	mux.HandleFunc("/api/auth/logout", rateLimitMiddleware(authLimiter, server.AuthMiddleware(server.HandleLogout)))
	// M-04 FIX: forgot-password uses stricter limiter (3/min)
	mux.HandleFunc("/api/auth/forgot-password", rateLimitMiddleware(forgotPwLimiter, server.HandleForgotPassword))
	mux.HandleFunc("/api/auth/convert-guest", rateLimitMiddleware(authLimiter, server.AuthMiddleware(server.HandleConvertGuest)))

	// Profile (protected)
	mux.HandleFunc("/api/profile", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleProfile)))

	// Stats
	mux.HandleFunc("/api/stats", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleStats)))
	mux.HandleFunc("/api/history", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleMatchHistory)))

	// Leaderboard (public)
	mux.HandleFunc("/api/leaderboard", rateLimitMiddleware(apiLimiter, server.HandleLeaderboard))

	// Achievements (protected)
	mux.HandleFunc("/api/achievements", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleAchievements)))

	// Social (protected)
	mux.HandleFunc("/api/friends", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleFriends)))
	mux.HandleFunc("/api/users/search", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleSearchUsers)))
	// P1-7 FIX: Removed duplicate /api/social/gift route — use /api/gifts/send instead
	mux.HandleFunc("/api/report", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleReport)))
	mux.HandleFunc("/api/blocked", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleBlocked)))
	mux.HandleFunc("/api/recent-players", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleRecentPlayers)))

	// Ranking (protected)
	mux.HandleFunc("/api/rank", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleRankInfo)))

	// Rooms (public)
	mux.HandleFunc("/api/rooms/public", rateLimitMiddleware(apiLimiter, server.HandleGetPublicRooms))

	// Inventory (protected)
	mux.HandleFunc("/api/inventory", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleInventory)))

	// Shop (protected)
	mux.HandleFunc("/api/shop", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleShop)))

	// Feature flags (public)
	mux.HandleFunc("/api/flags", rateLimitMiddleware(apiLimiter, server.HandleFeatureFlags))

	// Daily Missions (protected)
	mux.HandleFunc("/api/missions", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleMissions)))

	// Daily Reward (protected)
	mux.HandleFunc("/api/daily-reward", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleDailyReward)))
	mux.HandleFunc("/api/daily-reward/claim", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleDailyRewardClaim)))

	// Avatar upload
	mux.HandleFunc("/api/avatar/upload", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleAvatarUpload)))
	mux.HandleFunc("/api/avatar", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleAvatarDelete)))

	// FCM push notification token registration
	mux.HandleFunc("/api/fcm/token", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleFCMToken)))

	// Payment (Diamond top-up via Midtrans)
	mux.HandleFunc("/api/payment/packages", rateLimitMiddleware(apiLimiter, server.HandleGetPackages))
	mux.HandleFunc("/api/payment/create-order", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleCreateOrder)))
	mux.HandleFunc("/api/payment/webhook", server.HandlePaymentWebhook)

	// Admin dashboard API (all protected by X-Admin-Key)
	mux.HandleFunc("/api/admin/ban", server.HandleAdminBan)
	mux.HandleFunc("/api/admin/gift-catalog", server.HandleAdminUpdateGift)
	mux.HandleFunc("/api/admin/stats", server.HandleAdminStats)
	mux.HandleFunc("/api/admin/feature-flags", server.HandleAdminFeatureFlags)

	// Account deletion
	mux.HandleFunc("/api/account", rateLimitMiddleware(authLimiter, server.AuthMiddleware(server.HandleDeleteAccount)))

	// Static file server for uploaded avatars (path traversal protection built-in)
	uploadDir := os.Getenv("AVATAR_UPLOAD_DIR")
	if uploadDir == "" {
		uploadDir = "./uploads/avatars"
	}
	mux.HandleFunc("/avatars/", api.ServeAvatarFile(uploadDir))

	// Social / Gift system
	mux.HandleFunc("/api/gifts/catalog", rateLimitMiddleware(apiLimiter, server.HandleGiftCatalog))
	mux.HandleFunc("/api/gifts/send",    rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleSendGift)))
	mux.HandleFunc("/api/gifts/history", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleGiftHistory)))
	mux.HandleFunc("/api/gifts/analytics", rateLimitMiddleware(apiLimiter, server.HandleGiftAnalytics))
	mux.HandleFunc("/api/social/stats",       rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleSocialStats)))
	mux.HandleFunc("/api/social/feed",        rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleActivityFeed)))
	mux.HandleFunc("/api/social/leaderboard", rateLimitMiddleware(apiLimiter, server.HandleSocialLeaderboard))
	mux.HandleFunc("/api/diamonds",           rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleGetDiamonds)))
	mux.HandleFunc("/api/diamonds/topup",     server.HandleTopUpDiamonds) // protected by X-Admin-Key header

	// Events
	mux.HandleFunc("/api/events", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleEvents)))
	mux.HandleFunc("/api/events/claim", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleEventClaim)))

	// Lucky Spin
	mux.HandleFunc("/api/lucky-spin", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleLuckySpin)))
	mux.HandleFunc("/api/lucky-spin/history", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleSpinHistory)))

	// Gift Inbox
	mux.HandleFunc("/api/gifts/inbox", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleGiftInbox)))
	mux.HandleFunc("/api/gifts/claim", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleGiftClaim)))

	// Notifications (protected)
	mux.HandleFunc("/api/notifications", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleNotifications)))
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !wsLimiter.allow(ip) {
			http.Error(w, "Too many connection attempts", http.StatusTooManyRequests)
			return
		}
		ws.HandleWebSocket(hub, w, r)
	})

	// #11 FIX: appVersionMiddleware is now wired into the chain.
	// Order: logging → CORS → security headers → maintenance mode → app version → mux
	handler := loggingMiddleware(corsMiddleware(originList, securityHeadersMiddleware(maintenanceModeMiddleware(appVersionMiddleware(mux)))))

	// #8: Wire OS signal handler for graceful shutdown (saves active game snapshots)
	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit
		log.Println("🛑 Shutting down — saving active game snapshots...")
		hub.SaveAllSnapshots()
		log.Println("✅ Snapshots saved. Goodbye.")
		os.Exit(0)
	}()

	fmt.Printf("🐺 GGS Werewolf Server on :%s\n", port)
	fmt.Printf("   Auth:    POST /api/auth/{register,login,guest,refresh,logout}\n")
	fmt.Printf("   Profile: GET|PUT /api/profile\n")
	fmt.Printf("   Stats:   GET /api/stats, /api/history, /api/leaderboard\n")
	fmt.Printf("   WS:      /ws\n")
	fmt.Printf("   CORS:    %v\n", originList)
	addr := "0.0.0.0:" + port
	srv := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1MB
	}
	log.Fatal(srv.ListenAndServe())
}

func rateLimitMiddleware(tb *tokenBucket, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !tb.allow(ip) {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", "60")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"rate limit exceeded, please try again later"}`))
			return
		}
		next(w, r)
	}
}

// C-02 FIX: corsMiddleware — no wildcard `Access-Control-Allow-Credentials: true`.
// Mobile apps (no Origin header) get a plain `*` ACAO without credentials.
func corsMiddleware(allowedOrigins []string, next http.Handler) http.Handler {
	originSet := make(map[string]bool)
	allowAll := false
	for _, o := range allowedOrigins {
		if o == "*" {
			allowAll = true
		}
		originSet[strings.ToLower(strings.TrimSpace(o))] = true
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		if origin == "" {
			// Mobile apps / same-origin: allow without credentials header
			w.Header().Set("Access-Control-Allow-Origin", "*")
		} else if allowAll {
			// Explicit dev override: allow all origins WITH credentials
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		} else if originSet[strings.ToLower(origin)] {
			// Whitelisted origin
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		} else {
			// Unknown origin — block CORS but let request proceed (server can decide)
			// Preflight will fail, which is the desired security behavior
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		next.ServeHTTP(w, r)
	})
}

// maintenanceModeMiddleware checks the maintenance_mode feature flag.
// #47 FIX: Enforce maintenance mode from DB feature flag.
func maintenanceModeMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Always allow health check and auth refresh so clients can detect maintenance
		if r.URL.Path == "/api/health" || r.URL.Path == "/api/auth/refresh" || r.URL.Path == "/api/flags" {
			next.ServeHTTP(w, r)
			return
		}

		// Check feature flag from DB (only if DB is available)
		if db.DB != nil {
			var enabled bool
			var msg string
			row := db.DB.QueryRow(`SELECT enabled, COALESCE(description, 'Server sedang dalam maintenance') FROM feature_flags WHERE key = 'maintenance_mode'`)
			if err := row.Scan(&enabled, &msg); err == nil && enabled {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", "300")
				w.WriteHeader(http.StatusServiceUnavailable)
				fmt.Fprintf(w, `{"error":"maintenance","message":%q}`, msg)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// appVersionMiddleware checks min_app_version from server_settings.
// #48 FIX: Enforce app version check on all API calls.
// Client must send X-App-Version header. Rejected if below minimum.
func appVersionMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip version check for health, flags, and auth
		skip := map[string]bool{
			"/api/health": true, "/api/flags": true,
			"/api/auth/register": true, "/api/auth/login": true,
			"/api/auth/guest": true, "/api/auth/refresh": true,
		}
		if skip[r.URL.Path] {
			next.ServeHTTP(w, r)
			return
		}

		clientVersion := r.Header.Get("X-App-Version")
		if clientVersion == "" {
			// No version header — allow (backward compatibility with older clients)
			next.ServeHTTP(w, r)
			return
		}

		if db.DB != nil {
			var minVersion string
			err := db.DB.QueryRow(`SELECT value FROM server_settings WHERE key = 'min_app_version'`).Scan(&minVersion)
			if err == nil && minVersion != "" && compareVersions(clientVersion, minVersion) < 0 {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusUpgradeRequired)
				fmt.Fprintf(w, `{"error":"version_outdated","minVersion":%q,"clientVersion":%q}`, minVersion, clientVersion)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

// compareVersions compares semver strings a and b.
// Returns -1 if a < b, 0 if equal, 1 if a > b.
func compareVersions(a, b string) int {
	parse := func(v string) [3]int {
		var major, minor, patch int
		fmt.Sscanf(v, "%d.%d.%d", &major, &minor, &patch)
		return [3]int{major, minor, patch}
	}
	av, bv := parse(a), parse(b)
	for i := 0; i < 3; i++ {
		if av[i] < bv[i] {
			return -1
		}
		if av[i] > bv[i] {
			return 1
		}
	}
	return 0
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
	size       int
}

func newResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(b)
	rw.size += size
	return size, err
}

func (rw *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hj, ok := rw.ResponseWriter.(http.Hijacker); ok {
		return hj.Hijack()
	}
	return nil, nil, fmt.Errorf("websocket: response does not implement http.Hijacker")
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		requestID := fmt.Sprintf("%d", time.Now().UnixNano())
		wrapped := newResponseWriter(w)
		wrapped.Header().Set("X-Request-ID", requestID)
		next.ServeHTTP(wrapped, r)
		duration := time.Since(start)
		ip := getClientIP(r)

		if r.URL.Path == "/api/health" && os.Getenv("LOG_HEALTH") != "true" {
			return
		}

		// Get userID from context (set by AuthMiddleware)
		var userID string
		if uid, ok := r.Context().Value("userId").(string); ok {
			userID = uid
		}

		level := logger.INFO
		if wrapped.statusCode >= 500 {
			level = logger.ERROR
		} else if wrapped.statusCode >= 400 {
			level = logger.WARN
		}

		logger.GetLogger().Log(level, logger.CatAPI, fmt.Sprintf("%s %s → %d", r.Method, r.URL.Path, wrapped.statusCode), map[string]interface{}{
			"requestId": requestID,
			"userId":    userID,
			"method":    r.Method,
			"path":      r.URL.Path,
			"status":    wrapped.statusCode,
			"duration":  duration.String(),
			"ip":        ip,
			"bytes":     wrapped.size,
		})
	})
}
