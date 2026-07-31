package db

import "time"

// FriendStatus represents friendship state
type FriendStatus string

const (
	FriendPending  FriendStatus = "pending"
	FriendAccepted FriendStatus = "accepted"
	FriendBlocked  FriendStatus = "blocked"
)

// Friendship represents a friend relationship
type Friendship struct {
	ID        string       `json:"id"`
	UserID    string       `json:"userId"`
	FriendID  string       `json:"friendId"`
	Status    FriendStatus `json:"status"`
	CreatedAt string       `json:"createdAt"`
}

// FriendProfile is a friend entry with profile info
type FriendProfile struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	AvatarID    int    `json:"avatarId"`
	Level       int    `json:"level"`
	IsOnline    bool   `json:"isOnline"`
	Status      string `json:"status"` // pending, accepted
}

// ReportEntry represents a player report
type ReportEntry struct {
	ID         string `json:"id"`
	ReporterID string `json:"reporterId"`
	ReportedID string `json:"reportedId"`
	Reason     string `json:"reason"`
	Details    string `json:"details"`
	MatchID    string `json:"matchId"`
	CreatedAt  string `json:"createdAt"`
}

// RecentPlayer is someone you played with recently
type RecentPlayer struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	AvatarID    int    `json:"avatarId"`
	Level       int    `json:"level"`
	PlayedAt    string `json:"playedAt"`
	IsFriend    bool   `json:"isFriend"`
}

// --- Friends ---

func SendFriendRequest(userID, friendID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO friendships (user_id, friend_id, status, created_at)
		VALUES ($1, $2, 'pending', $3)
		ON CONFLICT (user_id, friend_id) DO NOTHING
	`, userID, friendID, time.Now().Format(time.RFC3339))
	return err
}

func AcceptFriendRequest(userID, friendID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`UPDATE friendships SET status = 'accepted' WHERE user_id = $1 AND friend_id = $2`, friendID, userID)
	if err != nil {
		return err
	}
	// Create reverse friendship
	DB.Exec(`INSERT INTO friendships (user_id, friend_id, status, created_at) VALUES ($1, $2, 'accepted', $3) ON CONFLICT DO NOTHING`,
		userID, friendID, time.Now().Format(time.RFC3339))
	return nil
}

func BlockUser(userID, blockedID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO friendships (user_id, friend_id, status, created_at)
		VALUES ($1, $2, 'blocked', $3)
		ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'blocked'
	`, userID, blockedID, time.Now().Format(time.RFC3339))
	return err
}

func RemoveFriend(userID, friendID string) error {
	if DB == nil {
		return nil
	}
	DB.Exec(`DELETE FROM friendships WHERE user_id = $1 AND friend_id = $2`, userID, friendID)
	DB.Exec(`DELETE FROM friendships WHERE user_id = $1 AND friend_id = $2`, friendID, userID)
	return nil
}

func GetFriends(userID string) ([]FriendProfile, error) {
	if DB == nil {
		return []FriendProfile{}, nil
	}
	rows, err := DB.Query(`
		SELECT f.friend_id, p.display_name, p.avatar_id, p.level, f.status
		FROM friendships f
		JOIN profiles p ON p.user_id = f.friend_id
		WHERE f.user_id = $1 AND f.status IN ('accepted', 'pending')
		ORDER BY f.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []FriendProfile
	for rows.Next() {
		var fp FriendProfile
		if err := rows.Scan(&fp.UserID, &fp.DisplayName, &fp.AvatarID, &fp.Level, &fp.Status); err != nil {
			continue
		}
		friends = append(friends, fp)
	}
	return friends, nil
}

func GetPendingRequests(userID string) ([]FriendProfile, error) {
	if DB == nil {
		return []FriendProfile{}, nil
	}
	rows, err := DB.Query(`
		SELECT f.user_id, p.display_name, p.avatar_id, p.level, 'pending'
		FROM friendships f
		JOIN profiles p ON p.user_id = f.user_id
		WHERE f.friend_id = $1 AND f.status = 'pending'
		ORDER BY f.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []FriendProfile
	for rows.Next() {
		var fp FriendProfile
		if err := rows.Scan(&fp.UserID, &fp.DisplayName, &fp.AvatarID, &fp.Level, &fp.Status); err != nil {
			continue
		}
		friends = append(friends, fp)
	}
	return friends, nil
}

// --- Blocked Users ---

// BlockedUser represents a blocked player
type BlockedUser struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	AvatarID    int    `json:"avatarId"`
	BlockedAt   string `json:"blockedAt"`
}

func GetBlockedUsers(userID string) ([]BlockedUser, error) {
	if DB == nil {
		return []BlockedUser{}, nil
	}
	rows, err := DB.Query(`
		SELECT f.friend_id, p.display_name, p.avatar_id, f.created_at
		FROM friendships f
		JOIN profiles p ON p.user_id = f.friend_id
		WHERE f.user_id = $1 AND f.status = 'blocked'
		ORDER BY f.created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocked []BlockedUser
	for rows.Next() {
		var bu BlockedUser
		if err := rows.Scan(&bu.UserID, &bu.DisplayName, &bu.AvatarID, &bu.BlockedAt); err != nil {
			continue
		}
		blocked = append(blocked, bu)
	}
	return blocked, nil
}

func UnblockUser(userID, blockedID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`DELETE FROM friendships WHERE user_id = $1 AND friend_id = $2 AND status = 'blocked'`, userID, blockedID)
	return err
}

func IsUserBlocked(userID, otherID string) (bool, error) {
	if DB == nil {
		return false, nil
	}
	var exists bool
	err := DB.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM friendships WHERE user_id = $1 AND friend_id = $2 AND status = 'blocked')
	`, userID, otherID).Scan(&exists)
	return exists, err
}

// --- Reports ---

func ReportPlayer(reporterID, reportedID, reason, details, matchID string) error {
	if DB == nil {
		return nil
	}
	_, err := DB.Exec(`
		INSERT INTO reports (reporter_id, reported_id, reason, details, match_id, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, reporterID, reportedID, reason, details, matchID, time.Now().Format(time.RFC3339))
	return err
}

// --- Recent Players ---

func GetRecentPlayers(userID string, limit int) ([]RecentPlayer, error) {
	if DB == nil {
		return []RecentPlayer{}, nil
	}
	if limit <= 0 {
		limit = 20
	}
	rows, err := DB.Query(`
		SELECT DISTINCT ON (p.user_id) p.user_id, p.display_name, p.avatar_id, p.level, mh.played_at,
			EXISTS(SELECT 1 FROM friendships f WHERE f.user_id = $1 AND f.friend_id = p.user_id AND f.status = 'accepted') as is_friend
		FROM match_history mh
		JOIN match_history mh2 ON mh.match_id = mh2.match_id AND mh2.user_id = $1
		JOIN profiles p ON p.user_id = mh.user_id
		WHERE mh.user_id != $1
		ORDER BY p.user_id, mh.played_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var players []RecentPlayer
	for rows.Next() {
		var rp RecentPlayer
		if err := rows.Scan(&rp.UserID, &rp.DisplayName, &rp.AvatarID, &rp.Level, &rp.PlayedAt, &rp.IsFriend); err != nil {
			continue
		}
		players = append(players, rp)
	}
	return players, nil
}
