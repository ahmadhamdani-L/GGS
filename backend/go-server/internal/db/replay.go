package db

import (
	"encoding/json"
	"time"
)

type GameAction struct {
	ID         string                 `json:"id"`
	GameID     string                 `json:"gameId"`
	Round      int                    `json:"round"`
	Phase      string                 `json:"phase"`
	ActionType string                 `json:"actionType"`
	ActorID    string                 `json:"actorId,omitempty"`
	TargetID   string                 `json:"targetId,omitempty"`
	Data       map[string]interface{} `json:"data,omitempty"`
	Timestamp  time.Time              `json:"timestamp"`
}

// LogGameAction records a single game action for replay.
// Called from the WS hub after each state change.
func LogGameAction(gameID string, round int, phase, actionType, actorID, targetID string, data map[string]interface{}) {
	if DB == nil {
		return
	}
	dataJSON, _ := json.Marshal(data)
	DB.Exec(`
		INSERT INTO game_action_log (game_id, round, phase, action_type, actor_id, target_id, data)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, gameID, round, phase, actionType,
		nullIfEmpty(actorID), nullIfEmpty(targetID), string(dataJSON))
}

// GetGameReplay returns all actions for a game, ordered chronologically.
func GetGameReplay(gameID string) ([]GameAction, error) {
	if DB == nil {
		return nil, nil
	}
	rows, err := DB.Query(`
		SELECT id, game_id, round, phase, action_type,
		       COALESCE(actor_id,''), COALESCE(target_id,''), data, timestamp
		FROM game_action_log
		WHERE game_id = $1
		ORDER BY timestamp ASC
	`, gameID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var actions []GameAction
	for rows.Next() {
		var a GameAction
		var dataJSON string
		if err := rows.Scan(&a.ID, &a.GameID, &a.Round, &a.Phase,
			&a.ActionType, &a.ActorID, &a.TargetID, &dataJSON, &a.Timestamp); err == nil {
			json.Unmarshal([]byte(dataJSON), &a.Data)
			actions = append(actions, a)
		}
	}
	return actions, nil
}

func nullIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
