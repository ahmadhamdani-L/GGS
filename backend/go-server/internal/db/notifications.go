package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

// Notification types
const (
	NotifyFriendRequest    = "friend_request"
	NotifyFriendAccepted   = "friend_accepted"
	NotifyGameInvite       = "game_invite"
	NotifyAchievementUnlock = "achievement_unlocked"
	NotifyMissionComplete  = "mission_complete"
	NotifyLevelUp          = "level_up"
	NotifyDailyReward      = "daily_reward"
	NotifySystemMessage    = "system"
)

// Notification represents an in-app notification
type Notification struct {
	ID        string                 `json:"id"`
	UserID    string                 `json:"userId"`
	Type      string                 `json:"type"`
	Title     string                 `json:"title"`
	Message   string                 `json:"message"`
	Data      map[string]interface{} `json:"data,omitempty"`
	IsRead    bool                   `json:"isRead"`
	CreatedAt time.Time              `json:"createdAt"`
}

// GetNotifications returns notifications for a user
func GetNotifications(userID string, limit int, unreadOnly bool) ([]Notification, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.GetNotifications(userID, limit, unreadOnly)
		}
		return nil, fmt.Errorf("no database connection")
	}

	if limit <= 0 || limit > 100 {
		limit = 50
	}

	query := `
		SELECT id, user_id, type, title, message, data, is_read, created_at
		FROM notifications 
		WHERE user_id = $1
	`
	if unreadOnly {
		query += ` AND is_read = FALSE`
	}
	query += ` ORDER BY created_at DESC LIMIT $2`

	rows, err := DB.Query(query, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("query notifications: %w", err)
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var n Notification
		var dataJSON sql.NullString
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Message, &dataJSON, &n.IsRead, &n.CreatedAt); err != nil {
			continue
		}
		// Parse data JSON if present
		if dataJSON.Valid && len(dataJSON.String) > 2 {
			if err := json.Unmarshal([]byte(dataJSON.String), &n.Data); err != nil {
				n.Data = make(map[string]interface{})
			}
		}
		notifications = append(notifications, n)
	}

	if notifications == nil {
		notifications = []Notification{}
	}

	return notifications, nil
}

// GetUnreadCount returns the count of unread notifications
func GetUnreadCount(userID string) (int, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.GetUnreadCount(userID)
		}
		return 0, nil
	}

	var count int
	err := DB.QueryRow(`
		SELECT COUNT(*) FROM notifications 
		WHERE user_id = $1 AND is_read = FALSE
	`, userID).Scan(&count)
	if err != nil {
		return 0, err
	}
	return count, nil
}

// MarkNotificationRead marks a single notification as read
func MarkNotificationRead(userID, notificationID string) error {
	if DB == nil {
		if Mem != nil {
			return Mem.MarkNotificationRead(userID, notificationID)
		}
		return nil
	}

	_, err := DB.Exec(`
		UPDATE notifications SET is_read = TRUE 
		WHERE id = $1 AND user_id = $2
	`, notificationID, userID)
	return err
}

// MarkAllNotificationsRead marks all notifications as read for a user
func MarkAllNotificationsRead(userID string) error {
	if DB == nil {
		if Mem != nil {
			return Mem.MarkAllNotificationsRead(userID)
		}
		return nil
	}

	_, err := DB.Exec(`
		UPDATE notifications SET is_read = TRUE 
		WHERE user_id = $1 AND is_read = FALSE
	`, userID)
	return err
}

// Fix notifications.go — CreateNotification passes data as JSON bytes, not hardcoded "{}"
func CreateNotification(userID, notifType, title, message string, data map[string]interface{}) (*Notification, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.CreateNotification(userID, notifType, title, message, data)
		}
		return nil, fmt.Errorf("no database connection")
	}

	id := fmt.Sprintf("notif_%s_%d", userID[:8], time.Now().UnixNano())
	now := time.Now()

	// Marshal data to JSON; use empty object if nil
	dataBytes := []byte("{}")
	if data != nil {
		if b, err := json.Marshal(data); err == nil {
			dataBytes = b
		}
	}

	_, err := DB.Exec(`
		INSERT INTO notifications (id, user_id, type, title, message, data, is_read, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, FALSE, $7)
	`, id, userID, notifType, title, message, string(dataBytes), now)
	if err != nil {
		return nil, err
	}

	return &Notification{
		ID:        id,
		UserID:    userID,
		Type:      notifType,
		Title:     title,
		Message:   message,
		Data:      data,
		IsRead:    false,
		CreatedAt: now,
	}, nil
}

// DeleteNotification deletes a notification
func DeleteNotification(userID, notificationID string) error {
	if DB == nil {
		return nil
	}

	_, err := DB.Exec(`
		DELETE FROM notifications 
		WHERE id = $1 AND user_id = $2
	`, notificationID, userID)
	return err
}

// DeleteOldNotifications removes notifications older than given days
func DeleteOldNotifications(days int) (int64, error) {
	if DB == nil {
		return 0, nil
	}

	cutoff := time.Now().AddDate(0, 0, -days)
	result, err := DB.Exec(`
		DELETE FROM notifications 
		WHERE created_at < $1
	`, cutoff)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected()
}

// Helper functions to create specific notification types

// NotifyFriendRequestReceived creates a friend request notification
func NotifyFriendRequestReceived(toUserID, fromUserID, fromDisplayName string) error {
	_, err := CreateNotification(
		toUserID,
		NotifyFriendRequest,
		"Permintaan Pertemanan",
		fmt.Sprintf("%s ingin berteman denganmu", fromDisplayName),
		map[string]interface{}{"fromUserId": fromUserID, "fromDisplayName": fromDisplayName},
	)
	return err
}

// NotifyFriendRequestAccepted creates a friend accepted notification
func NotifyFriendRequestAccepted(toUserID, fromUserID, fromDisplayName string) error {
	_, err := CreateNotification(
		toUserID,
		NotifyFriendAccepted,
		"Pertemanan Diterima",
		fmt.Sprintf("%s menerima permintaan pertemananmu", fromDisplayName),
		map[string]interface{}{"fromUserId": fromUserID, "fromDisplayName": fromDisplayName},
	)
	return err
}

// NotifyGameInviteReceived creates a game invite notification
func NotifyGameInviteReceived(toUserID, fromUserID, fromDisplayName, roomCode string) error {
	_, err := CreateNotification(
		toUserID,
		NotifyGameInvite,
		"Undangan Game",
		fmt.Sprintf("%s mengundangmu ke game", fromDisplayName),
		map[string]interface{}{"fromUserId": fromUserID, "roomCode": roomCode},
	)
	return err
}

// NotifyAchievementUnlocked creates an achievement unlocked notification
func NotifyAchievementUnlocked(userID, achievementName, achievementEmoji string) error {
	_, err := CreateNotification(
		userID,
		NotifyAchievementUnlock,
		"Achievement Unlocked!",
		fmt.Sprintf("%s %s", achievementEmoji, achievementName),
		map[string]interface{}{"achievementName": achievementName},
	)
	return err
}

// NotifyLevelUpAchieved creates a level up notification
func NotifyLevelUpAchieved(userID string, newLevel int) error {
	_, err := CreateNotification(
		userID,
		NotifyLevelUp,
		"Level Up!",
		fmt.Sprintf("Selamat! Kamu naik ke Level %d", newLevel),
		map[string]interface{}{"level": newLevel},
	)
	return err
}

// Memory implementation
func (m *MemStore) GetNotifications(userID string, limit int, unreadOnly bool) ([]Notification, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Return sample notifications for memory store
	now := time.Now()
	return []Notification{
		{
			ID:        "notif_sample_1",
			UserID:    userID,
			Type:      NotifyDailyReward,
			Title:     "Hadiah Harian",
			Message:   "Klaim hadiah harianmu!",
			IsRead:    false,
			CreatedAt: now,
		},
		{
			ID:        "notif_sample_2",
			UserID:    userID,
			Type:      NotifySystemMessage,
			Title:     "Selamat Datang",
			Message:   "Selamat bermain GGS Werewolf!",
			IsRead:    true,
			CreatedAt: now.Add(-24 * time.Hour),
		},
	}, nil
}

func (m *MemStore) GetUnreadCount(userID string) (int, error) {
	return 1, nil // Sample count
}

func (m *MemStore) MarkNotificationRead(userID, notificationID string) error {
	return nil
}

func (m *MemStore) MarkAllNotificationsRead(userID string) error {
	return nil
}

func (m *MemStore) CreateNotification(userID, notifType, title, message string, data map[string]interface{}) (*Notification, error) {
	return &Notification{
		ID:        fmt.Sprintf("notif_%d", time.Now().UnixNano()),
		UserID:    userID,
		Type:      notifType,
		Title:     title,
		Message:   message,
		Data:      data,
		IsRead:    false,
		CreatedAt: time.Now(),
	}, nil
}
