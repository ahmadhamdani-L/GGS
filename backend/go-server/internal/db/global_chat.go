package db

import "time"

// GlobalChatMessage represents a message in global chat
type GlobalChatMessage struct {
	ID          string    `json:"id"`
	UserID      string    `json:"userId"`
	DisplayName string    `json:"displayName"`
	Message     string    `json:"message"`
	CreatedAt   time.Time `json:"createdAt"`
}

// GetRecentGlobalChat returns the most recent global chat messages
func GetRecentGlobalChat(limit int) ([]GlobalChatMessage, error) {
	if DB == nil {
		return nil, nil
	}
	if limit <= 0 {
		limit = 30
	}
	rows, err := DB.Query(`
		SELECT id, user_id, COALESCE(display_name, 'Player'), message, created_at
		FROM global_chat
		ORDER BY created_at DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []GlobalChatMessage
	for rows.Next() {
		var m GlobalChatMessage
		rows.Scan(&m.ID, &m.UserID, &m.DisplayName, &m.Message, &m.CreatedAt)
		messages = append(messages, m)
	}
	// Reverse to get chronological order
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}
	return messages, nil
}

// SaveGlobalChatMessage persists a global chat message
func SaveGlobalChatMessage(userID, displayName, message string) (*GlobalChatMessage, error) {
	if DB == nil {
		return &GlobalChatMessage{
			ID:          "mem-" + time.Now().Format("150405"),
			UserID:      userID,
			DisplayName: displayName,
			Message:     message,
			CreatedAt:   time.Now(),
		}, nil
	}

	var msg GlobalChatMessage
	err := DB.QueryRow(`
		INSERT INTO global_chat (user_id, display_name, message)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, display_name, message, created_at
	`, userID, displayName, message).Scan(&msg.ID, &msg.UserID, &msg.DisplayName, &msg.Message, &msg.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &msg, nil
}
