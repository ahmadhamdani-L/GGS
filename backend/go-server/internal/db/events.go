package db

import (
	"encoding/json"
	"time"
)

// parseJSON is a helper to unmarshal JSONB data from postgres
func parseJSON(data []byte, target interface{}) {
	if len(data) > 0 {
		json.Unmarshal(data, target)
	}
}

// Event represents a game event
type Event struct {
	ID           string                 `json:"id"`
	Name         string                 `json:"name"`
	Description  string                 `json:"description"`
	EventType    string                 `json:"eventType"`
	BannerEmoji  string                 `json:"bannerEmoji"`
	Rewards      []EventReward          `json:"rewards"`
	Requirements map[string]interface{} `json:"requirements"`
	StartAt      time.Time              `json:"startAt"`
	EndAt        time.Time              `json:"endAt"`
	IsActive     bool                   `json:"isActive"`
}

// EventReward defines a reward for completing an event
type EventReward struct {
	Type   string `json:"type"`
	Amount int    `json:"amount"`
}

// EventProgress tracks user progress in an event
type EventProgress struct {
	ID          string                 `json:"id"`
	UserID      string                 `json:"userId"`
	EventID     string                 `json:"eventId"`
	Progress    map[string]interface{} `json:"progress"`
	Claimed     bool                   `json:"claimed"`
	CompletedAt *time.Time             `json:"completedAt,omitempty"`
}

// EventWithProgress combines event info with user progress
type EventWithProgress struct {
	Event    Event          `json:"event"`
	Progress *EventProgress `json:"progress,omitempty"`
}

// GetActiveEvents returns all currently active events
func GetActiveEvents() ([]Event, error) {
	if DB == nil {
		return defaultEvents(), nil
	}
	rows, err := DB.Query(`
		SELECT id, name, description, event_type, banner_emoji, rewards, requirements, start_at, end_at, is_active
		FROM events
		WHERE is_active = true AND start_at <= now() AND end_at >= now()
		ORDER BY end_at ASC
	`)
	if err != nil {
		return defaultEvents(), nil
	}
	defer rows.Close()

	var events []Event
	for rows.Next() {
		var e Event
		var rewardsJSON, reqJSON []byte
		err := rows.Scan(&e.ID, &e.Name, &e.Description, &e.EventType, &e.BannerEmoji,
			&rewardsJSON, &reqJSON, &e.StartAt, &e.EndAt, &e.IsActive)
		if err != nil {
			continue
		}
		parseJSON(rewardsJSON, &e.Rewards)
		parseJSON(reqJSON, &e.Requirements)
		events = append(events, e)
	}
	if len(events) == 0 {
		return defaultEvents(), nil
	}
	return events, nil
}

// GetEventProgress returns user progress for an event
func GetEventProgress(userID, eventID string) (*EventProgress, error) {
	if DB == nil {
		return nil, nil
	}
	var ep EventProgress
	var progressJSON []byte
	err := DB.QueryRow(`
		SELECT id, user_id, event_id, progress, claimed, completed_at
		FROM event_progress
		WHERE user_id = $1 AND event_id = $2
	`, userID, eventID).Scan(&ep.ID, &ep.UserID, &ep.EventID, &progressJSON, &ep.Claimed, &ep.CompletedAt)
	if err != nil {
		return nil, nil
	}
	parseJSON(progressJSON, &ep.Progress)
	return &ep, nil
}

// GetEventsWithProgress returns active events with user progress
func GetEventsWithProgress(userID string) ([]EventWithProgress, error) {
	events, err := GetActiveEvents()
	if err != nil {
		return nil, err
	}
	var result []EventWithProgress
	for _, e := range events {
		ewp := EventWithProgress{Event: e}
		if userID != "" {
			progress, _ := GetEventProgress(userID, e.ID)
			ewp.Progress = progress
		}
		result = append(result, ewp)
	}
	return result, nil
}

// ClaimEventReward marks an event as claimed and grants rewards
func ClaimEventReward(userID, eventID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		UPDATE event_progress SET claimed = true, completed_at = now()
		WHERE user_id = $1 AND event_id = $2 AND claimed = false
	`, userID, eventID)
	return err
}

func defaultEvents() []Event {
	return []Event{
		{
			ID:          "default-event-1",
			Name:        "Werewolf Night Festival",
			Description: "Mainkan 5 game dan menangkan 2 untuk hadiah spesial!",
			EventType:   "special",
			BannerEmoji: "🎃",
			Rewards:     []EventReward{{Type: "coins", Amount: 1000}, {Type: "diamonds", Amount: 100}},
			Requirements: map[string]interface{}{"games_played": 5, "wins": 2},
			StartAt:     time.Now().Add(-24 * time.Hour),
			EndAt:       time.Now().Add(7 * 24 * time.Hour),
			IsActive:    true,
		},
	}
}
