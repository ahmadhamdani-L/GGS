package logger

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"
	"sync"
	"time"
)

// LogLevel represents the severity of a log message
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

var levelNames = map[LogLevel]string{
	DEBUG: "DEBUG",
	INFO:  "INFO",
	WARN:  "WARN",
	ERROR: "ERROR",
	FATAL: "FATAL",
}

var levelColors = map[LogLevel]string{
	DEBUG: "\033[36m", // Cyan
	INFO:  "\033[32m", // Green
	WARN:  "\033[33m", // Yellow
	ERROR: "\033[31m", // Red
	FATAL: "\033[35m", // Magenta
}

const colorReset = "\033[0m"

// LogCategory for filtering and grouping logs
type LogCategory string

const (
	CatAPI       LogCategory = "API"
	CatWebSocket LogCategory = "WS"
	CatGame      LogCategory = "GAME"
	CatRoom      LogCategory = "ROOM"
	CatAuth      LogCategory = "AUTH"
	CatDB        LogCategory = "DB"
	CatBot       LogCategory = "BOT"
	CatTimer     LogCategory = "TIMER"
	CatSystem    LogCategory = "SYS"
)

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp  time.Time              `json:"timestamp"`
	Level      string                 `json:"level"`
	Category   string                 `json:"category"`
	Message    string                 `json:"message"`
	RequestID  string                 `json:"requestId,omitempty"`
	UserID     string                 `json:"userId,omitempty"`
	RoomID     string                 `json:"roomId,omitempty"`
	Duration   string                 `json:"duration,omitempty"`
	Error      string                 `json:"error,omitempty"`
	Extra      map[string]interface{} `json:"extra,omitempty"`
	File       string                 `json:"file,omitempty"`
	Line       int                    `json:"line,omitempty"`
}

// Logger is the main logging struct
type Logger struct {
	minLevel    LogLevel
	useColors   bool
	useJSON     bool
	mu          sync.Mutex
	recentLogs  []LogEntry
	maxRecent   int
}

var (
	defaultLogger *Logger
	once          sync.Once
)

// Init initializes the global logger
func Init() {
	once.Do(func() {
		defaultLogger = &Logger{
			minLevel:   DEBUG,
			useColors:  true,
			useJSON:    os.Getenv("LOG_FORMAT") == "json",
			recentLogs: make([]LogEntry, 0, 1000),
			maxRecent:  1000,
		}
		
		// Set log level from environment
		switch strings.ToUpper(os.Getenv("LOG_LEVEL")) {
		case "DEBUG":
			defaultLogger.minLevel = DEBUG
		case "INFO":
			defaultLogger.minLevel = INFO
		case "WARN":
			defaultLogger.minLevel = WARN
		case "ERROR":
			defaultLogger.minLevel = ERROR
		default:
			defaultLogger.minLevel = DEBUG // Default to DEBUG for development
		}
		
		log.SetFlags(0) // We handle formatting ourselves
	})
}

// GetLogger returns the global logger instance
func GetLogger() *Logger {
	if defaultLogger == nil {
		Init()
	}
	return defaultLogger
}

// Log logs a message with the given level and category
func (l *Logger) Log(level LogLevel, cat LogCategory, msg string, fields map[string]interface{}) {
	if level < l.minLevel {
		return
	}

	// Get caller info
	_, file, line, ok := runtime.Caller(2)
	if ok {
		// Shorten file path
		parts := strings.Split(file, "/")
		if len(parts) > 2 {
			file = strings.Join(parts[len(parts)-2:], "/")
		}
	}

	entry := LogEntry{
		Timestamp: time.Now(),
		Level:     levelNames[level],
		Category:  string(cat),
		Message:   msg,
		File:      file,
		Line:      line,
		Extra:     fields,
	}

	// Extract common fields
	if fields != nil {
		if v, ok := fields["requestId"].(string); ok {
			entry.RequestID = v
			delete(fields, "requestId")
		}
		if v, ok := fields["userId"].(string); ok {
			entry.UserID = v
			delete(fields, "userId")
		}
		if v, ok := fields["roomId"].(string); ok {
			entry.RoomID = v
			delete(fields, "roomId")
		}
		if v, ok := fields["duration"].(string); ok {
			entry.Duration = v
			delete(fields, "duration")
		}
		if v, ok := fields["error"].(string); ok {
			entry.Error = v
			delete(fields, "error")
		}
		if err, ok := fields["err"].(error); ok {
			entry.Error = err.Error()
			delete(fields, "err")
		}
	}

	// Store in recent logs
	l.mu.Lock()
	if len(l.recentLogs) >= l.maxRecent {
		l.recentLogs = l.recentLogs[1:]
	}
	l.recentLogs = append(l.recentLogs, entry)
	l.mu.Unlock()

	// Output log
	if l.useJSON {
		jsonBytes, _ := json.Marshal(entry)
		fmt.Println(string(jsonBytes))
	} else {
		l.printColored(entry, level)
	}

	if level == FATAL {
		os.Exit(1)
	}
}

func (l *Logger) printColored(entry LogEntry, level LogLevel) {
	color := ""
	if l.useColors {
		color = levelColors[level]
	}

	// Format: [TIME] [LEVEL] [CATEGORY] message {extra}
	timestamp := entry.Timestamp.Format("15:04:05.000")
	
	extra := ""
	if entry.RequestID != "" {
		extra += fmt.Sprintf(" req=%s", entry.RequestID)
	}
	if entry.UserID != "" {
		extra += fmt.Sprintf(" user=%s", entry.UserID)
	}
	if entry.RoomID != "" {
		extra += fmt.Sprintf(" room=%s", entry.RoomID)
	}
	if entry.Duration != "" {
		extra += fmt.Sprintf(" dur=%s", entry.Duration)
	}
	if entry.Error != "" {
		extra += fmt.Sprintf(" err=%s", entry.Error)
	}
	if len(entry.Extra) > 0 {
		extraJSON, _ := json.Marshal(entry.Extra)
		extra += fmt.Sprintf(" %s", string(extraJSON))
	}

	fmt.Printf("%s[%s] [%s%-5s%s] [%-5s] %s%s%s\n",
		color, timestamp,
		color, entry.Level, colorReset,
		entry.Category,
		entry.Message, extra,
		colorReset,
	)
}

// GetRecentLogs returns recent log entries for the debug API
func (l *Logger) GetRecentLogs(limit int, category string, level string) []LogEntry {
	l.mu.Lock()
	defer l.mu.Unlock()

	result := make([]LogEntry, 0)
	for i := len(l.recentLogs) - 1; i >= 0 && len(result) < limit; i-- {
		entry := l.recentLogs[i]
		
		// Filter by category
		if category != "" && entry.Category != category {
			continue
		}
		
		// Filter by level
		if level != "" && entry.Level != level {
			continue
		}
		
		result = append(result, entry)
	}
	
	return result
}

// Convenience methods
func Debug(cat LogCategory, msg string, fields map[string]interface{}) {
	GetLogger().Log(DEBUG, cat, msg, fields)
}

func Info(cat LogCategory, msg string, fields map[string]interface{}) {
	GetLogger().Log(INFO, cat, msg, fields)
}

func Warn(cat LogCategory, msg string, fields map[string]interface{}) {
	GetLogger().Log(WARN, cat, msg, fields)
}

func Error(cat LogCategory, msg string, fields map[string]interface{}) {
	GetLogger().Log(ERROR, cat, msg, fields)
}

func Fatal(cat LogCategory, msg string, fields map[string]interface{}) {
	GetLogger().Log(FATAL, cat, msg, fields)
}

// WebSocket specific logging
func WSConnect(userID, remoteAddr string) {
	Info(CatWebSocket, "Client connected", map[string]interface{}{
		"userId": userID,
		"addr":   remoteAddr,
	})
}

func WSDisconnect(userID, reason string) {
	Info(CatWebSocket, "Client disconnected", map[string]interface{}{
		"userId": userID,
		"reason": reason,
	})
}

func WSMessage(userID, msgType string, roomID string, payload interface{}) {
	Debug(CatWebSocket, fmt.Sprintf("Message: %s", msgType), map[string]interface{}{
		"userId":  userID,
		"roomId":  roomID,
		"type":    msgType,
		"payload": payload,
	})
}

func WSError(userID, msgType, errMsg string) {
	Error(CatWebSocket, fmt.Sprintf("WS Error: %s", msgType), map[string]interface{}{
		"userId": userID,
		"type":   msgType,
		"error":  errMsg,
	})
}

// Room specific logging
func RoomCreated(roomID, roomCode, hostID string) {
	Info(CatRoom, "Room created", map[string]interface{}{
		"roomId": roomID,
		"code":   roomCode,
		"hostId": hostID,
	})
}

func RoomJoined(roomID, userID string, playerCount int) {
	Info(CatRoom, "Player joined room", map[string]interface{}{
		"roomId":      roomID,
		"userId":      userID,
		"playerCount": playerCount,
	})
}

func RoomLeft(roomID, userID string, reason string) {
	Info(CatRoom, "Player left room", map[string]interface{}{
		"roomId": roomID,
		"userId": userID,
		"reason": reason,
	})
}

func RoomDestroyed(roomID, reason string) {
	Info(CatRoom, "Room destroyed", map[string]interface{}{
		"roomId": roomID,
		"reason": reason,
	})
}

// Game specific logging
func GameStarted(roomID string, playerCount int, roles map[string]int) {
	Info(CatGame, "Game started", map[string]interface{}{
		"roomId":      roomID,
		"playerCount": playerCount,
		"roles":       roles,
	})
}

func GamePhaseChange(roomID, fromPhase, toPhase string, round int) {
	Info(CatGame, fmt.Sprintf("Phase: %s → %s", fromPhase, toPhase), map[string]interface{}{
		"roomId": roomID,
		"from":   fromPhase,
		"to":     toPhase,
		"round":  round,
	})
}

func GameAction(roomID, userID, action string, target string) {
	Debug(CatGame, fmt.Sprintf("Action: %s", action), map[string]interface{}{
		"roomId": roomID,
		"userId": userID,
		"action": action,
		"target": target,
	})
}

func GameEnded(roomID string, winner string, rounds int, duration time.Duration) {
	Info(CatGame, "Game ended", map[string]interface{}{
		"roomId":   roomID,
		"winner":   winner,
		"rounds":   rounds,
		"duration": duration.String(),
	})
}

// API specific logging
func APIRequest(requestID, method, path, userID string) {
	Debug(CatAPI, fmt.Sprintf("%s %s", method, path), map[string]interface{}{
		"requestId": requestID,
		"userId":    userID,
	})
}

func APIResponse(requestID string, status int, duration time.Duration) {
	level := INFO
	if status >= 400 {
		level = WARN
	}
	if status >= 500 {
		level = ERROR
	}
	GetLogger().Log(level, CatAPI, fmt.Sprintf("Response: %d", status), map[string]interface{}{
		"requestId": requestID,
		"status":    status,
		"duration":  duration.String(),
	})
}

func APIError(requestID, errMsg string, status int) {
	Error(CatAPI, "API Error", map[string]interface{}{
		"requestId": requestID,
		"error":     errMsg,
		"status":    status,
	})
}

// Timer specific logging
func TimerStarted(roomID, phase string, deadline time.Time) {
	Debug(CatTimer, fmt.Sprintf("Timer started: %s", phase), map[string]interface{}{
		"roomId":   roomID,
		"phase":    phase,
		"deadline": deadline.Format(time.RFC3339),
	})
}

func TimerExpired(roomID, phase string) {
	Info(CatTimer, fmt.Sprintf("Timer expired: %s", phase), map[string]interface{}{
		"roomId": roomID,
		"phase":  phase,
	})
}

// Database specific logging
func DBQuery(query string, duration time.Duration, err error) {
	fields := map[string]interface{}{
		"query":    query,
		"duration": duration.String(),
	}
	if err != nil {
		fields["error"] = err.Error()
		Error(CatDB, "DB query failed", fields)
	} else if duration > 100*time.Millisecond {
		Warn(CatDB, "Slow DB query", fields)
	} else {
		Debug(CatDB, "DB query", fields)
	}
}
