package db

import (
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID           string    `json:"id"`
	Email        *string   `json:"email,omitempty"`
	PasswordHash string    `json:"-"`
	IsGuest      bool      `json:"isGuest"`
	CreatedAt    time.Time `json:"createdAt"`
}

type Profile struct {
	UserID      string                 `json:"userId"`
	DisplayName string                 `json:"displayName"`
	AvatarID    int                    `json:"avatarId"`
	Coins       int64                  `json:"coins"`
	Level       int                    `json:"level"`
	XP          int64                  `json:"xp"`
	GamesPlayed int                    `json:"gamesPlayed"`
	GamesWon    int                    `json:"gamesWon"`
	ChibiConfig map[string]interface{} `json:"chibiConfig,omitempty"`
}

// DefaultChibiConfig returns the default chibi avatar configuration
func DefaultChibiConfig() map[string]interface{} {
	return map[string]interface{}{
		"skinColor":      4294961865,
		"hairColor":      4287269688,
		"eyeColor":       4285227043,
		"shirtColor":     4294309365,
		"pantsColor":     4284185507,
		"hairStyle":      0,
		"eyeStyle":       0,
		"expression":     2,
		"shirtStyle":     0,
		"accessory":      0,
		"accessoryColor": nil,
		"showBlush":      true,
		"version":        1,
	}
}

// CreateUser registers a user with email/password
func CreateUser(email, password, displayName string) (*User, *Profile, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	user := &User{}
	err = DB.QueryRow(`
		INSERT INTO users (email, password_hash, is_guest)
		VALUES ($1, $2, false)
		RETURNING id, email, is_guest, created_at
	`, email, string(hash)).Scan(&user.ID, &user.Email, &user.IsGuest, &user.CreatedAt)
	if err != nil {
		return nil, nil, err
	}

	profile := &Profile{}
	err = DB.QueryRow(`
		INSERT INTO profiles (user_id, display_name)
		VALUES ($1, $2)
		RETURNING user_id, display_name, avatar_id, coins, level, xp, games_played, games_won
	`, user.ID, displayName).Scan(
		&profile.UserID, &profile.DisplayName, &profile.AvatarID,
		&profile.Coins, &profile.Level, &profile.XP,
		&profile.GamesPlayed, &profile.GamesWon,
	)
	if err != nil {
		return nil, nil, err
	}

	// Init stats and leaderboard
	DB.Exec(`INSERT INTO player_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, user.ID)
	DB.Exec(`INSERT INTO leaderboard (user_id, display_name) VALUES ($1, $2) ON CONFLICT DO NOTHING`, user.ID, displayName)

	return user, profile, nil
}

// CreateGuest creates a guest user
func CreateGuest(displayName string) (*User, *Profile, error) {
	user := &User{}
	err := DB.QueryRow(`
		INSERT INTO users (is_guest)
		VALUES (true)
		RETURNING id, is_guest, created_at
	`).Scan(&user.ID, &user.IsGuest, &user.CreatedAt)
	if err != nil {
		return nil, nil, err
	}

	if displayName == "" {
		displayName = "Tamu_" + user.ID[:6]
	}

	profile := &Profile{}
	err = DB.QueryRow(`
		INSERT INTO profiles (user_id, display_name, coins)
		VALUES ($1, $2, 50)
		RETURNING user_id, display_name, avatar_id, coins, level, xp, games_played, games_won
	`, user.ID, displayName).Scan(
		&profile.UserID, &profile.DisplayName, &profile.AvatarID,
		&profile.Coins, &profile.Level, &profile.XP,
		&profile.GamesPlayed, &profile.GamesWon,
	)
	if err != nil {
		return nil, nil, err
	}

	DB.Exec(`INSERT INTO player_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, user.ID)
	DB.Exec(`INSERT INTO leaderboard (user_id, display_name, coins) VALUES ($1, $2, 50) ON CONFLICT DO NOTHING`, user.ID, displayName)

	return user, profile, nil
}

// LoginUser validates credentials
func LoginUser(email, password string) (*User, error) {
	user := &User{}
	err := DB.QueryRow(`
		SELECT id, email, password_hash, is_guest, created_at
		FROM users WHERE email = $1
	`, email).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.IsGuest, &user.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("invalid email or password")
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, errors.New("invalid email or password")
	}

	return user, nil
}

// GetProfile returns a user's profile including chibi config
func GetProfile(userID string) (*Profile, error) {
	profile := &Profile{}
	var chibiConfigJSON sql.NullString
	
	err := DB.QueryRow(`
		SELECT user_id, display_name, avatar_id, coins, level, xp, games_played, games_won, chibi_config
		FROM profiles WHERE user_id = $1
	`, userID).Scan(
		&profile.UserID, &profile.DisplayName, &profile.AvatarID,
		&profile.Coins, &profile.Level, &profile.XP,
		&profile.GamesPlayed, &profile.GamesWon,
		&chibiConfigJSON,
	)
	if err != nil {
		return nil, err
	}
	
	// Parse chibi config JSON
	if chibiConfigJSON.Valid && chibiConfigJSON.String != "" {
		if err := json.Unmarshal([]byte(chibiConfigJSON.String), &profile.ChibiConfig); err != nil {
			// Use default if JSON is invalid
			profile.ChibiConfig = DefaultChibiConfig()
		}
	} else {
		profile.ChibiConfig = DefaultChibiConfig()
	}
	
	return profile, nil
}

// MaxAvatarID is the maximum valid avatar ID (matches Flutter assets/avatars/)
const MaxAvatarID = 4

// UpdateProfile updates display name and avatar
func UpdateProfile(userID, displayName string, avatarID int) (*Profile, error) {
	profile := &Profile{}
	var chibiConfigJSON sql.NullString
	
	err := DB.QueryRow(`
		UPDATE profiles SET
			display_name = COALESCE(NULLIF($2, ''), display_name),
			avatar_id = CASE WHEN $3 > 0 AND $3 <= $4 THEN $3 ELSE avatar_id END,
			updated_at = now()
		WHERE user_id = $1
		RETURNING user_id, display_name, avatar_id, coins, level, xp, games_played, games_won, chibi_config
	`, userID, displayName, avatarID, MaxAvatarID).Scan(
		&profile.UserID, &profile.DisplayName, &profile.AvatarID,
		&profile.Coins, &profile.Level, &profile.XP,
		&profile.GamesPlayed, &profile.GamesWon,
		&chibiConfigJSON,
	)
	if err != nil {
		return nil, err
	}

	// Parse chibi config JSON
	if chibiConfigJSON.Valid && chibiConfigJSON.String != "" {
		if err := json.Unmarshal([]byte(chibiConfigJSON.String), &profile.ChibiConfig); err != nil {
			profile.ChibiConfig = DefaultChibiConfig()
		}
	} else {
		profile.ChibiConfig = DefaultChibiConfig()
	}

	// Sync leaderboard
	DB.Exec(`UPDATE leaderboard SET display_name=$2, avatar_id=$3 WHERE user_id=$1`,
		userID, profile.DisplayName, profile.AvatarID)

	return profile, nil
}

// UpdateChibiConfig updates the chibi avatar configuration for a user
func UpdateChibiConfig(userID string, config map[string]interface{}) error {
	// Add version if not present
	if _, ok := config["version"]; !ok {
		config["version"] = 1
	}
	
	configJSON, err := json.Marshal(config)
	if err != nil {
		return err
	}
	
	_, err = DB.Exec(`
		UPDATE profiles 
		SET chibi_config = $2, updated_at = now()
		WHERE user_id = $1
	`, userID, string(configJSON))
	
	return err
}
