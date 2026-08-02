package db

import (
	"encoding/json"
	"fmt"
	"time"
)

// SaveGameSnapshot serialises the current game state to DB so active games
// can be restored after a server restart.
// Called by hub.Shutdown() via os.Signal handler in main.go.
func SaveGameSnapshot(roomID, gameStateJSON string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO game_snapshots (room_id, state_json, saved_at)
		VALUES ($1, $2, now())
		ON CONFLICT (room_id) DO UPDATE
			SET state_json = $2, saved_at = now()
	`, roomID, gameStateJSON)
	return err
}

// LoadGameSnapshots returns all snapshots younger than maxAge.
// Called at server startup before accepting connections.
func LoadGameSnapshots(maxAge time.Duration) (map[string]json.RawMessage, error) {
	if DB == nil {
		return nil, nil
	}
	cutoff := time.Now().Add(-maxAge)
	rows, err := DB.Query(`
		SELECT room_id, state_json FROM game_snapshots
		WHERE saved_at > $1
	`, cutoff)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[string]json.RawMessage)
	for rows.Next() {
		var roomID, stateJSON string
		if err := rows.Scan(&roomID, &stateJSON); err == nil {
			result[roomID] = json.RawMessage(stateJSON)
		}
	}
	return result, nil
}

// DeleteGameSnapshot removes a snapshot once the game has been cleanly restored.
func DeleteGameSnapshot(roomID string) {
	if DB == nil {
		return
	}
	DB.Exec(`DELETE FROM game_snapshots WHERE room_id = $1`, roomID)
}

// DeleteExpiredSnapshots cleans up old snapshots (called at startup + periodic cleanup).
func DeleteExpiredSnapshots(maxAge time.Duration) error {
	if DB == nil {
		return nil
	}
	cutoff := time.Now().Add(-maxAge)
	res, err := DB.Exec(`DELETE FROM game_snapshots WHERE saved_at < $1`, cutoff)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n > 0 {
		fmt.Printf("[Snapshot] Deleted %d expired game snapshots\n", n)
	}
	return nil
}
