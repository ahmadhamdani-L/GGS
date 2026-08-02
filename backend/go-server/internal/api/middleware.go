package api

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/ggs/werewolf-server/internal/auth"
	"github.com/ggs/werewolf-server/internal/logger"
)

// ContextKey type for context values
type ContextKey string

const (
	ContextKeyRequestID ContextKey = "requestId"
	ContextKeyUserID    ContextKey = "userId"
	ContextKeyStartTime ContextKey = "startTime"
)

// generateRequestID creates a unique request ID
func generateRequestID() string {
	bytes := make([]byte, 8)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

// LoggingMiddleware logs all HTTP requests with timing
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Generate request ID
		requestID := r.Header.Get("X-Request-ID")
		if requestID == "" {
			requestID = generateRequestID()
		}

		// Get user ID from auth header if present
		userID := ""
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			token := strings.TrimPrefix(authHeader, "Bearer ")
			if uid, err := auth.ValidateToken(token); err == nil {
				userID = uid
			}
		}

		// Store in context
		startTime := time.Now()
		ctx := context.WithValue(r.Context(), ContextKeyRequestID, requestID)
		ctx = context.WithValue(ctx, ContextKeyUserID, userID)
		ctx = context.WithValue(ctx, ContextKeyStartTime, startTime)

		// Log request
		logger.APIRequest(requestID, r.Method, r.URL.Path, userID)

		// Wrap response writer to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: 200}

		// Set request ID header in response
		w.Header().Set("X-Request-ID", requestID)

		// Process request
		next.ServeHTTP(wrapped, r.WithContext(ctx))

		// Log response
		duration := time.Since(startTime)
		logger.APIResponse(requestID, wrapped.statusCode, duration)
	})
}

// responseWriter wraps http.ResponseWriter to capture status code
// It also implements http.Hijacker to support WebSocket upgrades
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Hijack implements http.Hijacker interface for WebSocket support
func (rw *responseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	if hijacker, ok := rw.ResponseWriter.(http.Hijacker); ok {
		return hijacker.Hijack()
	}
	return nil, nil, http.ErrNotSupported
}

// Flush implements http.Flusher interface
func (rw *responseWriter) Flush() {
	if flusher, ok := rw.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

// CORSMiddleware handles CORS headers
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-ID")
		w.Header().Set("Access-Control-Expose-Headers", "X-Request-ID")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// RecoveryMiddleware recovers from panics and logs them
func RecoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				requestID, _ := r.Context().Value(ContextKeyRequestID).(string)
				logger.Error(logger.CatAPI, "Panic recovered", map[string]interface{}{
					"requestId": requestID,
					"error":     err,
					"path":      r.URL.Path,
				})

				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusInternalServerError)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"error":     "Internal server error",
					"requestId": requestID,
				})
			}
		}()

		next.ServeHTTP(w, r)
	})
}

// TimeoutMiddleware adds request timeout
func TimeoutMiddleware(timeout time.Duration) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx, cancel := context.WithTimeout(r.Context(), timeout)
			defer cancel()

			done := make(chan struct{})
			go func() {
				next.ServeHTTP(w, r.WithContext(ctx))
				close(done)
			}()

			select {
			case <-done:
				// Request completed normally
			case <-ctx.Done():
				requestID, _ := r.Context().Value(ContextKeyRequestID).(string)
				logger.Warn(logger.CatAPI, "Request timeout", map[string]interface{}{
					"requestId": requestID,
					"path":      r.URL.Path,
					"timeout":   timeout.String(),
				})
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusGatewayTimeout)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"error":     "Request timeout",
					"requestId": requestID,
				})
			}
		})
	}
}

// DebugLogsHandler returns recent logs for debugging.
// #5 FIX: The key comparison now uses the DEBUG_KEY env var instead of a
// hardcoded string. If DEBUG_KEY is not set, ALL requests are rejected.
// main.go already gates the route registration on DEBUG_KEY != "", but this
// handler guards itself too so it can never be reached with the old hardcoded
// key even if registered elsewhere by accident.
func DebugLogsHandler(w http.ResponseWriter, r *http.Request) {
	debugKey := os.Getenv("DEBUG_KEY")
	if debugKey == "" || r.Header.Get("X-Debug-Key") != debugKey {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	limit := 100
	category := r.URL.Query().Get("category")
	level := r.URL.Query().Get("level")

	logs := logger.GetLogger().GetRecentLogs(limit, category, level)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"count": len(logs),
		"logs":  logs,
	})
}
