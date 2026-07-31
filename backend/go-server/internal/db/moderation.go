package db

import "time"

// PenaltyType represents moderation severity
type PenaltyType string

const (
	PenaltyWarning  PenaltyType = "warning"
	PenaltyMute     PenaltyType = "mute"
	PenaltyChatBan  PenaltyType = "chat_ban"
	PenaltyTempBan  PenaltyType = "temp_ban"
	PenaltyPermaBan PenaltyType = "perma_ban"
)

// Penalty represents a moderation action
type Penalty struct {
	ID        string      `json:"id"`
	UserID    string      `json:"userId"`
	Type      PenaltyType `json:"type"`
	Reason    string      `json:"reason"`
	IssuedBy  string      `json:"issuedBy"`
	StartsAt  string      `json:"startsAt"`
	ExpiresAt *string     `json:"expiresAt"`
	IsActive  bool        `json:"isActive"`
}

// IssuePenalty creates a new penalty for a user
func IssuePenalty(userID string, penType PenaltyType, reason, issuedBy string, durationHours int) error {
	if DB == nil {
		return nil
	}
	var expiresAt *time.Time
	if durationHours > 0 {
		t := time.Now().Add(time.Duration(durationHours) * time.Hour)
		expiresAt = &t
	}
	_, err := DB.Exec(`
		INSERT INTO penalties (user_id, type, reason, issued_by, starts_at, expires_at, is_active)
		VALUES ($1, $2, $3, $4, now(), $5, true)
	`, userID, penType, reason, issuedBy, expiresAt)
	return err
}

// GetActivePenalties returns current active penalties for a user
func GetActivePenalties(userID string) ([]Penalty, error) {
	if DB == nil {
		return []Penalty{}, nil
	}
	rows, err := DB.Query(`
		SELECT id, user_id, type, reason, issued_by, starts_at, expires_at, is_active
		FROM penalties
		WHERE user_id = $1 AND is_active = true
		  AND (expires_at IS NULL OR expires_at > now())
		ORDER BY starts_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var pens []Penalty
	for rows.Next() {
		var p Penalty
		rows.Scan(&p.ID, &p.UserID, &p.Type, &p.Reason, &p.IssuedBy, &p.StartsAt, &p.ExpiresAt, &p.IsActive)
		pens = append(pens, p)
	}
	return pens, nil
}

// CheckAutoMod runs auto-moderation rules after a report
// Returns true if an auto-penalty was applied
func CheckAutoMod(reportedID string) bool {
	if DB == nil {
		return false
	}
	// Count reports in last 24h from different users
	var reportCount int
	DB.QueryRow(`
		SELECT COUNT(DISTINCT reporter_id)
		FROM reports
		WHERE reported_id = $1 AND created_at > now() - interval '24 hours'
	`, reportedID).Scan(&reportCount)

	if reportCount >= 3 {
		// Auto-mute for 24h
		IssuePenalty(reportedID, PenaltyMute, "Auto-mod: 3+ reports in 24h", "system", 24)
		return true
	}
	return false
}

// IsPlayerBanned checks if player has an active ban
func IsPlayerBanned(userID string) (bool, string) {
	if DB == nil {
		return false, ""
	}
	var reason string
	err := DB.QueryRow(`
		SELECT reason FROM penalties
		WHERE user_id = $1 AND is_active = true
		  AND type IN ('temp_ban', 'perma_ban')
		  AND (expires_at IS NULL OR expires_at > now())
		LIMIT 1
	`, userID).Scan(&reason)
	if err != nil {
		return false, ""
	}
	return true, reason
}

// IsPlayerMuted checks if player has active mute/chat_ban
func IsPlayerMuted(userID string) bool {
	if DB == nil {
		return false
	}
	var count int
	DB.QueryRow(`
		SELECT COUNT(*) FROM penalties
		WHERE user_id = $1 AND is_active = true
		  AND type IN ('mute', 'chat_ban')
		  AND (expires_at IS NULL OR expires_at > now())
	`, userID).Scan(&count)
	return count > 0
}
