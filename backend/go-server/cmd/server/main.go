package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/api"
	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
	"github.com/ggs/werewolf-server/internal/ws"
)

// ─── Rate Limiter ────────────────────────────────────────

type rateLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rate     int           // requests per window
	window   time.Duration // time window
}

type visitor struct {
	count    int
	lastSeen time.Time
}

func newRateLimiter(rate int, window time.Duration) *rateLimiter {
	rl := &rateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate,
		window:   window,
	}
	// Clean up old entries every minute
	go func() {
		for {
			time.Sleep(time.Minute)
			rl.mu.Lock()
			for ip, v := range rl.visitors {
				if time.Since(v.lastSeen) > rl.window*2 {
					delete(rl.visitors, ip)
				}
			}
			rl.mu.Unlock()
		}
	}()
	return rl
}

func (rl *rateLimiter) allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	now := time.Now()

	if !exists || now.Sub(v.lastSeen) > rl.window {
		rl.visitors[ip] = &visitor{count: 1, lastSeen: now}
		return true
	}

	if v.count >= rl.rate {
		return false
	}

	v.count++
	v.lastSeen = now
	return true
}

func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (for reverse proxy)
	xff := r.Header.Get("X-Forwarded-For")
	if xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	// Check X-Real-IP header
	xri := r.Header.Get("X-Real-IP")
	if xri != "" {
		return xri
	}
	// Fall back to RemoteAddr
	return strings.Split(r.RemoteAddr, ":")[0]
}

func main() {
	// Initialize logger
	logger.Init()
	logger.Info(logger.CatSystem, "Starting GGS Werewolf Server", nil)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Get allowed origins from environment (comma-separated)
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		// Default: allow localhost and local network for development
		// Mobile apps don't send Origin header, so this mainly affects web clients
		allowedOrigins = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:8080,http://10.168.69.185:8080,*"
		log.Println("⚠ ALLOWED_ORIGINS not set, using development defaults (allowing all origins)")
	}
	originList := strings.Split(allowedOrigins, ",")
	for i := range originList {
		originList[i] = strings.TrimSpace(originList[i])
	}

	// Create rate limiters
	authLimiter := newRateLimiter(10, time.Minute)     // 10 auth attempts per minute per IP
	apiLimiter := newRateLimiter(100, time.Minute)     // 100 API calls per minute per IP
	wsLimiter := newRateLimiter(5, time.Minute)        // 5 WebSocket connections per minute per IP

	// Connect to PostgreSQL
	if err := db.Connect(); err != nil {
		logger.Warn(logger.CatDB, "PostgreSQL unavailable, using in-memory fallback", map[string]interface{}{
			"error": err.Error(),
		})
		log.Printf("  Set DATABASE_URL or run: createdb ggs_werewolf && psql -d ggs_werewolf -f migrations/001_init.sql")
		db.InitMemoryStore()
	} else {
		logger.Info(logger.CatDB, "Connected to PostgreSQL", nil)
		defer db.Close()
	}

	// Create API server
	server := api.NewServer()

	// Create WebSocket hub
	hub := ws.NewHub()
	go hub.Run()
	hub.StartTimerLoop()

	mux := http.NewServeMux()

	// Health
	mux.HandleFunc("/api/health", api.HealthHandler)

	// Debug logs (development only)
	mux.HandleFunc("/api/debug/logs", api.DebugLogsHandler)

	// Auth (public, rate limited)
	mux.HandleFunc("/api/auth/register", rateLimitMiddleware(authLimiter, server.HandleRegister))
	mux.HandleFunc("/api/auth/login", rateLimitMiddleware(authLimiter, server.HandleLogin))
	mux.HandleFunc("/api/auth/guest", rateLimitMiddleware(authLimiter, server.HandleGuest))
	mux.HandleFunc("/api/auth/refresh", rateLimitMiddleware(authLimiter, server.HandleRefresh))
	mux.HandleFunc("/api/auth/logout", rateLimitMiddleware(authLimiter, server.AuthMiddleware(server.HandleLogout)))

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
	mux.HandleFunc("/api/report", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleReport)))
	mux.HandleFunc("/api/blocked", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleBlocked)))
	mux.HandleFunc("/api/recent-players", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleRecentPlayers)))

	// Ranking (protected)
	mux.HandleFunc("/api/rank", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleRankInfo)))

	// Inventory (protected)
	mux.HandleFunc("/api/inventory", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleInventory)))

	// Shop (protected)
	mux.HandleFunc("/api/shop", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleShop)))

	// Feature flags (public)
	mux.HandleFunc("/api/flags", rateLimitMiddleware(apiLimiter, server.HandleFeatureFlags))

	// Daily Missions (protected)
	mux.HandleFunc("/api/missions", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleMissions)))

	// Notifications (protected)
	mux.HandleFunc("/api/notifications", rateLimitMiddleware(apiLimiter, server.AuthMiddleware(server.HandleNotifications)))

	// WebSocket (rate limited)
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !wsLimiter.allow(ip) {
			http.Error(w, "Too many connection attempts", http.StatusTooManyRequests)
			return
		}
		ws.HandleWebSocket(hub, w, r)
	})

	handler := loggingMiddleware(corsMiddleware(originList, securityHeadersMiddleware(mux)))

	fmt.Printf("🐺 GGS Werewolf Server on :%s\n", port)
	fmt.Printf("   Auth:    POST /api/auth/{register,login,guest,refresh,logout}\n")
	fmt.Printf("   Profile: GET|PUT /api/profile\n")
	fmt.Printf("   Stats:   GET /api/stats, /api/history, /api/leaderboard\n")
	fmt.Printf("   WS:      /ws\n")
	fmt.Printf("   CORS:    %v\n", originList)
	// Listen on all interfaces (0.0.0.0) for network access
	addr := "0.0.0.0:" + port
	log.Fatal(http.ListenAndServe(addr, handler))
}

// rateLimitMiddleware wraps a handler with rate limiting
func rateLimitMiddleware(rl *rateLimiter, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		if !rl.allow(ip) {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", "60")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"rate limit exceeded, please try again later"}`))
			return
		}
		next(w, r)
	}
}

// corsMiddleware handles CORS with whitelist
func corsMiddleware(allowedOrigins []string, next http.Handler) http.Handler {
	originSet := make(map[string]bool)
	allowAll := false
	for _, o := range allowedOrigins {
		if o == "*" {
			allowAll = true
		}
		originSet[o] = true
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		
		// Check if origin is allowed
		if allowAll && origin != "" {
			// Allow all origins (development mode)
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		} else if origin != "" && originSet[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		} else if origin == "" {
			// Allow requests without origin (mobile apps, same-origin, curl, etc.)
			// Mobile apps typically don't send Origin header
			w.Header().Set("Access-Control-Allow-Origin", "*")
		}
		
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours
		
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// securityHeadersMiddleware adds security headers
func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		next.ServeHTTP(w, r)
	})
}

// responseWriter wraps http.ResponseWriter to capture status code
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

// Hijack implements http.Hijacker interface for WebSocket support
func (rw *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hj, ok := rw.ResponseWriter.(http.Hijacker); ok {
		return hj.Hijack()
	}
	return nil, nil, fmt.Errorf("websocket: response does not implement http.Hijacker")
}

// loggingMiddleware logs HTTP requests with structured output
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Generate request ID
		requestID := fmt.Sprintf("%d", time.Now().UnixNano())
		
		// Wrap response writer to capture status
		wrapped := newResponseWriter(w)
		wrapped.Header().Set("X-Request-ID", requestID)
		
		// Process request
		next.ServeHTTP(wrapped, r)
		
		// Calculate duration
		duration := time.Since(start)
		
		// Get client IP
		ip := getClientIP(r)
		
		// Log format: timestamp | status | duration | method | path | ip | size
		statusEmoji := "✓"
		if wrapped.statusCode >= 400 {
			statusEmoji = "✗"
		}
		if wrapped.statusCode >= 500 {
			statusEmoji = "⚠"
		}
		
		// Skip logging health checks in production (too noisy)
		if r.URL.Path == "/api/health" && os.Getenv("LOG_HEALTH") != "true" {
			return
		}
		
		log.Printf("%s %d | %12v | %-6s %-30s | %s | %d bytes",
			statusEmoji,
			wrapped.statusCode,
			duration.Round(time.Microsecond),
			r.Method,
			r.URL.Path,
			ip,
			wrapped.size,
		)
	})
}
