package db

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
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
	AvatarURL   string                 `json:"avatarUrl,omitempty"` // custom uploaded photo
	Coins       int64                  `json:"coins"`
	Level       int                    `json:"level"`
	XP          int64                  `json:"xp"`
	GamesPlayed int                    `json:"gamesPlayed"`
	GamesWon    int                    `json:"gamesWon"`
	Charm       int                    `json:"charm"`
	Popularity  int                    `json:"popularity"`
	RankTier    string                 `json:"rankTier"`
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

// CreateUser registers a user with email/password (transactional)
func CreateUser(email, password, displayName string) (*User, *Profile, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	// P1-4 FIX: Wrap in transaction to prevent orphan records on partial failure
	tx, err := DB.Begin()
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback() // no-op if committed

	user := &User{}
	err = tx.QueryRow(`
		INSERT INTO users (email, password_hash, is_guest)
		VALUES ($1, $2, false)
		RETURNING id, email, is_guest, created_at
	`, email, string(hash)).Scan(&user.ID, &user.Email, &user.IsGuest, &user.CreatedAt)
	if err != nil {
		return nil, nil, err
	}

	profile := &Profile{}
	err = tx.QueryRow(`
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

	// Non-critical rows — still inside tx for atomicity
	tx.Exec(`INSERT INTO player_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, user.ID)
	tx.Exec(`INSERT INTO leaderboard (user_id, display_name) VALUES ($1, $2) ON CONFLICT DO NOTHING`, user.ID, displayName)
	tx.Exec(`INSERT INTO diamond_balance (user_id, amount) VALUES ($1, 100) ON CONFLICT DO NOTHING`, user.ID)

	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit tx: %w", err)
	}

	return user, profile, nil
}

// CreateGuest creates a guest user (transactional)
func CreateGuest(displayName string) (*User, *Profile, error) {
	// P1-4 FIX: Wrap in transaction
	tx, err := DB.Begin()
	if err != nil {
		return nil, nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	user := &User{}
	err = tx.QueryRow(`
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
	err = tx.QueryRow(`
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

	tx.Exec(`INSERT INTO player_stats (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, user.ID)
	tx.Exec(`INSERT INTO leaderboard (user_id, display_name, coins) VALUES ($1, $2, 50) ON CONFLICT DO NOTHING`, user.ID, displayName)
	tx.Exec(`INSERT INTO diamond_balance (user_id, amount) VALUES ($1, 100) ON CONFLICT DO NOTHING`, user.ID)

	if err := tx.Commit(); err != nil {
		return nil, nil, fmt.Errorf("commit tx: %w", err)
	}

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

// GetProfile returns a user's profile including chibi config and avatar_url
func GetProfile(userID string) (*Profile, error) {
	profile := &Profile{}
	var chibiConfigJSON sql.NullString
	var avatarURL sql.NullString

	err := DB.QueryRow(`
		SELECT user_id, display_name, avatar_id, COALESCE(avatar_url,''),
		       coins, level, xp, games_played, games_won, chibi_config
		FROM profiles WHERE user_id = $1
	`, userID).Scan(
		&profile.UserID, &profile.DisplayName, &profile.AvatarID, &avatarURL,
		&profile.Coins, &profile.Level, &profile.XP,
		&profile.GamesPlayed, &profile.GamesWon,
		&chibiConfigJSON,
	)
	if err != nil {
		return nil, err
	}
	if avatarURL.Valid {
		profile.AvatarURL = avatarURL.String
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

// MaxAvatarID is the maximum valid avatar ID (matches Flutter assets/avatars/ — 12 avatars)
// H-11 FIX: was 4, all 12 avatars are valid
const MaxAvatarID = 12

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

// ConvertGuest converts a guest user to a registered email account
func ConvertGuest(userID, email, password string) (*User, *Profile, error) {
	// Check if email already registered
	var count int
	err := DB.QueryRow(`SELECT COUNT(*) FROM users WHERE email = $1`, email).Scan(&count)
	if err != nil {
		return nil, nil, err
	}
	if count > 0 {
		return nil, nil, errors.New("email already registered")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	user := &User{}
	err = DB.QueryRow(`
		UPDATE users SET
			email = $2,
			password_hash = $3,
			is_guest = false
		WHERE id = $1 AND is_guest = true
		RETURNING id, email, is_guest, created_at
	`, userID, email, string(hash)).Scan(&user.ID, &user.Email, &user.IsGuest, &user.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil, errors.New("user is not a guest account or not found")
		}
		return nil, nil, err
	}

	profile, err := GetProfile(userID)
	if err != nil {
		return nil, nil, err
	}

	return user, profile, nil
}

// ResetPassword updates user password hash for a given email
func ResetPassword(email, newPassword string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	res, err := DB.Exec(`UPDATE users SET password_hash = $2 WHERE email = $1`, email, string(hash))
	if err != nil {
		return err
	}

	rows, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return errors.New("email not found")
	}

	return nil
}

// SearchUsers searches profiles by display name or user ID
func SearchUsers(query string) ([]Profile, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return []Profile{}, nil
	}

	// #7 FIX: Escape SQL LIKE metacharacters (% and _) to prevent wildcard injection.
	// A raw query of "%" would otherwise match ALL users.
	safeQuery := strings.ReplaceAll(query, `\`, `\\`)
	safeQuery = strings.ReplaceAll(safeQuery, "%", `\%`)
	safeQuery = strings.ReplaceAll(safeQuery, "_", `\_`)

	rows, err := DB.Query(`
		SELECT user_id, display_name, avatar_id, coins, level, xp, games_played, games_won,
		       COALESCE(charm, 300), COALESCE(popularity, 150)
		FROM profiles
		WHERE LOWER(display_name) LIKE LOWER($1) ESCAPE '\' OR user_id::text = $2
		LIMIT 20
	`, "%"+safeQuery+"%", query)
	if err != nil {
		return []Profile{}, nil
	}
	defer rows.Close()

	var results []Profile
	for rows.Next() {
		var p Profile
		err := rows.Scan(
			&p.UserID, &p.DisplayName, &p.AvatarID,
			&p.Coins, &p.Level, &p.XP,
			&p.GamesPlayed, &p.GamesWon,
			&p.Charm, &p.Popularity,
		)
		if err == nil {
			p.RankTier = CalculateRankTier(p.XP)
			results = append(results, p)
		}
	}
	return results, nil
}

// ─── Password Reset Token ────────────────────────────────
// H-04 FIX: Token-based password reset instead of direct email→password change.

// CreatePasswordResetToken generates a 6-digit token, stores it hashed in DB (5-minute TTL).
func CreatePasswordResetToken(email string) (string, error) {
	if DB == nil {
		return "", errors.New("database not available")
	}
	// Ensure user exists
	var userID string
	if err := DB.QueryRow(`SELECT id FROM users WHERE email = $1 AND is_guest = false`, email).Scan(&userID); err != nil {
		return "", errors.New("email not found")
	}

	// Generate 6-digit token
	b := make([]byte, 3)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	token := fmt.Sprintf("%06d", int(b[0])%1000000)

	hash, err := bcrypt.GenerateFromPassword([]byte(token), bcrypt.MinCost)
	if err != nil {
		return "", err
	}

	// Store token (upsert — one active token per user)
	_, err = DB.Exec(`
		INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, NOW() + INTERVAL '5 minutes')
		ON CONFLICT (user_id) DO UPDATE
		SET token_hash = $2, expires_at = NOW() + INTERVAL '5 minutes', used = false
	`, userID, string(hash))
	if err != nil {
		return "", err
	}
	return token, nil
}

// ResetPasswordWithToken validates the reset token and updates the password.
func ResetPasswordWithToken(email, token, newPassword string) error {
	if DB == nil {
		return errors.New("database not available")
	}
	var userID, tokenHash string
	var expiresAt time.Time
	var used bool
	err := DB.QueryRow(`
		SELECT u.id, prt.token_hash, prt.expires_at, prt.used
		FROM users u
		JOIN password_reset_tokens prt ON prt.user_id = u.id
		WHERE u.email = $1 AND u.is_guest = false
	`, email).Scan(&userID, &tokenHash, &expiresAt, &used)
	if err != nil {
		return errors.New("invalid or expired reset token")
	}
	if used {
		return errors.New("reset token already used")
	}
	if time.Now().After(expiresAt) {
		return errors.New("reset token expired")
	}
	if bcrypt.CompareHashAndPassword([]byte(tokenHash), []byte(token)) != nil {
		return errors.New("invalid reset token")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	_, err = DB.Exec(`UPDATE users SET password_hash = $2 WHERE id = $1`, userID, string(hash))
	if err != nil {
		return err
	}
	// Mark token as used
	DB.Exec(`UPDATE password_reset_tokens SET used = true WHERE user_id = $1`, userID)
	return nil
}

// ─── FCM Push Notification Tokens ────────────────────────────

// SaveFCMToken upserts the FCM device token for a user (one per user, latest wins).
func SaveFCMToken(userID, token, platform string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
		VALUES ($1, $2, $3, now())
		ON CONFLICT (user_id) DO UPDATE
			SET token = $2, platform = $3, updated_at = now()
	`, userID, token, platform)
	return err
}

// GetFCMToken returns the current FCM token for a user, or "" if none.
func GetFCMToken(userID string) (string, error) {
	if DB == nil {
		return "", nil
	}
	var token string
	err := DB.QueryRow(`SELECT token FROM fcm_tokens WHERE user_id=$1`, userID).Scan(&token)
	if err != nil {
		return "", nil // no token is not an error
	}
	return token, nil
}

// DeleteFCMToken removes a user's FCM token on logout.
func DeleteFCMToken(userID string) {
	if DB == nil {
		return
	}
	DB.Exec(`DELETE FROM fcm_tokens WHERE user_id=$1`, userID)
}

// ─── Delete Account ──────────────────────────────────────────

// DeleteAccount permanently removes a user and all their data.
// Uses CASCADE on foreign keys so all related rows are automatically deleted.
func DeleteAccount(userID string) error {
	if DB == nil {
		return nil
	}
	// Delete user — CASCADE handles profiles, stats, match_history, etc.
	_, err := DB.Exec(`DELETE FROM users WHERE id = $1`, userID)
	return err
}
