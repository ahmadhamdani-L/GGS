package security

import (
	"html"
	"regexp"
	"strings"
)

var (
	// Regex patterns for sanitization
	htmlTagRegex    = regexp.MustCompile(`<[^>]*>`)
	multiSpaceRegex = regexp.MustCompile(`\s+`)
	sqlKeywords     = regexp.MustCompile(`(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute|xp_|sp_|0x|--|;|'|\"|\\)`)
)

// SanitizeString removes potentially dangerous characters from user input
func SanitizeString(input string) string {
	// Trim whitespace
	input = strings.TrimSpace(input)
	
	// HTML escape to prevent XSS
	input = html.EscapeString(input)
	
	// Remove HTML tags if any remain
	input = htmlTagRegex.ReplaceAllString(input, "")
	
	// Normalize whitespace
	input = multiSpaceRegex.ReplaceAllString(input, " ")
	
	return input
}

// SanitizeDisplayName sanitizes a display name
func SanitizeDisplayName(name string) string {
	name = SanitizeString(name)
	
	// Limit length
	if len(name) > 20 {
		name = name[:20]
	}
	
	return name
}

// SanitizeChatMessage sanitizes a chat message
func SanitizeChatMessage(msg string) string {
	msg = SanitizeString(msg)
	
	// Limit length
	if len(msg) > 200 {
		msg = msg[:200]
	}
	
	return msg
}

// ContainsSQLInjection checks if input contains potential SQL injection patterns
func ContainsSQLInjection(input string) bool {
	return sqlKeywords.MatchString(input)
}

// SanitizeUUID validates and returns a UUID, or empty string if invalid
func SanitizeUUID(input string) string {
	input = strings.TrimSpace(input)
	
	// Basic UUID format validation
	uuidRegex := regexp.MustCompile(`^[a-fA-F0-9\-]{36}$`)
	if !uuidRegex.MatchString(input) {
		return ""
	}
	
	return strings.ToLower(input)
}

// SanitizeRoomCode validates and returns a room code
func SanitizeRoomCode(input string) string {
	input = strings.TrimSpace(input)
	input = strings.ToUpper(input)
	
	// Room code should be 6 alphanumeric characters
	roomCodeRegex := regexp.MustCompile(`^[A-Z0-9]{6}$`)
	if !roomCodeRegex.MatchString(input) {
		return ""
	}
	
	return input
}
